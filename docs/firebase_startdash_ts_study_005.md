# 第05章：Antigravityで作業場を作る：Mission Controlに慣れる🕹️🛸

この章では「Antigravity上で、**エージェント＋エディタ＋ターミナル＋ブラウザ**を1つの作業場として回せる状態」を作ります✨
（次章以降でReactやFirebaseを乗せるための“土台づくり”だよ🧱）

---

## まずイメージだけ：Antigravityは「エージェントの管制室」🛰️🤖

普通のIDEは「ファイルを開いて書く」が中心だけど、Antigravityは最初に **Agent Manager（Mission Control）** が前面に来ます🚦
ここで複数エージェントを並行に動かし、成果物（Artifacts）や差分をレビューしながら進める感じです🧠✨ ([Google Codelabs][1])

---

## この章のゴール🎯✅

* ✅ **Workspaces（作業フォルダ）** を作って、迷子にならない置き場ができる📁
* ✅ **Agent Manager ↔ Editor** を行き来できる🔁
* ✅ **ターミナル** を開いてコマンドが叩ける💻
* ✅ **ブラウザ連携（Chrome拡張）** を入れて、AIがWebを見に行ける🌐🤖
* ✅ **安全な許可設定**（勝手に実行しない）を理解する🔐

---

## 1) インストール＆初回セットアップ（ここだけは丁寧に）🧩🔧

Antigravityはデスクトップアプリとしてインストールして使います。プレビュー提供で、個人Gmailで始められます📩
Chromeも必要になります🌐 ([Google Codelabs][1])

## セットアップで出てくる“3つの許可”が超重要⚠️🧯

初回に「AIにどこまでやらせる？」が出ます。ここはビビってOKです😆
設定はあとで変えられるけど、最初は安全寄りがラク！

* 🧨 **Terminal Execution policy（ターミナル実行）**

  * Always proceed / Request review（承認してから実行）
* 🧾 **Review policy（レビュー）**

  * Always proceed / Agent decides / Request review
* 🌐 **JavaScript Execution policy（ブラウザでJS実行）**

  * Always proceed / Request review / Disabled
    ※Always proceedは自動で進むけど、セキュリティ露出も上がるよ⚠️ ([Google Codelabs][1])

## おすすめの選び方👍✨

* 迷ったら **Review-driven development（よく確認を求めてくるやつ）** がバランス良くておすすめです✅ ([Google Codelabs][1])

---

## 2) Workspacesを作る：プロジェクト置き場を決める📁🧭

AntigravityのWorkspaceは、ざっくり言うと「このフォルダで作業するよ」という拠点です🏠
初回に“Workspaceを開く”流れが出たら、そこでプロジェクト用フォルダを選びます📂

例：`my-agy-projects` みたいなフォルダを作って選ぶ（名前は何でもOK）✨
このステップはスキップもできるけど、最初に作っておくと迷子になりません🧭 ([Google Codelabs][1])

## Agent Managerの見どころ👀

* 📥 **Inbox**：会話（タスク）一覧。あとで戻れる
* 🧵 **Start Conversation**：新しい依頼を出す
* 🗂️ **Workspaces**：作業場所を切り替える ([Google Codelabs][1])

---

## 3) 「Planning」と「Fast」を使い分ける⚡🧠

会話を始めると、モードが選べます：

* 🧠 **Planning**：調査→計画→成果物（Artifacts）を作ってから進む（初心者はこっちが安心）
* ⚡ **Fast**：すぐ実行（小さな変更向け） ([Google Codelabs][1])

この章は基本 **Planning** でOKです🙆‍♂️

---

## 4) Editorに移動して「3点セット」を揃える🧰💻🤖

Agent Manager右上の **Open Editor** でEditorへ移動できます✍️ ([Google Codelabs][1])

Editor側で見たいのはこの3つ👇

* 🧾 エディタ（ファイル）
* 💻 ターミナル
* 🤖 エージェントパネル（右側チャット）

## 表示の切り替え（覚えると速い）⌨️✨

* 💻 ターミナルの表示：`Ctrl + ``（バッククォート）` ([Google Codelabs][1])
* 🤖 エージェントパネル：`Cmd + L`（※環境により異なるので、効かなければメニューから開けばOK） ([Google Codelabs][1])

（ショートカットが合わないときは、**表示メニュー**や**パネル切り替え**から開ければOKです😊）

## まず1回だけ“ターミナル動作確認”✅

PowerShellでもOKなので、とりあえずこれ打って「動く」確認しよう💨

```powershell
pwd
```

表示が返ってきたら勝ち🏆✨

---

## 5) ブラウザ連携：Chrome拡張を入れて“Web操作”を有効化🌐🧩

Antigravityの強みは「エージェントがブラウザを見に行って確認できる」ことです👀🤖
そのために **Chrome拡張** を入れます。

やり方はシンプル👇

1. Agent Managerで **Playground** を選ぶ🎮
2. 依頼に「antigravity.google に行って」みたいなタスクを投げる📝
3. エージェントが途中で「ブラウザ設定が必要」的に言うので **Setup** を押す🔧
4. Chromeが開いて拡張のインストールへ誘導されるので入れる🧩
5. 戻ると、エージェントがブラウザ操作を続行できるようになる🌐🤖 ([Google Codelabs][1])

## ここでも“許可の考え方”が大事🔐

ブラウザでJavaScript実行の許可（Request review/Disabledなど）が関わります。
最初は **Request review** が安心です🧯 ([Google Codelabs][1])

---

## 6) Artifacts（成果物）とReview Changes（差分確認）を知る🧾🔍

Antigravityは、エージェントが作ったものを **Artifacts** として残します📌
スクショ、動画、計画、差分…が出てくるので「あとで検証しやすい」のが良さ✨

* 🧾 Artifactsは **Agent Manager / Editor** どちらにも出る
* 🔍 **Review Changes** でコード差分を確認できる
* 🗒️ フィードバックは “Google Docsみたいなコメント” 感覚で返せる ([Google Codelabs][1])

---

## 7) エージェントに任せる / 自分でやる：切り分けのコツ🧠🫱🫲

## エージェントに任せると気持ちいいやつ🎉

* 🔎 公式ドキュメントの読み取り＆要約
* 🧭 「次に何する？」の手順化（チェックリスト化）
* 🧪 エラー文の意味説明（→候補を3つ出す）

## 自分が握ったほうが安全なやつ🔐

* 💳 課金・権限・本番データに触れる操作
* 🧨 ターミナルで危険なコマンド（削除/上書き）
* 🔑 秘密情報（APIキー、秘密鍵）を貼ること（AIにも貼らない🙅‍♂️）

---

## 8) AIへの聞き方：この章で使うテンプレ💬✨

コピペで使えるやつ置いとくね🧡

* 🧭 **次にやること3つ**

  * 「いま私はAntigravityの作業場を作っています。次にやることを3つ、短く箇条書きでください。」
* 🧩 **迷子防止**

  * 「いま開いてる画面がAgent ManagerかEditorか、見分け方を教えて。」
* 🌐 **ブラウザ連携が不安**

  * 「Chrome拡張のセットアップで“どこを押すか”を、手順だけで説明して。」
* 🧯 **許可設定のおすすめ**

  * 「初心者向けに安全な設定（ターミナル/レビュー/ブラウザJS）を、理由つきでおすすめして。」

---

## ミニ課題🎯📝：「次にやること3つ」をエージェントに言わせる

1. Agent Managerで新しい会話を開始💬
2. さっきのテンプレを投げる🧠
3. 出てきた3つを、あなた用に短く言い直してメモする🗒️✨
4. 可能なら、そのうち1つだけ実行して✅を付ける

---

## チェック✅（できたらこの章クリア！）🏁✨

* ✅ Workspace（作業フォルダ）が決まってる📁
* ✅ Agent ManagerとEditorを行き来できる🔁
* ✅ ターミナルを開いて `pwd` が打てた💻
* ✅ Chrome拡張が入り、ブラウザ連携ができた🌐🧩
* ✅ “勝手に実行させない”許可の感覚が分かった🔐

---

## よくある詰まりポイント集🧯😵‍💫

* 😵 **エージェントが止まって見える**
  → だいたい「承認待ち」です。Inbox/会話の中に確認要求が出てないかチェック📥
* 🧩 **Chrome拡張の導線が出ない**
  → ブラウザを使うタスク（“サイトに行って”）を投げるとSetupが出やすい🌐 ([Google Codelabs][1])
* 🔐 **ターミナル実行が進まない**
  → Terminal Execution policyが“承認制”なら、承認してね（それが正しい動き）✅ ([Google Codelabs][1])
* 🌐 **ブラウザでJS実行の確認が頻繁**
  → Request reviewにしてると“ちゃんと聞いてくる”ので正常です🙆‍♂️ ([Google Codelabs][1])

---

## 次章への布石：FirebaseのAI支援、実はここに繋がる🤖🔥

この作業場ができると、いよいよ **Firebase×AI** が強くなります💪
たとえば **Gemini CLIのFirebase拡張**は、入れると **Firebase MCP server** を自動で入れてくれて、

* Firebase向けの“定型プロンプト（/コマンド）”が増える📚
* AIがFirebaseプロジェクトを操作できるツールが増える🛠️
* FirebaseドキュメントをAIが読みやすい形式で引ける📖
  …みたいな“加速装置”になります🚀 ([Firebase][2])

（このへんは第6章・第15〜16章でガッツリ触るよ👍）

---

次は **第6章：Gemini CLI** に行こう💻🤖✨
「ターミナルで聞きながら進む」ができると、学習スピードが一段上がるよ🏃‍♂️💨

[1]: https://codelabs.developers.google.com/getting-started-google-antigravity "Getting Started with Google Antigravity  |  Google Codelabs"
[2]: https://firebase.google.com/docs/ai-assistance/gcli-extension "Firebase extension for the Gemini CLI  |  Develop with AI assistance"
