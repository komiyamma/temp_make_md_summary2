# 第23章：冪等性テスト（2回/10回/同時実行）🧪🔁

## この章のゴール🎯✨

* 「同じリクエストを何回送っても壊れない」ことを、**テストで証明できる**ようになる🙆‍♀️💯
* とくにこの3つをテストできるようになる👇

  * 同じキーで **2回** 🔁
  * 同じキーで **10回** 🔁🔁🔁
  * 同じキーで **同時にたくさん** ⚡🧵

---

## まず大事：冪等性テストは “回数” と “同時” が命🔥

冪等性って、頭でわかった気になりやすいんだけど…
本番は **リトライ** と **同時実行** で壊れます😇💥

* 2回連打：ユーザーがボタンを2回押した🖱️🖱️
* 10回リトライ：通信が不安定で再送が増えた📶🔁
* 同時実行：タイムアウト直前に同じ操作が並んで突っ込んできた🏁⚔️

だから、**「回数」と「同時」を必ずテストする**のが正解です✅

---

## 今どきの道具えらび🧰✨（ざっくり結論）

* テストフレームワーク：**Vitest**（Vite系で速い＆今どき）🧪⚡ ([vitest.dev][1])
* APIテスト：**Supertest**（HTTP APIテストの定番）📨✅ ([npm][2])
* 追加の選択肢：Nodeの組み込みテストランナー（`node:test`）も安定運用に入ってるよ🟢 ([Node.js][3])

> この章では **Vitest + Supertest** で進めるよ😊🫶

---

## 冪等性テスト観点チェックリスト✅🧠

最低限、これが通れば「冪等性やってます」って胸張れるやつ👇✨

### A. 同じキー（Idempotency-Key）🔑

* ✅ 同じキーで2回 → **結果が同じ**（IDも同じ）
* ✅ 同じキーで10回 → **結果が同じ**（作成は1回だけ）
* ✅ 同じキーで同時に20回 → **作成は1回だけ**（残りは待って同じ結果）

### B. “ズルい再送” 対策😈

* ✅ 同じキーだけど **ボディが違う** → **エラー**（例：409）

  * 「同じキー＝同じ内容の再送」以外は事故の元なので止める💣
  * Stripeも「同じキーでもパラメータが違ったらエラー」にしてるよ🧾 ([Stripe Docs][4])

### C. エラー時の扱い🧯

* ✅ 1回目が失敗（500など）でも、同じキーなら **同じ結果を返す**（設計次第だけど、こうすると事故が減る）

  * Stripeは「成功も失敗も最初のレスポンス（ステータスと本文）を保存して、同じキーには同じ結果を返す」方式📦 ([Stripe Docs][4])

---

## 例題ミニAPI：/orders（最小の冪等実装）🍰🧑‍💻

「同じキーなら、同じ注文結果を返す」ミニ注文APIを作って、テストで殴ります🥊😆

### 1) 冪等ストア（メモリ版）🗃️

ポイントはこれ👇

* 初回：`processing` を置いて **先に席取り**🪑
* 同時の2回目以降：処理完了まで **待って** 同じ結果を返す⏳
* 同じキーで内容違い：**409で止める**🚫

```ts
// src/idempotencyStore.ts
import crypto from "node:crypto";

export type StoredResponse = {
  status: number;
  body: any;
};

type RecordState =
  | { state: "processing"; requestHash: string; wait: Promise<void>; resolve: () => void; reject: (e: unknown) => void }
  | { state: "done"; requestHash: string; response: StoredResponse };

function sha256Json(value: unknown): string {
  const json = JSON.stringify(value);
  return crypto.createHash("sha256").update(json).digest("hex");
}

export class IdempotencyStore {
  private map = new Map<string, RecordState>();

  /**
   * 同じキーの同時実行を「待ち合わせ」して、作成は1回だけにする
   */
  async run<TBody>(
    scopeKey: string,
    idempotencyKey: string,
    body: TBody,
    handler: () => Promise<StoredResponse>,
  ): Promise<StoredResponse> {
    const key = `${scopeKey}:${idempotencyKey}`;
    const requestHash = sha256Json(body);

    const existing = this.map.get(key);
    if (existing) {
      if (existing.requestHash !== requestHash) {
        // 同じキーで内容が違う＝危険なので止める
        const err: any = new Error("Idempotency-Key was reused with different payload");
        err.status = 409;
        throw err;
      }

      if (existing.state === "done") {
        return existing.response;
      }

      // processing なら完了まで待ってから done を返す
      await existing.wait;
      const after = this.map.get(key);
      if (after && after.state === "done") return after.response;

      // ここに来たらおかしいので保険
      const err: any = new Error("Idempotency state broken");
      err.status = 500;
      throw err;
    }

    // 初回：先に processing を置いて席取り
    let resolve!: () => void;
    let reject!: (e: unknown) => void;
    const wait = new Promise<void>((res, rej) => {
      resolve = res;
      reject = rej;
    });

    this.map.set(key, { state: "processing", requestHash, wait, resolve, reject });

    try {
      const response = await handler();
      this.map.set(key, { state: "done", requestHash, response });
      resolve();
      return response;
    } catch (e) {
      reject(e);
      // 失敗を「保存する派」なら、ここで done として保存する（第19章の話）
      // 今回はシンプルに「失敗は保存しない」例にしておく（好みで変えてOK）
      this.map.delete(key);
      throw e;
    }
  }
}
```

---

### 2) API本体（Express）📮

注文を “作った回数” を数えるカウンタを入れて、テストで「1回だけ」を検証するよ🔍✨

```ts
// src/app.ts
import express from "express";
import { randomUUID } from "node:crypto";
import { IdempotencyStore } from "./idempotencyStore";

export function createApp() {
  const app = express();
  app.use(express.json());

  const store = new IdempotencyStore();

  // テスト用：本当に作成が1回だけか見る
  let createCount = 0;

  app.post("/orders", async (req, res) => {
    const idempotencyKey = req.header("Idempotency-Key");
    if (!idempotencyKey) return res.status(400).json({ message: "Idempotency-Key is required" });

    const userId = String(req.body?.userId ?? "");
    if (!userId) return res.status(400).json({ message: "userId is required" });

    try {
      const response = await store.run(
        `user:${userId}`,       // scopeKey（ユーザー単位にしがち）
        idempotencyKey,
        req.body,
        async () => {
          // わざと遅らせる：同時実行バグを起こしやすくする👿
          await new Promise((r) => setTimeout(r, 50));

          createCount++;
          const orderId = randomUUID();

          return {
            status: 201,
            body: { orderId, userId, created: true, createCountSnapshot: createCount },
          };
        },
      );

      return res.status(response.status).json(response.body);
    } catch (e: any) {
      const status = typeof e?.status === "number" ? e.status : 500;
      return res.status(status).json({ message: e?.message ?? "unknown error" });
    }
  });

  // テスト用：外から参照できるようにする（本番なら隠す）
  (app as any).__test = {
    getCreateCount: () => createCount,
  };

  return app;
}
```

---

## いよいよテスト！🧪✨（Vitest + Supertest）

### セットアップ（依存関係）📦

* `vitest` は公式ガイド参照🧭 ([vitest.dev][1])
* `supertest` は npm で提供されてるよ📦 ([npm][2])

（教材なのでコマンドは省略しつつ、`vitest` と `supertest` を入れた前提で進めるね😊）

---

## テストコード：同じキーで2回 / 10回 / 同時実行⚡🔁

```ts
// test/idempotency.test.ts
import { describe, it, expect } from "vitest";
import request from "supertest";
import { createApp } from "../src/app";

function postOrder(app: any, key: string, body: any) {
  return request(app)
    .post("/orders")
    .set("Idempotency-Key", key)
    .send(body);
}

describe("Idempotency /orders 🧪🔑", () => {
  it("同じキーで2回叩いても、同じ結果＆作成は1回だけ 🔁", async () => {
    const app = createApp();
    const body = { userId: "u1", item: "cake" };

    const r1 = await postOrder(app, "k-1", body);
    const r2 = await postOrder(app, "k-1", body);

    expect(r1.status).toBe(201);
    expect(r2.status).toBe(201);

    expect(r2.body.orderId).toBe(r1.body.orderId); // 同じ注文
    expect((app as any).__test.getCreateCount()).toBe(1); // 作成は1回
  });

  it("同じキーで10回叩いても、作成は1回だけ 🔁🔁🔁", async () => {
    const app = createApp();
    const body = { userId: "u1", item: "coffee" };

    const results = [];
    for (let i = 0; i < 10; i++) {
      results.push(await postOrder(app, "k-10", body));
    }

    const first = results[0];
    for (const r of results) {
      expect(r.status).toBe(201);
      expect(r.body.orderId).toBe(first.body.orderId);
    }

    expect((app as any).__test.getCreateCount()).toBe(1);
  });

  it("同じキーを同時に20発投げても、作成は1回だけ ⚡🧵", async () => {
    const app = createApp();
    const body = { userId: "u1", item: "pizza" };

    const tasks = Array.from({ length: 20 }, () => postOrder(app, "k-concurrent", body));
    const results = await Promise.all(tasks);

    const first = results[0];
    for (const r of results) {
      expect(r.status).toBe(201);
      expect(r.body.orderId).toBe(first.body.orderId);
    }

    expect((app as any).__test.getCreateCount()).toBe(1);
  });

  it("違うキーなら、同時でもそれぞれ作成される ✅✅✅", async () => {
    const app = createApp();
    const body = { userId: "u1", item: "sushi" };

    const tasks = Array.from({ length: 5 }, (_, i) => postOrder(app, `k-${i}`, body));
    const results = await Promise.all(tasks);

    const orderIds = new Set(results.map((r) => r.body.orderId));
    expect(orderIds.size).toBe(5);
    expect((app as any).__test.getCreateCount()).toBe(5);
  });

  it("同じキーでボディが違うなら 409（危険な再利用をブロック）🚫", async () => {
    const app = createApp();

    const r1 = await postOrder(app, "k-reuse", { userId: "u1", item: "A" });
    expect(r1.status).toBe(201);

    const r2 = await postOrder(app, "k-reuse", { userId: "u1", item: "B" });
    expect(r2.status).toBe(409);
  });
});
```

### ここでのポイント💡

* **同じキー＝同じ結果** を “orderIdで断言” してる🔍
* **作成回数が1回** を “カウンタで断言” してる🧮
* **同時実行は Promise.all** で再現できる⚡

---

## もっとリアルに：Idempotency-Key って標準化の動きもあるよ📜

`Idempotency-Key` ヘッダはIETFで仕様ドラフトが議論されてる（2025年10月のドラフトなど）ので、今後さらに一般化していく流れだよ🧾✨ ([IETF Datatracker][5])

---

## ちょい負荷テスト：autocannon で “連打” を現実に寄せる🏋️‍♀️⚡

自動テスト（Vitest）で守った上で、最後に「ほんとに連打されても大丈夫？」を確かめるやつ💪

* autocannon は Node製のHTTPベンチツールとして紹介されてる📈 ([Fastify][6])

例（イメージ）👇

* **同じキー固定で叩く** → ずっと orderId が変わらないか？
* **キーを毎回変えて叩く** → 件数がちゃんと増えるか？

> ここは“自動採点”よりも、“挙動の観察”目的でやると理解が爆伸びするよ👀✨

---

## 発展①：fast-check（プロパティベーステスト）で “変な入力” を自動生成🌀🧠

「テストケースを人間が全部思いつくのムリ😇」を助けてくれるやつ💡
fast-check は JS/TS のプロパティベーステストフレームワークで、Vitestとも組み合わせOK🧪✨ ([fast-check.dev][7])

たとえば👇

* いろんな `item` 文字列や配列で「同じキーなら結果同じ」を大量に試す
* バグが出たら “その入力” が残るので再現できる（強い）💪

---

## 発展②：DB/Redis入りの統合テスト（Testcontainers）🐳🗄️

冪等性は、実務だと「メモリだけ」じゃなくて DB/Redis に寄ることが多いよね🧰
Testcontainers は “使い捨てのDBをテスト中だけ立てる” ためのライブラリで、Node向けもあるよ🐳✨ ([node.testcontainers.org][8])

やりたいこと👇

* DBの **ユニーク制約** と一緒に「同時20発でも1件」になるか検証
* Redisの **分散ロック** や **SETNX** 相当の仕組みで検証（第16〜17章の世界）🔒

---

## 失敗したときのデバッグ術🔍🧯（超効く）

テストが落ちたら、まずこれだけ見ればOK👇✨

* ✅ orderId が違う
  → **二重作成**。たぶん「席取り（processing）」が先に置けてない😭
* ✅ createCount が 2 以上
  → どこかで handler が2回走ってる💥（典型：check-then-create のレース）
* ✅ 同じキーで別ボディが通ってしまう
  → 危険！同じキーに対して **リクエスト内容の一致チェック** を入れる（Stripeもこれ）🧾 ([Stripe Docs][4])

---

## AI活用（この章用テンプレ）🤖✨

### 1) テスト観点を増やす🧠

* 「/orders の冪等性テスト観点を20個出して。特に *同時実行* と *失敗時* を厚めに」

### 2) 失敗原因を一気に絞る🔍

* 「この失敗ログとテストコードから、あり得る原因を3つに絞って。優先度順に“確認手順”も書いて」

### 3) “テストの抜け” を指摘させる✅

* 「このチェックリストに穴がないかレビューして。不足があれば追加して（理由も）」

---

## まとめ🌸

* 冪等性は “気持ち” じゃなくて **テストで保証** するもの🧪💯
* 最低ラインは **2回 / 10回 / 同時** を全部通すこと🔁⚡
* 「同じキー＝同じ結果」「作成は1回だけ」を **数字とIDで断言** できたら勝ち🏆✨

Stripeのように「同じキーなら最初の結果（成功も失敗も）を返す」「同じキーで内容が違えばエラー」みたいな挙動は、実務でもかなり強い指針になるよ🧾🔑 ([Stripe Docs][4])

[1]: https://vitest.dev/guide/?utm_source=chatgpt.com "Getting Started | Guide"
[2]: https://www.npmjs.com/package/supertest?utm_source=chatgpt.com "Supertest"
[3]: https://nodejs.org/api/test.html?utm_source=chatgpt.com "Test runner | Node.js v25.5.0 Documentation"
[4]: https://docs.stripe.com/api/idempotent_requests?utm_source=chatgpt.com "Idempotent requests | Stripe API Reference"
[5]: https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/?utm_source=chatgpt.com "The Idempotency-Key HTTP Header Field - Datatracker - IETF"
[6]: https://fastify.io/docs/latest/Guides/Benchmarking/?utm_source=chatgpt.com "Benchmarking - Fastify"
[7]: https://fast-check.dev/?utm_source=chatgpt.com "fast-check official documentation | fast-check"
[8]: https://node.testcontainers.org/?utm_source=chatgpt.com "Testcontainers for NodeJS"

