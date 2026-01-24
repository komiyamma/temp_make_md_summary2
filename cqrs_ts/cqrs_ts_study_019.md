# 第19章　QueryServiceの責務（副作用ゼロ！）🧼🚫
（この章は **CQRSの気持ちよさ**が一気にわかる回だよ😆💘）

---

## 19章でできるようになること🎯✨

* QueryService が **“やっていいこと / ダメなこと”** を説明できる🙂✅
* 「副作用ゼロ」を **設計で守るコツ**がわかる🛡️
* `QueryService + ReadRepository` で **読み取り実装**を作れる🔎📦
* 「うっかり更新しちゃう事故」も、最初から避けられる🚑💦

---

## まず結論：QueryServiceは「読むだけ係」📖👀

QueryService は一言でいうと、

> **画面が欲しい形（Read DTO）を、いい感じに“読む”だけの係**😊✨
> **データを“変えない”**のがルール🧼🚫

だから、QueryServiceがやるのはこんな感じ👇

* DB/Readモデルから **取得**する🔎
* 画面に合わせて **整形（DTO化）**する🎁
* 並び替え・絞り込み・集計を **読み取りとして**やる📊✨

---

## 「副作用」ってなに？（超やさしく）🙂🧠

**副作用 = “読んだついでに、何かが変わること”**だよ⚡

例👇（ありがちな事故😭）

* 一覧表示したら「閲覧回数 +1」しちゃった👀➡️➕
* 「最後に見た日時」を更新しちゃった🕒✍️
* 「ついでに状態を直しておこう」と修正保存しちゃった🔧💾

これ、**Queryの顔してCommandしてる**のが問題😵‍💫💥
（CQRSの分ける意味が薄まって、事故が増えるやつ…！）

---

## QueryServiceの鉄の掟（やさしめ版）🧼🪨

QueryServiceはこの5つを守ると、ほぼ勝ち🏆✨

1. **DBに書かない**（INSERT/UPDATE/DELETEしない）🚫✍️
2. **イベントを発行しない**📣🚫
3. **外部サービスを動かさない**（決済/メール送信等）💳📧🚫
4. **ドメイン（Write側）を変形・更新しない**📦🚫
5. **読み取りの結果だけ返す**（返すのは DTO）🎁✅

---

## “副作用ゼロ”を守るコツ（根性じゃなく設計で！）🛡️😆

ここ大事！💘
「気をつけます！」だと絶対破れるから、**破れない形**にするよ〜✨

### コツ1：QueryServiceが依存していいのは「ReadRepositoryだけ」📦✅

* QueryService → ReadRepository（読む専用）だけに依存する
* WriteRepository や CommandHandler を見えない場所に置く🙈✨

### コツ2：ReadRepositoryに「更新っぽいメソッド」を置かない🚫🧨

`save()` とか `update()` が存在すると、いつか使う😇（断言）

---

## 2026年の“最新メモ”🗓️✨（超短く）

* TypeScript は **5.9 系**が最新安定版として公開されているよ（例：5.9.3）🟦✨ ([GitHub][1])
* Node.js は **v24 が Active LTS**、v25 が Current という扱いになってるよ🟩✨ ([Node.js][2])
* TypeScript は 5.8 で **ビルド/ウォッチ/エディタ更新の最適化**が強調されてる（＝開発体験が良くなる方向）🚀 ([TypeScript][3])
* TypeScriptブログでは **TypeScript 7**に向けた進捗も公開されていて、今後もコンパイラ改善が進む流れだよ🧠🔥 ([Microsoft for Developers][4])

（※この章のコードは、こういう“今のTS”で気持ちよく書ける形に寄せるね🙂✨）

---

# ハンズオン🔥 QueryService + ReadRepository を作る（学食アプリ）🍙📱

今回は **「注文一覧」**を例にするよ🔎📋
（集計も同じ型で作れるから、まずは一覧で勝つ！😆）

---

## 1) Read DTO と Query Input を用意🎁📝

**ポイント**：Read DTO は「画面の言葉」でOK🙆‍♀️（ドメインの `Order` をそのまま返さない）

```ts
// src/queries/getOrderList/GetOrderListTypes.ts

export type GetOrderListInput = {
  status?: "ORDERED" | "PAID" | "CANCELLED";
  limit?: number;       // 画面の都合でOK
  offset?: number;      // ページング用
};

export type OrderListItemDto = {
  orderId: string;
  status: "ORDERED" | "PAID" | "CANCELLED";
  totalYen: number;
  itemsCount: number;
  orderedAt: string; // 画面表示しやすく文字列でもOK（ISOとか）
};
```

---

## 2) ReadRepository（読む専用の口）を作る🗄️🔎

ここが **“副作用ゼロの防波堤”**だよ🛡️✨
更新メソッドを置かないのがポイント！

```ts
// src/queries/getOrderList/OrderReadRepository.ts

import type { GetOrderListInput, OrderListItemDto } from "./GetOrderListTypes";

export interface OrderReadRepository {
  findOrderList(input: GetOrderListInput): Promise<OrderListItemDto[]>;
}
```

---

## 3) まずは InMemory 実装（最速で動かす）🪶💨

「Readモデルの置き場」は次章（20章）でちゃんとやるから、ここは軽く！🙂
まず “QueryServiceが更新しない” って体験が大事✨

```ts
// src/queries/getOrderList/InMemoryOrderReadRepository.ts

import type { OrderReadRepository } from "./OrderReadRepository";
import type { GetOrderListInput, OrderListItemDto } from "./GetOrderListTypes";

const seed: OrderListItemDto[] = [
  { orderId: "o_001", status: "ORDERED", totalYen: 780, itemsCount: 2, orderedAt: "2026-01-24T10:12:00.000Z" },
  { orderId: "o_002", status: "PAID",    totalYen: 520, itemsCount: 1, orderedAt: "2026-01-24T10:15:00.000Z" },
  { orderId: "o_003", status: "PAID",    totalYen: 980, itemsCount: 3, orderedAt: "2026-01-24T10:18:00.000Z" },
];

export class InMemoryOrderReadRepository implements OrderReadRepository {
  async findOrderList(input: GetOrderListInput): Promise<OrderListItemDto[]> {
    const limit = input.limit ?? 20;
    const offset = input.offset ?? 0;

    let rows = seed;

    if (input.status) {
      rows = rows.filter(r => r.status === input.status);
    }

    // orderedAt の新しい順にしたい（画面都合🙂）
    rows = [...rows].sort((a, b) => b.orderedAt.localeCompare(a.orderedAt));

    return rows.slice(offset, offset + limit);
  }
}
```

---

## 4) QueryService を作る（副作用ゼロで整える係）🧼✨

QueryServiceは **薄くてOK**🙂
「読む → 整える → 返す」だけ🎁

```ts
// src/queries/getOrderList/GetOrderListQueryService.ts

import type { OrderReadRepository } from "./OrderReadRepository";
import type { GetOrderListInput, OrderListItemDto } from "./GetOrderListTypes";

export class GetOrderListQueryService {
  constructor(private readonly repo: OrderReadRepository) {}

  async execute(input: GetOrderListInput): Promise<OrderListItemDto[]> {
    const list = await this.repo.findOrderList(input);

    // ✅ OK：整形（副作用じゃない）
    // 例：表示のために orderedAt を人間向けに…とかも本当はここでやれる🙂
    return list;
  }
}
```

> ここで **絶対にやっちゃダメ**な例👇😇💥
>
> * `await writeRepo.save(...)`
> * `await eventBus.publish(...)`
> * `await payment.charge(...)`
>   Queryに混ぜると、あとで死ぬ（テスト・負荷・事故）😭

---

## 5) 動かしてみる（超ミニ起動）🚀😆

```ts
// src/devRun.ts

import { InMemoryOrderReadRepository } from "./queries/getOrderList/InMemoryOrderReadRepository";
import { GetOrderListQueryService } from "./queries/getOrderList/GetOrderListQueryService";

async function main() {
  const repo = new InMemoryOrderReadRepository();
  const qs = new GetOrderListQueryService(repo);

  const all = await qs.execute({ limit: 10 });
  console.log("ALL:", all);

  const paidOnly = await qs.execute({ status: "PAID" });
  console.log("PAID:", paidOnly);
}

main().catch(console.error);
```

✅ これで「QueryServiceは読むだけ」が体感できたらOK！🎉✨

---

# よくある質問（初心者あるある）🙋‍♀️💭

## Q1. 「閲覧数 +1」したいんだけど…Queryじゃダメ？👀➕

**ダメじゃないけど、それは “更新” だから Command にするのが安全**🙂
つまり、

* 画面表示：Query ✅
* 閲覧ログ更新：Command ✅（`RecordOrderViewed` とか）

「表示したら勝手に更新」ってやると、後で追跡不能になるよ〜😭🌀

---

## Q2. 「キャッシュ更新」は副作用？🧊💭

基本は副作用だよ⚡
ただし実務では「読み取り最適化」として使うこともある🙂
初心者のうちはルールを単純化して、

* QueryService：**キャッシュ“読む”だけ**✅
* キャッシュ更新：**別プロセス/別責務**✅

にしておくのが事故らない✨

---

## Q3. QueryServiceにロジック入れていい？🧠

OKだよ🙆‍♀️✨
ただし **“業務ルール（不変条件/状態遷移）” は Write側（ドメイン）**で守るのが基本！

Query側は

* 表示のための整形
* 集計・並び替え
* 欠損値の埋め
  みたいな「UI都合ロジック」が中心だよ🙂🎁

---

# AI活用プロンプト例🤖💬（そのままコピペOK）

### 1) “副作用混入”をチェックしてもらう🕵️‍♀️✅

* 「この `GetOrderListQueryService` は副作用ゼロになってる？更新っぽい処理が混ざってたら指摘して！」

### 2) DTOが“画面の言葉”かレビューしてもらう🎁👀

* 「この `OrderListItemDto` は画面に必要な形になってる？ドメイン丸出しになってない？」

### 3) ReadRepositoryの責務が重すぎないか相談🧠🧹

* 「`InMemoryOrderReadRepository` の責務が肥大化しそう。SQL/整形の境界をどう分けるのが自然？」

---

# まとめ🎉✨（ここだけ覚えればOK）

* QueryServiceは **読むだけ係**📖
* **副作用ゼロ**がルール🧼🚫
* 破らないコツは「設計で防ぐ」🛡️（ReadRepositoryを分ける！）
* この形ができると、次の章（Readモデルの置き場）に気持ちよく進める📦🪶

---

次（第20章）は、「Readモデルをどこに置く？」っていう **現実の選択肢**を、迷子にならないように整理していくよ〜🧭✨
その前に、もし今のプロジェクト構成（フォルダ構成）をあなたの形に合わせて整えた“おすすめ配置案”も出せるよ📁😊

[1]: https://github.com/microsoft/typescript/releases?utm_source=chatgpt.com "Releases · microsoft/TypeScript"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-8.html?utm_source=chatgpt.com "Documentation - TypeScript 5.8"
[4]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
