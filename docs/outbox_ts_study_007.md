# 第7章：ミニ題材を決める（学習用の小さな世界）🧪🍀

### 7.1 なんで「ミニ題材」が必要なの？🤔✨

Outbox（トランザクショナル・アウトボックス）は、いきなり本番っぽい題材でやると…
「要件が多すぎて」「どこが大事か分からなくて」「実装が迷子」になりがちです😵‍💫🌀

だからこの章では、**Outboxの核心（＝事故るポイント）だけが入った“小さな世界”**を先に決めます🧊💡
小さいほど、理解が速いし、あとで拡張もしやすいよ〜🪜🌱

---

### 7.2 ミニ題材に入れておくべき“必須条件”✅📦

ミニ題材は「Outboxが必要になる状況」をわざと作るのがコツです😈✨
次のチェックを満たす題材を選べばOK！

* ✅ **業務データの更新がある**（例：注文ステータスが変わる）🛒
* ✅ **外へ通知したいことがある**（例：通知サービスへイベント）📩
* ✅ **通知は失敗しうる**（ネットワーク・一時障害）🌧️
* ✅ **再送が起こりうる**（リトライで二重送信の可能性）🔁
* ✅ **「更新」と「送信」を同時に扱うと事故る**（これがOutboxの出番）💥

この“二重書き問題（DB更新と通知送信の両方が絡む）”を、Transactional Outbox が解決する、という位置づけだよ🛡️📦
([AWS ドキュメント][1])

---

### 7.3 今回のミニ題材（採用）🛒📩「注文確定 → OrderConfirmed を送る」

この教材では、ミニ題材をこれに固定します🎯✨

#### ✅ ユースケース（やりたいこと）

* ユーザーが「注文確定」ボタンを押す🖱️
* 注文の状態が **Confirmed** になる✅
* その事実を、外部（通知サービス）へ **OrderConfirmed** として知らせたい📩

#### 😱 でも現実は…

* DB更新は成功✅
* 送信は失敗❌（通信エラー）
  → 「確定したのに通知が飛んでない！」📭 みたいな事故が起きる

だから、**“送る予定”をDBに残す Outbox** が必要になる、という流れです📦🧾
Outbox は「業務DBと同じ場所にメッセージ（イベント）を保存して、あとでリレーが送る」という登場人物構成で語られることが多いよ👥📤
([microservices.io][2])

---

### 7.4 仕様を「小さく固定」しよう（YAGNIで勝つ）🧊🏆

ミニ題材は、**“学ぶために”割り切る**のが正義です🙂✨
ここで欲張ると、Outbox以外で燃えます🔥

#### ✅ 今回「やる」こと（スコープIN）🟢

* 注文を **Confirmed** に更新する
* Outbox に **OrderConfirmed** を1件保存する
* （後の章で）Outbox を拾って送る係が送信する📤

#### ❌ 今回「やらない」こと（スコープOUT）🔴

* 決済・在庫・配送などの本格業務💳🚚
* 本物のメール送信✉️（最初はダミーでOK）
* メッセージブローカー（Kafka等）導入🧠（後でやれる）
* 分散トレーシングの完全実装🔍（後で育てる）

**“動く最小”を最速で作る**のがゴールだよ🏃‍♀️💨🎯

---

### 7.5 1枚で書ける「ミニ仕様」テンプレ📝✨

この章の成果物はこれ！👇
（このテンプレを埋めれば、次章以降が超ラクになります🪄）

#### 🧾 ミニ仕様：注文確定

* **入力**：orderId（注文ID）🆔
* **前提**：注文は存在する（見つからなければエラー）⚠️
* **ルール**：status が Draft のときだけ Confirmed にできる✅
* **DB更新**：orders.status = Confirmed、confirmedAt を入れる🕒
* **Outbox追加**：eventType = "OrderConfirmed"、payload を保存📦
* **期待結果**：

  * DB更新とOutbox追加が **どっちも成功**したときだけ完了✅
  * 送信は後でやる（失敗しても業務を巻き込まない）✂️

---

### 7.6 イベント（OrderConfirmed）の設計をミニで決める📨🧩

イベントは「受け手が困らない最小」を目指すよ🎁✨

#### ✅ 推奨フィールド（最小）

* eventId：一意なID🆔
* eventType："OrderConfirmed"🏷️
* occurredAt：発生時刻🕒
* payload：本体（注文の情報）📄
* schemaVersion：1（将来のため）🧬

#### ✅ payload に入れる最小（例）

* orderId🆔
* userId👤
* totalAmount💰
* currency（"JPY"など）💴

「Outboxに入れるメッセージは、あとでリレー（送信係）が外へ出す」ので、**後で見返して意味が分かる形**にするのが大事だよ👀📦
([microservices.io][2])

---

### 7.7 TypeScriptで“型”として固定しておく（迷いを消す）🧠✨

ここでは実装をガッツリ進めなくてOK🙆‍♀️
でも、**型だけは先に決める**と「仕様のブレ」が激減します📌

```ts
// まずはイベント種別を固定（タイポ防止✨）
export type EventType = "OrderConfirmed";

// payload（通知したい中身）
export type OrderConfirmedPayload = {
  orderId: string;
  userId: string;
  totalAmount: number;
  currency: "JPY";
};

// Outboxに入れる1レコード（最小）
export type OutboxMessage = {
  id: string;                 // eventId と同じでOK（最初は）
  eventType: EventType;
  payloadJson: string;        // JSON文字列で保存する想定
  status: "pending" | "sent"; // まずは2状態でOK
  createdAt: string;          // ISO文字列
  schemaVersion: 1;
};
```

> 🍀ポイント：**まずは status を2つだけ**にする（pending / sent）
> “processing” や “failed” や retryCount は、あとで段階的に増やす🪜✨

---

### 7.8 AI（コーディング支援）で「題材の完成度」を上げる🤖💖

ミニ題材づくりは、AIに手伝わせると速いよ⚡
例えば GitHub の Copilot や、OpenAI の Codex系ツールにこう聞くと便利🧠✨
（※“答えを丸写し”じゃなくて、“仕様の穴を見つける”使い方がおすすめ！👀）

#### 💬 そのまま使えるプロンプト例

* 「注文確定イベントの payload に最低限必要な項目を、受け手視点で提案して」🎁
* 「Draft→Confirmed の状態遷移で、初心者がやりがちなバグを3つ教えて」🐛
* 「このミニ題材、YAGNI的に“やりすぎ”な要素があったら削って」🧊
* 「Outboxレコードの最小カラム案を、学習用に2段階（初級→実運用寄り）で出して」🪜

#### 🔍 追加ヒント

Copilot は VS Code で提案＆チャットが使える形で説明されているよ🧰💬
([Visual Studio Code][3])

---

### 7.9 章末チェックリスト（ここまでできた？）✅🌸

* [ ] ミニ題材が「注文確定→イベント通知」になっている🛒📩
* [ ] スコープIN / OUT が言える（やらないことを守れる）🧊
* [ ] ミニ仕様が1枚で書けた📝
* [ ] OrderConfirmed の payload 最小が決まった🎁
* [ ] TypeScriptの型で固定できた🧠

---

### 7.10 ミニ演習（5分）⏱️🎀

次のどれか1つ、同じテンプレで「ミニ題材化」してみよう👇（注文確定の次にやると理解が深まるよ🪄）

* A：会員登録完了 → UserRegistered 🧑‍💻✨
* B：投稿公開 → PostPublished 📝📣
* C：パスワード変更 → PasswordChanged 🔐⚠️

「DB更新」と「外へ知らせたいこと」がセットになってれば、Outbox向きだよ📦✅

---

### まとめ 🎯📦

この章でやったのは、**Outboxを学ぶための“最小の舞台づくり”**です🧪✨
次章からは、このミニ題材を使って「実装の最短ルート」を進みます🏃‍♀️💨

[1]: https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html?utm_source=chatgpt.com "Transactional outbox pattern - AWS Prescriptive Guidance"
[2]: https://microservices.io/patterns/data/transactional-outbox.html?utm_source=chatgpt.com "Pattern: Transactional outbox"
[3]: https://code.visualstudio.com/docs/copilot/overview?utm_source=chatgpt.com "GitHub Copilot in VS Code"
