# 第18章　Read DTOの割り切り（ビュー専用でOK）🎁🙂

この章はひとことで言うと、**「表示に必要な形に“気持ちよく”整える練習」**だよ〜！✨
CQRSのRead側は、**ドメインの綺麗さより“使いやすさ”優先でOK**なのがポイント😎💕

---

## 0. 2026/01 時点のミニ最新メモ🗞️✨

* TypeScript の最新安定版は **5.9.3**（npmの “Latest version” 表記）だよ〜🧡 ([npm][1])
* さらに将来に向けて、TypeScript の **native preview**（高速化のプレビュー）も npm や VS Code で試せる流れが進んでるよ🚀 ([Microsoft for Developers][2])

> でも、この章のDTO設計は **どのバージョンでも通用する“設計の体幹”**だから安心してね🙂✨

---

## 1. Read DTOってなに？（超ざっくり）🧃✨

Read DTOは、**画面やAPIが欲しい形に整えた“見せる用の箱”**だよ📦✨
ドメイン（OrderとかMoneyとか）をそのまま返すんじゃなくて、**表示に都合がいい形に加工する**のが仕事🙂

たとえば👇

* 画面：「合計 **680円**」「**12:03**」「支払いボタン **押せる/押せない**」
* ドメイン：「amount=680」「createdAt=Date」「status='ORDERED'」

この“翻訳”をするのが **Read DTO** だよ〜🪄✨

---

## 2. この章のゴール🎯✨（できるようになること）

* **「画面の言葉」でDTOを設計**できる🙂🧡
* **整形（価格/日時/ラベル）**をDTO側で割り切れる🧁
* **欠損値（null/undefined）**を“事故らない”方針で扱える🛟
* **DTO変換（map関数）**を気持ちよく書ける✍️✨
* **ドメインを漏らさない境界線**がわかる🧠🛡️

---

## 3. まず最重要：Read DTOは“ビュー専用”でOK🙆‍♀️🎀

### ✅ 割り切っていいことリスト（やってOK！）✨

* **フラットにする**（ネストを減らす）📄✨
* **表示用の文字列を入れる**（例：`totalYenText: "¥680"`）💴
* **ラベルを入れる**（例：`statusLabel: "支払い待ち"`）🏷️
* **画面の都合で項目を足す**（例：`canPay: true`）🔘
* **同じ情報を重複して持つ**（例：`statusCode`と`statusLabel`）🔁

### ❌ やっちゃダメ寄りリスト（事故るやつ）😵‍💫

* Read DTOを **Write（Command）入力に使い回す**（境界が溶ける🫠）
* Read DTOに **業務ルール（不変条件）を実装する**（それはドメインの仕事💥）
* Read DTOが **DB構造そのまま**（画面がDBの奴隷になる😇）

---

## 4. ドメイン vs Read DTO（例で一撃理解👊✨）

### ドメイン側（ルールと整合性の世界）🧠🛡️

```ts
export type OrderStatus = "ORDERED" | "PAID" | "CANCELLED";

export type Money = {
  amount: number;       // 680
  currency: "JPY";      // 固定
};

export type Order = {
  id: string;
  status: OrderStatus;
  total: Money;
  createdAt: Date;
};
```

### Read DTO側（画面が嬉しい世界）🍰✨

```ts
export type OrderListItemDto = {
  id: string;

  // 画面でそのまま出せる✨
  statusLabel: string;      // "支払い待ち" など
  totalYenText: string;     // "¥680"
  createdAtText: string;    // "2026/01/24 12:03"

  // 画面の都合で足してOK🙂
  canPay: boolean;          // 支払いボタンを出す？
};
```

見て〜！💡
**Read DTOは“表示のための都合100%”**でいいの😊✨
（ドメインの美学をReadに持ち込むと、しんどくなる率が上がるよ…！😇）

---

## 5. 変換（mapping）は“関数”にしよう🧼✨

### 5.1 DTO変換は「純粋な関数」にすると最強💪🙂

* 入力：Read側の行データ（DBやin-memory）
* 出力：Read DTO
* 副作用：なし（大事！）

例👇

```ts
export type OrderListRow = {
  orderId: string;
  status: "ORDERED" | "PAID" | "CANCELLED";
  totalAmount: number;   // 680
  createdAt: Date;
};

const yen = new Intl.NumberFormat("ja-JP", {
  style: "currency",
  currency: "JPY",
});

const dt = new Intl.DateTimeFormat("ja-JP", {
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
});

function statusToLabel(status: OrderListRow["status"]): string {
  switch (status) {
    case "ORDERED":
      return "支払い待ち";
    case "PAID":
      return "支払い済み";
    case "CANCELLED":
      return "キャンセル";
  }
}

export function toOrderListItemDto(row: OrderListRow): OrderListItemDto {
  return {
    id: row.orderId,
    statusLabel: statusToLabel(row.status),
    totalYenText: yen.format(row.totalAmount),
    createdAtText: dt.format(row.createdAt),
    canPay: row.status === "ORDERED",
  };
}
```

---

## 6. `satisfies` で“DTOの作り間違い”を早めに潰す💣➡️🧯

DTO変換って、地味に **タイポ**とか **項目漏れ**が起きやすいのね🥺
そこで便利なのが `satisfies`！✨
（式の型を変えずに、**「DTO型に合ってる？」をチェック**してくれるやつだよ）([TypeScript][3])

```ts
export function toOrderListItemDto(row: OrderListRow): OrderListItemDto {
  const dto = {
    id: row.orderId,
    statusLabel: statusToLabel(row.status),
    totalYenText: yen.format(row.totalAmount),
    createdAtText: dt.format(row.createdAt),
    canPay: row.status === "ORDERED",
  } satisfies OrderListItemDto;

  return dto;
}
```

これ、**DTO設計に慣れてない最初期ほど助かる**よ〜🙂💕

---

## 7. 欠損値（null / undefined）をどうする？🕳️😵‍💫➡️🙂✨

Read側って、集計やJOINの都合で **値がない**ことがあるよね。
そのときの“おすすめ方針”を2つ出すね👇

### 方針A：DTOは `null` を許可して、UIで表示を決める（現場で多い）🧩

```ts
export type SalesSummaryDto = {
  date: string;          // "2026-01-24"
  totalYen: number;      // 12340
  topMenuName: string | null; // ない日は null
};
```

### 方針B：DTOに “表示用” を入れてしまう（初心者にやさしい）🧸

```ts
export type SalesSummaryDto = {
  date: string;
  totalYenText: string;       // "¥12,340"
  topMenuNameText: string;    // "カレー" / "（なし）"
};
```

おすすめは、学習段階なら **方針B** が気持ちよく進むよ🙂✨
（“画面に出すものはDTOに全部揃ってる”って超ラク！🫶）

---

## 8. QueryServiceは「DTOを返す係」📦➡️📤✨

QueryServiceの戻り値は、もう **DTOで固定**しちゃってOK😊

```ts
export type OrderListDto = {
  items: OrderListItemDto[];
};

export interface OrderReadRepository {
  listOrders(): Promise<OrderListRow[]>;
}

export class OrderQueryService {
  constructor(private readonly repo: OrderReadRepository) {}

  async getOrderList(): Promise<OrderListDto> {
    const rows = await this.repo.listOrders();
    return {
      items: rows.map(toOrderListItemDto),
    };
  }
}
```

こうすると、QueryServiceが **表示用の形を保証**できるから、UI側がすっごい楽になるよ〜🙂✨

---

## 9. “割り切り”の境界線：DTOに入れていい情報・だめな情報🧠🛡️

### ✅ DTOに入れていい（ビュー都合）🎀

* `canPay`（ボタン制御）🔘
* `statusLabel`（表示文言）🏷️
* `totalYenText`（フォーマット済み）💴
* `createdAtText`（フォーマット済み）🕒
* `warningMessage`（画面の注意書き）⚠️

### ❌ DTOに入れないほうがいい（ドメイン都合）🚫

* 「支払い可能判定の“業務ルール本体”」
  → それはドメイン or Command側の責務だよ🙂
  Read側の `canPay` は **“今見せたい状態”**として割り切ってOK！

---

## 10. ミニ演習（手を動かすと一気に定着🫶✨）

### 演習①：一覧DTOに「表示用の短いID」を追加してみよ🙂🆔

* `displayId: string`（例：`"A12F"` みたいに短く）
* `orderId` の先頭4文字を使う、みたいな軽いルールでOK✨

### 演習②：`statusLabel` に絵文字を混ぜてテンション上げよ😆✨

例：

* ORDERED → `"支払い待ち💳"`
* PAID → `"支払い済み✅"`
* CANCELLED → `"キャンセル🌀"`

### 演習③：欠損値のときに「（なし）」を出す🙂🧸

`topMenuName` が `null` のとき、DTO側で `topMenuNameText = "（なし）"` を作ろう！

---

## 11. AI活用🤖✨（レビューさせると強い！）

そのままコピペで使えるやつ置いとくね🫶

* 「このDTO、画面の言葉になってる？専門用語が混ざってないか見て！」👀✨
* 「このRead DTO、ドメインやDB構造を漏らしてない？漏れてたら指摘して！」🛡️
* 「DTOの項目名、もっとわかりやすい命名案を10個ちょうだい！」🏷️✨
* 「DTO変換関数にテストを書きたい。Arrange/Act/Assertで例を書いて！」🧪✨

---

## 12. まとめ（この章で一番言いたいこと🥹💖）

Read DTOはね、**“ビュー専用で割り切ってOK”**なの！🎁✨

* ドメインをそのまま返さない🙂
* 表示に必要な形に整える🙂
* 欠損値も整形も、DTOで吸収しちゃう🙂

ここができると、CQRSのRead側が **一気に気持ちよく**なるよ〜！😆🌸

次（第19章）は、**QueryServiceの責務（副作用ゼロ！）**をさらにガッチリ固めていこうね🧼🚫✨

[1]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[2]: https://devblogs.microsoft.com/typescript/announcing-typescript-native-previews/?utm_source=chatgpt.com "Announcing TypeScript Native Previews"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html?utm_source=chatgpt.com "Documentation - TypeScript 4.9"
