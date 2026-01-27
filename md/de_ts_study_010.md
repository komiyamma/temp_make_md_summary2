# 第10章 イベントpayload設計のコツ（必要最小限）🎒✨

## 10.0 この章のゴール 🎯💡

* イベントの **payload（中身）** を「最小で強い形」にできるようになる 💪✨
* 「入れるべき情報」と「入れない方がいい情報」を理由つきで判断できるようになる 🧠🔍
* `OrderPlaced` のpayloadを **2案** 作って、良し悪しを比べられるようになる ⚖️🛒

---

## 10.1 payloadってなに？（イベントの“中身”）🧾👀

ドメインイベントは「何が起きたか」を表す **過去の事実** だったよね ⏳✨
そのイベントの中で、**追加で伝えたい細かい情報** が payload（ペイロード）だよ🎒

例：`OrderPlaced`（注文が置かれた）

* 「起きた事実」：注文が作られた ✅
* 「payloadに入りうる情報」：`orderId`、`items`、`totalAmount` など 🧾

ここで超大事なのが👇
**payloadは“入れれば便利”だけで増やすと、未来で地獄を見る** 😇➡️😱

---

## 10.2 “薄いイベント”と“厚いイベント”⚖️🍱

payload設計には、よく出る2つの方向性があるよ〜！✨

### A) 薄い（Thin / Notification）📣🪶

* payloadは **最小限（IDとかキー中心）**
* 受け取った側が「必要なら自分で取りに行く」スタイル 🔎

「薄いイベント（通知イベント）」は、イベントの結合を弱くしやすいよ〜って整理されることが多いよ📌 ([Solace][1])

### B) 厚い（Thick / State Transfer）📦🍖

* payloadに **必要な情報を多めに載せて渡す**
* 受け取った側は「イベントだけでだいたい処理できる」✨

ただし、厚いほど **互換性（変更）・サイズ・機密** の問題が出やすい⚠️
この章は「必要最小限にするコツ」を中心に扱うよ🎒✨

---

## 10.3 payloadを最小にしたい3つの理由 🧠✨

### 理由1：変更に強くなる（壊れにくい）🧱🔧

payloadが太いほど「誰かが使ってるフィールド」が増えて、**ちょっと直すだけで破壊変更** になりがち💥
イベント・スキーマの進化では「追加は基本OK（できればoptional）」みたいな運用が強い味方になるよ✅ ([Solace Documentation][2])

### 理由2：個人情報・機密が混ざると事故りやすい 🙅‍♀️🔐

イベントはログ・キュー・解析基盤など **いろんな場所に複製されやすい**。
だから payload に個人情報を入れすぎると、削除や保管期限（retention）まで含めて難しくなりがちだよ😵‍💫 ([Event-Driven][3])

### 理由3：サイズが大きいと、インフラの上限に当たりやすい 📦💣

イベント基盤には「1イベント何KBまで」みたいな制限が普通にあるよ〜
例：EventBridgeは256KB上限があるし ([Amazon Web Services, Inc.][4])、Pub/Subはメッセージサイズ10MBなどの制限があるよ ([Google Cloud Documentation][5])
Kafkaも「大きいメッセージは非推奨/アンチパターン」寄りに語られがち🧯 ([Confluent][6])

---

## 10.4 payloadに「入れる / 入れない」の判断ルール ✅🧭

### ルールA：payloadは「意味が成立する最小の事実」だけ 🧾✨

イベント名が `OrderPlaced` なら、payloadは「注文が置かれたと理解できる最小セット」だけでOK！

おすすめの最低ライン例👇

* `orderId`（主キー）🆔
* `customerId`（関係する主体）🙋‍♀️
* `items`（何を買ったか：商品IDと数量）🛒
* `totalAmountAtThatTime`（その瞬間の合計：あとで変わる可能性があるなら）💰

### ルールB：「参照で取れる情報」は入れない 🔎🙅‍♀️

たとえば👇

* 商品名（`productName`）は、商品マスタから取れるなら入れない
* 顧客のメール（`email`）は、通知側が顧客DBから取れるなら入れない

入れるのは基本 **ID** でOK！🪪✨

### ルールC：「あとで取れない瞬間の値」は入れていい ⏳🧊

イベントは“過去の事実”。
だから **あとで参照すると変わっちゃう値** は、スナップショットとしてpayloadに入れる価値があるよ！

例👇

* 購入時の単価（あとで値上げされるかも）💸
* 適用したクーポン（後で無効化されるかも）🎟️
* 税率（時期で変わるかも）🧾

### ルールD：個人情報（PII）は原則入れない 🙅‍♀️🪪

特に👇は避けたい：住所・電話・氏名・メール・生年月日など
イベントは保存・転送・分析されやすいから、扱いが難しくなるよ🧯 ([Event-Driven][3])

### ルールE：巨大データは入れない（画像/全文/大量配列）🐘❌

「イベントは軽く」が基本！
大きいものは **別ストレージに置いて参照（ID/URL/キー）** が定番だよ📦➡️🗃️
（イベント基盤のサイズ制限にも引っかかりやすいよね） ([Amazon Web Services, Inc.][4])

---

## 10.5 例：`OrderPlaced` payloadを2案で比べよう ⚖️🛒✨

ここでは **“太い案”** と **“最小案”** を並べるよ〜！

### まずイベント型（第9章の共通フォーマットのイメージ）🧾🛡️

```ts
export type DomainEvent<TType extends string, TPayload> = Readonly<{
  eventId: string;
  occurredAt: string;        // ISO文字列 (例: "2026-01-27T12:34:56.789Z")
  aggregateId: string;       // ここでは orderId を入れる想定
  type: TType;
  payload: TPayload;
}>;
```

---

### 案1：太いpayload（やりがちだけど危険）🍖💥

```ts
type OrderPlacedPayload_Fat = {
  order: {
    orderId: string;
    status: "PLACED";
    customer: {
      customerId: string;
      name: string;
      email: string;
      phone: string;
    };
    shippingAddress: {
      postalCode: string;
      prefecture: string;
      city: string;
      line1: string;
      line2?: string;
    };
    items: Array<{
      productId: string;
      productName: string;
      unitPrice: number;
      quantity: number;
      imageUrl?: string;
    }>;
    totalAmount: number;
    note?: string;
  };
};
```

😱 これの問題は…

* 個人情報がごっそり（メール・住所）🚨
* 商品名や画像URLなど「参照で取れる」ものが多い 🔎
* 依存が増える → 変更が怖い → schema地獄 💥
* サイズも太りやすい 📦

---

### 案2：最小payload（おすすめ）🪶✨

「通知＋必要最小限の事実」だけに寄せるよ🎒

```ts
type Money = { amount: number; currency: "JPY" };

type OrderPlacedPayload_Slim = {
  orderId: string;
  customerId: string;

  // “意味が成立する最小の中身”
  lineItems: ReadonlyArray<{
    productId: string;
    quantity: number;

    // “あとで取れないかも”なら snapshot としてOK（例：購入時単価）
    unitPriceAtThatTime?: Money;
  }>;

  // 合計も「購入時点の記録」として価値があることが多い
  totalAmountAtThatTime: Money;

  // PIIは避けて「参照キー」に寄せる
  shippingAddressId?: string;

  couponCodeApplied?: string;
};
```

✨ この案が強いところ

* 個人情報を持ちにくい（住所はID参照）🔐
* 利用側が「自分の都合で必要な情報を取りに行ける」🔎
* producer側が「誰が何を欲しがるか」を背負いすぎない 🧠
* 将来の利用者が増えても、イベントが太りにくい 🎈

「基本はキー中心にして、必要なら利用側が参照する」という考え方は、結合を増やしすぎない方向としてよく語られるよ📌 ([Solace][1])

---

## 10.6 “参照で取れる情報” vs “今この瞬間の情報” 🔎⏳

### 参照で取れる情報（基本入れない）🙅‍♀️

* `productName`（商品マスタ）
* `customerEmail`（顧客DB）
* `categoryName`（分類マスタ）
* `stock`（在庫の現在値）

理由：イベントpayloadに入れると「未来の変更」で壊れたり、二重管理になりやすい💥

### 今この瞬間の情報（入れてOKになりやすい）✅

* 購入時単価
* 税率
* 割引後の価格
* 適用クーポン

理由：あとで変わると困る「履歴の真実」だから🧾✨

---

## 10.7 payload設計の“よくある事故” 😵‍💫💣

### 事故1：Entity丸ごとpayloadに詰める 🧺💥

* 便利そうに見えるけど、フィールド追加・変更が全部破壊変更になりがち😱
* 個人情報も混ざりやすい🚨

✅ 対策：**ID＋瞬間スナップショットだけ** に寄せる🎒

---

### 事故2：計算済みフィールドを大量に入れて「二重の真実」になる 🧮😇➡️😱

例：`totalAmount`, `subtotal`, `discountTotal`, `taxTotal` を全部入れる
→ どれかズレたら、どれが正しいの？ってなる💥

✅ 対策：

* “基準”を1つ決める（例：`totalAmountAtThatTime`）
* ほかは必要になったタイミングで追加（しかもoptional）📌 ([Solace Documentation][2])

---

### 事故3：payloadが大きすぎて運用が詰む 📦🧯

基盤の上限・遅延・コスト・再送など、地味に効いてくるよ〜😵‍💫
（サイズ制限があるサービスも多い） ([Amazon Web Services, Inc.][4])

✅ 対策：巨大データは外に置いて参照キーでつなぐ🗃️🔗

---

## 10.8 演習：`OrderPlaced` payloadを2案作って比較しよう ✍️⚖️✨

### Step 1：まず“太い案”をあえて作る 🍖

* 顧客情報、住所、商品名、画像…「便利そう」を全部入れてみる

### Step 2：次に“最小案”を作る 🪶

* ID中心にする（`orderId`, `customerId`, `productId` など）
* “あとで取れない瞬間値”だけ残す（単価、税率、割引など）

### Step 3：チェックリストで採点 ✅🧠

各項目「YESなら危険かも⚠️」って思ってね！

* そのフィールド、別DB/別APIから取れない？（取れるならIDでよくない？）🔎
* 個人情報が混ざってない？🙅‍♀️
* それ、将来の仕様変更で変わりやすくない？（商品名とか）🌀
* イベント1個が重くなりすぎてない？📦
* “購入時点の真実”として残す価値ある？⏳
* 利用側が増えたとき、producerが毎回イベントを変える羽目にならない？😵‍💫

---

## 10.9 AI活用（Copilot/Codex）でpayloadをスッキリさせる 🤖🪄💖

### 目的：まず“欲しがりリスト”を出してもらう 📝

```text
OrderPlaced の利用者（通知/ポイント/在庫/分析）が
「欲しがりそうな情報」を列挙して。
そのうえで、payloadに入れるべき最小セット案を提案して。
PIIっぽい項目があれば指摘して。
```

### 目的：太いpayloadを“削ぎ落とし”してもらう ✂️🎒

```text
この payload は太すぎるので、
(1) 参照で取れる情報
(2) 個人情報・機微情報
(3) 二重の真実になりそうな計算値
に分類して、最小payload案にリライトして。
```

### 目的：将来の変更に強い進化案（optional追加）を考える 🧱✨

スキーマ進化では「追加はoptionalに」が実務でよく推奨されるよ📌 ([Solace Documentation][2])

```text
今の OrderPlacedPayload_Slim に対して、
互換性を壊しにくい拡張（optional追加）案を3つ出して。
フィールド名の変更や削除は避けて。
```

---

## 10.10 まとめ 🎁✨

* payloadは「便利」より「未来の壊れにくさ」優先が基本だよ🎒🧱
* **参照で取れる情報はIDで**、**あとで取れない瞬間値はスナップショットで** ⏳🔎
* 個人情報は原則入れない（イベントは複製されやすい）🙅‍♀️🔐 ([Event-Driven][3])
* スキーマ進化は「optional追加」が強い味方✅ ([Solace Documentation][2])
* “薄いイベント”は結合を増やしにくく、変更にも強くしやすい🪶✨ ([Solace][1])

[1]: https://solace.com/blog/events-schemas-payloads/?utm_source=chatgpt.com "Events, Schemas and Payloads:The Backbone of EDA ..."
[2]: https://docs.solace.com/Schema-Registry/schema-registry-best-practices.htm?utm_source=chatgpt.com "Best Practices for Evolving Schemas in Schema Registry"
[3]: https://event-driven.io/en/gdpr_in_event_driven_architecture/?utm_source=chatgpt.com "How to deal with privacy and GDPR in Event-Driven systems"
[4]: https://aws.amazon.com/blogs/mt/event-driven-architecture-using-amazon-eventbridge/?utm_source=chatgpt.com "Event Driven Architecture using Amazon EventBridge"
[5]: https://docs.cloud.google.com/pubsub/quotas?utm_source=chatgpt.com "Pub/Sub quotas and limits"
[6]: https://www.confluent.io/learn/kafka-message-size-limit/?utm_source=chatgpt.com "Apache Kafka Message Size Limit: Best Practices & Config ..."
