# 第05章：Create① 追加する（addDoc / setDoc の気持ち）➕📄

この章は「フォームからToDoを追加できる！」を最速で体験する回です 😆✨
Firestoreの **“追加” は2系統**あります：

* **addDoc**：IDはFirestoreにお任せ（自動ID）🪄
* **setDoc**：IDを自分で決める（固定ID）🧷

まずは結論👇

* 迷ったら **addDoc**（ToDoみたいな「どんどん増えるデータ」に強い）
* 「このIDじゃないと困る」があるなら **setDoc**

（参考：Firestoreの“追加”公式ガイド） ([Firebase][1])

---

## 0) 今日の前提バージョン（動作の安心材料）🧾

* Firebase Web SDK（`firebase`）：**12.9.0** ([npm][2])
* TypeScript：**5.9.3** ([npm][3])
* Node.js：**v24 が Active LTS** ([Node.js][4])

---

## 1) addDoc と setDoc の違いを“感覚”でつかむ 🧠✨

## ✅ addDoc（自動ID）

イメージ：**「伝票番号は店が付けるから、とにかく登録して！」** 🧾➡️🗃️
ToDoの追加は基本これでOKです。

* 👍 追加がラク
* 👍 ID衝突を気にしなくていい
* 👍 返り値で `id` を受け取れる

（公式の “Add data” の流れに沿ってます） ([Firebase][1])

## ✅ setDoc（固定ID）

イメージ：**「会員番号が決まってるから、その番号で保存して！」** 👤🧷
例：`users/{uid}` とか、`settings/{appId}` とか。

* 👍 “同じIDに上書き/更新” を作りやすい
* ⚠️ 同じIDに `setDoc` すると **上書き**になりやすい（注意！）

---

## 2) 今回作るToDoデータの形（最小セット）🧩

まずは型で迷子防止！🧭✨

```ts
// src/types/todo.ts
export type TodoCreateInput = {
  title: string;
  done: boolean;
  createdAt: number; // いったん number（後の章で timestamp に進化させるよ⏱️）
};

export type TodoDoc = TodoCreateInput & {
  id: string; // FirestoreのドキュメントID
};
```

---

## 3) “追加”の処理を1か所にまとめる（おすすめ）🧱✨

UI（React）からFirestore直叩きでも動くけど、あとで増えるので
**`todosRepo.ts` に集約**すると後悔しにくいです 👍

## 3-1) addDoc版（基本これ）🪄

```ts
// src/lib/todosRepo.ts
import { db } from "./firebase"; // 第4章で作った想定
import { collection, addDoc } from "firebase/firestore";
import type { TodoCreateInput } from "../types/todo";

export async function addTodo(input: TodoCreateInput) {
  const colRef = collection(db, "todos");
  const docRef = await addDoc(colRef, input);
  return docRef.id; // ← これが自動ID！
}
```

`addDoc` は「コレクションに追加して、IDを返す」王道パターンです。 ([Firebase][1])

---

## 4) React：フォームから追加する ✍️➡️🗃️

## 4-1) 最小の追加フォーム（バリデーション込み）🧩

ポイントはこれ👇

* `title` は **trimして空ならNG**
* 追加中はボタンを無効化（連打防止）🧱
* 成功したら入力欄を空にする 🎉

```tsx
// src/components/TodoAddForm.tsx
import { useState } from "react";
import { addTodo } from "../lib/todosRepo";

export function TodoAddForm() {
  const [title, setTitle] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastId, setLastId] = useState<string | null>(null);

  const canSubmit = title.trim().length > 0 && !saving;

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLastId(null);

    const t = title.trim();
    if (!t) {
      setError("タイトルは必須だよ！✋");
      return;
    }
    if (t.length > 80) {
      setError("タイトル長すぎ！80文字以内にしてね🙏");
      return;
    }

    try {
      setSaving(true);

      const id = await addTodo({
        title: t,
        done: false,
        createdAt: Date.now(),
      });

      setLastId(id);
      setTitle("");
    } catch (err: any) {
      // ありがち：permission-denied / network error など
      setError(err?.message ?? "追加に失敗したよ…🥲");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={onSubmit} style={{ display: "grid", gap: 8, maxWidth: 520 }}>
      <div style={{ display: "flex", gap: 8 }}>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="例：牛乳買う🥛"
          style={{ flex: 1, padding: 10 }}
        />
        <button type="submit" disabled={!canSubmit} style={{ padding: "10px 14px" }}>
          {saving ? "追加中…" : "追加➕"}
        </button>
      </div>

      {error && <div style={{ color: "crimson" }}>⚠️ {error}</div>}
      {lastId && (
        <div style={{ color: "green" }}>
          🎉 追加できた！ID：<code>{lastId}</code>
        </div>
      )}
    </form>
  );
}
```

---

## 5) setDoc を使うパターン（固定IDが必要なとき）🧷

## 5-1) 例：自分でIDを作って保存する（UUIDなど）🆔

「URLに入れたい」「他システムのIDに合わせたい」みたいな時に使います。

```ts
// src/lib/todosRepo.ts（追加例）
import { db } from "./firebase";
import { doc, setDoc } from "firebase/firestore";
import type { TodoCreateInput } from "../types/todo";

export async function setTodoWithId(todoId: string, input: TodoCreateInput) {
  const docRef = doc(db, "todos", todoId);
  await setDoc(docRef, input); // ← 同じIDなら上書きになるよ⚠️
}
```

`doc(db, "todos", id)` → `setDoc(...)` は固定IDの基本形です。 ([Firebase][1])

---

## 6) “自動IDが欲しいけど、先にIDを知りたい”問題の解決 🧠🪄

たとえば「画像を `todos/{id}/...` に保存したい」みたいな時、
**先にIDだけ生成**して、あとから `setDoc` で保存する手があります。

```ts
import { collection, doc, setDoc } from "firebase/firestore";
import { db } from "./firebase";

export async function addTodoButKnowIdFirst(data: any) {
  const newRef = doc(collection(db, "todos")); // ここで自動IDが決まる！
  await setDoc(newRef, data);
  return newRef.id;
}
```

このパターンは公式の “generated id を作って後で setDoc” と同じ考え方です。 ([Firebase][1])

---

## 7) つまずきポイント集（ここが“初学者あるある”）🧯😤

## ❌ 追加できない：`permission-denied`

* だいたい **Rules**（まだゆるい設定でも、期限切れ/設定ミスで起きる）🔐
* もしくは **プロジェクト違い**（別Firebaseプロジェクトの `firebaseConfig` を刺してる）🧩

## ❌ 追加できない：ネットワーク系

* 一旦リロード🔄
* `try/catch` の `err.message` を画面に出す（今章のフォームはそれやってる）👀

---

## 8) 🤖AIで“入力”を楽にする（Firebase AI Logic ちょい足し）✨

ここ、かなり美味しいです 😋
**「ToDoタイトルをAIが提案」→ 気に入ったらそのまま addDoc** みたいにすると、アプリが一気に“現代”っぽくなります⚡

Firebase AI Logic（Web）は `firebase/ai` から使えて、`getAI` → `getGenerativeModel` → `generateContent()` でテキスト生成できます。 ([Firebase][5])
また、AI Logic はプロキシ経由で、APIキーをアプリに埋めない形を作れる説明もあります（本番で安心）🛡️ ([Firebase][6])

## 8-1) AI初期化（例：ai.ts）🧠

```ts
// src/lib/ai.ts
import { firebaseApp } from "./firebase"; // initializeApp済みを export してる想定
import { getAI, getGenerativeModel, GoogleAIBackend } from "firebase/ai";

const ai = getAI(firebaseApp, { backend: new GoogleAIBackend() });

// 軽くて速いモデル例（ドキュメント例に登場）
export const model = getGenerativeModel(ai, { model: "gemini-2.5-flash" });
```

`getAI` / `getGenerativeModel` / `GoogleAIBackend` の構成は公式 Getting Started のWeb例そのままです。 ([Firebase][5])

## 8-2) 「タイトル提案」ボタン（フォームに付ける）🪄

```tsx
// src/components/SuggestTitleButton.tsx
import { useState } from "react";
import { model } from "../lib/ai";

export function SuggestTitleButton(props: { current: string; onPick: (t: string) => void }) {
  const [loading, setLoading] = useState(false);

  async function suggest() {
    setLoading(true);
    try {
      const prompt =
        `次のメモをToDoタイトルにして。短く、8〜20文字くらい。絵文字は1つまで。\n` +
        `メモ: ${props.current || "(空)"}`;

      const result = await model.generateContent(prompt);
      const text = result.response.text().trim();
      if (text) props.onPick(text);
    } finally {
      setLoading(false);
    }
  }

  return (
    <button type="button" onClick={suggest} disabled={loading} style={{ padding: "8px 12px" }}>
      {loading ? "AI考え中…" : "AIでタイトル提案🤖✨"}
    </button>
  );
}
```

`generateContent()` の呼び方（Web）も公式例に沿っています。 ([Firebase][5])

> ✅ 使い方：`TodoAddForm` にこのボタンを置いて、`onPick` で `setTitle(...)` してあげれば完成です 🎉

---

## 9) Antigravity / Gemini CLI で“第5章”を爆速にするコツ ⚡🛠️

* **Antigravity** は “Mission Control でエージェントが計画→実装→調査” みたいな流れを扱える設計です 🧑‍✈️🛰️ ([Google Codelabs][7])
* **Gemini CLI** はターミナル上のAIエージェントで、ReActループやMCP連携で修正・機能追加・テスト改善などを回せます 🧰 ([Google Cloud Documentation][8])

たとえばお願いの仕方（例）👇

* 「`TodoAddForm` に二重送信防止とエラーメッセージ表示を入れて」
* 「`addTodo()` をテストしやすい形に分離して」
* 「`title` のバリデーションを共通関数にして」

この章は“UI・型・例外処理”が一気に混ざるので、AIにレビューさせると安定します👌🤖

---

## 🧩 ミニ課題（5〜15分）🎯

1. タイトルが空なら追加できない（もうできてるはず）✅
2. **80文字制限**を入れる ✅
3. 追加成功したら「追加できた！」を表示する 🎉（`lastId` を出すだけでもOK）

---

## ✅ チェック（言えたら勝ち）🏁✨

* `addDoc` は **自動IDで増やす系**に向く 🪄
* `setDoc` は **固定IDが必要**なときに使う 🧷
* 「先にIDが欲しい」は `doc(collection(...))` → `setDoc` でいける 🧠🪄 ([Firebase][1])
* フォームは **trim / 連打防止 / try-catch** が最低ライン 🧱

---

次の第6章は「1件読む（getDoc）」で、**追加したToDoを詳細画面で表示**していきます 🔎📄✨

[1]: https://firebase.google.com/docs/firestore/manage-data/add-data "Add data to Cloud Firestore  |  Firebase"
[2]: https://www.npmjs.com/package/firebase?utm_source=chatgpt.com "firebase"
[3]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[4]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[5]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
[6]: https://firebase.google.com/docs/ai-logic "Gemini API using Firebase AI Logic  |  Firebase AI Logic"
[7]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[8]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
