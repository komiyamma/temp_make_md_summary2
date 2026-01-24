# 第6章　CQSの基本（更新と参照は混ぜない）🔀✅✨

この章は、CQRSの前にやる“準備運動”だよ〜！🏃‍♀️💨
いきなり「CommandHandler！QueryService！」って分ける前に、まずは **「同じクラスの中でもいいから、更新と参照は混ぜない」** を体に染み込ませます😊🧠✨

---

### 今日のゴール🎯💡

できるようになることは3つだけ！🙌

1. **Command（更新）** と **Query（参照）** を見分けられる👀✅
2. メソッド命名で **「これは更新」「これは参照」** が伝わるようにできる✍️✨
3. 「読み取りのつもりが更新してた😱」事故を防げる🛡️💥

---

## 1) まずCQSってなに？（CQRSとの違いも軽く）🙂📚

### CQS（Command Query Separation）って？

**1つのメソッドは、どっちかにしようね**ってルールだよ😊

* **Command**：状態を変える（副作用あり）🧾➡️🗄️
* **Query**：情報を返すだけ（副作用なし）🔎➡️📋

> “副作用”っていうのは、DB更新・配列更新・ファイル書き込み・外部API呼び出し・状態変更…みたいな「世界が変わる」やつね🌍⚡

### CQRSとの違い（超ざっくり）🌱

* **CQS**：メソッド単位の「混ぜない」ルール
* **CQRS**：クラス/層/モデルまで「分けて作る」設計スタイル🧩✨

この章は **CQS** に集中だよ〜😊✨

---

## 2) Command / Query の見分け方👀✨（迷ったらこれ！）

### まずは超シンプル判定✅

**質問：そのメソッド、呼んだあと世界は変わる？** 🌍

* 変わる → **Command** 🧾
* 変わらない → **Query** 🔎

### ありがちな例（学食モバイル注文）🍙📱

| やりたいこと                   | 判定         | 理由             |
| ------------------------ | ---------- | -------------- |
| 注文する（PlaceOrder）         | Command 🧾 | 注文が増える（状態が変わる） |
| 支払う（PayOrder）            | Command 💳 | ステータスが変わる      |
| 注文一覧を見る（GetOrderList）    | Query 🔎   | 表示するだけ         |
| 売上集計を見る（GetSalesSummary） | Query 📊   | 計算して返すだけ       |

---

## 3) 命名のコツ（ここが地味に超効く）✍️✨😆

### Commandの命名✅（動詞で“やる”感じ）

* `placeOrder`
* `payOrder`
* `cancelOrder`

**コツ：** “Get”とか“Find”は使わない🙅‍♀️（更新なのに読み取りっぽくなる！）

### Queryの命名✅（get / find / list / search など）

* `getOrderList`
* `findOrderById`
* `searchOrders`

---

## 4) ハンズオン：同じクラス内で「混ぜない」整理🧹✨

ここでは第3〜4章の「ごちゃごちゃサービス」から、**メソッド単位で分けて**スッキリさせます😊🧼

---

### 4-1) ダメな例：読み取りが“こっそり更新”してる😱💥

よくある事故：**一覧取得（Query）のつもりが、閲覧日時を更新してた**とか…😭

```ts
// OrderService.ts（ダメな例😱）
type OrderStatus = "ORDERED" | "PAID";

type Order = {
  id: string;
  status: OrderStatus;
  totalYen: number;
  lastViewedAt?: Date; // ← これが事故ポイント💣
};

export class OrderService {
  private orders: Order[] = [];

  placeOrder(totalYen: number): string { // Commandっぽい✅
    const id = crypto.randomUUID();
    this.orders.push({ id, status: "ORDERED", totalYen });
    return id;
  }

  getOrderList(): Order[] { // Queryのつもり…😇
    // 😱😱😱 ここで更新してる！！！（副作用）
    for (const o of this.orders) {
      o.lastViewedAt = new Date();
    }
    return this.orders;
  }
}
```

これ、何がヤバいかというと…👇😵‍💫

* 「一覧見ただけ」なのに **状態が変わる**
* 将来DB保存になったら、**GETしただけでUPDATE** が走る可能性もある😱
* テストもしんどい（時間が絡むし、参照しただけで変わる）🧪💦

---

### 4-2) まずは“読み取りはDTOで返す”にする🎁✨

Queryの返り値は **ドメインそのもの（Order）** じゃなくて、
**画面に必要な形（DTO）** にして返すと事故が減るよ😊✨

```ts
// dto.ts
export type OrderListItemDto = {
  id: string;
  status: "ORDERED" | "PAID";
  totalYen: number;
};
```

---

### 4-3) 改善：Queryは副作用ゼロ、Commandは更新だけ✅✨

```ts
// OrderService.ts（改善版✨）
type OrderStatus = "ORDERED" | "PAID";

type Order = {
  id: string;
  status: OrderStatus;
  totalYen: number;
};

export type OrderListItemDto = {
  id: string;
  status: OrderStatus;
  totalYen: number;
};

export class OrderService {
  private orders: Order[] = [];

  // ✅ Command：状態を変える（副作用OK）
  placeOrder(totalYen: number): string {
    const id = crypto.randomUUID();
    this.orders.push({ id, status: "ORDERED", totalYen });
    return id; // ※ID返すのはよくある実務スタイル👍
  }

  // ✅ Command：状態を変える（副作用OK）
  payOrder(orderId: string): void {
    const order = this.orders.find(o => o.id === orderId);
    if (!order) throw new Error("注文が見つかりません");
    if (order.status !== "ORDERED") throw new Error("未注文以外は支払えません");

    order.status = "PAID";
  }

  // ✅ Query：読むだけ（副作用ゼロ）
  getOrderList(): OrderListItemDto[] {
    return this.orders.map(o => ({
      id: o.id,
      status: o.status,
      totalYen: o.totalYen,
    }));
  }
}
```

ポイントはこれ！👇✨

* **Queryは“読むだけ”**（更新しない）🧼
* **QueryはDTOで返す**（中身を直接触らせない）🎁
* **Commandは更新する**（こっちは堂々と世界を変えてOK）🧾⚡

---

## 5) ミニ演習：それ、Command？Query？📝✨😆

次のメソッド名を見て、どっちか当ててみて〜！🎯

1. `getTodaySalesSummary()`
2. `updateMenuPrice(menuId, newPrice)`
3. `findOrderById(orderId)`
4. `createOrderAndReturnList()` ← これ地雷臭しない？😆💣

答え（こっそり）👇🙈

* 1 Query / 2 Command / 3 Query / 4 **混ぜてる**（CQS違反の匂いが濃い）

---

## 6) 「混ぜたくなる」瞬間の対処法🧯✨

### ✅ パターンA：Commandの結果、画面に返すものが欲しい😵‍💫

例：注文したら「注文内容」をすぐ表示したい！

**おすすめ順**👇

1. **CommandはIDだけ返す** → そのあとQueryで取る（CQS的に最強）🏆
2. Commandが “最小限の結果” を返す（例：`orderId`、`newStatus`）🪶
3. Commandでドメイン全部返す（最後の手段）😇

> CQRSに進むと、だいたい「Commandの後にQuery」スタイルが気持ちよくなるよ😊✨

---

### ✅ パターンB：Queryでキャッシュ更新したい（副作用では？）🤔

キャッシュやメトリクス更新は「ビジネス状態じゃない」ことも多いけど、
初心者のうちは混乱しやすいから…

* **まずはQueryに書き込みを入れない**（安全第一🛡️）
* 必要になったら「Read側の仕組み」として切り出す（後の章でやるやつ！）📦✨

---

## 7) AI活用コーナー🤖💖（CQSはAIにめっちゃ相性いい！）

### プロンプト例1：Command/Query判定をAIにやらせる👀

「このメソッドはCommand/Queryどっち？理由も。副作用があるなら指摘して」
って貼り付けるだけで、事故発見率が上がるよ〜✅✨

### プロンプト例2：命名案を大量に出す✍️

「`注文を確定する` のCommand名を英語で10個、動詞始まりで」
「`注文一覧を取得` のQuery名を get/find/list 系で10個」

### プロンプト例3：CQS違反のにおい検知🚨

「このクラスをCQS観点でレビューして。混ざってるメソッドを列挙して、分割案も出して」

---

## 8) 章末チェックリスト✅✅✅（これ通ればOK！）

* [ ] Queryが **DB/配列/オブジェクト** を書き換えてない🧼
* [ ] Queryは **DTOで返して**、ドメインを直接返してない🎁
* [ ] Commandは **やることが名前から伝わる**（動詞スタート）✍️
* [ ] 「Commandの後にQueryで取り直す」流れがイメージできる🔁✨

---

## 9) 最新事情ちょこっと（2026年1月時点）🗓️✨

* TypeScriptの安定版は **5.9.3**（npmの “latest”）だよ📦✨ ([NPM][1])
* 5.9 のリリースノートには `--module node20` みたいな **Node向けオプション**の話も出てきてて、モジュールまわりはどんどん整ってきてるよ〜🧩 ([typescriptlang.org][2])
* Nodeは **v24 が Active LTS**、v25 が Current という並び（2026-01-12/19更新）📌 ([nodejs.org][3])
* 直近だと **Node 24.13.0（LTS）のセキュリティリリース**も出てるよ🛡️ ([nodejs.org][4])
* さらに先の話だけど、TypeScriptは **6.0（ブリッジ）→7.0（ネイティブ移行）** の流れが公式ブログで語られてるよ🚀 ([Microsoft for Developers][5])

---

## 次章の予告🎬✨

第6章で「同じクラス内でも混ぜない」ができたら、次はいよいよ…

**第7章：CQRSの最小形（CommandHandler / QueryService）** 🧩✨
“クラスとして分ける”に進みます😊💕

必要なら、この第6章のハンズオンを **あなたの第3〜4章のコード構成に寄せた形（ファイル分割・関数名の統一）** に整えたバージョンでも書くよ〜！📁✨

[1]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[4]: https://nodejs.org/en/blog/release/v24.13.0?utm_source=chatgpt.com "Node.js 24.13.0 (LTS)"
[5]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
