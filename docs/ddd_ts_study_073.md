# 第73章 Repositoryの粒度：集約単位📦✨

この章はね、「Repositoryを作りすぎてコードが太る問題」を止める回だよ〜！🧁
結論からいくと **Repositoryは“集約ルート（Aggregate Root）単位”で作る** のが基本ルールです💡

（2026時点のTypeScriptまわりは、公式ドキュメントも継続更新されてて、現場はESM・型強め・テスト高速化の流れが強いよ〜🧡）([typescriptlang.org][1])

---

## 1) Repositoryの「粒度」ってなに？🍪

Repositoryは一言でいうと…

> **集約を“丸ごと”出し入れするための入口（保管庫）** 📦🔑

「粒度」っていうのは、**Repositoryを“どの大きさの単位”で作るか**ってことだよ😊

* ✅ ちょうどいい：**集約ルート単位（OrderRepositoryなど）**
* ❌ 細かすぎ：OrderLineRepository / MoneyRepository / StatusRepository…みたいに増殖
* ❌ でかすぎ：なんでも一個のRepositoryに押し込む

---

## 2) なんで「集約単位」が大事なの？💥🛡️

### ❌ Repositoryを細かくしすぎると起きること

たとえば「Orderの中のOrderLine」みたいな“子”にRepositoryを作っちゃうと…

* アプリ層が **子だけ取り出して更新** できちゃう
* その結果、**集約ルートが守るはずの不変条件**が破られる😱

DDD的には、集約って **“ルールを守るための城🏯”** なので、城の壁をすり抜ける抜け道は作っちゃダメなの🥺

---

## 3) ダメな例：OrderLineRepositoryを作ってしまう😵‍💫

```ts
// ❌ ダメ例：子（OrderLine）を直接いじれる設計
const line = await orderLineRepo.findById(lineId);

line.changeQuantity(newQty); // ← これが通るとヤバいことがある

await orderLineRepo.save(line);
```

これの何がマズいかというと…

* 「支払い後は明細変更不可🔒」みたいなルールを
  **Order（集約ルート）が守れなくなる** 可能性があるの💦

---

## 4) 良い例：OrderRepositoryだけにして、Order経由で操作する😊✨

```ts
// ✅ 良い例：集約ルート（Order）を取得して、Orderのメソッドで変更する
const order = await orderRepo.findById(orderId);
if (!order) throw new Error("Order not found");

order.changeLineQuantity(lineId, newQty); // ← ルールはOrderがチェックする

await orderRepo.save(order);
```

こうすると…

* 変更の入口が **Orderだけ** になる🚪👑
* 不変条件は **Order内で必ずチェック** できる🛡️

---

## 5) じゃあRepositoryは何個作るの？目安ルール🧭

### ✅ Repositoryを作っていいのは基本この子たち

* **集約ルート**（例：Order, Menu, Customer…）

  * 「外部から直接触っていい入口」がその子だけ、ってやつ😊

### ❌ Repositoryを作らないのが基本

* **Value Object**（Money, Quantity, Email…）
* **集約の中のEntity/VO**（OrderLineなど）
* 状態（Status）や小さな部品たち

> 「それ単体で出し入れしたい」って思ったら、
> それは **“集約の境界が違う”サイン** かもだよ👀✨

---

## 6) Repositoryのメソッド粒度：少なめが強い💪🍬

Repositoryのメソッドは、最初はこれくらいが超おすすめ👇

```ts
export interface OrderRepository {
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
}
```

### 💡 よくある誘惑：「findByCustomerId」とか増やしたい！

増やしていい時もあるけど、まずは一回立ち止まろう🫷🙂

* それは **更新に必要な取得**？（→Repositoryに置いてもOK寄り）
* それとも **一覧表示・検索・集計**？（→“読み取り専用の別口”が合うこと多い）

---

## 7) “読み取り”は別口に逃がしてOK（Query側）🔎✨

DDDでよくある整理だよ👇

* ✅ **更新系**：OrderRepository（集約の保存・取得）
* ✅ **参照系**：OrderQueryService（表示用DTOを返す）

```ts
export type OrderViewDto = {
  id: string;
  status: "Draft" | "Confirmed" | "Paid" | "Fulfilled" | "Canceled";
  totalYen: number;
  lines: Array<{ menuItemId: string; name: string; qty: number; priceYen: number }>;
};

export interface OrderQueryService {
  getById(id: string): Promise<OrderViewDto | null>;
  listByCustomerId(customerId: string): Promise<OrderViewDto[]>;
}
```

こうすると、

* 表示の都合でDTOが膨らんでもドメインが汚れない🧼✨
* “速さ優先のSQL/ORM直読み”もやりやすい🏎️💨

---

## 8) InMemory Repositoryでも「集約丸ごと」を意識しよ🧪📦

「オブジェクト参照をそのままMapに入れる」と、あとで事故りやすい（保存後に外から書き換え…）ので、**スナップショットで保存**が安全寄りだよ😊
（InMemoryの落とし穴は現場記事でもよく注意されてるよ〜）([Qiita][2])

### 例：Snapshotで保存するInMemoryOrderRepository

```ts
// domain側（例）
export type OrderSnapshot = {
  id: string;
  status: string;
  lines: Array<{ lineId: string; menuItemId: string; qty: number; priceYen: number }>;
  totalYen: number;
};

export class Order {
  // ...省略...

  toSnapshot(): OrderSnapshot {
    return {
      id: this.id.value,
      status: this.status.value,
      lines: this.lines.map(l => ({
        lineId: l.id.value,
        menuItemId: l.menuItemId.value,
        qty: l.quantity.value,
        priceYen: l.price.yen,
      })),
      totalYen: this.total.yen,
    };
  }

  static rehydrate(s: OrderSnapshot): Order {
    // snapshotからOrderを復元（Factory的な役割）
    // ...省略...
    return order;
  }
}
```

```ts
// infra側（例）
export class InMemoryOrderRepository implements OrderRepository {
  private store = new Map<string, OrderSnapshot>();

  async findById(id: OrderId): Promise<Order | null> {
    const snap = this.store.get(id.value);
    return snap ? Order.rehydrate(structuredClone(snap)) : null;
  }

  async save(order: Order): Promise<void> {
    const snap = order.toSnapshot();
    this.store.set(snap.id, structuredClone(snap));
  }
}
```

---

## 9) テスト観点：Repository粒度が正しいかチェック✅🧪

### ✅ テストで確認したいこと（粒度の章らしく）

* OrderLineを直接保存する道が存在しない（= APIがない）🚫
* 変更は必ずOrderのメソッドを通る（= ルールが漏れない）🔒
* 参照DTOはQuery側で自由に作れてる（= ドメインが汚れてない）🧼

ちなみに最近のNode/TS現場だと、Vitest採用の事例もかなり見かけるよ（ESM寄り＋高速志向）🧡([Qiita][3])

---

## 10) AIに頼むと強いプロンプト集🤖💞

### 🧠 粒度チェック（Repository増殖を止める）

* 「このドメインモデルで“集約ルート”候補を列挙して。各候補の理由も一言で。」
* 「OrderLineRepositoryを作りたくなった。代替案（Query側・設計変更含む）を3つ提案して。」

### 🛡️ ルール漏れチェック（抜け道探し）

* 「子エンティティを直接更新できてしまう“抜け道API”がないか、コードから探して指摘して。」

---

## 11) 章末ミニ演習🎓🍓

### 演習A：これはRepositoryいる？いらない？（理由も）💬

1. Order
2. OrderLine
3. Money
4. MenuItem（※注文時に存在チェックが必要）
5. OrderQueryService（表示用）

**目安の答え✨**

* 1. ✅ いる（集約ルート）
* 2. ❌ いらない（集約の中。Order経由で守る）
* 3. ❌ いらない（VO）
* 4. ✅/△ たいてい「別集約」ならいる（ただし読み取り専用ならQueryでもOK）
* 5. ✅ いる（参照は別口に分けると楽）

### 演習B：次のコードを“集約単位Repository”に直してみて🛠️

* 「OrderLineRepoで更新してる箇所」を全部
  **OrderRepoでOrder取得 → Orderのメソッドで更新 → save** に置き換える✨

---

## まとめ🎀✨

* Repositoryは基本 **集約ルート単位** 📦👑
* 子にRepositoryを作ると **不変条件が漏れる** 🔥
* “検索・一覧・集計”は **Query側** に逃がしてOK🔎
* 「Repository増殖しそう…」は、設計の見直しサイン👀

次の章（Factory）に行くと、「生成が散らばってつらい問題」も一気に片付けられるようになるよ〜！🏭💖

[1]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-5.html?utm_source=chatgpt.com "Documentation - TypeScript 5.5"
[2]: https://qiita.com/Yasushi-Mo/items/ae1b57f4f258c428caba?utm_source=chatgpt.com "【Vitest】TypeScript / Expressにおけるドメイン駆動設計の各層 ..."
[3]: https://qiita.com/Yasushi-Mo/items/21a8392cbb7e14750f4d?utm_source=chatgpt.com "【Vitest】TypeScript / Expressにおけるドメイン駆動設計の各層 ..."
