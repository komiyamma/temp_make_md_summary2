# 第16章：“インデックスエラー”を怖がらない（読む→直す）🛠️😤

この章はね、結論から言うとこうです👇
**「インデックスエラー＝Firestoreからの“宿題プリント”」** です📄✨
怖いのは最初だけ。読めるようになると、むしろ助かる存在になります💪😎

（※以下は2026年2月時点の公式ドキュメントを確認して構成しています）([Firebase][1])

---

## 📖 読む：まず“インデックス”って何？（超やさしく）🧠📚

Firestoreは**速い検索を保証するために、すべてのクエリをインデックスで処理**しようとします。
基本的なクエリに必要なインデックスは自動で作られて、足りない時はエラーで教えてくれます🧭([Firebase][1])

インデックスは大きく2種類👇

* **単一フィールド（single-field）**：多くは自動で面倒見てくれる🍼
* **複合（composite）**：複数条件や並び替えで必要になることがある（手動で作ることが多い）🧩([Firebase][1])

そして大事ポイント👇
**複合インデックスは“フィールドの順番どおりに並んだ辞書”**みたいなもの。順番が意味を持ちます📖🧷([Firebase][1])

---

## 🛠️ 手を動かす：わざとエラーを出して、直してみよう🔥➡️✅

ここからは「エラーを出すのが正解」です😆
ToDoアプリの `todos` を想定して、**複合クエリ**で “インデックスが足りない” を体験します。

## 1) わざと“複合クエリ”を作る🧨

例：未完了＋タグ指定＋新しい順（ありがちなやつ）👇

```ts
import { collection, query, where, orderBy, limit, onSnapshot } from "firebase/firestore";
import { db } from "./firebase"; // 第4章で作った Firestore 初期化のやつ

const q = query(
  collection(db, "todos"),
  where("done", "==", false),
  where("tags", "array-contains", "ai"),
  orderBy("createdAt", "desc"),
  limit(10),
);

const unsub = onSnapshot(
  q,
  (snap) => {
    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    console.log("✅ todos", items);
  },
  (err) => {
    console.error("🔥 Firestore error", err);
  },
);

// 画面を離れる時などに unsub() する（第13章の復習）
```

## 期待すること🎯

まだインデックスが無ければ、多くの場合、コンソールにこんな系のエラーが出ます👇

* 「The query requires an index」
* または `failed-precondition` っぽいエラー

> これが出たら勝ちです🏆（=学習が進んでる証拠）

なお、**複合インデックスには“配列フィールドは最大1つ”**という制限があります（tagsみたいな配列は入れすぎ注意）🧯([Firebase][1])

---

## 👀 読む：エラー文の“見分け方”はこれだけ🕵️‍♂️

## A) 「インデックスが足りない」系（今回の主役）🧩

* だいたい **“index が必要”** と言われる
* 直し方：**インデックスを作ればOK** ✅([Firebase][2])

## B) 「クエリ自体が無理」系（インデックスじゃ解決しない）🚫

* だいたい **“Invalid query”** と言われる
* 例：不等号（`>` とか `!=` とか）を複数フィールドでやりすぎ、など
* 直し方：**クエリ設計を変える**（whereを減らす／データの持ち方を変える）🧠([Firebase][3])

---

## 🛠️ 手を動かす：直し方は3ルートあるよ🛣️✨

## 直し方①：エラーに出てくるリンクで作る（最速）🚀

公式的には、足りない時に**“作成リンク”がエラーに含まれる**想定です。クリック→自動入力→Create で終わり！([Firebase][2])

ただし現実には、SDKや状況によって **リンクが出ない/動かない報告もあります**🥲
（その場合は②へ）([GitHub][4])

## 直し方②：Consoleで手動作成（確実）🧰

Firebase Console の Firestore → **Indexes** タブから **Add Index** で作れます。
インデックスは数分かかることがあるので、作ったらステータスが “Building” になってないか見る👀([Firebase][2])

今回の例クエリなら、だいたいこういう形（目安）👇

* collection: `todos`
* fields（例）:

  * `tags`：Array contains
  * `done`：Ascending（等価条件でも選択が必要）
  * `createdAt`：Descending（orderBy に合わせる）

> もし「作ったのにまだ同じエラー」が出たら、**フィールドの順番・ASC/DESC・ARRAY_CONTAINS**がズレてることが多いです😵‍💫
> （リンクが出る場合はリンクの内容が正解なので、そこに寄せるのがいちばんラク）

## 直し方③：CLIで “インデックスをコード管理”📦

チーム開発や複数環境（開発/本番）ではめっちゃ強いです💪
公式でも、CLIで `firestore.indexes.json` を作ってデプロイできると案内されています。([Firebase][2])

流れのイメージ👇

```bash
## 初期化（プロジェクトに Firestore の設定ファイルを作る）
firebase init firestore

## インデックス＆ルールだけデプロイ（必要なものだけ）
firebase deploy --only firestore
```

さらに、今あるインデックスを吐き出してファイルに反映したい時は、CLIでエクスポートもできます🧾([Firebase][5])

---

## ⏳ 「作ったのに直らない！」あるある集😤➡️😌

## 1) “Building中”だった🧱

インデックス作成は、空のDBでも最短で数分はかかることがあります。データが多いほど時間が伸びます⌛([Firebase][2])

## 2) `orderBy` してるのに、そのフィールドが入ってないドキュメントがある🙈

`orderBy` は「そのフィールドが存在するものだけ」返す動きになるので、データ次第で「消えた？」になります😵‍💫([Firebase][6])

## 3) 配列フィールドを2つ入れた複合インデックスを作ろうとして詰む🪤

複合インデックスは **配列フィールドは最大1つ**です（tags系は特に注意）([Firebase][1])

---

## 🤖 AI活用：インデックス作成を“爆速で終わらせる”やり方

## ✅ Gemini CLI：エラーログを貼って「何が必要？」を即翻訳🧠⚡

**Gemini CLI**はターミナルで動くAIエージェントで、調査やデバッグの流れに向いてます。([Google Cloud Documentation][7])
やることは単純👇

* ブラウザコンソールのエラー文をコピペ
* 「必要な複合インデックスのフィールド構成を教えて」って聞く
* そのまま Console/CLI に反映する

## ✅ Antigravity：Mission Controlで“原因→修正→確認”を自動で回す🛰️🤖

**Google Antigravity**は、エージェントが計画して調査して直す流れ（Mission Control）を組みやすいです。([Google Codelabs][8])
たとえば👇

* 「このクエリが落ちてる。どの条件が複合インデックス要るか調べて」
* 「`firestore.indexes.json` を生成して」
* 「デプロイコマンドの手順もまとめて」
  みたいな“作業の束”をまとめてお願いできるのが強み💥

## ✅ Firebase AI Logic：アプリ内で“エラー説明”や“運用ヘルプ”もできる🧩✨

Firestoreの話から一歩進んで、アプリ側に「ヘルプAI」を入れるのもアリ。
**Firebase AI Logic**は、アプリからGemini/Imagenにアクセスできる仕組みです。([Firebase][9])
（例：開発者向け画面で「最後のエラーをAIに要約させる」など）

---

## 🧩 ミニ課題：あなたの手で“インデックス職人”になろう🔧😎

## お題🎯

次のクエリを作って、**インデックスエラー→作成→成功**までやってみてね！

* `done == false`
* `tags array-contains "work"`
* `orderBy updatedAt desc`
* `limit 10`

## できたら追加ボーナス🎁

* CLIで `firestore.indexes.json` を用意して、インデックスをコード管理に寄せてみる📦

---

## ✅ チェック：この章を終えたら言えるようになること🗣️✨

* 「インデックスエラー」は **“必要な索引を作ってね”** という合図だと分かる📣
* リンクが出る時は最速で作れるし、出なくても **Indexes タブで手動作成できる**🧰([Firebase][2])
* 「Invalid query」系は **インデックスじゃなく設計の見直し**だと判断できる🧠([Firebase][3])
* CLI/AIを使って、インデックス作成を“作業”から“手順化”にできる🤖📦([Firebase][2])

---

次に第17章でページングへ行く前に、もしよければ👇
いまの `todos` のフィールド（done/tags/createdAt/updatedAt）を前提に、**「よく使うクエリ3つ」と「必要になりがちな複合インデックス候補」**を先に作っちゃうテンプレも出せるよ🧠🧩✨

[1]: https://firebase.google.com/docs/firestore/query-data/index-overview "Index types in Cloud Firestore  |  Firebase"
[2]: https://firebase.google.com/docs/firestore/query-data/indexing "Manage indexes in Cloud Firestore  |  Firebase"
[3]: https://firebase.google.com/docs/firestore/query-data/multiple-range-fields?utm_source=chatgpt.com "Query with range and inequality filters on multiple fields ..."
[4]: https://github.com/firebase/firebase-js-sdk/issues/6788?utm_source=chatgpt.com "Firestore Composite Index error does not give a link anymore"
[5]: https://firebase.google.com/docs/reference/firestore/indexes?utm_source=chatgpt.com "Cloud Firestore Index Definition Reference | Firebase - Google"
[6]: https://firebase.google.com/docs/firestore/query-data/order-limit-data?utm_source=chatgpt.com "Order and limit data with Cloud Firestore - Firebase - Google"
[7]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[8]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[9]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
