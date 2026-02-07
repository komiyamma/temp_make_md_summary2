# 第71章 Repository入門：保存・取得の抽象化📚💾✨

## 1) 今日のゴール🎯🌸

この章が終わったら、こうなります👇

* Repositoryが「何のための道具」か説明できる🗣️✨
* **domain側に `interface` を置く理由**がわかる📦🧠
* `OrderRepository` のメソッド粒度を、ユースケースから逆算して決められる🔎🧾
* Application Serviceが **DB/Map/外部保存に触れずに**注文を保存・取得できるようになる🎬🛡️

---

## 2) Repositoryってなに？（一言で）🧠📚

Repositoryはね…

**「集約（例：Order）を、保存・取得する“窓口”を1つにまとめたもの」**だよ💡✨
しかもポイントは、**窓口の形（interface）はdomain側**に置くこと！

---

## 3) Repositoryがない世界、だいたい地獄😵‍💫🪦

Repositoryがないと、よくこうなる👇

* Application Serviceが `Map` や `DB` を直に触る
* すると、いつの間にか **ユースケース手順の中に「保存の都合」や「検索の都合」**が混ざる
* さらに、domainがDB都合に引っぱられて汚れていく…😇

DDD（戦術DDD）の理想はこれ👇

* domain：ルール（不変条件・状態遷移）を守る🏯🔒
* app：手順を回す🎬
* infra：保存や通信の現実を担当する🧰

---

## 4) どこに置く？（超大事！）📦🧭

Repositoryはこう分けます👇

* **domain**：`OrderRepository` **interface**（「こう使いたい！」の希望）🌱
* **infra**：`OrderRepository` の **実装**（「実際どう保存するか」）🧰

依存の向きはこう👇（矢印の先を“知ってる”）

```
app  → domain
infra → domain
domain は app/infra を知らない
```

これが「差し替え可能」になるカギ🔑✨
（DBを変えてもdomainは無傷〜！💃）

ちなみに、2026時点のNodeは「v24がActive LTS」になってるので、現実の実装（infra側）をあとで足していくのもしやすいよ🪟✨ ([nodejs.org][1])

---

## 5) メソッド粒度の決め方🧩🔎（ここが腕の見せどころ！）

Repositoryのメソッドは、**ユースケースから逆算**して決めるのがコツ💡

いま私たちの例題ユースケースは（第70章までで）だいたい👇

* PlaceOrder：新規作成して保存
* PayOrder：注文を取得して支払い済みにして保存
* FulfillOrder：注文を取得して提供済みにして保存
* GetOrder：注文を取得して表示用に返す

だから最小セットはこうなりがち👇

* `save(order)`
* `findById(orderId)`

「検索条件が増えそうだから」といって、いきなり

* `findByStatus`
* `findByCustomer`
* `search(...)`
  みたいに増やすと、太りやすいよ😂💦（必要になったら足すでOK！）

---

## 6) domainに置く：OrderRepository interface（例）🪪📚

> ※ この章では「形」を作るのが目的！実装（Mapで保存とか）は次章でやるよ〜🧪📦

```ts
// domain/order/OrderRepository.ts

import { Order } from "./Order";
import { OrderId } from "./OrderId";

export interface OrderRepository {
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
}
```

### 戻り値は `null`？それとも Result型？⚖️🎀

ここはチーム方針でOKだけど、超入門ならまずは👇がラク✨

* 見つからない → `null`
* ユースケース側で「なかったらエラー」にする

Result型にすると表現力は上がるけど、最初は型が増えて混乱しやすいかも😵‍💫
（第87〜89章のエラー設計の章で、もっとキレイにできるよ🧯✨）

---

## 7) appが使う：Application ServiceはRepositoryだけ知る🎬🛡️

「PayOrder」を超ざっくりで書くとこんな感じ👇

```ts
// app/PayOrderService.ts

import { OrderRepository } from "../domain/order/OrderRepository";
import { OrderId } from "../domain/order/OrderId";

export class PayOrderService {
  constructor(private readonly orderRepo: OrderRepository) {}

  async execute(input: { orderId: string }) {
    const orderId = OrderId.fromString(input.orderId);

    const order = await this.orderRepo.findById(orderId);
    if (!order) {
      // ここは「アプリ層の責務」でOK（見つからない → どうする？）
      throw new Error("注文が見つかりませんでした🥲");
    }

    order.pay();              // ← domainのルールを動かす✨
    await this.orderRepo.save(order); // ← 保存方法は知らない💾
  }
}
```

ここが気持ちいいポイント😍✨

* appは「取得して→ドメイン操作→保存」しかしてない
* DBだろうがMapだろうが、**どうでもいい**（Repositoryが吸収！）

---

## 8) 「差し替えできる」ってどう嬉しいの？🔁🎉

Repositoryがあると…

* テストでは `InMemoryOrderRepository` に差し替え🧪
* 本番では `DbOrderRepository` に差し替え💾
* しかも、**app/domain側のコードはほぼ変えない**✨

これ、成長しても崩れにくい設計の“芯”だよ🏯💖

テスト周りは、2025年後半にVitest 4.0が出ていて（4系の流れが強い）、軽く速く回しやすいのも追い風〜🏃‍♀️💨 ([vitest.dev][2])
（Jestも安定版は30系だよ📌）([jestjs.io][3])

---

## 9) ありがち事故集😂⚠️（先に踏み抜きポイントを潰す！）

### ❌ 事故1：domainに「DBっぽい型」が漏れる

* `OrderRepository.save(orderRecord: OrderRow)` みたいに「保存用の形」をdomainに入れない🙅‍♀️
  → domainは **domainの型（Order）**で完結させよう✨

### ❌ 事故2：Repositoryが“何でも屋検索サービス”になる

* `searchOrders(filter: any)` とかは危険🍄
  → まずはユースケース最小で！

### ❌ 事故3：Repositoryが集約ルート以外も保存し始める

* LineItem単体を保存しだすと、集約ルールが崩れやすい😱
  → Repositoryは基本「集約ルート単位」📦（第73章で深掘り！）

---

## 10) AI（Copilot/Codex）で爆速にするプロンプト集🤖💨📝

そのままコピペでOK系👇✨

### ✅ interfaceの骨格を出してもらう

* 「Order集約のRepository interfaceをTypeScriptで提案して。ユースケースは PlaceOrder/PayOrder/FulfillOrder/GetOrder。最小のメソッドに絞って。戻り値はPromiseで。」

### ✅ 粒度レビューしてもらう

* 「このRepositoryメソッド一覧、DDDの観点で太りすぎてない？不要なものを指摘して、削った最小案を出して。」

### ✅ 依存の向きレビュー

* 「domainがinfraを参照してしまっているimportがないか、チェック観点をリスト化して。」

---

## 11) 章末ミニ演習🎓🍰

### 演習A（やさしめ）🧁

`OrderRepository` に **「findById / save」以外を追加したくなった理由**を3つ書いてみて✍️
→ その理由、本当に「今必要」？それとも「未来の不安」？🫣

### 演習B（ちょい実戦）🍩

`MenuRepository` を同じ方針で設計してみよう👇

* domainにinterface
* 最小メソッドだけ
* 検索メソッドを増やしすぎない

---

## 12) 理解チェック（3問）✅🌟

1. Repositoryのinterfaceをdomain側に置くのはなぜ？（一言で）
2. `findById` が `null` を返す設計のとき、「見つからない場合の扱い」はどの層の責務？
3. Repositoryメソッドが太り始めたときの“危険サイン”を1つ言ってみて👀

---

### まとめ🎀✨

Repositoryは「保存・取得の窓口」を作って、**domainを現実（DB）から守るバリア**だよ🛡️💖
この章で「形（interface）」ができたから、次章で `InMemory` 実装して **差し替え体験**しようね🧪📦🎉

（ちなみに、TypeScriptの公式リリースノートは2026年2月時点で5.9系が更新されてて、`tsc --init` まわりの改善なども入ってるよ🧡）([typescriptlang.org][4])

[1]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[2]: https://vitest.dev/blog/vitest-4 "Vitest 4.0 is out! | Vitest"
[3]: https://jestjs.io/versions "Jest"
[4]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html "TypeScript: Documentation - TypeScript 5.9"
