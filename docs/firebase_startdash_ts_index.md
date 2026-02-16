# Firebase「スタートダッシュ（全体地図＆最小アプリ完成）」教材アウトライン（全20章）🗺️🚀

（各章は 10〜20分想定：読む→手を動かす→ミニ課題→チェック ✅）

---

## 第01章：Firebaseって結局なにができるの？用途別マップ🙂🧭

- **読む**：認証・DB・ファイル・配信・サーバー処理・通知・分析・AIをざっくり俯瞰👀
- **手を動かす**：コンソールの「Build / Run」あたりを眺めて“全体の住所”を覚える🗺️
- **ミニ課題**：自分の作りたいアプリを1行で書いて、どの機能が必要か丸をつける⭕
- **チェック**：「何に使うサービスか」を5つ言えたらOK✅

## 第02章：プロジェクト＝アプリ？まず“入れ物”の考え方📦🧠

- **読む**：FirebaseプロジェクトとGoogle Cloudプロジェクトの関係、だいたいの感覚🤝
- **手を動かす**：プロジェクト一覧→切り替え→設定画面まで行けるようにする🧭
- **ミニ課題**：プロジェクト名の命名ルールを自分用に作る（例：myapp-dev / myapp-prod）📝
- **チェック**：「どこを変えると“別環境”になる？」を説明できたらOK✅

## 第03章：Consoleの歩き方：迷子にならない最低ルート🔧🚦

- **読む**：Project Overview / Project settings / Usage & billing の役割をざっくり🙂
- **手を動かす**：左メニューを一周して「ここで何をするか」をメモる🗒️
- **ミニ課題**：「設定がありそうな場所」を3つ探して当てるゲーム🎯
- **チェック**：Webアプリ設定（SDK）に自力で辿り着けたらOK✅

## 第04章：🤖AIと一緒に学ぶ：聞き方テンプレ（超初心者向け）💬✨

- **読む**：AIに投げる“良い質問”＝目的＋現状＋エラー＋期待、だけ📌
- **手を動かす**：Geminiに「今から何をすれば最小で動く？」を聞いて手順を箇条書きにさせる🤖
- **ミニ課題**：質問テンプレをメモ帳に保存（コピペ用）📝
- **チェック**：AIの答えを“自分の言葉で”3行に要約できたらOK✅

## 第05章：Antigravityで作業場を作る：Mission Controlに慣れる🕹️🛸

- **読む**：エージェント中心IDEとしての考え方（エディタ＋ターミナル＋ブラウザ）🌐 ([Google Codelabs][1])
- **手を動かす**：ワークスペース作成→ターミナルでコマンド実行→プレビュー表示まで一回通す🚀
- **ミニ課題**：Agentに「次にやること3つ」を短く提案させる🧠
- **チェック**：エージェントに任せる/自分でやるの切り分けが言えたらOK✅

## 第06章：Gemini CLIの超入門：ターミナルで“聞きながら進む”💻🤖

- **読む**：CLIでできること（調査・要約・修正案・テストたたき台）を軽く知る🙂 ([firebase.studio][2])
- **手を動かす**：Gemini CLIで「FirebaseのWeb初期化の最小コード」を聞いてみる🧪
- **ミニ課題**：よく使う質問を3つ“スニペ化”する（例：エラー解説、次の一手、コード例）📌
- **チェック**：CLIで答えを引き出して行動に移せたらOK✅

## 第07章：Node.jsとnpm：まず“動く土台”を確認🔩🧰

- **読む**：フロント開発で必要なNodeの役割（実行環境＋パッケージ管理）🙂
- **手を動かす**：Nodeのバージョン確認→npmで依存追加のイメージを掴む📦
- **ミニ課題**：`package.json` を開いて scripts を読めるようになる👀
- **チェック**：`npm run dev` が何をするか説明できたらOK✅

## 第08章：React+TypeScript最小アプリ作成（Vite）⚛️🌱

- **読む**：Viteの役割（爆速開発サーバー・ビルド）と、必要なNode条件🙂 ([vitejs][3])
- **手を動かす**：ViteでReact+TSプロジェクト作成→起動→ブラウザ表示🚀
- **ミニ課題**：画面に「動いた！」を表示してスクショ📸
- **チェック**：ローカル（またはAntigravity）で起動できたらOK✅

## 第09章：ファイル構成の超基本：迷子にならない3点セット🧭📁

- **読む**：`src` / `public` / `package.json` の役割だけ覚える🙂
- **手を動かす**：`App.tsx` を触って表示を変える✍️
- **ミニ課題**：コンポーネントを1個分ける（例：`TopPage.tsx`）🧩
- **チェック**：どこを直すと画面が変わるか分かったらOK✅

## 第10章：UIミニ設計：ログイン前トップの“最低限きれい”🎨✨

- **読む**：トップ画面に必要な要素（見出し・説明・ボタン・フッター）🙂
- **手を動かす**：Header/Main/Footer を作る（中身はダミーでOK）🏗️
- **ミニ課題**：「はじめる」ボタンだけ押せるようにする👆
- **チェック**：レイアウトが崩れても“直す場所”が分かればOK✅

## 第11章：Firebaseプロジェクト作成：最初の1回を最短で🌋🚀

- **読む**：プロジェクト作成時に出る選択肢の意味をざっくり🙂
- **手を動かす**：新規プロジェクト作成→Overviewに戻って確認✅
- **ミニ課題**：プロジェクトIDをメモしておく📝
- **チェック**：コンソール上で「今どのプロジェクト？」が分かればOK✅

## 第12章：Webアプリ登録：SDKの“名札”を作る🏷️🌐

- **読む**：Webアプリ登録＝ブラウザ用設定（config）を発行すること🙂
- **手を動かす**：Webアプリ追加→config取得→メモ📝
- **ミニ課題**：configの各項目を1行で説明してみる（分からなければAIに聞く🤖）
- **チェック**：configを見失わず保管できたらOK✅

## 第13章：SDK導入→初期化→起動確認：最小の「繋がった！」🌱⚡

- **読む**：初期化は `initializeApp` から始まる（まずここだけ）🙂
- **手を動かす**：Firebase JS SDK導入→`firebase.ts` 作成→アプリ起動🧪
- **ミニ課題**：画面に「Firebase初期化OK」表示（成功/失敗で文言を変える）✅
- **チェック**：ブラウザコンソールでエラーが出たら読めるようになればOK✅

## 第14章：設定の置き場所：公開していいもの/ダメなもの🔐📦

- **読む**：Webのconfigは“完全な秘密鍵”ではないけど、扱いのルールは必要🙂
- **手を動かす**：Viteの環境変数（`.env`）に移して読み込む🧪
- **ミニ課題**：Gitに入れないファイルの考え方を覚える（AIに貼らない🙅‍♂️🤖）
- **チェック**：「どれを公開しちゃダメ？」を言えたらOK✅

## 第15章：🤖Firebase MCPサーバー：AIエージェントにFirebase操作を手伝わせる🛠️🧠

- **読む**：MCPで“ツールとしてFirebaseを叩ける”ようになるイメージ🙂 ([Firebase][4])
- **手を動かす**：AntigravityのMCP ServersからFirebaseをInstall（`firebase-tools@latest mcp`）🔌 ([Firebase][4])
- **ミニ課題**：Agentに「プロジェクト一覧」「設定場所」を案内させる🧭🤖
- **チェック**：AIが“勝手に”ではなく“あなたの許可で”進む感覚が掴めたらOK✅

## 第16章：🤖Gemini CLI×Firebase拡張：困ったら即レスで前に進む🏃‍♂️💨

- **読む**：Firebase extensionを入れるとMCP＋コンテキストが整って強い🙂 ([Firebase][4])
- **手を動かす**：Gemini CLIにFirebase拡張を入れて、初期化の相談をさせる🧰 ([Firebase][4])
- **ミニ課題**：「よくあるミス3つ（config場所/初期化/ビルド）」をAIにまとめさせる📝
- **チェック**：エラー時に“聞き方”が分かったらOK✅

## 第17章：プロジェクト分け（dev/prod）の超基本：事故らない運用の入口🧠🚧

- **読む**：環境分けの目的＝設定/データ/課金を混ぜないこと💡
- **手を動かす**：dev用プロジェクトを作って切り替え練習🔁
- **ミニ課題**：configをdev/prodで差し替えできる形にする（まずは手動でOK）🧪
- **チェック**：「今どっちの環境で動いてる？」が即答できたらOK✅

## 第18章：料金・クォータ事故を避ける：最初に付ける“安全装置”💸🧯

- **読む**：料金プランの概要（Spark/Blaze）と注意点🙂
- **手を動かす**：Usage & billing周りを確認→通知（アラート）設定の入口まで行く🔔
- **ミニ課題**：「予算アラートは“停止装置”じゃない」ことを一言で説明してみる⚠️
- **チェック**：“お金が増える要因”を3つ言えたらOK✅

## 第19章：これから出てくるFunctions/AIの予告：言語とバージョン感だけ先に👀⚙️

- **読む**：Cloud Functionsは2nd gen中心＆Nodeが主役、Python/.NETも選択肢🙂 ([Firebase][5])
- **手を動かす**：Firebase側のFunctionsドキュメントでNodeランタイム（20/22）を確認🧾 ([Firebase][5])
- **ミニ課題**：未来メモを書く📝
  - Node：20/22が主に案内される ([Firebase][5])
  - Python：FirebaseのFunctionsでは python310/311 が登場（まずはここ） ([Firebase][5])
  - .NET：Cloud Run functions側では .NET 6/8（＋preview）などが見える ([Google Cloud Documentation][6])
- **チェック**：「今は触らないけど、後でこれをやる」が言語別に言えたらOK✅

## 第20章：仕上げミニ課題：ログイン前トップ画面を完成させる🎨🏁

- **読む**：完成条件＝“見た目OK”＋“起動OK”＋“Firebase初期化OK”の3点セット✅
- **手を動かす**：トップ画面を整える（見出し/説明/CTA/フッター）＋Firebase初期化表示🌱
- **ミニ課題**：スクショ1枚＋「どこができて、どこが不安か」を3行で書く📸📝
- **チェック**：
  - `npm run dev`（またはAntigravityのRun）で毎回起動できる✅
  - configが迷子にならない✅
  - 料金画面の入口に行ける✅

---

## 補足（最新動向の拾いどころ）🆕👀

- TypeScriptは 6.0 Beta が出ていて、5.9系からの橋渡しという位置づけだよ🧱 ([Microsoft for Developers][7])
- Reactは 19.2 系が最新ラインとして案内されてるよ⚛️ ([react.dev][8])
- Viteは 7.3.1 が最新で、Node要件が上がっているのでここだけ注意⚡ ([npmjs.com][9])
- FirebaseのAI連携（AI Logic）はモデルの更新/終了予定が明記されるので、教材でも“古い例を踏まない”導線を作るのが大事🤖🧯 ([Firebase][10])

次は、この20章アウトラインをそのまま「各章の本文テンプレ（説明→手順→よくある詰まり→AIに聞く例→チェック問題）」に展開して、章ごとの完成原稿まで落とせるよ📚✨

[1]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[2]: https://firebase.studio/blog/article/nix-on-idx?utm_source=chatgpt.com "How we use Nix on Project IDX"
[3]: https://vite.dev/guide/?utm_source=chatgpt.com "Getting Started"
[4]: https://firebase.google.com/docs/ai-assistance/mcp-server "Firebase MCP server  |  Develop with AI assistance"
[5]: https://firebase.google.com/docs/app-hosting "Firebase App Hosting"
[6]: https://docs.cloud.google.com/run/docs/runtimes/function-runtimes "Cloud Run functions runtimes  |  Google Cloud Documentation"
[7]: https://devblogs.microsoft.com/typescript/announcing-typescript-6-0-beta/ "Announcing TypeScript 6.0 Beta - TypeScript"
[8]: https://react.dev/versions?utm_source=chatgpt.com "React Versions"
[9]: https://www.npmjs.com/package/vite?utm_source=chatgpt.com "vite - Native-ESM powered web dev build tool"
[10]: https://firebase.google.com/docs/functions/manage-functions "Manage functions  |  Cloud Functions for Firebase"
