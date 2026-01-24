# 第10章　コマンド設計①（PlaceOrder：注文する）🧾✅

今日は「**注文する**」という “更新の意思” を、**Command（コマンド）として気持ちよく設計**して、**最小のバリデーション**まで入れていくよ〜😊✨
（※本日 2026-01-24 時点の最新：TypeScript は npm で **5.9.3** が Latest、Node.js は **v24 が Active LTS**、VS Code は **1.108（2026-01-08 リリース）**だよ📌）([NPM][1])

---

## 今日のゴール🎯✨

できたら勝ち！の到達点はこれ👇

* ✅ PlaceOrder の **入力DTO** を決められる（必須/任意がわかる）
* ✅ 「型」だけじゃ足りない理由（＝実行時に壊れる）を理解できる
* ✅ **最小バリデーション**を境界でやれる（Zodでサクッと）
* ✅ Handler に渡す “ちゃんとした形” に整形できる

---

## 1) Commandってどんなもの？🤔🧠

Command は一言でいうと…

> 「**これをやって！**」という更新リクエスト📩✨

* PlaceOrder（注文する）
* PayOrder（支払う）
* CancelOrder（キャンセルする）

みたいに、**動詞 + 目的語**のノリで命名すると迷子になりにくいよ😊🧭

そして超大事ポイント👇

### TypeScriptの「型」は、実行時には守ってくれない😇⚡

画面やAPIから来るデータって、**実は何でも入ってくる**のね…（文字列のはずが null とか）
だから **Command の入口**で、軽くでもチェックしてあげるのが安全🛡️✨

---

## 2) PlaceOrder の入力DTOを決めよう🧾🧩

学食アプリの「注文する」って、最低限なにが必要？🍙📱

### 最小セット（おすすめ）✅

* `userId`：誰が注文するの？🙋‍♀️
* `items`：何を買うの？（配列）🍱

  * `menuId`：メニューID
  * `quantity`：数量
* `note?`：備考（任意）📝（例：アレルギー注意とか）

ここでのコツは👇

* **Command は “やりたいこと” を表す**（画面都合の項目を盛りすぎない）🙅‍♀️
* 「注文」なのに「支払い方法」まで入れる？ → それは次の PayOrder の仕事かも💳✨
  （分けるとラクになるのがCQRSの気持ちよさ💕）

---

## 3) ハンズオン：Zodで入力DTO + 最小バリデーション✅✨

Zodは **TypeScript向けのバリデーションライブラリ**で、
「実行時チェック」しつつ「型」も作れて便利だよ〜🤖💖([Zod][2])

### 3-1) 入力（外から来る形）を schema で定義する📦

```ts
// src/commands/placeOrder/PlaceOrderInput.ts
import { z } from "zod";

export const PlaceOrderInputSchema = z.object({
  userId: z.string().min(1),
  items: z.array(
    z.object({
      menuId: z.string().min(1),
      quantity: z.number().int(), // ここでは「整数」まで（深いルールは次章でやるよ🛡️）
    })
  ).min(1),
  note: z.string().max(200).optional(),
});

export type PlaceOrderInput = z.infer<typeof PlaceOrderInputSchema>;
```

ポイント✨

* `min(1)` で「空文字NG」✅
* `items` は `min(1)` で「空注文NG」✅
* quantity は **int** まで。**quantity > 0** みたいな業務ルールは次章（不変条件）で本格的に守るよ🔥

---

## 4) “入力DTO” と “Command” を分ける発想💡✨

初心者がめっちゃハマりやすい落とし穴👇

* 入力DTO（外から来る） = **信用できない**😈
* Command（アプリ内部で扱う） = **信用できる形に整える**😊

なので、入口でこうするのがキレイ👇

1. 入力を parse（バリデーション）
2. “中で使う形” に整形して Handler に渡す

### 4-1) 整形して Command を作る（変換関数）🔁

```ts
// src/commands/placeOrder/PlaceOrderCommand.ts
export type PlaceOrderCommand = {
  userId: string;
  items: Array<{
    menuId: string;
    quantity: number;
  }>;
  note?: string;
};
```

```ts
// src/commands/placeOrder/parsePlaceOrder.ts
import { PlaceOrderInputSchema } from "./PlaceOrderInput";
import type { PlaceOrderCommand } from "./PlaceOrderCommand";

export function parsePlaceOrder(input: unknown): PlaceOrderCommand {
  // ✅ ここで「実行時に」チェックされる！
  const parsed = PlaceOrderInputSchema.parse(input);

  // ✅ “中で使う形” に整える（今回はそのままでもOKだけど、将来ここが効く✨）
  return {
    userId: parsed.userId.trim(),
    items: parsed.items.map((x) => ({
      menuId: x.menuId.trim(),
      quantity: x.quantity,
    })),
    note: parsed.note?.trim(),
  };
}
```

Zod の `parse()` は、ダメな入力なら例外を投げるよ⚠️
例外をどう返すか（Resultにする？エラー分類する？）は、後半の章（エラー設計）でめっちゃ丁寧にやるから安心してね😊✨

---

## 5) PlaceOrderHandler は「流れ」だけ持つ🏃‍♀️💨

第10章では “雰囲気” をつかむのが目的なので、まずは薄く！

```ts
// src/commands/placeOrder/PlaceOrderHandler.ts
import type { PlaceOrderCommand } from "./PlaceOrderCommand";

export type PlaceOrderResult = {
  orderId: string;
};

export class PlaceOrderHandler {
  async handle(command: PlaceOrderCommand): Promise<PlaceOrderResult> {
    // ここで本来は：
    // - Orderを作る（domain）
    // - repositoryに保存する（infrastructure）
    // …みたいに流れる（詳細は後の章で育てる🌱）

    const orderId = crypto.randomUUID(); // NodeならOK（ブラウザでもOK）
    return { orderId };
  }
}
```

「え、ドメインどこ？」って思った？🙂
それでOK！今日は **Commandの形を整える**のが主役だから、ドメインの深いルールは次章で “ガチ守り” するよ🛡️🔥

---

## 6) 入口から呼ぶイメージ（API/画面側）🌐🖥️

```ts
// どこかのcontroller的な場所のイメージ
import { parsePlaceOrder } from "./commands/placeOrder/parsePlaceOrder";
import { PlaceOrderHandler } from "./commands/placeOrder/PlaceOrderHandler";

const handler = new PlaceOrderHandler();

export async function placeOrderEndpoint(body: unknown) {
  const command = parsePlaceOrder(body);  // ✅ 入口で安全にする
  const result = await handler.handle(command);
  return result;
}
```

こうするとね👇

* 「危ない入力」は入口で止まる🛑
* Handler 以降は “ちゃんとした形” 前提で書ける✍️✨
* 未来に仕様が増えても、入口の変換関数がクッションになる🛏️💕

---

## 7) ミニ演習🧪✨（10〜15分でOK）

### 演習A：任意項目を1つ増やす🎀

`couponCode?: string` を追加してみてね🎟️

* 空文字はNG（`min(1)`）にする？
* 文字数上限は？（`max(20)` とか）

### 演習B：items の上限を決める🍱📦

例えば「一回で最大20件まで」にしたいなら？
`z.array(...).min(1).max(20)` でいけるよ〜✅

### 演習C：AIにレビューさせる🤖🧐

Copilot / Codex にこんな感じで聞くのおすすめ✨

* 「PlaceOrderInput のバリデーション漏れがないかチェックして」
* 「このDTOは “注文する” 以外の関心が混ざってない？」

AIは気づきの相棒だけど、**採用判断は人間がやる**のがコツだよ🙂👍

---

## 8) 今日のまとめ🎉✨

* Command は「やって！」を表す🧾✨
* 入力DTOは信用しない → 入口でチェック🛡️
* TypeScriptの型だけじゃ実行時は守れない → Zodが便利✅([Zod][2])
* Handlerはまず薄くてOK（流れ担当）🏃‍♀️💨

---

## おまけ：ちょい安全Tips🔒（VS Code）

知らないリポジトリを開くときは **Workspace Trust** を「制限モードのまま」にして様子見が安全だよ〜⚠️
VS Code公式も「迷ったら Restricted Mode」と言ってる👍([Visual Studio Code][3])

---

次の第11章では、いよいよ **不変条件（Invariants）を入口で守る**よ🛡️🔥
「quantity > 0 とか、合計金額とか、無効状態を絶対作らない」っていう “設計の強さ” が出てくる章になるよ〜😊✨

[1]: https://www.npmjs.com/package/typescript?activeTab=versions&utm_source=chatgpt.com "typescript"
[2]: https://zod.dev/?utm_source=chatgpt.com "Zod: Intro"
[3]: https://code.visualstudio.com/docs/editing/workspaces/workspace-trust?utm_source=chatgpt.com "Workspace Trust"
