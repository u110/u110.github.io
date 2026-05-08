# Jekyll の `exclude` を書き足したら GitHub Pages のビルドが壊れた話

このブログをいじっていて踏んだ落とし穴メモ。`_config.yml` の `exclude` は **デフォルト値に追記される設定ではなく、上書きされる設定** だった。

## 何が起きたか

リポジトリ直下の `CLAUDE.md` がヘッダーナビに出ていたので、`_config.yml` に1行足してビルド対象から外した。

```yaml
exclude:
  - CLAUDE.md
```

ローカルの `bundle exec jekyll serve` ではナビからも消え、`/CLAUDE.html` も 404 になり想定どおり。ところが master に push したら GitHub Actions の Jekyll build が exit 1 で落ちた。

```
Error: could not read file vendor/bundle/ruby/3.4.0/gems/jekyll-3.10.0/lib/site_template/_posts/0000-00-00-welcome-to-jekyll.markdown.erb:
Invalid date '<%= Time.now.strftime('%Y-%m-%d %H:%M:%S %z') %>':
Document does not have a valid date in the YAML front matter.
```

gem に同梱されているサイトテンプレの `_posts` を Jekyll が拾ってしまっていた。

## 原因

[Jekyll のデフォルト `exclude`](https://jekyllrb.com/docs/configuration/options/) には `vendor/bundle/` や `node_modules/` などが含まれている。だから普段は CI 上で `bundle install --path vendor/bundle` しても展開された gem は無視される。ところが `_config.yml` で `exclude` を明示すると **デフォルトは継承されず完全に置き換わる**。`vendor/bundle/` の除外が消失したので、`bundle exec jekyll build` が `vendor/bundle/.../jekyll-*/lib/site_template/_posts/` 配下のテンプレートまで普通の記事として読みに行き、ERB プレースホルダのままの `date:` で死んだ、という経路。

ローカルで気付かなかったのは `bundle install` が `~/.gem` に入っていて、リポジトリ直下に `vendor/` が無かったから。

## 直し方

デフォルト分を自分で書き戻す。

```yaml
exclude:
  - CLAUDE.md
  - vendor/
  - node_modules/
  - Gemfile
  - Gemfile.lock
```

これで CI も通った。

## 学び

- 設定の配列フィールドが「マージされる」か「置き換える」かは設定ごとに違う。ドキュメントを読まずに足すと壊れる。Webpack の `plugins` とか ESLint の `extends` あたりでも同じ事故が起きるやつ。
- `_config.yml` の変更は `jekyll serve` の auto-regenerate では再読み込みされないので、ローカルではサーバ再起動が要る。今回はローカルで再起動しないまま push してしまい、CI で初めて踏んだ。
