# 第32章 any卒業①（unknownへの切り替え）🎓🧷

## ねらい🎯

* `any` の「型チェック無効化スイッチ」状態を減らして、**壊れにくいコード**に近づける🛡️✨
* まずは第一歩として、`any` を **`unknown` に置き換える**流れを身につける👣
* 「中身が分からない値」は **境界で受け止めて、確認してから使う**癖をつける🚪📦✅

---

## 今日のゴール✅

* `any` を見つけられる🔍
* `any` → `unknown` に置換できる🔁
* `unknown` を安全に使うための「最小の確認」を入れられる🧪✅
* そして大事：**`unknown` を広げずに“境界に寄せる”**感覚が分かる🧱🌱

---

## まず知っておきたい：any が危ない理由💣😵‍💫

`any` は「何でもできる」代わりに、TypeScript の型チェックがほぼ効かなくなる“脱法ハッチ”です🚪💨
プロパティもメソッドも、存在してなくても通ってしまい、**実行時に落ちる**可能性が上がります⚠️
TypeScript の公式ドキュメントでも、`any` は型チェックを段階的に外すための手段で、`unknown` とは安全性が違うと説明されています。 ([TypeScript][1])

---

## unknown って何？🧩❓（ざっくり：中身不明の箱📦）

* `unknown` は **「何が入ってるか分からない」**を表す型📦
* どんな値でも入れられるけど、**そのままでは触れない**（= 安全）🛡️
* だから「確認してから使う」流れを自然に強制できます✅

`any` と `unknown` の違いは、`unknown` だと型ガード（確認）が必要になる点がポイントです🧷
公式の説明や例でも、`unknown` は `any` より安全な代替として扱われています。 ([TypeScript][1])

---

## いつ unknown を使うの？🧭✨（使いどころは“境界”）

`unknown` は、だいたいここで出てきます👇

* `JSON.parse()` の結果（中身が何か分からない）🧾
* API から返ってきた JSON（形が保証されない）🌐
* 外部ライブラリ・プラグイン・イベントの `payload`（型が曖昧）🧰
* ユーザー入力（フォーム、URLクエリ、ローカルストレージ等）⌨️🫧

ここでの合言葉はこれ👇
**「境界では unknown で受けて、内側では型を確定させる」**🚪➡️🏠✅

---

## 手順👣：any → unknown に置き換える“安全ステップ”🛟

### 1) any を見つける🔍

よくある場所👇

* `: any`
* `as any`
* `any[]`
* `Record<string, any>`
* `JSON.parse(...)` をそのまま使ってる箇所

---

### 2) まず置換：any → unknown 🔁🧷

「とりあえず unknown にする」だけで、**危ない操作がコンパイルエラーで止まる**ようになります🚦

---

### 3) unknown を触る場所に“確認”を入れる✅

確認のやり方は色々あるけど、この章では **最小の確認**だけやります🧁
（細かい絞り込みテクは次の章で強化🔍🧩）

---

## 例①：JSON.parse の any を卒業🎓🧾

### ビフォー😵‍💫（any でスルーしちゃう）

```ts
type User = { id: string; name: string };

export function parseUser(json: string): User {
  const obj: any = JSON.parse(json);
  return { id: obj.id, name: obj.name.toUpperCase() };
}
```

これ、`name` が無かったり `null` だったりすると実行時に落ちます💥

---

### アフター✨（unknown で受けて、確認してから使う）

```ts
type User = { id: string; name: string };

export function parseUser(json: string): User {
  const raw: unknown = JSON.parse(json);

  if (!isRecord(raw)) {
    throw new Error("Invalid JSON: not an object");
  }

  const id = raw["id"];
  const name = raw["name"];

  if (typeof id !== "string") {
    throw new Error("Invalid JSON: id must be string");
  }
  if (typeof name !== "string") {
    throw new Error("Invalid JSON: name must be string");
  }

  return { id, name: name.toUpperCase() };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
```

ポイント👇

* `unknown` にした瞬間、雑なアクセスは止められる🚦
* “使う直前”に **型チェック（確認）**してから進む✅🧷

---

## 例②：fetch().json() の戻りを unknown で受ける🌐🧪

`Response.json()` は型的に扱いがゆるくなりがちなので、境界として `unknown` で受けるのが安全です🛡️

### ビフォー😬

```ts
const data: any = await (await fetch("/api/user")).json();
console.log(data.user.name);
```

### アフター✨

```ts
type ApiUser = { user: { name: string } };

const raw: unknown = await (await fetch("/api/user")).json();

if (!isApiUser(raw)) {
  throw new Error("API response is invalid");
}

console.log(raw.user.name);

function isApiUser(value: unknown): value is ApiUser {
  if (!isRecord(value)) return false;
  const user = value["user"];
  if (!isRecord(user)) return false;
  return typeof user["name"] === "string";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
```

こうしておくと、API が壊れても「静かにバグる」より先に「ちゃんと止まる」方向に寄ります🛑✨

---

## “unknown化”のコツ🌸（失敗しにくい考え方）

### コツ1：unknown をアプリの奥まで運ばない🚫📦

`unknown` のままアプリ内部に持ち込むと、毎回チェックが必要でしんどいです😵‍💫
**境界で受けて、早めに型を確定**させましょう✅

### コツ2：「確認→型確定→それ以降は普通に書く」🧷➡️🧠

* 境界：`unknown`
* 内側：ちゃんと型が付いた値（`User` とか）

これが一番ラクで強いです💪✨

---

## Lintで any を増やさない🚫🧯（おすすめ設定）

`@typescript-eslint/no-explicit-any` を有効にすると、明示的な `any` を検出できます👮‍♀️⚠️
ルールページでも、`unknown` が代替案として挙げられています。 ([TypeScript ESLint][2])

### 例：Flat Config の最小イメージ🧩

```ts
// eslint.config.mjs の一例（ルールだけ抜粋）
export default [
  {
    rules: {
      "@typescript-eslint/no-explicit-any": "error",
    },
  },
];
```

（Flat Config 例も公式ルールページに載っています📄） ([TypeScript ESLint][2])

---

## どうしても any を使いたい時の“最小ダメージ”戦略🛟⚠️

「今すぐ全部直せない…😭」は普通にあります。そんな時は👇

### ✅ 方針

* **アダプタ（境界）に閉じ込める**🧱
* **理由を書く**📝
* 後で直せるように **小さく隔離**📦

### 例：1行だけ抑える（理由コメントつき）🧯

```ts
// TODO: 外部ライブラリの型が不完全。次のタイミングで型定義を改善する。
/* eslint-disable-next-line @typescript-eslint/no-explicit-any */
const x: any = legacyLib.getValue();
```

ESLint の無効化コメントの書き方は定番として知られています。 ([Stack Overflow][3])

---

## AI活用ポイント🤖✨（お願い方＋チェック観点✅）

### ① any 探し＆置換案を出してもらう🔍

お願い例👇

* 「このプロジェクトで `any` / `as any` の使用箇所を列挙して、`unknown` への置換案を提案して」
* 「境界（API/JSON.parse/外部入力）だけ `unknown` にして、アプリ内部では型を確定させる方針で直して」

### ② “確認が足りない場所”をレビューしてもらう✅

お願い例👇

* 「`unknown` を触っている箇所で、型チェック不足の可能性がある場所を指摘して」
* 「この型ガード、抜け道ある？（null/配列/ネスト/型違い）」

### ③ でも最後は自分で確認👀🧪

AIの提案は便利だけど、**実行時チェックの正しさ**は人間の目で最終確認が安心です🧷✨

---

## ミニ課題✍️🎀（手を動かして覚える！）

次のコードの `any` を `unknown` に変えて、落ちないようにしてね✅

### お題コード🧩

```ts
type Settings = { theme: "light" | "dark"; fontSize: number };

export function readSettings(json: string): Settings {
  const obj: any = JSON.parse(json);
  return {
    theme: obj.theme,
    fontSize: obj.fontSize,
  };
}
```

### やること✅

* `obj: any` を `raw: unknown` に変更🔁
* `theme` が `"light" | "dark"` かチェック🚦
* `fontSize` が number かチェック🔢
* ダメなら `throw new Error(...)` で止める🛑

---

## 章末チェックリスト🧿✨

* `any` を見つけたら、まず `unknown` に置けた？🔁
* `unknown` を触る前に、最小の確認を入れた？✅
* `unknown` をアプリの奥まで運んでない？🚫📦
* “境界で受けて、内側で型確定”になってる？🚪➡️🏠
* `@typescript-eslint/no-explicit-any` で増殖を防げてる？👮‍♀️⚠️ ([TypeScript ESLint][2])

---

## （ミニ豆知識）2026年1月25日時点の TypeScript 周辺の動き🧠✨

* 安定版としては TypeScript 5.9 系が公開されているのが確認できます（GitHub Releases 上で 5.9 が先頭に表示）。 ([GitHub][4])
* TypeScript 6.0 は「橋渡し（bridge）」的な位置づけで、TypeScript 7（ネイティブ化）に向けた計画が公式ブログで説明されています。 ([Microsoft for Developers][5])

[1]: https://www.typescriptlang.org/docs/handbook/basic-types.html?utm_source=chatgpt.com "TypeScript: Handbook - Basic Types"
[2]: https://typescript-eslint.io/rules/no-explicit-any/?utm_source=chatgpt.com "no-explicit-any"
[3]: https://stackoverflow.com/questions/59147324/disable-typescript-eslint-plugin-rule-no-explicit-any-with-inline-comment?utm_source=chatgpt.com "Disable typescript-eslint plugin rule (no-explicit-any) with ..."
[4]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[5]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
