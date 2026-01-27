# 第8章 ドメインイベントの基本ルール🧠📏

## この章のゴール🎯✨

* ✅ **良いイベント名 / 微妙なイベント名**を見分けられるようになる
* ✅ 命令っぽい名前（Do/Send系）を、**「起きた事実」**に言い換えられる✍️
* ✅ **粒度（大きすぎ/小さすぎ）**を、理由つきで判断できるようになる⚖️

---

## 8.1 まず大前提：ドメインイベントは「起きた事実」📸⏳

ドメインイベントは「こうしなさい（命令）」じゃなくて、**「こうなった（事実）」**を表すよ〜！💡
なので名前は基本 **過去形** がしっくりくる✨ ([Microsoft Learn][1])

* 👍 事実（イベント）例：`OrderPlaced`（注文が行われた）🧾
* 👎 命令（コマンド）例：`PlaceOrder`（注文しろ）🫵💦

> イメージは「ニュースの見出し」より「履歴の記録」📒✨
> “やった/起きた/確定した” を残す感じだよ〜🧸

---

## 8.2 ルール①：名前は「過去形」⏳✅

**イベント＝もう起きたこと**なので、過去形が自然！ ([Microsoft Learn][1])

### 👍 いい例

* `OrderPlaced`（注文された）🛒
* `OrderPaid`（支払いされた）💳
* `OrderShipped`（発送された）📦
* `StockReserved`（在庫が引き当てられた）🧺

### 👎 ありがちな微妙例（命令っぽい）

* `PlaceOrder` / `PayOrder` / `ShipOrder` 😵‍💫
* `SendEmail`（それは「やれ」になってる）📮❌

---

## 8.3 ルール②：動詞は “Do/Send/Create” から離れる📮❌

イベント名に **Do / Send / Create / Update / Process** が入ってたら、だいたい黄色信号🚥💦
なぜなら、それって **「手段」**になりがちで、**「事実」**が見えにくいから👀

### 命令っぽい → 事実に言い換え（変換テンプレ）🔁✨

「何をする？」じゃなくて「何が起きた？」へ！

| 命令っぽい😵                | 事実っぽい✅                                             |
| ---------------------- | -------------------------------------------------- |
| `SendOrderEmail` 📩    | `OrderEmailSent` / もっと業務寄りなら `CustomerNotified` 🔔 |
| `CreateInvoice` 🧾     | `InvoiceIssued`（請求書が発行された）                         |
| `ProcessPayment` 💳    | `PaymentAuthorized` / `PaymentCaptured`（どの事実？を選ぶ）  |
| `UpdateOrderStatus` 🔧 | `OrderPaid` / `OrderCanceled` など「何になった？」にする        |

💡コツ：**名詞（主語）＋過去形動詞**にすると整いやすいよ〜🧩

---

## 8.4 ルール③：「技術の都合」をイベント名に混ぜない🌍🚫

ドメインイベントは **業務の言葉（ユビキタス言語）**で書くのが大事✨ ([Mathias Verraes' Blog][2])

### 👎 技術都合っぽい例（避けたい）

* `OrderKafkaPublished` 🛰️
* `OrderRowInserted` 🧱
* `WebhookCalled` 🪝

### 👍 業務の事実に寄せる例

* `OrderPlaced` 🛒
* `OrderPaid` 💳
* `CustomerNotified` 🔔

> 技術はあとで変わるけど、業務の言葉は残り続けやすい📚✨
> 未来の自分に優しい☺️

---

## 8.5 ルール④：「OrderUpdated」みたいな “なんでもイベント” は避ける🧨

`OrderUpdated` とか `UserChanged` みたいなイベントは便利そうに見えるけど…
**あとで絶対つらくなる**率が高い😇💥

### なにがつらいの？😵

* 🤷‍♀️「何が更新されたの？」が分からない
* 🧩 ハンドラ側が `if (payload.xxx)` だらけになってカオス
* 🧪 テストもしんどい（条件分岐地獄）

### じゃあどうする？✅

更新の “意味” に分ける✨

* `OrderAddressChanged` 🏠
* `OrderItemAdded` ➕
* `OrderPaid` 💳
* `OrderCanceled` 🛑

---

## 8.6 ルール⑤：粒度（大きすぎ/小さすぎ）を見分けよう⚖️🧠

### 大きすぎるイベント（でかすぎ🍙）

* `OrderLifecycleCompleted` 😵‍💫
  → 何が起きたか曖昧すぎるし、後で分岐が爆発しやすい💥

### 小さすぎるイベント（細かすぎ🌾）

* `OrderTotalCalculated` 🧮
* `DiscountRuleChecked` 🧾
  → 内部処理のメモになりがちで、イベントとしてはノイズ多め📢💦

---

## 8.7 粒度を決めるための “3つの質問” 🔍✨

イベント名に迷ったら、これを自分に質問してみてね☺️

### ✅ 質問1：「ビジネス的に大事？」📣

* “起きたら喜ぶ/困る/誰かに伝えたい” ならイベント候補💡

### ✅ 質問2：「タイムライン（履歴）に残したい？」📒

* “後から追跡したい事実” ならイベントっぽい✨

### ✅ 質問3：「反応する人（処理）がいる？」🔔

* 通知・集計・連携・ポイント付与など、**後から増えそう**ならイベントが活きる🌱

---

## 8.8 ミニEC題材で粒度の例を見てみよう🛒📦

「注文→支払い→発送」なら、このくらいがちょうど良いことが多いよ✨

* `OrderPlaced` 🛒（注文が確定した）
* `OrderPaid` 💳（支払いが完了した）
* `OrderShipped` 📦（発送された）
* `OrderCanceled` 🛑（キャンセルされた）

逆に、こんなのは “内部処理” 寄りになりがち👇

* `OrderTotalCalculated` 🧮
* `EmailTemplateSelected` 📨

---

## 8.9 TypeScriptでイベント名を “ぶれない” ようにする小ワザ🔷🧷

イベント名って、文字列だとタイポしがち😭
だから **リテラル型**で固定すると安心だよ〜🛡️

```typescript
export type DomainEventType =
  | "OrderPlaced"
  | "OrderPaid"
  | "OrderShipped"
  | "OrderCanceled";
```

「TypeScriptは現行 5.9 系が最新ライン」として案内されているよ。 ([TypeScript][3])

---

## 8.10 演習①：命令っぽい名前を「事実」に直そう✍️✨

次のイベント名（？）を、**過去形の事実**に直してみてね🧠💕

1. `SendReceiptEmail` 📩
2. `CreateOrder` 🛒
3. `ProcessPayment` 💳
4. `UpdateShippingAddress` 🏠
5. `DoPointGrant` 🪙
6. `PublishOrderEvent` 📣

✅ 例：`CreateOrder` → `OrderPlaced`

---

## 8.11 演習②：粒度レビュー（大きすぎ？小さすぎ？）⚖️🔍

次の候補を「でかすぎ🍙 / ちょうどよい🍰 / 細かすぎ🌾」に分類してみよう！

* `OrderLifecycleCompleted`
* `OrderPaid`
* `DiscountRuleChecked`
* `OrderItemAdded`
* `CustomerNotified`
* `OrderRowInserted`

---

## 8.12 AI活用プロンプト集🤖💬（コピペOK）

### ① 命名を “事実” に直す

```text
あなたはDDDの設計コーチです。
次の候補名を「ドメインイベント（過去形の事実）」として自然な名前に直してください。
さらに「なぜその名前が良いか」を1行で添えてください。

候補:
- SendReceiptEmail
- ProcessPayment
- UpdateOrderStatus
```

### ② 粒度が適切かチェック

```text
あなたはイベント設計レビュアーです。
次のイベント名が「大きすぎる / ちょうどよい / 小さすぎる」か判定し、
理由と改善案（別名の候補）を出してください。

イベント候補:
- OrderUpdated
- OrderPaid
- DiscountRuleChecked
```

### ③ ミニECのフローからイベント候補を抽出

```text
次の業務フローから「ドメインイベント（起きた事実）」を5〜8個提案してください。
各イベントは過去形で、業務の言葉を使ってください。

フロー:
注文 → 支払い → 発送 → 通知 → ポイント付与
```

---

## 8.13 今日のまとめ🧁✨（チェックリスト）

* ✅ イベント名は **過去形の事実**（〜した/〜された）⏳ ([Microsoft Learn][1])
* ✅ `Do/Send/Create/Update` っぽさが出たら、**事実に言い換え**🔁
* ✅ 技術用語じゃなくて **業務の言葉**で📚✨ ([Mathias Verraes' Blog][2])
* ✅ `OrderUpdated` みたいな “なんでも” は避ける🧨
* ✅ 粒度は「ビジネス的に大事？」「履歴に残す？」「反応する？」で判断⚖️

---

## おまけ：IDが欲しくなったら（超ミニTips）🆔✨

イベントにIDを付けたくなったら、`randomUUID()` が使えるよ〜！
ブラウザ側は `crypto.randomUUID()`、サーバ側も `node:crypto` にあるよ🔐 ([MDNウェブドキュメント][4])

```typescript
import { randomUUID } from "node:crypto";

const eventId = randomUUID();
```

[1]: https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation?utm_source=chatgpt.com "Domain events: Design and implementation - .NET"
[2]: https://verraes.net/2014/11/domain-events/?utm_source=chatgpt.com "Domain Events"
[3]: https://www.typescriptlang.org/download/?utm_source=chatgpt.com "How to set up TypeScript"
[4]: https://developer.mozilla.org/en-US/docs/Web/API/Crypto/randomUUID?utm_source=chatgpt.com "Crypto: randomUUID() method - Web APIs | MDN"
