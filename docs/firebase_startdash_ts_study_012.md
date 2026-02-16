# 第12章：Webアプリ登録：SDKの“名札”を作る🏷️🌐

この章でやることはシンプル！
Firebaseに「このWebアプリ、うちのプロジェクトの子ですよ〜」って登録して、**Web用の設定（firebaseConfig）**をもらいます🙌✨
これがないと、次章（SDK導入＆初期化）で「つながった！」ができません⚡

（※ 2026-02-15時点の公式手順ベースで構成しています）([Firebase][1])

---

## 今日のゴール🎯✨

* Firebase Consoleで**Webアプリを登録**できる✅
* **firebaseConfig（設定オブジェクト）をコピーして保管**できる✅
* 後から迷子にならずに**もう一度configを取り直せる**✅ ([Google ヘルプ][2])
* configの各項目を「だいたい何者か」説明できる✅ ([Firebase][3])

---

## 1) まずイメージをつかもう🧠🗺️

* **Firebaseプロジェクト**＝“建物”🏢
* **Webアプリ登録**＝“部屋の名札を作る”🏷️
* **firebaseConfig**＝“その名札に書かれた情報”🪪

登録すると、Firebase側が「このWebアプリ（appId）は、このプロジェクトに所属ね！」って覚えてくれます🙂
そして私たちは、その“名札情報（config）”をコードに貼って初期化して使います（次章でやるよ）([Firebase][1])

---

## 2) 手を動かす：Firebase ConsoleでWebアプリを追加🏗️🌐

## 手順（迷わない版）🧭

1. Firebase Consoleで対象プロジェクトを開く👀
2. 画面中央あたりの「アプリを追加」的なところで、**Web（</>）アイコン**を押す🌐

   * すでに何かアプリが登録済みなら「Add app（アプリを追加）」からWebを選べます🧩([Firebase][1])
3. **アプリのニックネーム**を入力（例：`myapp-web-dev`）✍️

   * これは**自分用のラベル**で、動作には直接関係しないよ🙂
4. 「Register app（登録）」を押す✅
5. すると次の画面で、**Firebase SDKの導入手順**といっしょに **firebaseConfig（設定オブジェクト）** が出てくる✨([Firebase][1])
6. その場で **firebaseConfigをコピー**して、いったん安全に保管📝🔐
7. 「Continue to console」的なボタンでコンソールへ戻る🏁

> 💡この章は「登録＆config取得」までがゴール！
> npm install や initializeApp は次章でやるよ⚡

---

## 3) configを“なくさない”保管ルール🗃️🧯

最低限、これだけやればOK👌

* ① **コピペしたfirebaseConfigをメモ帳に保存**（まず最優先）📝
* ② “どのプロジェクト用か”がわかるように **プロジェクトIDも一緒にメモ**🧷
* ③ 後から取り直せるルートも覚える（次の章で説明）🧭

Firebase公式も「登録するとconfigオブジェクトが手に入る」前提で説明してます([Firebase][1])
そして、**configを手でいじるのは基本おすすめしない**（必要なキーが欠けると不具合の元！）とも書かれてます([Firebase][3])

---

## 4) いつでも取り直せる：config再取得の最短ルート🧭🔁

「どこに置いたか忘れた😇」は、あるあるです。大丈夫！

**Firebase Console → 歯車（Project settings）→ General → Your apps → 対象のWebアプリ → Firebase SDK snippet → Config**
ここで **いつでもconfigを再表示してコピー**できます✅([Google ヘルプ][2])

---

## 5) firebaseConfigの中身を“超ざっくり”理解しよう🧩✨

コンソールで出てくるのは、だいたいこんな形👇（値はダミーです）

```ts
export const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT.appspot.com",
  messagingSenderId: "012345678901",
  appId: "1:012345678901:web:abcdef1234567890",
  measurementId: "G-XXXXXXX", // 出ないこともある（Analytics有効時など）
  // databaseURL: "https://YOUR_PROJECT.firebaseio.com", // RTDB使うとき等
} as const;
```

それぞれの意味はこんな感じ🙂👇

* **apiKey**：Firebase/Googleの各サービスにリクエストを送るときの“宛先判定に使われるキー”🔑

  * “完全な秘密鍵”ではないけど、**運用上は雑にばらまかない**が安心🙆‍♂️
  * Firebase公式でもAPIキーの扱い・ベストプラクティスを説明しています([Firebase][4])
* **authDomain**：主に認証（Auth）のためのドメイン🌐

  * 認証のリダイレクトなどで関係してくることがあります([Firebase][5])
* **projectId**：プロジェクトの“本名”みたいなもの🪪（Firestore等で超重要）([Firebase][3])
* **storageBucket**：Storage（ファイル置き場）のバケット名📦
* **messagingSenderId**：主にFCM（通知）系の識別子📣
* **appId**：この“アプリ登録”に対して発行される固有ID🆔（アプリを区別する本体）([Firebase][3])
* **measurementId**：Analyticsを使う場合に出てくるID📊（出ないなら無理に探さなくてOK）([Firebase][6])
* **databaseURL**（出る/出ない）：Realtime Databaseを使う時に必要になることがあるURL🏊‍♂️

  * 公式でも「Realtime Database URLを指定してね」と書かれています([Firebase][7])

> ✅超大事：**configは“魔法の秘密鍵セット”ではなく、プロジェクトとアプリを紐づけるための設定**って感覚がちょうどいいです🙂
> そして、公式は「特に apiKey / projectId / appID（appId） は壊さないでね」って注意してます([Firebase][3])

---

## 6) 🤖AIと一緒に爆速理解：Gemini CLI / Antigravity の使いどころ💬⚡

この章は「理解」と「迷子回避」が勝ちなので、AIがめちゃ役立ちます✨

## そのままコピペでOKな質問例🧠📝

* 「firebaseConfigの各キー（apiKey/authDomain/projectId/appId…）を、初心者向けに1行ずつ説明して」
* 「Firebase ConsoleでWebアプリのconfigを“後から”取り直す最短手順を、メニュー名つきで教えて」([Google ヘルプ][2])
* 「measurementIdが出ないのは何が原因？ 出ないと困るケースは？」([Firebase][6])
* 「Realtime Databaseを使うとき databaseURL が必要になる理由と、URLの見つけ方は？」([Firebase][7])

## MCPの話（“最新情報を取り続ける”最強ルート）🛠️🔥

* **Firebase MCP server**は、**Antigravity / Gemini CLI などのMCPクライアントからFirebase作業を支援**できる、と公式が明記してます([Firebase][8])
* Antigravity側での入れ方（MCP Servers → Firebase → Install）も公式ドキュメントに手順があります([Firebase][9])
* さらに、**Google Developer Knowledge MCP server**みたいに「公式ドキュメントを検索して最新根拠を返す」系もあります([Google for Developers][10])

> 🔥コツ：**「画面のどこ？」「用語の意味は？」をAIに投げて、答えを3行に要約させる**と迷子が激減します🙂✨

---

## 7) よくある詰まりポイント集😵‍💫🧯

* **Web（</>）アイコンが見当たらない**
  → すでに何かアプリがある可能性大！「Add app」から選ぶ流れになります([Firebase][1])
* **違うプロジェクトで登録してた😇**
  → あるある！コンソール上部のプロジェクト名/IDを必ずチェック👀
* **measurementIdが無い！失敗？**
  → 失敗じゃないことが多いよ。Analyticsを使う時に出るものなので、出なければ「今は未使用」くらいでOK🙂([Firebase][6])
* **configをちょっと編集して貼ったら動かない**
  → 公式が「手編集はおすすめしない」って注意してます。まずはコンソールのスニペットをそのまま使うのが安全✅([Firebase][3])

---

## 8) ミニ課題🎒✨

## ミニ課題A（必須）📝

コピーしたfirebaseConfigを見ながら、各項目を1行で説明してみよう！

* apiKey：
* authDomain：
* projectId：
* storageBucket：
* messagingSenderId：
* appId：
* measurementId（あれば）：

わからなければAIに聞いてOK🤖💡（**“1行で！”**って指定すると読みやすい）

## ミニ課題B（余力があれば）🧪

同じプロジェクトに、もう1つWebアプリを登録してみて👇

* 「nickname」と「appId」が変わるのを確認👀✨
  （※あとで“dev/prod分け”を理解するのにめちゃ効きます）

---

## 9) チェック✅（合格ライン）

* ✅ Webアプリ登録ができた
* ✅ firebaseConfigを保管した
* ✅ configの再取得ルートを言える（Project settings → General → Your apps → Config）([Google ヘルプ][2])
* ✅ appIdが「アプリ固有のID」だと分かった([Firebase][3])

---

## 次章の予告🔜⚡

次はついに、SDKを入れて `initializeApp` して、画面に「繋がった！」を出します🌱✨
第13章で一気に気持ちよくいこう〜🚀

[1]: https://firebase.google.com/docs/web/setup?utm_source=chatgpt.com "Add Firebase to your JavaScript project"
[2]: https://support.google.com/firebase/answer/7015592?hl=en&utm_source=chatgpt.com "Download Firebase config file or object"
[3]: https://firebase.google.com/docs/web/learn-more?utm_source=chatgpt.com "Understand Firebase for web - Google"
[4]: https://firebase.google.com/docs/projects/api-keys?utm_source=chatgpt.com "Learn about using and managing API keys for Firebase - Google"
[5]: https://firebase.google.com/docs/auth/web/redirect-best-practices?utm_source=chatgpt.com "Best practices for using signInWithRedirect on browsers that ..."
[6]: https://firebase.google.com/docs/analytics/get-started?utm_source=chatgpt.com "Get started with Google Analytics - Firebase"
[7]: https://firebase.google.com/docs/database/web/start?utm_source=chatgpt.com "Installation & Setup in JavaScript | Firebase Realtime Database"
[8]: https://firebase.google.com/docs/ai-assistance/mcp-server?utm_source=chatgpt.com "Firebase MCP server | Develop with AI assistance - Google"
[9]: https://firebase.google.com/docs/crashlytics/ai-assistance-mcp?utm_source=chatgpt.com "AI assistance for Crashlytics via MCP - Firebase"
[10]: https://developers.google.com/knowledge/mcp?utm_source=chatgpt.com "Connect to the Developer Knowledge MCP server"
