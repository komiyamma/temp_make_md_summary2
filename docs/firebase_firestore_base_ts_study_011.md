# 第11章：Timestamp入門（createdAt / updatedAt の基本）⏱️🧩

この章でやることはシンプルです👇
**「追加した日時」「更新した日時」をFirestoreにちゃんと残して、画面に出せる**ようになります📅✨
これができると、**新しい順ソート**・**更新履歴**・**“さっき更新したやつどれ？”問題**が一気に解決します😆👍

（※2026-02-16時点の主要バージョン確認：Firebase `12.9.0` / Node.js v24 Active LTS / TypeScript `5.9.3`）([npm][1])

---

## 1) まず結論：時刻は「サーバー時刻」を使うのが安定⏱️🌍

端末の時計って、意外とズレます😇（PCの時刻がズレてる、スマホは自動補正、など）
そこでFirestoreでは、**サーバー側で確定する時刻**を入れられます👇

* ✅ `createdAt`: 作った瞬間（基本いじらない）
* ✅ `updatedAt`: 更新した瞬間（更新のたびに上書き）

Firestoreの公式的な入れ方は **`serverTimestamp()`** を使う方法です。([Firebase][2])

---

## 2) 「Timestamp」って何？🤔🧾

Firestoreの時刻フィールドは、ただの文字列じゃなくて **`Timestamp` 型**です🧩
ポイントはこれ👇

* **タイムゾーンに依存しない “時刻の点”**として保存される（中身はUTC基準）🌐
* JSで表示したいときは **`toDate()`** で `Date` に変換できる📆

`Timestamp.toDate()` は公式リファレンスにあります。([Firebase][3])

---

## 3) 実装①：ToDoの型に createdAt / updatedAt を足す🧱✨

「読み取り用」と「書き込み用」で、時刻の型がちょっとややこしくなりがちなので、初心者向けに**安全寄り**にいきます👇
読み取りは `Timestamp | null` として扱う（最初は `null` の可能性があるため）🧯

```ts
// src/types/todo.ts
import type { Timestamp } from "firebase/firestore";

export type Todo = {
  id: string;
  title: string;
  done: boolean;

  // Firestoreの時刻（未確定の瞬間などはnullの可能性があるので保険）
  createdAt: Timestamp | null;
  updatedAt: Timestamp | null;

  tags?: string[];
};
```

---

## 4) 実装②：追加時に createdAt / updatedAt を入れる➕⏱️

追加の瞬間に `serverTimestamp()` を入れます。
これで**端末の時計がズレてても、DB上は整う**👏

```ts
// src/lib/todos.ts
import { addDoc, collection, serverTimestamp } from "firebase/firestore";
import { db } from "./firebase"; // 第4章で作った想定

export async function addTodo(title: string) {
  const trimmed = title.trim();
  if (!trimmed) throw new Error("タイトルは必須です🙏");

  await addDoc(collection(db, "todos"), {
    title: trimmed,
    done: false,
    tags: [],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
}
```

🔥小ネタ：同じ書き込みの中で `serverTimestamp()` を複数フィールドに入れると、**同じ時刻値**になります（地味に嬉しい）([Firebase][2])

---

## 5) 実装③：更新時に updatedAt を入れる✏️⏱️

更新するたびに `updatedAt` だけ更新します。

```ts
import { doc, updateDoc, serverTimestamp } from "firebase/firestore";
import { db } from "./firebase";

export async function updateTodoTitle(todoId: string, title: string) {
  const trimmed = title.trim();
  if (!trimmed) throw new Error("タイトルは必須です🙏");

  await updateDoc(doc(db, "todos", todoId), {
    title: trimmed,
    updatedAt: serverTimestamp(),
  });
}

export async function toggleTodoDone(todoId: string, done: boolean) {
  await updateDoc(doc(db, "todos", todoId), {
    done,
    updatedAt: serverTimestamp(),
  });
}
```

---

## 6) 実装④：画面に「作成日時」を表示する📅👀

## 6-1) まず：`null` を安全にさばく🧯

`createdAt` が `null` の間は、UIで「—」とか「作成中…」を出すのがラクです😌

```ts
import type { Timestamp } from "firebase/firestore";

export function formatTimestamp(ts: Timestamp | null): string {
  if (!ts) return "—";

  const d = ts.toDate(); // Timestamp -> Date
  return new Intl.DateTimeFormat("ja-JP", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(d);
}
```

`Timestamp.toDate()` は公式に書かれている変換です。([Firebase][3])

---

## 6-2) さらに快適に：サーバー確定前でも「推定値」で表示する🪄

Firestoreは、`serverTimestamp()` がまだ確定してない瞬間、**デフォルトだと `null`** を返します。
でも、スナップショット取得時に **`estimate`** を指定すると、ローカル時計ベースの推定値を返せます（あとで確定値に変わります）✨

この挙動は `SnapshotOptions.serverTimestamps` に明記されています。([Firebase][4])

例：`getDoc()` / `onSnapshot()` で受け取った `snapshot` から読むとき👇

```ts
import type { DocumentSnapshot } from "firebase/firestore";
import type { Todo } from "@/types/todo";

export function snapshotToTodo(
  snap: DocumentSnapshot
): Todo {
  const data = snap.data({ serverTimestamps: "estimate" }) as any;

  return {
    id: snap.id,
    title: data.title ?? "",
    done: !!data.done,
    tags: data.tags ?? [],
    createdAt: data.createdAt ?? null,
    updatedAt: data.updatedAt ?? null,
  };
}
```

---

## 7) ミニ課題：一覧に「作成日時」を出してみよう📋📅✨

やることはこれだけ👇

* ✅ 一覧の各ToDoの下に `作成: 2026/02/16 12:34` を表示する
* ✅ できたら `更新: ...` も表示する（`updatedAt`）

例（UIイメージ）👇

* 📝 牛乳買う

  * 📅 作成: 2026/02/16 12:34
  * ✏️ 更新: 2026/02/16 13:02

---

## 8) よくあるハマりどころ集（先に踏んでおく）💥🧯

## ハマり①：作成日時が `null` のままで表示されない😇

* 原因：`serverTimestamp()` はサーバー確定まで **一瞬 `null`** になりうる
* 対策：

  * UIで `null` を許容（「—」表示）
  * もしくは `serverTimestamps: "estimate"` を使う([Firebase][4])

## ハマり②：端末時刻で `Date.now()` を入れたら、順番がぐちゃる⌛🌀

* 原因：端末の時計ズレ＆タイムゾーン＆手動変更
* 対策：**createdAt/updatedAt は serverTimestamp()** が安定([Firebase][2])

## ハマり③：あとから “createdAt を編集できちゃう” 問題🔓

* これは本質的に「セキュリティルール」で守る話に繋がります🛡️
  （今は“そういう事故がある”だけ覚えておけばOK👌）

---

## 9) AIでここを爆速にする🤖⚡（任意だけど超おすすめ）

## 9-1) Google Antigravityで「全ファイル修正」を一気にやる🛰️🛠️

Antigravityは、エージェントが計画→修正→検証まで回しやすい “Mission Control” の考え方が特徴です。([Google Codelabs][5])

おすすめの指示（例）👇

* 「プロジェクト内の `addDoc` / `updateDoc` を探して、`updatedAt: serverTimestamp()` を入れて。型エラーも直して。最後に起動確認まで」

## 9-2) Googleの Gemini CLIで “探して直す” を端末でやる🧰🤖

Gemini CLI はターミナル上のAIエージェントで、検索・修正・テスト支援みたいな流れを回せます。([Google Cloud Documentation][6])

おすすめの頼み方（例）👇

* 「`createdAt` と `updatedAt` を Firestore に追加する作業をやりたい。該当箇所を検索して、必要な修正パッチを提案して」

## 9-3) Firebase AI Logicで「自然言語の日時→Timestamp」を作る📆➡️⏱️（超それっぽくなる）

Firebase AI Logic は、アプリからGemini/Imagenを扱える仕組み（＋App Checkなどで守れる）です。([Firebase][7])

この章と相性いいAIネタはこれ👇

* 例）入力欄に「**明日の15時**」って書いたら、AIに **ISO日時**にしてもらう
* それを `Timestamp.fromDate(new Date(iso))` で `remindAt` として保存🧩

（※ここは“任意の拡張”。まずは createdAt/updatedAt を固めればOKです👌）

---

## 10) チェック（できたら勝ち）✅🏁

* ✅ `createdAt / updatedAt` を **serverTimestamp()** で入れられた([Firebase][2])
* ✅ 画面に `createdAt` を表示できた（`null` も安全に）🧯
* ✅ 必要なら `estimate` で “確定前の表示” もできる([Firebase][4])
* ✅ 「時刻があると、ソート・履歴・表示が強くなる」を説明できる💪✨

---

次の第12章では、いよいよ **`onSnapshot` のリアルタイム購読**に突入します⚡👀
ここで入れた `createdAt` が、リアルタイムの一覧でも効いてきますよ〜😆🔥

[1]: https://www.npmjs.com/package/firebase?utm_source=chatgpt.com "firebase"
[2]: https://firebase.google.com/docs/firestore/manage-data/add-data "Add data to Cloud Firestore  |  Firebase"
[3]: https://firebase.google.com/docs/reference/js/firestore_.timestamp "Timestamp class  |  Firebase JavaScript API reference"
[4]: https://firebase.google.com/docs/reference/js/firestore_.snapshotoptions "SnapshotOptions interface  |  Firebase JavaScript API reference"
[5]: https://codelabs.developers.google.com/getting-started-google-antigravity "Getting Started with Google Antigravity  |  Google Codelabs"
[6]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli "Gemini CLI  |  Gemini for Google Cloud  |  Google Cloud Documentation"
[7]: https://firebase.google.com/docs/ai-logic "Gemini API using Firebase AI Logic  |  Firebase AI Logic"
