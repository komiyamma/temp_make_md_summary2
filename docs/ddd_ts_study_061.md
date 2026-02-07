# 第61章 Application Service入門：ユースケース担当🎬🧑‍🍳✨

## 🆕 2026年2月7日時点の“最新メモ”だけ先に📌

* TypeScriptは **5.9系（npmの最新は 5.9.3）** が現行の安定ラインだよ🧡 ([npm][1])
* tsconfigで **`--module node20`** みたいに「Node向けの安定プリセット」を選べる流れが強い（“nodenext”より挙動が固定されやすい）🧩 ([typescriptlang.org][2])
* Node.jsは v24 が Active LTS で、v25 が Current（次のLTS候補の流れ）になってるよ🟩 ([nodejs.org][3])
* テストは Vitest 4.0 が出てて、4.1 beta も動いてる（勢い強め）🧪⚡ ([vitest.dev][4])
* そしてTypeScriptは将来、コンパイラを Go で高速化する “TypeScript 7” の進捗が定期的に話題になってるよ🚀（※今すぐの書き方は大きく変えなくてOK） ([InfoQ][5])

---

## 1) 今日のゴール🎯🌸

この章が終わったら、あなたはこうなるよ✨

* Application Service（アプリケーションサービス）が **何の係** か説明できる🎬
* 「ドメイン（ルール）」と「アプリ層（手順）」を **混ぜない** で書ける🧊🧡
* “入力→取得→ドメイン操作→保存” の流れが **テンプレとして手に入る** 🧾✅
* テストで「ユースケースが回ってる！」を確認できる🧪🎉

---

## 2) Application Serviceってなに？（超いっこだけ）🧠💡

**Application Service = ユースケースの“進行役”** だよ🎬✨
映画でいうと、ドメインが「ルール（脚本）」で、Application Serviceが「段取り（進行）」！

* ドメイン：**ルールを守る**（不変条件・状態遷移・整合性）🏯🛡️
* Application Service：**手順を回す**（ロードして、呼んで、保存して、返す）🔁📦
* UI/Infra：**入出力する**（HTTP、DB、外部API）🌍🔌

---

## 3) 3つの層の役割分担（ここが命！）💖🧭

### ✅ ドメイン層（domain）

* 「支払い後は明細いじれない」みたいな **絶対ルール** を守る🔒
* `order.pay()` とか **意図のあるメソッド** を持つ🕹️
* DBやHTTPのことは知らない🙅‍♀️

### ✅ アプリ層（app）

* ユースケースの手順を書く📜
  例：

  1. 受け取る
  2. 取得する
  3. ドメインを動かす
  4. 保存する
  5. 返す
* どこまでを“一括で成功/失敗”にするか（トランザクション境界）を決める🧾⏱️
* **ルールはドメインに任せる**（ここ大事💕）

### ✅ インフラ層（infra）

* DBの保存/取得、外部API呼び出し、ログなど🗄️📡
* ドメインに合わせて実装を差し替える🔁

---

## 4) “型”として覚える黄金フロー🥇🔁

Application Serviceの最頻出テンプレはこれ👇✨

```text
(入力DTO/Command)
    ↓
[Application Service]
  1) validate(軽く)
  2) repoから集約を取得
  3) 集約メソッドを呼ぶ（ルールは集約が守る）
  4) repoに保存
  5) 出力DTO/Resultで返す
    ↓
(出力DTO)
```

ここでの気持ち🫶

* Application Serviceは **“オーケストラの指揮者”** 🎻
* ドメインは **“楽譜どおりじゃないと音が出ない楽器”** 🎺
* infraは **“会場（DB/ネットワーク）”** 🏟️

---

## 5) 例題：PlaceOrder（注文する）で体験しよ☕🧾✨

### 💌 入力（Command/DTO）の例

* 顧客ID
* 注文行（メニューID、数量）

### 🎁 出力（Result/DTO）の例

* 作られた注文ID
* 合計金額
* ステータス（Draftなど）

---

## 6) 実装してみよう（最小構成）🛠️🎬

### 6-1) domain：Repositoryの“型”だけ用意（中身はinfra）📚

> ここでは「どう保存するか」はまだ気にしないでOK！
> Application Serviceが使う“窓口”の形だけ作るよ✨

```ts
// src/domain/order/OrderRepository.ts
import { Order } from "./Order";
import { OrderId } from "./value/OrderId";

export interface OrderRepository {
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
}
```

---

### 6-2) app：入力/出力DTO（外と話す形）📦✨

```ts
// src/app/order/place/PlaceOrderCommand.ts
export type PlaceOrderCommand = Readonly<{
  customerId: string;
  items: ReadonlyArray<{
    menuItemId: string;
    quantity: number;
  }>;
}>;
```

```ts
// src/app/order/place/PlaceOrderResult.ts
export type PlaceOrderResult =
  | { ok: true; orderId: string; total: number; status: "Draft" }
  | { ok: false; code: "VALIDATION_ERROR" | "DOMAIN_ERROR"; message: string };
```

---

### 6-3) app：Application Service本体（手順の係）🎬🧑‍🍳

```ts
// src/app/order/place/PlaceOrderService.ts
import { OrderRepository } from "@/domain/order/OrderRepository";
import { PlaceOrderCommand } from "./PlaceOrderCommand";
import { PlaceOrderResult } from "./PlaceOrderResult";

// ※ domain側に Order / VO が既にある前提で“使うだけ”にする
import { Order } from "@/domain/order/Order";
import { Money } from "@/domain/order/value/Money";
import { OrderId } from "@/domain/order/value/OrderId";
import { MenuItemId } from "@/domain/order/value/MenuItemId";
import { Quantity } from "@/domain/order/value/Quantity";

export class PlaceOrderService {
  constructor(
    private readonly orderRepo: OrderRepository,
    private readonly generateOrderId: () => string, // 今は簡易でOK
  ) {}

  async execute(cmd: PlaceOrderCommand): Promise<PlaceOrderResult> {
    // 1) まず“軽く”入力チェック（UIの代わりの最低限）🧼
    if (cmd.items.length === 0) {
      return { ok: false, code: "VALIDATION_ERROR", message: "商品が1つもないよ🥺" };
    }

    // 2) 集約を作る（生成の詳細は後でFactoryで綺麗にする）🏭✨
    try {
      const orderId = OrderId.fromString(this.generateOrderId());
      const order = Order.createDraft(orderId, cmd.customerId);

      // 3) ドメイン操作：ルールはドメインが守る🛡️
      for (const it of cmd.items) {
        order.addItem(
          MenuItemId.fromString(it.menuItemId),
          Quantity.fromNumber(it.quantity),
        );
      }

      // 4) 保存（永続化の詳細はinfraへ）🗄️
      await this.orderRepo.save(order);

      // 5) 返す（ドメインをそのまま返さずDTOに）🎁
      const total: Money = order.total();
      return { ok: true, orderId: orderId.value, total: total.amount, status: "Draft" };
    } catch (e) {
      // ここでは雑に握る。後でエラー設計章でピカピカにする🧯✨
      const message = e instanceof Error ? e.message : "不明なエラーだよ🥲";
      return { ok: false, code: "DOMAIN_ERROR", message };
    }
  }
}
```

💡ポイント（ここテストに出るやつ😆）

* `execute()` の中は **“手順”だけ**
* ルール（数量は1以上、支払い後は変更禁止…）は **VO/集約が守る**
* 返すのは **DTO**（集約そのまま返さない）📦

---

## 7) “動いた！”をテストで確認🧪🎉

テストは「このユースケースの進行が正しいか」を見るよ👀✨
（Vitestの現行ライン/動きも強いよ🧪⚡） ([vitest.dev][4])

```ts
// src/app/order/place/PlaceOrderService.spec.ts
import { describe, it, expect } from "vitest";
import { PlaceOrderService } from "./PlaceOrderService";
import { OrderRepository } from "@/domain/order/OrderRepository";

// 最小のInMemory（本物のDBは後でOK）🧺
class InMemoryOrderRepo implements OrderRepository {
  public savedCount = 0;
  async findById() { return null; }
  async save() { this.savedCount++; }
}

describe("PlaceOrderService", () => {
  it("itemsが1つ以上ならokで返る🎉", async () => {
    const repo = new InMemoryOrderRepo();
    const svc = new PlaceOrderService(repo, () => "order-001");

    const res = await svc.execute({
      customerId: "c-1",
      items: [{ menuItemId: "latte", quantity: 1 }],
    });

    expect(res.ok).toBe(true);
    expect(repo.savedCount).toBe(1);
  });

  it("itemsが0ならVALIDATION_ERRORで返る🥺", async () => {
    const repo = new InMemoryOrderRepo();
    const svc = new PlaceOrderService(repo, () => "order-002");

    const res = await svc.execute({ customerId: "c-1", items: [] });

    expect(res.ok).toBe(false);
    if (!res.ok) {
      expect(res.code).toBe("VALIDATION_ERROR");
    }
  });
});
```

---

## 8) あるある事故パターン（先に潰す😇⚠️）

### ❌ 事故1：アプリ層にルールを書いちゃう

* 「支払い済みなら変更禁止」を `if` でアプリ層に書く → すぐ散らばる💥
  ✅ ルールは集約/VOへ！

### ❌ 事故2：ドメインをそのまま返す

* UIが `order.items.push(...)` できちゃう → 城が落ちる🏯💣
  ✅ 返すのはDTO（読み取り専用の形）！

### ❌ 事故3：アプリ層が“神クラス”になる

* PlaceOrderServiceが、割引計算も、在庫確認も、ログも、DBも…
  ✅ 手順だけ。詳細はドメイン/infra/サービスへ分割！

---

## 9) AIの使いどころ（補助輪🛟🤖💕）

ここはめちゃ効くよ✨（でも“ルール”は任せすぎない！）

### 🧠 AIに頼むと強いこと

* DTOの形を整える（余計な項目を削る）📦
* Application Serviceの“骨組み”だけ生成🎬
* テストの観点を増やす（正常/異常/境界）🧪

### 💬 そのまま使えるプロンプト例

```text
Application Serviceの責務は「手順のオーケストレーション」に限定して。
ドメインの不変条件はドメイン側に寄せたい。
PlaceOrderのexecute(cmd)の骨組みをTypeScriptで提案して。
入出力はDTO、保存はOrderRepository経由、例外はapp層でResultに変換して。
```

---

## 10) ミニ演習（手を動かすと一気に定着🎮✨）

できたら勝ち〜〜🎉

1. **PayOrderService** を同じテンプレで作ってみよ💳

   * 手順：注文取得 → `order.pay()` → 保存 → DTO返す
2. `items` のチェックをもう少し増やす（quantityが0以下なら弾く）📏
3. Resultの `code` を増やして、UIが分岐しやすい形にする🎛️

---

## まとめ（この章の一行）🎬✨

**Application Serviceは「ユースケースの進行役」！**
ドメインはルール担当🛡️、アプリは手順担当🎬、infraは入出力担当🔌——この分業ができるとDDDがめっちゃ気持ちよく回り出すよ〜〜💖😊

次の第62章では、このユースケースを **Command/Queryで分けてさらにスッキリ** させにいこうね🧾🔎✨

[1]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[4]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[5]: https://www.infoq.com/news/2026/01/typescript-7-progress/?utm_source=chatgpt.com "Microsoft Share Update on TypeScript 7"
