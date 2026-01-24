# 第17章　クエリ設計②（GetSalesSummary：集計）📊✨

**この章のゴール**：管理画面っぽい「売上サマリー（集計）」を、**Read側だけ**で気持ちよく作れるようになるよ〜！🍙🏆
（CQRSの“うまみ”がいちばん出るところ🤭✨）

---

### 1) なんで「集計」はCQRSで気持ちいいの？😆🎉

一覧（GetOrderList）は「表示用に並べる」だったけど、集計（GetSalesSummary）は、

* **日別売上**（日ごとの合計）
* **注文数**
* **人気メニューTOP3**
* **平均客単価** など

みたいに、**ドメインモデルをそのまま返すとむしろ扱いづらい**やつが多いのね🙃💦
だから Read側で「画面が欲しい形」を作るのが超相性いい！✅

---

### 2) まず決める：このアプリで「売上」ってなに？💳🧾

集計で迷子になる原因の9割はここ！😇
今回はわかりやすく、こう決めよう👇

* 売上に入れるのは **支払い済み（PAID）の注文だけ** ✅
* 日付は **支払日（paidAt）基準**（注文日じゃなくて）📅
* 金額は **円の整数（yen）**で扱う（小数で事故らない）💰✨

> 💡「返金」「キャンセル」などが出てくるのは後半で拡張できるよ（まずはシンプルに！）🧸

---

### 3) 出力（DTO）設計：画面が欲しい形が正義👑📦

管理画面のイメージはこんな感じ👇
「期間を選ぶ」→「サマリーが出る」→「日別とTOP3が見える」📈🍙

**SalesSummaryDto（返す形）**はこうしよ！

```ts
// src/queries/get-sales-summary/SalesSummaryDto.ts
export type SalesSummaryDto = {
  range: { from: string; to: string }; // YYYY-MM-DD
  totalSalesYen: number;
  paidOrderCount: number;
  averageOrderValueYen: number;

  daily: DailySalesDto[];      // 日別
  topMenus: TopMenuDto[];      // 人気TOP
};

export type DailySalesDto = {
  day: string;                 // YYYY-MM-DD
  salesYen: number;            // その日の売上
  paidOrderCount: number;      // その日の支払い済み注文数
};

export type TopMenuDto = {
  menuId: string;
  menuName: string;
  quantity: number;            // 何個売れた？
  salesYen: number;            // いくら売れた？
};
```

ポイントはこれ👇😊✨

* **range（期間）をレスポンスに入れる**：画面が「どの条件の結果？」って迷わない🧭
* **daily/topMenusは“表示に必要な分だけ”**：余計な情報は持たない✂️

---

### 4) 入力（Query）設計：集計は「期間」が命📅🔎

入力はこうしよう👇（UIから来る想定）

```ts
// src/queries/get-sales-summary/GetSalesSummaryQuery.ts
export type GetSalesSummaryQuery = {
  from: string; // YYYY-MM-DD
  to: string;   // YYYY-MM-DD
};
```

> 💡ここで「from/toの妥当性チェック」をどこでやる？って話は後で育てられるよ🌱
> いまは **QueryServiceの入口で軽くチェック**でOK！

---

### 5) Read側の“材料”を決める：集計に必要なデータだけ🍳✨

集計は **「注文と明細」**が要るね！
Read用に最低限こういう形を想定するよ👇

```ts
// src/queries/get-sales-summary/ReadModels.ts
export type ReadOrder = {
  orderId: string;
  status: "ORDERED" | "PAID";
  paidAt?: string;              // ISO文字列でもいいけど、今回はYYYY-MM-DDを作りやすくする
  paidDay?: string;             // ★おすすめ：投影で作る（YYYY-MM-DD）
  totalYen: number;
  items: ReadOrderItem[];
};

export type ReadOrderItem = {
  menuId: string;
  menuName: string;
  unitPriceYen: number;
  quantity: number;
};
```

#### 💡小ワザ（超重要）

集計するたびに Date をこねるの、地味にダルい＆バグりやすいの🥹
だから **Readモデルに paidDay（YYYY-MM-DD）を持たせる**のが超おすすめ！✨
（後半の「投影」でまさにやるやつの先取りだよ〜🪞）

---

### 6) QueryService 実装：GetSalesSummary を作ろう！🧩🚀

#### 6-1. ReadRepository（材料を取ってくる係）🧺

まずは in-memory でOK！

```ts
// src/queries/get-sales-summary/ReadOrderRepository.ts
import { ReadOrder } from "./ReadModels";

export interface ReadOrderRepository {
  findPaidOrdersInRange(from: string, to: string): Promise<ReadOrder[]>;
}

// まずは簡単に in-memory 実装（後でSQLiteとかに置き換えOK）
export class InMemoryReadOrderRepository implements ReadOrderRepository {
  constructor(private readonly orders: ReadOrder[]) {}

  async findPaidOrdersInRange(from: string, to: string): Promise<ReadOrder[]> {
    // paidDay が入ってる前提でラクする！😇
    return this.orders.filter(o =>
      o.status === "PAID" &&
      o.paidDay !== undefined &&
      from <= o.paidDay && o.paidDay <= to
    );
  }
}
```

#### 6-2. 集計ロジック（本体）📊✨

「1回なめて、Mapで集計」すると読みやすいよ〜！

```ts
// src/queries/get-sales-summary/GetSalesSummaryQueryService.ts
import { ReadOrderRepository } from "./ReadOrderRepository";
import { SalesSummaryDto, DailySalesDto, TopMenuDto } from "./SalesSummaryDto";

export class GetSalesSummaryQueryService {
  constructor(private readonly repo: ReadOrderRepository) {}

  async execute(from: string, to: string): Promise<SalesSummaryDto> {
    // 入口の最低限チェック（ガチガチにしなくてOK）
    if (from > to) {
      throw new Error(`from must be <= to. from=${from}, to=${to}`);
    }

    const paidOrders = await this.repo.findPaidOrdersInRange(from, to);

    // 日別
    const dailyMap = new Map<string, { salesYen: number; count: number }>();
    // メニュー別
    const menuMap = new Map<string, { menuId: string; menuName: string; qty: number; salesYen: number }>();

    let totalSalesYen = 0;
    let paidOrderCount = 0;

    for (const order of paidOrders) {
      const day = order.paidDay!;

      totalSalesYen += order.totalYen;
      paidOrderCount += 1;

      // 日別に加算
      const daily = dailyMap.get(day) ?? { salesYen: 0, count: 0 };
      daily.salesYen += order.totalYen;
      daily.count += 1;
      dailyMap.set(day, daily);

      // TOPメニュー用に加算
      for (const item of order.items) {
        const key = item.menuId;
        const m = menuMap.get(key) ?? {
          menuId: item.menuId,
          menuName: item.menuName,
          qty: 0,
          salesYen: 0,
        };
        m.qty += item.quantity;
        m.salesYen += item.unitPriceYen * item.quantity;
        menuMap.set(key, m);
      }
    }

    // 日付の抜け（売上ゼロの日）も埋めると管理画面が親切🥰
    const daily: DailySalesDto[] = [];
    for (const day of enumerateDays(from, to)) {
      const d = dailyMap.get(day);
      daily.push({
        day,
        salesYen: d?.salesYen ?? 0,
        paidOrderCount: d?.count ?? 0,
      });
    }

    // TOP3（売上降順 → 同率なら数量降順 → それでも同率なら名前で安定ソート）
    const topMenus: TopMenuDto[] = Array.from(menuMap.values())
      .sort((a, b) =>
        (b.salesYen - a.salesYen) ||
        (b.qty - a.qty) ||
        a.menuName.localeCompare(b.menuName)
      )
      .slice(0, 3)
      .map(m => ({
        menuId: m.menuId,
        menuName: m.menuName,
        quantity: m.qty,
        salesYen: m.salesYen,
      }));

    const averageOrderValueYen =
      paidOrderCount === 0 ? 0 : Math.floor(totalSalesYen / paidOrderCount);

    return {
      range: { from, to },
      totalSalesYen,
      paidOrderCount,
      averageOrderValueYen,
      daily,
      topMenus,
    };
  }
}

// ───────────────────────────────────────────
// 期間内の日付を "YYYY-MM-DD" で列挙（シンプル版）📅
// ※後でdate-fns等に置き換えてもOK
function enumerateDays(from: string, to: string): string[] {
  const result: string[] = [];
  const start = new Date(from + "T00:00:00Z");
  const end = new Date(to + "T00:00:00Z");

  for (let d = start; d <= end; d = new Date(d.getTime() + 24 * 60 * 60 * 1000)) {
    result.push(d.toISOString().slice(0, 10));
  }
  return result;
}
```

---

### 7) 動作確認ミニ：ダミーデータで動かす🍙🧪

```ts
// src/queries/get-sales-summary/_demo.ts
import { InMemoryReadOrderRepository } from "./ReadOrderRepository";
import { GetSalesSummaryQueryService } from "./GetSalesSummaryQueryService";
import { ReadOrder } from "./ReadModels";

const orders: ReadOrder[] = [
  {
    orderId: "o1",
    status: "PAID",
    paidDay: "2026-01-20",
    totalYen: 900,
    items: [
      { menuId: "m1", menuName: "からあげ丼", unitPriceYen: 600, quantity: 1 },
      { menuId: "m3", menuName: "みそ汁",   unitPriceYen: 300, quantity: 1 },
    ],
  },
  {
    orderId: "o2",
    status: "PAID",
    paidDay: "2026-01-20",
    totalYen: 600,
    items: [{ menuId: "m2", menuName: "カレー", unitPriceYen: 600, quantity: 1 }],
  },
  {
    orderId: "o3",
    status: "PAID",
    paidDay: "2026-01-22",
    totalYen: 1200,
    items: [{ menuId: "m1", menuName: "からあげ丼", unitPriceYen: 600, quantity: 2 }],
  },
];

async function main() {
  const repo = new InMemoryReadOrderRepository(orders);
  const service = new GetSalesSummaryQueryService(repo);

  const summary = await service.execute("2026-01-20", "2026-01-22");
  console.log(JSON.stringify(summary, null, 2));
}

main().catch(console.error);
```

👀結果の見どころ：

* 2026-01-21 が **0円で出てくる**（抜けが埋まってる）✨
* TOP3が出てくる🏆
* total / average が出てくる💰

---

### 8) テスト観点（集計はテストが最強の味方）🧪🛡️

集計は「正しいっぽい」だけだと事故る😇
最低でもこの4つをテストしよ👇

* 売上ゼロの日が **0で出る**か
* PAID以外が混ざらないか
* TOP3の並びが安定してるか
* from > to を弾くか

例（Nodeの `node:test` を使う超シンプル版）：

```ts
// src/queries/get-sales-summary/GetSalesSummaryQueryService.test.ts
import test from "node:test";
import assert from "node:assert/strict";
import { InMemoryReadOrderRepository } from "./ReadOrderRepository";
import { GetSalesSummaryQueryService } from "./GetSalesSummaryQueryService";
import { ReadOrder } from "./ReadModels";

test("sales summary fills missing days with zero", async () => {
  const orders: ReadOrder[] = [
    {
      orderId: "o1",
      status: "PAID",
      paidDay: "2026-01-20",
      totalYen: 500,
      items: [{ menuId: "m1", menuName: "おにぎり", unitPriceYen: 250, quantity: 2 }],
    },
  ];

  const repo = new InMemoryReadOrderRepository(orders);
  const service = new GetSalesSummaryQueryService(repo);

  const s = await service.execute("2026-01-20", "2026-01-22");
  const day21 = s.daily.find(d => d.day === "2026-01-21");
  assert.equal(day21?.salesYen, 0);
  assert.equal(day21?.paidOrderCount, 0);
});
```

---

### 9) AI活用（Copilot / Codex）で爆速にするプロンプト例🤖✨

集計は「仕様の言語化」ができるとAIがめっちゃ強い！💪

* **DTO案を出させる**

  * 「学食注文アプリの管理画面で、期間の売上サマリー（総売上/日別/人気TOP3）を出したい。DTOをTypeScriptの型で提案して。日別は売上0の日も出したい」

* **テスト観点を列挙させる**

  * 「この集計ロジックでバグりやすい境界条件を10個出して。優先度もつけて」

* **並び順の仕様を固める**

  * 「TOP3の同率時に画面が毎回並び替わらないように安定ソートしたい。おすすめのtie-break案を提案して」

---

### 10) 2026っぽい小ネタ（いまどきのTS実行まわり）🧠✨

* NodeのLTSは v20 が **2026年4月**まで、v22 は **2027年4月**までの案内が出ていて、長く使うなら v22 を選ぶ判断がしやすいよ〜📅 ([Node.js][1])
* TypeScriptの実行は、`ts-node`で詰まりがちな場面があって、実務では `tsx` を使う案内が増えてるよ🧯 ([Better Stack][2])
* さらに最近は、Node側で “型を落としてTypeScriptをそのまま動かす” 方向の話題もある（ただし「型だけ」など“消せる構文”中心）って流れもあるよ〜🧩 ([The Dev Newsletter][3])

> ※この章の中身（集計の設計）は、どの実行方式でもそのまま使える考え方だよ☺️👍

---

### 11) よくある落とし穴（先に踏み抜きポイント回避）🕳️🐾

* **「売上日」がブレる**：orderedAt 기준？ paidAt 기준？ → 章の冒頭で決め打ちする✅
* **小数（浮動小数点）で金額を持つ**：`0.1 + 0.2` 的な事故がある → 円の整数で💰
* **売上0の日が消える**：ダッシュボードがガタガタになる → enumerateDaysで埋める📅✨
* **TOPの並びが毎回変わる**：同率で順序が揺れる → tie-breakを入れて安定ソート🏆

---

### 12) 章末チェックリスト✅✨

* [ ] PAIDだけ集計してる
* [ ] 日別（daily）を **0円の日も含めて**返せる
* [ ] TOP3が安定した順序で返る
* [ ] total / average が出る
* [ ] テストが1本以上ある🧪

---

次の第18章では、この「画面専用DTO」をさらに割り切って、**命名・整形・欠損値**を“気持ちよく統一”していくよ〜🎁🙂✨

[1]: https://nodejs.org/en/blog/announcements/node-18-eol-support?utm_source=chatgpt.com "Beware of End-of-Life Node.js Versions - Upgrade or Seek ..."
[2]: https://betterstack.com/community/guides/scaling-nodejs/ts-node-intro/?utm_source=chatgpt.com "Getting Started with ts-node"
[3]: https://devnewsletter.com/p/state-of-typescript-2026?utm_source=chatgpt.com "State of TypeScript 2026 - The Dev Newsletter"
