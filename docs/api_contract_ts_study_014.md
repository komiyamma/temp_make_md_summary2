# 第14章：npmパッケージ契約②：配布の契約（入口・型・exports）📦🧾

## この章でできるようになること🎯✨

* 「配布したら壊れた😱」を防ぐために、**入口（エントリポイント）・型・exports**を正しくそろえられる
* **ESM / CJS**の違いで起きる事故を、`package.json` の設計で回避できる
* 公開範囲（＝契約）を `exports` で “ちゃんと閉じる” ことができる🔒
* 配布前に **npm pack** で「本当に入ってる？」を確認できる✅ ([docs.npmjs.com][1])

---

## 14.1 「配布の契約」ってなに？🤝📦

npmパッケージって、**zipみたいに固めて配る**よね📦
このとき利用者が頼るのは主にこの3つ👇

1. **入口**：`import xxx from "your-lib"` したら、どのファイルが読まれる？🚪
2. **型**：TypeScriptが「その入口の `.d.ts` をどこから読む？」🟦
3. **公開範囲**：`your-lib/internal/xxx` みたいな“奥のファイル”まで勝手に読まれない？🙈

この3つがズレると、**動くのに型が無い**とか、**型はあるのに実行で死ぬ**とか、地獄が起きがち😵‍💫💥

---

## 14.2 入口の基本：`main` と `exports` の関係🚪🧩

いまのNodeでは、入口は主に `package.json` の **`main`** と **`exports`** で決まるよ📌
ポイントはこれ👇

* `main` は昔からある「メイン入口を1個だけ決める」仕組み
* `exports` は新しい仕組みで、

  * **複数の入口**を定義できる
  * **import / require で出し分け**できる（条件付き）
  * `exports` に書いてない奥のファイルは **基本インポート不可**にできる（＝契約を閉じられる）🔒
* 両方ある場合、対応Nodeでは **`exports` が優先**されるよ⚠️ ([nodejs.org][2])

さらに大事な注意👇
既存パッケージに途中から `exports` を追加すると、今まで `your-lib/dist/xxx` みたいに奥を直読みしてた人が **突然 `ERR_PACKAGE_PATH_NOT_EXPORTED`** で死ぬことがある💥（＝破壊的変更になりやすい） ([nodejs.org][2])

---

## 14.3 2026年いまの前提：Node / TypeScriptの「解決（resolution）」🧭✨

いまのNodeは「Current / LTS」がハッキリ分かれていて、2026-02時点だと **Node 24 が Active LTS、Node 22 が Maintenance LTS** になってるよ📌 ([nodejs.org][3])
（配布する側は、だいたいこの辺を狙うと安全運用しやすい💖）

TypeScript側は、パッケージの `exports` をちゃんと読むために、`tsconfig` の **`moduleResolution`** が重要だよ🟦✨

* `node16` / `nodenext`：Nodeの現代的な解決ルール
* `bundler`：バンドラ向け（`exports` / `imports` をサポートしつつ、相対パスの拡張子要求がゆるい） ([typescriptlang.org][4])

---

## 14.4 型の入口：`types` と `exports` の「types条件」🟦🧠

「実行の入口」と「型の入口」がズレやすいのがnpmの罠ポイント😇💣

TypeScriptは `exports` の中で、**型のための条件 `"types"`** を扱えるよ✨
そして超重要ルール👇

* **`exports` の条件は上から順にマッチ**していくイメージ
* TypeScript公式でも **`"types"` は `exports` の先頭に置くのが大事**って言ってるよ📌 ([typescriptlang.org][5])

さらに、ここも落とし穴👇
TypeScriptは「`exports` を見て解決する」挙動が強くなっていて、`typesVersions` より `exports` を優先する変更も入ってるよ（影響あるなら `exports` 側で `types@...` 条件を使う必要が出る場合あり）⚠️ ([GitHub][6])

---

## 14.5 まずは鉄板：シンプルな“ESMのみ”パッケージ例🌿📦

「まず動けばOK！」な最小構成からいこう😊✨
（ESMのみなら事故が少なめ🌈）

**フォルダ例📁**

* `src/`（TSのソース）
* `dist/`（ビルド成果物）

  * `index.js`
  * `index.d.ts`

**package.json例（ESMのみ）**

```json
{
  "name": "my-lib",
  "version": "1.0.0",
  "type": "module",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "default": "./dist/index.js"
    }
  },
  "types": "./dist/index.d.ts",
  "files": ["dist", "README.md", "LICENSE"]
}
```

✅ ここで守ってる契約

* 利用者が `import ... from "my-lib"` したら `dist/index.js` を読む
* TSは `dist/index.d.ts` を読む
* `exports` に書いてない奥ファイルは基本 “公開しない” 🔒 ([nodejs.org][2])

---

## 14.6 次に鉄板：“ESM/CJS両対応（デュアル）”パッケージ例⚔️📦

現場だと「require使う人もいる」問題があるので、両対応したくなることが多いよね🙂‍↕️
その場合は **条件付きexports** を使うのが定番✨ ([nodejs.org][2])

**フォルダ例📁**

* `dist/esm/index.js`
* `dist/cjs/index.cjs`
* `dist/types/index.d.ts`

**package.json例（デュアル）**

```json
{
  "name": "my-lib",
  "version": "1.0.0",
  "exports": {
    ".": {
      "types": "./dist/types/index.d.ts",
      "import": "./dist/esm/index.js",
      "require": "./dist/cjs/index.cjs",
      "default": "./dist/esm/index.js"
    },
    "./package.json": "./package.json"
  },
  "types": "./dist/types/index.d.ts",
  "files": ["dist", "README.md", "LICENSE"]
}
```

ポイント💡

* `import` と `require` を分けると、利用者の環境で “自然に” 正しい方が読まれる🎁
* `"default"` は最後の保険（フォールバック）🧯（Node側でも “defaultは汎用フォールバック” として扱われる） ([nodejs.org][2])
* `./package.json` を export すると、必要なツールが参照できて事故が減ることがある（ただし公開するかは方針次第） ([nodejs.org][2])

---

## 14.7 “奥を読まれる事故”を防ぐ：Subpath exportsで公開範囲を固定🔒🧱

たとえば利用者がこう書いちゃうやつ👇

* `import { x } from "my-lib/dist/internal/x.js"` 😇

これを許すと、将来ディレクトリ構造を整理しただけで **破壊的変更**になりやすい💥
`exports` を使うと「ここだけが公開だよ」を宣言できる✨ ([nodejs.org][2])

**例：`my-lib/feature` だけ追加で公開する**

```json
{
  "exports": {
    ".": { "types": "./dist/types/index.d.ts", "default": "./dist/index.js" },
    "./feature": {
      "types": "./dist/types/feature.d.ts",
      "default": "./dist/feature.js"
    }
  }
}
```

これで利用者は `my-lib/feature` まではOK、奥の `dist/...` は基本NGになる（契約が固まる）🔒✨ ([nodejs.org][2])

---

## 14.8 配布で起きがちな事故あるある😱💥（と対策）

## 事故①：型ファイルが入ってない

* `dist/index.d.ts` を生成したつもりでも、`files` / `.npmignore` のせいで **パッケージに入ってない**やつ😇
  ✅ 対策：**`npm pack` で中身を確認**する！ ([docs.npmjs.com][1])

## 事故②：実行入口と型入口がズレる

* JSは `exports.import` を読んでるのに、型は古い `types` を読んでる…みたいなズレ
  ✅ 対策：`exports` の中に `"types"` を置いて、**実行と同じ分岐で型も分岐**させる🟦✨ ([typescriptlang.org][5])

## 事故③：利用者の `moduleResolution` が古くて exports を読めない

* 利用者が古い設定だと、`exports` 前提のパッケージで「型が見つからない」って言われがち
  ✅ 対策：現代モード（`node16`/`nodenext`/`bundler`）が `exports` をサポートすることを理解しておく🧠 ([typescriptlang.org][4])

---

## 14.9 配布チェックリスト✅📋（そのままコピペOK）

**A. 入口（実行）🚪**

* [ ] `exports["."]` がある
* [ ] `import` / `require` を分けるなら両方のファイルが存在する
* [ ] `exports` のパスは **必ず `./` から始まってる** ([nodejs.org][2])

**B. 入口（型）🟦**

* [ ] `exports["."]` の中に `"types"` がある
* [ ] `"types"` は **条件の先頭**にある ([typescriptlang.org][5])
* [ ] `dist/**/*.d.ts` がパッケージに入る設定になってる

**C. 公開範囲🔒**

* [ ] 奥ディレクトリを直接読まれない設計（= `exports` で閉じてる） ([nodejs.org][2])
* [ ] もし途中から `exports` を入れるなら、過去の入口を全部 export して破壊を避ける（or MAJOR上げる） ([nodejs.org][2])

**D. 配布前の現物確認📦**

* [ ] `npm pack` を実行して、tarballの中身を確認した ([docs.npmjs.com][1])
* [ ] 別フォルダで `npm i ../my-lib` して `import` / `require` を試した

---

## 14.10 ミニ演習📝✨（15〜30分）

## 演習1：配布設計ゲーム🎮📦

「次のどれを公開する？」を決めて `exports` を書いてみよう✍️

* `my-lib`（メイン）
* `my-lib/feature`（便利機能）
* `my-lib/internal/*`（これは公開しない🙈）

ゴール🎯：`internal` を読もうとしたらエラーになる設計にする🔒

## 演習2：事故をわざと起こして直す🧯

1. `files` から `dist` を外す（わざと）
2. `npm pack` して中身を見る
3. 「型が消えた😱」を確認してから元に戻す
   → “確認できる人” が強い💪✨ ([docs.npmjs.com][1])

---

## 14.11 AI活用プロンプト集🧠🤖✨

そのまま貼って使ってOKだよ🌸

* 「このフォルダ構成（貼る）で、ESMのみの `package.json exports` を作って。型も含めて、事故りにくくして」
* 「デュアル（import/require）対応にしたい。`exports` の条件順と `types` の置き方も含めて提案して」 ([typescriptlang.org][5])
* 「`npm pack` の結果に `dist/*.d.ts` が入ってるかチェックする手順を、コマンド付きで短く」 ([docs.npmjs.com][1])
* 「既存利用者が `my-lib/dist/*` を使ってるかもしれない。`exports` 導入が破壊的変更になる可能性をレビューして、移行案も出して」 ([nodejs.org][2])

---

## おまけ：いまのTypeScriptの“現役ライン”メモ📝🟦

TypeScriptは **5.9系**が安定版として公開されていて、将来の大型アップデート（6.0/7.0）に向けた話も公式ブログで出てるよ📣 ([Microsoft for Developers][7])

[1]: https://docs.npmjs.com/cli/v9/using-npm/developers/ "developers | npm Docs"
[2]: https://nodejs.org/api/packages.html "Modules: Packages | Node.js v25.6.0 Documentation"
[3]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[4]: https://www.typescriptlang.org/tsconfig/moduleResolution.html "TypeScript: TSConfig Option: moduleResolution"
[5]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-7.html?utm_source=chatgpt.com "Documentation - TypeScript 4.7"
[6]: https://github.com/microsoft/TypeScript/wiki/Breaking-Changes?utm_source=chatgpt.com "Breaking Changes · microsoft/TypeScript Wiki"
[7]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
