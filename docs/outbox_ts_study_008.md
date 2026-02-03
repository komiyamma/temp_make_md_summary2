# 第8章：Windows＋VS Codeで開発準備（TypeScript最小構成）🪟💻✨

## この章でできるようになること 🎯

* 「実行 ▶️ / 型チェック ✅ / テスト 🧪 / ビルド 🏗️」がワンコマンドで回る土台を作る
* `src / tests / scripts` の“迷子になりにくい”フォルダ構成を固定する 📁✨
* 未来のOutbox実装に備えて、最小のTypeScript設定（Node向け）を入れる 🧩
* AI（GitHub Copilot / OpenAI Codex）で雛形を爆速生成するコツを覚える 🤖💨

---

## 0) いまの“基準バージョン”の目安 🧭✨

* Node.js：現時点のActive LTSは v24 系（Current は v25 系）📌 ([Node.js][1])
* TypeScript：5.9 系が安定版として使われているよ 📌 ([TypeScript][2])
* VS Code：直近の安定版リリースは 1.108 系（2026-01-08 リリース）📌 ([Visual Studio Code][3])

> バージョン数字は“絶対暗記”じゃなくてOKだよ😊
> 「LTSを使う」「設定を固定する（浮かせない）」のほうが100倍大事！💪✨

---

## 1) Node.js を入れて、動作確認する 🧩⚙️

Node.js は **LTS** を入れるのが安心（長くサポートされる）だよ🫶 ([Node.js][1])

### ✅ 動作確認（PowerShell）

```txt
node -v
npm -v
```

---

## 2) pnpm を “Corepack” で有効化する 🧺✨

`pnpm` は速くて軽いパッケージマネージャーだよ🚀（この教材ではpnpmで統一するね）

Node には `corepack` が同梱される期間があり、**corepack enable** で pnpm を使えるようにできるよ🧡 ([GitHub][4])

### ✅ 有効化（PowerShell）

```txt
corepack enable
```

### ✅ プロジェクトで使う pnpm の“世代”を固定（おすすめ）📌

```txt
corepack use pnpm@latest-10
```

> 固定する理由：チームや未来の自分のPCでも、挙動がズレにくいからだよ🙂‍↕️✨ ([pnpm.io][5])

---

## 3) プロジェクトを作る（最小構成）📦🧪📁

今回は学習用に、まず **1プロジェクト** でシンプルにいくよ🍀

### ✅ 作成（PowerShell）

```txt
mkdir outbox-lab
cd outbox-lab
pnpm init
```

---

## 4) 必要パッケージを入れる（TypeScript + 実行 + テスト）📦✨

* TypeScript：型チェック＆ビルド 🧠
* tsx：TSをサクッと実行（ただし **型チェックはしない**）⚡
* Vitest：テスト 🧪
* @types/node：Nodeの型 🧩

`tsx` は「そのまま実行できる」けど「型チェックしない」ので、**`tsc` で型チェックしてから実行**が安全だよ✅ ([Node.js][6])

### ✅ インストール

```txt
pnpm add -D typescript tsx vitest @types/node
```

---

## 5) フォルダ構成を作る（迷子防止）🧭📁

```txt
mkdir src tests scripts
```

<!-- img: outbox_ts_study_008_structure.png -->
この教材では、ざっくりこう役割分担するよ👇

* `src/`：アプリ本体（後で Outbox 実装が入る）📦
* `tests/`：テスト（仕様を守れてる？を確認）🧪
* `scripts/`：開発用スクリプト（DB初期化、Outbox掃除…など）🧹

---

## 6) TypeScript 設定（Node向け最小 tsconfig）🧠⚙️

TypeScript 5.9 では、Node向け設定に **`module: "node20"`** みたいな“安定オプション”が用意されてるよ📌（挙動がフラつきにくい） ([TypeScript][2])

プロジェクト直下に `tsconfig.json` を作って、これを貼ってね👇

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "node20",
    "moduleResolution": "node20",

    "rootDir": "src",
    "outDir": "dist",

    "strict": true,
    "noUncheckedIndexedAccess": true,

    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src", "tests", "scripts"]
}
```

> ここは「まず動く」「学習が進む」を優先した最小セットだよ🙂✨
> もっと堅くするのは、Outboxが動き始めてからでOK！🪜

---

## 7) package.json に “いつもの流れ” を作る 🔁✨

`package.json` の `"scripts"` を、こうするよ👇（コピペOK）

```json
{
  "scripts": {
    "dev": "tsx watch src/main.ts",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "build": "tsc",
    "start": "node dist/main.js"
  }
}
```

* `dev`：開発中は watch で自動再実行 ▶️
* `typecheck`：型だけチェック ✅（**tsx は型チェックしない**から必須！） ([Node.js][6])
* `test`：テスト一発 🧪
* `build` → `start`：配布/本番っぽい動き 🏗️▶️

---

## 8) “まず動く” main.ts を置く ▶️😊

`src/main.ts` を作って、これを貼ってね👇

```ts
console.log("Outbox Lab: ready! 📦✨");
```

### ✅ 実行してみよう

```txt
pnpm run dev
```

---

## 9) テストの最小セット（Vitest）🧪✨

Vitest は 4.0 が公開されてて、4.x 系で運用されてるよ📌 ([vitest.dev][7])

`tests/smoke.test.ts` を作って、これ👇

```ts
import { describe, expect, test } from "vitest";

describe("smoke", () => {
  test("runs", () => {
    expect(1 + 1).toBe(2);
  });
});
```

### ✅ テスト実行

```txt
pnpm run test
```

---

## 10) VS Code 側の“快適スイッチ” 🔧💖

### ✅ 保存したら自動でサクッと整える（おすすめ）✨

`.vscode/settings.json` を作って👇

```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": "always"
  }
}
```

> まだESLint/Prettierを入れてなくても、import整理だけでも気持ちいいよ🥰✨
> ルール追加は後でOK！（詰め込み防止🧊）

---

## 11) “AIで雛形生成” テンプレ（コピペ用）🤖✨

### 11-1) フォルダ構成＆scripts を整えてもらう 📁

```txt
TypeScript(Node)の学習用プロジェクトです。
src/tests/scripts の構成で、
- package.json scripts（dev/typecheck/test/build/start）
- tsconfig.json（Node向け、strict）
を“初心者が迷子にならない最小構成”で提案してください。
説明は短く、まずコピペできる完成形を出してください。
```

### 11-2) “次の章で作る題材”の雛形だけ先に作らせる 🛒📦

```txt
次の章で Outbox パターンを学びます。
注文（Order）を題材にしたいので、
src/ に Order の型と簡単な作成関数（createOrder）だけ作ってください。
まだDBやOutboxは入れません。テストも1本だけ付けてください。
```

### 11-3) 詰め込み防止のレビューをさせる 🧊👀

```txt
このプロジェクトの構成をレビューして、
「初心者が混乱しやすいポイント」を3つだけ指摘して、
それぞれに対して“最小の改善”を提案してください。
大げさなアーキ変更はしないでください。
```

---

## 12) つまづきポイント集（先に回避✨）🧯

* **tsx は型チェックしない** → `pnpm run typecheck` を必ず使う✅ ([Node.js][6])
* **テストが動かない** → まず `tests/smoke.test.ts` の超ミニで確認🧪
* **ビルド成果物が見つからない** → `dist/` に出る（`outDir`）📁

---

## 13) この章のチェックリスト ✅📦

* `pnpm run dev` で `Outbox Lab: ready!` が出る ▶️✨
* `pnpm run typecheck` が成功する ✅
* `pnpm run test` が成功する 🧪
* `pnpm run build` → `pnpm run start` が通る 🏗️▶️

---

## 次章へのつなぎ（超ミニ予告）📨✨

次は、いよいよ **Outboxテーブル（学習用の最小カラム）** を設計していくよ📦🧾💖

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://code.visualstudio.com/updates?utm_source=chatgpt.com "December 2025 (version 1.108)"
[4]: https://github.com/nodejs/corepack?utm_source=chatgpt.com "nodejs/corepack: Package manager version ..."
[5]: https://pnpm.io/installation?utm_source=chatgpt.com "Installation | pnpm"
[6]: https://nodejs.org/en/learn/typescript/run?utm_source=chatgpt.com "Running TypeScript with a runner"
[7]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
