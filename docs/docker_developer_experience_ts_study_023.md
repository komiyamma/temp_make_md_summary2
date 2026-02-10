# 第23章：TypeScript向けの王道セットを入れる🧠✨

この章のゴールはシンプル！
**「TSコードを書いたら、ESLintが“いい感じに”怒ってくれる状態」**を最短で作ります😎🧹
（そして後半で“型情報ありLint”に育てられるよう、道筋も用意するよ🛣️✨）

---

## 1) 2026/02の最新事情（ここ大事）🧠⚡

* **ESLintはv9からFlat Configが標準**になってます（`eslint.config.*`方式）([eslint.org][1])
* さらに、**ESLint v10.0.0 が 2026-02-06 にリリース**され、`eslintrc`は完全に削除されました🧨（`.eslintrc.*` / `.eslintignore` が効かない）([eslint.org][2])
* ただし！**typescript-eslint（TS向けESLintプラグイン群）の公式サポート範囲は “ESLint v9まで” と明記**されています（少なくとも 2026-02-10 時点の公式ページ表記）([typescript-eslint.io][3])

👉 なので現実的には、今この章を安定させるなら
**「ESLint v9系 + typescript-eslint v8系」**が“王道の安全運用”です✅
（ESLint v10に上げたい場合は、typescript-eslint側の対応状況を見てからが安心😇）

---

## 2) まずは最短で導入する（クイックスタート）🚀🧩

## 2-1. 必要パッケージを入れる📦✨

公式の最短セットはこれ👇（そのままOK）([typescript-eslint.io][4])

```bash
npm install --save-dev eslint @eslint/js typescript typescript-eslint
```

> 参考：typescript-eslint は週次で latest を出してるタイプなので、ロックファイル（package-lock / pnpm-lock / yarn.lock）を必ずコミットしておくと安心だよ🧷✨ ([typescript-eslint.io][5])

---

## 2-2. `eslint.config.mjs` を作る📝✨

公式の最短テンプレはこれ👇（まずはコピペでOK）([typescript-eslint.io][4])

```js
// @ts-check

import eslint from '@eslint/js';
import { defineConfig } from 'eslint/config';
import tseslint from 'typescript-eslint';

export default defineConfig(
  eslint.configs.recommended,
  tseslint.configs.recommended,
);
```

これで **TSコードに対して「まず必要な注意」が入る**ようになります🧠✨

---

## 3) “王道セット”として最低限だけ現場寄せする🧹🔧

ここからが第23章のメイン！
クイックスタートを「実戦で困らない形」にちょい足しします😊✨

## 3-1. まずは “生成物はLintしない” ようにする（超重要）🗑️🚫

ESLint v10 では `.eslintignore` が効かないので、**Flat Config内で ignores を持つのが安定**です([eslint.org][2])
（v9でもこのやり方はOK🙆‍♂️）

```js
// @ts-check

import eslint from '@eslint/js';
import { defineConfig } from 'eslint/config';
import tseslint from 'typescript-eslint';

export default defineConfig(
  {
    ignores: [
      '**/node_modules/**',
      '**/dist/**',
      '**/build/**',
      '**/coverage/**',
    ],
  },
  eslint.configs.recommended,
  tseslint.configs.recommended,
);
```

> Flat Config の ignore は「`dist`」じゃなくて **`**/dist/**` みたいに書く**のがコツだよ🧠（パターンの挙動が違う）([eslint.org][1])

---

## 3-2. コマンドを用意する（迷いゼロ）🧰✨

`package.json` にこれを足すだけ👇

```json
{
  "scripts": {
    "lint": "eslint .",
    "lint:fix": "eslint . --fix"
  }
}
```

* `lint`：チェックする👀
* `lint:fix`：直せるものは自動修正してくれる🪄✨

---

## 3-3. 実行してみる（成功体験）✅🎉

```bash
npm run lint
```

Dockerの中で動かしてるなら、だいたいこんな感じ👇（サービス名は自分の構成に合わせてね😉）

```bash
docker compose exec app npm run lint
```

---

## 4) “型情報ありLint”は後半で育てる🌱🧪（段階導入マップ）

ここが設計のコツ！いきなり強くしない😌✨
まずは **`recommended`** で「基本の事故」を潰す → 慣れたら強化💪

typescript-eslint の共有設定はこんな階段になってます🪜✨([typescript-eslint.io][6])

* `recommended`（まずここ👍）
* `recommendedTypeChecked`（型情報ありLintの入口🧠）
* `strictTypeChecked`（TS熟練者が多いなら…って感じ🔥）([typescript-eslint.io][6])
* `stylistic` / `stylisticTypeChecked`（見た目系。整形はPrettier等に任せるのが推奨）([typescript-eslint.io][6])

## 4-1. 次の章以降でこう育てるイメージ（予告）👀✨

型情報ありLintは **`parserOptions.projectService` が推奨**になっています（v8以降の流れ）([typescript-eslint.io][7])

たとえば、将来的にこういう方向👇（今すぐやらなくてOK！）

```js
export default defineConfig(
  eslint.configs.recommended,
  tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
      },
    },
  },
);
```

---

## 5) よくある詰まりポイント（先回り）🧯😅

## 詰まり1：ESLint v10に上げたら `.eslintignore` が効かない💥

→ **Flat Configの `ignores` に寄せる**（上でやったやつ）([eslint.org][2])

## 詰まり2：ESLint v10 + typescript-eslint で依存関係が微妙🌀

→ 2026-02-10時点の公式表記だと、typescript-eslint は **ESLint v9まで**サポート([typescript-eslint.io][3])
安定運用したいなら **ESLint v9系に揃える**のが無難👍
（逆に “新しいの試すぜ！” のときは、CIでしっかり検証してからね😎🧪）

## 詰まり3：型情報ありLintを入れたら「tsconfigに含まれてない」系で落ちる😵

→ project service は **最寄りの tsconfig がそのファイルを include してないと怒る**ことがあるよ([typescript-eslint.io][7])
対策はだいたい3つ👇

* lintしたいなら：`tsconfig.json` の `include` に入れる
* lintしたくないなら：ESLintでignoreする
* 例外的に lintしたいなら：`allowDefaultProject` を検討（後半で扱うと安全）([typescript-eslint.io][7])

---

## 6) ミニ課題（10分）⏱️📘

1. いまの設定で `npm run lint` を通す✅
2. `src/demo.ts` を作って、わざとミスを入れる😈

   * 使ってない変数を作る
   * `any` を入れる
   * `console.log` を残す
3. ESLintがどんな注意を出すか見て、「なるほど〜😳」ってなる✨
4. `npm run lint:fix` を試して「自動修正できる系」を体感する🪄

---

## 7) AIで時短（でも事故らない）🤖✨

## 使えるお願いテンプレ（コピペOK）📝

* 「Flat Configのまま、TS向けの最小ESLint構成を作って。`dist` と `coverage` は無視して。`lint` と `lint:fix` の scripts も用意して」
* 「`_` で始まる未使用変数は許可したい。eslint.config.mjs の差分だけ提案して」

## 事故らないコツ🧯

AIが出した設定は、**いきなり丸ごと置換しない**で
✅ 1行ずつ意味を確認 → ✅ lint実行 → ✅ git diffで確認
この順でいけば安全だよ😎✨

---

次の章（Prettier）に進むと、**「見た目はPrettier、危険検知はESLint」**の黄金分離が完成して、気持ちよさが一気に跳ね上がるよ〜🧹✨

[1]: https://eslint.org/docs/latest/use/configure/migration-guide "Configuration Migration Guide - ESLint - Pluggable JavaScript Linter"
[2]: https://eslint.org/blog/2026/02/eslint-v10.0.0-released/ "ESLint v10.0.0 released - ESLint - Pluggable JavaScript Linter"
[3]: https://typescript-eslint.io/users/dependency-versions "Dependency Versions | typescript-eslint"
[4]: https://typescript-eslint.io/getting-started/ "Getting Started | typescript-eslint"
[5]: https://typescript-eslint.io/users/releases/?utm_source=chatgpt.com "Releases"
[6]: https://typescript-eslint.io/users/configs/ "Shared Configs | typescript-eslint"
[7]: https://typescript-eslint.io/troubleshooting/typed-linting "Typed Linting | typescript-eslint"
