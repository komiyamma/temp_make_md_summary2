# 第09章：Update② よく使う“便利更新”（done切替・配列・数値）✅📈

この章は「編集画面を開かずに、サクッと更新する」技をまとめて身につける回です😆✨
ToDoアプリが一気に“それっぽく”なります！

---

## まず今日のゴール 🎯

次の3つを、React画面からワンクリックでできるようにします👇

1. ✅ `done` を ON/OFF 切替（チェックボックス）
2. 🏷️ `tags: string[]` を追加 / 削除（配列更新）
3. 📈 `likeCount` を +1 / -1（数値カウンタ更新）

配列や数値は「サーバー側で原子的（atomic）に処理してくれる更新」が使えるので、実はめちゃ強いです💪🔥 ([Firebase][1])

---

## 9-1）この章で使う“便利更新”の武器たち🧰✨

## ✅ done切替（boolean）

`updateDoc()` で `done: true/false` を更新するだけ！
「一覧のチェックボックスを押した瞬間に更新」みたいなUXが作れます😎 ([Firebase][1])

## 🏷️ 配列の更新（arrayUnion / arrayRemove）

タグみたいに配列を扱うときは、配列を丸ごと上書きするより
`arrayUnion()`（追加）と `arrayRemove()`（削除）が便利です✨ ([Firebase][1])

さらに `arrayUnion()` は「同じ要素がすでにあるなら足さない」性質があるので、重複しにくいのが良いところです🧠 ([Google Cloud][2])

## 📈 数値カウンタ更新（increment）

「いいね +1」「閲覧数 +1」みたいなのは `increment(1)` が最強です🔥
複数人が同時に押しても“足し算として安全に積み上がる”のがうれしいポイント！ ([Firebase][1])

ただし注意：**超高頻度**で同じドキュメントを叩き続けると、カウンタは“混み合い”ます🚧
その場合は「分散カウンタ（distributed counters）」という設計を使います（今は“知識として知っておく”でOK🙆‍♂️） ([Firebase][3])

---

## 9-2）実装①：done をワンクリックで切り替え✅🖱️

## 追加するフィールド（例）

* `done: boolean`
* `updatedAt: serverTimestamp()`（更新した瞬間がわかる⏱️）

## まずは更新関数を作る（おすすめ：`src/lib/todoActions.ts`）

```ts
import { db } from "../lib/firebase"; // 既存の初期化ファイル想定
import {
  doc,
  updateDoc,
  serverTimestamp,
} from "firebase/firestore";

export async function toggleTodoDone(todoId: string, currentDone: boolean) {
  const ref = doc(db, "todos", todoId);
  await updateDoc(ref, {
    done: !currentDone,
    updatedAt: serverTimestamp(),
  });
}
```

`updateDoc()` は「指定したフィールドだけ更新」できるので安心です👍 ([Firebase][1])

## React側（チェックボックスで即更新）

```tsx
type Todo = {
  id: string;
  title: string;
  done: boolean;
  tags?: string[];
  likeCount?: number;
};

export function TodoItem({ todo, onToggle }: { todo: Todo; onToggle: (id: string, done: boolean) => void }) {
  return (
    <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
      <input
        type="checkbox"
        checked={todo.done}
        onChange={() => onToggle(todo.id, todo.done)}
      />
      <span style={{ textDecoration: todo.done ? "line-through" : "none" }}>
        {todo.title}
      </span>
    </label>
  );
}
```

---

## 9-3）実装②：タグ配列を追加・削除する🏷️🧩

タグは「ToDoを探しやすくする」ので、後の検索（where）にも効いてきます🔎✨

## タグ追加（arrayUnion）

```ts
import { db } from "../lib/firebase";
import { doc, updateDoc, arrayUnion, serverTimestamp } from "firebase/firestore";

export async function addTag(todoId: string, rawTag: string) {
  const tag = rawTag.trim();

  // 超ミニ入力チェック（気持ちでOK😊）
  if (!tag) return;
  if (tag.length > 20) throw new Error("タグは20文字までにしよう！");

  const ref = doc(db, "todos", todoId);
  await updateDoc(ref, {
    tags: arrayUnion(tag),
    updatedAt: serverTimestamp(),
  });
}
```

`arrayUnion()` はサーバー側で配列に“足し込み”してくれます✨ ([Firebase][1])

## タグ削除（arrayRemove）

```ts
import { db } from "../lib/firebase";
import { doc, updateDoc, arrayRemove, serverTimestamp } from "firebase/firestore";

export async function removeTag(todoId: string, tag: string) {
  const ref = doc(db, "todos", todoId);
  await updateDoc(ref, {
    tags: arrayRemove(tag),
    updatedAt: serverTimestamp(),
  });
}
```

配列の原子的更新（arrayUnion/arrayRemove）は公式の代表パターンです💡 ([Firebase][1])

---

## 9-4）実装③：数値カウンタを +1 / -1 する📈👍

「いいね」ボタンを作ってみます！

```ts
import { db } from "../lib/firebase";
import { doc, updateDoc, increment, serverTimestamp } from "firebase/firestore";

export async function addLike(todoId: string) {
  const ref = doc(db, "todos", todoId);
  await updateDoc(ref, {
    likeCount: increment(1),
    updatedAt: serverTimestamp(),
  });
}

export async function removeLike(todoId: string) {
  const ref = doc(db, "todos", todoId);
  await updateDoc(ref, {
    likeCount: increment(-1),
    updatedAt: serverTimestamp(),
  });
}
```

`increment()` は「同時に押されても足し算として安全に合流」しやすい更新です💪 ([Firebase][1])

---

## 9-5）AIで“タグ提案”をやってみよう🤖🏷️（Firebase AI Logic）

ここから一気に楽しくなります😆✨
「タイトルからタグ候補を作る」→「ボタン1つで tags に追加」みたいな流れを作れます。

Firebase AI Logic のWeb向けSDKでは、`firebase/ai` から `getGenerativeModel()` を使う形が案内されています。([Firebase][4])

## 例：タイトルからタグ候補をJSONで返してもらう

* 返答は **必ずJSONだけ** にしてもらう（パース楽！）
* 受け取ったタグは **短く・安全な文字だけ** に整える（AIはたまに暴れる😇）

```ts
import { getAI, getGenerativeModel } from "firebase/ai";
import { app } from "../lib/firebaseApp"; // initializeApp の戻り（例）

export async function suggestTagsByAI(title: string): Promise<string[]> {
  const ai = getAI(app);
  const model = getGenerativeModel(ai, { model: "gemini-2.5-flash" });

  const prompt = `
あなたはタグ付けアシスタントです。
次のToDoタイトルから、短い日本語タグを3〜5個提案してください。
出力は JSON の配列だけにしてください（例：["掃除","買い物"]）。
タイトル: ${JSON.stringify(title)}
`.trim();

  const result = await model.generateContent(prompt);
  const text = result.response.text().trim();

  // 超雑だけどまずはこれでOK（慣れたら堅くする😊）
  const tags = JSON.parse(text) as string[];

  // 最低限の掃除（AIの出力はそのまま信じない！）
  return tags
    .map(t => String(t).trim())
    .filter(t => t.length > 0 && t.length <= 20)
    .slice(0, 5);
}
```

ここで返ってきた `tags` を `arrayUnion(...tags)` で一括追加すると、体験がめちゃ良くなります🏷️✨
（複数追加もサンプルで紹介されています） ([Google Cloud Documentation][5])

---

## 9-6）Antigravity / Gemini CLI で“実装スピード”を上げる🚀🧠

## Antigravity（Mission Control）でやると何が良い？🛰️

「実装」「デバッグ」「調査」をエージェントに分担させる思想が紹介されています。([Google Codelabs][6])
この章だと、例えば👇

* エージェントA：UI（チェックボックス/タグUI）
* エージェントB：Firestore更新関数（toggle / tags / increment）
* エージェントC：AIタグ提案（JSON固定、例外処理）

みたいに分けると、ほんとに早いです⚡

## Gemini CLI + Firebase拡張（/firebase:init）でAI機能の導入が楽に🧰

Firebase側は **Gemini CLI拡張**を用意していて、`/firebase:init` で AI Logic セットアップを手伝う流れが案内されています。([Firebase][7])
さらに「AI用プロンプトカタログ」では、Gemini CLI や Antigravity などで使う“お手本プロンプト”も整理されています🧾✨ ([Firebase][8])

---

## 9-7）ミニ課題🧩🎯（15〜30分）

1. ✅ done切替を「一覧のチェックボックス」で実装
2. 🏷️ タグ入力欄 + 追加ボタン（Enterでも追加できたら最高🥳）
3. 🏷️ タグをクリックすると削除（`arrayRemove`）
4. 📈 いいね +1 ボタン（`increment(1)`）
5. 🤖 「AIでタグ提案」ボタンを追加して、提案されたタグを一括で付与

---

## 9-8）チェック✅（言えたら勝ち！）

* `updateDoc()` は「必要なフィールドだけ更新」できる✏️ ([Firebase][1])
* 配列は `arrayUnion / arrayRemove` を使うと“安全に足し引き”できる🏷️ ([Firebase][1])
* 数値は `increment()` が“足し算として強い”📈 ([Firebase][1])
* AIの出力はそのまま保存せず、短さ・形式などをチェックする🤖🧯（JSON固定が楽） ([Firebase][4])

---

次の第10章（Delete）に入ると、「削除確認ダイアログ」「取り消し（Undo）っぽいUX」みたいな“事故防止”が楽しくなります🗑️💥
第9章のコード貼ってくれたら、UIの気持ちいい動き（楽しいやつ😆）まで一緒に整えます！

[1]: https://firebase.google.com/docs/firestore/manage-data/add-data "Add data to Cloud Firestore  |  Firebase"
[2]: https://googleapis.dev/nodejs/firestore/4.15.0/FieldValue.html?utm_source=chatgpt.com "FieldValue - Documentation"
[3]: https://firebase.google.com/docs/firestore/solutions/counters?hl=ja&utm_source=chatgpt.com "分散カウンタ | Firestore - Firebase"
[4]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
[5]: https://docs.cloud.google.com/firestore/docs/samples/firestore-data-set-array-operations?utm_source=chatgpt.com "Update a Firestore document containing an array field"
[6]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[7]: https://firebase.google.com/docs/ai-assistance/gcli-extension?utm_source=chatgpt.com "Firebase extension for the Gemini CLI"
[8]: https://firebase.google.com/docs/ai-assistance/prompt-catalog?utm_source=chatgpt.com "AI prompt catalog for Firebase | Develop with AI assistance"
