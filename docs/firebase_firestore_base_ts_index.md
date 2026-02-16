# Firestore基礎：CRUD＋リアルタイムを体で覚える（20章アウトライン）🗃️⚡

この20章を終えると、**「Firestoreって怖い…」が消えて**、CRUDとリアルタイム更新を使った **ToDo/メモアプリが完成**します🎯✨
途中からは、AIも絡めて「データ作り」「整理」「デバッグ」もスピードアップします🤖💨

---

### 2026-02-16 時点の“登場バージョン”メモ 🧾

* Firebase Web SDK：`firebase` **12.9.0**（npm）([npm][1])
* Node.js：**v24.x が Active LTS**（最新LTS枠）([Node.js][2])
* TypeScript：npm上の安定版は **5.9.3**（※6.0はBetaの話も出てる）([npm][3])
* Firebase Admin（サーバー側）

  * Node.js：**13.6.1**([Firebase][4])
  * Python：**7.1.0**([Firebase][5])
  * .NET：**3.4.0（.NET 8+ 推奨）**([Firebase][6])

---

## 全体アウトライン（ユニット構成）🧭

* **Unit A（1〜4）**：Firestoreの地図・Console・SDK準備
* **Unit B（5〜10）**：CRUDを“手が勝手に動く”まで反復 ✋
* **Unit C（11〜16）**：リアルタイム購読＆クエリ基礎 🔎⚡
* **Unit D（17〜20）**：ページング→安全なローカル検証→ミニアプリ完成 🎯🤖

---

## 20章の教材アウトライン（各章：読む→手を動かす→ミニ課題→チェック）📚✨

### 第01章：Firestoreって何者？（まず怖さを消す）😌🗃️

* 📖 読む：Firestoreは「ドキュメント型DB」「リアルタイム同期」が得意
* 🛠️ 手を動かす：完成イメージ（ToDo/メモ）を先に眺める
* 🧩 ミニ課題：ToDoの画面イメージを3つ書く（一覧/追加/編集）📝
* ✅ チェック：「テーブルじゃないDB」でも困らない理由を言える

---

### 第02章：コレクション/ドキュメントの感覚をつかむ📚🧠

* 📖 読む：`todos` コレクション、`todoId` ドキュメント、フィールドの考え方
* 🛠️ 手を動かす：ToDoのフィールド案（title, done, createdAt…）を決める
* 🧩 ミニ課題：ToDoを5件ぶん、JSONっぽく紙に書く🧾
* ✅ チェック：「コレクション=箱」「ドキュメント=1件」を説明できる

---

### 第03章：ConsoleでFirestoreを有効化＆触ってみる🧰👀

* 📖 読む：Firestore作成〜Consoleでデータを見る流れ([Firebase][7])
* 🛠️ 手を動かす：Consoleから手動で `todos` を作って1件追加
* 🧩 ミニ課題：Consoleで `done: false` のToDoを3件入れる✅
* ✅ チェック：Consoleで「今どこに何が入ってるか」迷子にならない

---

### 第04章：ReactからFirestoreへ接続（最初の配線）🔌⚛️🗃️

* 📖 読む：Web SDKの導入とFirestore初期化の全体像([Firebase][7])
* 🛠️ 手を動かす：`firebaseConfig` を入れて Firestore インスタンスを作る
* 🧩 ミニ課題：接続確認として「一覧取得→画面に0件表示」まで到達
* ✅ チェック：どのファイルに初期化を置くと綺麗かイメージできる

---

### 第05章：Create① 追加する（addDoc / setDoc の気持ち）➕📄

* 📖 読む：自動IDと固定IDの違い、どっちを使う？
* 🛠️ 手を動かす：フォームからToDoを追加できるようにする
* 🧩 ミニ課題：「タイトル必須」だけバリデーション入れる🧩
* ✅ チェック：IDが自動でも運用できる理由がわかる

---

### 第06章：Read① 1件読む（getDoc）🔎📄

* 📖 読む：ドキュメント参照と「存在チェック」
* 🛠️ 手を動かす：詳細ページでToDo 1件を表示
* 🧩 ミニ課題：存在しないIDなら「見つからない」表示を出す🙅‍♂️
* ✅ チェック：「取得できない」と「存在しない」の区別ができる

---

### 第07章：Read② 複数読む（getDocs）📚📄✨

* 📖 読む：コレクション取得と配列に変換する考え方
* 🛠️ 手を動かす：一覧ページでToDoを全部表示
* 🧩 ミニ課題：件数（○件）も表示する🔢
* ✅ チェック：取得結果が「スナップショット」だと理解できる

---

### 第08章：Update① 更新する（updateDoc / setDoc merge）✏️🔁

* 📖 読む：部分更新と“まるごと上書き”の違い
* 🛠️ 手を動かす：ToDoのタイトル編集を実装
* 🧩 ミニ課題：更新完了トースト（成功メッセージ）を出す🎉
* ✅ チェック：うっかりフィールド消し事故を避けられる

---

### 第09章：Update② よく使う“便利更新”（done切替・配列・数値）✅📈

* 📖 読む：チェックON/OFF、カウンタ、タグ配列の更新の発想
* 🛠️ 手を動かす：`done` をワンクリックで切り替え
* 🧩 ミニ課題：タグ（配列）を1つ追加するUIを作る🏷️
* ✅ チェック：“編集画面なし更新”ができる

---

### 第10章：Delete 削除する（deleteDoc）🗑️💥

* 📖 読む：削除UIは慎重に（取り消しできない）
* 🛠️ 手を動かす：一覧から削除（確認ダイアログ付き）
* 🧩 ミニ課題：「削除したら一覧から消える」まで
* ✅ チェック：削除のUX（誤タップ防止）を説明できる

---

### 第11章：Timestamp入門（createdAt / updatedAt の基本）⏱️🧩

* 📖 読む：クライアント時刻 vs サーバー時刻、ソートで困る話
* 🛠️ 手を動かす：追加時に `createdAt`、更新時に `updatedAt` を入れる
* 🧩 ミニ課題：一覧に「作成日時」を表示する📅
* ✅ チェック：時刻フィールドがあると何が嬉しいか言える

---

### 第12章：リアルタイム購読①（onSnapshotで“勝手に更新”）⚡👀

* 📖 読む：リアルタイム購読の気持ちよさ（ポーリング不要）
* 🛠️ 手を動かす：一覧を `onSnapshot` に切り替える
* 🧩 ミニ課題：別タブで追加→一覧が自動で増えるのを確認🪄
* ✅ チェック：購読解除が必要な理由がわかる

---

### 第13章：リアルタイム購読②（Reactで安全に扱う）⚛️🧯

* 📖 読む：`useEffect` と unsubscribe の関係
* 🛠️ 手を動かす：購読をhooks化（例：`useTodos()`）
* 🧩 ミニ課題：読み込み中/エラー/空状態をきれいに出す✨
* ✅ チェック：画面遷移してもメモリリークしない

---

### 第14章：クエリ基礎① where（絞り込み）🔎🎯

* 📖 読む：条件検索の基本（等価/範囲/配列系）
* 🛠️ 手を動かす：`done == false` だけ表示するフィルタ
* 🧩 ミニ課題：「未完了/完了」切替ボタンを作る🎛️
* ✅ チェック：whereの条件が増えると何が起きがちか想像できる

---

### 第15章：クエリ基礎② `orderBy` / `limit`（並べて、上だけ取る）📏⬆️

* 📖 読む：並び替えと件数制限の考え方([Firebase][8])
* 🛠️ 手を動かす：`createdAt desc` で新しい順に並べる
* 🧩 ミニ課題：最新10件だけ表示（limit）
* ✅ チェック：orderByすると「フィールドが無いドキュメント」がどうなるか言える([Firebase][8])

---

### 第16章：“インデックスエラー”を怖がらない（読む→直す）🛠️😤

* 📖 読む：複合条件でインデックスが必要になることがある（あるある）
* 🛠️ 手を動かす：わざと複合クエリを作ってエラーを出す
* 🧩 ミニ課題：エラーメッセージのリンクからインデックスを作る
* ✅ チェック：エラー文を見て「何が足りないか」判断できる

---

### 第17章：ページング入門①（カーソルって何？）📜🧭

* 📖 読む：Firestoreのページングは“カーソル”でやる([Firebase][9])
* 🛠️ 手を動かす：`limit(10)` + `startAfter(lastDoc)` の形を作る
* 🧩 ミニ課題：「次へ」ボタンで次の10件を取る
* ✅ チェック：`startAt` と `startAfter` の違いを説明できる([Firebase][9])

---

### 第18章：ページング入門②（無限スクロールの考え方）♾️📱

* 📖 読む：無限スクロールは「次を取りに行くタイミング」が肝
* 🛠️ 手を動かす：IntersectionObserverで下に来たら次ページ取得
* 🧩 ミニ課題：二重読み込み（連打）を防ぐガードを入れる🧱
* ✅ チェック：重複表示・取りこぼしを防ぐ工夫が言える

---

### 第19章：安全に壊して練習する（Emulator + サーバー側投入）🧪🧯

* 📖 読む：Emulator Suiteの概要と、Firestore Emulatorに接続する手順([Firebase][10])
* 🛠️ 手を動かす：Firestore Emulatorへ接続して、ローカルでCRUD確認
* 🛠️ ついでに：Emulator UIの **Requests** で「何が投げられてるか」眺める👀([Firebase][11])
* 🧩 ミニ課題：サーバー側（Admin SDK）で seed データを10件流し込む（Node/Python/.NET いずれか）

  * Admin Node：13.6.1([Firebase][4])
  * Admin Python：7.1.0（Python 3.10+ 推奨）([Firebase][5])
  * Admin .NET：3.4.0（.NET 8+ 推奨）([Firebase][6])
* ✅ チェック：「本番DBを汚さず試す」流れを説明できる

---

### 第20章：総合ミニ課題（ToDo/メモ完成）＋AIで“実用っぽさ”を足す🎯🤖✨

* 📖 読む：AIを「文章を整える」「タグ抽出する」「入力補助する」に使う発想
* 🛠️ 手を動かす：最終アプリ要件（例）

  * 追加/編集/削除 ✅
  * リアルタイム一覧 ⚡
  * フィルタ（未完了）🔎
  * 無限スクロール ♾️
  * createdAt/updatedAt ⏱️
* 🤖 AIパワーアップ（FirebaseのAIサービス）

  * Firebase AI Logicで **Gemini/Imagen** をアプリから安全に呼べる([Firebase][12])
  * 例）メモ文章を「読みやすく整形」→整形後をFirestoreに保存📝✨
  * 例）メモから「タグをJSONで抽出」→`tags: string[]` に保存🏷️🧾
* 🤖 開発をAIで加速

  * GoogleのAntigravityは“エージェント駆動で計画→実装”の流れを作りやすい（Mission Control）([Google Codelabs][13])
  * Gemini CLIはターミナル上のAIエージェントで、修正・調査・テスト支援までやる設計（ReAct/MCPなど）([Google Cloud Documentation][14])
* ✅ チェック：自分のアプリを「説明できる」「直せる」「育てられる」状態になってる

---

## おまけ：この20章で作るデータ例（迷子防止）🧭🧩

* コレクション：`todos`
* ドキュメント例フィールド：

  * `title: string`
  * `done: boolean`
  * `createdAt: timestamp`
  * `updatedAt: timestamp`
  * `tags: string[]`（AI抽出で活躍🏷️）
  * `order?: number`（将来の並び替え用）

---

[1]: https://www.npmjs.com/package/firebase?utm_source=chatgpt.com "firebase"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[4]: https://firebase.google.com/support/release-notes/admin/node?utm_source=chatgpt.com "Firebase Admin Node.js SDK Release Notes - Google"
[5]: https://firebase.google.com/support/release-notes/admin/python?utm_source=chatgpt.com "Firebase Admin Python SDK Release Notes - Google"
[6]: https://firebase.google.com/support/release-notes/admin/dotnet?utm_source=chatgpt.com "Firebase Admin .NET SDK Release Notes"
[7]: https://firebase.google.com/docs/firestore/quickstart?utm_source=chatgpt.com "Get started with Cloud Firestore Standard edition - Firebase"
[8]: https://firebase.google.com/docs/firestore/query-data/order-limit-data?utm_source=chatgpt.com "Order and limit data with Cloud Firestore - Firebase - Google"
[9]: https://firebase.google.com/docs/firestore/query-data/query-cursors?utm_source=chatgpt.com "Paginate data with query cursors | Firestore | Firebase"
[10]: https://firebase.google.com/docs/emulator-suite?utm_source=chatgpt.com "Introduction to Firebase Local Emulator Suite"
[11]: https://firebase.google.com/docs/emulator-suite/connect_firestore?utm_source=chatgpt.com "Connect your app to the Cloud Firestore Emulator - Firebase"
[12]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[13]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[14]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
