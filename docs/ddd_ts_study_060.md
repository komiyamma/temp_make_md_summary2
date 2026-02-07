# 第60章 中間まとめ：戦術DDDの核3点（VO/Entity/Agg）🎒✨🏯

ここまでで、あなたはもう「DDDっぽい用語を知ってる人」じゃなくて、**“ルールを安全にコードへ閉じ込められる人”**になってます👏🥳
この章は、その力を**キレイに整理して、次のアプリ層（第61章〜）へスムーズに渡す**ための「まとめ回」だよ〜🧠🧡

---

## 0️⃣ まずは“最新メモ”🗞️✨（2026-02-07時点）

* TypeScriptの最新安定版は **5.9.3** 🧩（npmの`typescript`パッケージでも最新が5.9.3になってるよ）([npm][1])
* **TypeScript 6.0** は、公式の反復計画（Iteration Plan）で **Betaが2026-02-10、安定版が2026-03-17予定**になってるよ📅✨([GitHub][2])
* 5.9は「import defer」などの機能や、セットアップ/IDE体験の改善が入ってる（公式アナウンスあり）🪄([Microsoft for Developers][3])

※この教材のコードは、今の安定版（5.9系）で普通に書ける形で進めるね☺️

---

## 1️⃣ 戦術DDDの核3点って、結局なに？🌸

### 💎 Value Object（VO）

* **「値そのもの」**が主役（同一性IDなし）
* だいたい **不変（immutable）**で、**生成時に検証**して、**等価性は値で比較**🧊✨

👉 例：`Money`、`Email`、`Quantity`、`OrderId`（IDでも“値”として扱うならVO）💴✉️🆔

---

### 🪪 Entity

* **「同一性（ID）」**が主役（中身が変わっても同じ子）
* ルールは **自分のメソッドで自衛**して守る🛡️

👉 例：`Order`（注文は同じ注文として追跡したい）☕🧾

---

### 🏯 Aggregate（集約）

* **“いっしょに整合性を守る”まとまり**（境界）
* 外からの更新は **Aggregate Rootだけが入口** 🚪👑
* その目的は **集約内の不変条件（整合性ルール）を守る**こと🔒✨([Microsoft Learn][4])

---

## 2️⃣ 今日のゴール：ルールの「住所録」を作る📒🏠✨

DDDで一番迷うのがここ👇

> **「このルール、どこに書けばいいの？😵‍💫」**

答えは、“ルールの種類”で決めるのが最強だよ💪✨
この章では、**ルールを4種類に分けて住所（配置）を決める**よ〜📌

---

## 3️⃣ ルール分類4つ📦（ここが超重要！）

### A) 形式・入力のルール（UIっぽい）⌨️🧼

例：空欄禁止、桁数、メール形式、数値かどうか
✅ 主に **入力側（UI/DTO）**で早めに弾く
ただし…👇

### B) ドメインの“絶対ルール”（不変条件）🔒

例：「支払い後は明細変更不可」
✅ **VO / Entity / Aggregate** で必ず守る（最後の砦🔥）

### C) 手順のルール（ユースケースの流れ）🎬

例：「注文作成→保存→通知」
✅ **アプリ層（Application Service）**の役割（次の章）🎯

### D) 外部都合のルール（DB/API/メール送信）🌍📡

✅ **infra側**に隔離（ドメインに持ち込まない）🧱

---

## 4️⃣ いちばん大事な1枚絵（ミニ図）🗺️✨

（※文字図でごめんね！でも効果バツグン✊）

```text
[外の世界]  UI / API / DB / 外部サービス
    │
    ▼
[Application]  ユースケースの手順（Command/Query）
    │
    ▼
[Domain]  ルールの本丸🏯
  - Value Object   💎（値のルール）
  - Entity         🪪（同一性と振る舞い）
  - Aggregate      🏯（整合性の境界、入口はRootだけ🚪👑）
```

---

## 5️⃣ 「どのルールをどこに置く？」最短判定チャート⚡🧠

迷ったら、この順でYES/NOしてね😉

1. **そのルールは“値単体”で完結する？**（金額、数量、メール…）
   → YES 👉 **VO** 💎

2. **同一性（ID）で追跡する対象？**
   → YES 👉 **Entity** 🪪

3. **複数オブジェクトの整合性を“一緒に”守る必要がある？**
   （例：注文の状態×明細×合計）
   → YES 👉 **Aggregate（Rootが守る）** 🏯

4. **手順（取得→操作→保存）っぽい？**
   → YES 👉 **Application** 🎬（次の章！）

---

## 6️⃣ 例題（カフェ注文）で “ルール住所録” を作ろう☕🧾📒

ここからが本番〜！🥳
いったん、よくあるルールを並べて、住所を決めるよ🧠✨

| ルール              | 住所（守る場所）                             | 理由          |
| ---------------- | ------------------------------------ | ----------- |
| 金額は0以上           | Money（VO）💎                          | 値単体で完結      |
| 数量は1以上           | Quantity（VO）💎                       | 値単体で完結      |
| 注文明細は空にできない（確定時） | Order（Aggregate Root）🏯              | “注文の整合性”    |
| 支払い後は明細変更不可      | Order（Aggregate Root）🏯              | 状態×操作の整合性   |
| 合計は明細の合算と一致      | Order（Aggregate Root）🏯              | 集約内で一貫性     |
| 注文IDは外から変更不可     | OrderId（VO）💎 + Order（Entity/Root）🪪 | 同一性を守る      |
| 「注文作成→保存」手順      | Application 🎬                       | 手順はドメインじゃない |
| DB保存方法           | infra 🌍                             | 外部都合        |

👉 **この表が作れたら、戦術DDDの基礎は完成**だよ🎉✨

---

## 7️⃣ “集約が城🏯”になってるかチェック✅🛡️

集約はよく「城」って言われるんだけど、ほんとに城になってる？😂🏯
次のチェックを全部YESにできたら強いよ💪✨

### 🏯 Aggregate Root チェック10

* [ ] Root以外を外から直接いじれない（配列とか参照が漏れてない）🫣
* [ ] `setStatus()`みたいな雑な更新口がない🚫
* [ ] 状態遷移がメソッドになってる（`confirm()` / `pay()` など）🚦
* [ ] 不変条件が **“必ず守られる場所”**にある🔒
* [ ] 例外メッセージが「何がダメか」分かる😿➡️🙂
* [ ] 集約外参照は基本ID（他集約を丸ごと抱えない）🔗🪪
* [ ] 1ユースケースで複数集約を“同時に整合”させようとしてない（危険信号）⚠️
* [ ] 合計など導出値がズレない（更新忘れない仕組み）🧮
* [ ] テストが「遷移×操作」の組み合わせを守ってる🧪
* [ ] “大きすぎる集約”になってない（責務がモリモリじゃない）🍙💦

※「入口はRootだけ」は、MicrosoftのDDD解説やMartin Fowlerの説明でも基本として書かれてるよ🧠📌([Microsoft Learn][4])

---

## 8️⃣ ミニ実装例：Order集約の“安全な入口”🚪👑（雰囲気だけ掴もう✨）

「こういう雰囲気だよ〜」っていう短いやつね☺️
（細部は第56〜58章で作った形に合わせてOK！）

```ts
// 💎 Value Object
export class Money {
  private constructor(private readonly yen: number) {}

  static ofYen(yen: number): Money {
    if (!Number.isInteger(yen)) throw new Error("金額は整数でね🙏");
    if (yen < 0) throw new Error("金額は0以上だよ💴");
    return new Money(yen);
  }

  add(other: Money): Money {
    return Money.ofYen(this.yen + other.yen);
  }

  get value(): number {
    return this.yen;
  }

  equals(other: Money): boolean {
    return this.yen === other.yen;
  }
}

type OrderStatus = "Draft" | "Confirmed" | "Paid" | "Canceled";

// 🏯 Aggregate Root（Entityでもある）
export class Order {
  private status: OrderStatus = "Draft";
  private readonly lines: { price: Money; qty: number }[] = [];

  addLine(price: Money, qty: number): void {
    if (this.status !== "Draft") throw new Error("確定後は明細いじれないよ😵‍💫");
    if (qty <= 0) throw new Error("数量は1以上だよ☕");
    this.lines.push({ price, qty });
  }

  confirm(): void {
    if (this.lines.length === 0) throw new Error("明細なしで確定はできないよ🧾");
    if (this.status !== "Draft") throw new Error("今は確定できない状態だよ🚦");
    this.status = "Confirmed";
  }

  total(): Money {
    return this.lines.reduce(
      (sum, l) => sum.add(Money.ofYen(l.price.value * l.qty)),
      Money.ofYen(0),
    );
  }
}
```

ポイントはこれだけ覚えてね🧡

* **値のルールはVOへ💎**
* **状態×操作のルールは集約Rootへ🏯**
* **外からの操作はRootメソッドに限定🚪👑**

---

## 9️⃣ AIの使いどころ（この章バージョン）🤖🪄

### 🧠 ルール住所録を作るプロンプト

「カフェ注文ドメインの不変条件を10個列挙して、VO/Entity/Aggregateのどこで守るべきか理由つきで表にして。前提：支払い後は明細変更不可、他集約参照はIDが基本。」

### 🧪 テスト観点を増やすプロンプト

「Order集約の状態（Draft/Confirmed/Paid/Canceled）×操作（addLine/confirm/pay/cancel）の許可/禁止マトリクスを作って。禁止ケースは“例外メッセージ案”も付けて。」

### 🧹 アンチパターン臭チェック

「このOrder集約のコードを見て、DDDの観点で危ない点（参照漏れ、setter、巨大化、他集約直参照など）を優先度つきで指摘して。」

---

## 🔟 小テスト（理解チェック）🎓✨

### Q1：`Money`の「0以上」はどこで守る？

👉 **VO（Money）💎**（値単体で完結だから）

### Q2：「支払い後は明細変更不可」はどこ？

👉 **Aggregate Root（Order）🏯**（状態×操作の整合性）

### Q3：「注文作成→保存→通知」はどこ？

👉 **Application 🎬**（手順だから）

---

## 11️⃣ 次（第61章〜）にどう繋がる？🌈🎬

ここまでで、あなたのドメインはこうなってるはず👇

* ドメイン（VO/Entity/Agg）が **ルールを守る装置**になった🏯🔒
* 次は、その装置を使って
  **「入力 → 取得 → 操作 → 保存」**の“ユースケース”を組み立てる🎬✨

つまり…次章は「ドメインを汚さずに、アプリを動かす係」だよ〜🧑‍🍳💕

---

## おまけ：開発者向け安全メモ（超短め）🛡️🧯

最近も npm で“タイポスクワッティング（名前が似た悪意パッケージ）”系の被害が報告されてるから、インストール前にパッケージ名・作者・DL数をサッと見るクセはおすすめ🥺🙏([BleepingComputer][5])

---

必要なら、この章の内容をあなたの今の章（第56〜59章で作ったOrder集約）に合わせて、**「あなたのコード版：ルール住所録」**を一緒に作ることもできるよ📒✨（コード貼ってくれたら、そこに合わせて表とテスト観点を作るね🧪💕）

[1]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[2]: https://github.com/microsoft/TypeScript/issues/62785?utm_source=chatgpt.com "Iteration Plan for Typescript 5.10/6.0 ? · Issue #62785 ..."
[3]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
[4]: https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model?utm_source=chatgpt.com "Designing a microservice domain model - .NET"
[5]: https://www.bleepingcomputer.com/news/security/malicious-npm-packages-fetch-infostealer-for-windows-linux-macos/?utm_source=chatgpt.com "Malicious NPM packages fetch infostealer for Windows ..."
