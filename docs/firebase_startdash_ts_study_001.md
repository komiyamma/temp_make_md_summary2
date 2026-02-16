# 第01章：Firebaseって結局なにができるの？用途別マップ🙂🧭

この章は「Firebaseの全体地図を、迷子にならないレベルで頭に入れる」がゴールです🗺️✨
（まだ開発はほぼしません。まず“どこに何があるか”だけ掴めばOK！）

---

## この章のゴール🎯✅

* Firebaseでできることを **用途別にざっくり説明**できる🙂
* Firebaseコンソールで **Build / Run / AI まわりの“住所”** が分かる🧭
* 自分の作りたいアプリに必要な機能へ **丸を付けられる** ⭕

---

## Firebaseを3行でいうと？📌

* **アプリに必要な部品（ログイン、DB、保存、配信、分析、AIなど）をまとめて使えるセット**🧰
* フロント（Reactなど）から **SDKで直接つなげられる** のが強み⚡
* さらに **AI機能（アプリに入れるAI）** と **開発を助けるAI（コンソール/CLI/エージェント）** が増えてきて、作るのが速い🏃‍♂️💨 ([Firebase][1])

---

## 1) 用途別マップ（まずはこの表だけでOK）🗺️✨

| やりたいこと                | 代表サービス                                                | 何がうれしい？（超ざっくり）                                       |
| --------------------- | ----------------------------------------------------- | ---------------------------------------------------- |
| ログインしたい🔐             | Authentication                                        | メール/Googleログインなどをサクッと用意できる                           |
| データを保存したい🗃️          | Firestore / Realtime Database                         | アプリのデータ置き場（リアルタイム更新が得意）                              |
| 画像やPDFを置きたい📦         | Storage                                               | ファイル置き場。プロフィール画像などに便利                                |
| Webサイトを公開したい🌍        | Hosting / App Hosting                                 | 静的サイト〜フルスタックまで公開しやすい                                 |
| “サーバー処理”を動かしたい🧠      | Cloud Functions（など）                                   | 決済連携、バッチ、外部API連携、危険処理の隔離に使う                          |
| 通知したい🔔               | Cloud Messaging                                       | プッシュ通知（モバイル/ウェブ）                                     |
| アプリの状態を見たい👀          | Analytics / Crashlytics / Performance                 | 使われ方・クラッシュ・遅さを見える化                                   |
| アプリを出し分けたい🎛️         | Remote Config / A/B Testing                           | ボタン文言や機能を後から切替、テストもできる                               |
| 悪用を減らしたい🛡️           | App Check / Security Rules                            | 不正アクセス・ボット対策の入口                                      |
| AI機能をアプリに入れたい🤖       | Firebase AI Logic / Genkit                            | Gemini/Imagenなどでチャット・要約・画像生成などを入れやすい ([Firebase][2]) |
| AIに開発を手伝わせたい🧑‍💻🤝🤖 | Gemini in Firebase / Firebase MCP server / Gemini CLI | コンソールやエージェントが、調査・設定・手順案内まで支援してくれる ([Firebase][3])    |

> ポイント👉 Firebaseは「**Build（作る）**」「**Run（運用する）**」「**AI（AI機能とAI支援）**」で考えると、一気に見通しが良くなります🙂 ([Firebase][1])

---

## 2) AIは “2種類” ある（ここ超重要）🤖✨

## A. アプリに入れるAI（ユーザー向け）🧠📱

* **Firebase AI Logic**：Web/モバイルから、Gemini/Imagenに安全につなぐための仕組み（SDKやプロキシなど） ([Firebase][2])
* 画像生成も扱える（Imagen系）ので、将来「画像も作れるアプリ」も作れます🖼️✨ ([Firebase][4])
* クォータ（上限）で `429` が出ることがあるので、「最初に“上限と課金の動き”を把握する」癖が大事💸⚠️ ([Firebase][5])

## B. 開発を助けるAI（あなた向け）🧑‍💻🛠️

* **Gemini in Firebase**：Firebaseコンソール上で相談できる（設定・デバッグ・手順案内など） ([Firebase][3])
* **Firebase MCP server**：AIエージェントに「Firebaseを操作する道具」を渡せる（プロジェクト作成、設定取得など） ([Firebase][6])
* **Gemini CLI**：ターミナルから調査・要約・コード案・次の一手が出せる ([Google Cloud Documentation][7])

---

## 3) いまのフロント開発の“土台”だけ先に知っておこう⚛️🧱

この教材はReact+TypeScript中心なので、最低限これだけ押さえます🙂

* Reactは **19系（例：v19.2.1が2025年12月）** の流れで進みます⚛️ ([react.dev][8])
* Viteは **Node.js 20.19+ / 22.12+ 以上が必要**（テンプレにより上がることも）⚡ ([vitejs][9])
* Node.jsは **v24がActive LTS、v25がCurrent（2026-02-09更新）** という状態です（迷ったらLTS寄りが安心）🟢 ([nodejs.org][10])
* TypeScriptは **npmのlatestが5.9.3（2025-09-30公開）**、そして **6.0 Betaが2026-02-11に発表** されています（学習は安定版でOK）🧠 ([npm][11])

---

## ここから「手を動かす」💻🖱️（コンソール散歩）

## 4) Firebaseコンソールで“住所”を覚える🗺️🏃‍♂️

やることはシンプルです。**迷子にならないための3点チェック**だけ✅

## Step 1：左メニューを「Build / Run / AI」目線で眺める👀

* 「ログインっぽい」→ Authentication
* 「DBっぽい」→ Firestore / Realtime Database
* 「ファイルっぽい」→ Storage
* 「公開っぽい」→ Hosting / App Hosting
* 「運用っぽい」→ Analytics / Crashlytics / Performance / Remote Config
* 「AIっぽい」→ AI（Firebase AI Logic など） ([Firebase][1])

## Step 2：右上の“AI相談”入口を探す✨🤖

* コンソールの右上あたりに **Gemini in Firebase** が出る構造になっています（プロジェクト単位で有効化する流れ） ([Firebase][12])

## Step 3：AIが“できること / できないこと”を一言で言えるようにする🧠

* できる：設定手順の案内、エラー原因の推理、作業分解、注意点の整理
* できない：あなたの許可なしに勝手に課金確定、勝手に大事なデータ削除（※ツール連携では「実行前確認」が前提になることが多い）

  * MCP serverは「AIツールにFirebase操作の手段を渡す」仕組み、という理解でOK🔌 ([Firebase][6])

---

## 5) AIに聞くと最強な質問テンプレ💬🤖（コピペ用）

## “作りたいアプリ → Firebase機能”を一発でマッピングする質問🗺️

```text
私はReact(TypeScript)でWebアプリを作ります。
作りたいもの：{ここに1行で}
ユーザー要件：{例：ログイン、投稿、画像アップ、通知}
制約：初心者でFirebase初めて。できるだけ最小構成で。

質問：
1) Firebaseの機能を用途別に並べて、必要/不要を○×で判断してください
2) まず最初に触るべき順番（最短ルート）を提案してください
3) 事故りやすい課金/権限/セキュリティ注意点を3つ教えてください
```

## “コンソールで迷子”になったときの質問🧭

```text
いまFirebaseコンソールで {探しているもの} を探しています。
見えているメニュー：{Build/Run/AI のどこにいそう？}
私がやりたいこと：{目的}

最短のクリック手順を、3〜6ステップで教えてください。
```

（このあたりは **Gemini in Firebase** でも、**Gemini CLI** でも同じノリで使えます💪） ([Firebase][3])

---

## ミニ課題✏️⭕（3分でOK）

## 6) 「作りたいアプリ」を1行で書いて、必要機能に丸を付ける🙂✅

## ① 1行アイデア（例）

* 例：*「ログインして、短いメモを保存して、あとで検索して読めるアプリ」*📝

## ② 必要そうな機能に⭕（チェック表）

* [ ] Authentication（ログイン）🔐
* [ ] Firestore（メモ保存）🗃️
* [ ] Storage（画像を付けたいなら）📦
* [ ] Hosting / App Hosting（公開）🌍
* [ ] Functions（危険処理/外部API連携が必要なら）🧠
* [ ] Analytics（どれが使われたか見たい）👀
* [ ] Crashlytics / Performance（品質管理）🛠️
* [ ] Remote Config / A/B（出し分けしたい）🎛️
* [ ] Firebase AI Logic（要約/チャット等のAI機能）🤖✨ ([Firebase][2])

## ③ 最後にひとこと（超大事）🧯

* 「**今すぐ必要**」と「**あとで欲しくなる**」を分ける

  * 例：最初は Authentication + Firestore + Hosting だけで十分、みたいに🙂

---

## チェック✅（5つ言えたら合格！）

1. Firebaseでできることを **用途別に5つ**言える🙂
2. 「ログイン」「DB」「ファイル」「公開」が **どのサービスか**結びつく🧠
3. 「AIは2種類（アプリ向け / 開発向け）」を説明できる🤖
4. コンソールで **Build/Run/AI** のだいたいの場所が分かる🧭 ([Firebase][1])
5. 自分のアプリ案に、必要機能へ⭕が付けられた⭕

---

## 次章予告👀➡️

次は「プロジェクト＝入れ物」の考え方📦に進みます。
ここが分かると、**dev/prodで事故らない**し、AIに相談するときもズレなくなります🙂✨

---

必要なら、この第1章を **スライド化（1枚1テーマ）** とか、逆に **超短縮のチートシート版** にもできます📄✨

[1]: https://firebase.google.com/docs/ai?utm_source=chatgpt.com "AI | Firebase Documentation"
[2]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[3]: https://firebase.google.com/docs/ai-assistance/gemini-in-firebase?utm_source=chatgpt.com "Gemini in Firebase - Google"
[4]: https://firebase.google.com/docs/ai-logic/generate-images-imagen?utm_source=chatgpt.com "Generate images using Imagen | Firebase AI Logic - Google"
[5]: https://firebase.google.com/docs/ai-logic/quotas?utm_source=chatgpt.com "Rate limits and quotas | Firebase AI Logic"
[6]: https://firebase.google.com/docs/ai-assistance/mcp-server?utm_source=chatgpt.com "Firebase MCP server | Develop with AI assistance - Google"
[7]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[8]: https://react.dev/versions?utm_source=chatgpt.com "React Versions"
[9]: https://vite.dev/guide/?utm_source=chatgpt.com "Getting Started"
[10]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[11]: https://www.npmjs.com/package/typescript?activeTab=versions&utm_source=chatgpt.com "typescript"
[12]: https://firebase.google.com/docs/ai-assistance/gemini-in-firebase/set-up-gemini?utm_source=chatgpt.com "Set up Gemini in Firebase - Google"
