# 第11章：Firebaseプロジェクト作成：最初の1回を最短で🌋🚀

この章でやることはシンプルです👇
**「Firebase Consoleで新規プロジェクトを作って、IDを控えて、迷子にならない状態にする」**だけ！✨

---

## 🎯 この章のゴール（できたら勝ち！）✅

* Consoleで **新規プロジェクトを作成**できる🏗️
* **プロジェクトID（超重要）**を控えられる📝
* 「今どのプロジェクト？」が即答できる🧭
* ついでに **AI（Gemini in Firebase / Gemini CLI）**で迷子回避の型を作る🤖✨

---

## 1) まず“ここだけ”知っとく（最短で理解🧠⚡）

## ✅ プロジェクト名 / プロジェクトID / プロジェクト番号の違い

* **プロジェクト名**：人間向けの表示名（あとで変えてもOKなことが多い）🙂
* **プロジェクトID**：世界で一意のID。**あとから変更できない**ので、ここが一番大事🔥 ([Firebase][1])
* **プロジェクト番号**：自動採番（主に裏側で使う）🔢

> 迷ったら：**プロジェクトIDは“ドメイン名”みたいなもの**だと思ってOKです🌐✨（後で変えられないやつ）

## ✅ Google Analyticsは「最初にON」か「後でON」か

作成フローで **Google Analytics を有効化**できるし、あとで **Project settings → Integrations**から有効化もできます📈 ([Firebase][2])
（ただし、後でONにするより、最初からONのほうが迷いが少ないことが多いです🙂）

## ✅ 料金でビビりすぎなくてOK（でも事故は防ぐ）

最初は無料枠（Spark）で始められます。クレカが必須じゃない範囲で動かせます💸🧯 ([Firebase][3])
ただし、後で使う機能によっては課金プランが必要になるので、**「どこで課金が発生するか」を早めに把握**しておくのが安全です⚠️

---

## 2) 手を動かす：Consoleでプロジェクト作成（最短ルート🚀）

## Step 1：新規作成に入る🧭

1. Firebase Console を開く
2. **「プロジェクトを追加（Add project）」** を押す➕

## Step 2：プロジェクト名を決める🏷️

* ここは表示名なので気楽でOK🙂
* 例：`myapp-dev` / `myapp-prod` みたいに “環境が分かる” と後で幸せ🧠✨

## Step 3：プロジェクトIDを（できれば）整える🧨

作成途中で **プロジェクトIDを編集できる画面**が出ます。ここが最重要🔥
**プロジェクトIDは後から変更できません** ([Firebase][1])

プロジェクトIDの命名ルールは（Google Cloud側の）制約があり、だいたい

* 小文字・数字・ハイフン
* 文字数制限あり
  みたいな感じです📌 ([Google Cloud Documentation][4])

**おすすめの考え方**👇

* できるだけ短く
* 意味が分かる（例：`sengoku-notes-2026`）
* 会社/個人で被りそうなら、末尾に短い接尾辞（`-jp` `-dev`）を足す

## Step 4：Google Analytics をどうする？📈

作成フロー中に

* **Analytics を有効化** → 既存アカウントを選ぶ / 新規作る
  が出ます。 ([Firebase][2])

後で有効化も可能です（Project settings → Integrations）🧩 ([Firebase][2])

> 迷う人向けの雑ルール：
> **「あとで分析とか改善やりたい」ならON**、完全に検証だけならOFFでもOK🙂

## Step 5：作成ボタンを押す🏁

* **Create project** を押して待つ⌛
* 完了したら **Project Overview** に着地します✅

---

## 3) 作った直後にやる“超大事な2分作業”📝✨

## ✅ 1分：プロジェクトIDを控える

1. ⚙️（歯車）→ **Project settings**
2. **Project ID** をコピーしてメモ📝

このID、今後ずっと使います（SDK設定・CLI・AI連携・デプロイ…全部）🔥

## ✅ 1分：「今どのプロジェクト？」を確認できる状態にする🧭

* 左上のプロジェクト名表示で **切り替え方法**だけ覚える🔁
* Project Overview に戻る導線も覚える🏠

---

## 4) ありがち罠（初心者あるある）と回避🧯😇

## 罠A：プロジェクトIDを適当に付けた→後で泣く😭

* **IDは変えられない**ので、ここだけは丁寧に！ ([Firebase][1])
* “とりあえず”で作ったなら、早い段階なら作り直しが一番安いです💡

## 罠B：「このIDもう使われてる」😵

* プロジェクトIDは世界で一意なので、被ると作れません
* その場合は、短い接尾辞（`-jp` `-kmy` `-2026`）を足すのが早い🏃‍♂️💨

## 罠C：FirestoreやApp Hostingの“場所”を後で変えられない🗺️

プロジェクト作成直後はまだ決めないことも多いですが、
Firestore など一部サービスは **ロケーションが後から変更できません**。 ([Firebase][5])
（この罠は後の章で本格的に扱うけど、ここで“存在だけ”知っておくと事故が減ります🧯）

---

## 5) 🤖 AIもここから使う（迷子回避の最強チート✨）

## A) Console内の「Gemini in Firebase」をONにする⚡

Firebase Consoleには **Gemini in Firebase（AIアシスタント）**があります🤖
有効化や利用には権限（Owner/Editorなど）条件があります。 ([Firebase][6])

**この章での使い方（超おすすめ）**👇

* 「プロジェクトIDの命名案を10個出して」
* 「dev/prod分けるなら命名どうする？」
* 「このプロジェクトで最初に触るべきメニューはどこ？」

## B) Gemini CLI × Firebase Extension（ターミナル派の味方💻🤖）

Gemini CLI 側に **Firebase Extension** を入れると、Firebase向けの支援が入りやすくなります。 ([Firebase][7])

インストール例（公式の案内に沿った形）👇 ([Firebase][7])

```bash
gemini extensions install https://github.com/gemini-cli-extensions/firebase/
```

Extensionは **MCP（Model Context Protocol）**経由で、Firebaseの作業を“ツールとして”手伝える設計です（例：プロジェクト/アプリ作成、設定参照など）。 ([Firebase][8])

> ポイント：AIが勝手にやるんじゃなく、**あなたの操作を速く・安全にする補助輪**として使うのがコツです🙂🧠

---

## 6) ミニ課題🎯（5分で終わる）

## ✅ ミニ課題

次をメモ帳に貼って保存📝

* プロジェクト名：＿＿＿＿
* プロジェクトID：＿＿＿＿
* Analytics：ON/OFF（どっちにした？）＿＿＿＿
* Consoleでの到達ルート：Project Overview → ⚙️ → Project settings ✅

## ✅ チェック（できたら合格💯）

* [ ] Project Overview に戻れる🏠
* [ ] Project settings に行ける⚙️
* [ ] Project ID を即コピペできる📝
* [ ] 「IDは変えられない」を理解した🔥 ([Firebase][1])

---

## 7) 1分クイズ🧩（定着タイム！）

1. 後から変えられないのはどっち？
   A. プロジェクト名 / B. プロジェクトID
   → **答え：B** ([Firebase][1])

2. Google Analytics は後からでも有効化できる？
   → **できる**（Project settings → Integrations） ([Firebase][2])

---

次の第12章は、このプロジェクトに **Webアプリ登録（SDKの名札づくり🏷️）**をして、いよいよアプリ側と“接続”していきます🌱⚡

[1]: https://firebase.google.com/docs/web/setup "Add Firebase to your JavaScript project  |  Firebase for web platforms"
[2]: https://firebase.google.com/docs/analytics/get-started?utm_source=chatgpt.com "Get started with Google Analytics - Firebase"
[3]: https://firebase.google.com/docs/projects/billing/firebase-pricing-plans?utm_source=chatgpt.com "Firebase pricing plans"
[4]: https://docs.cloud.google.com/resource-manager/docs/creating-managing-projects?utm_source=chatgpt.com "Creating and managing projects | Resource Manager"
[5]: https://firebase.google.com/docs/firestore/locations?utm_source=chatgpt.com "Cloud Firestore locations | Firebase - Google"
[6]: https://firebase.google.com/docs/ai-assistance/gemini-in-firebase/set-up-gemini?utm_source=chatgpt.com "Set up Gemini in Firebase - Google"
[7]: https://firebase.google.com/docs/ai-assistance/gcli-extension "Firebase extension for the Gemini CLI  |  Develop with AI assistance"
[8]: https://firebase.google.com/docs/ai-assistance/mcp-server "Firebase MCP server  |  Develop with AI assistance"
