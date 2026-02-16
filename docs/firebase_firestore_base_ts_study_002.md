# 第02章：コレクション/ドキュメントの感覚をつかむ📚🧠

この章は「Firestoreの世界観」を体に入れる回だよ〜！😆✨
CRUDの前にここがふわっとしてると、あとでずっと迷子になるので、今日は“感覚づくり”を勝ちにいく✊🔥

---

## この章でできるようになること🎯✨

* 「コレクション」「ドキュメント」「フィールド」を、例で説明できる📦📄🔑
* ToDoアプリ用に、**データの形（設計）**を自分で決められる🧩
* ToDoを5件ぶん、**JSONっぽく**書ける🧾✨
* パス（住所）の見方がわかる🏠➡️📍

---

## まずは超イメージ：Firestoreは「住所でたどる」📮🏠

Firestoreは **テーブル**じゃなくて、基本はこういう“住所”で見にいく感じ！👀✨
（これが腹落ちすると一気にラクになる）

* コレクション：`todos`
* ドキュメントID：`todoId`
* ドキュメントの住所（パス）：`todos/{todoId}`

Firestoreでは、データは **ドキュメント（＝1件）**として保存され、それが **コレクション（＝箱）**に入るよ📦📄
そしてドキュメントの中身は **キーと値のセット（フィールド）**だよ🔑✨ ([Firebase][1])

---

## ① 用語を“手触り”で覚える🧠✨

## コレクション（collection）＝箱📦

* `todos` みたいに「同じ種類のドキュメントをまとめる箱」
* 箱の中には **ドキュメントしか入らない**（いきなり値は置けない） ([Firebase][1])

## ドキュメント（document）＝1件📄

* 例：1つのToDo（「牛乳買う」）が1ドキュメント
* それぞれ **ドキュメントID**がある（自分で付けてもいいし、ランダム自動IDでもOK） ([Firebase][1])

## フィールド（field）＝中身の項目🔑

* `title: "牛乳買う"` とか `done: false` とか
* 1ドキュメントは **キーと値の集合**（オブジェクト） ([Firebase][1])

---

## ② ToDoの「データの形」を決めよう🛠️🧩

ここで決めるのは「ToDo 1件って、どんな項目が必要？」ってやつ😊
あとでCRUDするとき、ここがそのまま効いてくるよ〜⚡

おすすめの最小セットはこれ👇

* `title: string`（ToDoの本文📝）
* `done: boolean`（完了した？✅）
* `createdAt: timestamp`（作成日時⏰）
* `updatedAt: timestamp`（更新日時🔁）
* `tags: string[]`（タグ🏷️）

`tags` を最初から入れておくのは、あとでAIと絡めると超気持ちいいから🤖✨
たとえば「このメモからタグを自動抽出して `tags` に入れる」みたいな実用ができるよ（アプリからGemini/Imagenを安全に呼べる仕組みとして Firebase AI Logic が用意されてる）([Firebase][2])

---

## ③ TypeScriptで「型」を作って頭を整理しよう🧠⚛️

「DB設計」って聞くと身構えるけど、**型にすると一気にラク**😆✨

```ts
// ToDo 1件の形（Firestoreのドキュメントの形）
export type TodoDoc = {
  title: string;        // 例: "牛乳を買う"
  done: boolean;        // 例: false
  createdAt: unknown;   // 後の章で Timestamp にする（serverTimestamp など）
  updatedAt: unknown;   // 同上
  tags: string[];       // 例: ["買い物", "家"]
};
```

※ここでは timestamp を “unknown” 扱いにしてOK！
「型を厳密にする」のは、あとで `Timestamp` や `serverTimestamp()` を入れる章で気持ちよく整える👍✨

---

## ④ 「ToDoを5件」JSONっぽく書いてみよう🧾✍️

ここが今日のメイン練習！✊😤
**実データを先に作る**と、次章でConsole触るときに迷子にならないよ🧭✨

```ts
// 5件ぶんのサンプル（JSONっぽいToDo）
export const seedTodos: Array<{
  id: string;        // これは「ドキュメントIDの例」だと思ってOK
  data: {
    title: string;
    done: boolean;
    createdAt: "2026-02-16T09:00:00+09:00";
    updatedAt: "2026-02-16T09:00:00+09:00";
    tags: string[];
  };
}> = [
  {
    id: "todo_001",
    data: {
      title: "牛乳を買う",
      done: false,
      createdAt: "2026-02-16T09:00:00+09:00",
      updatedAt: "2026-02-16T09:00:00+09:00",
      tags: ["買い物", "家"],
    },
  },
  {
    id: "todo_002",
    data: {
      title: "歯医者の予約を入れる",
      done: false,
      createdAt: "2026-02-16T09:00:00+09:00",
      updatedAt: "2026-02-16T09:00:00+09:00",
      tags: ["健康", "予定"],
    },
  },
  {
    id: "todo_003",
    data: {
      title: "部屋の掃除（机の上だけ）",
      done: true,
      createdAt: "2026-02-16T09:00:00+09:00",
      updatedAt: "2026-02-16T09:00:00+09:00",
      tags: ["家", "片付け"],
    },
  },
  {
    id: "todo_004",
    data: {
      title: "メモ：Firestoreの用語（collection/document/field）を説明できるようにする",
      done: false,
      createdAt: "2026-02-16T09:00:00+09:00",
      updatedAt: "2026-02-16T09:00:00+09:00",
      tags: ["勉強", "Firestore"],
    },
  },
  {
    id: "todo_005",
    data: {
      title: "週末の予定を3つ考える",
      done: false,
      createdAt: "2026-02-16T09:00:00+09:00",
      updatedAt: "2026-02-16T09:00:00+09:00",
      tags: ["予定", "生活"],
    },
  },
];
```

ポイントはこれ👇😺✨

* **ドキュメントID（id）** と **フィールド（dataの中身）** を分けて考える
* `tags` は配列だけど、配列の中にさらに配列は入れられない（地味に大事） ([Firebase][3])

---

## ⑤ AIで「フィールド案」と「サンプルデータ」を秒速で作る🤖⚡

ここからが2026っぽいやつ！😎✨
AIは“答えを出す係”というより、**たたき台製造機**として使うのが最強👍

## A) Antigravity（Mission Control）で「設計たたき台」🛰️🧠

Antigravityはエージェントを管理しながら、計画→実装→調査まで回しやすい思想になってるよ（Mission Control って考え方が前面）([Google Codelabs][4])

**投げるプロンプト例：**

```text
ToDoアプリのFirestore設計をしたい。
コレクション名は todos で固定。
1件のToDoドキュメントのフィールド案を、初心者向けに「最小セット」「あると便利」「AIで活躍」の3段に分けて提案して。
型（TypeScript）も出して。
```

## B) Gemini CLIで「サンプル5件」生成🧪🧾

Gemini CLIはターミナルで動くオープンソースのAIエージェントで、ReActループやMCP連携の説明も公式にあるよ([Google Cloud Documentation][5])

**投げるプロンプト例：**

```text
Firestoreの todos コレクション用に、TodoDoc 形式で5件のサンプルデータを作って。
titleは日本語、tagsは2〜3個、doneは混ぜて。
出力は TypeScript の配列リテラルだけで。
```

生成結果はそのまま使わず、**「変なフィールド名がないか」だけ目視チェック**すればOK👌😆

---

## ⑥ つまずきポイント（先回りで潰す）🧯😤

* **コレクションやドキュメントは、作成ボタンより先に“書き込んだら勝手に作られる”**
  これがFirestoreの感覚！([Firebase][1])
* **ドキュメントは最大1 MiB**（でかい本文を1個に詰め込みすぎ注意）([Google Cloud Documentation][6])
* **フィールド名に `/` は使えない**（パスと衝突する）([Google Cloud Documentation][6])
* **ドキュメント名やフィールド名に個人情報を入れない**（運用で地雷になりがち）([Firebase][7])

---

## 🧩ミニ課題（5〜15分）✍️✨

1. `todos` の ToDo 1件に必要なフィールドを、**最小セット5つ**で書く📝
2. さっきの `seedTodos` みたいに、**5件ぶん**をJSONっぽく書く🧾
3. そのうち1件は「AIでタグ抽出したくなる文章」にする🤖🏷️（長めのメモとか）

---

## ✅チェック（言えたら勝ち）🎉

* 「コレクション＝箱、ドキュメント＝1件、フィールド＝中身」って言える？📦📄🔑
* `todos/{todoId}` みたいな“住所”の見方がわかる？🏠📍
* ToDo 5件ぶんを、同じ形で書けた？🧾✨
* `tags: string[]` を入れると、あとでAIが絡めやすい理由が言える？🤖🏷️

---

## 次章ちょい予告👀✨

次はConsoleでFirestoreを有効化して、`todos` に **実際に1件入れて**「いまどこに何が入ってるか」を目で追うよ〜🧰👀🔥

[1]: https://firebase.google.com/docs/firestore/data-model?utm_source=chatgpt.com "Cloud Firestore Data model | Firebase - Google"
[2]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[3]: https://firebase.google.com/docs/firestore/manage-data/data-types?utm_source=chatgpt.com "Supported data types | Firestore - Firebase - Google"
[4]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[5]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[6]: https://docs.cloud.google.com/firestore/quotas?utm_source=chatgpt.com "Quotas and limits | Firestore in Native mode"
[7]: https://firebase.google.com/docs/firestore/best-practices?utm_source=chatgpt.com "Best practices for Cloud Firestore - Firebase - Google"
