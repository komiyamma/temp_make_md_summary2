# 第22章　エラー設計②（境界でどう返す？Result/例外）🎯🧰✨

この章はね、「エラーを“どう返すか”をチームで揃えて、UIもAPIも迷子にしない」回だよ〜！🥳💖
CQRSだと特に **Command側は“失敗”が起きやすい**（支払いできない、とか）から、ここを整えると一気に強くなる🔥

---

## 0) この章でできるようになること ✅✨

* 「想定内の失敗」と「想定外の事故」を分けられる🙂🧠
* CommandHandlerの返り値を **Result型** にして、呼び出し側で必ず処理できるようにする🧩
* APIの“境界”でエラーを **HTTPの返し方に変換**できるようにする🌐🚪
* 返却フォーマットを統一して、フロントが超ラクになる🙌🎀
* 最後の砦として **グローバル例外ハンドラ** も作れる🛡️⚠️

---

## 1) まず結論：Result と 例外の使い分け（超だいじ）🧡

### ✅ Result（推し🥰）

**「仕様として起こり得る失敗」** を返す用✨
例：

* 注文が存在しない（NotFound）
* もう支払い済み（Conflict）
* 状態的に支払い不可（Business rule）
* 入力が不正（Validation）

👉 これらは「バグ」じゃなくて「ありがちな現実」だよね🙂

### ⚠️ 例外（最後の砦）

**「基本起きないはずの事故」** 用😵‍💫
例：

* DB接続が落ちてる
* コードのバグ（null参照とか）
* あり得ない状態（不変条件破壊）

👉 例外は便利だけど、投げまくると「どこで失敗したか追えない」「握りつぶされる」になりがち🥲

---

## 2) “境界”ってどこ？（ここで返し方を決める！）🚪🌐

CQRSでいう境界は、だいたいここ👇

* HTTP API の Controller / Route（いちばん多い）🌐
* CLIコマンドの入口（管理コマンドとか）🖥️
* Queue/Job の入口（非同期処理）📨

**ドメインやHandlerはHTTPを知らない**のがキレイ✨
だから **境界で「DomainError → HTTPレスポンス」** に変換するよ！

---

## 3) エラー返却フォーマットは「Problem Details」寄せが強い🥇✨

HTTPのエラー返却を統一する“型”として、**RFC 9457（Problem Details）** があるよ〜！📄✨
これは **RFC 7807を置き換える形**で整理された標準だよ🧠📌 ([RFCエディタ][1])

返すJSONの基本形（ざっくり）👇

* type（エラーの種類を表すURIっぽいやつ）
* title（短い要約）
* status（HTTPステータス）
* detail（人間向け詳細）
* instance（どのリクエストで起きたか）

Content-Type はだいたい「application/problem+json」🎯 ([RFCエディタ][1])

---

## 4) 実装していこ〜！🛠️💕（Result → DomainError → Problem Details）

### 4-1) Result型（最小構成）を作る🧩✨

まずは依存なしで自作しちゃう（学習に最高）😆
（もちろん、後でライブラリに差し替えもOK！）

```ts
// src/shared/result.ts
export type Ok<T> = { ok: true; value: T };
export type Err<E> = { ok: false; error: E };
export type Result<T, E> = Ok<T> | Err<E>;

export const ok = <T>(value: T): Ok<T> => ({ ok: true, value });
export const err = <E>(error: E): Err<E> => ({ ok: false, error });
```

💡人気のResultライブラリとして「neverthrow」もあるよ（Ok/Err と ResultAsync が揃ってて便利）🧁🤖 ([GitHub][2])
（でも最初は自作でぜんぜんOK！）

---

### 4-2) DomainError を「コード付き」で作る（UIが嬉しい）🏷️✨

エラーは **“分類”だけじゃなく、機械が扱える code** を持たせると神👼✨
フロントが「codeで分岐」できるから、文言変更しても壊れにくいよ💪

```ts
// src/domain/errors/domainError.ts
export type DomainError =
  | { kind: "NotFound"; code: "ORDER_NOT_FOUND"; message: string }
  | { kind: "Conflict"; code: "ORDER_ALREADY_PAID"; message: string }
  | { kind: "Rule"; code: "ORDER_NOT_PAYABLE"; message: string }
  | { kind: "Validation"; code: "INVALID_COMMAND"; message: string; fields?: Record<string, string[]> };
```

ポイントはこれ👇

* kind：HTTP寄せの分類に使える🎯
* code：UI分岐の鍵🔑
* message：ログや開発向け（ユーザー文言はUIで差し替えてもOK）🧸

---

### 4-3) CommandHandler は Result を返す（投げない）🧼🚫

例：PayOrder（支払い）💳✨

```ts
// src/commands/payOrder/payOrderHandler.ts
import { Result, ok, err } from "../../shared/result";
import { DomainError } from "../../domain/errors/domainError";

type PayOrderCommand = { orderId: string; paidAt: string };

export class PayOrderHandler {
  constructor(
    private readonly orderRepo: { findById(id: string): Promise<any | null>; save(order: any): Promise<void> }
  ) {}

  async handle(cmd: PayOrderCommand): Promise<Result<{ orderId: string }, DomainError>> {
    const order = await this.orderRepo.findById(cmd.orderId);
    if (!order) {
      return err({ kind: "NotFound", code: "ORDER_NOT_FOUND", message: "注文が見つかりません" });
    }

    if (order.status === "PAID") {
      return err({ kind: "Conflict", code: "ORDER_ALREADY_PAID", message: "すでに支払い済みです" });
    }

    if (order.status !== "ORDERED") {
      return err({ kind: "Rule", code: "ORDER_NOT_PAYABLE", message: "この状態では支払いできません" });
    }

    order.status = "PAID";
    order.paidAt = cmd.paidAt;

    await this.orderRepo.save(order);
    return ok({ orderId: order.id });
  }
}
```

👉 これで呼び出し側は **「成功 or 失敗」を必ず分岐**できるようになるよ〜！🥳

---

## 5) いちばん大事：境界（API）で “返す形” に変換する🌐🎁

ここからが第22章のメイン🍰✨
「DomainErrorをどうHTTPにする？」を **一箇所に集約**する！

### 5-1) 入力バリデーションは境界でやる（Zodが便利）🧁✅

Zodは **TypeScript-firstのバリデーションライブラリ**で、実行時に検証しつつ型も推論できるよ✨ ([Zod][3])

```ts
// src/api/schemas.ts
import { z } from "zod";

export const PayOrderSchema = z.object({
  orderId: z.string().min(1),
  paidAt: z.string().min(1) // 本当は日時形式チェックしてもOK🙂
});
export type PayOrderRequest = z.infer<typeof PayOrderSchema>;
```

---

### 5-2) Problem Details っぽいレスポンスを作る関数🧩✨

```ts
// src/api/problemDetails.ts
import { DomainError } from "../domain/errors/domainError";

export type ProblemDetails = {
  type: string;
  title: string;
  status: number;
  detail?: string;
  instance?: string;
  code?: string;
  traceId?: string;
  errors?: Record<string, string[]>;
};

export function domainErrorToProblem(e: DomainError, traceId: string, instance?: string): ProblemDetails {
  // type は「分類のURIっぽい文字列」でOK（社内ルールで固定すると◎）
  switch (e.kind) {
    case "NotFound":
      return {
        type: "https://example.com/problems/not-found",
        title: "Not Found",
        status: 404,
        detail: e.message,
        code: e.code,
        traceId,
        instance
      };
    case "Conflict":
      return {
        type: "https://example.com/problems/conflict",
        title: "Conflict",
        status: 409,
        detail: e.message,
        code: e.code,
        traceId,
        instance
      };
    case "Rule":
      return {
        type: "https://example.com/problems/rule-violation",
        title: "Rule Violation",
        status: 422,
        detail: e.message,
        code: e.code,
        traceId,
        instance
      };
    case "Validation":
      return {
        type: "https://example.com/problems/validation",
        title: "Validation Error",
        status: 400,
        detail: e.message,
        code: e.code,
        traceId,
        instance,
        errors: e.fields
      };
  }
}
```

📌 422（Unprocessable Entity）は「形は合ってるけど意味がダメ」系でよく使われるよ🙂✨
（Conflictで返してもOK。ここはチーム規約で揃えるのが勝ち！🏆）

---

### 5-3) Route（境界）での組み立て例（Express想定）🚦✨

```ts
// src/api/routes/payOrderRoute.ts
import express from "express";
import { randomUUID } from "crypto";
import { PayOrderSchema } from "../schemas";
import { domainErrorToProblem } from "../problemDetails";
import { PayOrderHandler } from "../../commands/payOrder/payOrderHandler";
import { err } from "../../shared/result";

export function buildPayOrderRouter(handler: PayOrderHandler) {
  const router = express.Router();

  router.post("/pay", express.json(), async (req, res, next) => {
    const traceId = req.header("x-trace-id") ?? randomUUID();
    const instance = req.originalUrl;

    // 1) 入力チェック（境界で！）
    const parsed = PayOrderSchema.safeParse(req.body);
    if (!parsed.success) {
      const fields: Record<string, string[]> = {};
      for (const issue of parsed.error.issues) {
        const key = issue.path.join(".") || "body";
        fields[key] = [...(fields[key] ?? []), issue.message];
      }

      const problem = domainErrorToProblem(
        { kind: "Validation", code: "INVALID_COMMAND", message: "入力が正しくありません", fields },
        traceId,
        instance
      );

      return res.status(problem.status).type("application/problem+json").json(problem);
    }

    // 2) Handler実行（Resultで返ってくる✨）
    const result = await handler.handle(parsed.data);

    if (result.ok) {
      return res.status(200).json({ orderId: result.value.orderId, traceId });
    }

    // 3) DomainError → HTTP Problem Details へ変換
    const problem = domainErrorToProblem(result.error, traceId, instance);
    return res.status(problem.status).type("application/problem+json").json(problem);
  });

  return router;
}
```

✅ これでフロントは「status + code + errors」を見れば、ほぼ全部さばける！🎉

* 404：注文ない
* 409：すでに支払い済み
* 422：状態的に無理
* 400：入力ダメ（フィールド別エラーあり）

---

## 6) 例外は“最後の砦”として一箇所で握る🛡️⚠️

Resultで処理しきれない事故（DB落ち、バグ）はここで回収する💪
※ detail に生の例外メッセージを出すのは、基本やめよ（情報漏れしがち）🥲

```ts
// src/api/globalErrorHandler.ts
import { Request, Response, NextFunction } from "express";
import { randomUUID } from "crypto";

export function globalErrorHandler(err: unknown, req: Request, res: Response, _next: NextFunction) {
  const traceId = req.header("x-trace-id") ?? randomUUID();

  // ここでログ（traceId付き）を出すと調査が爆速になるよ🕵️‍♀️✨
  console.error("Unhandled error", { traceId, err });

  const problem = {
    type: "https://example.com/problems/internal",
    title: "Internal Server Error",
    status: 500,
    detail: "サーバー側で問題が起きました。時間をおいて再度お試しください。",
    traceId,
    instance: req.originalUrl
  };

  res.status(500).type("application/problem+json").json(problem);
}
```

---

## 7) 仕上げ：エラー対応の“型”をチームで固定しよう🧷✨

### ✅ 最低限固定したいルール（おすすめ）📌

* **DomainError は必ず code を持つ**（UI分岐が安定）🔑
* **HTTPは境界だけが知る**（ドメインに混ぜない）🧼
* **“想定内”は Result、“想定外”は例外**（事故の見える化）👀
* **Problem Details 形式で統一**（返却のブレを消す）🧠 ([RFCエディタ][1])
* **traceId を返す**（問い合わせ対応が神になる）📞✨

---

## 8) ミニ演習（手を動かすやつ）✍️🎀

### 演習A：PlaceOrder にも同じ仕組みを入れる🍙

* 入力Zod → Result → Problem Details
* メニューIDが存在しない場合：

  * kind を NotFound にする？ Rule にする？（チームで決めよ🙂）

### 演習B：フロントで code 分岐して表示を変える🖥️💖

* ORDER_ALREADY_PAID → 「支払い済みです」
* ORDER_NOT_PAYABLE → 「注文状態を確認してね」
* INVALID_COMMAND → フィールドエラーをフォームに表示

---

## 9) AI活用🤖✨（Copilot/ChatGPTに投げると強いプロンプト例）

* 「このPayOrderの仕様から、起こり得るDomainErrorを列挙して、kindとcodeを提案して」🧠📋
* 「Problem Detailsの返却フォーマットを固定したい。フロントが扱いやすいプロパティ案を出して」🎁
* 「statusとcodeの対応表を作って。409/422の使い分けも提案して」🎯
* 「Zodのissuesからフィールド別 errors を組み立てる関数をもう少し綺麗にして」🧼✨

---

## 10) ちょい最新メモ（周辺状況）🗞️✨

* TypeScript は GitHubのReleases上では **5.9.3 が “Latest”** として表示されているよ📌 ([GitHub][4])
* Node.js は **24系がActive LTS** として扱われていて、2026-01-13に 24.13.0(LTS) のリリースも出てるよ🔐✨ ([Node.js][5])
* TypeScriptコンパイラの高速化（Go移植のプレビュー）も進んでて、エコシステムはまだ伸びてる感じ🥳🚀 ([InfoQ][6])

---

## まとめ 🎉💗

この章のゴールはこれだったね👇
**「HandlerはResultで返す」→「境界でHTTPに変換」→「返却フォーマットを統一」** ✨

これができると、CQRSの開発がほんとに楽になるよ〜！😆🫶
次の章（テスト）で、このエラー設計がそのままテストの書きやすさに直結して「うわ、気持ちいい…」ってなるはず🥰🧪

[1]: https://www.rfc-editor.org/rfc/rfc9457.html?utm_source=chatgpt.com "RFC 9457: Problem Details for HTTP APIs"
[2]: https://github.com/supermacro/neverthrow?utm_source=chatgpt.com "supermacro/neverthrow: Type-Safe Errors for JS & TypeScript"
[3]: https://zod.dev/?utm_source=chatgpt.com "Zod: Intro"
[4]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[5]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[6]: https://www.infoq.com/news/2026/01/typescript-7-progress/?utm_source=chatgpt.com "Microsoft Share Update on TypeScript 7"
