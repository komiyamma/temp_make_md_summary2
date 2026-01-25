# 第28章 if/switch整理（分岐を育てる）🧭🧹

### ねらい🎯

分岐（if/switch）が増えても、**読める・直せる・追加できる**形に整えるよ✨
「巨大switchで毎回ビクビク😵‍💫」を卒業しよう〜！🎓🌸

---

### 今日のゴール🏁

* 巨大な `if / switch` を **小さく分解**できる✂️📦
* **共通処理**と**ケース固有処理**を分けられる🧩✨
* ケース追加での「入れ忘れ😱」を **型やLintで検知**できるようにする🧷✅ ([TypeScript ESLint][1])

---

## まず知っておく！分岐が巨大化する“よくある原因”👃💦

### ① 1つの関数に色んな役割が混ざってる🎭

* 表示ロジック
* 計算ロジック
* データ整形
* 例外処理
  …が1つの `switch` に全部のってると、肥大化しやすいよ〜😵

### ② caseごとにちょっとずつ違う＆共通もある🧩

「似た処理が毎回出てくる」→ コピペ増殖🐛
「共通の修正を入れたのに一部だけ直し忘れ」→ バグ💥

---

## 例題：巨大switchを育て直す🌱🧹

「通知の種類（type）ごとにメッセージを作る」…みたいな場面を想像してね📣✨

### Before（ありがちな巨大switch）😵‍💫

```ts
type NotifyType =
  | "WELCOME"
  | "PASSWORD_RESET"
  | "BILLING_FAILED"
  | "PROMO";

type User = { id: string; name: string; email: string; locale: "ja" | "en" };
type Payload = { url?: string; amount?: number; campaignId?: string };

export function buildMessage(
  type: NotifyType,
  user: User,
  payload: Payload,
): { subject: string; body: string } {
  switch (type) {
    case "WELCOME": {
      const subject = user.locale === "ja" ? "ようこそ！" : "Welcome!";
      const body =
        user.locale === "ja"
          ? `${user.name}さん、はじめまして！`
          : `Hi ${user.name}, nice to meet you!`;
      return { subject, body };
    }

    case "PASSWORD_RESET": {
      if (!payload.url) {
        return { subject: "Reset", body: "Missing reset url" };
      }
      const subject = user.locale === "ja" ? "パスワード再設定" : "Password Reset";
      const body =
        user.locale === "ja"
          ? `こちらから再設定できます: ${payload.url}`
          : `Reset here: ${payload.url}`;
      return { subject, body };
    }

    case "BILLING_FAILED": {
      const subject = user.locale === "ja" ? "決済失敗" : "Billing Failed";
      const amountText = payload.amount ? `${payload.amount}円` : "(不明)";
      const body =
        user.locale === "ja"
          ? `支払いに失敗しました。金額: ${amountText}`
          : `Payment failed. Amount: ${amountText}`;
      return { subject, body };
    }

    case "PROMO": {
      const subject = user.locale === "ja" ? "キャンペーン！" : "Promo!";
      const body =
        user.locale === "ja"
          ? `今すぐチェック: ${payload.campaignId ?? "(IDなし)"}`
          : `Check now: ${payload.campaignId ?? "(no id)"}`;
      return { subject, body };
    }
  }
}
```

**しんどいポイント**😵‍💫

* `locale` 分岐が各caseで繰り返し🔁
* `payload` の不足チェックがcaseごとにバラバラ🧨
* ケース追加が怖い（入れ忘れそう）😱

---

## 手順（小さく刻む）👣✨

### 0️⃣ 先に安全ネット🛡️

最低限これを回せる状態で進めよう✅

* 型チェック（`tsc`）🧷
* テスト（あるなら）🧪
* 実行での動作確認▶️

---

### 1️⃣ 「共通」と「差分」を分けてメモ📝

この例だと…

* 共通：`locale` による文章切り替え🌍
* 差分：通知タイプごとのテンプレ＆payload要件📦

ここが見えたら勝ち！🏆✨

---

### 2️⃣ “メッセージ作り”を小さい関数に分割✂️📦

まずは **caseの中身を関数へ**（これだけで急に読みやすくなる！）😍

```ts
type Message = { subject: string; body: string };

function msgJa(subject: string, body: string): Message {
  return { subject, body };
}
function msgEn(subject: string, body: string): Message {
  return { subject, body };
}

function welcomeMessage(user: User): Message {
  return user.locale === "ja"
    ? msgJa("ようこそ！", `${user.name}さん、はじめまして！`)
    : msgEn("Welcome!", `Hi ${user.name}, nice to meet you!`);
}

function passwordResetMessage(user: User, payload: Payload): Message {
  if (!payload.url) {
    return msgEn("Password Reset", "Missing reset url");
  }
  return user.locale === "ja"
    ? msgJa("パスワード再設定", `こちらから再設定できます: ${payload.url}`)
    : msgEn("Password Reset", `Reset here: ${payload.url}`);
}

// ... billingFailedMessage / promoMessage も同様に
```

ここまでできたら、`switch` は「交通整理係🚦」にできるよ✨

---

### 3️⃣ switchを“薄く”して、見通しを良くする🚦✨

```ts
export function buildMessage(type: NotifyType, user: User, payload: Payload): Message {
  switch (type) {
    case "WELCOME":
      return welcomeMessage(user);

    case "PASSWORD_RESET":
      return passwordResetMessage(user, payload);

    case "BILLING_FAILED":
      return billingFailedMessage(user, payload);

    case "PROMO":
      return promoMessage(user, payload);
  }
}
```

💡この形になると…

* `switch` は「どこへ行く？」だけ🧭
* 詳細は各関数の中📦
  で、読むのがめっちゃ楽になるよ〜😍

---

### 4️⃣ 「ただの振り分け」なら、辞書（マップ）にする📚✨

`switch` が **“type → 関数”** の対応だけなら、こう書けるよ👇

```ts
const handlers = {
  WELCOME: (user: User, payload: Payload) => welcomeMessage(user),
  PASSWORD_RESET: (user: User, payload: Payload) => passwordResetMessage(user, payload),
  BILLING_FAILED: (user: User, payload: Payload) => billingFailedMessage(user, payload),
  PROMO: (user: User, payload: Payload) => promoMessage(user, payload),
} satisfies Record<NotifyType, (user: User, payload: Payload) => Message>;

export function buildMessage(type: NotifyType, user: User, payload: Payload): Message {
  return handlers[type](user, payload);
}
```

ここで使ってる `satisfies` は、
**「キーの網羅性チェックをしつつ、型推論のうまみも残す」**のが得意だよ🧷✨ ([TypeScript入門『サバイバルTypeScript』][2])
（キーを追加し忘れたら、型チェックで気づける！👀✅）

---

## 超だいじ！defaultの扱い🧨➡️✅

### ✅ default を置くのが自然なとき

* 外部入力（API/DB/ユーザー入力）などで、**想定外が来る可能性がある**🌪️
  → その場合は **バリデーション** or **defaultで安全に落とす**のが良いよ🛟

### ✅ default を置かない方が強いとき

* `NotifyType` みたいに **ユニオン型で“許される値”が決まってる**とき
  → 「全部書けてる？」を **Lint/型**で守れる🧷✅ ([TypeScript ESLint][1])

---

## ケース追加の「抜け」を機械に見つけてもらう🤖🧷✅

### 1) ESLintで switch 網羅性チェックをON👮‍♀️✨

`@typescript-eslint/switch-exhaustiveness-check` を使うと、
ユニオン型の `switch` で **case不足**を警告してくれるよ🚨 ([TypeScript ESLint][1])

（例：ESLint設定のイメージ）

```json
{
  "rules": {
    "@typescript-eslint/switch-exhaustiveness-check": "error"
  }
}
```

ルールは「defaultがあると不足を見逃しやすい」みたいな考え方も含んでるよ📌 ([TypeScript ESLint][1])

---

## VS Codeでの作業のコツ🧑‍💻✨（時短！）

* 範囲選択 → **Ctrl + .** で「Extract function」などのリファクタ候補が出るよ✂️✨ ([Visual Studio Code][3])
* 関数名や型名のリネームも、参照込みで安全にできる🏷️✅ ([Visual Studio Code][4])

---

## AI活用ポイント🤖✨（お願い方＋チェック観点✅）

### 使いどころ①：caseの分割案を出してもらう🧩

お願い例👇

* 「このswitchを、caseごとに関数抽出して読みやすくして。副作用は変えないで」
* 「共通処理（locale分岐）をまとめる案を3つ出して。メリット/デメリットも」

チェック観点✅

* 差分が小さい？👣
* 返り値・例外・ログが変わってない？🔍
* `tsc` とテストが通る？🧷🧪

---

### 使いどころ②：ケース追加での“抜け”探し👀

お願い例👇

* 「NotifyTypeに 'SURVEY' を追加した想定で、修正が必要な場所を列挙して」

チェック観点✅

* handlersのキー追加漏れがない？📚
* 例外ケース（payload不足）をどう扱う？🛟

---

## ミニ課題✍️🌸（やってみよ〜！）

次の巨大switchを、今日の手順で整理してみてね🧹✨

### 課題：決済手段ごとの表示テキスト💳

要件：

* `method` ごとに表示文言を返す
* いまは `switch` が巨大＆共通処理が重複してる
* 目標：**case関数化 → switch薄型化 → 可能ならhandlers化**📚✨

```ts
type PayMethod = "CARD" | "BANK" | "APPLE_PAY" | "GOOGLE_PAY";
type Locale = "ja" | "en";

export function labelPayMethod(method: PayMethod, locale: Locale): string {
  switch (method) {
    case "CARD": {
      return locale === "ja" ? "クレジットカード" : "Credit Card";
    }
    case "BANK": {
      return locale === "ja" ? "銀行振込" : "Bank Transfer";
    }
    case "APPLE_PAY": {
      return locale === "ja" ? "Apple Pay" : "Apple Pay";
    }
    case "GOOGLE_PAY": {
      return locale === "ja" ? "Google Pay" : "Google Pay";
    }
  }
}
```

### クリア条件✅

* `switch` が「振り分けだけ」になってる🚦✨
* `handlers` にした場合、**キーの網羅性が型で守られてる**🧷✅（`satisfies` など） ([TypeScript入門『サバイバルTypeScript』][2])
* 新しい決済手段を追加したとき、**抜けが見つかりやすい構造**になってる🧠✨ ([TypeScript ESLint][1])

---

## 仕上げチェックリスト🧿✅

* `switch` は薄い？🚦
* caseの中身は小さい関数へ行ってる？📦
* 共通処理は共通化できた？🔁
* defaultは「必要な理由」がある？🧨➡️🛟
* 型/Lintで追加漏れを検知できる？🧷✅ ([TypeScript ESLint][1])

---

### おまけ：最新のTypeScript周辺メモ🗒️✨

TypeScriptのリリースノートは **5.9** が公開されていて、npm上でも **5.9.x** が最新として案内されてるよ🧷📦 ([TypeScript][5])
さらに TypeScriptの“ネイティブ化”の話（TypeScript 7 / Project Corsa）も進捗が出てるよ🚀（プレビュー/進行中） ([Microsoft Developer][6])

[1]: https://typescript-eslint.io/rules/switch-exhaustiveness-check/?utm_source=chatgpt.com "switch-exhaustiveness-check"
[2]: https://typescriptbook.jp/reference/values-types-variables/satisfies?utm_source=chatgpt.com "satisfies演算子「satisfies operator」"
[3]: https://code.visualstudio.com/docs/languages/typescript?utm_source=chatgpt.com "TypeScript in Visual Studio Code"
[4]: https://code.visualstudio.com/docs/editing/refactoring?utm_source=chatgpt.com "Refactoring"
[5]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[6]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026?utm_source=chatgpt.com "TypeScript 7 native preview in Visual Studio 2026"
