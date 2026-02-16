# 第12章：リアルタイム購読①（onSnapshotで“勝手に更新”）⚡👀

この章は、**「一覧を見てるだけで勝手に更新される」**を体に入れる回です😆✨
やることはシンプルで、前の章までの `getDocs()` を **`onSnapshot()` に置き換えるだけ**！💪

---

## この章でできるようになること 🎯

* ✅ Firestoreの「リアルタイム購読（Listener）」の感覚がわかる
* ✅ Reactで安全に `onSnapshot()` を貼れる（＝解除できる）
* ✅ 別タブで追加した瞬間、一覧が増える “魔法” を体験できる🪄
* ✅ 「解除しないと何が起きるか」を説明できる

---

## 1) リアルタイム購読って何？🤔⚡

Firestoreのリアルタイムは、ざっくり言うとこう👇

* **「データ変わったら、向こうから通知が飛んでくる」**📨
* だから **ポーリング（何秒ごとに取りに行くやつ）不要**🙅‍♂️
* しかも自分の書き込みは **“即” 画面に反映**される（ラグ補正）⚡

  * ローカルの更新が先に届いて、あとでサーバー確定が来る…みたいな動きになるよ🧠
  * それを見分けるための `metadata.hasPendingWrites` も用意されてる👍 ([Firebase][1])

---

## 2) まずは「置き換え前」を確認しよう 👀🧩

第7章あたりの一覧がこんな感じだったはず👇（例）

* `getDocs(query(...))` で **一回だけ取得**
* 画面はその結果で固定（更新されない）

ここを **`onSnapshot()` に差し替えて**、以降は **勝手に更新される**ようにします⚡

---

## 3) 手を動かす：一覧を `onSnapshot()` に切り替える 🛠️⚛️

## 3-1. 型（ToDo）を用意 🧱

「id付きの表示用データ」を作るのがポイントです😊

```ts
export type Todo = {
  id: string;
  title: string;
  done: boolean;
  createdAt?: unknown; // Timestamp型は後でちゃんと揃える（今は雰囲気でOK）
  updatedAt?: unknown;
  tags?: string[];
};
```

---

## 3-2. `onSnapshot()` で購読して state に入れる 🔁📥

例：`TodoList.tsx`（一覧コンポーネント）に直書き版です👇
（後の章で hooks 化してキレイにします✨）

```tsx
import { useEffect, useState } from "react";
import { collection, onSnapshot, orderBy, query } from "firebase/firestore";
import { db } from "../lib/firebase"; // 既に作ってある想定
import type { Todo } from "../types/Todo";

export function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // 🔎 一覧は「新しい順」に並べる（createdAt desc）
    const q = query(collection(db, "todos"), orderBy("createdAt", "desc"));

    // ⚡ 購読スタート
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const next = snapshot.docs.map((d) => {
          const data = d.data() as Omit<Todo, "id">;
          return { id: d.id, ...data };
        });

        setTodos(next);
        setLoading(false);
        setError(null);
      },
      (err) => {
        // 権限エラーや無効クエリなどで落ちることがある
        setError(err.message);
        setLoading(false);
      }
    );

    // 🧯 超重要：コンポーネントが消える時に解除！
    return () => unsubscribe();
  }, []);

  if (loading) return <div>読み込み中…⏳</div>;
  if (error) return <div>エラーだよ😇：{error}</div>;
  if (todos.length === 0) return <div>まだ0件だよ📝</div>;

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

* `onSnapshot()` は **変更があるたびに** コールバックを呼びます📣 ([Firebase][1])
* さらに **エラー用コールバック**も付けられます（付けるのおすすめ）🧯 ([Firebase][1])
* `unsubscribe()` を呼ぶと **購読が止まる**（解除できる）🛑 ([Firebase][1])

---

## 4) ミニ課題：別タブで「増える」体験しよう 🪄🧪

## やること（3分）⏱️

1. ブラウザで **同じアプリを2タブ**開く🧑‍💻🧑‍💻
2. 片方のタブで ToDo を追加 ➕
3. もう片方のタブの一覧が **自動で増える**のを確認🎉

**見えたら勝ち！**😆⚡

---

## 5) ここが落とし穴：解除しないと何が起きる？💥🧠

`onSnapshot()` は **貼ったら貼りっぱなし**になりがちです。

## ありがち事故 😇

* 画面遷移するたびに購読が増えて、**同じ更新が複数回来る**
* メモリも通信も無駄に増える
* そして「なんか重い…」になる🐢

だから React では、

* `useEffect(() => { ...; return () => unsubscribe(); }, [])`

これが基本形です✨
（第13章で「hooks化＆安全運用」をやるよ！）

---

## 6) “即反映”の正体：ローカル変更イベント 🏎️💨

Firestoreは、書き込みしたら **サーバーに届く前でも** リスナーをすぐ動かします⚡
これが **ラグ補正（latency compensation）** です。 ([Firebase][1])

イベントが「ローカル由来」か「サーバー確定」かを見分けたいなら👇

* `doc.metadata.hasPendingWrites` を使う

  * `true` → まだローカルの仮状態
  * `false` → サーバー確定✨ ([Firebase][1])

---

## 7) 上級者っぽい小ワザ：メタデータ変化も取りたい時 🕵️‍♂️✨

デフォルトだと「データそのものが変わった時」だけ通知されます。
でも「pendingWrites が true→false になった」みたいな **メタデータの変化**も取りたいなら👇

```ts
onSnapshot(
  doc(db, "cities", "SF"),
  { includeMetadataChanges: true },
  (doc) => {
    // ...
  }
);
```

こうするとメタデータ変化でもイベントが来ます📣 ([Firebase][1])

---

## 8) 料金とパフォーマンスの超ざっくり注意 🧾⚠️

リアルタイムは便利だけど、**“読み取りが増えやすい”**のは意識しよう👀
Firestoreは基本的に **返ってきたドキュメント分が読み取り**として計上されます（リスナーも例外じゃない）

なのでコツは👇

* 🔎 必要な範囲に絞る（where / limit）
* 📏 一覧は `limit()` をつける（次の章以降のページングにもつながる）
* 🧹 画面にいない時はちゃんと解除（無駄な購読をしない）

---

## 9) AIで“デバッグ”を早くする（おまけ）🤖🔧✨

## 9-1) Firebase AI Logicで「変更内容ログ」を日本語で要約させる 📝🤖

「今、何が起きてるの？」をAIに説明させると、初心者の理解が爆速になります🚀

Firebase AI LogicのWeb例（初期化→モデル作成）はこんな形です👇 ([Firebase][2])

```ts
import { getAI, getGenerativeModel, GoogleAIBackend } from "firebase/ai";
import { initializeApp } from "firebase/app";

const firebaseApp = initializeApp({ /* ... */ });
const ai = getAI(firebaseApp, { backend: new GoogleAIBackend() });
const model = getGenerativeModel(ai, { model: "gemini-2.5-flash" });
```

モデルは状況で変わるので、**古いモデルの廃止予定**があるのも覚えておくと安心です🧯（例：特定モデルのretire案内）([Firebase][2])

そして `onSnapshot` の中で `docChanges()` から「追加/更新/削除」を拾って、
それをAIに食わせて “今起きたこと” を文章で返してもらう…みたいな流れが作れます😊

---

## 9-2) Gemini CLI / Antigravityで「原因特定」を早くする 🧠⚡

* 「購読が増えてる気がする」「useEffectの依存配列これでいい？」みたいな悩みを
  **ログ貼ってAIに突っ込んでもらう**のが強いです💪
* エージェント系ツールは便利な反面、**怪しい指示（プロンプト注入）に注意**って話もあるので、知らないリポジトリやスクリプトは慎重にね🧯

---

## ✅ チェック（できたら次へ！）🎓✨

* ✅ `getDocs()` を `onSnapshot()` に置き換えた
* ✅ 別タブで追加したら、一覧が自動で増えた🪄
* ✅ `useEffect` の cleanup で解除している（超大事）
* ✅ 「解除しないと購読が増える」を言葉で説明できる

---

次の第13章は、これを **Reactで安全に運用する型（hooks化・ローディング/エラー/空状態）**に仕上げます⚛️🧯✨

[1]: https://firebase.google.com/docs/firestore/query-data/listen "Get realtime updates with Cloud Firestore  |  Firebase"
[2]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
