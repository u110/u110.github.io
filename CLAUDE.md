# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) が本リポジトリで作業する際のガイドを提供します。

## リポジトリの目的

GitHub Pages でホストしている個人ブログ (`u110's blog`)。Jekyll + `minima` テーマ + `github-pages` gem で構築している (= ローカルのスタックは GitHub Pages が描画するものと互換性を保つ必要がある)。

## よく使うコマンド

- `make run` — `bundle exec jekyll serve` を実行 (ローカルプレビューは http://localhost:4000)
- `bundle install` — gem 依存関係をインストール (Ruby バージョンは `.ruby-version` で 3.4.9 に固定)
- `bundle update github-pages` — GitHub Pages スタックをアップグレード (Gemfile のコメントに準拠)

テストスイートと Lint 設定はないため、ローカルでのフィードバックループは Jekyll の serve のみ。`master` への push 時には `.github/workflows/jekyll.yml` が走り、サイトをビルドして GitHub Pages にデプロイする (Ruby バージョンは `.ruby-version` を参照)。

## アーキテクチャ メモ

- **Posts** は `_posts/` 配下に置き、Jekyll の `YYYY-MM-DD-slug.md` 命名規則に従う。`titles_from_headings` (`_config.yml` 参照) を使っているため、ファイル先頭の H1 がポストタイトルになり、レンダリング時に本文から取り除かれる。同じ記事に front-matter の `title:` と H1 を両方書かないこと。
- **Markdown** は kramdown (GFM 入力) で処理し、シンタックスハイライトは rouge、数式エンジンは katex を使用。`_config.yml` の `use_math: true` で数式サポートを有効化し、配線は `_includes/head.html` に入っている。インライン数式は `$...$`、ディスプレイ数式は `$$...$$` または `[%...%]`。
- **Layouts/theme** は `minima` gem から来ており、ローカルで上書きしているのは `_includes/head.html` のみ。テーマの他の部分をカスタマイズしたいときは、gem を直接編集せず、対応するローカルディレクトリに gem 内のファイルをコピーして編集する。
- **Plugins** は GitHub Pages のホワイトリストに載っているもののみ使用可 (現状 `jekyll-feed` のみ)。リスト外のプラグインを追加するとローカルでは動くが本番サイトで壊れる。

## 依存関係の更新

`update-packages` ブランチは Dependabot 形式の gem バンプ (json、faraday、nokogiri、addressable など) を追跡している。gem を更新したらマージ前にローカルで `bundle install` を流し、`make run` でサイトが正常に立ち上がることを確認すること。`master` にマージすると Pages デプロイのワークフローがビルドを走らせるが、それより前にローカルで動作確認するのが基本。
