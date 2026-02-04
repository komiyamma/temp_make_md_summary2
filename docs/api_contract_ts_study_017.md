# 第17章：エラーも契約②：利用者に優しい返し方🎁✨

## 17.1 この章でできるようになること🎯🌸

エラーを「その場しのぎ」じゃなく、**利用者（呼び出し側）が直しやすい“約束”**として作れるようになります😊✨

* どんな情報を返すと親切かが分かる🧭
* エラー形式を**毎回同じ形**にそろえられる📦
* 「メッセージはやさしく、でも機械的にも扱える」設計ができる🤖💡
* 互換性（後方互換）を壊さずにエラーを育てられる🌱🔁

---

## 17.2 まず結論：良いエラーは「4点セット」🎁🧁

利用者が困るのは、だいたいこの2パターンです😵‍💫

* 「何が起きたか分からない」
* 「直し方が分からない」

そこで、エラーは基本 **この4点セット**で返すのが超おすすめです✨

1. **安定したエラーコード**（機械が見て分かるID）🏷️
2. **短く要点の人間向けメッセージ**（何がダメ？）💬
3. **対処ヒント**（どう直す？）🛠️
4. **追跡ID（traceId / requestId）**（運営・調査が速い）🧵🔍

さらに余裕があれば👇も足すと強いです💪

* **どの項目がダメか**（バリデーション詳細）🧾
* **ドキュメントURL**（仕様ページへ誘導）📚✨

---

## 17.3 HTTP APIなら “Problem Details” が大本命🦴🌐✨

HTTP APIのエラーレスポンスは、**Problem Details** という標準があって、今は **RFC 9457** が最新版です📜✨（昔のRFC 7807を置き換え）([rfc-editor.org][1])

### ✅ 代表フィールド（覚えるのはこれだけでOK）💡

* `type`：エラーの種類を表すURI（自分のドメインでOK）🔗
* `title`：短いタイトル（人間向け）📰
* `status`：HTTPステータスコード🔢
* `detail`：もう少し詳しい説明（人間向け）📝
* `instance`：このエラー事象の識別子（任意）🧾

※ `Content-Type: application/problem+json` を使うのが基本だよ〜🥰([rfc-editor.org][1])

---

## 17.4 例：利用者に優しいエラーの完成形🎁✨

### 17.4.1 ありがちな「悪い例」😇→😱

* ステータスだけ返す：`400`（中身なし）🥶
* `message: "error"` だけ返す😵
* スタックトレースや内部情報をそのまま返す（危険！）💥

内部情報の出しすぎは、セキュリティ的にNGになりやすいです🚫（デバッグ情報やスタックトレースをそのまま返さない、機密情報を漏らさない等）([devguide.owasp.org][2])

### 17.4.2 「良い例」🌸✨（Problem Details + 拡張フィールド）

```json
{
  "type": "https://example.com/problems/validation-error",
  "title": "入力に問題があります",
  "status": 400,
  "detail": "email の形式が正しくありません",
  "errors": [
    { "field": "email", "code": "invalid_format", "message": "メールアドレスの形式で入力してね" }
  ],
  "errorCode": "USER_EMAIL_INVALID",
  "traceId": "01HZY8P9H9K0Q8B2Y7R2D0N1QG"
}
```

ポイントはこれ👇

* `errorCode` は **安定ID**（クライアントはこれで分岐できる）🏷️
* `detail` / `errors[].message` は **人間が直せる言葉**💬
* `traceId` で問い合わせ・ログ追跡が速い🧵🔍（多くのガイドでも相関IDが重要視されます）([Microsoft Learn][3])

---

## 17.5 ステータスコードの選び方（よく使う7つ）🎛️✨

HTTPステータスコードは「何が起きたか」の大分類です📌
意味づけは HTTP 仕様で定義されています📜([datatracker.ietf.org][4])

| 状況        | 代表ステータス | 例                 | ひとこと                 |
| --------- | ------: | ----------------- | -------------------- |
| 入力が変・足りない |     400 | JSONが壊れてる / 必須が無い | まず入力を直そう🧾           |
| 認証してない    |     401 | トークン無し/期限切れ       | ログインしてね🔐            |
| 権限がない     |     403 | ロール不足             | 権限が必要だよ🛡️           |
| 対象がない     |     404 | IDのデータが無い         | 見つからない🔍             |
| 競合した      |     409 | 二重登録 / 更新競合       | 状態がぶつかった⚔️           |
| 制限にかかった   |     429 | 回数多すぎ             | 少し待ってね⏳              |
| サーバ側の失敗   | 500/503 | バグ/一時障害           | ごめんね（でも追跡IDは出す）🧑‍🔧 |

---

## 17.6 TypeScriptの関数・ライブラリは「Result型」か「例外」か🎭🟦

HTTPだけじゃなく、**関数APIも契約**だよ〜😊✨
ここでは「呼び出し側が扱いやすい」設計に寄せます🎁

### パターンA：Result型（失敗も値として返す）🎁✅

「失敗は想定内」なら、Resultがすごく親切🌸

```ts
type AppError = {
  code: "USER_EMAIL_INVALID" | "USER_ALREADY_EXISTS";
  message: string;           // 人間向け（表示用）
  hint?: string;             // 対処ヒント
};

type Result<T> =
  | { ok: true; value: T }
  | { ok: false; error: AppError };

function registerUser(email: string): Result<{ userId: string }> {
  if (!email.includes("@")) {
    return {
      ok: false,
      error: {
        code: "USER_EMAIL_INVALID",
        message: "メールアドレスの形式が正しくないよ",
        hint: "例：name@example.com の形で入力してね"
      }
    };
  }
  // ...
  return { ok: true, value: { userId: "u_123" } };
}
```

👍 いいところ

* 呼び出し側が `if (!result.ok)` で確実に扱える✅
* 例外で落ちないから初心者にも読みやすい🌷

### パターンB：例外（想定外・異常系は throw）💥🧯

「ネットワーク障害」「DB死んだ」みたいな **想定外**は例外が合うことも多いです⚡

```ts
class DomainError extends Error {
  constructor(
    public readonly code: "USER_ALREADY_EXISTS",
    message: string,
    public readonly hint?: string
  ) {
    super(message);
    this.name = "DomainError";
  }
}

function assertUserNotExists(email: string) {
  // 例：既にいる
  throw new DomainError(
    "USER_ALREADY_EXISTS",
    "そのメールアドレスは既に登録されているよ",
    "ログインするか、パスワード再設定を試してね"
  );
}
```

✅ 例外運用のコツ

* `throw "文字列"` はやめよう🥺（情報が足りない）
* **code/hint** を持つError型にするのが親切💖
* 外側で `catch (e: unknown)` → きれいな形に変換して返す🧼✨

---

## 17.7 エラーコード設計：互換性の“地雷”を避ける💣➡️🌸

エラーコードは「契約そのもの」なので、ここが雑だと後で詰みます😇💥

### ✅ エラーコードのルール（おすすめ）🏷️

* **意味が変わらない**名前にする（安定ID）🧷
* 文字列は `UPPER_SNAKE` などで統一🧼
* 「メッセージ」は変えてOK（表示文は改善して良い）✍️✨
* 分岐ロジックは **messageでしない**（codeでやる）🤖

### 🔁 互換性の考え方（超重要）

* `errorCode` を削除する → 破壊変更😱
* `errorCode` の意味を変える → 破壊変更😱
* 新しい `errorCode` を追加する → 多くの場合は安全🌱
* `errors[]` の要素を追加する → 基本は安全（ただし仕様に依存）🧾

---

## 17.8 セキュリティとやさしさを両立するコツ🛡️🎀

「親切にしたい！」の気持ちで、内部情報を出しすぎると危険です⚠️
**スタックトレース、ファイルパス、SQL、秘密情報**は返さないのが基本🚫([devguide.owasp.org][2])

### ✅ 表に出してOK寄り

* 入力ミスの場所（field名）🧾
* 直し方の例（フォーマット例）🧁
* traceId（調査用）🧵

### ❌ 表に出しちゃダメ寄り

* 例外スタックトレース（そのまま）🧨
* DBのテーブル名やSQL全文🗄️
* サーバ構成や内部パス🧱

「外にはやさしく」「中（ログ）には詳しく」✨
これが黄金バランスです😊🌸

---

## 17.9 ミニ演習：悪いエラー → 良いエラーに変身させよう🪄✨

### お題①：これを直す🧪

**悪い例**

```json
{ "message": "Invalid request" }
```

**やること✅**

* どの項目が何でダメかを入れる
* `errorCode` を付ける
* `traceId` を付ける

### お題②：これも直す🧪

**悪い例**（危険）

```json
{
  "message": "NullReferenceException at UserService.cs:91 ...",
  "stack": "..."
}
```

**やること✅**

* 外には「起きたこと」と「対処」だけ
* 内部情報はログへ（外に出さない）

---

## 17.10 AI活用（プロンプト例）🤖🌸

コピペで使えるやつ置いとくね〜💖

* 「このAPIの失敗パターンを洗い出して、`errorCode`案を10個出して」🧠
* 「このエラーをProblem Details（RFC 9457）形式に整形して。`errors[]`も付けて」🧾([rfc-editor.org][1])
* 「利用者が直しやすい“対処ヒント”を1行で添えて」🛠️
* 「このエラー設計、内部情報漏えいリスクない？危ない点を指摘して」🛡️([devguide.owasp.org][2])

---

## 17.11 まとめ：この章のチェックリスト✅🎀

リリース前にこれを見れば安心度アップ✨

* [ ] エラー形式が常に同じ（毎回同じキー構造）📦
* [ ] `errorCode` がある（機械が分岐できる）🏷️
* [ ] メッセージが「直し方」に寄ってる（やさしい）💬
* [ ] バリデーションは `errors[]` 等で項目単位が分かる🧾
* [ ] `traceId` / `requestId` がある（調査が速い）🧵🔍([Microsoft Learn][3])
* [ ] スタックトレース等を外に出してない🛡️([devguide.owasp.org][2])
* [ ] ステータスコードの意味が合ってる📜([datatracker.ietf.org][4])

---

次の章では、エラーだけじゃなく **データ（JSON）の契約**も「壊さず育てる」方向に入っていくよ〜🧬✨

[1]: https://www.rfc-editor.org/rfc/rfc9457.html?utm_source=chatgpt.com "RFC 9457: Problem Details for HTTP APIs"
[2]: https://devguide.owasp.org/en/04-design/02-web-app-checklist/10-handle-errors-exceptions/?utm_source=chatgpt.com "Handle all Errors and Exceptions"
[3]: https://learn.microsoft.com/en-us/javascript/api/%40azure/identity/errorresponse?view=azure-node-latest&utm_source=chatgpt.com "ErrorResponse interface"
[4]: https://datatracker.ietf.org/doc/html/rfc9110?utm_source=chatgpt.com "RFC 9110 - HTTP Semantics"
