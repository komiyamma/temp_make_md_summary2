# 第8章　Windows＋VS Code＋TSのプロジェクト土台づくり🪟🧰✨（CQRS用の“迷子防止テンプレ”）

この章のゴールはこれ👇
**「Command/Query/Domain/Infrastructure を“最初から分けた形”で、すぐ動いて・すぐテストできて・すぐ整形できる」**状態を作ることだよ〜😊💕

---

## 8-1. フォルダ構成はこの形で固定しちゃおう📁✨

まずは“型”を決め打ちして迷子防止🧭✨
（あとで章が進んでも崩れにくい形！）

```text
gakushoku-cqrs/
  src/
    commands/         # 更新（Command）入口：HandlerやDTO
    queries/          # 参照（Query）入口：QueryServiceやDTO
    domain/           # 業務ルール：Entity/ValueObject/不変条件
    infrastructure/   # DB/外部API/Repository実装など
    shared/           # 共有：Result型、エラー型、ユーティリティ
    index.ts          # 起動・動作確認用（今だけ）
  tests/
  package.json
  tsconfig.json
  eslint.config.mjs
  vitest.config.ts
```

> ✅ “CQRSの境界”をフォルダで表現しておくと、コードが増えても散らかりにくいよ〜🧹✨

---

## 8-2. プロジェクトを作る（ターミナルで一気に）⚡🖥️

### ① フォルダ作成＋npm初期化📦

```bash
mkdir gakushoku-cqrs
cd gakushoku-cqrs
npm init -y
```

### ② 必要パッケージを入れる（2026の定番セット）🤖✨

* **TypeScript**：型チェック＆ビルド
* **tsx**：TSをそのまま実行＆watch（開発体験がラク）⚡
* **ESLint（Flat Config）＋typescript-eslint**：文法ミス・事故防止🚨
* **Vitest**：高速テスト🧪⚡（設定も軽い）

```bash
npm install -D typescript tsx @types/node
npm install -D eslint @eslint/js typescript-eslint
npm install -D vitest
```

補足：Node.jsはLTSを使うのが安心💡
2026年1月時点だと **v24 系が Active LTS**として案内されてるよ（v24/v22/v20 のLTSが並走）🛡️✨ ([nodejs.org][1])
（LTSはセキュリティ更新も出るので追従しやすい👍） ([nodejs.org][2])

---

## 8-3. `package.json` を“回せる形”にする🔁✨

`scripts` をこうしておくと、開発が超スムーズ💨

```json
{
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js",
    "lint": "eslint .",
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

* `dev`：保存したら自動で再実行♻️✨
* `build/start`：一応“配布できる形”も作っておく🎁
* `lint/test`：あとで品質が爆上がりする仕込み💪

---

## 8-4. `tsconfig.json` を用意する🧠🛠️

ここ、最初に決めると後で助かるよ〜😊✨
**Nodeの現代的な解決ルール**に合わせて `moduleResolution` を `nodenext` にするのが定番（TypeScript公式も node16/nodenext を“モダンNode向け”として説明してるよ） ([typescriptlang.org][3])

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "NodeNext",
    "moduleResolution": "NodeNext",

    "rootDir": "src",
    "outDir": "dist",

    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,

    "sourceMap": true,
    "declaration": false,
    "skipLibCheck": true,

    "types": ["node"]
  },
  "include": ["src", "tests"]
}
```

> 💡 もし将来 Vite など“バンドラ前提”に寄せたくなったら、`moduleResolution: "bundler"` って選択肢もあるよ（拡張子必須になりにくい、って公式に書かれてる） ([typescriptlang.org][3])
> でも今はNode寄りでOK🙆‍♀️✨（学習の道がまっすぐ！）

---

## 8-5. ESLint（Flat Config）を最小で入れる🧹🚨

`eslint.config.mjs` を作って、公式の“最短ルート”でいくよ〜✨
（typescript-eslint の Quickstart がこの形を推してる） ([typescript-eslint.io][4])

```js
// @ts-check

import eslint from "@eslint/js";
import { defineConfig } from "eslint/config";
import tseslint from "typescript-eslint";

export default defineConfig(
  eslint.configs.recommended,
  tseslint.configs.recommended
);
```

実行はこれ👇

```bash
npm run lint
```

> ✅ “まず recommended で事故を防ぐ”のが正解〜😆✨
> ルールを増やすのは、慣れてからでぜんぜんOK🙆‍♀️

---

## 8-6. Vitestで“土台テスト”を1本だけ作る🧪✨

`vitest` は設定が軽くて速いのがウリ⚡（公式も導入手順がシンプル） ([vitest.dev][5])

### ① `vitest.config.ts`

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node"
  }
});
```

### ② `tests/smoke.test.ts`

```ts
import { describe, it, expect } from "vitest";

describe("smoke", () => {
  it("project boots", () => {
    expect(1 + 1).toBe(2);
  });
});
```

実行👇

```bash
npm test
npm run test:watch
```

---

## 8-7. CQRSフォルダに“最小のダミー”を置いて動作確認🎮✨

「分けた構成で import が通るか」だけを確認するミニコードだよ〜😊

### `src/domain/Order.ts`

```ts
export type OrderId = string;

export type Order = {
  id: OrderId;
  status: "ORDERED" | "PAID";
};
```

### `src/commands/placeOrder.ts`

```ts
import type { Order } from "../domain/Order.js";

export type PlaceOrderCommand = {
  orderId: string;
};

export function placeOrder(cmd: PlaceOrderCommand): Order {
  return { id: cmd.orderId, status: "ORDERED" };
}
```

### `src/queries/getOrderList.ts`

```ts
import type { Order } from "../domain/Order.js";

export function getOrderList(): Order[] {
  return [];
}
```

### `src/index.ts`

```ts
import { placeOrder } from "./commands/placeOrder.js";
import { getOrderList } from "./queries/getOrderList.js";

const order = placeOrder({ orderId: "o-001" });
console.log("placed:", order);

const list = getOrderList();
console.log("list:", list);
```

起動👇

```bash
npm run dev
```

> 🎉 ここまで動いたら「土台完成」だよ〜！！👏✨

---

## 8-8. AI拡張の使い方（この章で効くやつ）🤖💡

### ✅ 1) フォルダ構成レビューを頼む（責務まざってない？）

例プロンプト👇
「このフォルダ構成でCQRSを進めたいです。`commands/queries/domain/infrastructure/shared` の責務が混ざってないか、改善案があれば指摘して。初心者が迷わない観点で！」

### ✅ 2) Handlerが太りそうな匂いを先に消す🚨

「このCommandの処理手順を箇条書きにして、Handlerに置くべき処理とDomainに置くべき処理を分けて提案して！」

### ✅ 3) ESLint/tsconfigの“やりすぎ”を止めてもらう🧯

「初心者向け教材なので、設定を増やしすぎたくない。今の設定で過剰なもの・不足してるものを優先度つきで教えて！」

---

## 8-9. できたかチェックリスト✅✨

* `npm run dev` が動く💨
* `npm run lint` が通る🧹
* `npm test` が通る🧪
* `src/commands` と `src/queries` が分かれている🔀
* `domain` に“業務っぽい型”が置けそうな雰囲気がある📦🙂

---

## おまけ：TypeScriptの“今”ってどうなってるの？🧠✨

2026年1月時点だと **TypeScript 5.9 系が安定ライン**として参照しやすいよ（公式のリリースノートもある） ([typescriptlang.org][6])
そして **TypeScript 6.0/7.0（Go移植のネイティブ版）**が近いって公式が進捗を出してる段階！🚀 ([Microsoft for Developers][7])
なので教材としては、今は「安定して回る土台（5.9系相当）」で作って、移行は最後に“発展”として触れるのが安心だよ〜😊✨

---

次の第9章では、この土台の上で **「Orderって何を持つ？」を言葉と型でそろえる**（ドメイン超入門）に入っていくよ📦💕
続けて第9章もこのテンションで作る？😆🎀

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://nodejs.org/en/blog/vulnerability/december-2025-security-releases?utm_source=chatgpt.com "Tuesday, January 13, 2026 Security Releases"
[3]: https://www.typescriptlang.org/tsconfig/moduleResolution.html "TypeScript: TSConfig Option: moduleResolution"
[4]: https://typescript-eslint.io/getting-started/ "Getting Started | typescript-eslint"
[5]: https://vitest.dev/guide/?utm_source=chatgpt.com "Getting Started | Guide"
[6]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[7]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
