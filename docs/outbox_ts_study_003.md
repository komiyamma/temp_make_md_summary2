# 第3章：前提① イベントってなに？（超入門）📨🙂

## この章のゴール🎯✨

* 「イベントって何？」を**ひとことで説明**できるようになる🗣️💡
* **Domain Event** と **Integration Event** の違いをざっくり掴む👀✨
* 「どこまでがドメイン？どこから外？」の**境界感**を持てるようになる🧱🚪

---

## 1. 「イベント」って、いったい何？📨❓

イベントは、超ざっくり言うと…

> **「起きた事実」** ✅（だいたい過去形）

たとえばこんなやつ👇

* 注文が確定した🛒✅
* 支払いが失敗した💳💥
* 在庫がなくなった📦😱
* 会員登録が完了した🙋‍♀️🎉

ポイントはここ👇✨

* **イベントは“お願い”じゃない**（お願いはコマンド💌➡️🧑‍💻）
* **イベントは“起きた”こと**（もう戻らない）🕰️
* **イベントは基本的に書き換えない**（あとで「実は違いました」は別のイベントで扱うことが多い）🧾🔒

「イベント駆動」って言うと、実際に飛んでいるのは“イベントそのもの”というより、**イベントの通知メッセージ**として扱われることが多いよ〜📩🙂（用語が混ざりやすいので注意！） ([ウィキペディア][1])

---

## 2. まず覚える！イベントの“3点セット”🧺✨

イベントには最低限、だいたいこの3つが欲しいです👇

1. **id（イベントID）** 🆔

* 「これと同じイベント、もう処理した？」を判断する手がかりにもなるよ🔁🛡️

2. **type（イベントの種類）** 🏷️

* 例：`order.created` とか `payment.failed` とか

3. **time（いつ起きた？）** 🕒

* 「起きた時刻」と「気づいた時刻」がズレることもあるよ〜（分散あるある）⌛👀 ([martinfowler.com][2])

---

## 3. イベント vs コマンド（ここ超大事！）⚡📩

| 種類     | 意味           | 例              | ニュアンス      |
| ------ | ------------ | -------------- | ---------- |
| イベント🟩 | **起きた事実**    | `OrderCreated` | 「もう起きたよ」✅  |
| コマンド🟦 | **やってほしい依頼** | `CreateOrder`  | 「これやって！」🙏 |

イベントっぽい言葉で「実は依頼」をやると、設計がぐちゃりやすい😵‍💫
（“イベントのふりをした命令”が混乱の元になりやすい、という話があるよ） ([martinfowler.com][3])

---

## 4. Domain Event と Integration Event の違い👀🧠✨

ここからが本章のメインだよ〜！🎉

<!-- img: outbox_ts_study_003_event_types.png -->
## 4.1 Domain Event（ドメインイベント）って？🏠✨

**同じドメインの中（同じ境界の内側）**で、「起きた事実」を知らせたいときのイベント。

* 例：`OrderConfirmed`（注文が確定した）🛒✅
* 「アプリが関心を持つ“外部世界で起きたこと”」を表す、という考え方が代表的だよ📌 ([martinfowler.com][2])

特徴（ざっくり）👇

* **内向き**（同じ境界の中の人たち向け）🏠
* **ドメイン用語がそのまま出やすい**🗣️
* **小さめデータでも回しやすい**（同じチーム・同じサービス内なら理解が揃ってる前提）🧩

---

## 4.2 Integration Event（インテグレーションイベント）って？🌍📡

**境界の外（別のシステム・別サービス）**にも「起きた事実」を伝えたいときのイベント。

* 例：`OrderCreatedIntegrationEvent`（注文が作られたので外へ通知）📤🛒
* 目的は「他のサービスや外部システムと状態を同期したり、連携を起こすこと」だよ🤝✨ ([Microsoft Learn][4])

特徴（ざっくり）👇

* **外向き**（外部の購読者がいる）🌍
* **契約（フォーマット）を壊しにくくする必要**がある🧬⚠️
* **相手が増えるほど、名前やpayloadに気を遣う**🎁😇

---

## 5. 「境界」ってなに？どこで線を引くの？🧱✍️

ここで出てくるのが **Bounded Context（境界づけられたコンテキスト）** という考え方だよ〜🧠✨
ざっくり言うと👇

> **「この範囲では、このドメインモデル（言葉・ルール）が通じるよ」**っていう境界🧱

つまり、境界が違うと…

* 同じ「注文」でも、意味や必要な情報が違ったりする🍱↔️🍔
* モデルをムリに共有すると事故りやすい😵‍💫

Bounded Context は「どこまで同じモデルが適用されるか」を区切る考え方として説明されるよ📌 ([Microsoft Learn][5])

---

## 6. ミニ題材でイメージしよう🧪🍀（注文アプリ）

登場人物を分けると分かりやすいよ👇

## 境界A：注文（Order）🛒

* ここが「注文ドメイン」🏠
* ここで起きる事実：注文確定✅

→ **Domain Event（内向き）**：

* `OrderConfirmed` 🛒✅

  * 「注文が確定した」という、注文ドメインの“事実”

## 境界B：通知（Notification）📩

* メールやPush通知の世界📨
* 注文ドメインの内部事情は知らない（知りたくない）🙈

→ **Integration Event（外向き）**：

* `OrderConfirmedForNotification` 📤📩

  * 通知側が必要な最低限（注文ID、顧客ID、通知種別など）だけを持つ🎁

イメージとしては👇

* Domain Event：**内側の会話**🏠🗣️
* Integration Event：**外へのお知らせ**📢🌍

---

## 7. “標準の封筒”って知ってる？CloudEvents ✉️🌤️

外へイベントを流すとき、毎回フォーマットがバラバラだと大変😵‍💫
そこで便利なのが CloudEvents ✉️✨

* 「イベントのメタデータを共通化しよう！」という仕様だよ📦
* Cloud Native Computing Foundation では、**2024年1月25日に Graduated（卒業）プロジェクト**として承認されたよ🎓🎉 ([CNCF][6])

CloudEvents では、だいたいこんな“外側の封筒”を付けるイメージ👇

* `specversion`（例：`1.0`）
* `type`（イベント種類）
* `source`（発生元）
* `id`（イベントID）
* `time`（時刻）
  などなど🧾✨ ([cloudevents.github.io][7])

### TypeScriptで“封筒＋中身”の最小イメージ📦🧩

```ts
// ざっくり「CloudEventsっぽい封筒」
type CloudEventEnvelope<T> = {
  specversion: "1.0";
  id: string;
  type: string;
  source: string;
  time?: string;            // ISO文字列が多いよ
  subject?: string;
  datacontenttype?: string; // "application/json" とか
  data: T;                  // ← ここが「中身」
};

// 中身（通知側が欲しい最小情報）
type OrderConfirmedData = {
  orderId: string;
  customerId: string;
  totalYen: number;
};
```

---

## 8. Domain Event / Integration Event どっち？判定チートシート🧠💨

次の質問に「YES」が多い方を選ぶと迷いにくいよ👇

## Domain Event 寄り🏠

* 同じサービス（同じ境界）内だけで使う？✅
* ドメイン用語をそのまま使ってOK？✅
* 変更しても影響範囲をコントロールできる？✅

## Integration Event 寄り🌍

* 他サービス・外部システムが読む？✅
* 長く残る“契約”になる？✅
* 購読者が増える可能性がある？✅

---

## 9. ちょい練習📝✨（3分でOK）

次の出来事を「Domain / Integration」で分類してみよう👇🙂

1. 注文が確定した🛒✅
2. 注文確定をメール通知サービスに伝える📤📩
3. 在庫数が減った📦⬇️
4. 在庫の変化を分析基盤に流す📤📊

**目安の答え**👇（理由も言えたら最高！）

* 1. Domain / 2) Integration / 3) Domain / 4) Integration

---

## 10. AI活用ミニ型🤖✨（イベント名づけ＆境界チェック）

## イベント名を整える（命名ブレ防止）📛

* 「`注文確定` を英語イベント名にして、過去形で候補を10個。粒度も3段階で」📝✨

## Domain / Integration の仕分け👀

* 「この出来事リストを Domain / Integration に分類して、理由も1行ずつ」📚✅

## 境界チェック（“それ、外に出して大丈夫？”）🧱

* 「このpayloadは外部公開してよい？個人情報・内部実装の匂いを指摘して」🕵️‍♀️🔍

---

## まとめ🎀✨

* イベント＝**起きた事実**✅（コマンド＝お願い🙏）
* Domain Event＝**境界の内側**の事実共有🏠
* Integration Event＝**境界の外側**への通知📤🌍
* 境界（Bounded Context）を意識すると、イベント設計が急にラクになる🧱✨
* 外に出すイベントは“封筒”を揃えると強い（CloudEventsなど）✉️🔥 ([cloudevents.github.io][7])

[1]: https://en.wikipedia.org/wiki/Event-driven_architecture?utm_source=chatgpt.com "Event-driven architecture"
[2]: https://martinfowler.com/eaaDev/EventNarrative.html "Focusing on Events"
[3]: https://martinfowler.com/articles/201701-event-driven.html "What do you mean by “Event-Driven”?"
[4]: https://learn.microsoft.com/en-us/dotnet/architecture/microservices/multi-container-microservice-net-applications/integration-event-based-microservice-communications?utm_source=chatgpt.com "Implementing event-based communication between ..."
[5]: https://learn.microsoft.com/en-us/azure/architecture/microservices/model/domain-analysis?utm_source=chatgpt.com "Using domain analysis to model microservices"
[6]: https://www.cncf.io/announcements/2024/01/25/cloud-native-computing-foundation-announces-the-graduation-of-cloudevents/ "Cloud Native Computing Foundation Announces the Graduation of CloudEvents | CNCF"
[7]: https://cloudevents.github.io/sdk-javascript/interfaces/CloudEventV1.html "CloudEventV1 | cloudevents"
