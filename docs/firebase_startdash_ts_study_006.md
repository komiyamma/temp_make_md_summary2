# 第06章：Gemini CLIの超入門：ターミナルで“聞きながら進む”💻🤖

この章では、ターミナルから **Gemini CLI** を使って、
「調べる→要約→次の一手→コードたたき台→詰まり解消」までを一気に体験します🚀✨
（あとでFirebaseを触る章が来ても、ここができてると爆速になります🔥）

---

## この章のゴール🎯（できたら勝ち✅）

* ターミナルで `gemini` を起動して、会話できる🤖
* 1発質問（ワンショット）で答えを引き出せる💬
* **秘密を守りつつ**（.envなど）プロジェクトを見せて相談できる🔐
* FirebaseのWeb初期化の「最小コード」を“質問で”引き出せる🧪

---

## 1) Gemini CLIって何？どこが便利？🧠✨

Gemini CLIは、ターミナルの中で動くAIエージェントです🤖
プロジェクトのファイルを読んでくれて、説明・提案・修正案まで出せます（もちろん勝手に壊さないための仕組みもあります）🛡️
さらに、必要に応じて「検索」や「ツール連携（MCPなど）」もできる設計です。([GitHub][1])

---

## 2) セットアップ（最短）🚀

## A. すぐ使う（ターミナルで起動）🕹️

Gemini CLIの基本は「起動してログイン」です。

```bash
gemini
```

初回は「どう認証する？」が出るので、普通は **Googleアカウントでログイン** を選びます。([Gemini CLI][2])

## B. もしインストールが必要なら（npmで一発）📦

標準のインストール方法はこれです。([Gemini CLI][2])

```bash
npm install -g @google/gemini-cli
```

### ここだけ注意⚠️（Windowsまわり）

Gemini CLIの推奨要件として **Node.js 20+**、Windowsは **Windows 11（24H2以降）** が挙げられています。([Gemini CLI][3])
（「Node / npm がまだよく分からない😵」でも大丈夫。次の章でちゃんと固めます👍）

---

## 3) 使い方の基本：まずはこの3パターンだけ覚える🧩✨

## ① ふつうに会話（いちばん使う）💬

```bash
gemini
```

起動したら、そのまま日本語でOK🙆‍♂️
「これやりたい」「このエラー何？」って聞くだけで進みます。

## ② 1発質問（ワンショット）⚡

スクリプトみたいに「質問→回答だけ欲しい」ならこれ。([GitHub][1])

```bash
gemini -p "このプロジェクトの次の一手を3つ、箇条書きで"
```

## ③ 複数フォルダも見せたい（ちょい応用）📁

モノレポや別フォルダも含めたいとき。([GitHub][1])

```bash
gemini --include-directories ../docs,../shared
```

---

## 4) 「聞き方」テンプレ3つ💬✨（これだけで強い）

Gemini CLIで詰まらないコツは、質問に“材料”を添えること🍳
おすすめテンプレはこれ👇

## テンプレA：最小で動く形を出してもらう🚀

* **目的**：何をしたい？
* **現状**：何がある？
* **制約**：使う技術、やりたくないこと
* **出力**：欲しい形式（ファイル名、手順、コード）

例👇

```text
目的：FirebaseのWeb初期化を最小で通したい
現状：Vite + React + TypeScript の構成
制約：modular SDKで、configはViteの環境変数から読む
出力：firebase.tsの例 + 置き場所 + importする場所
```

## テンプレB：エラー解読（最短で直す）🧯

```text
このエラーの原因候補を3つ、確認手順つきで。
最短の修正案を1つ、コード差分イメージで。
（エラー全文ここ↓）
```

## テンプレC：次の一手（迷子防止）🧭

```text
今の状況から、次にやることを優先度順に5つ。
各ステップの「完了条件」もつけて。
```

---

## 5) プロジェクトに“前提”を覚えさせる（超重要）🧠🧷

ここができると、Geminiが**毎回いい回答**を出しやすくなります✨

## 5-1. GEMINI.md（プロジェクトのルールブック）📘

Gemini CLIは **GEMINI.md** をプロジェクト文脈として使えます。([Gemini CLI][4])
例：プロジェクト直下に置くやつ👇

```text
## GEMINI.md（例）
- このプロジェクトは Vite + React + TypeScript
- パッケージ管理は npm
- Firebaseは modular SDK を使う（initializeApp など）
- 返答は「手順→コード→確認方法」の順で
- 変更は必ず「どのファイルをどう変えるか」を先に説明してから
```

## 5-2. .geminiignore（見せたくないものを遮断）🔐

Gemini CLIには **.geminiignore** があり、AIに読ませないファイルを指定できます。([Gemini CLI][5])
最低限これを入れておくのが安全です👇

```text
## .geminiignore（例）
.env
.env.*
**/*.pem
**/*.key
node_modules
dist
```

> ここ、めちゃ大事：**APIキーや認証情報は絶対にAIに渡さない**🙅‍♂️
> まず ignore で守る → それでも貼らない、が最強です🛡️

## 5-3. “実行できる場所”をコントロールする（安全装置）🧯

Gemini CLIには、フォルダを「信頼する/しない」みたいな安全管理の考え方もあります。([Gemini CLI][4])
（いきなり深掘りしなくてOK。**勝手に危険な操作を通さない**ための仕組みがある、くらいで👌）

---

## 6) ハンズオン：FirebaseのWeb初期化「最小コード」を“聞いて”作る🧪🔥

ここがこの章のメインイベント🎆
「自分で全部調べる」のではなく、**質問で最小解**を取りに行きます。

## Step 1：まずGeminiに“やりたいこと”を投げる💬

ワンショットでOK👇（答えをそのままメモしてね📝）

```bash
gemini -p "Vite + React + TypeScript。Firebase modular SDKでinitializeAppする最小例を教えて。configはViteの環境変数(import.meta.env)から読む形で。firebase.tsの例と配置場所、どこでimportするかも。"
```

`-p` のようなワンショット実行は、CLIでも案内されている基本の使い方です。([GitHub][1])

## Step 2：返ってきた答えを“採用しやすい形”に整える✂️

だいたいこういう形に落ち着けばOKです（例）👇

```ts
// src/lib/firebase.ts（例）
import { initializeApp } from "firebase/app";

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

export const firebaseApp = initializeApp(firebaseConfig);
```

> まだFirebase Console側の設定やconfig取得は後の章でやるので、ここでは
> **「どんなファイルが必要になりそうか」**を掴めればOK🙆‍♂️✨

## Step 3：詰まったら“次の質問”で前進🏃‍♂️💨

例👇

* 「この構成で `.env.local` はどう書くのが良い？」
* 「dev/prodで差し替える設計にするなら、今のうち何を決める？」
* 「将来AI Logicを入れるなら、今の構成でどこに置くのが自然？」

---

## 7) FirebaseのAIも絡める：AI Logicを“設計だけ先に”やってみる🤖🧠

Firebaseには **Firebase AI Logic** があり、Gemini/Imagenモデルを使ったAI機能をアプリに組み込みやすくする位置づけです。([Firebase][6])
この章では実装はまだ早いので、Gemini CLIに「設計案だけ」作らせるのが超おすすめ👍

例えば👇

```bash
gemini -p "ログイン前トップ画面に『一言キャッチコピー生成』を付けたい。Firebase AI Logicを前提に、UI構成（ボタン/入力/結果表示）と、クライアント側で気をつける点（セキュリティ/コスト）を箇条書きで。"
```

こうしておくと、あとで本当にAI機能を入れる章で「迷子」になりにくいです🧭✨

---

## 8) よくある詰まりポイント集🧯（ここだけ見れば復帰できる）

## ログインがうまくいかない😵

Gemini CLIは認証方法が複数あります（Googleログイン / API key / Vertex AIなど）。アカウント種別によってはCloudプロジェクト設定が必要になることもあります。([Gemini CLI][2])
→ うまくいかない時は、**「どの認証を選んだか」**と**エラー全文**をGeminiに投げると早いです💨

## 秘密情報が混ざりそうで怖い😨

`.geminiignore` をまず作る（.env系は全部ブロック）🔐 ([Gemini CLI][5])
それでも、**キーやトークンは貼らない**🙅‍♂️（最強ルール）

---

## 9) ミニ課題🎒✨（10分でOK）

## ミニ課題A：スニペを3つ作る📌

メモ帳でもOK。下の3つを自分用に保存📝

1. エラー解読テンプレ
2. 最小実装テンプレ
3. 次の一手テンプレ

## ミニ課題B：GEMINI.md + .geminiignore を置く🧷

* GEMINI.md：プロジェクトの前提を5行で
* .geminiignore：`.env*` を確実に遮断

## ミニ課題C：ワンショットで「次の一手」を出す🧭

```bash
gemini -p "今の段階（Vite + React + TSが動く）から、Firebaseにつなげる次の一手を3つ。完了条件つきで。"
```

---

## 10) チェック✅（3つ答えられたらOK）

* `gemini` と `gemini -p` の違いを説明できる？🤔
* GEMINI.md と .geminiignore は何のため？🔐
* 「目的＋現状＋制約＋出力」を入れて質問できる？💬

---

次の章（Node.jsとnpm）に進むと、Gemini CLIのインストールや依存周りがさらにスムーズになります📦✨
もし今この章で「ここで詰まった！」があれば、**エラー全文をそのまま貼って**ください🧯💨（秘密情報だけは伏せてね🔐）

[1]: https://github.com/google-gemini/gemini-cli "GitHub - google-gemini/gemini-cli: An open-source AI agent that brings the power of Gemini directly into your terminal."
[2]: https://geminicli.com/docs/get-started/ "Get started with Gemini CLI | Gemini CLI"
[3]: https://geminicli.com/docs/get-started/installation/ "Gemini CLI installation, execution, and releases | Gemini CLI"
[4]: https://geminicli.com/docs/cli/trusted-folders/ "Trusted Folders | Gemini CLI"
[5]: https://geminicli.com/docs/cli/gemini-ignore/ "Ignoring files | Gemini CLI"
[6]: https://firebase.google.com/docs/ai-logic "Gemini API using Firebase AI Logic  |  Firebase AI Logic"
