# 第24章：Prettierで整形を自動化✍️✨

この章のゴールはシンプル！
**「書き方の迷い（スペース？改行？クォート？）」をゼロにして、保存したら勝手にキレイになる状態**を作ります 😆💾

---

## 0) まず結論：Prettierは“迷いを消す装置”🧠🧹

* **Prettier**：見た目（空白・改行・カンマ・クォート等）を自動で統一 ✨
* **ESLint**：バグっぽい書き方を止める（品質チェック）🛡️

役割を分けるほど、設定がラクで事故りにくいです🙂
（Prettier公式も「整形はPrettier、品質はLint」推し）([Prettier][1])

---

## 1) 2026/02時点の“いま”のPrettier ✅🆕

Prettierは **npm上で 3.8.1（2026-01-21公開）** が確認できます。([npm][2])
3.8系のリリースノートも公式ブログで更新されています。([Prettier][3])

---

## 2) インストール（最短）📦⚡

プロジェクト直下で：

```bash
npm i -D prettier
```

Prettier公式は、CIなどでは **`--check`**、実際に整形するなら **`--write`** が基本だよ、と言っています。([Prettier][4])

---

## 3) 設定ファイルは“最小”でOK（まずは printWidth だけでも）✍️🙂

Prettierは「設定ファイルを探して上の階層にたどっていく」挙動です（プロジェクト内で自然に効く）。([Prettier][5])

おすすめはまずこれ👇（迷いが出やすいのは行の長さだけなので）

**`.prettierrc`**

```json
{
  "printWidth": 100
}
```

## よく触るオプション（必要になったら）🧩

* `"singleQuote": true`（`'` に寄せたい）
* `"semi": true/false`（セミコロン派閥）
* `"trailingComma": "all"`（末尾カンマ）

※ただし、増やすほど「好み戦争」になりがちなので、**最小が正義**です😇✨

---

## 4) `.prettierignore` で“触っちゃダメなもの”を除外🧯📄

`.prettierignore` は **gitignore形式**で書けます。([Prettier][6])
しかも Prettier は **`node_modules` をデフォで無視**し、さらに **`.gitignore` も参照**します。([Prettier][6])

**`.prettierignore`（例）**

```txt
## build成果物
dist
build
coverage

## フレームワーク系の生成物
.next
.turbo

## 生成されたファイルや巨大ファイルがあるならここに
## *.min.js
```

> これを入れておくと、`prettier . --write` が怖くなくなるのが大きいです😋✨([Prettier][6])

---

## 5) “2コマンド”を用意：整形する / 整形されてるか確認する 🧰✅

**`package.json`**

```json
{
  "scripts": {
    "format": "prettier . --write",
    "format:check": "prettier . --check"
  }
}
```

* `npm run format`：全部整形✨
* `npm run format:check`：差分が出るかチェック（CI向け）✅([Prettier][7])

---

## 6) VS Code：保存したら勝手に全部済む 💾✨（ここが本番！）

## 6-1) 拡張機能はこれ

VS Codeの「Prettier - Code formatter」（拡張）を使います。([marketplace.visualstudio.com][8])
（古い/非公式っぽい拡張もあるので、名前が同じでも注意⚠️）([marketplace.visualstudio.com][9])

## 6-2) “デフォルトフォーマッタ”を Prettier にする 🎯

VS Codeには **`editor.defaultFormatter`** という仕組みがあり、「複数フォーマッタがいる時にどれを使うか」を決められます。([code.visualstudio.com][10])
GUIでも「Configure Default Formatter…」で選べます。([code.visualstudio.com][11])

**`settings.json`（おすすめ）**

```json
{
  "editor.formatOnSave": true,

  "[javascript]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[typescript]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[typescriptreact]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[json]": { "editor.defaultFormatter": "esbenp.prettier-vscode" }
}
```

* 保存時フォーマットは `editor.formatOnSave` でON。([code.visualstudio.com][12])
* 言語ごとに設定すると「他の言語は別のフォーマッタ」も両立できます🙂✨

---

## 7) ESLintとケンカしない（超重要）⚔️➡️🤝

Prettier公式は **衝突するESLintルールをオフにするために `eslint-config-prettier` を使う**のを推しています。([Prettier][1])
逆に **“PrettierをESLintのルールとして動かす系（eslint-plugin-prettier）”は基本おすすめしない**（遅い・赤線だらけ・壊れやすい）とも書かれています。([Prettier][1])

## Flat Config（ESLint v9系）での入れ方（典型）🧩

**`eslint.config.js`** の最後に足すだけ：

```js
import eslintConfigPrettier from "eslint-config-prettier";

export default [
  // ...（あなたの既存の設定たち）

  // ✅ いちばん最後に置く！
  eslintConfigPrettier,
];
```

---

## 8) Docker/Compose運用の小ワザ 🐳🖱️

フォーマットは「どこで走らせてもOK」だけど、運用がラクなのはこのどちらか👇

* **A. 普段どおり `npm run format`**（ホスト側で）
* **B. コンテナ内で `npm run format`**（依存がコンテナにあるなら）

たとえばコンテナ派なら：

```bash
docker compose exec app npm run format
docker compose exec app npm run format:check
```

“いつも同じ場所で走る”が正義です😄✨

---

## 9) AIで爆速セットアップするプロンプト例 🤖⚡

## 目的：差分が小さく、レビューしやすい導入にする👀

使うときは「**変更していいファイル**」を縛るのがコツ！

```txt
次のファイルだけ変更して、Prettier導入の最小構成を作って：
- package.json（scripts追加：format / format:check）
- .prettierrc（まず printWidth 100 だけ）
- .prettierignore（dist, build, coverage, .next, .turbo など）
- eslint.config.js（eslint-config-prettier を最後に追加）

出力は「変更後のファイル全文」ではなく、差分が分かるようにファイルごとに提示して。
```

👉 AIに全部やらせてOKだけど、**最終的に人間が“差分”を見る**のが安全運転です🙂🛡️

---

## 10) ミニ課題（10分）⏱️📚

1. わざと汚いコードを1ファイル作る（インデントガタガタ、改行も適当）
2. `npm run format:check` を実行 → warn が出るのを確認✅
3. `npm run format` を実行 → 自動で直るのを確認✨
4. `git diff` を見て「見た目だけ変わってる」ことを確認👀

---

## 11) よくある詰まり集（ここだけ読めば助かる）🧯😵‍💫

## Q1. 保存しても整形されない😭

* Prettier拡張が入ってる？([marketplace.visualstudio.com][8])
* デフォルトフォーマッタが別の拡張になってない？（`editor.defaultFormatter`）([code.visualstudio.com][10])
* `editor.formatOnSave` がON？([code.visualstudio.com][12])

## Q2. ESLintが「Prettierと違う」って怒る😡

* `eslint-config-prettier` を入れて、**最後**に置く！([Prettier][1])
* “eslint-plugin-prettier” 方式にしてるなら、一旦やめるのが早い（遅い＆うるさい）([Prettier][1])

## Q3. 生成物まで整形されて重い🐢

* `.prettierignore` を置く（そして `prettier . --write` で全体にかける）([Prettier][6])
* `.gitignore` も参照されるのを利用する([Prettier][6])

## Q4. ちょいセキュリティ注意：依存パッケージ事故🧨

過去に **`eslint-config-prettier` に悪意あるバージョンが混入**した事例があり、**Windowsを狙う挙動**が報告されています。([GitHub][13])
対策は堅くてカンタン👇

* lockファイルをコミットして、CIは `npm ci`
* 変なバージョンを固定しない（怪しい指定を避ける）
* `npm audit` を習慣にする🙂🔒

---

次の第25章では、ここで作った Prettier を **「保存したら ESLint の自動修正も走る」** ところまで“完全自動化”していきます 💾✨🧹

[1]: https://prettier.io/docs/integrating-with-linters "Integrating with Linters · Prettier"
[2]: https://www.npmjs.com/package/prettier?utm_source=chatgpt.com "prettier"
[3]: https://prettier.io/blog/2026/01/14/3.8.0?utm_source=chatgpt.com "Prettier 3.8: Support for Angular v21.1"
[4]: https://prettier.io/docs/install?utm_source=chatgpt.com "Install · Prettier"
[5]: https://prettier.io/docs/configuration?utm_source=chatgpt.com "Configuration File"
[6]: https://prettier.io/docs/ignore "Ignoring Code · Prettier"
[7]: https://prettier.io/docs/cli?utm_source=chatgpt.com "CLI"
[8]: https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode&utm_source=chatgpt.com "Prettier - Code formatter"
[9]: https://marketplace.visualstudio.com/items?itemName=Prettier.prettier-vscode&utm_source=chatgpt.com "Prettier - Code formatter (Deprecated)"
[10]: https://code.visualstudio.com/updates/v1_33?utm_source=chatgpt.com "March 2019 (version 1.33)"
[11]: https://code.visualstudio.com/docs/python/formatting?utm_source=chatgpt.com "Formatting Python in VS Code"
[12]: https://code.visualstudio.com/docs/editing/codebasics?utm_source=chatgpt.com "Basic editing"
[13]: https://github.com/advisories/GHSA-f29h-pxvx-f335?utm_source=chatgpt.com "eslint-config-prettier, eslint-plugin-prettier, synckit, @pkgr ..."
