# 第35章 Union型で状態を表す（許される値を固定）🚦🧷

### ねらい🎯

「状態（status）」に **変な値が入らない** ようにして、バグと迷子を減らすよ〜！😊✨
文字列の `"pending"` とか `"done"` みたいな **決まった値** を、TypeScriptの型でガチガチに守る章です🛡️

---

### 今日のゴール🏁

次の3つができたら勝ち〜！🎉

* status を `string` じゃなくて **Union型** にする🏷️
* `"pendng"` みたいな **タイプミスがコンパイルで止まる** ようにする🧯
* 状態が増えても破綻しにくい「増やし方の型」を覚える🌱

---

### まずは「あるある地獄」😇🔥（ビフォー）

status を `string` にすると…こうなる👇

```ts
type Task = {
  id: string;
  title: string;
  status: string; // 😇 なんでも入っちゃう
};

const task: Task = {
  id: "1",
  title: "レポート",
  status: "pendng", // 😇 ミスっても通る（つらい）
};
```

#### 何が困るの？🌀

* タイプミスが **実行するまで気づけない** 😭
* 「どんな値が来るの？」がコードから分からない👀💦
* UIの分岐（表示切り替え）が増えるほど事故る🚑

---

### 解決！Union型で「許可リスト」を作る✅✨（アフター）

status を「この中だけOK！」って固定するよ〜🚦

```ts
type Status = "todo" | "doing" | "done";

type Task = {
  id: string;
  title: string;
  status: Status;
};

const ok: Task = { id: "1", title: "レポート", status: "doing" }; // ✅

const ng: Task = {
  id: "2",
  title: "買い物",
  // @ts-expect-error ❌ "pendng" は許可されてない！
  status: "pendng",
};
```

Union型（`A | B | C`）は「どれか1つ」しか入らない型だよ🧷
TypeScript公式でも Union型は基本として説明されてるよ〜📚✨ ([TypeScript][1])

---

### 🍬 2026の“今”のTypeScript豆知識

現時点の安定版は **TypeScript 5.9 系（例: 5.9.3）** が最新として案内されてるよ🧑‍💻✨ ([npm][2])
（6.0/7.0に向けた動きも進んでるよ〜という公式の進捗記事もあるよ📣） ([Microsoft for Developers][3])

※この章のUnion型の考え方は、バージョンが進んでもずっと超定番👍

---

## 手順（小さく刻む）👣✨

### Step 1：まず「許される状態」を日本語で書き出す📝💡

例：タスクなら…

* 未着手
* 作業中
* 完了

これをそのまま **リテラルUnion** にするよ🚦
（リテラル型はTypeScript公式でも説明されてるよ） ([TypeScript][4])

---

### Step 2：`string` を Union型に置き換える🔁🧷

```ts
type Status = "todo" | "doing" | "done";

type Task = {
  status: Status;
};
```

---

### Step 3：既存コードの「比較」や「代入」を直す🔧🧹

`if (task.status === "done")` みたいなのはそのままOK！
でも、怪しいのはここ👇

* 外部入力（URLパラメータ、APIレスポンス、localStorage）から直接入れてる😱
* `status = someString` みたいに雑に代入してる😇

---

### Step 4：外から来る値は「チェックしてから」入れる🛟✅

Union型は **実行時に勝手に検証してくれるわけじゃない** からね！⚠️
（型はコンパイル時の安全ネット🧷）

例えば API から `unknown` が来る想定で👇

```ts
const statuses = ["todo", "doing", "done"] as const;
type Status = typeof statuses[number];

function isStatus(value: unknown): value is Status {
  return typeof value === "string" && (statuses as readonly string[]).includes(value);
}

function parseStatus(value: unknown): Status {
  if (isStatus(value)) return value;
  return "todo"; // デフォルトに寄せる作戦🛟
}
```

ポイント💡

* `as const` を付けると、配列の中身が `"todo"` みたいな **リテラル** として保持されるよ✨
* `typeof statuses[number]` で「配列の要素のUnion型」が作れるよ🎯

---

## 実戦ミニ例：UI表示がスッキリする🌸✨

status が固定されると、分岐が読みやすくなるよ〜👀

```ts
type Status = "todo" | "doing" | "done";

function statusLabel(status: Status): string {
  if (status === "todo") return "未着手";
  if (status === "doing") return "作業中";
  return "完了";
}
```

「え、`return "完了"` で雑じゃない？」って思った人えらい👏
これを **取りこぼしゼロ** にする方法（switch網羅性チェック）は次の章（第36章）でやるよ🧷✅

---

## よくある落とし穴🐣⚠️

### ① `string` に戻したくなる病😇

「一旦 `as any` とか `as Status` で通しちゃえ」…は事故のもと🚑💥
**外部入力だけは必ずチェック** しようね🛟

### ② 状態が増えたのに「関連コード」を更新し忘れる😵‍💫

Union型にしておくと、型エラーで気づける範囲が増えるよ✨
さらに強くするのが第36章の「判別可能Union」だよ〜🚦🧠

### ③ `enum` と迷う🤔

* **Union型**：ランタイム出力が増えない（型だけで守る）🧷✨
* **enum**：実行時にも値がある（連携は楽だけど出力が増える）📦

まずはこの教材では **Union型を基本** にすると迷いが減るよ😊

---

## ミニ課題✍️🎀

### 課題A：statusをUnion型にしよう🚦

次を満たすように直してね👇

* `status: string` をやめる
* `"draft" | "published" | "archived"` にする
* `"publised"`（スペルミス）を入れるとコンパイルで怒られるのを確認する💥

```ts
type Article = {
  id: string;
  title: string;
  status: string;
};
```

---

### 課題B：外部入力を安全に通そう🛟

`localStorage` から読んだ `status` を `Article.status` に入れたい！

* `parseStatus()` を作って、ダメなら `"draft"` に寄せよう😊

---

### 課題C：「増えた時に壊れにくい形」にしてみよう🌱✨

status候補を配列で管理して、型を自動生成してみよう🎯
（さっきの `statuses as const` のやつ！）

---

## AI活用ポイント🤖✨（お願い方＋チェック観点✅）

### 1）Union候補の洗い出しを手伝ってもらう📝

お願い例👇

* 「この機能の状態を設計したい。ありそうな状態（status）を5〜8個、粒度がバラけないように提案して。あと“同時に成り立たない組み合わせ”があれば指摘して」

チェック✅

* 状態が「動詞っぽい・名詞っぽい」で混ざってない？（例: `"loading"` と `"loaded"` の混在）😵‍💫
* UI/ログ/保存で必要な状態が抜けてない？👀

### 2）移行作業の差分を小さくする🤏✨

お願い例👇

* 「`status: string` を Union型に置き換える手順を、コンパイルを壊さない順番で“5コミット”に分割して」

チェック✅

* 1コミットで直しすぎてない？👣
* 途中で `as any` を増やしてない？⚠️

### 3）外部入力の取り扱いをレビューしてもらう🛟

お願い例👇

* 「この `parseStatus()` は安全？抜けや危険な `as` があったら指摘して、より堅い案も出して」

チェック✅

* `unknown` → `Status` の変換で、必ずチェックがある？✅
* 例外にするのか、デフォルトに寄せるのか、方針が一貫してる？🧭

---

## まとめ🎁✨

* `status: string` は自由すぎて事故りやすい😇💥
* `type Status = "todo" | "doing" | "done"` で **許可リスト化** すると強い🚦🧷
* 外部入力は **チェックしてから** Union型に入れる🛟✅
* 次の章で「switchの取りこぼしゼロ（網羅性チェック）」まで完成させるよ〜！🌸

[1]: https://www.typescriptlang.org/docs/handbook/2/everyday-types.html?utm_source=chatgpt.com "TypeScript: Documentation - Everyday Types"
[2]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[3]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
[4]: https://www.typescriptlang.org/docs/handbook/literal-types.html?utm_source=chatgpt.com "Handbook - Literal Types"
