# 第15章：🤖Firebase MCPサーバー：AIエージェントにFirebase操作を手伝わせる🛠️🧠

この章はひとことで言うと、**「AIに“Firebaseの操作ボタン”を持たせる」**回です👀✨
ただし、**勝手に操作される**んじゃなくて、**あなたの許可でツール実行**されるのがポイントです🔐👍 ([Firebase][1])

---

## ✅ この章のゴール（10〜20分）

* Antigravity か Gemini CLI に **Firebase MCPサーバー**をつないでみる🔌
* AIに「プロジェクトの場所」「SDK設定」などを **案内・取得**させる🧭🤖
* **安全に使うコツ**（許可の出し方・危ない依頼の避け方）を掴む🧯

---

## 1) まず読む：MCPってなに？（超ざっくり）🧩

## MCPは「AIと外部ツールの共通プラグ」🔌

* **MCPサーバー**：できること（ツール）を提供する側
* **MCPクライアント**：AI側（Antigravity / Gemini CLI など）
* FirebaseのMCPサーバーを入れると、AIがFirebaseに対して

  * プロジェクト管理
  * Authユーザー管理
  * Firestore操作
  * ルール理解
  * FCM送信
    …みたいな作業を“ツールとして”扱えるようになります🧰✨ ([Firebase][1])

## 重要：権限は「Firebase CLIのログイン権限」が使われる🪪

Firebase MCPサーバーがツール実行するときは、**その環境の Firebase CLI を認可している資格情報**（ログイン済みユーザー or ADC）で動きます。
つまり **あなたの権限で動く**ので、安全に扱うのが超大事です⚠️ ([Firebase][1])

---

## 2) MCPサーバーで何が“楽”になる？🚀

Firebase公式の説明だと、MCPサーバーでAIは例えばこんなことを手伝えます👇 ([Firebase][1])

* Firebaseプロジェクトの作成・管理🏗️
* Authenticationユーザーの管理👤
* Firestore / Data Connect のデータ作業🗂️
* ルール（Firestore/Storage）理解＆チェック🔒
* FCMでメッセージ送信📣

さらに、Firebaseブログでは「**30以上のツール**があり、プロジェクトに応じて関連ツールを自動で有効化する」ことも説明されています🧰✨ ([The Firebase Blog][2])

---

## 3) 手を動かす：Antigravityで入れる（いちばん簡単）🛸✨

## ✅ 手順（UIでOK）

1. Antigravity の **Agent** ペインで「…（more）」を開く
2. **MCP Servers** を選ぶ
3. **Firebase → Install** を押す🔌

これで Antigravity が自動的に `mcp_config.json` を更新してくれます📝 ([Firebase][1])

中身はだいたいこんな感じ👇（参考：表示は “View raw config” から見れます） ([Firebase][1])

```json
{
  "mcpServers": {
    "firebase-mcp-server": {
      "command": "npx",
      "args": ["-y", "firebase-tools@latest", "mcp"]
    }
  }
}
```

> 💡昔の記事だと `experimental:mcp` って書かれてることがあるけど、**今の公式手順は `mcp`** になってます（ここ大事）📌 ([Firebase][1])

---

## 4) 手を動かす：WindowsでGemini CLIに入れる（おすすめは拡張）💻🤖

## ✅ いちばん楽：Firebase拡張を入れる

Firebase公式のおすすめは **Gemini CLI に Firebase拡張をインストール**する方法です。
これを入れると **MCPサーバー設定も自動**で入ります🔧✨ ([Firebase][1])

PowerShell など「普通のターミナル」で👇（※Gemini CLIのプロンプト内じゃなくて“外”で実行） ([Firebase][3])

```bash
gemini extensions install https://github.com/gemini-cli-extensions/firebase/
```

* 拡張はよく更新されるので、たまにアップデートも👍 ([Firebase][3])

```bash
gemini extensions update firebase
```

## ✨拡張を入れるメリット（ここが強い）

Firebase拡張は👇をまとめてやってくれます🧠✨ ([Firebase][3])

* MCPサーバー自動設定🔌
* Firebase用“文脈ファイル（ルールファイル）”を追加して回答精度アップ📚
* **事前に用意されたスラッシュコマンド**が使える（例：`/firebase:init`）⌨️

しかも `/firebase:init` は「バックエンド設定」だけじゃなく、**AI機能の追加（Firebase AI Logic）**のセットアップ導線もあります🤖🔥 ([Firebase][3])

---

## 5) まず試す：AIに“安全なお願い”をしてみよう🧪🧸

ここでは「破壊しにくい」「お金が動きにくい」お願いから行きます✅

## ✅ Antigravity / Gemini CLI 共通：最初の3つ（安全寄り）

* 「**今のFirebaseプロジェクト一覧を出して**」📋
* 「**このプロジェクトの設定（Web SDK config）がどこにあるか案内して**」🧭
* 「**“今やるべき次の一手”を3つに絞って**」🪜

## ✅ Gemini CLIなら：スラッシュコマンドで導線が速い⚡

* `/firebase:init`（Firebaseサービスの初期セットアップ）([Firebase][1])
* `/firebase:deploy`（デプロイの案内＆実行プラン）([Firebase][3])

---

## 6) 安全運転のコツ：許可の出し方（ここ超重要）🧯🔐

Firebase MCPは「ツール実行」ができる分、**許可の出し方**で事故が減ります🙆‍♂️

## ✅ まず覚える：MCPには3種類ある

Firebase MCPは大きく👇の3つを提供します📦 ([Firebase][1])

* **Prompts**：用意された手順書（スラッシュコマンド系）🗒️
* **Tools**：AIが必要に応じて呼ぶ“操作ボタン”（あなたの承認付き）🛠️
* **Resources**：ドキュメント等の参照情報📚

## ✅ 事故りにくいルール（初心者の鉄板）🥋

* ✅ **読むだけ**（一覧取得、設定の案内、ルールの説明）はOK🙆
* 🟡 **作る/変更する**（Firestore作成、ルール更新、デプロイ）は毎回「内容を読んでから許可」👀
* ❌ **課金・削除・権限まわり**は、慣れるまでAIに触らせない（提案だけさせる）🙅‍♂️💸

## ✅ 「ツール露出を減らす」もできる（上級だけど効果大）🎛️

MCP起動コマンドに `--only` を付けて、必要な機能グループだけに絞れます✂️
（例：auth と firestore だけ、など） ([Firebase][1])

---

## 7) よくある詰まりポイント＆対処🧰😵‍💫

## ❓AIがツールを使ってくれない

* **新しいチャットを開始**すると、最新のツール設定を拾うことがある✅ ([Firebase][4])
* それでもダメなら「このツールを使って」と**ツール名を指定**して頼む（例：SDK config取得ツール名など）🎯 ([Firebase][4])

## ❓MCPサーバーが接続失敗する

* Firebase Studio系なら「ログを見る」「環境をリビルド」が効くことがある🔁 ([Firebase][4])
  （Antigravityでも“再インストール / 再起動 / 設定確認”の発想は同じです👍）

## ❓認証エラーっぽい

* MCPはFirebase CLIの認証を使うので、必要なら CLI 側でログインします（例）🔑 ([The Firebase Blog][2])

```bash
npx -y firebase-tools@latest login
```

---

## 8) ミニ課題（5分）🎯✨

## ✅ お題：AIに「迷子防止ナビ」を作らせる🧭🤖

1. MCP（Antigravity or Gemini CLI拡張）を入れる🔌
2. AIにこう聞く👇

   * 「このプロジェクトで、**WebアプリのSDK config**はどこで見れる？最短ルートで案内して」
   * 「**いまの段階（最小アプリ）**で、次にやることを3つだけ提案して」

## 📸 提出物（自分用でOK）

* AIが出した「最短ルート」をメモ📝
* “次の3つ”のうち、今日やるのに丸⭕を付ける

---

## 9) チェック（理解できたらOK）✅🧠

* MCPは「AIに外部ツールをつなぐ仕組み」って説明できる？🔌
* Firebase MCPサーバーは「Firebase CLIの権限で動く」って分かってる？🪪 ([Firebase][1])
* `/firebase:init` が「Firebaseの初期セットアップ導線」って分かる？⌨️ ([Firebase][1])
* “変更系”は中身を読んでから許可する、ができそう？🧯

---

次の章（第16章）では、**Gemini CLI×Firebase拡張**を使って「困ったら即レスで前に進む」型を作っていきます🏃‍♂️💨
第15章で入れたMCPが、そのまま“相談→実行”の土台になります🤝✨

[1]: https://firebase.google.com/docs/ai-assistance/mcp-server "Firebase MCP server  |  Develop with AI assistance"
[2]: https://firebase.blog/posts/2025/05/firebase-mcp-server/ "Firebase MCP Server"
[3]: https://firebase.google.com/docs/ai-assistance/gcli-extension "Firebase extension for the Gemini CLI  |  Develop with AI assistance"
[4]: https://firebase.google.com/docs/studio/mcp-servers "Connect to Model Context Protocol (MCP) servers  |  Firebase Studio"
