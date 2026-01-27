# 第27章 テスト：ハンドラ（副作用が呼ばれたか？）📞🧪

## 🎯 この章のゴール

* ドメインイベントの**ハンドラ**を、**外部I/Oなし**で安全にテストできるようになる🧯✨
* **モック（Mock）/スパイ（Spy）**を使って「呼ばれた？」「何回？」「引数は？」を検証できるようになる👀✅
* **失敗ケース**（外部サービスが落ちた💥）もテストで再現できるようになる😵‍💫➡️🧪

---

## 🧠 まず整理：ハンドラのテストって何を見ればいいの？

ハンドラはだいたい「イベントを受け取って、副作用を起こす係」だよね📩🔔
だからテストは、ざっくりこの3つを見ればOK！✨

1. **呼ばれた？**（副作用が実行されたか）☎️
2. **正しい回数？**（1回だけ？0回？2回以上はダメ？）🔁
3. **正しい内容？**（引数・ログ・送信内容・保存内容）📦🧾

そしてハンドラのテストは、だいたい **Arrange / Act / Assert** の3段でスッキリ書けるよ🧼✨

* Arrange：準備（イベント作る、モック作る）🧰
* Act：実行（handler.handle(event)）▶️
* Assert：確認（呼ばれた回数・引数・例外など）✅

---

## 🧩 テストしやすいハンドラの形：DI（差し替え）で勝つ🎭

外部I/O（メール送信・DB・HTTPなど）を**直で呼ぶ**とテストが地獄👿
だからハンドラは「外部I/Oを **インターフェース越し** に受け取る」形にするよ💡

### ✅ 例：メール送信をするハンドラ（OrderPaid → Email）

```ts
// domainEvent.ts
export type DomainEvent<TType extends string, TPayload> = Readonly<{
  eventId: string
  occurredAt: string // ISO文字列でOK（例: new Date().toISOString()）
  aggregateId: string
  type: TType
  payload: TPayload
}>
```

```ts
// orderPaid.ts
import type { DomainEvent } from "./domainEvent"

export type OrderPaid = DomainEvent<
  "OrderPaid",
  {
    orderId: string
    userId: string
    email: string
    amount: number
    currency: "JPY" | "USD"
  }
>
```

```ts
// ports.ts（外部I/Oはここに置くイメージ）
export interface EmailSender {
  send(to: string, subject: string, body: string): Promise<void>
}

export interface Logger {
  info(message: string, meta?: unknown): void
  error(message: string, meta?: unknown): void
}
```

```ts
// orderPaidEmailHandler.ts
import type { OrderPaid } from "./orderPaid"
import type { EmailSender, Logger } from "./ports"

export class OrderPaidEmailHandler {
  constructor(
    private readonly emailSender: EmailSender,
    private readonly logger: Logger,
  ) {}

  async handle(event: OrderPaid): Promise<void> {
    const { email, amount, currency, orderId } = event.payload

    // ガード：送れないなら何もしない（テストしやすい！）🛡️
    if (!email) return

    try {
      await this.emailSender.send(
        email,
        "お支払い完了のお知らせ💳✨",
        `ご注文 ${orderId} のお支払いが完了しました！\n金額：${amount} ${currency}`,
      )

      this.logger.info("OrderPaid email sent", { eventId: event.eventId, orderId })
    } catch (e) {
      // 失敗時の方針：ログして投げ直す（この章ではこの形でいくよ）🚨
      this.logger.error("OrderPaid email failed", { eventId: event.eventId, error: e })
      throw e
    }
  }
}
```

ポイント💡

* ハンドラは **EmailSender を知らない**（ただの interface として扱う）🎭
* だからテスト側で EmailSender を **モックに差し替え**できる🪄

---

## 🧪 Vitestで「副作用が呼ばれたか？」をテストする📞✅

ここでは **Vitest** の `vi.fn()` / `vi.spyOn()` を使うよ✨
（モックの基本は `vi` って覚えるとラク！）🧠

### ✅ テスト：メール送信が1回呼ばれる📩

```ts
// orderPaidEmailHandler.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest"
import { OrderPaidEmailHandler } from "./orderPaidEmailHandler"
import type { EmailSender, Logger } from "./ports"
import type { OrderPaid } from "./orderPaid"

const createEvent = (): OrderPaid => ({
  eventId: "evt-001",
  occurredAt: new Date().toISOString(),
  aggregateId: "order-001",
  type: "OrderPaid",
  payload: {
    orderId: "order-001",
    userId: "user-001",
    email: "a@example.com",
    amount: 1200,
    currency: "JPY",
  },
})

describe("OrderPaidEmailHandler", () => {
  let sendMock: ReturnType<typeof vi.fn<(to: string, subject: string, body: string) => Promise<void>>>
  let logger: Logger
  let handler: OrderPaidEmailHandler

  beforeEach(() => {
    sendMock = vi.fn<(to: string, subject: string, body: string) => Promise<void>>()
      .mockResolvedValue(undefined)

    const emailSender: EmailSender = { send: sendMock }

    logger = {
      info: vi.fn(),
      error: vi.fn(),
    }

    handler = new OrderPaidEmailHandler(emailSender, logger)

    vi.clearAllMocks() // 念のためスッキリ🧼
  })

  it("メール送信が1回呼ばれる📩✅", async () => {
    // Arrange
    const event = createEvent()

    // Act
    await handler.handle(event)

    // Assert
    expect(sendMock).toHaveBeenCalledTimes(1)
    expect(sendMock).toHaveBeenCalledWith(
      "a@example.com",
      expect.stringContaining("完了"),
      expect.stringContaining("1200"),
    )

    expect(logger.info).toHaveBeenCalledTimes(1)
    expect(logger.error).toHaveBeenCalledTimes(0)
  })
})
```

### ✅ テスト：emailが空なら「何もしない」🚫📩

```ts
it("emailが空なら送らない🚫📩", async () => {
  const event = createEvent()
  event.payload.email = ""

  await handler.handle(event)

  expect(sendMock).toHaveBeenCalledTimes(0)
  expect(logger.info).toHaveBeenCalledTimes(0)
  expect(logger.error).toHaveBeenCalledTimes(0)
})
```

---

## 💥 失敗ケースのテスト：外部サービスが落ちたらどうなる？

「メール送信が失敗した」みたいなケース、テストでちゃんと再現しよ🧨🧪

### ✅ テスト：EmailSenderが失敗したら例外が投げられる😵‍💫

```ts
it("送信に失敗したら例外を投げてログに残す🚨", async () => {
  const event = createEvent()
  sendMock.mockRejectedValueOnce(new Error("SMTP Down"))

  await expect(handler.handle(event)).rejects.toThrow("SMTP Down")

  expect(logger.error).toHaveBeenCalledTimes(1)
  expect(sendMock).toHaveBeenCalledTimes(1)
})
```

ここで大事なのは、

* **失敗時の方針（投げ直す？握りつぶす？リトライ要求？）**を先に決めること📌
* 決めたら、**テストで固定**すること🧷✅

---

## 👀 Spy（スパイ）って何？ `vi.spyOn` の使いどころ

* `vi.fn()`：ゼロから偽物の関数を作る（モック）🎭
* `vi.spyOn()`：既存オブジェクトのメソッドを監視する（スパイ）👀

### ✅ 例：既存オブジェクトの info を監視する🕵️‍♀️

```ts
it("logger.info が呼ばれたか spy で見る👀", async () => {
  const event = createEvent()

  const infoSpy = vi.spyOn(logger, "info")

  await handler.handle(event)

  expect(infoSpy).toHaveBeenCalledTimes(1)
})
```

---

## 🧯 よくある落とし穴（ハンドラテストあるある）🤣

### 1) 「実装の細部」をテストしすぎる👗💦

* ❌ メール本文が1文字違うだけで落ちるテスト
* ✅ 「送信された」「重要な情報が含まれる」くらいに寄せる

  * `expect.stringContaining(...)` がちょうど良いよ🧡

### 2) モックを作りすぎて何のテストかわからなくなる🧟‍♀️

* まずは **必要最小限**（今回なら EmailSender と Logger だけ）でOK👌

### 3) テスト間で呼び出し履歴が残る😱

* `beforeEach` で作り直すか、`vi.clearAllMocks()` を使う🧼✨

---

## 📝 演習（やってみよう）💪🧪

### 演習1：ポイント付与ハンドラをテストしよう🪙

* `OrderPaid` を受けて `PointsService.add(userId, points)` を呼ぶハンドラを書く
* テストで👇を確認！

  * ✅ 1回呼ばれた
  * ✅ 引数が正しい
  * ✅ `amount=0` のときは呼ばれない

### 演習2：通知ハンドラを2種類に分けて、それぞれテスト📣📩

* 「メール通知」と「アプリ内通知」を別ハンドラにして
* それぞれ “自分の副作用だけ” をテストする🎯✨

### 演習3：失敗時の方針を変えてテストも変える🔁🚨

* 例）失敗したら例外にせず、`logger.error` だけ残して終わる
* その方針に合わせてテストも作り直す✍️

---

## 🤖 AI活用（Copilot / Codex向け）プロンプト例🧠✨

* 「このハンドラのテスト観点を **Given/When/Then** で10個出して」🧾
* 「Vitestで `vi.fn()` を使って **型安全なモック** を作る例を3パターン」🧩
* 「このテスト、**実装依存になってる部分**を見つけて改善案ちょうだい」🔍
* 「失敗時の方針（投げ直す/握る/リトライ）ごとのテスト例を比較して」⚖️

---

## ✅ まとめ（この章で覚えたいこと）🎀

* ハンドラテストは「副作用が呼ばれたか？」を見る📞✅
* 外部I/Oは **interface + DI** で差し替え可能にする🎭
* `vi.fn()` でモック、`vi.spyOn()` で監視👀
* 失敗ケースもテストで再現して、方針を固定する🧷🚨

---

## 📚 参考（公式）🔗

* Vitest：モックの考え方（Mocking Guide） ([Vitest][1])
* Vitest：`vi` API（モック関連） ([Vitest][2])
* Vitest：モジュールのモック（Mocking Modules） ([Vitest][3])

[1]: https://vitest.dev/guide/mocking?utm_source=chatgpt.com "Mocking | Guide"
[2]: https://vitest.dev/api/vi.html?utm_source=chatgpt.com "Vitest"
[3]: https://vitest.dev/guide/mocking/modules?utm_source=chatgpt.com "Mocking Modules"
