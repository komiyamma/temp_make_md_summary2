# 第70章 ここまで統合：ユースケースが回る状態🎉🔁✨

この章は「DDDっぽい部品が揃った！」から一歩進んで、**実際にユースケースが “一周” 回る状態**を作ります💪🌸
（Place → Pay → Fulfill → Get を通して、ちゃんと状態が変わって、ちゃんと読める✨）

---

## この章のゴール✅🎯

* **1つのシナリオ**で「注文→支払い→提供→参照」を通しで動かせる🎬☕
* アプリ層（ユースケース）の**配線（DI）**ができる🔌🧩
* **統合テスト**で「壊れてない」を自動で守れる🧪🛡️
* “動くけど設計が崩れる”を防ぐチェックポイントが分かる👀⚠️

---

## 0) まず「統合」って何するの？🧠🧩

統合って、超ざっくり言うと👇

* domain：Order集約（ルールと状態遷移）🏯🔒
* app：Place/Pay/Fulfill/Get の手順（ユースケース）🎬
* infra：OrderRepository の実装（いまは InMemory）📦
* demo/test：それらを **線でつないで**、実行して確かめる🔁✅

イメージ図だとこんな感じ💡

```text
[demo/test]
   |
   v
[app/usecase]  ----->  [domain/Order Aggregate]
   |
   v
[infra/OrderRepository (InMemory)]
```

---

## 1) “配線” を1か所に集めよう🔌📌（bootstrap）

統合の第一歩は **「new 祭り」を1か所に閉じ込める**ことだよ〜😊✨
（あちこちで new し始めると、あとで地獄になる💀）

## 例：`src/bootstrap.ts` を作る🧰✨

* Repositoryを作る
* UseCaseを作る
* まとめて返す（＝アプリの入口）

```ts
// src/bootstrap.ts
import { InMemoryOrderRepository } from "./infra/InMemoryOrderRepository";
import { PlaceOrderService } from "./app/placeOrder/PlaceOrderService";
import { PayOrderService } from "./app/payOrder/PayOrderService";
import { FulfillOrderService } from "./app/fulfillOrder/FulfillOrderService";
import { GetOrderService } from "./app/getOrder/GetOrderService";

export function bootstrap() {
  const orderRepo = new InMemoryOrderRepository();

  return {
    orderRepo, // テストで中身を見たい時に便利🧪
    placeOrder: new PlaceOrderService(orderRepo),
    payOrder: new PayOrderService(orderRepo),
    fulfillOrder: new FulfillOrderService(orderRepo),
    getOrder: new GetOrderService(orderRepo),
  };
}
```

> こうしておくと、UIを作る日が来ても「bootstrap() 呼ぶだけ」でOKになるよ🎮✨

---

## 2) デモ台本を作ろう🎬📝（“回る”の確認）

「回る」って言っても、いきなりWeb画面いらないよ〜🙆‍♀️
まずは **シナリオスクリプト**でOK！

## デモでやること☕📦

1. PlaceOrder：注文を作る
2. GetOrder：状態を確認（Placed）
3. PayOrder：支払いして状態をPaidへ
4. FulfillOrder：提供して状態をFulfilledへ
5. GetOrder：最終状態を確認（Fulfilled）

```ts
// src/demo/runScenario.ts
import { bootstrap } from "../bootstrap";

async function main() {
  const app = bootstrap();

  console.log("🌸 1) PlaceOrder");
  const placed = await app.placeOrder.execute({
    customerId: "cust-001",
    items: [
      { menuItemId: "latte", quantity: 1 },
      { menuItemId: "cookie", quantity: 2 },
    ],
  });
  console.log("✅ orderId =", placed.orderId);

  console.log("\n🔎 2) GetOrder (after place)");
  console.log(await app.getOrder.execute({ orderId: placed.orderId }));

  console.log("\n💳 3) PayOrder");
  await app.payOrder.execute({ orderId: placed.orderId, paidAt: new Date().toISOString() });

  console.log("\n☕📦 4) FulfillOrder");
  await app.fulfillOrder.execute({ orderId: placed.orderId, fulfilledAt: new Date().toISOString() });

  console.log("\n🔎 5) GetOrder (final)");
  console.log(await app.getOrder.execute({ orderId: placed.orderId }));

  console.log("\n🎉 Done!");
}

main().catch((e) => {
  console.error("💥 error:", e);
  process.exitCode = 1;
});
```

---

## 3) “最新の実行方法”も押さえておこう🏃‍♀️💨

最近の **Node.js は TypeScript を（型を削って）そのまま実行**できるようになってきてるよ✨
ただし **型チェックはしない**ので、`tsc` は別で回すのが前提だよ🧠🧪
（Node公式の “Running TypeScript Natively” に書いてあるやつ！）([nodejs.org][1])

* Node.js v22.18.0 以降なら `node example.ts` が可能（“消せる型”の範囲）([nodejs.org][1])
* `import type` をちゃんと使わないと実行時に事故ることがある（Node公式ドキュメントで強調）([nodejs.org][2])

そして本日時点（2026-02-07）だと、Nodeは **v24系がLTS**で、最新リリースは **v25系**が出てるよ🪟✨([nodejs.org][3])

---

## 4) 統合テストを書こう🧪🛡️（“回る”を自動化）

デモで回ったら、次は **テストで固定**しよ〜！😊✨
ここができると「壊してもすぐ気づける」最強状態になる💪💕

最近の流れだと **Vitest** がかなり使われてるよ（Vitest 4.0 リリース済み）([vitest.dev][4])

## 統合テストの狙い🎯

* **ユースケースの並び**が通る
* 状態が期待通りに変わる
* 変な順番だと落ちる（＝ドメインのガードが効いてる）

```ts
// src/app/__tests__/orderFlow.int.test.ts
import { describe, it, expect } from "vitest";
import { bootstrap } from "../../bootstrap";

describe("Order flow integration 🌸", () => {
  it("Place -> Pay -> Fulfill -> Get が回る🎉", async () => {
    const app = bootstrap();

    const placed = await app.placeOrder.execute({
      customerId: "cust-001",
      items: [{ menuItemId: "latte", quantity: 1 }],
    });

    const afterPlace = await app.getOrder.execute({ orderId: placed.orderId });
    expect(afterPlace.status).toBe("PLACED");

    await app.payOrder.execute({ orderId: placed.orderId, paidAt: new Date().toISOString() });

    const afterPay = await app.getOrder.execute({ orderId: placed.orderId });
    expect(afterPay.status).toBe("PAID");

    await app.fulfillOrder.execute({ orderId: placed.orderId, fulfilledAt: new Date().toISOString() });

    const afterFulfill = await app.getOrder.execute({ orderId: placed.orderId });
    expect(afterFulfill.status).toBe("FULFILLED");
  });

  it("支払い前に提供しようとすると失敗する😵‍💫", async () => {
    const app = bootstrap();

    const placed = await app.placeOrder.execute({
      customerId: "cust-001",
      items: [{ menuItemId: "cookie", quantity: 2 }],
    });

    await expect(
      app.fulfillOrder.execute({ orderId: placed.orderId, fulfilledAt: new Date().toISOString() })
    ).rejects.toThrow();
  });
});
```

> ここで “rejects.toThrow()” になるのが超大事！
> 「アプリ層に if がなくても、ドメインが守ってくれてる」って証拠だよ🔒✨

---

## 5) 統合で一番やりがちな事故⚠️😂（回避チェック）

ここ、初心者が **めっちゃ踏みがち**なので先に潰しとこ🧯✨

## 事故1：アプリ層がドメインの中身を直接いじる🫠

* ❌ `order.status = "PAID"` みたいなやつ
* ✅ `order.pay(...)` みたいな “意図メソッド” だけで変更する

👉 「状態遷移のルール」がアプリ層に漏れると、第69章のアンチパターンへ逆戻り😇⚠️

---

## 事故2：保存し忘れ（repo.save忘れ）💾😵

* “ドメイン操作したのに、永続化されてない” あるある！

✅ 対策：ユースケースのテンプレを固定しよ🎬

```text
入力DTO → repoから取得 → ドメイン操作 → repo.save → 出力DTO
```

---

## 事故3：GetOrderがドメインを返しちゃう📦💥

* ❌ `return order;`（そのまま返す）
* ✅ 表示用DTOに詰め替える（必要な形にする）

👉 「表示に便利だから」とドメインを外に出すと、後で境界が崩れる😵‍💫

---

## 事故4：TypeScriptをNodeで直実行する時の import 罠🧨

Nodeの型削除実行では、**型だけのimportは `import type` を明示**しないと、実行時に「それ値として無いよ？」って怒られる場合があるよ⚠️
公式ドキュメントでも注意されてるポイント！([nodejs.org][2])

---

## 6) AIの使いどころ🤖💞（この章向け）

AIはこの章だと **「台本」と「テスト観点」**が超得意！🎉

## ① デモ台本を増やす（異常系も）📝

お願い例👇

* 「PayOrder を2回叩いたらどうなるべき？」🔁
* 「Fulfill後にGetOrderした時、表示に欲しい項目は？」🔎

## ② テストの抜けを見つける🧪

お願い例👇

* 「このフローの境界値と異常系を10個出して」⚠️
* 「状態遷移の禁止パターンを表にして」🚦

---

## 7) 章末チェックリスト✅🧡（これが満たせたら勝ち！）

* [ ] `runScenario.ts` が最後まで走る🎬🎉
* [ ] 実行ログで `PLACED → PAID → FULFILLED` が見える🚦✨
* [ ] 統合テストが1本以上ある🧪
* [ ] 「順番ミス」のテストが落ちる（＝守られてる）🔒
* [ ] GetOrder が DTO を返している📦
* [ ] bootstrap に配線が集約されている🔌

---

## 8) ミニ課題🎓🌸（ちょい足しで理解が固まる！）

## 課題A：CancelOrder を1本追加しよう🚫🧾

* Place後ならキャンセルOK
* Pay後はキャンセルNG（返金は別ユースケースにする、みたいに）

✅ できたら「台本」にも1パターン追加してね🎬✨

## 課題B：GetOrderの表示項目を “最小で気持ちいい” にする🔎✨

* orderId / status / total / items（名前・数量）くらい
* “UI都合の余計な形”は入れない（DTOは境界！）📦🛡️

---

## 最新情報メモ🗞️✨（本日時点の根拠つき）

* TypeScript の最新リリースは **5.9.3**（GitHub Releases上で Latest 表示）([GitHub][5])
* Node.js は **v24系がLTS**、最新リリースは **v25.6.0**（公式リリースページに “Latest LTS / Latest Release” 表示）([nodejs.org][3])
* Node.js は TypeScript を **型を削って直接実行**できる（ただし型チェックは別）([nodejs.org][1])
* Vitest は **4.0** がリリース済み([vitest.dev][4])
* Microsoftは TypeScript 6.0/7.0（ネイティブ化）の計画も発信していて、早期2026をターゲットにしている報道があるよ📣([InfoWorld][6])
* GitHub上でも TypeScript 5.9.3 が Latest として出ているよ🧾([GitHub][5])

---

次の第71章からは Repository を “ちゃんとDDDっぽく” 仕上げていくよ〜📚✨
この第70章で「回る」状態を作れてると、後半めっちゃ楽になるからね😊💖

[1]: https://nodejs.org/en/learn/typescript/run-natively?utm_source=chatgpt.com "Running TypeScript Natively"
[2]: https://nodejs.org/api/typescript.html?utm_source=chatgpt.com "Modules: TypeScript | Node.js v25.6.0 Documentation"
[3]: https://nodejs.org/en/blog/release/v25.6.0?utm_source=chatgpt.com "Node.js 25.6.0 (Current)"
[4]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[5]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[6]: https://www.infoworld.com/article/4100582/microsoft-steers-native-port-of-typescript-to-early-2026-release.html?utm_source=chatgpt.com "Microsoft steers native port of TypeScript to early 2026 ..."
