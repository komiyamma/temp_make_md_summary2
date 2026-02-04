# 第19章：データ契約②：実行時バリデーション（型だけじゃ足りない）🚫✅

## この章のゴール🎯✨

* 「型があるのに壊れる」理由を、ちゃんと説明できるようになる🙂💡
* 入力の“境界（boundary）”で、**unknown を安全にチェックしてから中に入れる**流れを作れるようになる🚪✅
* 失敗したときに、利用者が直しやすいエラーを返せるようになる📣🍰

---

## 1) なんで型だけじゃ足りないの？😵‍💫

TypeScriptの型は、基本的に **実行時には存在しない**（コードとして動いてくれない）からだよ〜！
だから「型が合ってる前提」で進むと、外から来たデータ（HTTP/JSON/フォーム/DB/環境変数など）で普通に事故る💥

たとえば、これ👇はコンパイルは通るのに、実行時に壊れがちパターン😇

```ts
// 期待している型（契約）🌸
type User = {
  id: string;
  name: string;
  age?: number;
};

async function fetchUser(): Promise<User> {
  const res = await fetch("/api/user");
  // ⚠️ res.json() は基本「信用していい型」じゃないのに…
  const data = await res.json();
  return data as User; // ← ここで「信じ込む」と事故りやすい💥
}

async function demo() {
  const u = await fetchUser();

  // もし age が "20" (文字列) で来たら…？
  // +1 が "201" みたいな文字列結合になったりする😱
  const next = (u.age ?? 0) + 1;
  console.log(next);
}
```

「satisfies 演算子」みたいな機能もあるけど、これは **型チェック（コンパイル時）**の話で、実行時データを検証してくれるわけじゃないよ🙂‍↔️（型の確認はするけど、値を“チェックして直す/弾く”処理は走らない）([typescriptlang.org][1])

---

## 2) 解決の基本方針：「境界でチェック、内部は信頼」🧠🔒

おすすめの考え方はこれ！

* 外から入ってくるデータは、まず **unknown 扱い**にする🕵️‍♀️
* 境界で **バリデーション（検証）**する✅
* 通ったものだけ、アプリ内部の「信頼できる世界」に入れる🌈

このメリハリができると、内部のコードがスッキリするし、バグが減るよ〜😊✨

---

## 3) 実行時バリデーションの代表選手たち🏃‍♀️💨

ここでは超ざっくり「どれを選ぶ？」の目安ね👇

### A. Zod（定番のスキーマバリデーション）🧩

* スキーマを作って `.parse()` / `.safeParse()` で検証できる✅
* スキーマから型も推論できる（`z.infer`）🟦
* Zod 4 は stable として提供されてるよ🧡([Zod][2])

### B. Valibot（小さめ＆モジュール志向）🪶

* 「型は実行されない、スキーマは実行できる」って説明が分かりやすい✨
* バンドルサイズを小さくしたい時にも候補になる📦([valibot.dev][3])

### C. Ajv（JSON Schema）📜

* JSON Schema を使う派なら強い💪
* TSと組み合わせる機能（型ガード等）もあるよ🧠([ajv.js.org][4])

この章では、まず **Zod** で「境界で守る型」を体験していくよ〜😊🧁

---

## 4) ハンズオン：Zodで「境界チェック」を作ってみよう🧪✨

### 4-1. 例題の契約（入力）を決める🧾

「ユーザー作成APIの入力」を想定してみよ〜📮
入力（JSON）に期待するのはこんな感じ👇

* name: 1文字以上の文字列（前後の空白は許すけど、保存前に整える）✂️
* age: 任意。あるなら 0以上の整数🎂
* email: “それっぽい形式”の文字列📧

### 4-2. スキーマを書く（＝実行時に動く契約）🧩

```ts
import * as z from "zod";

// ✅ これが「動く契約」だよ〜！
const CreateUserInput = z.object({
  name: z.string().trim().min(1, "name は必須だよ"),
  age: z.number().int().min(0).optional(),
  email: z.string().email("email の形式が変だよ"),
});

// ✅ スキーマから型を作る（型と実行時契約がズレにくい！）
type CreateUserInput = z.infer<typeof CreateUserInput>;
```

Zodは、スキーマを定義して `.parse()` で検証し、成功すれば型付きデータを返してくれるよ✅([Zod][2])

### 4-3. 境界で safeParse（失敗も丁寧に扱える）🧯

`.parse()` は失敗すると例外になるけど、`.safeParse()` は **成功/失敗の結果オブジェクト**で返してくれるから扱いやすいよ〜😊
（成功/失敗の分岐が書きやすい形になってる）([Zod][2])

```ts
type ValidationErrorResponse = {
  code: "INVALID_INPUT";
  message: string;
  issues: Array<{
    path: string;
    message: string;
  }>;
};

export function validateCreateUserInput(raw: unknown):
  | { ok: true; data: CreateUserInput }
  | { ok: false; error: ValidationErrorResponse } {

  const result = CreateUserInput.safeParse(raw);

  if (!result.success) {
    return {
      ok: false,
      error: {
        code: "INVALID_INPUT",
        message: "入力がルールに合ってないよ🥲",
        issues: result.error.issues.map((i) => ({
          path: i.path.join("."),
          message: i.message,
        })),
      },
    };
  }

  return { ok: true, data: result.data };
}
```

これで、外から来たデータを **いったん unknown で受けて**、通ったものだけ `CreateUserInput` として扱えるようになったよ🎉✨

### 4-4. 使う側（内部）は「信頼できる世界」🌈

```ts
async function handleCreateUser(body: unknown) {
  const v = validateCreateUserInput(body);

  if (!v.ok) {
    // ここで HTTP 400 を返すイメージ📣
    return { status: 400, json: v.error };
  }

  // ✅ ここから先は型も値も、最低限の整合が取れてる世界
  const { name, age, email } = v.data;
  // 例：DB保存、重複チェック…などなど🗃️
  return { status: 201, json: { id: "new-id", name, age, email } };
}
```

---

## 5) Zod 4 の「オブジェクトの厳しさ」どうする？🤔🔧

「余計なキーが来たらどうする？」って、契約ではわりと大事だよね👀

Zod 4 では、オブジェクトの扱いとして **strict / loose** 方向のAPIが用意されてるよ（移行ガイドで触れられてる）🧭([Zod][5])

* 厳しめ：想定外のキーを許さない🚫
* ゆるめ：想定外のキーがあっても通す🫶

どっちが正解というより、「契約としてどうしたい？」で決めるのがポイントだよ😊✨

---

## 6) “境界チェック”観点表（ミニ演習）📋🔍

自分のアプリで、境界になってる場所を思い出して埋めてみてね〜📝✨

| 境界（どこから入る？）🚪  | 入ってくる形🧾         | ありがちな事故💥    | チェックすること✅        | 失敗時の返し方📣    |
| -------------- | ---------------- | ------------ | ---------------- | ------------ |
| HTTPのリクエストbody | JSON             | 型が違う/必須欠け    | 必須/型/範囲/形式       | 400 + issues |
| クエリ文字列         | string           | 数値が文字列       | 変換/範囲            | 400 + ヒント    |
| localStorage   | string           | JSON.parse失敗 | try/catch + スキーマ | 初期化/警告       |
| 環境変数           | string/undefined | 未設定          | 必須/形式            | 起動時に落とす      |

---

## 7) よくある落とし穴あるある😇💣

* `as SomeType` で“信じ込む” → 契約違反が内部まで侵入する🧟‍♀️
* `any` を境界に置く → 事故が静かに増える🫠
* バリデーションのエラーが「Invalid input」だけ → 利用者が直せない😢
* チェックがあちこちに散る → 仕様変更で漏れやすい🕳️

👉 対策はシンプルで、**境界に集約**して、**エラーを分かりやすく**することだよ😊💕

---

## 8) AI活用プロンプト集🤖💖

コピペで使えるやつ置いとくね〜🎁✨

* 「この入力仕様（name, age, email）に対して、危ない入力パターンを20個出して。境界で弾くべき理由も」⚠️
* 「Zodのスキーマを作って。trim/範囲/形式/必須/任意も入れて」🧩
* 「バリデーション失敗時のエラーレスポンスを、利用者が直しやすい形に整えて」📣
* 「このスキーマの“後方互換を壊しやすい変更”をリスト化して」🔁

---

## 9) まとめ🌸✅

* 型は心強いけど、**外から来るデータは型だけじゃ守れない**😵‍💫
* **unknown → 境界で実行時バリデーション → 内部は信頼** の流れが最強💪✨
* 失敗した時は、**どこがダメで、どう直せばいいか**を返すのが優しさだよ🍰💕

次の章（第20章）では、「安全な変更・危険な変更」を **“判定できる目”** にしていくよ〜🧬⚖️

[1]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html?utm_source=chatgpt.com "Documentation - TypeScript 4.9"
[2]: https://zod.dev/basics "Basic usage | Zod"
[3]: https://valibot.dev/ "Valibot: The modular and type safe schema library"
[4]: https://ajv.js.org/guide/typescript.html "Using with TypeScript | Ajv JSON schema validator"
[5]: https://zod.dev/v4/changelog "Migration guide | Zod"
