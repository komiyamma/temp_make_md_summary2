# 第31章 イベントは契約（壊さず育てる）🤝📜

## この章のゴール🎯

* ドメインイベントを「公開API（＝契約）」として扱えるようになる✨
* 変更が「安全か？危険か？」を判断できるようになる⚖️
* 事故らないための“仕組み”を、コードと運用で作れるようになる🧰🔧

---

## 1) なんでイベントは「契約」なの？🫶📣

イベントって、送る側（Producer）だけのものに見えるけど…実は **受け取る側（Consumer）がいる** よね👀
しかも受け取り側は「別サービス」「別チーム」「未来の自分」だったりする🪞✨

だからイベントは、こう考えるのが超大事👇

* **イベント＝公開インターフェース（契約）**
* いきなり形を変えると、利用者が落ちる（＝本番事故）💥😵‍💫

---

## 2) まず知っておく互換性の方向🧭

イベントの変更は、ざっくりこの3つで考えるとスッキリするよ🧠✨

* **後方互換（Backward compatible）**：古いConsumerが、新しいイベントを受けても壊れない✅
* **前方互換（Forward compatible）**：新しいConsumerが、古いイベントも受けられる✅
* **完全互換（Full compatible）**：両方OK（いちばん強い）💪✨
  「完全互換」を目指すなら、“古いProducer/Consumer” と “新しいProducer/Consumer” の組み合わせで壊れない状態が理想だよ🧩 ([クリークサービス][1])

---

## 3) 「安全な変更 / 危険な変更」ざっくり早見表⚖️🧾

| 変更内容                       | 判定    | なぜ？                     | どうするのが良い？                                             |
| -------------------------- | ----- | ----------------------- | ----------------------------------------------------- |
| フィールドを**追加**（しかも optional） | ✅安全寄り | 古いConsumerは無視できる        | 新規追加は基本これ🫶 ([Solace Documentation][2])               |
| フィールドを**削除**               | ❌危険   | 使ってるConsumerが死ぬ         | すぐ消さず、段階的に廃止🕰️                                       |
| フィールド名を**リネーム**            | ❌危険   | Consumerが読めなくなる         | **新フィールド追加→旧フィールド廃止**が王道✨ ([Solace Documentation][2]) |
| 型を変更（number→string等）       | ❌危険   | パース/計算が壊れる              | 新フィールドで置き換え🧩                                         |
| enumの候補を追加                 | ⚠️注意  | Consumerのswitchが落ちることある | default分岐 or unknown許容にする🧯                           |
| 意味だけ変更（同じ名前で意味が違う）         | ❌超危険  | いちばん気づきにくい事故💥          | 仕様として禁止レベル🙅‍♀️                                       |

ポイントはこれ👇

* “追加”は比較的安全（でも **optional** が基本）
* “削除/変更/リネーム”はだいたい危険⚠️

---

## 4) 「契約」を文章じゃなく“仕様”にする📐✨

口頭やREADMEだけだと、いつかズレるよね…🥲
なので、**機械が読める形**にしておくと強い💪

代表がこのへん👇

* **JSON Schema**：JSONの形を仕様として固定できる📄 ([JSON Schema][3])
* **AsyncAPI**：イベント駆動のAPI仕様をまとめて表現できる📚（payload schemaを定義できる） ([AsyncAPI][4])
* **CloudEvents**：イベントの“封筒”（メタデータ）を共通化する仕様📦（最低限の必須属性がある） ([Microsoft Learn][5])

### CloudEventsの「必須っぽい封筒」イメージ📦✨

CloudEventsは「イベントの外側（メタ情報）」を揃えるための仕様だよ🧾
たとえば必須属性として `id / source / specversion / type` を持つ、みたいな考え方🧠 ([Microsoft Learn][5])

---

## 5) 破壊変更を防ぐ“運用ルール”3点セット🧯🧰

### ① 契約は「公開インターフェース」だから、バージョンで扱う🔖

ここ、章タイトルの核心ね🤝
コードのバージョンと同じで、契約にも「互換性」があるから、**SemVer的な感覚**が役に立つよ✨

* 壊す変更＝Major
* 機能追加（互換性あり）＝Minor
* バグ修正＝Patch
  みたいなやつ😊 ([Semantic Versioning][6])

（※イベントのバージョニング戦略そのものは次章でガッツリやるよ🔖）

### ② 追加は optional、リネームはしない（置き換え式）🧩

* 追加するなら **optionalで追加** が鉄板✅ ([Solace Documentation][2])
* リネームはしないで

  * `newField` を追加
  * `oldField` を deprecated 扱い
  * 移行が終わったら…（やっと）削除
    これが安全ルート🕰️✨ ([Solace Documentation][2])

### ③ “仕様チェック”をCIに入れる（人間の注意力に頼らない）🤖✅

「うっかり壊した」を防ぐのは仕組みが最強💪
たとえば、ConfluentのSchema Registryみたいに **スキーマをバージョン管理して互換性チェック**する考え方があるよ📚 ([Confluent ドキュメント][7])

---

## 6) TypeScriptで「契約」をコード化する例🧾💙

### 6-1) まずはイベントの“封筒”を固定する📦

（CloudEventsっぽい形に寄せた、学習用の簡易版だよ😊）

```ts
export type EventType =
  | "OrderPaid"
  | "OrderShipped";

export type DomainEvent<TType extends EventType, TPayload> = Readonly<{
  // CloudEventsの考え方だと id / source / specversion / type が軸になるよ📦
  // （必須属性の考え方の参考：CloudEvents）🧠
  id: string;
  source: string;
  specversion: "1.0";
  type: TType;

  occurredAt: string; // ISO文字列（例: new Date().toISOString()）
  aggregateId: string;

  payload: TPayload;
}>;
```

CloudEventsでは必須属性の定義があるので、「封筒を固定する発想」がしやすいよ📦✨ ([Microsoft Learn][5])

---

### 6-2) payloadは「追加はOK、変更は慎重」が基本🎒

ミニECの例で `OrderPaid` を作るよ💳✨

```ts
export type OrderPaidPayloadV1 = Readonly<{
  orderId: string;
  amount: number;     // 支払い金額
  currency: "JPY";    // まずは固定でもOK（将来増えるなら注意⚠️）
}>;

export type OrderPaidV1 = DomainEvent<"OrderPaid", OrderPaidPayloadV1>;
```

---

### 6-3) “安全な進化”の例（フィールド追加）✅✨

「支払い方法」も載せたくなった！ってなった場合👇
**追加するなら optional** が強い🫶

```ts
export type OrderPaidPayloadV2 = Readonly<{
  orderId: string;
  amount: number;
  currency: "JPY";

  // ✅追加は optional にする（古いConsumerが壊れにくい）
  paymentMethod?: "Card" | "BankTransfer" | "CashOnDelivery";
}>;

export type OrderPaidV2 = DomainEvent<"OrderPaid", OrderPaidPayloadV2>;
```

この「optionalで追加」は、多くのスキーマ運用のベストプラクティスで推されがちだよ✅ ([Solace Documentation][2])

---

### 6-4) “危険な進化”の例（リネーム）❌😵‍💫

`amount` を `totalAmount` に変えたい！
→ **リネームは破壊変更**になりがち⚠️ ([Solace Documentation][2])

安全ルートはこう👇

1. `totalAmount` を optional で追加
2. Consumerを移行
3. `amount` を deprecated（ログ/メトリクスで利用状況を観測）
4. 十分時間をおいて削除🕰️

---

## 7) 「契約」を守るテスト戦略🧪📜

### 7-1) Consumer Driven Contract Testing（CDC）って考え方🤝

APIで有名だけど、**メッセージ（イベント）でも同じ発想が使える**よ📩✨

* Consumerが「こういうメッセージが来るはず」を契約として書く
* Producer側がそれを満たしてるか検証する
  みたいなイメージ🧠 ([Pactflow Contract Testing Platform][8])

「Pact」はメッセージ（イベント）にも対応してて、Consumerが期待するメッセージを契約として扱えるよ📄 ([Pact Docs][9])

---

### 7-2) いちばん現実的で強いのはコレ💪✨

* **契約（JSON Schema / AsyncAPI）を置く**📄 ([JSON Schema][3])
* **Producerは“その形で出してるか”をテスト**🧪
* **Consumerは“その形を受けられるか”をテスト**🧪
* CIで「契約の差分」を検知して、危険変更なら止める🛑🤖

---

## 8) 事故りがちなポイント集（超重要）🚨🧯

### ✅ 追加したフィールドを required にしちゃう

* 追加は基本 optional（後方互換のため）🫶 ([Solace Documentation][2])

### ✅ enumを増やしたらConsumerが落ちた

* `switch` に `default` がなくて落ちるあるある😇
* 対策：unknownを許容する・defaultでログ出す・段階導入🧯

### ✅ 同じフィールド名で“意味”を変えちゃう

* 型も名前も同じだからレビューで見落としやすい💥
* 対策：「意味変更は禁止」くらいにして、新フィールドで表現し直す✨

### ✅ PII（個人情報）をpayloadに入れてしまう

* 仕様が公開契約になるほど、取り扱いが重くなるよ⚠️
* 対策：必要最小限、参照で取れるものは入れない（第10章の復習だね🎒）

---

## 9) 演習✍️📌（安全？危険？分類しよう）

次の変更案を「安全/注意/危険」に分けて、理由も一言つけてみよう🧠✨

1. `OrderPaid` に `paymentMethod?: ...` を追加
2. `amount: number` を `amount: string` に変更
3. `currency: "JPY"` を `currency: "JPY" | "USD"` に拡張
4. `orderId` を削除
5. `amount` を `totalAmount` にリネーム（旧フィールドは削除）

---

## 10) AI活用🤖💡（互換性レビューを爆速にするプロンプト例）

コピペで使えるよ🫶✨

* 「このイベント変更は破壊的？理由と代替案（安全な移行手順）を出して」
* 「Consumer視点で、落ちる可能性があるパターンを列挙して」
* 「このpayloadの変更を、後方互換を保ったまま実現する“置き換え案”を3つ出して」
* 「このイベントの“契約として守るべき項目”チェックリストを作って」

---

## まとめ🎀✨

* イベントは**契約（公開API）**だから、壊すと利用者が落ちる💥
* “追加はoptional”が基本で、削除/変更/リネームは危険⚠️ ([Solace Documentation][2])
* 契約は **JSON Schema / AsyncAPI / CloudEvents** みたいに“仕様化”すると強い📄📦 ([JSON Schema][3])
* 仕組み（CI・テスト・契約管理）で「うっかり破壊」を止めよう🤖✅ ([Confluent ドキュメント][7])

[1]: https://www.creekservice.org/articles/2024/01/09/json-schema-evolution-part-2.html?utm_source=chatgpt.com "Evolving JSON Schemas - Part II - Creek Service"
[2]: https://docs.solace.com/Schema-Registry/schema-registry-best-practices.htm?utm_source=chatgpt.com "Best Practices for Evolving Schemas in Schema Registry"
[3]: https://json-schema.org/specification?utm_source=chatgpt.com "JSON Schema - Specification [#section]"
[4]: https://www.asyncapi.com/docs/reference/specification/v3.0.0?utm_source=chatgpt.com "3.0.0 | AsyncAPI Initiative for event-driven APIs"
[5]: https://learn.microsoft.com/en-us/azure/event-grid/namespaces-cloud-events?utm_source=chatgpt.com "Event Grid Namespaces - support for CloudEvents schema"
[6]: https://semver.org/?utm_source=chatgpt.com "Semantic Versioning 2.0.0 | Semantic Versioning"
[7]: https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html?utm_source=chatgpt.com "Schema Evolution and Compatibility for Schema Registry ..."
[8]: https://pactflow.io/what-is-consumer-driven-contract-testing/?utm_source=chatgpt.com "What is Consumer-Driven Contract Testing (CDC)? - PactFlow"
[9]: https://docs.pact.io/implementation_guides/javascript/docs/messages?utm_source=chatgpt.com "Event driven-systems"
