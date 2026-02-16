# 第08章：Update① 更新する（updateDoc / setDoc merge）✏️🔁

この章のゴールはシンプル！
**「ToDoのタイトルを編集して、Firestoreに安全に保存できる」**ようになることです😆🧩
そして同時に、Firestoreでありがちな事故 **「うっかり上書きでフィールド消滅💥」** を回避できるようになります。

（ちなみに本日時点で、Web SDK の `firebase` は npm で **12.9.0** が最新として表示されています）([npm][1])

---

## 0) まず結論：更新はこの3つを使い分ける🧠✨

Firestoreの更新は、だいたいこの3パターンで勝てます✌️

| やりたいこと                  | 使うAPI                          | ざっくり何が起きる？            | よくある注意                |
| ----------------------- | ------------------------------ | --------------------- | --------------------- |
| **一部だけ更新**（titleだけ変える等） | `updateDoc()`                  | 指定フィールドだけ更新✅          | **ドキュメントが無いと失敗**しがち😵 |
| **まるごと保存**（全部入れ直す）      | `setDoc()`                     | **ドキュメントを上書き**（全置換）✍️ | 既存フィールドが消える事故💥       |
| **一部だけ保存（存在しなくてもOK）**   | `setDoc(..., { merge: true })` | 指定フィールドだけ反映（足し込み）➕    | ネスト（オブジェクト）更新は要注意⚠️   |

`setDoc()` が **デフォルトは上書き**で、`merge: true` で **部分反映**になる、というのが超重要ポイントです🧯([Firebase][2])

---

## 1) 事故る例：「tagsが消えた…😇」を体験で理解する

たとえば `todos/{id}` がこうだったとします👇

* `title: "牛乳買う"`
* `done: false`
* `tags: ["買い物", "冷蔵庫"]`

ここで「タイトルだけ変えたい！」と思って、うっかり👇をやると…

```ts
await setDoc(todoRef, { title: "牛乳と卵買う" });
```

**tags が消えます**（上書きだから）💥😇
→ こういう “消し事故” を避けるのがこの章の主役です！

---

## 2) 🛠️ 手を動かす：タイトル編集を `updateDoc()` で実装する✍️⚛️

## 2-1) 更新用の関数を作る（まずはこれだけでOK）🧩

```ts
// src/lib/todos/updateTodoTitle.ts
import { doc, updateDoc, serverTimestamp } from "firebase/firestore";
import { db } from "../firebase"; // 例：あなたの db 取得に合わせて調整

export async function updateTodoTitle(todoId: string, newTitle: string) {
  const title = newTitle.trim();
  if (!title) throw new Error("タイトルが空です");

  const todoRef = doc(db, "todos", todoId);

  // ✅ 一部だけ更新（安全）
  await updateDoc(todoRef, {
    title,
    updatedAt: serverTimestamp(),
  });
}
```

`updateDoc()` は「このフィールドだけ変える」用です✅
そして、ドキュメントが存在しないと失敗することがあります（エラー例として “たぶん存在してないよ” 的な説明がドキュメントにも出ます）([Firebase][2])

---

## 2-2) 編集UI（最小のフォーム例）📝✨

```tsx
// src/components/TodoTitleEditor.tsx
import { useState } from "react";
import { updateTodoTitle } from "../lib/todos/updateTodoTitle";

type Props = {
  todoId: string;
  initialTitle: string;
  onSaved?: () => void;
};

export function TodoTitleEditor({ todoId, initialTitle, onSaved }: Props) {
  const [title, setTitle] = useState(initialTitle);
  const [saving, setSaving] = useState(false);
  const [toast, setToast] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToast(msg);
    window.setTimeout(() => setToast(null), 1600);
  };

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await updateTodoTitle(todoId, title);
      showToast("保存できた！🎉");
      onSaved?.();
    } catch (err: any) {
      showToast(`保存失敗…😵 ${err?.message ?? ""}`);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div>
      <form onSubmit={onSubmit} style={{ display: "flex", gap: 8 }}>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          disabled={saving}
          placeholder="タイトル"
          style={{ flex: 1, padding: 8 }}
        />
        <button disabled={saving} type="submit" style={{ padding: "8px 12px" }}>
          {saving ? "保存中…" : "保存"}
        </button>
      </form>

      {toast && (
        <div style={{ marginTop: 10, padding: 10, border: "1px solid #ddd" }}>
          {toast}
        </div>
      )}
    </div>
  );
}
```

これで最低限、**編集 → 保存 → 成功メッセージ** が完成です🎯✨
（UIはTailwind等に置き換えてOK👍）

---

## 3) `setDoc(..., { merge: true })`：存在しなくても更新したい時の技🪄

`updateDoc()` は「あるものを更新」向き。
一方で、たとえば **ユーザー設定**みたいに「無ければ作ってOK」な時は `setDoc(merge:true)` がラクです😆

```ts
import { doc, setDoc, serverTimestamp } from "firebase/firestore";
import { db } from "../firebase";

export async function upsertUserPrefs(uid: string, theme: "light" | "dark") {
  const ref = doc(db, "users", uid);

  // ✅ 無ければ作る / あれば一部だけ更新（足し込み）
  await setDoc(
    ref,
    { prefs: { theme }, updatedAt: serverTimestamp() },
    { merge: true }
  );
}
```

ただし！ここで注意点⚠️
`prefs` が “オブジェクト” だと、書き方によっては **prefs全体を置き換える**感じになりやすいです（ネストは罠になりがち）😵

---

## 4) ネスト（オブジェクト）の安全更新：「ドット記法」を覚える🔧🧠

「オブジェクトの中の1項目だけ変えたい」なら、ドット記法が便利です✨
Firestoreのドキュメントでも、**ネスト更新にはドット記法を使う**例が出ています([Firebase][2])

```ts
await updateDoc(ref, {
  "prefs.theme": "dark",
  updatedAt: serverTimestamp(),
});
```

---

## 5) ついでに覚えると強い：フィールド削除 `deleteField()` 🗑️✨

「このフィールド、無かったことにしたい！」って時もありますよね😆
そんな時は `deleteField()` が使えます🧹

```ts
import { doc, updateDoc, deleteField } from "firebase/firestore";

await updateDoc(doc(db, "todos", todoId), {
  tags: deleteField(),
});
```

公式ドキュメントでも “Delete fields” として `deleteField()` の例が載っています([Firebase][3])

---

## 6) 🤖 AIで“更新”を賢くする（Firebase AI Logic を絡める）✨

ここからが「AI導入済み」前提の美味しいところです😋
編集したタイトルをそのまま保存するだけじゃなく、

* 誤字を直す✍️
* いい感じに短くする📏
* 読みやすく整える🧼

みたいな加工を **保存前にAIにやらせる**と、アプリが一気に実用っぽくなります🎯

Firebase AI Logic の Web 例では、`firebase/ai` を使ってモデルを作る流れが案内されています([Firebase][4])

## 6-1) 例：タイトルをAIに整形させてから updateDoc する🪄

イメージはこんな感じ👇（超ざっくり）

* ユーザー入力：`"  ぎゅうにゅう かう "`
* AI整形：`"牛乳を買う"`
* Firestore更新：`title = "牛乳を買う"`

実装のコツは：

* **AIの出力をそのまま信じず**、`trim()` と **空チェック**をもう一回する🧯
* “長すぎる” を防ぐため **最大文字数**を決める（例：60文字）✂️

---

## 7) 🧠 開発をAIで加速：Gemini CLI / Antigravity の使いどころ

* **Gemini CLI** はターミナルでAIに作業を頼める系で、ドキュメントでは *ReAct* や *MCP* などの仕組み（ツール連携）に触れています
* **Google Antigravity** は “Mission Control” 的なノリで、計画→実装をエージェントで回しやすい導線が用意されています

この章での実用アイデアはこんな感じ👇

* ✅ **「この setDoc、上書き事故起きない？」** をコードレビューしてもらう🔍
* ✅ Firestoreのエラー文を貼って **原因と直し方を日本語で説明**してもらう🧑‍🏫
* ✅ `updateDoc` に渡すデータを **型崩れしない形に整えてもらう**🧱

---

## 🧩 ミニ課題（この章のゴールチェック）🎯✨

次の3つを全部満たせたらクリアです🙆‍♂️🎉

1. タイトルを編集して保存できる✍️
2. 保存成功時に「保存できた！🎉」が出る（トースト）
3. `updatedAt: serverTimestamp()` を毎回更新している⏱️

余裕があれば＋1🔥
4. AI整形（整形後タイトル）を保存できる🤖✨

---

## ✅ チェック（言えたら勝ち）🧠💯

* `setDoc()` はデフォルトで **上書き**。フィールドが消える事故が起きる😇([Firebase][2])
* 一部更新は `updateDoc()` が安全✅
* 「無ければ作る」も含めたいなら `setDoc(..., { merge: true })` が便利🪄([Firebase][2])
* ネストは **ドット記法**が安心🔧([Firebase][2])
* フィールド削除は `deleteField()` 🗑️([Firebase][3])

---

## よくある詰まりポイント集😵‍💫🧯

* **保存したのに他フィールドが消えた**
  → `setDoc()` 上書き事故の可能性大💥（`merge:true` か `updateDoc()`へ）

* **`updateDoc` が失敗する**
  → そのIDのドキュメントが無い可能性🫠（編集画面に来る前に取得できてるか確認）

* **ネストを更新したら、ネスト全体が置き換わった**
  → ドット記法で “中の1個” を指定する🔧([Firebase][2])

---

必要なら、この第8章の内容に合わせて
「第7章の一覧画面」に **編集ボタン→編集フォーム表示** まで自然に繋がる形のサンプル構成にも整理して出しますよ😉✨

[1]: https://www.npmjs.com/package/firebase?utm_source=chatgpt.com "firebase"
[2]: https://firebase.google.com/docs/firestore/manage-data/add-data "Add data to Cloud Firestore  |  Firebase"
[3]: https://firebase.google.com/docs/firestore/manage-data/delete-data "Delete data from Cloud Firestore  |  Firebase"
[4]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
