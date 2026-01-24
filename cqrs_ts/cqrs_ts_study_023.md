# 第23章　テスト① CommandHandlerをユニットテスト🧪✅
ここを押さえると、更新ロジックの安心感が一気に上がるし、CQRSが“気持ちいい設計”になってくるよ😊💕

---

# 第23章　テスト① CommandHandler をユニットテスト🧪✅

### この章のゴール🎯✨

* CommandHandler（更新処理）が **仕様どおりに動く**のをテストで守れるようになる✅
* DBや外部APIに触れない **速いユニットテスト**が書けるようになる⚡
* 「正常系」「ドメインエラー」「インフラ失敗」をテストで分けられるようになる🧠✨

---

## まず超大事：ユニットテストの“境界”ってどこ？🧱👀

CommandHandler のユニットテストで守るのは、基本これ👇✨

* ✅ **入力 → 判定（不変条件/状態遷移） → 依存先の呼び出し → 結果**
* ❌ DBの実物（SQLiteでも本物は触らない）
* ❌ ネットワーク（支払いAPIとか）
* ❌ 時刻（必要なら `Clock` みたいな依存にして差し替える）

つまり、Handlerの外側（RepositoryやPaymentなど）は **モック（偽物）**にして、Handlerの頭脳だけをテストする感じ🧠💡

---

## 今どきのテスト実行：Vitest を使うよ🏃‍♀️💨

この章では **Vitest** で進めるね😊
Vitest は `vitest` コマンドがローカルで基本ウォッチ動作になってて、開発中のフィードバックが速いのがうれしいやつ💖（CIでは自動で単発実行にも寄るよ）([Vitest][1])
あとカバレッジも `v8` / `istanbul` から選べて、デフォルトは `v8` でOK👌([Vitest][2])
（ちなみに Vitest 4.0 は 2025/10 に発表されてるよ〜）([Vitest][3])

---

## 0) 先に“最低限の動作環境”チェック🧰🪟

Node は **LTS系**を選べばOKだよ〜！
2026年1月時点だと **v24 が Active LTS**として扱われてるのが分かりやすい✨([Node.js][4])

---

## 1) テスト導入（Vitest）🔧✨

### インストール📦

PowerShell でプロジェクト直下から👇

```bash
npm i -D vitest
```

### package.json に scripts を足す🧾✨

Vitest公式の「よくあるスクリプト」例はこんな感じだよ👇([Vitest][5])

```json
{
  "scripts": {
    "test": "vitest",
    "coverage": "vitest run --coverage"
  }
}
```

### vitest.config.ts（最小）🧩

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node"
  }
});
```

### tsconfig.json に型を追加（補完＆型エラー回避）🧠✨

```json
{
  "compilerOptions": {
    "types": ["vitest/globals", "node"]
  }
}
```

（Vitestの設定ファイルは `defineConfig` を使う形が基本だよ〜）([Vitest][6])

---

## 2) この章でテストする“最小の題材”🍙📱🧾

> ここからは「PlaceOrder（注文）」と「PayOrder（支払い）」を **CommandHandler** としてテストするよ🧪✨
> 「依存は注入してモック差し替え」がポイント😊

---

## 3) 実装（最小サンプル）✍️✨

### Result と Error（境界で揃えるやつ）🎁⚠️

```ts
// src/shared/result.ts
export type Ok<T> = { ok: true; value: T };
export type Err<E> = { ok: false; error: E };
export type Result<T, E> = Ok<T> | Err<E>;

export const ok = <T>(value: T): Ok<T> => ({ ok: true, value });
export const err = <E>(error: E): Err<E> => ({ ok: false, error });
```

```ts
// src/domain/errors.ts
export type DomainError =
  | { kind: "DomainError"; code: "InvalidInput"; message: string }
  | { kind: "DomainError"; code: "NotFound"; message: string }
  | { kind: "DomainError"; code: "InvalidState"; message: string };

export type InfraError =
  | { kind: "InfraError"; code: "PaymentFailed"; message: string }
  | { kind: "InfraError"; code: "RepoFailed"; message: string };
```

### ポート（依存先の“型だけ”）🔌✨

```ts
// src/application/ports/orderRepository.ts
export type OrderStatus = "ORDERED" | "PAID";

export type Order = {
  id: string;
  customerId: string;
  items: { menuId: string; qty: number; unitPrice: number }[];
  total: number;
  status: OrderStatus;
  paymentId?: string;
};

export interface OrderRepository {
  findById(id: string): Promise<Order | null>;
  save(order: Order): Promise<void>;
}
```

```ts
// src/application/ports/paymentGateway.ts
import { Result } from "../../shared/result";
import { InfraError } from "../../domain/errors";

export interface PaymentGateway {
  charge(amount: number, token: string): Promise<Result<{ paymentId: string }, InfraError>>;
}
```

### CommandHandler（今回の主役）👑✨

```ts
// src/application/commands/placeOrder.ts
import { err, ok, Result } from "../../shared/result";
import { DomainError, InfraError } from "../../domain/errors";
import { Order, OrderRepository } from "../ports/orderRepository";

export type PlaceOrderCommand = {
  customerId: string;
  items: { menuId: string; qty: number; unitPrice: number }[];
};

export class PlaceOrderHandler {
  constructor(
    private readonly repo: OrderRepository,
    private readonly idGen: () => string
  ) {}

  async handle(cmd: PlaceOrderCommand): Promise<Result<{ orderId: string }, DomainError | InfraError>> {
    if (!cmd.customerId) {
      return err({ kind: "DomainError", code: "InvalidInput", message: "customerId is required" });
    }
    if (cmd.items.length === 0) {
      return err({ kind: "DomainError", code: "InvalidInput", message: "items is empty" });
    }
    if (cmd.items.some(i => i.qty <= 0 || i.unitPrice < 0 || !i.menuId)) {
      return err({ kind: "DomainError", code: "InvalidInput", message: "invalid items" });
    }

    const total = cmd.items.reduce((sum, i) => sum + i.qty * i.unitPrice, 0);
    const order: Order = {
      id: this.idGen(),
      customerId: cmd.customerId,
      items: cmd.items,
      total,
      status: "ORDERED"
    };

    try {
      await this.repo.save(order);
      return ok({ orderId: order.id });
    } catch {
      return err({ kind: "InfraError", code: "RepoFailed", message: "save failed" });
    }
  }
}
```

```ts
// src/application/commands/payOrder.ts
import { err, ok, Result } from "../../shared/result";
import { DomainError, InfraError } from "../../domain/errors";
import { OrderRepository } from "../ports/orderRepository";
import { PaymentGateway } from "../ports/paymentGateway";

export type PayOrderCommand = {
  orderId: string;
  token: string;
};

export class PayOrderHandler {
  constructor(
    private readonly repo: OrderRepository,
    private readonly payment: PaymentGateway
  ) {}

  async handle(cmd: PayOrderCommand): Promise<Result<{ paymentId: string }, DomainError | InfraError>> {
    const order = await this.repo.findById(cmd.orderId);
    if (!order) {
      return err({ kind: "DomainError", code: "NotFound", message: "order not found" });
    }
    if (order.status !== "ORDERED") {
      return err({ kind: "DomainError", code: "InvalidState", message: "order is not payable" });
    }

    const paid = await this.payment.charge(order.total, cmd.token);
    if (!paid.ok) return paid;

    const updated = { ...order, status: "PAID" as const, paymentId: paid.value.paymentId };

    try {
      await this.repo.save(updated);
      return ok({ paymentId: paid.value.paymentId });
    } catch {
      return err({ kind: "InfraError", code: "RepoFailed", message: "save failed" });
    }
  }
}
```

---

## 4) いよいよテスト！🧪✨（CommandHandler のユニットテスト）

ここでのコツはこれだよ👇😊💕

* Arrange：依存（repo/payment）を **モック**にする🧸
* Act：handler.handle() を呼ぶ🏃‍♀️
* Assert：戻り値＆依存の呼ばれ方を検証する✅

---

### テスト：PlaceOrderHandler 🧾✅

```ts
// tests/placeOrderHandler.test.ts
import { describe, expect, test, vi } from "vitest";
import { PlaceOrderHandler } from "../src/application/commands/placeOrder";
import type { OrderRepository } from "../src/application/ports/orderRepository";

describe("PlaceOrderHandler", () => {
  test("正常系：注文できて、repo.save が1回呼ばれる🟢", async () => {
    // Arrange
    const repo: OrderRepository = {
      findById: vi.fn(),
      save: vi.fn().mockResolvedValue(undefined)
    };
    const idGen = () => "order-001";
    const handler = new PlaceOrderHandler(repo, idGen);

    // Act
    const result = await handler.handle({
      customerId: "c-001",
      items: [
        { menuId: "m-001", qty: 2, unitPrice: 500 },
        { menuId: "m-002", qty: 1, unitPrice: 300 }
      ]
    });

    // Assert
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.orderId).toBe("order-001");
    }
    expect(repo.save).toHaveBeenCalledTimes(1);
    expect(repo.save).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "order-001",
        customerId: "c-001",
        status: "ORDERED",
        total: 1300
      })
    );
  });

  test("異常系：qty<=0 は InvalidInput で、repo.save は呼ばれない🔴", async () => {
    const repo: OrderRepository = {
      findById: vi.fn(),
      save: vi.fn()
    };
    const handler = new PlaceOrderHandler(repo, () => "order-xxx");

    const result = await handler.handle({
      customerId: "c-001",
      items: [{ menuId: "m-001", qty: 0, unitPrice: 500 }]
    });

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.kind).toBe("DomainError");
      expect(result.error.code).toBe("InvalidInput");
    }
    expect(repo.save).not.toHaveBeenCalled();
  });
});
```

---

### テスト：PayOrderHandler 💳✅

```ts
// tests/payOrderHandler.test.ts
import { describe, expect, test, vi } from "vitest";
import { PayOrderHandler } from "../src/application/commands/payOrder";
import type { OrderRepository, Order } from "../src/application/ports/orderRepository";
import type { PaymentGateway } from "../src/application/ports/paymentGateway";
import { err, ok } from "../src/shared/result";

describe("PayOrderHandler", () => {
  test("異常系：注文がない(NotFound)🔴", async () => {
    const repo: OrderRepository = {
      findById: vi.fn().mockResolvedValue(null),
      save: vi.fn()
    };
    const payment: PaymentGateway = {
      charge: vi.fn()
    };
    const handler = new PayOrderHandler(repo, payment);

    const result = await handler.handle({ orderId: "nope", token: "tok" });

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.kind).toBe("DomainError");
      expect(result.error.code).toBe("NotFound");
    }
    expect(payment.charge).not.toHaveBeenCalled();
    expect(repo.save).not.toHaveBeenCalled();
  });

  test("異常系：支払い失敗(InfraError)🔴", async () => {
    const base: Order = {
      id: "order-001",
      customerId: "c-001",
      items: [{ menuId: "m-001", qty: 1, unitPrice: 500 }],
      total: 500,
      status: "ORDERED"
    };

    const repo: OrderRepository = {
      findById: vi.fn().mockResolvedValue(base),
      save: vi.fn()
    };
    const payment: PaymentGateway = {
      charge: vi.fn().mockResolvedValue(
        err({ kind: "InfraError", code: "PaymentFailed", message: "card rejected" })
      )
    };
    const handler = new PayOrderHandler(repo, payment);

    const result = await handler.handle({ orderId: "order-001", token: "tok" });

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.kind).toBe("InfraError");
      expect(result.error.code).toBe("PaymentFailed");
    }
    expect(repo.save).not.toHaveBeenCalled();
  });

  test("正常系：支払い成功→status が PAID で保存🟢", async () => {
    const base: Order = {
      id: "order-001",
      customerId: "c-001",
      items: [{ menuId: "m-001", qty: 1, unitPrice: 500 }],
      total: 500,
      status: "ORDERED"
    };

    const repo: OrderRepository = {
      findById: vi.fn().mockResolvedValue(base),
      save: vi.fn().mockResolvedValue(undefined)
    };
    const payment: PaymentGateway = {
      charge: vi.fn().mockResolvedValue(ok({ paymentId: "pay-999" }))
    };
    const handler = new PayOrderHandler(repo, payment);

    const result = await handler.handle({ orderId: "order-001", token: "tok" });

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.paymentId).toBe("pay-999");
    }
    expect(payment.charge).toHaveBeenCalledWith(500, "tok");
    expect(repo.save).toHaveBeenCalledWith(
      expect.objectContaining({ status: "PAID", paymentId: "pay-999" })
    );
  });
});
```

---

## 5) テストの実行コマンド🏃‍♀️💨

Vitest は `vitest` が基本で、開発環境だとウォッチに入りやすいよ〜（CIや非対話だと単発へ）([Vitest][1])
単発で回したいなら `vitest run` が公式に用意されてるよ✅([Vitest][1])

```bash
npm test
npm run coverage
```

カバレッジは「v8/istanbul」が選べて、デフォルトは v8 だよ〜📊✨([Vitest][2])

---

## 6) VS Code をもっと楽にする小ワザ🧡🧰

Vitest は **VS Code用の公式拡張**も案内されてるので、テストの成功/失敗がエディタ内で見やすくなるよ👀✨([Vitest][5])
（テスト増えてきたら、これ入れると体験めっちゃ良くなる😊）

---

## 7) AI活用🤖✨（この章でめっちゃ効く！）

おすすめの使い方はこれ〜👇💕

* 「PlaceOrder の異常系、仕様の穴が出やすい入力パターンを10個出して」🧠
* 「このHandler、依存が多すぎる？テストしやすくするリファクタ案ある？」🛠️
* 「このテスト、Assert弱い？どこを検証すべき？」✅

💡コツ：AIに出してもらったテストは、そのまま採用せず
「**仕様として意味がある？**」って一回だけ自分でチェックすると最強だよ😆✨

---

## ミニ演習🎯📝（やると一気に身につく！）

1. PlaceOrder に「unitPrice が 0 のメニューはOK？」を決めて、テストを1本追加🍙
2. PayOrder に「すでに PAID は弾く」をテストで固定💳
3. Repo 保存失敗（例外）を **InfraError** にするテストを追加して、仕様として確定させる🧯

---

## よくある詰まりポイント（先に潰そ〜）🧱😵‍💫

* **“repo.save が呼ばれない”の Assert を忘れてる**
  → 異常系は特に `not.toHaveBeenCalled()` が効くよ✅
* **モジュールモックが効かない**
  → セットアップで読み込んだモジュールはキャッシュされることがあるので、必要なら `vi.resetModules()` みたいな整理も検討だよ🧼✨([Vitest][7])
* **カバレッジで型だけのファイルが 0% になる**
  → “実行されないものはカウントされにくい”はあるある。そこは「仕様としてテストすべきコードか？」で割り切りOK😊

---

## 次章につながるよ〜📘✨

次（第24章）は QueryService のテスト！
Command は「状態を正しく変える」テストで、Query は「返す形（DTO）を守る」テストに寄せると、役割分担がキレイになるよ😆💕

続けて第24章も同じテンションで作る？👀🧪✨

[1]: https://vitest.dev/guide/cli?utm_source=chatgpt.com "Command Line Interface | Guide"
[2]: https://vitest.dev/guide/coverage.html?utm_source=chatgpt.com "Coverage | Guide"
[3]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[4]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[5]: https://vitest.dev/guide/?utm_source=chatgpt.com "Getting Started | Guide"
[6]: https://vitest.dev/config/?utm_source=chatgpt.com "Configuring Vitest"
[7]: https://vitest.dev/api/vi.html?utm_source=chatgpt.com "Vitest"
