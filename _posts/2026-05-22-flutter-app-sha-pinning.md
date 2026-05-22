# 個人開発 Flutter app の GitHub Actions を SHA pinning 対応した

個人開発の Flutterアプリで、GitHub Actions のサードパーティ action 参照を全部 SHA pinning に揃えた。
昨今のサプライチェーン問題は業務でも対応していたので、学びのために個人リポジトリでもやってみた、というメモ。

最終的に 利用していた GHA の一部は置き換えも行った。

## なぜ SHA pinning するのか

サードパーティ action を `@v1` `@v4` のようなタグで参照すると、タグは可変なので攻撃者がタグを悪意あるコミットに付け替えるだけでこちら側の CI に任意コードが流れ込む。
2025年3月の事案 ([CVE-2025-30066](https://nvd.nist.gov/vuln/detail/CVE-2025-30066) / [GHSA-mrrh-fwg8-r2c3](https://github.com/advisories/GHSA-mrrh-fwg8-r2c3)) は実際にこれが起きた例で、複数のリリースタグが悪意あるコミットに書き換えられ、runner メモリから secrets をダンプしてログに出力する payload が走ったとのこと。

SHA を直接参照していれば、タグが書き換えられても参照先は変わらない。[GitHub 公式](https://docs.github.com/en/actions/reference/security/secure-use#using-third-party-actions) も

> Pinning an action to a full-length commit SHA is currently the only way to use an action as an immutable release

> （訳）アクションを完全なコミットSHAに固定することは、現在、アクションを不変のリリースとして使用する唯一の方法です。

と書いている。

## 対応前の状態

ワークフローは Android APK build / iOS build / dart format の3本あり、それぞれ以下を可変タグで参照していた。

- `actions/checkout@v2`
- `actions/setup-java@v2`
- `subosito/flutter-action@v1`

`flutter pub get` 前の Flutter SDK セットアップは共通なので、`.github/actions/flutter_setting/action.yml` という local composite action に切り出してあった。

`setup-java` と `flutter-action` はその中。`checkout` だけ各 workflow が直接呼んでいる。

## 進め方

SHA pinning 自体はシンプルで、対象タグを指している commit を引いて置換するだけ。

```bash
gh api repos/actions/checkout/git/refs/tags/v4 --jq '.object.sha'
```

`actions/checkout` `actions/setup-java` はこれで置換。コメントに元のバージョンを残しておくと後で読みやすい。

```yaml
- uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
- uses: actions/setup-java@c1e323688fd81a25caa38c78aa6df2d33d3e20d9 # v4
  with:
    distribution: 'zulu'
    java-version: '11'
```

ここまでは順当だったが、`subosito/flutter-action` で詰まった。

## 補足: `subosito/flutter-action` の内部が unpinned だった

`subosito/flutter-action@v1` を SHA に置き換えようとして中身を覗いたら、composite action の内部で `actions/cache` を可変タグで呼んでいた。

```yaml
- name: Cache Flutter
  id: cache-flutter
  uses: actions/cache@v5
  ...
- name: Cache pub dependencies
  uses: actions/cache@v5
  ...
```

外側の `subosito/flutter-action` を SHA で固定しても、その内部の `actions/cache@v5` は可変のまま呼ばれる。
つまり推移的依存に SHA pinning の穴が残る。

サードパーティ composite action は中身まで確認しないと「pinning した」とは言えない、という当然の話だが、実際に踏むまで意識していなかった。

(2026-03-30 時点の v1 / 直近の v2.23.0 (2026-03-25 リリース) どちらでも同様。)

## 対応 — 自前 composite で Flutter SDK を直ダウンロード

`subosito/flutter-action` でやっていることは要するに「Flutter SDK の zip を取ってきて PATH に通す」だけなので、
今回は自前 composite action で書き直すことにした。以下修正した GitHub Actions の一部。

```yaml
- name: Install Flutter SDK
  shell: bash
  run: |
    FLUTTER_VERSION="${{ inputs.flutter-version }}"
    if [ "$RUNNER_OS" = "macOS" ]; then
      FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip"
      curl -fsSL "$FLUTTER_URL" -o flutter.zip
      unzip -q flutter.zip -d "$HOME"
      rm flutter.zip
    else
      FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
      curl -fsSL "$FLUTTER_URL" -o flutter.tar.xz
      tar xf flutter.tar.xz -C "$HOME"
      rm flutter.tar.xz
    fi
    echo "$HOME/flutter/bin" >> "$GITHUB_PATH"
```

キャッシュは個人プロジェクトの CI であり、実行時間も数分なので一旦許容。どうしても欲しくなったら、この composite action の中で `actions/cache` を 足すなど（もちろんその場合も SHA pinningもわすれないように）

## 結果

- 3本の workflow が全部 SHA で固定された状態に揃った。
- サードパーティ action の参照は `subosito/flutter-action` が消えたので、結果的に管理対象も減った。
- そのサードパーティも将来は内部を pin する方向に動くかもしれないので、戻すかどうかまた考える。

## 気づき

- **SHA pinning は uses の下も見る必要がある**。外側を pin しても、中で別 action を可変タグで呼んでいたら穴は残る。
- 今回はサードパーティの実装がシンプルだったから自前で書き直したけど、厳しい場合どうすればいいかな。。
- 管理するリポジトリやライブラリ増えると大変。。
- pinning したライブラリで既に問題のあるコードが含まれていたらダメよね。何にせよ利用するライブラリの動向は継続的に追う必要はある。

## 参考

- [StepSecurity: Harden-Runner detection: tj-actions/changed-files action is compromised](https://www.stepsecurity.io/blog/harden-runner-detection-tj-actions-changed-files-action-is-compromised) — 事案を最初に検知・公表したセキュリティベンダのレポート。
- [GHSA-mrrh-fwg8-r2c3](https://github.com/advisories/GHSA-mrrh-fwg8-r2c3) / [CVE-2025-30066](https://nvd.nist.gov/vuln/detail/CVE-2025-30066) — GitHub Security Advisory と CVE。
- [GitHub Docs: Using third-party actions](https://docs.github.com/en/actions/reference/security/secure-use#using-third-party-actions) — SHA pinning が推奨されている公式ガイド。

