# 第38章 I/Oを外へ（テスタブル設計の入口）🚪🧪

### ねらい🎯

* 「テストしづらいコード」の正体＝**I/O（入出力）**を見抜けるようになる👀✨
* **ロジック（考える部分）**を、I/O（外の世界）から分離できるようになる🧠🧩
* まずは「純粋関数っぽい中心（コア）」＋「薄いアダプタ（外側）」を作れるようになる🥚➡️🐣

---

### I/Oってなに？（“外の世界”のことだよ🌍）📥📤

I/Oは、だいたいこういうやつ👇（覚えやすい！）

* 🌐 API通信（`fetch`）
* 💾 ファイル読み書き（`fs`）
* 🧺 DBアクセス
* ⏰ 現在時刻（`Date.now()`）
* 🎲 乱数（`Math.random()`）
* 🧪 環境変数（`process.env`）
* 🖨️ ログ出力（`console.log`）

ポイントはこれ👇
**I/Oがロジックのど真ん中にいると、テストが急にむずくなる**😵‍💫💥
（外部の状態・ネットワーク・時間に引っ張られて、結果が安定しないから）

ちなみに今どきのNodeでは `fetch` が安定版として扱われていて（Node 21で stable 扱いになった話があるよ）、“外部I/O”の代表格としてめちゃ分かりやすい題材です🌐✨ ([Node.js][1])

---

### 今日の合言葉🧙‍♀️✨：「コアは静かに、外側はうすく」

* **コア（中心）**：データを受け取って計算し、結果を返すだけ（副作用なし）🧠
* **外側（アダプタ）**：API呼ぶ、保存する、ログ出す…などI/O担当🏃‍♀️💨

イメージ👇

* 外側（I/O） → コア（ロジック） → 外側（I/O）
  「サンドイッチ」みたいに挟む🥪✨

---

## コード例（ビフォー/アフター）🧩➡️✨

### お題：ユーザーを取得して、挨拶メッセージを作る💌

* APIでユーザーを取る（I/O）🌐
* メッセージを組み立てる（ロジック）🧠
* ログを出す（I/O）🖨️
* 時刻も入れる（I/Oっぽい：時間依存）⏰

---

### Before：I/Oとロジックが混ざっててテストしづらい😵‍💫

```ts
type User = { id: string; name: string; plan: "free" | "pro" };

export async function getWelcomeMessage(userId: string): Promise<string> {
  const baseUrl = process.env.API_BASE_URL ?? "https://example.com";
  const prefix = process.env.WELCOME_PREFIX ?? "Hello";

  console.log("Fetching user...", userId);

  const res = await fetch(`${baseUrl}/users/${userId}`);
  if (!res.ok) throw new Error("Failed to fetch user");

  const user = (await res.json()) as User;

  const now = new Date(); // 時刻依存
  const planLabel = user.plan === "pro" ? "🌟PRO" : "🆓FREE";

  const message = `${prefix}, ${user.name}! (${planLabel}) - ${now.toISOString()}`;
  console.log("Done");

  return message;
}
```

**テストがつらい理由**💦

* `process.env` をいじらないと動かない🧪
* `fetch` が本当に通信しちゃう（遅い・不安定）🌩️
* 時刻で結果が変わる（スナップショット壊れる）⏰
* ログが混ざる（テスト出力がうるさい）🖨️

---

### After：I/Oを外へ！コアがテストしやすい😍🧪

「メッセージを組み立てる」部分を**純粋関数っぽく**するよ🧠✨
（“っぽく”でOK！最初は完璧じゃなくていい🙂🌸）

#### 1) コア：組み立てだけ（I/Oなし）🧠

```ts
type User = { id: string; name: string; plan: "free" | "pro" };

export function buildWelcomeMessage(
  user: User,
  opts: { prefix: string; nowIso: string }
): string {
  const planLabel = user.plan === "pro" ? "🌟PRO" : "🆓FREE";
  return `${opts.prefix}, ${user.name}! (${planLabel}) - ${opts.nowIso}`;
}
```

#### 2) 外側：I/Oを担当する（fetch/env/log/time）🏃‍♀️💨

ここは“薄く”するのがコツ！🥚✨

```ts
import { buildWelcomeMessage } from "./buildWelcomeMessage";

type User = { id: string; name: string; plan: "free" | "pro" };

export async function getWelcomeMessage(userId: string): Promise<string> {
  const baseUrl = process.env.API_BASE_URL ?? "https://example.com";
  const prefix = process.env.WELCOME_PREFIX ?? "Hello";

  console.log("Fetching user...", userId);

  const res = await fetch(`${baseUrl}/users/${userId}`);
  if (!res.ok) throw new Error("Failed to fetch user");

  const user = (await res.json()) as User;

  const message = buildWelcomeMessage(user, {
    prefix,
    nowIso: new Date().toISOString(),
  });

  console.log("Done");
  return message;
}
```

✅ これで **テストしたい中心（buildWelcomeMessage）** は、
*通信なし・環境変数なし・時間固定できる* になった！🎉🧪

---

## 手順（小さく刻む）👣✨：I/O追い出し4ステップ

### ステップ1：I/Oに蛍光ペンを引く🖍️👀

対象関数の中で、これを探す👇

* `fetch` / `fs` / `process.env` / `Date.now` / `new Date` / `Math.random` / `console`

見つけたら「外の世界だ！」って印をつける🌍✅

### ステップ2：ロジックの“目的”を1文で言う💬✨

例：
*「ユーザー情報から挨拶メッセージを作る」💌

この“目的”が **コア** になる🎯

### ステップ3：コア関数を作って、必要なものは引数で受け取る📦

* 時刻 → `nowIso` を引数へ⏰➡️📦
* prefix → `prefix` を引数へ🏷️➡️📦
* ユーザー → `user` を引数へ👤➡️📦

ここで大事：**コアの中でI/Oしない**🙅‍♀️✨

### ステップ4：外側（アダプタ）にI/Oをまとめる🏃‍♀️💨

外側はやることがシンプルになる👇

* 値を集める（env/time/API）
* コアに渡す
* 結果を返す

---

## テスト例（Vitest）🧪✨

2026年1月時点だと、Vitestは v4 系が案内されてる流れがあるよ📌 ([Vitest][2])
（もちろん他のテストでもOKだけど、ここでは軽くて速い路線で！🚀）

### buildWelcomeMessage は超テストしやすい💖

```ts
import { describe, it, expect } from "vitest";
import { buildWelcomeMessage } from "./buildWelcomeMessage";

describe("buildWelcomeMessage", () => {
  it("proユーザーのメッセージを作れる🌟", () => {
    const msg = buildWelcomeMessage(
      { id: "1", name: "Mika", plan: "pro" },
      { prefix: "Hi", nowIso: "2026-01-25T00:00:00.000Z" }
    );

    expect(msg).toBe("Hi, Mika! (🌟PRO) - 2026-01-25T00:00:00.000Z");
  });

  it("freeユーザーのメッセージを作れる🆓", () => {
    const msg = buildWelcomeMessage(
      { id: "2", name: "Saki", plan: "free" },
      { prefix: "Hello", nowIso: "2026-01-25T00:00:00.000Z" }
    );

    expect(msg).toBe("Hello, Saki! (🆓FREE) - 2026-01-25T00:00:00.000Z");
  });
});
```

✅ 通信ゼロ！環境変数ゼロ！時刻固定！
テストが「スパッと終わる」感じになるよ〜😄🧪✨

---

## よくあるつまずきポイント（回避！）🧯😺

### つまずき1：外へ出しすぎて、どこで何してるか迷子🌀

* まずは **「コア1個」** でOK！
* 外側は薄く！薄く！🥚✨

### つまずき2：コアが結局 `process.env` を読んでる😇

* コアは **引数で受け取る** が基本📦

  * `prefix: string`
  * `nowIso: string`
  * `featureFlags: {...}` とか

### つまずき3：時刻や乱数が混ざってテストが不安定⏰🎲

* `nowIso` や `randomValue` を **引数** にしちゃうと一発で安定するよ🧷✨

---

## ミニ課題✍️💖（I/O追い出し練習）

次の関数を「コア」と「外側」に分けてね👣✨

### Before（練習用）

```ts
import { readFile } from "node:fs/promises";

type Profile = { name: string; likes: number; badges: string[] };

export async function loadAndRankProfile(path: string): Promise<string> {
  const json = await readFile(path, "utf-8"); // I/O
  const profile = JSON.parse(json) as Profile;

  const now = new Date().toISOString(); // 時刻依存
  const score = profile.likes + profile.badges.length * 10;

  return `${profile.name} score=${score} @ ${now}`;
}
```

### ゴール🎯

* コア関数例：`rankProfile(profile, { nowIso }) => string` 🧠
* 外側：`readFile` と `JSON.parse` と `new Date()` を担当🏃‍♀️

できたら、**コアにテストを1本**つけよう🧪✨

---

## AI活用ポイント🤖✨（お願い方＋チェック観点✅）

### ① I/O洗い出し依頼🖍️

「この関数の中にあるI/O（外部依存）を全部列挙して、理由も一言で書いて」

### ② 分離の設計案を3パターン出させる🧩

「I/Oを外へ出す分け方を “小さめ/ふつう/しっかり” の3案で。各案のメリット・デメリットも」

### ③ テスト生成（ただし検証は必須！）🧪

「この純粋関数に対して、境界値と代表ケースのテストをVitestで。期待値は文字列で固定して」

### ✅ AIの提案を採用する前のチェック（お守り）🧿

* 返り値の形式、句読点、空白、絵文字が変わってない？🧐
* エラー時の挙動（throwする/しない）が変わってない？⚠️
* 入力が `undefined` のときの扱いが変わってない？🫧
* 差分は説明できる？📝
* 型チェック＆テストで確認した？🧷🧪

---

## 2026年1月時点の“最新メモ”🗓️📌

* TypeScript の npm 上の最新は **5.9.3** と表示されてるよ📦✨ ([NPM][3])
* Node.js は **v24 が Active LTS** として案内されてる（LTSを使うと安定運用しやすい💖） ([Node.js][4])

---

## まとめ🌸

* テストしづらい原因の多くは **I/Oがロジックに混ざってる**こと😵‍💫
* **コア（純粋関数っぽい中心）**を作って、I/Oは外側へ📤✨
* コアができると、テストが速い・安定・気持ちいい😍🧪🚀

[1]: https://nodejs.org/en/blog/announcements/v21-release-announce?utm_source=chatgpt.com "Node.js 21 is now available!"
[2]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[3]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[4]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
