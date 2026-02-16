# 第15章：クエリ基礎② `orderBy` / `limit`（並べて、上だけ取る）📏⬆️

この章では、**「新しい順に並べる」＋「最新10件だけ取る」**を、ReactのToDo一覧に入れていきます😆✨
Firestoreのクエリで一番よく使う組み合わせなので、ここを覚えると一気に“それっぽいアプリ”になります🔥

---

## 0) この章で使う“今の定番”メモ（2026-02-16 時点）🧾✨

* Firebase Web SDK（npm）：`firebase@12.9.0` ([npm][1])
* Node.js：v24 が Active LTS（ローカルツールやスクリプト用の定番枠） ([Node.js][2])

---

## 1) まず概念：`orderBy` と `limit` は「並べて、上だけ取る」🧠📌

* `orderBy("createdAt", "desc")`
  → `createdAt` を **降順（desc）**＝新しい順に並べる⬇️✨
* `limit(10)`
  → 上から **10件だけ** 取る✂️📄

Firestore公式の要点はこの2つ👇 ([Firebase][3])

---

## 2) 重要注意：`orderBy` すると「そのフィールドが無いドキュメント」は消える😱💥

ここ、超大事です⚠️

Firestoreは `orderBy()` に使ったフィールドが **存在するドキュメントだけ** 返します。
つまり `createdAt` が入ってない古いデータがあると、**並べ替えた瞬間に一覧から消えます**😇 ([Firebase][3])

## 対策はこれだけ覚えればOK ✅

* 新規追加のとき：`createdAt` を必ず入れる（サーバー時刻が安心）⏱️
* すでにあるデータ：`createdAt` が無いものを埋める（後で一括でもOK）🧹

> すでに第11章で `createdAt/updatedAt` を入れてる前提だと思うけど、もし「一部だけ抜けてる」ならここで直すと気持ちいいです😆✨

---

## 3) ハンズオン：最新順＋最新10件のクエリを作る 🛠️⚛️

## ゴール 🎯

* ToDo一覧が **新しい順** に並ぶ
* さらに **最新10件だけ表示** できる

---

## 3-1) クエリだけ先に作ってみる（超基本形）🧩

```ts
import { collection, query, orderBy, limit } from "firebase/firestore";
import { db } from "./firebase"; // あなたの初期化ファイルに合わせてね

const todosRef = collection(db, "todos");

const q = query(
  todosRef,
  orderBy("createdAt", "desc"),
  limit(10)
);
```

ポイント👇

* `query()` の中に「条件パーツ」を並べていく感じです🧱✨ ([Firebase][3])

---

## 3-2) `onSnapshot`（リアルタイム）に合体させる ⚡👀

すでに一覧が `onSnapshot` になってる想定で、**購読対象を q に変えるだけ**です👍

```ts
import { useEffect, useState } from "react";
import {
  collection,
  query,
  orderBy,
  limit,
  onSnapshot,
  QueryDocumentSnapshot,
  DocumentData,
} from "firebase/firestore";
import { db } from "./firebase";

type Todo = {
  id: string;
  title: string;
  done: boolean;
  createdAt?: unknown; // Timestamp型は後で慣れたらちゃんと型付けでOK
};

export function useTodosLatest10() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLoading(true);

    const q = query(
      collection(db, "todos"),
      orderBy("createdAt", "desc"),
      limit(10)
    );

    const unsubscribe = onSnapshot(
      q,
      (snap) => {
        const list = snap.docs.map((d: QueryDocumentSnapshot<DocumentData>) => {
          const data = d.data();
          return {
            id: d.id,
            title: String(data.title ?? ""),
            done: Boolean(data.done ?? false),
            createdAt: data.createdAt,
          };
        });

        setTodos(list);
        setError(null);
        setLoading(false);
      },
      (e) => {
        setError(e.message);
        setLoading(false);
      }
    );

    return unsubscribe;
  }, []);

  return { todos, loading, error };
}
```

---

## 3-3) 画面に出す（例）🖥️✨

```tsx
import { useTodosLatest10 } from "./useTodosLatest10";

export function TodoList() {
  const { todos, loading, error } = useTodosLatest10();

  if (loading) return <p>読み込み中...⏳</p>;
  if (error) return <p>エラーだよ🙏：{error}</p>;
  if (todos.length === 0) return <p>まだ0件だよ📝</p>;

  return (
    <ul>
      {todos.map((t) => (
        <li key={t.id}>
          {t.done ? "✅" : "⬜"} {t.title}
        </li>
      ))}
    </ul>
  );
}
```

---

## 4) ミニ課題：最新10件だけ表示（limit）🧩🏁

## やること💪

1. ToDoを **15件以上** 作る（適当にOK🙆‍♂️）
2. 一覧に出るのが **10件だけ** になってるか確認👀
3. 追加した瞬間に、リアルタイムで「先頭に入って」「古いのが押し出される」動きになれば成功🎉⚡

## チェック✅

* 「新しい順」になってる？（直近で追加したものが上）⬆️
* 10件を超えた分は表示されない？✂️
* `createdAt` が無いデータが混じってない？（混じると消える😱） ([Firebase][3])

---

## 5) よくあるつまずき集（先に踏んでおく）💥😇

## ❶ `createdAt` が無いデータが消えた

* 仕様です（こわいよね😂）
* まずは **全部のドキュメントに createdAt を入れる**のが正解✅ ([Firebase][3])

## ❷ 「同じ時刻」で順番が微妙に揺れる

* 同タイミング追加が多いと、同値で“並びが固定されない”感じが出ることがあります🌀
* その場合は **2つ目の `orderBy`**（例：`title`）を足して“同点決勝”を作ると安定しやすいです🧷
  （複数フィールドの並び替えは公式サンプルもあります）([Google Cloud Documentation][4])

## ❸ `where` と組み合わせたら、急に怒られた（インデックス）

* それ第16章の主役です🔥（「インデックスエラーは怖くない」に続く✨）

---

## 6) AIで爆速化コーナー 🤖💨（開発とアプリ機能の両方）

## 6-1) 開発をAIで加速（エージェントに“差分”を作らせる）🧑‍💻➡️🤖

* Antigravity の Mission Control で「`useTodos` に `orderBy(createdAt desc) + limit(10)` を入れて、一覧が動くところまで」みたいに投げると、変更案（差分）をまとめて出させやすいです🛠️📋 ([Google Codelabs][5])
* Gemini CLI も「ターミナル上で、修正・調査・テスト支援まで」やる設計なので、同じ指示が通しやすいです💻🤝 ([Google Cloud Documentation][6])

> コツ：AIに“丸投げ”じゃなく、**「どのファイルをどう変えるか」**を1行で指定すると成功率アップです🎯✨

---

## 6-2) アプリ機能にAIを混ぜる（自然言語→並び替え/件数）🪄🗣️

例えばユーザーが
「新しい順で10件だけ見たい！」
みたいに入力したら、AIに **“安全な設定だけ”** JSONで返してもらい、その設定でクエリを作る…みたいな体験ができます😆

ここで使う“AIの入口”として、Firebase AI Logic が公式に用意されています（Gemini/Imagenへアクセス）🤖✨ ([Firebase][7])

安全にするコツはこれ👇（超大事⚠️）

* AIが返せるのは **固定の候補だけ**（例：`createdAt desc` / `createdAt asc`、`limit` は 1〜50 まで、など）🔒
* AIが「自由なFirestoreクエリ文字列」を返す設計は避ける（事故りやすい）🧯

---

## 7) この章のまとめ（言えると勝ち）🏆✨

* `orderBy` は並べ替え、`limit` は上から何件✂️⬆️ ([Firebase][3])
* `orderBy` に使ったフィールドが無いドキュメントは返ってこない（消える）😱 ([Firebase][3])
* `onSnapshot` と合体すると「最新10件がリアルタイムで更新」になる⚡👀
* AIは「開発の差分作り」も「自然言語UI」もいけるけど、**許可リスト方式**で安全にね🔒🤖 ([Firebase][7])

---

次の第16章は、ここで出がちな **インデックスエラー**を「読める→直せる」に変えていきます🛠️😤🔥

[1]: https://www.npmjs.com/package/firebase?utm_source=chatgpt.com "firebase"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://firebase.google.com/docs/firestore/query-data/order-limit-data?utm_source=chatgpt.com "Order and limit data with Cloud Firestore - Firebase - Google"
[4]: https://docs.cloud.google.com/firestore/docs/samples/firestore-query-order-multi?utm_source=chatgpt.com "Ordering a Firestore query on multiple fields"
[5]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[6]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[7]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
