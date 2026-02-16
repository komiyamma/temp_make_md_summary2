# 第14章：クエリ基礎① where（絞り込み）🔎🎯

この章では、Firestoreの **「サーバー側で絞り込む」** 技を身につけます😊✨
ToDoでいえば「未完了だけ」「完了だけ」を一瞬で出せるようになります👍

---

## 1) where って何？（まず感覚）🧠💡

Firestoreの `where()` は、**DBの中にある大量データから、必要なものだけを持ってくる**ための条件指定です🚚💨
つまり、アプリ側で全部読み込んで `filter()` するより、基本は `where()` が正解になりやすいです🙆‍♂️

Firestoreの `where()` には、等しい（`==`）だけじゃなくて、範囲（`>=` など）や配列（`array-contains`）みたいな条件もあります。公式の演算子一覧がここにまとまっています。([Firebase][1])

---

## 2) where早見（よく使うやつだけ）🧾✨

**まずはこの5つが使えたら勝ち**です✌️😆

* `where("done", "==", false)` → 未完了だけ ✅
* `where("createdAt", ">=", someDate)` → ある日以降 📅
* `where("tags", "array-contains", "urgent")` → タグに “urgent” を含む 🏷️
* `where("category", "in", ["work", "home"])` → カテゴリがこのどれか（OR的）🎯
* `where("category", "not-in", ["spam", "trash"])` → これら以外（ただし注意あり）🧨

※ `in` は最大30個までまとめられます（Standard edition の説明に明記）([Firebase][1])
※ `not-in` は最大10個、さらに「フィールドが存在しない」ドキュメントは対象外、などクセがあります([Firebase][1])

---

## 3) 手を動かす：未完了 / 完了 を切り替える🎛️⚡

やることはシンプルです😊
**①フィルタ状態を持つ → ②その状態でクエリを作る → ③onSnapshotで購読** です⚡

---

## 3-1) フィルタ状態を作る（React）🧩⚛️

```tsx
type TodoFilter = "all" | "open" | "done";

const [filter, setFilter] = useState<TodoFilter>("all");

return (
  <div style={{ display: "flex", gap: 8 }}>
    <button onClick={() => setFilter("all")}>全部</button>
    <button onClick={() => setFilter("open")}>未完了</button>
    <button onClick={() => setFilter("done")}>完了</button>
  </div>
);
```

---

## 3-2) filterからクエリを作る（whereの本体）🔎✨

```ts
import { collection, query, where } from "firebase/firestore";
import { db } from "./firebase"; // 既に作ってある想定

export type TodoFilter = "all" | "open" | "done";

export function buildTodosQuery(filter: TodoFilter) {
  const ref = collection(db, "todos");

  if (filter === "open") return query(ref, where("done", "==", false));
  if (filter === "done") return query(ref, where("done", "==", true));
  return query(ref); // 全部
}
```

`where("done","==",false)` みたいな **等価条件（==）** は、とにかく一番よく使います😄
（whereの基本例は公式でもこの形で紹介されています）([Firebase][1])

---

## 3-3) リアルタイム購読に組み込む（onSnapshot）⚡👀

```ts
import { onSnapshot } from "firebase/firestore";
import { useEffect, useState } from "react";
import { buildTodosQuery, TodoFilter } from "./buildTodosQuery";

type Todo = {
  id: string;
  title: string;
  done: boolean;
  tags?: string[];
};

export function useTodos(filter: TodoFilter) {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [error, setError] = useState<unknown>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);

    const q = buildTodosQuery(filter);
    const unsub = onSnapshot(
      q,
      (snap) => {
        setTodos(snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Todo, "id">) })));
        setLoading(false);
      },
      (e) => {
        setError(e);
        setLoading(false);
      }
    );

    return () => unsub();
  }, [filter]);

  return { todos, loading, error };
}
```

これで、ボタンを押すたびに **「購読する対象のクエリ」** が切り替わって、表示もスパッと変わります⚡😆

---

## 4) ミニ応用：タグで絞り込む（AIと相性最高）🏷️🤖

例えば ToDo の `tags: string[]` に
`["urgent", "work"]` みたいなのを入れておけば…

* `array-contains` → **そのタグを含むToDoだけ**
* `array-contains-any` → **この中のどれかを含むToDoだけ**

ができます✨（公式に例あり）([Firebase][1])

```ts
import { collection, query, where } from "firebase/firestore";

const ref = collection(db, "todos");

// 1つのタグで絞る
const q1 = query(ref, where("tags", "array-contains", "urgent"));

// 複数候補のどれか（ORっぽい）
const q2 = query(ref, where("tags", "array-contains-any", ["urgent", "work"]));
```

> ちなみに、「配列に **含まない**」みたいな `array-not-contains` は演算子一覧に存在しないので、直接は書けません🙅‍♂️
> そういう時は設計で回避（例：`isArchived: true/false` を持つ）を選びます🧠

---

## 5) whereが増えると何が起きがち？（事故ポイント集）💥🧯

## 5-1) `!=` / `not-in` の「存在しないフィールド問題」👻

Standard edition では、`!=` は **そのフィールドが存在するドキュメントだけ** が対象になります。([Firebase][1])
`not-in` も **フィールドが存在しないドキュメントは除外** されます。([Firebase][1])

✅ 対策：**「ある/ない」を検索したいフィールドは、ちゃんと保存する**（例：`hasTags: true`）📌

---

## 5-2) `not-in` はクセ強め🧨

* `not-in` は最大10個まで([Firebase][1])
* `not-in` と `!=` は一緒に使えません([Firebase][1])

---

## 5-3) OR系は「30分岐まで」上限がある🧱

`or` / `in` / `array-contains-any` は内部的に OR 扱いになって、**最大30分岐（disjunctions）** の制限があります。([Firebase][1])
（普通のToDoならまず踏まないけど、条件を盛りすぎると到達しがち😵）

---

## 5-4) “ORクエリ” も一応できる（上級の入口）🚪

Node.js の例ですが、Firestoreは `Filter.or(...)` みたいに **論理OR** も用意してます。([Firebase][1])
ただ、ここで沼りやすいので「必要になったら使う」でOKです🙂

---

## 6) FirebaseのAIサービスも絡める（whereが気持ちよくなる）🤖✨

ここが超おいしいところです😆🍣

## 6-1) AIでタグを作る → `where(tags...)` で検索する🏷️🔎

ユーザーが入れたタイトルから、AIにタグを作ってもらって保存すると便利です✨

FirestoreのToDo追加時に、Firebase AI Logicで `tags` を生成するイメージ👇
WebのSDKは `firebase/ai` から `getAI` / `getGenerativeModel` を使います。([Firebase][2])

```ts
import { initializeApp } from "firebase/app";
import { getAI, getGenerativeModel, GoogleAIBackend } from "firebase/ai";

const app = initializeApp({ /* ... */ });

// Gemini Developer API backend
const ai = getAI(app, { backend: new GoogleAIBackend() });

// 例: 速くて軽いモデル
const model = getGenerativeModel(ai, { model: "gemini-2.5-flash" });

export async function suggestTags(title: string): Promise<string[]> {
  const prompt =
    `次のToDoタイトルからタグを3つまで作って、JSON配列だけで返して。\n` +
    `タイトル: ${title}\n` +
    `例: ["urgent","work"]`;

  const result = await model.generateContent(prompt);
  const text = result.response.text();

  // 超ざっくり例：本当はJSONとして安全にパースする工夫を入れると安心🧯
  return JSON.parse(text);
}
```

そして保存したら、さっきの `array-contains` / `array-contains-any` で一瞬検索です⚡😆

> 公式のGetting Startedでも、**本番前に Remote Config でモデル名を差し替えできるようにする**のが強く推奨されています（運用で助かるやつ）([Firebase][2])

---

## 6-2) ついでに：Chromeデスクトップで “オンデバイス推論→クラウドにフォールバック” みたいな構成もある🧠🖥️

Firebase AI Logicには、Web（Chrome Desktop）での **ハイブリッド推論** も案内があります（Preview）。([Firebase][3])
ToDo程度なら必須じゃないけど、「通信減らしたい」系で刺さります👀✨

---

## 7) Antigravity / Gemini CLI でこの章を爆速にする⚡🧑‍💻🤖

* Antigravityは “Mission Control” 的な流れで、計画→実装をエージェントに寄せやすい構成になってます。([Google Codelabs][4])
* Gemini CLIはターミナル上でコード調査・修正・テスト支援までやる想定のツールとして案内されています。([Google for Developers][5])

## すぐ使える指示文（コピペOK）🧾✨

```text
目的：
Firestoreのtodosをリアルタイム購読しつつ、filter=all/open/doneでwhere条件を切り替えたい。

やってほしいこと：
1) buildTodosQuery(filter) を作って where("done","==",true/false) を切り替える
2) useTodos(filter) を onSnapshot + unsubscribe で実装
3) UIに「全部/未完了/完了」ボタンを追加して切り替え可能にする
4) つまずきやすい点（依存配列、unsubscribe漏れ、型）を指摘しながら進めて
```

---

## 8) ミニ課題（必ず手を動かす）🧩🔥

## 🎯 ミニ課題：「未完了/完了」切替を“気持ちよく”する

* ✅ ボタンの見た目を「選択中がわかる」ようにする✨
* ✅ フィルタ中もリアルタイム更新が効くのを確認する⚡
* ✅ おまけ：`tags` を1個付けて `array-contains` で絞れるようにする🏷️

---

## 9) チェック（ここまでできたら合格）✅🎉

* ✅ `where("done","==",false)` で未完了だけ取れる
* ✅ フィルタを切り替えると、購読対象も切り替わる（unsubscribe漏れなし）
* ✅ `in` / `not-in` / `array-contains-any` の「上限・クセ」があるのを知ってる([Firebase][1])
* ✅ AIで `tags` を作っておくと、where検索が超ラクになるのが想像できる([Firebase][2])

---

次の第15章は `orderBy / limit` で「並べて上だけ取る」ので、**フィルタ + 並び替え** が合体して一気に“アプリっぽさ”出ますよ〜😆📈

[1]: https://firebase.google.com/docs/firestore/query-data/queries "Perform simple and compound queries in Cloud Firestore  |  Firebase"
[2]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
[3]: https://firebase.google.com/docs/ai-logic/hybrid-on-device-inference?utm_source=chatgpt.com "Build hybrid experiences with on-device and cloud-hosted ..."
[4]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[5]: https://developers.google.com/gemini-code-assist/docs/gemini-cli "Gemini CLI  |  Gemini Code Assist  |  Google for Developers"
