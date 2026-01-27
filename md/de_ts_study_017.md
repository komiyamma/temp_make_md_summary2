# 第17章 集約とトランザクション境界（守る範囲）🔒🧱

## この章でわかるようになること 🎯✨

* 「集約（Aggregate）」って何をまとめる単位なのか、ざっくり説明できる 🧩
* 「トランザクション境界」は“どこまで一気に守るか”って話だと理解できる 🧯
* 「注文🧾」と「在庫📦」を同じトランザクションに入れるべきか、理由つきで判断できる ⚖️
* 集約をまたぐ更新は「ドメインイベントでつなぐ」のが自然、が腹落ちする 🔗✨

---

## まずは超ざっくり用語 🌱

### 集約（Aggregate）って？ 🏛️

「**この中だけは、絶対にルール（不変条件）を壊さないぞ！**」って守るために、ひとまとめにした“島”みたいなもの🏝️

* 集約の中には、EntityやValue Objectがいろいろ入るよ 🧩
* **集約ルート（Aggregate Root）**が“入口”🚪
  外からは基本、ルート経由でしか触らない（近道禁止！）🙅‍♀️

### トランザクション境界って？ 🧱

「**成功か失敗かを、まとめて判定する範囲**」だよ✅❌
たとえば…

* 途中でコケたら全部なかったことにする（ロールバック）🔁
* 成功したら全部確定（コミット）💾

---

## ミニECで考える題材 🛒✨

登場人物（候補）を置くね👇

* 注文（Order）🧾
* 在庫（Inventory）📦
* 決済（Payment）💳
* 配送（Shipment）🚚
* ポイント（Point）🪙

ここで大事な問いはこれ👇
**「どれとどれを“同じ島（集約）”にする？」「どこまでを“一気に確定（トランザクション）”する？」** 🤔💭

---

## ① 集約境界の決め方：いちばん大事な3つ 🧠⚖️

### A. いっしょに守りたい“不変条件”はどれ？ 🔒

集約は「ルールを守るための単位」だよ✨
たとえば注文なら…

* 支払い済みの注文は、もう支払いできない 💳❌
* 合計金額は 0円以上 🧾✅

こういうルールを **注文集約の中で必ず守る** って感じ！

### B. “同時に変わる”ものは一緒にしたくなる 🧲

「更新がいつもセット」なら、同じ集約にすると楽なことが多いよ🧩
でもここで注意⚠️
**セットに見えても、実は別トランザクションでいい**ことが多い！（後でやる）🕰️

### C. 集約をデカくしすぎると地獄 😵‍💫

集約が巨大になると…

* ちょっと更新するだけで、いろんなデータをロックしがち 🔒
* 変更の影響範囲がでかい 💥
* 速度が落ちる 🐢

なので合言葉はこれ👇
**「守りたいルールの最小単位まで絞る」** ✂️✨

---

## ② トランザクション境界の決め方：質問はこれだけ 💡

### 「今この瞬間に、一貫してないと困る？」⏱️

同じトランザクションに入れるべきなのは👇
**“今すぐ一致してないと困る”もの** だけ！

たとえば…

* 注文の支払い確定と、注文ステータス更新（同じ注文の中）🧾💳
  → これは“今すぐ一致”してないと困ることが多い✅

一方で…

* 注文確定と、ポイント付与🪙
  → 多少遅れてもユーザーは困りにくい（「反映まで少し時間かかります」でOK）🌊
  → **イベントで後から**が自然🔗

---

## ③ 「注文🧾」と「在庫📦」は同一トランザクション？の考え方

### パターン1：同一トランザクションにする（強い一貫性）💪

向いてるのはこんなとき👇

* 「在庫が確保できないなら、注文自体を成立させたくない」🧾❌
* 失敗したら注文も在庫も“なかったことにしたい”🔁
* 在庫確保が“その場で必須”なUX（残り1個争奪戦🔥）

この場合のイメージ👇

1. 在庫を確保する📦
2. 注文を作る🧾
3. まとめてコミット💾
4. コミット後にイベントを配る📣（ここ大事！）

### パターン2：別トランザクションにする（最終的整合性）🌊

向いてるのはこんなとき👇

* 注文と在庫が別システム/別チーム/別DBっぽい 🧩🌍
* 在庫確保が少し遅れても許容できる（“確保中”表示など）⏳
* スケールしたい（在庫だけ負荷高い等）📈

この場合は👇

* 注文側：注文を確定して `OrderPlaced` を出す🧾📣
* 在庫側：イベントを受けて在庫を確保して `StockReserved` を出す📦📣
* もし在庫が無理なら `StockReservationFailed` を出して、注文に反映（キャンセル等）🧯

👉 **集約をまたぐ更新は、イベントでつなぐのが自然** 🔗✨

---

## ④ “やりがち事故”まとめ（先に潰す）🧯💥

### ❌ 事故1：アプリ層が2つの集約を直接いじって、しかも順番バラバラ

* 結果：途中失敗で片方だけ更新、データがズレる😇
* 対策：

  * 同一トランザクションにするなら「まとめてコミット」💾
  * 別トランザクションなら「イベントでつなぐ」🔗

### ❌ 事故2：集約が巨大化（注文集約の中に在庫や配送やポイントまで…）

* 結果：変更が怖い、遅い、壊れやすい😵‍💫
* 対策：不変条件の単位に絞る✂️✨

### ❌ 事故3：イベントを“DB確定前”に外へ送る

* 結果：通知だけ飛んだけどDBは失敗、みたいなホラー👻
* 対策：**コミット後にディスパッチ**が基本📣💾
  （さらに確実性が要るならOutboxで強化、は後の章でやるよ🗃️）

---

## ⑤ TypeScriptでの最小実装イメージ（集約＋イベントバッファ）🧩🫙

### 1) DomainEventとAggregateRoot 🧾

```ts
// DomainEvent: 起きた事実（過去形）📣
export type DomainEvent<TType extends string, TPayload> = Readonly<{
  eventId: string;
  occurredAt: Date;
  aggregateId: string;
  type: TType;
  payload: TPayload;
}>;

// 集約ルートのベース：イベントをためる🫙
export abstract class AggregateRoot {
  private domainEvents: DomainEvent<string, unknown>[] = [];

  protected addDomainEvent(e: DomainEvent<string, unknown>) {
    this.domainEvents.push(e);
  }

  // アプリ層が取り出して配る📤
  pullDomainEvents(): DomainEvent<string, unknown>[] {
    const pulled = this.domainEvents;
    this.domainEvents = [];
    return pulled;
  }
}
```

### 2) Order集約：支払いでイベントを出す💳📣

```ts
type OrderStatus = "Draft" | "Paid";

type OrderPaid = DomainEvent<
  "OrderPaid",
  { orderId: string; paidAmount: number }
>;

export class Order extends AggregateRoot {
  private status: OrderStatus = "Draft";

  constructor(private readonly id: string, private totalAmount: number) {
    super();
    if (totalAmount < 0) throw new Error("totalAmount must be >= 0");
  }

  pay(amount: number) {
    if (this.status === "Paid") throw new Error("already paid");
    if (amount !== this.totalAmount) throw new Error("amount mismatch");

    this.status = "Paid";

    const event: OrderPaid = {
      eventId: crypto.randomUUID(),
      occurredAt: new Date(),
      aggregateId: this.id,
      type: "OrderPaid",
      payload: { orderId: this.id, paidAmount: amount },
    };

    this.addDomainEvent(event);
  }

  getId() {
    return this.id;
  }
}
```

---

## ⑥ ユースケースの分岐：同一トランザクション or イベント連携 🔀✨

### A) 同一トランザクションにする場合（注文＋在庫をまとめて確定）💾

考え方はこれ👇

* トランザクションの中で

  * 在庫を確保📦
  * 注文を作る🧾
  * まとめて保存💾
* **成功後に**、集約からイベントを回収してディスパッチ📣

（DBトランザクションの書き方は使うライブラリで違うけど、“やることの順番”は同じだよ！）

### B) 別トランザクションにする場合（イベントでつなぐ）🌊🔗

* 注文を確定 → `OrderPlaced` を発行📣
* 在庫側がイベントで確保を試す📦
* 成功/失敗イベントで“注文側の次の動き”を決める🧭

ここまでで、さっきの合言葉が効いてくるよ👇
**「集約をまたぐ“強い一貫性”が本当に必要？」** 🤔⚖️

---

## ⑦ ちいさな判断チェックリスト ✅📝

次の質問にYESが多いほど「同一トランザクション」寄り💪

* これがズレたら“即バグ”になる？🐛💥
* 片方だけ成功してもOK？（OKなら別でもいい）🌊
* 失敗時に“全部なかったこと”が必要？🔁
* UX的に「確保中…」が許容できない？⏳❌

---

## 📝 演習（やってみよう）🎓✨

### 演習1：注文🧾と在庫📦は同一トランザクション？理由つきで！

次の2ケースで答えてね👇

1. 限定1個の商品（争奪戦🔥）
2. 在庫が十分あるデジタル商品（争奪じゃない🎧）

それぞれ、**同一トランザクション / 別トランザクション** を選んで、理由を3行で✍️✨

### 演習2：イベントでつなぐ設計を言葉で描く🗺️

`OrderPlaced` → 在庫確保 → 成功/失敗
この流れで、イベント名を3つ考えてみよう📣
（例：`StockReserved`, `StockReservationFailed` など）

---

## 🤖 AI活用（コピペで使える）✨🧠

* 「注文🧾と在庫📦を同一トランザクションにする案」と「イベントで分ける案」を、**メリデメ付きで比較**して。前提はミニEC。
* 次の不変条件を守るには、集約境界をどう切るのが良い？（不変条件を箇条書きで貼る）🔒
* 私の案の弱点を“意地悪レビュー”して！ロック競合・失敗時・運用の観点で💥🧯
* イベント名が命令形っぽくなってないかチェックして、過去形の“事実”に直して📣✅

---

## ⑧ 2026年のTypeScriptまわり小ネタ（設計に直接は関係ないけど安心材料）🧋✨

* TypeScriptは近年、Node向けのmodule設定まわりが整理・追加されていて、Nodeの挙動差分を吸収しやすくなってるよ（例：`--module node18` など）。([typescriptlang.org][1])
* TypeScriptの開発体験（エディタ表示など）も継続的に改善されてるので、型情報の“見える化”が前より楽になってきてるよ。([typescriptlang.org][2])
* さらに将来に向けて、TypeScriptコンパイラをネイティブ化して高速化する取り組み（Go移植のプレビュー）も公式に紹介されてるよ。([Microsoft Developer][3])

---

## まとめ 🎁✨

* **集約 = ルール（不変条件）を守る“島”** 🏝️🔒
* **トランザクション境界 = 成功/失敗をまとめる“守る範囲”** 🧱💾
* 集約をまたぐ更新は、まず疑う：「本当に同時確定が必要？」🤔
* 必要なら同一トランザクション、そうでなければ **ドメインイベントでつなぐ** 🔗📣

[1]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-8.html?utm_source=chatgpt.com "Documentation - TypeScript 5.8"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026?utm_source=chatgpt.com "TypeScript 7 native preview in Visual Studio 2026"
