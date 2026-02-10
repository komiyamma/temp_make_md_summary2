# 第22章：ESLintは「Flat Config」が標準🧾✨

この章でやることはシンプルです😊
**ESLintの新しい設定方式（Flat Config）で、まず「壊れない骨組み」を作る！** そして次章で **TypeScript向けの王道セット** に育てます🪴

（Flat ConfigはESLint v9からデフォルトで、もう避けて通れない流れです🚀）([eslint.org][1])

---

## 22.1 Flat Configって何がうれしいの？🤔➡️😊

昔：`.eslintrc.*` に「extendsがいっぱい」「設定の継ぎ足し地獄」になりがち😇
今：`eslint.config.*` に **“設定オブジェクトの配列”** を並べていく方式📚

* **どのファイルにどの設定が当たるか** が明確になって混乱が減る✨
* 無視（ignore）も「設定の一部」として扱える🧹
* VS Code側もFlat Config前提に寄ってきてる🧩([marketplace.visualstudio.com][2])

---

## 22.2 まず覚える3点だけ🧠✨

### ✅ 1) 設定ファイル名は `eslint.config.*`

使える名前はこのへん👇（ルートに置く）([eslint.org][3])

* `eslint.config.js`
* `eslint.config.mjs`
* `eslint.config.cjs`
* `eslint.config.ts` / `mts` / `cts`（※追加セットアップが必要）([eslint.org][3])

### ✅ 2) 中身は「配列」

`export default [ {…}, {…} ]` みたいに、**設定を上から順に重ねる** 感じです📚([eslint.org][3])

### ✅ 3) `defineConfig()` を使うと安心

ESLint公式が用意してるヘルパーで、配列の形が崩れにくくなります👍([eslint.org][3])

---

## 22.3 最短で“動く骨組み”を作る🏗️✨

ここではまず **JS系ファイル（.js/.mjs/.cjs）だけ** をLint対象にします。
TypeScript（.ts/.tsx）は **次章でまとめて対応** するのが事故りにくいです😊🧯

### ① まず依存を入れる📦

```bash
npm i -D eslint @eslint/js globals
```

* `@eslint/js`：ESLint公式の“おすすめルールセット”を使う用🧰
* `globals`：`node` や `browser` みたいな環境のグローバル定義に使う（Flat ConfigではCLIの `--env` が使えないため）([eslint.org][4])

### ② 設定ファイルを作る（おすすめ：`.mjs`）✍️

`.mjs` だと「モジュール形式で悩む率」が下がります👍（`.js` は `package.json` の `"type":"module"` 次第で形式が変わるため）([eslint.org][3])

**eslint.config.mjs**

```js
import js from "@eslint/js";
import globals from "globals";
import { defineConfig } from "eslint/config";

export default defineConfig([
  // ✅ まず最初に：全体の無視設定（グローバルignore）
  {
    name: "global-ignores",
    ignores: ["**/node_modules/**", "**/dist/**", "**/build/**"],
  },

  // ✅ JS系だけLint（TSは次章で拡張）
  {
    name: "js-base",
    files: ["**/*.{js,cjs,mjs}"],
    plugins: { js },
    extends: ["js/recommended"],
    languageOptions: {
      globals: {
        ...globals.node,
      },
    },
    rules: {
      // お好みの軽い調整（例）
      "no-unused-vars": "warn",
    },
  },
]);
```

> ポイント：`ignores` は「それだけを書いたオブジェクト」にすると **全設定に効く“グローバルignore”** になります🧹([eslint.org][3])

### ③ スクリプトを用意（まずはJSだけLint）🧪

`package.json` に追加👇

```json
{
  "scripts": {
    "lint": "eslint .",
    "lint:fix": "eslint . --fix"
  }
}
```

実行🏃‍♂️💨

```bash
npm run lint
```

---

## 22.4 重要：`.eslintignore` はもう読まれない⚠️😵

Flat Configでは **`.eslintignore` から ignore を読み込めません**。
`ignores` に移す必要があります🧹([eslint.org][4])

しかも、パターンの意味がちょっと違います👇

* `.eslintignore` の `temp.js`：どこにあっても `temp.js` を無視
* Flat Configの `temp.js`：**設定ファイルと同じ階層の temp.js だけ**
  → だから Flat Configでは `**/temp.js` みたいに書くのが基本🧠([eslint.org][4])

さらに！
**ドットファイル（`.something.js`）がデフォルトで無視されなくなりました**😳
必要なら `ignores: ["**/.*"]` を足します🧹([eslint.org][4])

---

## 22.5 よくある詰まりポイント集🧯😅

### 詰まり①：VS CodeでESLintが効いてない気がする👻

VS CodeのESLint拡張には `eslint.useFlatConfig` という設定があります。ESLintのバージョン帯によって挙動が変わります🧩([marketplace.visualstudio.com][2])

* もし挙動が怪しいときは、ワークスペース設定で明示的にONにすると切り分けが速いです👍

### 詰まり②：`--env` とか昔のCLIオプションが効かない😵

Flat Configでは `--env` など一部のCLIフラグが非対応です。
代わりに `languageOptions.globals`（+ `globals` パッケージ）で書きます🧠([eslint.org][4])

### 詰まり③：ignoreが効いてない／効きすぎる🌀

* `ignores` は **ディレクトリを消すなら `dir/**` が基本**（`dir/` だけだと効かない）([eslint.org][3])
* `ignores` をどこに書くかで “全体に効く” か “そのブロックだけ効く” かが変わります🧹([eslint.org][3])

---

## 22.6 「どの設定が当たってる？」を一瞬で調べる🔍✨

Flat Configは「当たり判定」が分かりやすいのが強みだけど、迷ったら **Config Inspector** が最強です💪

* CLIに `--inspect-config` があり、どの設定が適用されてるか確認できます🕵️‍♂️([eslint.org][3])
* 公式の **Config Inspector（`@eslint/config-inspector`）** も紹介されています🧰([eslint.org][5])

困ったらここを使うだけで、調査時間が激減します⏳➡️😆

---

## 22.7 AI拡張で“設定づくり”を爆速にする🤖⚡

ESLint設定って「正解はあるけど、書き方がめんどい」代表です😂
だからAIをこう使うのが強いです👇

### 使い方A：今の構成に合わせた ignores を生成させる🧹

**AIに投げるテンプレ**

* 「dist/build/.turbo/.next など、一般的に除外する候補を出して」
* 「Flat Config の `ignores` に入れる形で提案して」
* 「`temp.js` みたいなパターンは `**/temp.js` に直して」

（Flat Configのignore挙動の違いがあるので、こういう依頼が効きます）([eslint.org][4])

### 使い方B：エラー文を貼って“最短の直し”だけ出してもらう🩹

**コツ**：
「原因→直し方→変更差分（パッチ形式）」で出させると安全です✅

---

## 22.8 ミニ課題🎒✨（10分）

1. `eslint.config.mjs` を作る
2. `npm run lint` が通るのを確認
3. 次のどれかを追加して、ちゃんと効くか試す

   * 例：`rules` に `"semi": "error"` を追加して、セミコロン無しのJSで怒られるか見る😆
   * 例：`ignores` に `"**/tmp/**"` を足して、そこがLint対象外になるか見る🧹

---

## 22.9 ここまでの合格チェック✅✨

* [ ] `eslint.config.*` がルートにある
* [ ] `ignores` をFlat Config側に移せた（`.eslintignore` に頼ってない）([eslint.org][4])
* [ ] `npm run lint` が通る
* [ ] 迷ったら `--inspect-config` / Config Inspector を使える気がする([eslint.org][5])

---

次章（第23章）では、この骨組みに **TypeScript向けの王道（typescript-eslint）** を合体させて、`src/**/*.ts` まで気持ちよくLintできる形にします🧠✨

[1]: https://eslint.org/blog/2025/03/flat-config-extends-define-config-global-ignores/ "Evolving flat config with extends - ESLint - Pluggable JavaScript Linter"
[2]: https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint "
        ESLint - Visual Studio Marketplace
    "
[3]: https://eslint.org/docs/latest/use/configure/configuration-files "Configuration Files - ESLint - Pluggable JavaScript Linter"
[4]: https://eslint.org/docs/latest/use/configure/migration-guide "Configuration Migration Guide - ESLint - Pluggable JavaScript Linter"
[5]: https://eslint.org/blog/2024/04/eslint-config-inspector/ "Introducing ESLint Config Inspector - ESLint - Pluggable JavaScript Linter"
