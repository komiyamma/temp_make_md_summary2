# 第24章：ESM/CJSで詰まない最低ライン🧯📦

この章はズバリ、**「`import` でコケた時に、原因を5分で切り分けられる」**状態を作ります😆✨
（Nodeは v24 が Active LTS、v25がCurrent、v22がMaintenance LTS という扱いです）([Node.js][1])
（TypeScript は npm の Latest が 5.9.3 です）([npm][2])

---

## 0) まず結論：詰まないための“3つの最低ライン”✅✅✅

### ✅ ルール1：Nodeには「2つの読み込み方式」がある

* **CJS**（古参）：`require()` / `module.exports`
* **ESM**（標準）：`import` / `export`
  Nodeはこの2つを持ってて、**どっちとして解釈するか**が問題の根っこです。([Node.js][3])

### ✅ ルール2：NodeがESM/CJSを決める“スイッチ”はこれ

* **拡張子**：`.mjs`（ESM） / `.cjs`（CJS）
* **package.json の `"type"`**：`"module"`（基本ESM） or `"commonjs"`（基本CJS）([Node.js][3])

### ✅ ルール3：TSは「Nodeのルールに合わせる設定」にする

Nodeで動かす前提なら、TS側は基本これで迷子になりにくいです👇

* `compilerOptions.module = "nodenext"`
* `compilerOptions.moduleResolution = "nodenext"`
  （TS公式も「現代Nodeなら nodenext が本命」寄りの説明です）([TypeScript][4])

---

## 1) Nodeの“判定ルール”を30秒で理解しよう⏱️🧠

### 🧩 package.json の `"type"` が効く範囲

* `"type": "module"` のプロジェクトでは、**`.js` は基本 ESM**扱い
  → でも **`.cjs` にすると強制的にCJS**にできます([Node.js][5])
* `"type": "commonjs"` のプロジェクトでは、**`.js` は基本 CJS**扱い
  → でも **`.mjs` にすると強制的にESM**にできます([Node.js][5])

### 🧠 ここだけ覚えると強い

* 「`"type": "module"` を付けたら、**requireが突然死しやすくなる**」
* 「`"type": "commonjs"` のままだと、**ESM専用ライブラリで死にやすくなる**」
* 「混ぜたい時は `.cjs` / `.mjs` が“非常口”」🚪✨([Node.js][5])

---

## 2) “よくある死亡ログ”→ 原因 → 即復帰の最短ルート🚑💨

ここは超重要なので、エラー文ベースでいきます👇

### 💥 A) `Cannot use import statement outside a module`

**原因あるある**

* Nodeがそのファイルを **CJSとして解釈**してる（＝ESM扱いになってない）

**最短解決**

* ① `package.json` に `"type": "module"` を入れる
* ② もしくは拡張子を `.mjs` にする
  （Nodeはこれらを“ESMの明示マーカー”として扱います）([Node.js][3])

---

### 💥 B) `ReferenceError: require is not defined in ES module scope`

**原因あるある**

* 逆です！あなたのプロジェクトが **ESM扱い**になってるのに、CJSの `require()` を呼んでる

**最短解決**

* ① `import` に書き換える
* ② どうしてもそのファイルだけCJSで行きたいなら **そのファイルを `.cjs` にする**（非常口）([Node.js][5])

---

### 💥 C) `Error [ERR_REQUIRE_ESM]: Must use import to load ES Module`

**原因あるある**

* CJS（`require`）で **ESM専用の依存**を読もうとしてる

**最短解決（初心者向け）**

* ① プロジェクトをESM寄せ（`"type": "module"`）にするのが一番ラク
* ② もしくはCJS側で **動的import**に逃げる（次の節で例あり）
  （CJS/ESMの混在が典型原因です）([Node.js][3])

---

### 💥 D) `Error [ERR_MODULE_NOT_FOUND]: Cannot find module ...`

**原因あるある（ESMで多い）**

* **相対importで拡張子を書いてない**（CJSのノリが残ってる）

**最短解決**

* ESMでは基本こう書く👇
  `import { x } from "./util.js";`
  TSでも「Nodeで動かす前提」ならこの書き方が安全です（後でセットで説明します）✨

---

## 3) 第24章の“推奨テンプレ”（ESM一本で勝つ）🏆✨

「最初は混ぜない」＝最速で勝てます😆🔥
ここでは **TS → dist に吐いて Nodeで実行**の王道ルートで作ります。

### 📁 構成

```text
myapp/
  src/
    index.ts
    util.ts
  package.json
  tsconfig.json
```

### ✅ package.json（ESM固定）

```json
{
  "name": "myapp",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js"
  },
  "devDependencies": {
    "typescript": "^5.9.3"
  }
}
```

* `"type": "module"` が **ESMスイッチ**です([Node.js][3])
* TS最新版は 5.9.3 が Latest 表示です([npm][2])

### ✅ tsconfig.json（Node向けの最小安全セット）

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "nodenext",
    "moduleResolution": "nodenext",

    "rootDir": "src",
    "outDir": "dist",

    "strict": true,
    "sourceMap": true
  },
  "include": ["src"]
}
```

* `module/moduleResolution` は Nodeでの動作を意識した設定です([TypeScript][4])
* TS 5.9 では Node向け設定の説明も整理されています([TypeScript][6])

### ✅ src/util.ts

```ts
export function add(a: number, b: number) {
  return a + b;
}
```

### ✅ src/index.ts（ここがコツ！）

```ts
import { add } from "./util.js";

console.log("2 + 3 =", add(2, 3));
```

🧠 **重要ポイント**：`"./util.js"` と **.jsで書く**

* 「TSなのに .js？」ってなるけど、Nodeで実行するのは最終的に `dist/*.js` だからです👍
* `moduleResolution: "nodenext"` にすると、TSは `./util.js` を `./util.ts` にうまく結びつける方向で見てくれます（Node挙動に寄せる）([TypeScript][7])

### ▶ 実行

```bash
npm install
npm run build
npm run start
```

---

## 4) どうしても混ざる時の“非常口”2つ🚪🧯

### 非常口①：ESMプロジェクト内で「このファイルだけCJS」にする

* ESMプロジェクト（`"type":"module"`）でも、**`.cjs` にすればCJS**で動きます([Node.js][5])

例：`scripts/legacy.cjs`

```js
const fs = require("node:fs");
console.log("legacy ok", fs.existsSync("."));
```

---

### 非常口②：CJSからESM依存を読みたい → 動的 import に逃げる

CJSファイルでこう👇

```js
(async () => {
  const mod = await import("some-esm-only-lib");
  console.log(mod);
})();
```

（TS側の設定や依存の形式でさらに話が広がるので、まずはこの逃げ道を“知ってるだけ”でOKです😊）

---

## 5) ミニ診断：あなたはいまどの沼？🧠🧭

次の3問で、原因がほぼ確定します👇

1. `package.json` に `"type": "module"` ある？

* ある → ESM寄り（requireが死にやすい）
* ない/`commonjs` → CJS寄り（importが死にやすい）

2. そのファイルの拡張子は？

* `.mjs/.cjs` → 強制スイッチ中
* `.js` → `"type"` の影響を受ける

3. TSの `module/moduleResolution` は Node向け？

* `nodenext` / `node16` ならOK寄り
* `bundler` だと「バンドラなら動くけどNodeで死ぬ」コードが混ざりやすい（初心者はまず避けるのが安全）([TypeScript][8])

---

## 6) 章末ミッション（手を動かすやつ）🏋️‍♂️🔥

### ✅ ミッション1：わざとエラーを出して直す

1. `index.ts` を `import { add } from "./util";` に変える（拡張子なし）
2. build → start してエラーを確認
3. `./util.js` に戻して復帰✨

### ✅ ミッション2：ESM内で `.cjs` を動かす

1. `scripts/legacy.cjs` を作る
2. `node scripts/legacy.cjs` で動かす
   「同じプロジェクトで、非常口が使える」感覚を掴む👍([Node.js][5])

### ✅ ミッション3：説明できるようになる（口頭テスト）

* 「`"type":"module"` を入れると何が変わる？」
* 「`.mjs` と `.cjs` は何のスイッチ？」
  これを30秒で言えたら勝ちです😆🏆

---

## 7) AIに投げると爆速で直る“質問テンプレ”🤖⚡

困ったら、ログを貼ってこれを投げるのが最強です👇

* 🧯 **原因特定**

  * 「このエラーはESM/CJSどっちの解釈が原因？最短修正案を3つ出して」
* 🧰 **設定提案**

  * 「Nodeで直接実行するTSです。`module` と `moduleResolution` の最小正解を提案して」
* 🧪 **再現用ミニコード作成**

  * 「このエラーが再現する最小構成（ファイルツリー付き）を作って」

---

### 次章への“チラ見せ”👀✨

TSの例外スタックを読みやすくするなら、Nodeの `--enable-source-maps` が効きます（次の章でガッツリやると気持ちいいやつ）([Node.js][9])

---

必要ならこの第24章に合わせて、**「ESM一本テンプレ（Dockerfile/compose込み）」**も“コピペで勝てる形”に整形して出します🐳✨

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[3]: https://nodejs.org/api/esm.html?utm_source=chatgpt.com "ECMAScript modules | Node.js v25.6.0 Documentation"
[4]: https://www.typescriptlang.org/tsconfig/module?utm_source=chatgpt.com "TSConfig Option: module"
[5]: https://nodejs.org/api/packages.html?utm_source=chatgpt.com "Modules: Packages | Node.js v25.6.0 Documentation"
[6]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[7]: https://www.typescriptlang.org/tsconfig/moduleResolution.html?utm_source=chatgpt.com "TSConfig Option: moduleResolution"
[8]: https://www.typescriptlang.org/docs/handbook/modules/guides/choosing-compiler-options.html?utm_source=chatgpt.com "Documentation - Modules - Choosing Compiler Options"
[9]: https://nodejs.org/download/release/v16.16.0/docs/api/cli.html?utm_source=chatgpt.com "Command-line API | Node.js v16.16.0 Documentation"
