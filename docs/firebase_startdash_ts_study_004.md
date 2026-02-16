# 第04章：🤖AIと一緒に学ぶ：聞き方テンプレ（超初心者向け）💬✨

この章のゴールはシンプルです👇
**AIの回答を「読める説明」じゃなくて「そのまま手順として実行できる形」**で引き出せるようになること！🚀✨

---

## 1) まず覚える！AIに通じる「黄金5点セット」📌🧠

AIに質問するとき、これだけ入れると一気に精度が上がります👇

1. **目的**：何を達成したい？🎯
2. **現状**：いま何ができてる？どこで止まってる？🧱
3. **制約**：使う技術/やりたい範囲/やらないこと🚧
4. **期待する出力**：箇条書き？コード？ファイル構成？✅
5. **材料**：エラー全文、ログ、該当コード（必要最小限）🧾

これ、**Antigravityみたいなエージェント型開発環境**でもめちゃ効きます（エージェントが「何をすべきか」を迷わない）🛸✨ ([Google Codelabs][1])

---

## 2) そのまま使える！質問テンプレ集（コピペOK）🧩📋

### A. 「最小で動かしたい」テンプレ（最強）🔥

```text
目的：Firebaseを使った最小のWebアプリを“起動確認”まで通したい
現状：React+TSの画面は表示できる（Viteでdev起動OK）
制約：機能は「Firebase初期化だけ」でOK（Auth/DBはまだ触らない）
期待する出力：
- 手順を番号つきで
- 作るファイル名と中身（最小）
- つまづきポイント3つ
材料：package.jsonの主要スクリプト / エラーが出たら全文
```

### B. 「エラー解決」テンプレ（詰まったらこれ）🧯

```text
目的：このエラーを解消して先に進みたい
現状：何をした直後に起きたか（例：initializeAppを書いてnpm run dev）
制約：変更は最小。理由も一緒に説明してほしい
期待する出力：
1) 原因候補を優先度順に
2) 1つずつ確認する手順
3) 修正パッチ（差分形式が理想）
材料：
- エラー全文（コピペ）
- 該当ファイル（例：firebase.ts / App.tsx）
- SDKのimport部分
```

### C. 「設計の相談」テンプレ（迷子防止🧭）

```text
目的：Firebase導入の“置き場所”を決めたい（config/初期化/呼び出し）
現状：Vite + React + TS でTopページはある
制約：初心者でも迷子にならない構成が良い
期待する出力：
- 推奨フォルダ構成
- firebase.ts の役割
- 将来Auth/Firestoreを足す時の拡張方針
```

### D. 「公式ドキュメント準拠で」テンプレ（最新追従🔎）

```text
目的：最新の公式ドキュメントに沿った手順にしたい
制約：推測で書かず、公式ページの根拠を前提にしてほしい
期待する出力：
- いま推奨される方法（理由）
- 以前のやり方と違う点（あれば）
- 注意点（課金/セキュリティ）
```

> コツ：**「推測で書かず、公式に沿って」**を入れるだけで、古い例を踏みにくくなります👍✨

---

## 3) Antigravity流：AIに“役割分担”させると爆速🏎️💨

Antigravityは「エージェントが計画して、コード書いて、調べてくれる」方向の作りです🛸
なので、**1回の質問で全部**より、**役割で分ける**のが勝ち筋です！ ([Google Codelabs][1])

✅おすすめ分担（超カンタン）

* 🕵️‍♂️ **調査役**：公式の最短ルートを調べる
* 🧑‍💻 **実装役**：作るファイルとコードを出す
* 🧪 **検証役**：起動確認ポイントと詰まりポイントを列挙する

調査役への投げ方例👇

```text
あなたは調査役。FirebaseのWeb最小初期化の“いま推奨のやり方”を、
手順だけ5ステップでまとめて。曖昧なら「不明」と書いてOK。
```

---

## 4) Gemini CLI流：ターミナルで“聞きながら進む”💻🤖

Gemini CLIは、**npmで入れる / npxで即実行**みたいな導入が用意されています📦✨ ([Gemini CLI][2])
さらに、MCPサーバー連携など「外部ツールとつなぐ」思想も強めです🔌 ([Gemini CLI][3])

よく使う形だけ置いとくね👇

```bash
## まず試す（インストール不要のやつ）
npx @google/gemini-cli

## ずっと使うなら（グローバル導入）
npm install -g @google/gemini-cli

## 起動（環境によってコマンドが案内される）
gemini
```

> ちなみに、Google Cloud側の案内でも「Cloud Shellでは追加セットアップなしで使える」系の説明があります（環境によって体験が違う）☁️ ([Google Cloud Documentation][4])

---

## 5) FirebaseのAI機能も“学習の味方”にする🤝🤖

ここ超大事！「AIは外部ツール」だけじゃなく、**Firebase側にもAI導線**が増えてます🔥

* **Gemini in Firebase**：FirebaseのUIやツール上で、開発を助ける協力型アシスタント💬✨ ([Firebase][5])
* **Firebase AI Logic**：アプリから **Gemini / Imagen** を使うための仕組み（クライアントSDKで組み込みやすい）🧠🖼️ ([Firebase][6])
* **Firebase MCP server**：AI開発ツールに「Firebase操作」を手伝わせるための仕組み（プロジェクト操作や設定取得など）🛠️ ([Firebase][7])

この章では「学び方」が主役だから、使い分けはこんな感じでOK👇

* 🧑‍🎓 **学習・詰まり解消**：Gemini in Firebase / Gemini CLI / Antigravityのエージェント
* 🧩 **アプリにAI機能を実装**：Firebase AI Logic（次の章以降で育てる🌱）

---

## 6) ハンズオン：AIに「最小アプリ完成の手順書」を作らせよう🚀📘

やることはこれだけ👇（10〜20分コース）

### 手順①：AIへ依頼（まずは“手順書”だけ作らせる）

```text
目的：React+TSアプリにFirebaseを導入して「初期化できた」まで確認したい
現状：Viteでnpm run devは動く。画面も表示できる
制約：この章ではAuth/Firestoreは触らない。初期化だけでOK
期待する出力：
- 5〜8ステップの手順
- 作るファイル名（firebase.tsなど）と最小コード
- 失敗しやすい点と確認方法
```

### 手順②：AIの回答を“実行用ToDo”に変換（これが超重要✅）

AIの回答を見たら、こう変換してね👇

* 「説明」→ ✂️削る
* 「やること」→ ✅チェックリスト化
* 「コード」→ 📁ファイル名とセットにする

### 手順③：詰まったら“追加質問”を投げる（1回で終わらせない）

```text
今の手順のステップ3で止まった。状況はこう：
- 何をした：〇〇
- 出たエラー：〇〇（全文）
次の一手を「1つだけ」指示して。成功したら次を聞く。
```

---

## 7) ミニ課題：自分専用「質問スニペ集」を作る📝✨

Windowsのメモ帳でもOK！`ai-prompts.md` みたいなファイルを作って、ここまでのテンプレを貼るだけ👍
最後に、あなた用に1個だけ追記👇

```text
（自分のアプリ案）：
目的：〇〇アプリを作りたい
優先：まずログイン前トップ → 次にログイン → 次に保存
今日やる範囲：〇〇だけ
```

---

## 8) チェック（できたら合格✅🎉）

* AIに投げる文に **目的/現状/制約/期待する出力** が入ってる？📌
* AIの回答を **手順（ToDo）に変換** できた？✅
* 詰まったら **「次の一手を1つだけ」** で聞けた？🧯
* FirebaseのAI導線（Gemini in Firebase / AI Logic / MCP）を「存在だけ」把握した？🤖✨ ([Firebase][5])

---

次の章で「AntigravityのMission Controlに慣れる🛸🕹️」へ行くと、ここで作ったテンプレがそのまま武器になります！💪😆

[1]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[2]: https://geminicli.com/docs/get-started/installation/?utm_source=chatgpt.com "Gemini CLI installation, execution, and releases"
[3]: https://geminicli.com/docs/?utm_source=chatgpt.com "Gemini CLI documentation"
[4]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[5]: https://firebase.google.com/docs/ai-assistance/gemini-in-firebase?utm_source=chatgpt.com "Gemini in Firebase - Google"
[6]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[7]: https://firebase.google.com/docs/ai-assistance/mcp-server?utm_source=chatgpt.com "Firebase MCP server | Develop with AI assistance - Google"
