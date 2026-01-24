# 第4章　まずは“分けない版”を作る②（増やして苦しむ）😵‍💫📌

この章はひとことで言うと👇
**「機能追加したら、1つのサービスが“ぐちゃぐちゃ”になっていくのを体験する回」**です😂🌀
（ここでちゃんと苦しんでおくと、あとでCQRSが気持ちよくなります✨）

---

## この章のゴール🎯✨

最後にあなたがこう言えたら勝ち！🏆

* 「更新（Command）と参照（Query）が混ざると、変更が怖い…😨」
* 「条件分岐が増えるほど、テストがしんどい…🧪💥」
* 「“どこを直せばいいか”探す時間が増えた…🔍⏳」

---

## 0) まずは“前章の続き”を用意しよ🧰

前章（第3章）で、だいたいこんな **雑な OrderService** を作ってる想定で進めるよ😊
（もし無ければ、これを `src/OrderService.ts` に置いてスタートでOK！）

```ts
// src/OrderService.ts
export type OrderStatus = "ORDERED" | "PAID" | "CANCELED";

export type OrderItem = {
  menuId: string;
  name: string;
  unitPrice: number;
  qty: number;
};

export type Order = {
  id: string;
  items: OrderItem[];
  total: number;
  status: OrderStatus;
  createdAt: Date;
};

export type PlaceOrderInput = {
  items: OrderItem[];
};

export class OrderService {
  private orders: Order[] = [];

  placeOrder(input: PlaceOrderInput): Order {
    if (input.items.length === 0) throw new Error("items required");

    const total = input.items.reduce((sum, x) => sum + x.unitPrice * x.qty, 0);

    const order: Order = {
      id: "ord_" + Math.random().toString(16).slice(2),
      items: input.items,
      total,
      status: "ORDERED",
      createdAt: new Date(),
    };

    this.orders.push(order);
    return order;
  }

  listOrders(): Order[] {
    // 本当はDTOにするけど、今は雑でOK😆
    return [...this.orders];
  }
}
```

---

## 1) 機能追加①：支払い（Pay）を足す💳✨

要件👇

* 注文（ORDERED）のものだけ支払える
* 支払ったら PAID になる
* 支払い方法（カード/現金/学食ポイント…）を持ちたい

まずは雑に、Order にフィールド追加しちゃう😇

```ts
export type PaymentMethod = "CARD" | "CASH" | "POINTS";

export type Order = {
  // ...既存
  paidAt?: Date;
  paymentMethod?: PaymentMethod;
};
```

そして `payOrder` 追加👇

```ts
payOrder(orderId: string, method: PaymentMethod): Order {
  const order = this.orders.find(x => x.id === orderId);
  if (!order) throw new Error("order not found");

  if (order.status === "CANCELED") throw new Error("canceled order can't be paid");
  if (order.status === "PAID") throw new Error("already paid");

  // 支払い処理っぽい何か（本当は外部サービスだよね…）
  order.status = "PAID";
  order.paymentMethod = method;
  order.paidAt = new Date();

  return order;
}
```

### 💥つらポイント①：「支払い」なのに、OrderService がどんどん太る🍔➡️🐘

* しかもこの “支払い処理っぽい何か” は、いずれ外部連携になってさらに地獄👹

### AI活用🤖💬（おすすめプロンプト）

* 「`payOrder` を追加して。状態がCANCELED/PAIDの時はエラー。返り値は更新後のOrder」
* 「例外メッセージはUI表示に使うので、短くわかりやすくして」

---

## 2) 機能追加②：キャンセル（Cancel）を足す🙅‍♀️🧾

要件👇

* 支払い後（PAID）はキャンセル不可
* 注文中（ORDERED）だけキャンセルOK

```ts
cancelOrder(orderId: string): Order {
  const order = this.orders.find(x => x.id === orderId);
  if (!order) throw new Error("order not found");

  if (order.status === "PAID") throw new Error("paid order can't be canceled");
  if (order.status === "CANCELED") throw new Error("already canceled");

  order.status = "CANCELED";
  return order;
}
```

### 💥つらポイント②：状態遷移のルールが “あちこちに散る”🧩🌀

* payOrder にも cancelOrder にも **状態チェック**がいる
* ルール追加のたびに、両方直す可能性が出てくる😵‍💫

---

## 3) 機能追加③：検索条件を足す（ここが地獄の入口）🔎😇➡️👹

要件👇

* ステータスで絞り込み（ORDERED/PAID/CANCELED）
* 最低金額で絞り込み（例：total >= 800）
* 期間で絞り込み（from/to）
* ついでに並び替えも（新しい順）

「`listOrders()` を強化すればいいよね！」ってなるよね？😆
…そしてこうなる👇

```ts
export type OrderSearch = {
  status?: OrderStatus;
  minTotal?: number;
  from?: Date;
  to?: Date;
};

listOrders(search?: OrderSearch): Order[] {
  let result = [...this.orders];

  if (search?.status) {
    result = result.filter(x => x.status === search.status);
  }

  if (typeof search?.minTotal === "number") {
    result = result.filter(x => x.total >= search.minTotal);
  }

  if (search?.from) {
    result = result.filter(x => x.createdAt >= search.from!);
  }

  if (search?.to) {
    result = result.filter(x => x.createdAt <= search.to!);
  }

  // 並び替え（新しい順）
  result.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

  return result;
}
```

### 💥つらポイント③：参照ロジックが増えるほど “更新ロジックのそば” に置かれて事故る💥

* 「検索条件を追加しただけ」のつもりが、OrderService 全体に影響しそうな恐怖😨
* この `listOrders` は **Query（参照）**なのに、同じクラスに **Command（更新）** も入ってる…（混線中🚧）

---

## 4) 機能追加④：売上集計（Summary）を足す📊✨

要件👇

* 今日の売上合計（PAIDだけ）
* 支払い方法別の件数
* 人気メニューTop3（ざっくり）

OrderService に **getSalesSummary** を追加！…すると👇

```ts
export type SalesSummary = {
  salesTotal: number;
  paidCount: number;
  byMethod: Record<string, number>;
  topMenus: { menuId: string; name: string; count: number }[];
};

getSalesSummary(today: Date): SalesSummary {
  const isSameDay = (a: Date, b: Date) =>
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate();

  const paidOrders = this.orders.filter(x => x.status === "PAID" && isSameDay(x.createdAt, today));

  const salesTotal = paidOrders.reduce((sum, x) => sum + x.total, 0);

  const byMethod: Record<string, number> = {};
  for (const o of paidOrders) {
    const key = o.paymentMethod ?? "UNKNOWN";
    byMethod[key] = (byMethod[key] ?? 0) + 1;
  }

  const menuCount = new Map<string, { menuId: string; name: string; count: number }>();
  for (const o of paidOrders) {
    for (const item of o.items) {
      const key = item.menuId;
      const cur = menuCount.get(key) ?? { menuId: item.menuId, name: item.name, count: 0 };
      cur.count += item.qty;
      menuCount.set(key, cur);
    }
  }

  const topMenus = [...menuCount.values()].sort((a, b) => b.count - a.count).slice(0, 3);

  return { salesTotal, paidCount: paidOrders.length, byMethod, topMenus };
}
```

### 💥つらポイント④：「画面が欲しい形（集計）」が増えるほど、サービスが“何でも屋”になる🧙‍♂️🧹

* 集計は完全に **Queryの世界** なのに、Commandと同居してカオス
* 「集計項目ちょっと追加して」→ `OrderService` を触る → ついでに payOrder に触る → 事故る、が起きがち😇💥

---

## 5) 仕上げ：ログ・通知・例外メッセージも足してみる📣🧾

よくある追加要望👇

* 「支払いしたらログ出して」
* 「キャンセルしたら通知キューに積んで」
* 「エラー文言はUI用に整えて」

これを **OrderService の中で**やりだすと…

* ビジネスルール
* 参照ロジック
* ログ/通知
* UI向けメッセージ

が **1ファイルに全部ミックス**されて、もう終わりです😇🌀

---

## 6) ここでテストを書こうとして詰む🧪💥（わざと！）

たとえば「ORDEREDの注文が支払われるとPAIDになる」テストを書きたいのに…

* `Math.random()` でIDが毎回変わる🎲
* `new Date()` が毎回変わる⏰
* 配列に直接 push していて状態がベタベタ🫠

### テスト導入メモ（2026の定番寄り）

* Vitest は Vite系のテストフレームワークで、4系が出ています🧪✨ ([vitest.dev][1])
* ガイドやIDE連携も公式にまとまっています🧰 ([vitest.dev][2])

---

## 7) “辛さ”チェックリスト✅😵‍💫

いまの状態で、どれか当てはまったら大成功（この章の狙い通り！）🎉

* ✅ `if` が増えすぎて、読むのがしんどい
* ✅ 「どの変更がどこに波及するか」想像できない
* ✅ Queryの変更なのに、Commandの近くを触って怖い
* ✅ テストしようとすると、日時や乱数が邪魔
* ✅ “注文”の話なのに、集計やログや通知まで同じ場所にいる

---

## 8) ミニ課題（この章の“追い打ち”）😈📝

次の要件を **OrderService にそのまま足して**みてね👇（そして苦しもう😂）

1. 支払い方法に `QR` を追加して、集計も対応
2. 検索条件に「メニュー名の部分一致」を追加
3. 「当日キャンセルは手数料100円」を追加（total計算にも影響）

きっとこう思うはず👇
「え、これ…どこを直すのが正解？😨」

---

## 9) ちょいメモ：今どきTS/Node周り（軽く）🪄

* TypeScript の現行ドキュメントは 5.9 系として更新されています🧠✨ ([TypeScript][3])
* Node.js は 20/22/24 のLTS系があり、24は Active LTS として継続更新されています🟢 ([Node.js][4])
* 2026年1月のNode 24.13.0はセキュリティリリースとして案内されています🔒 ([Node.js][5])

---

## 10) 次章の予告👓✨

次（第5章）は、この章で感じたモヤモヤを
**「言葉にして整理する章」**だよ😊🧠

* どんな“変更理由”が混ざってたの？
* どこが“責務の混在”だったの？
* なんで“テストしにくい”の？

ここを言語化できた瞬間、CQRSの理解が一気に進むよ🚀✨

---

### もしよければ💬😊

今の `OrderService.ts` の“増やして苦しんだ版”を貼ってくれたら、
**「どこが特に辛い構造になってるか」**を、章5につながる形で絵文字まみれでツッコミ入れるよ😂🧠✨

（GitHub Copilot は VS Code に入れると提案＋Chatが使えるよ🤖💬） ([docs.github.com][6])

[1]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[2]: https://vitest.dev/guide/?utm_source=chatgpt.com "Getting Started | Guide"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[4]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[5]: https://nodejs.org/en/blog/release/v24.13.0?utm_source=chatgpt.com "Node.js 24.13.0 (LTS)"
[6]: https://docs.github.com/ja/copilot/how-tos/set-up/install-copilot-extension?utm_source=chatgpt.com "環境への GitHub Copilot 拡張機能のインストール"
