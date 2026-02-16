# 第17章：ページング入門①（カーソルって何？）📜🧭

この章でやるのはコレ👇
**「ToDoを10件ずつ取って、`次へ` ボタンで次の10件を表示」**できるようにします✨
Firestoreのページングは「ページ番号」じゃなくて、**“しおり（カーソル）”**で進む感じです📖➡️

---

## 0) まず超ざっくり理解 🧠💡

## 🔖 カーソルってなに？

Firestoreのページングは、**前のページの“最後のドキュメント”を覚えておいて、次はそこから先を取る**スタイルです📌
この「どこから先を取るか」を決めるのが **クエリカーソル**です。([Firebase][1])

## ✅ startAt と startAfter の違い（めっちゃ大事）

* `startAt(...)`：そこ **含む**（inclusive）
* `startAfter(...)`：そこ **含まない**（exclusive）

この差だけ覚えればOKです👍([Google Cloud Documentation][2])

---

## 1) 今日のゴールの完成形 🏁✨

* 1ページ目：`createdAt desc` で新しい順に10件
* `次へ`：前ページの最後のドキュメントをカーソルにして、次の10件
* さらに `次へ`…を繰り返す📚📚📚

Firestoreでは **カーソル + limit()** を組み合わせてページングします。([Firebase][1])

---

## 2) 事前に「データが多い状態」を作る（AIで爆速）🤖💨

ページングは **30件とか50件** ないと気持ちよく練習できません😆
ここはAIを使ってサンプルToDoを量産しちゃいましょう🧪✨

## 方法A：Antigravity / Gemini CLI で「ToDo案」を作る🧠📝

Antigravityは “Mission Control でエージェントに計画→実装→調査” を任せやすい思想です🛰️([Google Codelabs][3])
Gemini CLI はターミナルで使えるので、JSONを作らせるのに便利です💻([Google Cloud Documentation][4])

**プロンプト例（コピペOK）👇**

* 「ToDoタイトルを日本語で50個。短め。重複なし。JSON配列で `[{ "title": "...", "done": false }]` の形で出して」

→ 出てきたJSONを、アプリの「一括追加ボタン」から流し込むのが最短です🚀

## 方法B（オプション）：Firebase AI Logic でアプリ内から生成する🔥

Firebase AI LogicのWeb SDKは `firebase/ai` を使ってモデルを呼べます。([Firebase][5])
（ここは“便利だけど寄り道”なので、章の最後にオプションで載せます🧩）

---

## 3) ハンズオン：10件ずつ取得して「次へ」する 🛠️📜

## 🧩 今回使うFirestoreの考え方

* まず `limit(10)` で **最初の10件**
* その結果の **最後のドキュメント**を `lastDoc` として覚える
* 次ページは `startAfter(lastDoc)` + `limit(10)`

「ドキュメントスナップショットをカーソルとして渡せる」ことがポイントです📌([Google Cloud Documentation][2])

---

## 4) 実装：ページング用hookを作る（おすすめ）⚛️🧰

`src/hooks/useTodosPaging.ts` みたいなファイルを作るとスッキリします✨
（すでに `useTodos()` があるなら、別名でOKです👍）

```ts
// src/hooks/useTodosPaging.ts
import { useCallback, useState } from "react";
import {
  collection,
  getDocs,
  limit,
  orderBy,
  query,
  startAfter,
  QueryDocumentSnapshot,
  DocumentData,
  Timestamp,
} from "firebase/firestore";
import { db } from "../firebase"; // 自分のdbの場所に合わせてね！

export type Todo = {
  id: string;
  title: string;
  done: boolean;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
  tags?: string[];
};

const PAGE_SIZE = 10;

export function useTodosPaging() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [lastDoc, setLastDoc] =
    useState<QueryDocumentSnapshot<DocumentData> | null>(null);

  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadFirstPage = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const todosRef = collection(db, "todos");
      const q = query(todosRef, orderBy("createdAt", "desc"), limit(PAGE_SIZE));

      const snap = await getDocs(q);
      const items: Todo[] = snap.docs.map((d) => ({
        id: d.id,
        ...(d.data() as Omit<Todo, "id">),
      }));

      setTodos(items);

      const newLast = snap.docs.length ? snap.docs[snap.docs.length - 1] : null;
      setLastDoc(newLast);

      // 10件未満なら「次へ」はもう無い
      setHasMore(snap.docs.length === PAGE_SIZE);
    } catch (e: any) {
      setError(e?.message ?? "読み込みでエラーが起きたよ🥲");
    } finally {
      setLoading(false);
    }
  }, []);

  const loadNextPage = useCallback(async () => {
    if (!lastDoc) return;
    if (!hasMore) return;
    if (loading) return;

    setLoading(true);
    setError(null);

    try {
      const todosRef = collection(db, "todos");
      const q = query(
        todosRef,
        orderBy("createdAt", "desc"),
        startAfter(lastDoc),
        limit(PAGE_SIZE)
      );

      const snap = await getDocs(q);
      const items: Todo[] = snap.docs.map((d) => ({
        id: d.id,
        ...(d.data() as Omit<Todo, "id">),
      }));

      setTodos((prev) => [...prev, ...items]);

      const newLast = snap.docs.length ? snap.docs[snap.docs.length - 1] : lastDoc;
      setLastDoc(newLast);

      setHasMore(snap.docs.length === PAGE_SIZE);
    } catch (e: any) {
      setError(e?.message ?? "次ページ取得でエラーが起きたよ🥲");
    } finally {
      setLoading(false);
    }
  }, [hasMore, lastDoc, loading]);

  return {
    todos,
    loading,
    hasMore,
    error,
    loadFirstPage,
    loadNextPage,
  };
}
```

---

## 5) UI：一覧に「次へ」ボタンを付ける 🎛️➡️

```tsx
import { useEffect } from "react";
import { useTodosPaging } from "../hooks/useTodosPaging";

export function TodosPage() {
  const { todos, loading, hasMore, error, loadFirstPage, loadNextPage } =
    useTodosPaging();

  useEffect(() => {
    loadFirstPage();
  }, [loadFirstPage]);

  return (
    <div style={{ padding: 16 }}>
      <h1>ToDo一覧📋</h1>

      {error && <div style={{ marginBottom: 12 }}>⚠️ {error}</div>}

      {todos.length === 0 && !loading && <div>まだ0件だよ〜🙂</div>}

      <ul>
        {todos.map((t) => (
          <li key={t.id}>
            {t.done ? "✅" : "⬜"} {t.title}
          </li>
        ))}
      </ul>

      <div style={{ marginTop: 16 }}>
        <button onClick={loadNextPage} disabled={!hasMore || loading}>
          {loading ? "読み込み中…" : hasMore ? "次へ➡️" : "もう無いよ🛑"}
        </button>
      </div>
    </div>
  );
}
```

---

## 6) よくあるハマりどころ（先に潰す）🧯💥

## ① `startAfter` って何を渡すの？

* **ドキュメント（スナップショット）**を渡せます📌([Firebase][1])
* または「フィールド値」でもいけるけど、**同じ値が多いとズレる**ので注意です⚠️
  公式サンプルでも「同値があると期待通りにならない」注意が出ています。([Google Cloud Documentation][6])

👉 なのでこの章では **`startAfter(lastDoc)`（ドキュメント渡し）**を採用してます✅

## ② `orderBy` を忘れる

ページングは **並び順が命**です📏
`orderBy` なしで「次の10件」は成立しません🙅‍♂️（“次”の定義がない）

## ③ `createdAt` が入ってないドキュメントが混ざる

`orderBy("createdAt")` してるのに、`createdAt` が無いデータが混ざると事故りがちです😵
→ 第11章の `createdAt` 追加を思い出して、全件に入るようにしてね⏱️✨

---

## 7) ミニ課題 🧩🎯

## 🎯 課題：ページングを“わかりやすく”する

次のどれか1つでOK🙆‍♂️（余裕あれば全部でも✨）

1. 「いま表示中：○件」カウンタを出す🔢
2. `次へ` が押せない時に理由を表示する（例：もう無いよ）🛑
3. `更新` ボタンを作って、最初から読み直せるようにする🔄

---

## 8) チェック ✅✅✅

* `startAt` と `startAfter` の違いを言える（含む/含まない）([Google Cloud Documentation][2])
* `limit + カーソル` でページングする理由がわかる([Firebase][1])
* `lastDoc` を保持して、次ページで `startAfter(lastDoc)` を使えてる([Firebase][1])
* 0件・最後のページ・読み込み中が破綻しない🙂

---

## 9) （オプション）Firebase AI LogicでサンプルToDoを生成→一括追加🤖🧾➕

「ページング練習用のデータ作り」がだるい…😇って時の最終兵器です🔥
Firebase AI Logicの例では、Webで `firebase/ai` を使ってモデルを呼ぶ形になっています。([Firebase][5])

※ここは“接続済み”ならサクッと入れられます（未接続なら第20章のAI回でガッツリやるのがおすすめ）🧠✨

```ts
import { getAI, getGenerativeModel, GoogleAIBackend } from "firebase/ai";

// どこかで初期化済みの app を使う想定
const ai = getAI(app, { backend: new GoogleAIBackend() });
const model = getGenerativeModel(ai, { model: "gemini-2.5-flash" });

const prompt = `
日本語のToDoを30件、重複なしで作って。
JSON配列で返して：[{ "title": "...", "done": false }]
`;

const result = await model.generateContent(prompt);
const text = result.response.text();
// text を JSON.parse して addDoc で流し込む（この部分は自作でOK）
```

---

次の第18章では、このページングを **無限スクロール（IntersectionObserver）**に進化させます♾️📱✨

[1]: https://firebase.google.com/docs/firestore/query-data/query-cursors "Paginate data with query cursors  |  Firestore  |  Firebase"
[2]: https://docs.cloud.google.com/firestore/native/docs/query-data/query-cursors "Paginate data with query cursors  |  Firestore in Native mode  |  Google Cloud Documentation"
[3]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[4]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[5]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
[6]: https://docs.cloud.google.com/firestore/docs/samples/firestore-query-cursor-pagination "Use start cursors and limits to paginate Firestore collections  |  Google Cloud Documentation"
