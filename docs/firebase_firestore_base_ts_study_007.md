# 第07章：Read② 複数読む（getDocs）📚📄✨

この章は「ToDo一覧ページ」が一気に“アプリっぽく”なる回です 😆⚡
Firestoreから **複数ドキュメントをまとめて取得**して、Reactで **一覧表示＋件数表示**まで仕上げます！🧩🔢

---

## 0) この章でできるようになること 🎯

* `todos` コレクションを **まとめて取得**できる（`getDocs`）📥
* 取得結果（`QuerySnapshot`）を **配列に変換**してReactで描画できる 📋
* **読み込み中 / エラー / 0件** をちゃんと出せる 🧯
* 「取得結果は“その瞬間のスナップショット”」の感覚がわかる 📸

Firestoreのデータ取得は「一回だけ取得」か「リアルタイム購読」などがあり、この章は前者です。 ([Firebase][1])

---

## 1) まず読む：getDocsってどんな読み方？🤔📚

## ✅ getDocsは「今この瞬間の一覧を、1回だけ取る」📸

`getDocs()` は、クエリ（またはコレクション）を実行して **結果を `QuerySnapshot` として返す**イメージです。
そしてこれは **“そのときの結果”** なので、あとでDBが変わっても **勝手には変わりません**（次章以降で `onSnapshot` に進むと“勝手に更新”になります⚡）。

## ✅ 取得できるデータは「docsの配列」📦

`QuerySnapshot` の中に `docs` があって、各要素が `QueryDocumentSnapshot`。
そこから `doc.id` と `doc.data()` を使って、Reactで使える形（配列）に変換します 🧠✨

## ✅ 注意：キャッシュが混ざることがある（仕様）🧊

`getDocs()` は可能な限り最新を取りに行きますが、状況によって **キャッシュを返す**ことがあります。
「絶対サーバー」「絶対キャッシュ」を指定したいときは `getDocsFromServer()` / `getDocsFromCache()` を使います。 ([modularfirebase.web.app][2])

---

## 2) 手を動かす：一覧取得 → 配列化 → 画面表示 🛠️⚛️

ここでは、よくある構成で進めます👇

* `src/lib/firebase.ts` に `db`（Firestoreインスタンス）がある
* `todos` コレクションに ToDo が入っている（第5章で追加済み想定）➕

---

## 2-1) ToDoの型を作る 🧱📝

```ts
// src/features/todos/types.ts
export type Todo = {
  id: string;
  title: string;
  done: boolean;
  // 第11章で createdAt/updatedAt を足す予定なら、今は無しでOK！
};
```

---

## 2-2) Firestoreから一覧を読む関数（readTodos）を作る 📥📚

ポイントはここ👇

* `getDocs(collection(...))` でまとめて取得
* `snap.docs.map(...)` で配列化
* `id` は `doc.id` から取る（フィールドじゃなくて “ドキュメントのID”）🪪

```ts
// src/features/todos/api/readTodos.ts
import { collection, getDocs } from "firebase/firestore";
import { db } from "../../../lib/firebase";
import type { Todo } from "../types";

type TodoDoc = Omit<Todo, "id">;

export async function readTodos(): Promise<Todo[]> {
  const snap = await getDocs(collection(db, "todos"));
  return snap.docs.map((d) => {
    const data = d.data() as TodoDoc;
    return {
      id: d.id,
      title: data.title,
      done: data.done,
    };
  });
}
```

Firestoreの「一回取得」はこの形が基本になります。 ([Firebase][1])

---

## 2-3) Reactで一覧ページを作る（読み込み中/エラー/0件も）🧯📋

```tsx
// src/features/todos/pages/TodoListPage.tsx
import { useEffect, useState } from "react";
import { readTodos } from "../api/readTodos";
import type { Todo } from "../types";

export function TodoListPage() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string>("");

  async function load() {
    setLoading(true);
    setError("");
    try {
      const items = await readTodos();
      setTodos(items);
    } catch (e) {
      console.error(e);
      setError("読み込みに失敗しました 😭");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  if (loading) return <p>読み込み中…⏳</p>;
  if (error) return (
    <div>
      <p>{error}</p>
      <button onClick={load}>もう一回 🔁</button>
    </div>
  );

  return (
    <div>
      <h1>ToDo一覧 📚</h1>

      <p>件数：{todos.length}件 🔢</p>

      <button onClick={load}>再読み込み 🔄</button>

      {todos.length === 0 ? (
        <p>まだ0件だよ！まず追加してみよう ➕✨</p>
      ) : (
        <ul>
          {todos.map((t) => (
            <li key={t.id}>
              <span>{t.done ? "✅" : "⬜"}</span>{" "}
              <span>{t.title}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

ここまでできたら、**「一覧が出る」「件数が出る」「0件/エラーも破綻しない」**で勝ちです 🏆✨

---

## 3) ミニ課題 🧩🎯

## ✅ ミニ課題：未完了だけ表示するスイッチを付けよう 🎛️

* `showOnlyUndone`（boolean）をstateで持つ
* 表示するときだけ `todos.filter(t => !t.done)` を使う
* ここでは **Firestoreのクエリにしない**（第14章でやる）🙆‍♂️

---

## 4) チェック（できた？）✅✅

* `getDocs` の結果を `docs.map(...)` で配列にできた？📦
* `doc.id` をちゃんと `id` として使えてる？🪪
* 0件のときに「0件表示」が出る？🫥
* 失敗したときに「失敗メッセージ＋再試行」が出る？🧯
* 「getDocsは“その瞬間の結果”」って言える？📸

---

## 5) よくある詰まりポイント集 💥🧰

## ❌ ① 一覧が0件のまま（でもConsoleにはある）

* コレクション名が違う：`todo` と `todos` とかあるある😇
* 参照してるプロジェクトが違う（Firebaseの設定取り違え）🔀
* ルールで弾かれてる（`permission-denied`）🚫
  → その場合は `catch` の `console.error(e)` を見て、エラー文字列を確認しよう👀

## ❌ ② 取得が“古い気がする”

`getDocs()` は状況によってキャッシュを返すことがあります（仕様）。
「絶対サーバーがいい！」ならこう👇 ([modularfirebase.web.app][2])

```ts
import { collection, getDocsFromServer } from "firebase/firestore";
import { db } from "../lib/firebase";

const snap = await getDocsFromServer(collection(db, "todos"));
```

---

## 6) AIで爆速にするコツ 🤖💨✨（開発がラクになるやつ）

## 6-1) Antigravityで「設計→実装→見直し」を一気に回す 🛰️🛠️

Antigravityはエージェント前提の開発フロー（Mission Controlで複数エージェント管理）を強く推してます。
「readTodos作って」「UI作って」「エラー時の表示まで」みたいな **一連作業が相性良い**です。 ([Google Codelabs][3])

おすすめ指示（コピペ用）👇

* 「Firestoreの `todos` を `getDocs` で取得して `Todo[]` に変換する関数を作って。`id` は `doc.id` を使って。例外処理も入れて」
* 「TodoListPageに loading / error / empty を入れて、件数も出して」

## 6-2) Gemini CLIで「このエラー何？」を即解決 🔍🧯

Gemini CLIはターミナルで動くオープンソースAIエージェントで、修正・調査・テスト支援までやる設計（ReActやMCP対応）です。 ([Google Cloud Documentation][4])
エラーが出たログを貼って「原因と直し方を、初心者向けに！」って投げるだけでだいぶ進みます😄

## 6-3) Firebase AI Logicで「サンプルToDo生成」→Firestoreに流し込み（発展）🧪✨

Firebase AI Logic はアプリから **Gemini/Imagen** を使えるようにする仕組みです。 ([Firebase][5])
Webなら `firebase/ai` から `getAI` / `getGenerativeModel` を使って呼べます。 ([Firebase][6])

例：**ToDoタイトルを10個、JSON配列で作らせる**（→第5章の追加処理に渡す）👇

```ts
import { initializeApp } from "firebase/app";
import { getAI, getGenerativeModel, GoogleAIBackend } from "firebase/ai";

const app = initializeApp({ /* firebaseConfig */ });

const ai = getAI(app, { backend: new GoogleAIBackend() });
const model = getGenerativeModel(ai, { model: "gemini-2.5-flash" });

export async function generateTodoTitles(): Promise<string[]> {
  const prompt =
    "日本語のToDoタイトルを10個、JSON配列（文字列だけ）で出して。例: [\"洗濯する\", ...]";
  const result = await model.generateContent(prompt);
  const text = result.response.text();

  // ここは雑にするより、ちゃんとJSON.parseできる形にAIへ強制するのがコツ👍
  return JSON.parse(text);
}
```

ちなみにAI Logicのドキュメント上、古いモデルのリタイア予定なども明記されているので、モデル名は都度チェックが安全です（例：2026-03-31に一部モデル退役の案内あり）。 ([Firebase][6])

---

次の章（第8章）では、取得したToDoを **更新（updateDoc / setDoc merge）**して「編集できるアプリ」にしていきます ✏️🔁🎉

[1]: https://firebase.google.com/docs/firestore/query-data/get-data?utm_source=chatgpt.com "Get data with Cloud Firestore | Firebase - Google"
[2]: https://modularfirebase.web.app/reference/firestore_/?utm_source=chatgpt.com "firebase/firestore"
[3]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[4]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[5]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[6]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
