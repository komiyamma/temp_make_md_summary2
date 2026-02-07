# 第51章 Aggregate入門：変更の単位を決める📦🏯✨

この章は「集約（Aggregate）って、結局なに？😵‍💫」を **“変更の単位（＝一緒に守るルールの単位）”** としてスッと理解できるようにする回だよ〜🫶💕

---

## 0. まずは一瞬でイメージ🌟（カフェ注文で）

カフェ注文って、だいたいこう👇☕🧾

* 注文（Order）を作る
* 明細（OrderLine）を追加する
* 合計を計算する
* 状態が変わる（下書き→確定→支払い済み…）

ここで怖いのは **「整合性が崩れる」** こと😱💥
たとえば…

* 明細を増やしたのに合計が更新されてない
* 支払い済みなのに明細が変更できちゃう
* 注文が確定したのに明細が0件になれる

こういう **“絶対守りたいルール（不変条件）”** を、まとめて守るための「安全な箱」が **Aggregate（集約）** だよ🏯🛡️

---

## 1. Aggregateってなに？📦（やさしい定義）

Aggregateは、

* **Entity と Value Object のかたまり**で
* **その中のルール（不変条件）を一緒に守る単位**で
* 外から触る入口を **Aggregate Root（集約ルート）1つに絞る**

…って考え方だよ✨
「外部の人は“ルート”にしか触れないでね🙅‍♀️」が超大事！

この考え方は Domain-Driven Design: Tackling Complexity in the Heart of Software や、DDDのリファレンスでも説明されてるよ。([Fabio Fumarola][1])

---

## 2. なんでAggregateが必要なの？🥺（ないと起きる事故）

### 2-1. ルールが散らばって壊れる💔

「明細はここでチェック」「合計は別の場所で計算」「状態はUIで制御」みたいになると、だんだん…

* ルールの重複（コピペ）
* チェック漏れ
* 変更が怖くなる

が起きるよ〜😵‍💫

### 2-2. “同時に更新されるべきもの”がバラける🧩

注文の確定って、「状態だけ変える」じゃなくて、

* 明細が最低1件ある
* 合計が一致している
* 確定後は編集できない

みたいな **セットで守るべき条件** があるよね？🧾🔒
それを **1つの箱** に入れて守るのがAggregate✨

---

## 3. 集約境界（Aggregate Boundary）の決め方🧭✨

ここが第51章のメインだよ💖

### ステップ①：不変条件（絶対守るルール）を箇条書き🔒📝

まずはこれ！
「どのルールを壊したくない？」を列挙するのが最強の入口だよ💪✨

例（注文）：

* 支払い済みなら明細変更不可
* 注文確定は明細1件以上が必須
* 合計＝明細合計の一致

### ステップ②：そのルールを“同時に”守る必要があるものを囲う⭕

**同じ操作の中で必ず整合する必要があるもの**を、同じ集約に入れる感じ🌸
（逆に「後で整合すればOK」なら分けられる可能性アリ）

### ステップ③：外部から触る入口を1つ決める🚪👑

その入口が **Aggregate Root**✨
「外から触っていいのはRootだけ！」にするのがコツだよ🫶

### ステップ④：他の集約は“ID参照”にしたくなるか？🔗🪪

もしオブジェクト参照でベタベタ繋げたくなるなら、分けるのが難しくなってるサイン⚠️
（この“ID参照”は次章以降でさらに深掘りするよ！）

### ステップ⑤：小さく保つ（巨大集約にしない）🍙

集約が大きいほど、更新の衝突が増えてしんどい😵‍💫
まずは **最小** を狙うのがおすすめ！

---

## 4. 例題：カフェ注文☕🧾で境界を決めてみよう！

登場人物（候補）を並べるね👇✨

* Order（注文）
* OrderLine（明細）
* MenuItem（商品）
* Payment（支払い）
* Customer（顧客）
* Receipt（レシート）

ここで大事なのは…
**「一緒に守りたいルールは何？」** だよ🔒💕

---

## 5. 境界案を3つ出して比べる🧠⚖️（超大事！）

### 案A：Order集約＝注文＋明細（まずはこれが王道🍰）

* 集約Root：Order
* 中身：OrderLine（VO寄りでもOK）
* ルール：明細操作・合計・状態遷移（の一部）

✅いいところ

* 注文の整合性が1か所で守れる
* 実装・テストが素直で学習に最適🎓✨

⚠️注意

* PaymentやMenuItemまで入れると巨大化しやすい😱

---

### 案B：Order集約にPaymentまで入れる💳

✅いいところ

* 「支払い済みなら変更不可」みたいなルールを一発で守りやすい

⚠️つらいところ

* 支払い連携（外部API）が絡むと責務が重くなりがち
* 失敗・リトライ・二重処理などの話が一気に来る😵‍💫

👉 初学者の第51章では、**まず案AでOK** が多いよ🫶

---

### 案C：MenuItemをOrderの中に持つ🍩

⚠️危険度高め

* 商品情報は別の都合（価格改定、販売停止…）で動く
* 注文と同じ箱に入れると、依存が増えてぐちゃぐちゃになりやすい😵‍💫🌀

---

## 6. このロードマップの第51章としての結論🎯✨

**Order集約＝「注文＋明細」** を基本形にしよう☕🧾🏯
（支払い・メニューは“別の塊になりうる”として一旦距離を置く）

---

## 7. 手を動かす：最小のOrder集約を作る🛠️💖

ここでは「集約っぽさ」を体に入れるために、**最小の骨格** を作るよ✨
（後の章でどんどん強化していく前提だよ〜🫶）

ポイントはこれ👇

* Root（Order）だけが明細を変更できる
* 明細配列を外に“生”で渡さない（改ざん防止🔒）
* ルールはメソッドの中に閉じ込める

```ts
// domain/order/Order.ts

export class Order {
  private constructor(
    private readonly id: string,
    private status: "Draft" | "Confirmed",
    private lines: OrderLine[],
  ) {}

  static create(id: string): Order {
    return new Order(id, "Draft", []);
  }

  // 外から明細配列を直接いじらせない：コピーして返す🛡️
  getLines(): readonly OrderLine[] {
    return [...this.lines];
  }

  addLine(menuItemId: string, quantity: number, unitPrice: number) {
    this.ensureDraft();

    const newLine = OrderLine.create(menuItemId, quantity, unitPrice);

    // 例：同一商品はまとめる（ルールは好きに調整OK）✨
    const idx = this.lines.findIndex(l => l.menuItemId === menuItemId);
    if (idx >= 0) {
      this.lines[idx] = this.lines[idx].increase(quantity);
      return;
    }

    this.lines.push(newLine);
  }

  confirm() {
    this.ensureDraft();
    if (this.lines.length === 0) {
      throw new Error("明細が0件の注文は確定できません");
    }
    this.status = "Confirmed";
  }

  private ensureDraft() {
    if (this.status !== "Draft") {
      throw new Error("確定後の注文は変更できません");
    }
  }
}

export class OrderLine {
  private constructor(
    public readonly menuItemId: string,
    public readonly quantity: number,
    public readonly unitPrice: number,
  ) {}

  static create(menuItemId: string, quantity: number, unitPrice: number) {
    if (quantity <= 0) throw new Error("数量は1以上にしてください");
    if (unitPrice < 0) throw new Error("単価は0以上にしてください");
    return new OrderLine(menuItemId, quantity, unitPrice);
  }

  increase(delta: number): OrderLine {
    if (delta <= 0) throw new Error("増分は1以上にしてください");
    return new OrderLine(this.menuItemId, this.quantity + delta, this.unitPrice);
  }

  subtotal(): number {
    return this.quantity * this.unitPrice;
  }
}
```

このコードの“DDDっぽい核心”は、ここだよ👇💖

* **Orderが変更の入口**（Root）
* **OrderLineは外から勝手にいじれない**
* **不変条件（数量1以上など）は生成時に守る**

---

## 8. テストで「集約が守るべきルール」を固定する🧪🔒

テストは「仕様の釘打ち」だよ📌💖
（第58章で本格的にやるけど、第51章でも軽く体験しよ！）

ちなみに最近のテスト環境としては、Vitest 4系が広く使われていて、2026年2月時点で 4.0.18 が安定版、4.1はbetaも動いてるよ。([vitest.dev][2])
（もちろん他でもOKだけど、学習テンポが出やすい！）

```ts
// test/order/Order.spec.ts
import { describe, it, expect } from "vitest";
import { Order } from "../../domain/order/Order";

describe("Order aggregate", () => {
  it("明細0件の注文は確定できない", () => {
    const order = Order.create("order-1");
    expect(() => order.confirm()).toThrow();
  });

  it("下書きなら明細を追加できる", () => {
    const order = Order.create("order-1");
    order.addLine("menu-espresso", 1, 500);
    expect(order.getLines().length).toBe(1);
  });

  it("確定後は明細追加できない", () => {
    const order = Order.create("order-1");
    order.addLine("menu-espresso", 1, 500);
    order.confirm();
    expect(() => order.addLine("menu-latte", 1, 600)).toThrow();
  });
});
```

---

## 9. AI活用（設計で迷った時の“質問テンプレ”）🤖💬✨

### 9-1. 不変条件の洗い出し用🔒

「カフェ注文ドメインで、Orderが守るべき不変条件を10個出して。
それぞれ“いつ守るか（生成時/操作時）”も添えて。」

### 9-2. 境界案の比較用⚖️

「Order/Payment/MenuItem をどう集約に分ける案がある？
“同時に整合が必要か”を基準に、3案出してメリデメ比較して。」

### 9-3. コードレビュー用👀

「このOrder集約コード、外から改ざんできる抜け道がないか見て。
配列の公開や、状態遷移の穴を重点的にチェックして。」

---

## 10. よくある落とし穴（第51章で先に潰す）😂⚠️

* **集約の中身を外にそのまま返す**（配列・オブジェクトが改ざんされる）😱
* **Root以外を外部から更新できる設計**（“入口1つ”が崩れる）🚪💥
* **なんでも同じ集約に入れて巨大化**（変更衝突・複雑化）🐘
* **“DBテーブル単位”で集約を切る**（ルール単位じゃない）🧱
* **集約外参照をオブジェクトで持つ**（絡まってほどけない）🕸️

---

## 11. ミニ演習（5〜10分）🎓💖

次のルールを読んで、「どこまでをOrder集約に入れるか」考えてみてね🧠✨

* 注文確定後は明細変更できない
* 商品の価格は、注文時点の価格を保持したい（後で価格改定があっても）
* レシートは、支払い完了後に作られる

💡ヒント

* 「注文時点の価格」は **OrderLine側に“unitPrice”として保持** するのが気持ちいいよ🍰
* Receiptは「後で作る」なら、Orderとは別でも成り立ちやすい📮✨

---

## 12. 理解チェック✅💯（答えつき）

1. Aggregateを作る目的は？
   → **一緒に守る不変条件を、1つの変更単位で守るため**🔒

2. 外部から触っていいのは基本なに？
   → **Aggregate Rootだけ**🚪👑

3. 集約境界を決める第一歩は？
   → **不変条件の列挙**📝✨

4. 集約を巨大にしすぎると何がつらい？
   → **変更衝突・複雑化・テスト増えすぎ**😵‍💫

5. 「注文」と「商品マスタ」を同じ集約に入れたくなったら？
   → **依存が増えすぎサイン**かも。価格は“注文時点の値”として注文側に保持、商品は別塊を検討🍩🔗

---

## 13. 最新ツール事情メモ（さらっと）🧡

* TypeScriptは 5.9 系のリリースノートが公開されてるよ（Node向けのオプションなども整理が進んでる）([TypeScript][3])
* Node.jsは 2026-02 時点で v24 が Active LTS、v25 が Current（最新系）だよ([Node.js][4])

---

次の第52章は「Aggregate Root：外部の入口は1つ🚪👑」で、いま作った“入口1つ”をもっと強固にするよ〜！💖🏯✨

[1]: https://fabiofumarola.github.io/nosql/readingMaterial/Evans03.pdf?utm_source=chatgpt.com "Domain-driven design: Tackling complexity in the heart of ..."
[2]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[4]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
