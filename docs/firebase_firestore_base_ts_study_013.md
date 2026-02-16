# 第13章：リアルタイム購読②（Reactで安全に扱う）⚛️🧯

この章はひとことで言うと、**「onSnapshotを“安全に”Reactへ組み込む」**回です✨
リアルタイム購読って気持ちいいんだけど、やり方をミスると **二重購読** や **メモリリーク** になりがち…😇 なので、ここで「型・hooks・後片付け」まで“型崩れなく”固めます💪

---

## 1) 読む：なぜ“安全”が必要？🧨→🧯

## ✅ Firestoreのリアルタイム購読は「解除しないと残る」

Firestoreは `onSnapshot()` で変更を監視できます。**最初に即スナップショットが届いて**、その後も変更のたびに届きます⚡👀 ([Firebase][1])
そして大事なのが、`onSnapshot()` が **購読解除用の関数（unsubscribe）を返す**こと。これを呼ぶと監視が止まります🧯 ([modularfirebase.web.app][2])

## ✅ Reactは「画面が消える」「条件が変わる」たびに後片付けが必要

Reactの `useEffect()` は、**依存が変わる前や、コンポーネントが消えるときに cleanup（後片付け）を呼べる**仕組みです🧹 ([react.dev][3])
しかも開発中（Strict Mode）だと、バグ発見のために **setup→cleanup→setup を1回余分に回す**ことがあります😳
つまり cleanup が弱いと、**二重購読が起きやすい**です（逆に、cleanupが正しければ安全）🛡️ ([react.dev][3])

---

## 2) 手を動かす：`useTodos()` を作って購読を“hooks化”しよう 🛠️✨

ここからのゴールはこれ👇

* `TodosPage.tsx` みたいな画面からは **`useTodos()` を呼ぶだけ**にする😆
* `onSnapshot()` の **解除漏れをゼロ**にする🧯
* **loading / error / empty** を“見た目として”ちゃんと出す✨

---

## 2-1. まず型を作る（ToDoの形を固定）🧱

```ts
// src/types/todo.ts
import type { Timestamp } from "firebase/firestore";

export type Todo = {
  id: string;
  title: string;
  done: boolean;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
  tags?: string[];
};
```

> `Timestamp` は Firestoreの時刻型です⏱️（第11章の流れでOK👍）

---

## 2-2. `useTodos()`（購読＋解除＋状態管理）を作る⚡🧯

ポイントは3つだけ👇

1. `onSnapshot()` の戻り値（unsubscribe）を **必ず return cleanup** で呼ぶ
2. 画面側は `status` を見て表示を分岐
3. クエリ（`query(...)`）は `useMemo` で安定させる（余計な再購読を減らす）🎯

```ts
// src/hooks/useTodos.ts
import { useEffect, useMemo, useState } from "react";
import {
  collection,
  onSnapshot,
  orderBy,
  query,
  where,
  type FirestoreError,
} from "firebase/firestore";
import { db } from "../lib/firebase"; // 既存のFirestore初期化を利用
import type { Todo } from "../types/todo";

type TodosState =
  | { status: "loading"; todos: Todo[]; error: null }
  | { status: "error"; todos: Todo[]; error: FirestoreError }
  | { status: "ready"; todos: Todo[]; error: null };

export function useTodos(options?: { onlyUndone?: boolean }) {
  const onlyUndone = options?.onlyUndone ?? false;

  const [state, setState] = useState<TodosState>({
    status: "loading",
    todos: [],
    error: null,
  });

  // ✅ クエリはuseMemoで“同じもの”を保つ（不要な再購読を減らす）
  const q = useMemo(() => {
    const base = collection(db, "todos");
    return onlyUndone
      ? query(base, where("done", "==", false), orderBy("createdAt", "desc"))
      : query(base, orderBy("createdAt", "desc"));
  }, [onlyUndone]);

  useEffect(() => {
    setState({ status: "loading", todos: [], error: null });

    // ✅ onSnapshotは「解除関数」を返す
    const unsub = onSnapshot(
      q,
      (snap) => {
        const todos: Todo[] = snap.docs.map((d) => {
          const data = d.data() as Omit<Todo, "id">;
          return { id: d.id, ...data };
        });
        setState({ status: "ready", todos, error: null });
      },
      (err) => {
        setState({ status: "error", todos: [], error: err });
      }
    );

    // ✅ これが命！！！！ 画面が消える/条件が変わる→購読解除🧯
    return () => unsub();
  }, [q]);

  const isEmpty = state.status === "ready" && state.todos.length === 0;

  return { ...state, isEmpty };
}
```

`onSnapshot()` の基本挙動（最初に即通知→変更で通知、解除関数あり）はこちらの公式説明が土台です📚 ([Firebase][1])
`useEffect()` の cleanup と Strict Mode の追加サイクルはここが根拠です🧠 ([react.dev][3])

---

## 3) 手を動かす：画面で “loading / error / empty” を綺麗に出す✨🎛️

```tsx
// src/pages/TodosPage.tsx
import { useState } from "react";
import { useTodos } from "../hooks/useTodos";

export function TodosPage() {
  const [onlyUndone, setOnlyUndone] = useState(false);
  const { status, todos, error, isEmpty } = useTodos({ onlyUndone });

  return (
    <div style={{ padding: 16 }}>
      <h1>ToDo 🗃️</h1>

      <button onClick={() => setOnlyUndone((v) => !v)}>
        {onlyUndone ? "全部表示に戻す" : "未完了だけ表示"}
      </button>

      {status === "loading" && <p>読み込み中…⏳</p>}
      {status === "error" && <p>エラー😭：{error.message}</p>}
      {isEmpty && <p>まだ1件もないよ📝（追加してみて！）</p>}

      <p>件数：{todos.length} 件 🔢</p>

      <ul>
        {todos.map((t) => (
          <li key={t.id}>
            <input type="checkbox" checked={t.done} readOnly /> {t.title}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

これで、別タブから追加すると **勝手に増える**（第12章の快感）を保ちつつ、React的にも安全になります⚡🧯

---

## 4) よくある事故パターン集（ここ踏む人多い）💥😇

## 💥 事故1：cleanupを書かずに購読が残る

* 画面遷移しても購読が生きてて、更新のたびに state 更新が飛ぶ…
* 最終的に「なんか重い」「二重に増える」になる🫠
  → **`return () => unsub()` が正解**🧯 ([react.dev][3])

## 💥 事故2：Strict Modeで「二重購読してるように見える」

開発中は **わざと** setup→cleanup→setup を1回余分に回します🧪
cleanupが正しければ「問題なし」👍（本番は通常どおり） ([react.dev][3])

## 💥 事故3：依存配列が毎回変わって再購読ループ

`query(...)` を毎レンダーで作ると、Effectが「別物だ！」って判断して再購読しがち😵
→ `useMemo()` で安定させるのが楽です🎯

---

## 5) ミニ課題 🧩🎯

次の3つ、やってみて！✨

1. **フィルタ切替**を入れる

   * 「未完了だけ」⇄「全部」の切替
   * 切り替えた瞬間に一覧が自然に変わる🎛️

2. **状態表示を強化**

   * loading：スケルトン風でもOK😆
   * error：`error.message` を表示
   * empty：かわいいメッセージ📝

3. **安全確認**

   * 画面を行ったり来たりしても、増殖しない
   * 追加したら1回だけ反映される（2回増えない）✅

---

## 6) チェック（合格ライン）✅✨

* [ ] `onSnapshot()` の戻り値（unsubscribe）を **cleanupで呼んでいる** 🧯 ([modularfirebase.web.app][2])
* [ ] Strict Modeでも「二重購読っぽい挙動」を **cleanupで潰せている** 🧪🛡️ ([react.dev][3])
* [ ] `useTodos()` の戻り値だけで画面が書ける（UIがスッキリ）✨
* [ ] loading / error / empty が出せてる ⏳😭📝

---

## 7) AIでさらに加速（オプション）🤖🚀

## 7-1) Gemini CLI / Antigravityで“unsubscribe漏れレビュー”してもらう🕵️‍♂️✨

Gemini CLI はターミナルで使えるAI支援、Antigravityはエージェント駆動の開発環境（Mission Control）って位置づけです🧠⚙️ ([Google Cloud Documentation][4])

たとえばこんなお願いが強いです👇

* 「この `useEffect`、Strict Modeでも二重購読しない？どこが危ない？」
* 「依存配列、最小でOK？ `useMemo` の置きどころは？」
* 「状態設計（loading/error/empty）もっと読みやすくできる？」

“人間が見落としやすいポイント”を先に潰せるのがうまいです🧯✨

---

## 7-2) Firebase AI Logicで「AIがToDo案を出す」→リアルタイム反映を体験🪄🗃️

Firebase AI Logic は **WebアプリからGemini/Imagenを安全寄りに呼べる**仕組みです🤖🔐 ([Firebase][5])
Webの初期化はこんな感じ（公式の形）👇 ([Firebase][6])

```ts
import { initializeApp } from "firebase/app";
import { getAI, getGenerativeModel, GoogleAIBackend } from "firebase/ai";

const app = initializeApp({ /* ... */ });
const ai = getAI(app, { backend: new GoogleAIBackend() });
const model = getGenerativeModel(ai, { model: "gemini-2.5-flash" });

export async function generateTodoTitle(): Promise<string> {
  const prompt = "日本語で短いToDoタイトルを1つだけ提案して。15文字以内。";
  const result = await model.generateContent(prompt);
  return result.response.text().trim();
}
```

> ちょい注意⚠️：モデル名は運用で変わることがあるので、古いモデルを固定してる場合は退役情報も確認してね（例：一部モデルは 2026-03-31 に退役予定の案内あり）📅 ([Firebase][5])

あとは `generateTodoTitle()` の結果を `addDoc()` で `todos` に入れるだけ！
するとこの章で作った `useTodos()` が **リアルタイムで勝手に増やしてくれます**⚡😆（「購読の快感」と「安全設計」が同時に味わえる🍰）

---

次の第14章（whereフィルタ）に行く前に、**この第13章のhooks化ができてると、以降ぜんぶ楽**になります💪🔥

[1]: https://firebase.google.com/docs/firestore/query-data/listen "Get realtime updates with Cloud Firestore  |  Firebase"
[2]: https://modularfirebase.web.app/reference/firestore_.onsnapshot?utm_source=chatgpt.com "Firebase Modular JavaScript SDK Documentation"
[3]: https://react.dev/reference/react/useEffect "useEffect – React"
[4]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[5]: https://firebase.google.com/docs/ai-logic "Gemini API using Firebase AI Logic  |  Firebase AI Logic"
[6]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
