# 第21章：データ進化②：移行（migration）と併存の設計🪜⏳

## ねらい🎯✨

この章が終わると、こんなことができるようになるよ😊🌸

* 古いデータ（v1）と新しいデータ（v2）を **同時に扱える** ように設計できる🔁🧠
* 変更で壊れやすいポイントを避けて、**安全に移行（migration）** できる🛡️🚶‍♀️
* **変換・デフォルト補完・段階移行** を、TypeScriptでちゃんと実装できる✍️🧩

---

## まず「移行」と「併存」って何？🧾🤝

* **移行（migration）**：昔の形のデータを、新しい形に **変えていく** こと🔄
* **併存**：移行期間中に、v1とv2が **混ざって存在しても壊れない** ようにすること🧁🍰

現実はね、いきなり全部をv2にできないことが多いの😅

* 端末に残った古いlocalStorage💾
* すでに保存済みのDBのレコード🗄️
* 古いクライアントから飛んでくるAPIリクエスト📡

だから「併存できる設計」が超大事になるよ〜！✨

---

## ありがちな事故😱💥（これ、ほんとに起きる）

たとえば、v1ではこうだったとするね👇

```json
{ "id": "t1", "title": "レポート", "done": false }
```

v2で「doneは分かりづらいから status にしよ〜」って変えた👇

```json
{ "id": "t1", "title": "レポート", "status": "todo" }
```

このとき **v1のデータが残ってる** と…

* `status` がない → 画面が落ちる😇
* 「全部done扱い」みたいなバグが出る😇😇
* 直したはずが、ユーザーの端末でだけ再現する😇😇😇

こういうのを防ぐのがこの章💪💖

---

## まず覚える「3つの基本作戦」🧠🛠️✨

### 作戦①：変換する（アップキャスト）🔄⬆️

古い形（v1）を受け取ったら、**新しい形（v2相当）に変換**してから使う。

### 作戦②：デフォルト補完する🧁✨

v2で増えた項目が無いなら、**安全なデフォルト値**を入れて成立させる。

### 作戦③：併存させる（読むのは広く、書くのは新しく）📖🖊️

* 読み込み：v1もv2も受け入れる（**tolerant reader**）
* 書き込み：基本v2だけを書く（**strict writer**）

この考え方が最強に効くよ💯✨

---

## いちばん大事：境界で「正規化」する🚪✨

おすすめの型はこれ👇

* 外から来るデータ（API/DB/ストレージ）を **境界** で受け取る🚪
* そこで **v1/v2どっちでもOK** にして
* 内部は **常に1つの形（Canonical）** で扱う🧠✨

つまり内部はこういう気持ち👇
「中に入ってきたら、もう“新しい形”として扱える状態にしてね🧁」

---

## 実装例：Todoのv1/v2を併存させる🧁🧩

ここでは **実行時バリデーション** つきで「正規化」までやるよ✅
（TypeScriptの型だけだと、実データの保証はできないからね😇）

### 1) v1/v2の形を決める🧾

* v1：`done: boolean`
* v2：`status: "todo" | "done"`（これが今後の内部標準✨）

### 2) Zodで入力をチェックして正規化する✅

Zodは「TypeScript-first validation library」って位置づけのライブラリだよ。([JSR][1])
Zod 4系は安定版としてリリースノートが出てるよ。([Zod][2])

```ts
import { z } from "zod";

// v1
const TodoV1 = z.object({
  id: z.string(),
  title: z.string(),
  done: z.boolean(),
});

// v2（これが“内部の標準形”にもなる）
const TodoV2 = z.object({
  id: z.string(),
  title: z.string(),
  status: z.enum(["todo", "done"]),
  // v2で増えた想定（任意）
  dueDate: z.string().datetime().optional(),
});

type Todo = z.infer<typeof TodoV2>; // 内部はv2で統一✨

// v1 -> v2 変換（アップキャスト）
function upcastTodo(v1: z.infer<typeof TodoV1>): Todo {
  return {
    id: v1.id,
    title: v1.title,
    status: v1.done ? "done" : "todo",
    // v2追加項目はデフォルト補完
    dueDate: undefined,
  };
}

// 正規化：unknown を受けて Todo(v2形) を返す
export function normalizeTodo(input: unknown): Todo {
  const v2 = TodoV2.safeParse(input);
  if (v2.success) return v2.data;

  const v1 = TodoV1.safeParse(input);
  if (v1.success) return upcastTodo(v1.data);

  // どっちでもなければ「壊れてるデータ」
  throw new Error("Todoデータの形式が不正です");
}

// 書き込みは常にv2で出す（strict writer）
export function serializeTodo(todo: Todo): string {
  return JSON.stringify(TodoV2.parse(todo));
}
```

### 3) localStorage読み込み時に使う💾✨

```ts
import { normalizeTodo, serializeTodo } from "./todo-schema";

export function loadTodos(): ReturnType<typeof normalizeTodo>[] {
  const raw = localStorage.getItem("todos");
  if (!raw) return [];

  const parsed = JSON.parse(raw) as unknown[];
  return parsed.map(normalizeTodo); // ここで全部v2形に正規化🎀
}

export function saveTodos(todos: ReturnType<typeof normalizeTodo>[]) {
  const raw = JSON.stringify(todos.map(t => JSON.parse(serializeTodo(t))));
  localStorage.setItem("todos", raw);
}
```

ここまでやると、v1が混ざってても中ではv2として扱えるよ〜！🥳🎉

---

## もう一段強くする：バージョン印（schemaVersion）を付ける🏷️✨

「形で判別できるからOK」でもいいんだけど、
将来の変更が増えると判定が難しくなることがあるの🥲

そこでおすすめがこれ👇

```json
{ "schemaVersion": 2, "id": "t1", "title": "レポート", "status": "todo" }
```

* 判別が安定する✅
* “どの変換を適用すべきか” が分かりやすい✅
* 変換関数をチェーンにしやすい✅

---

## JSON Schema派のやり方：2020-12 と Ajv🧾⚙️

JSON Schemaの現行仕様は **2020-12** が「current version」として案内されてるよ。([JSON Schema][3])
Ajvは draft 2020-12 をサポートしていて、ただし **2020-12 と旧draftは同じインスタンスで混ぜられない** って注意があるよ。([Ajv][4])

「組織でJSON Schemaを標準にしてる」みたいな場合はこのルートが便利😊✨
（この章の主役は“移行と併存の考え方”だから、実装は好みでOKだよ🫶）

---

## 移行戦略：どれを選ぶ？🧭🔁

### A) 読むとき移行（Read-time migration）📖✨

読み込み時に `normalize()` で毎回アップキャストする方式。

* ✅ すぐ始められる
* ✅ 全件一括の移行作業がいらない
* ⚠️ ずっとv1が残り続ける（将来掃除が必要）

### B) 書き換えて移行（Write-time migration / Backfill）🗄️🧹

保存済みデータをv2に書き換える（バッチ、管理画面、起動時処理など）。

* ✅ いつか“v2だけ”にできる
* ✅ 以後のコードがスッキリ
* ⚠️ 大量データだと事故りやすい（途中失敗・再開設計が必要）

### C) 併用（Dual-write / Shadow-read）👯‍♀️✨

移行期間中だけ

* 書き込み：v1とv2の両方を出す（または互換フィールドを両方埋める）
* 読み込み：v2優先、なければv1
  みたいにして安全に進めるやつ💪

---

## 段階移行：4ステップの鉄板テンプレ🗓️✅✨

ミニ演習でも使う「超よくある勝ちパターン」だよ🎀

1. **読む側を強くする**

   * v1/v2どっちでも読める（normalize導入）📖🧠
2. **新しい形で書き始める**

   * strict writer（基本v2のみ）🖊️✨
3. **既存データを順次バックフィル**

   * 失敗しても再実行できる設計で🧹🔁
4. **v1サポートを終わらせる**

   * 期限・利用率・ログを見て削除✂️🗑️

---

## よくある落とし穴😵‍💫🧯

* 「型を変えただけ」で安心しちゃう（実データはunknownだよ😇）
* 任意項目の追加なのに、UI側で `!` して落ちる💥
* 変換関数が増えて、どれが最新かわからなくなる🌀
* バックフィルが途中で止まったのに、そのままリリースしちゃう😱

---

## ミニ演習🎒✨

### 演習1：v1/v2併存の正規化関数を作ろう🧁

1. 自分のアプリのデータを1つ選ぶ（例：User設定、メモ、履歴…）📝
2. v1とv2を定義する🧾
3. `normalize()`（v1/v2→内部標準）を作る🔄
4. 「v1でもv2でも動く」テストケースを3つ作る✅🧪

### 演習2：4ステップ移行計画を作ろう🗓️

* Step1〜4を、自分のデータで具体化する
* 「いつv1を消す？」を必ず書く✍️⏳

### 演習3：利用者向けの移行説明（短文）を書く📣🧡

* 何が変わる？
* いつまでv1が使える？
* どう直せばいい？
  この3点だけでOK😊✨

---

## AI活用（コピペで使える指示文）🤖🪄

* 「このv1 JSONをv2に移す変換関数をTypeScriptで作って。境界で正規化する前提で！」🧠
* 「v1/v2を併存させたい。壊れやすいポイントとチェックリスト作って」✅
* 「バックフィル処理が途中で落ちても再開できる設計案を出して」🔁🧯
* 「移行手順を“利用者向け”にやさしく短く書き直して」🌸🧡

---

## 仕上げチェックリスト✅✨

* [ ] **読む側**は v1/v2 どちらでも正規化できる？📖
* [ ] **書く側**は新形式（v2）だけに寄せられてる？🖊️
* [ ] v2追加項目の **デフォルト補完** は決まってる？🧁
* [ ] 変換失敗時の扱い（エラー/破棄/復旧）は決まってる？🧯
* [ ] v1終了の条件（期限 or 利用率）は決めた？⏳
* [ ] 変換関数は「どこで呼ぶか」が一箇所にまとまってる？🚪✨

[1]: https://jsr.io/%40zod/zod?utm_source=chatgpt.com "Zod - JSR"
[2]: https://zod.dev/v4?utm_source=chatgpt.com "Release notes"
[3]: https://json-schema.org/specification?utm_source=chatgpt.com "JSON Schema - Specification [#section]"
[4]: https://ajv.js.org/json-schema.html?utm_source=chatgpt.com "draft 2020-12"
