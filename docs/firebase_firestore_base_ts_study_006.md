# 第06章：Read① 1件読む（getDoc）🔎📄

この章は「一覧 → 1件の詳細」に進んだときに、**指定IDのToDoを1件だけ読む**流れを作ります😊✨
ポイントは **`getDoc()` → `exists()` で分岐**です！公式ドキュメントでもこの形が基本になってます。([Firebase][1])

---

## この章で作るもの 🎯

* ルート：`/todos/:todoId`
* 画面：ToDoの詳細ページ（タイトル・doneなどを表示）
* 状態：`読み込み中` → `表示` / `見つからない` / `エラー`

---

## 1) まず読む：`getDoc()` の考え方（超ざっくり）🧠✨

Firestoreで「1件読む」はこの4ステップです👇

1. **doc参照を作る**（どのコレクションの、どのID？）
2. **`getDoc()` で取得**
3. **`snapshot.exists()` で存在チェック**
4. **`snapshot.data()` で中身を取り出す**

公式のサンプルも、`getDoc()` と `exists()` をセットで使う形です。([Firebase][1])

---

## 2) 手を動かす：詳細ページを実装しよう ⚛️🔧

> ここからは「第4章まででFirestore接続済み」「第5章で追加済み」の状態から、差分で進めます💪✨

---

## 2-1. 型を用意する（迷子防止）🧾🧭

`Todo` の“画面で使う形”を決めます。
FirestoreのドキュメントIDはフィールドに入ってないので、**`id` は別で持つ**のが定番です😉

```ts
// src/types/todo.ts
export type Todo = {
  id: string;
  title: string;
  done: boolean;
  createdAt?: unknown; // Timestampは後の章で丁寧にやるので今はunknownでOK👌
  updatedAt?: unknown;
};
```

---

## 2-2. 「1件読む関数」を作る（UIと分離）🧩✨

UIコンポーネントの中にFirestore処理をベタ書きすると、あとで辛くなります😵‍💫
なので `getTodoById()` を作っておきます！

```ts
// src/features/todos/api/getTodoById.ts
import { doc, getDoc } from "firebase/firestore";
import { db } from "@/lib/firebase"; // 第4章で作った想定（パスはあなたの構成でOK）
import type { Todo } from "@/types/todo";

export async function getTodoById(todoId: string): Promise<Todo | null> {
  const ref = doc(db, "todos", todoId);
  const snap = await getDoc(ref);

  // ✅ 存在チェック（ここが第6章の主役！）
  if (!snap.exists()) return null;

  const data = snap.data() as { title?: unknown; done?: unknown };

  // ざっくり安全策（後の章で型/検証を強化する）
  const title = typeof data.title === "string" ? data.title : "(no title)";
  const done = typeof data.done === "boolean" ? data.done : false;

  return {
    id: snap.id,
    title,
    done,
    // createdAt/updatedAtは後で扱うので今は省略でもOK
  };
}
```

`getDoc()` は「その瞬間のスナップショットを1回取る」動きで、リアルタイム更新は次のユニットでやります⚡([Firebase][1])

---

## 2-3. 詳細ページを作る（URLの `todoId` を使う）🔎📄

```tsx
// src/pages/TodoDetailPage.tsx
import { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import type { Todo } from "@/types/todo";
import { getTodoById } from "@/features/todos/api/getTodoById";

type LoadState =
  | { type: "loading" }
  | { type: "not-found" }
  | { type: "error"; message: string }
  | { type: "loaded"; todo: Todo };

export function TodoDetailPage() {
  const { todoId } = useParams();
  const [state, setState] = useState<LoadState>({ type: "loading" });

  useEffect(() => {
    let cancelled = false;

    async function run() {
      if (!todoId) {
        setState({ type: "not-found" });
        return;
      }

      setState({ type: "loading" });

      try {
        const todo = await getTodoById(todoId);

        if (cancelled) return;

        if (!todo) {
          setState({ type: "not-found" });
          return;
        }

        setState({ type: "loaded", todo });
      } catch (e) {
        if (cancelled) return;
        const message = e instanceof Error ? e.message : "Unknown error";
        setState({ type: "error", message });
      }
    }

    run();
    return () => {
      cancelled = true;
    };
  }, [todoId]);

  if (state.type === "loading") {
    return <p>読み込み中…⏳</p>;
  }

  if (state.type === "not-found") {
    return (
      <div>
        <h1>見つからない…🙅‍♂️</h1>
        <p>IDが間違ってるか、まだ作ってないかも！</p>
        <Link to="/">一覧へ戻る⬅️</Link>
      </div>
    );
  }

  if (state.type === "error") {
    return (
      <div>
        <h1>エラーだ〜😭</h1>
        <p>{state.message}</p>
        <Link to="/">一覧へ戻る⬅️</Link>
      </div>
    );
  }

  const { todo } = state;

  return (
    <div>
      <h1>ToDo 詳細 📄✨</h1>

      <p>
        <b>ID:</b> {todo.id}
      </p>
      <p>
        <b>タイトル:</b> {todo.title}
      </p>
      <p>
        <b>完了:</b> {todo.done ? "✅ 完了" : "⬜ 未完了"}
      </p>

      <Link to="/">一覧へ戻る⬅️</Link>
    </div>
  );
}
```

---

## 2-4. ルーティングに追加する 🧭

`/todos/:todoId` に入ったら詳細ページが出るようにします。

```tsx
// 例: src/App.tsx
import { Routes, Route } from "react-router-dom";
import { TodoDetailPage } from "@/pages/TodoDetailPage";
import { TodoListPage } from "@/pages/TodoListPage";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<TodoListPage />} />
      <Route path="/todos/:todoId" element={<TodoDetailPage />} />
    </Routes>
  );
}
```

---

## 3) 「存在しない」と「取れない」を区別しよう 🧯🧠

ここ、初心者が混乱しがちポイントです😵‍💫

* **存在しない** 👉 `getDoc()` は成功するけど `snap.exists()` が `false`
* **取れない**（権限NG・通信NGなど）👉 `getDoc()` 自体が **例外を投げる**ことがある

なので **`exists()` 分岐 + try/catch** をセットで持っておくと強いです💪
（公式も `exists()` で分岐するのが基本形）([Firebase][1])

---

## 4) ちょい発展：キャッシュ/サーバーを明示したいとき 🧊🌐

「オフラインっぽい挙動が気になる…」ってなったら、**キャッシュから取る/サーバーから取る**を明示できます。

* `getDocFromCache(ref)`：キャッシュに無いとエラーになりがち
* `getDocFromServer(ref)`：サーバー問い合わせを強制

※ この章では使わなくてOK！「そういう手もある」だけ覚えれば十分です😊

---

## 5) ミニ課題 🧩🎯

## ミニ課題A（必須）✅

* 一覧で表示している各ToDoに「詳細へ」リンクを付ける

  * 例：`/todos/${todo.id}` に飛ぶ

## ミニ課題B（ちょい楽しい）😆

* 「IDをコピー」ボタンを作る（`navigator.clipboard.writeText(todo.id)`）📋✨
* `見つからない` 画面に「新規作成へ」リンクを追加➕📄

---

## 6) チェック（できたら勝ち！）🏁✨

* `getDoc()` で1件取得できる🔎
* `exists()` で **見つからない** を出し分けできる🙅‍♂️
* `読み込み中 / エラー / 空状態 / 表示` をUIで分けられる🎛️
* URLの `todoId` を使って詳細画面に行ける🧭

---

## 7) AIで加速コーナー 🤖💨（超おすすめ）

## 7-1. Google の Gemini CLIで「エラー翻訳＆原因当て」🛠️

Gemini CLIはターミナルから使えるAIエージェントで、npmで入れられます。([Gemini CLI][2])
チートシート的に `gemini "質問"` や `gemini -p "質問"` が使えます。([Gemini CLI][3])

インストール例👇

```bash
npm install -g @google/gemini-cli
```

困ったときの投げ方（例）👇

```text
以下の状況で、原因候補を3つに絞って優先度順に教えて。
- /todos/xxx に行くと「見つからない」になる
- Firestoreには1件入ってるはず
- コレクション名は todos のつもり
あと、確認用にコンソールログをどこへ入れるべきかも教えて。
```

---

## 7-2. Antigravityで「原因調査→修正案→差分作成」🧠🧰

Antigravityは“Mission Control”で、エージェントに計画〜実装をまとめてやらせる思想が紹介されています。([The Verge][4])
おすすめの依頼テンプレ👇

```text
React + Firestoreで /todos/:todoId の詳細ページを作った。
- getDoc は動くが exists が false になることがある
- ありがちな原因（ID/パス/ルール/環境変数）をチェックリスト化して
- そのチェックをコード上で検出できるガード（ログ/例外/画面表示）を提案して
```

---

## 7-3. Firebase AI Logicで「タイトルを整える」ボタン（オプション）✨✍️

Firebase AI LogicはWeb SDKの中に入っていて、`firebase/ai` でモデル呼び出しができます。([Firebase][5])
この章では「保存まではしない」で、**提案だけ表示**にすると軽くて楽です😄

※ まずは“動く最小形”の例👇（既存の `firebaseApp` を使う想定）

```ts
import { getAI, getGenerativeModel, GoogleAIBackend } from "firebase/ai";

const ai = getAI(firebaseApp, { backend: new GoogleAIBackend() });
const model = getGenerativeModel(ai, { model: "gemini-2.5-flash" });

export async function polishTitle(title: string) {
  const prompt = `次のToDoタイトルを、短くて分かりやすい日本語に整えて。返答はタイトル1行だけ。\n\n${title}`;
  const result = await model.generateContent(prompt);
  return result.response.text();
}
```

この `polishTitle()` を詳細ページのボタンから呼んで、画面に「AI提案：〇〇✨」って出せたら勝ちです🤖🎉

---

次の第7章では、いよいよ「複数読む（getDocs）」で一覧を“ちゃんとDBから”組み立てていきます📚📄✨

[1]: https://firebase.google.com/docs/firestore/query-data/get-data?hl=ja "Cloud Firestore でデータを取得する  |  Firebase"
[2]: https://geminicli.com/docs/get-started/installation/?utm_source=chatgpt.com "Gemini CLI installation, execution, and releases"
[3]: https://geminicli.com/docs/cli/cli-reference/?utm_source=chatgpt.com "CLI cheatsheet"
[4]: https://www.theverge.com/news/822833/google-antigravity-ide-coding-agent-gemini-3-pro "Google Antigravity is an ‘agent-first’ coding tool built for Gemini 3 | The Verge"
[5]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
