# 第10章：Delete 削除する（deleteDoc）🗑️💥

この章のゴールはシンプル！
**ToDo一覧に「🗑️削除」ボタンを付けて、確認ダイアログ付きで安全に消せる**ようにします😎✨
Firestore側は `deleteDoc()` でOKです（公式の削除方法）([Firebase][1])

---

## 0) まず大事：削除は「一番取り返しがつかない」⚠️😱

追加・更新はミスっても直せるけど、削除は「データが消える」ので怖いです💥
だからこの章では、最初から **事故りにくいUI** にします👇

* 誤タップ防止：**確認ダイアログ**を出す🧯
* 二重クリック防止：削除中は**ボタン無効化**🔒
* 失敗しても安心：**エラー表示**＋ログ📣

---

## 1) Firestoreの削除はこれだけ！🧠🗑️

Firestore公式の「1ドキュメント削除」はこの形👇 ([Firebase][1])

```ts
import { doc, deleteDoc } from "firebase/firestore";

// await deleteDoc(doc(db, "todos", todoId));
```

---

## 2) 実装の全体像（今日やること）🧩🧰

今回の流れはこうです👇

1. `deleteTodo(todoId)` を作る🧱
2. 一覧の各行に「🗑️削除」ボタンを付ける🧷
3. 押したら確認 → OKなら `deleteDoc()` 実行💥
4. 成功したら画面から消える（state更新 or 再取得）✨

---

## 3) 手を動かす：削除関数を作る🛠️

`src/lib/todos/deleteTodo.ts`（ファイル名は例）を用意します📁

```ts
import { deleteDoc, doc } from "firebase/firestore";
import { db } from "../firebase"; // 既に作ってある想定（第4章あたり）

export async function deleteTodo(todoId: string) {
  // "todos" はコレクション名。ここが違うと消えません🙅‍♂️
  await deleteDoc(doc(db, "todos", todoId));
}
```

ポイント✅

* `doc(db, "todos", todoId)` の **パスが正しいこと**が命です🔥
* `await` を忘れると、UIだけ先に進んで「消えた気がする事故」になります😵‍💫

---

## 4) 手を動かす：一覧に削除ボタン＋確認ダイアログ🗑️✅

ここでは一番ラクで強い **`window.confirm()`** を使います（後でオシャレModalにも置き換えられるよ😉）

## 4-1) 状態（削除中ID）を持つ🔒

```tsx
import { useState } from "react";
import { deleteTodo } from "../lib/todos/deleteTodo";

type Todo = {
  id: string;
  title: string;
  done: boolean;
  tags?: string[];
};

export function TodoList({ initialTodos }: { initialTodos: Todo[] }) {
  const [todos, setTodos] = useState<Todo[]>(initialTodos);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [message, setMessage] = useState<string>("");

  async function handleDelete(todo: Todo) {
    const ok = window.confirm(
      `「${todo.title}」を削除しますか？\n※取り消しできません🧨`
    );
    if (!ok) return;

    setDeletingId(todo.id);
    setMessage("");

    try {
      await deleteTodo(todo.id);

      // 成功したら UI からも消す✨（onSnapshotにすると後で自動化できるよ⚡）
      setTodos((prev) => prev.filter((t) => t.id !== todo.id));
      setMessage("削除しました🗑️✨");
    } catch (e) {
      console.error(e);
      setMessage("削除に失敗しました😵（権限 or 通信の可能性）");
    } finally {
      setDeletingId(null);
    }
  }

  return (
    <div>
      {message && <p>{message}</p>}

      <ul>
        {todos.map((todo) => (
          <li key={todo.id} style={{ display: "flex", gap: 8, alignItems: "center" }}>
            <span>{todo.title}</span>

            <button
              type="button"
              onClick={() => handleDelete(todo)}
              disabled={deletingId === todo.id}
              aria-busy={deletingId === todo.id}
              title="削除"
            >
              {deletingId === todo.id ? "削除中…🌀" : "🗑️ 削除"}
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

## 4-2) もし「再取得型（loadTodos）」の作りなら🔁

`setTodos(filter…)` の代わりに、`await loadTodos()` で取り直してもOKです📚
（どっちでも正解！初心者は “取り直し” でも安心感ある👍）

---

## 5) つまずきポイント集（ここ超あるある）🧯🧠

## A) 「削除できない😡」→ だいたい Rules かパス

* `doc(db, "todos", todoId)` の `"todos"` が違う
* ルールで `delete` が許可されてない（後のRules章で本格的にやるやつ）🔐

## B) 「親を消したのにサブコレが残る…」👻

**重要⚠️：ドキュメント削除しても、サブコレの中身は自動で消えません！**
参照パスでアクセスできちゃいます。([Firebase][1])
（もし将来コメント等のサブコレを持つ設計なら、削除設計は別途必要🧨）

## C) 「大量削除したい！」🚜💣

クライアントからコレクション丸ごと削除は **非推奨**（セキュリティも負荷も事故りやすい）([Firebase][1])
大量削除は Console / Firebase CLI / bulk delete を使うのが基本です🧰([Firebase][1])

---

## 6) ミニ課題🎯🧩

次を満たしてたら勝ちです😆✨

* [ ] 削除前に確認が出る✅
* [ ] OKで削除できる🗑️
* [ ] 削除したら一覧から消える✨
* [ ] 削除中はボタンが押せない🔒
* [ ] 失敗したらメッセージが出る📣

---

## 7) ✅チェック（口で説明できたら理解OK）🗣️✨

* `deleteDoc(doc(db, "todos", id))` の意味を説明できる
* 「削除は取り消しできないから確認UIが必要」を説明できる
* 「サブコレは自動で消えない」を説明できる([Firebase][1])

---

## 8) 🔥AIで“削除事故”を減らす（オプション）🤖🧠

削除確認って、タイトルが短いと怖いよね😇
そこで **Firebase AI Logic** を使って、削除前に「短い確認文」をAIに作らせると安心感が上がります✨
Web向けの導入は `firebase/ai` でいけます([Firebase][2])

例：削除ダイアログ用の文を作る（やるならここまででOK）👇

```ts
import { getAI, getGenerativeModel, GoogleAIBackend } from "firebase/ai";
import type { FirebaseApp } from "firebase/app";

type Todo = { title: string; done: boolean; tags?: string[] };

export function createAiTools(firebaseApp: FirebaseApp) {
  const ai = getAI(firebaseApp, { backend: new GoogleAIBackend() });
  const model = getGenerativeModel(ai, { model: "gemini-2.5-flash" });

  return {
    async buildDeleteConfirmText(todo: Todo) {
      const prompt =
        "次のToDoを削除する確認文を、日本語で短く（30文字くらい）。" +
        "少し強めに注意して。\n" +
        `title: ${todo.title}\n` +
        `done: ${todo.done}\n` +
        `tags: ${(todo.tags ?? []).join(", ")}`;

      const result = await model.generateContent(prompt);
      return result.response.text();
    },
  };
}
```

使い方のイメージ👇

* ゴミ箱クリック → AIで確認文作る → その文で confirm を出す🧨🤖
  （将来、App Check とセットで運用するとさらに安全寄り👍）

---

## 9) Antigravity / Gemini CLI を使うなら、こう頼むと早い🚀🧑‍✈️

## Antigravity（Mission Controlで“設計→実装→確認”を回す）🛰️

Antigravityはエージェント管理（Mission Control）込みの開発フローが売りです([Google Codelabs][3])
**指示文テンプレ（コピペ用）**👇

* 「TodoListに削除ボタンを追加。confirm付き。削除中は二重押し防止。成功時はstateから除外。失敗時はメッセージ表示。変更差分だけ提示して」

## Gemini CLI（ターミナルで調査・修正・レビュー）🧑‍💻✨

Gemini CLIはターミナル上のAIエージェントとして、修正や調査もやれる設計です([Google Cloud Documentation][4])
**指示文テンプレ**👇

* 「FirestoreのdeleteDocでよくある失敗（Rules/パス/二重クリック）をチェックリスト化して、今のコードで抜けてる点を指摘して」

---

次（第11章）は `createdAt/updatedAt` のTimestampで、アプリが一気に“それっぽく”なります⏱️✨

[1]: https://firebase.google.com/docs/firestore/manage-data/delete-data "Delete data from Cloud Firestore  |  Firebase"
[2]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
[3]: https://codelabs.developers.google.com/getting-started-google-antigravity "Getting Started with Google Antigravity  |  Google Codelabs"
[4]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli "Gemini CLI  |  Gemini for Google Cloud  |  Google Cloud Documentation"
