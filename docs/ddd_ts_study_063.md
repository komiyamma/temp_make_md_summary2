# 第63章 DTO設計：入出力の形を決める📦🔁✨

第62章で「更新（Command）と参照（Query）を分ける」感覚ができたので、今日はその“境界のかたち”をちゃんと作ります😊
つまり **DTO（Data Transfer Object）＝外と内の間を流れる「ただのデータ箱」** を設計する回だよ〜📦💕

---

## 0. 🗓️ 2026/02のアップデート小ネタ（最新リサーチ）🔍✨

* 現時点の安定版 TypeScript は **npm では 5.9.3**（最終公開が2025/09末の表示）だよ🧩 ([npm][1])
* **TypeScript 6.0** は「次のメジャー」で、**Beta/RC/Final の具体スケジュール**が公開されてるよ（例：Beta 2026-02-10、Final 2026-03-17 など）📅 ([GitHub][2])
* そして **TypeScript 6.0 は “最後のJavaScript実装ベース” のリリース**になる予定、という公式アナウンスが出てるよ⚡ ([Microsoft for Developers][3])
* ちなみに Node.js 側も TypeScript ファイルの扱いが進んでるけど、**型は実行時には守ってくれない**（モジュール方式も勝手に変換しない）っていう前提は変わらないよ🧠 ([nodejs.org][4])
* 入力検証ライブラリは **Zod v4 が安定版**で、**v4.3.x が年末〜年始に継続リリース**されてる流れだよ✨ ([Zod][5])

👉 だからこの章の結論はシンプル：
**「型（TypeScript）だけに頼らず、DTOは“境界のデータ”として設計し、必要なら“実行時検証”もセットにする」** だよ😊💕

---

## 1. 今日のゴール🎯💖

この章が終わったら、あなたはこうなれる✨

* DTOが「何のための箱か」説明できる📦
* **入力DTO** と **出力DTO** を分けて作れる🔁
* ドメインを汚さない **変換（mapping）** の置き場がわかる🧼
* 「DTOに入れすぎ問題」や「ドメイン直返し事故」を避けられる🚫💥

---

## 2. DTOってなに？（ふわっと → くっきり）📦🧠

DTOはね、超ざっくり言うと：

* **外から来たデータを受け取る形**（入力DTO）
* **外へ返すデータを渡す形**（出力DTO）

どっちも共通して **“ふるまい（メソッド）を持たない、ただのデータ”** が基本だよ📦✨
（＝シリアライズしやすい、テストしやすい、境界がくっきりする！）

---

## 3. なんで「入力DTO」と「出力DTO」を分けるの？🔁🧼

同じ型を使うと、気づいたらこうなる😇

* 入力に要らない項目（例：`status`）まで受け取ってしまう
* 出力に内部情報（例：コスト計算の途中値）まで漏れる
* 「この項目、入力？出力？どっち？」で混乱する

だから **分ける** のが基本🧸💕

### ✅ すごく実務っぽいメリット

* **セキュリティ**：返しちゃダメな情報を混ぜない🛡️
* **変更に強い**：出力だけ項目追加したい、ができる🧱
* **責務がきれい**：アプリ層が「境界の翻訳者」になれる🧑‍🍳✨

---

## 4. DTO設計のコツ 7つ🌟（これだけ覚えよ！）

### ① DTOは「ユースケース単位」で作る🎬

同じ “Order” でも

* PlaceOrder（注文作る）
* PayOrder（支払う）
* GetOrder（見る）
  で **欲しいデータが違う** よね？👀

👉 **“画面/操作に必要な形”** がDTOの基本だよ📦

---

### ② DTOは基本「プリミティブ中心」🧱

DTOに `Money` とか `OrderId` とかのドメイン型をそのまま入れたくなるけど…
それは **内側の都合** を外へ漏らす原因になりがち😵‍💫

👉 DTOはまず `string / number / boolean / array / object` を中心に作って、
**アプリ層でドメイン型へ変換** するのが王道だよ🔁✨

---

### ③ 「日時」はDTOでは基本 “文字列（ISO）” が安定⏰

`Date` をそのまま返すより、`"2026-02-07T12:34:56.000Z"` みたいな形のほうが事故りにくい💣
（表示はUI側で自由にできるしね💅）

---

### ④ DTOに “計算やルール” を入れない🧊

DTOに `getTotal()` みたいなのを生やすと、
いつの間にか **ドメインルールがDTO側へ漏れる** 😇

DTOは **箱！箱！箱！** 📦📦📦

---

### ⑤ 出力DTOは「見せたいものだけ」👀✨

* ユーザーが必要な情報
* 画面が必要な情報
* 次の操作に必要な情報

だけを入れる🎁
「念のため全部」は未来の自分を殴るやつ👊😂

---

### ⑥ 入力DTOは「受け取りたいものだけ」✋

受け取る必要がないのに受け取ると、

* 意図しない上書き
* 不正値の混入
  が起きるよ🚨

---

### ⑦ DTOは「バージョン変更に耐える」設計にする🧱✨

* 追加はしやすい（optional で段階導入）
* 削除や意味変更は慎重（破壊的変更）

---

## 5. 例題：PlaceOrder のDTOを設計しよう☕🧾✨

ここから一気に “形” を作るよ〜！🌸

### ✅ 入力DTO（Command）📥

* 「注文を作る」ために必要な情報だけ
* 余計な情報（`status` とか）は受け取らない

```ts
// app/dto/place-order.dto.ts

export type PlaceOrderItemInputDto = {
  menuItemId: string;   // 外から来るIDはまずstringでOK
  quantity: number;     // まずnumber（あとでVOへ変換）
};

export type PlaceOrderInputDto = {
  customerId: string;
  items: PlaceOrderItemInputDto[];
  note?: string;        // 任意：備考
};
```

### ✅ 出力DTO（Result）📤

* 画面や呼び出し元が “次にしたいこと” ができる情報

```ts
// app/dto/place-order.dto.ts

export type PlaceOrderOutputDto = {
  orderId: string;
  status: "Draft" | "Confirmed" | "Paid" | "Cancelled";
  total: {
    amount: number;     // 例：最小通貨単位（円ならそのままでもOK）
    currency: "JPY";
  };
  createdAt: string;    // ISO文字列
};
```

---

## 6. 変換（mapping）はどこでやるの？🔁🧑‍🍳

ここ超重要だよ！💖

### ✅ 基本方針

* **DTO → ドメイン**：アプリ層（ユースケース）で変換
* **ドメイン → DTO**：アプリ層で整形して返す

ドメインは「外の都合（DTO）」を知らない🧼✨
だから、翻訳はアプリ層の責務だよ🎬

---

## 7. PlaceOrder ユースケースでの変換イメージ🧩✨

（※ドメイン側の `Order.create(...)` とか `Money`/`Quantity`/`OrderId` は既にある想定でOK🙆‍♀️）

```ts
// app/usecases/place-order.usecase.ts

import { PlaceOrderInputDto, PlaceOrderOutputDto } from "../dto/place-order.dto";
// domain imports ... (Order, Money, Quantity, etc.)

export class PlaceOrderUseCase {
  // constructor(repo, clock, idGenerator...) など

  async execute(input: PlaceOrderInputDto): Promise<PlaceOrderOutputDto> {
    // 1) DTO -> Domain 変換（ここが翻訳）
    const items = input.items.map(i => ({
      menuItemId: /* MenuItemId.fromString(i.menuItemId) */ i.menuItemId,
      quantity: /* Quantity.of(i.quantity) */ i.quantity,
    }));

    const order = /* Order.create({ customerId: ..., items, note: input.note }) */ null as any;

    // 2) 保存
    // await this.orderRepo.save(order);

    // 3) Domain -> DTO 変換（返す形に整える）
    return {
      orderId: /* order.id.value */ "ORDER-123",
      status: /* order.status */ "Draft",
      total: {
        amount: /* order.total.amount */ 1200,
        currency: "JPY",
      },
      createdAt: /* order.createdAt.toISOString() */ new Date().toISOString(),
    };
  }
}
```

ポイントはここ👇

* 変換がユースケースに集まると、境界が守れてスッキリするよ😊✨
* 逆に、ドメインがDTOを知り始めると、ぐちゃぐちゃが始まる😇

---

## 8. 「型があるのに、なぜ入力検証が要るの？」😵‍💫➡️😊

TypeScriptの型は **コンパイル時だけ** なんだよね🧠
実行時に飛んでくるJSONは、型なんて守ってくれないの🥲

Node.js も TypeScript を扱える流れはあるけど、**実行時に型安全を保証してくれるわけじゃない**（モジュール方式も勝手に変換しない）よ📌 ([nodejs.org][4])

だから **境界（DTO）** では、必要に応じて

* Zod
* Valibot
  みたいな “実行時検証” を組み合わせると強い💪✨
  Zod v4 が安定版になって継続リリースされてるのも追い風だよ〜🩵 ([Zod][5])

### 例：Zodで PlaceOrderInputDto を検証✅

```ts
// app/validation/place-order.schema.ts
import { z } from "zod";

export const PlaceOrderInputSchema = z.object({
  customerId: z.string().min(1),
  items: z.array(
    z.object({
      menuItemId: z.string().min(1),
      quantity: z.number().int().positive(),
    })
  ).min(1),
  note: z.string().max(200).optional(),
});

export type PlaceOrderInputDto = z.infer<typeof PlaceOrderInputSchema>;
```

👉 そしてユースケースの入口で `schema.parse(unknown)` してから進むと、事故が激減するよ🛡️✨

---

## 9. DTO “入れすぎ” チェックリスト✅😂

DTOを作ったら、これでセルフレビューしよ〜💖

* ❓「この項目、呼び出し元が本当に使う？」
* ❓「内部実装の都合（DB用のカラム）を漏らしてない？」
* ❓「同じDTOを別ユースケースでも使い回してない？」（危険信号🚨）
* ❓「日時が Date になってない？」
* ❓「DTOにメソッドが生えてない？」（箱じゃなくなってる📦→🧟‍♂️）

---

## 10. ミニ演習🎓✨（手を動かすよ〜！）

### 演習A：PayOrder のDTOを作ってみよう💳

* 入力DTOに何が必要？（例：orderId、支払い方法…？）
* 出力DTOに何が必要？（例：status、paidAt…？）

👉 コツ：**“支払い” に必要な最小情報だけ** を考える✂️✨

---

### 演習B：GetOrder のDTOを作ってみよう🔎

* “見る” ために欲しい情報は？
* “更新” に必要な情報とは違うよね？👀✨

---

## 11. AIの使いどころ🤖💡（そのままコピペOK）

### ✅ DTO案を出してもらうプロンプト

* 「PlaceOrder の入力DTO/出力DTOを、ユースケース最小で提案して。入れすぎ項目も指摘して」📦🔍

### ✅ “漏れ” を見つけてもらうプロンプト

* 「このDTO設計、セキュリティ的に返しちゃダメな項目が混ざってないかレビューして」🛡️

### ✅ 変換責務のチェック

* 「DTO→Domain / Domain→DTO の変換はどこに置くのが自然？ 依存逆流が起きない案で」🔁

---

## 12. まとめ🎀✨

* DTOは **境界のデータ箱** 📦
* **入力DTO と 出力DTO は分ける**（混ぜると事故る）🔁
* **DTO↔ドメインの変換はアプリ層の責務** 🧑‍🍳
* 型は消えるので、必要なら **実行時検証** も組み合わせる🛡️✨

---

次の第64章では、このDTOを使って **PlaceOrder を“最小の成功ルート”で実装**して「動いた〜！🎉」まで持っていくよ✅☕✨

[1]: https://www.npmjs.com/package/typescript?activeTab=versions&utm_source=chatgpt.com "typescript"
[2]: https://github.com/microsoft/TypeScript/issues/63085?utm_source=chatgpt.com "TypeScript 6.0 Iteration Plan · Issue #63085"
[3]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
[4]: https://nodejs.org/api/typescript.html?utm_source=chatgpt.com "Modules: TypeScript | Node.js v25.6.0 Documentation"
[5]: https://zod.dev/v4?utm_source=chatgpt.com "Release notes"
