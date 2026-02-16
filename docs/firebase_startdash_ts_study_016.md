# 第16章：🤖Gemini CLI×Firebase拡張：困ったら即レスで前に進む🏃‍♂️💨

この章はズバリ、**「詰まった瞬間に止まらない」**ための回です💪✨
Gemini CLIに**Firebase拡張（Extension）**を入れると、Firebase向けの“定番プロンプト集”と、Firebaseを触るための“道具箱”がセットで付いてきます🧰🔥（しかも裏で **Firebase MCP server** も整います）([Firebase][1])

---

## この章のゴール🎯

* Gemini CLIにFirebase拡張を入れて、**いつでも相談できる状態**にする🤝
* よくある詰まり（初期化・config・ビルド）を**AIと一緒に最短で抜ける**🧠⚡
* ついでに、**Firebase AI Logic** を“触り始められる入口”まで作る🤖🌱 ([Firebase][1])

---

## 1) まずは導入　Gemini CLI と Firebase拡張を入れる🧩🔧

## 1-1. Gemini CLI を最新にする⬆️

Gemini CLIはnpmで入れます。まずは**最新版に更新**しちゃうのが安全です✅
（2026-02時点で、拡張の設定まわりも強化されています）([Google Developers Blog][2])

```bash
npm install -g @google/gemini-cli@latest
gemini --version
```

## 1-2. Firebase拡張をインストール📦🔥

Firebase公式の拡張はこれです👇
（注意：**Gemini CLIの中**ではなく、普通のシェルで打ちます）([Firebase][1])

```bash
gemini extensions install https://github.com/gemini-cli-extensions/firebase/
```

入ると何が起きるかというと…👇

* **Firebase MCP server を自動インストール＆設定**してくれる🧠🔌
* Firebase向けの**スラッシュコマンド用プロンプト集**が増える📚✨
* Firebaseドキュメントを**AIが読みやすい形で参照**できるようになる🗂️
* プロジェクトにFirebase向けの**コンテキストファイル**も追加される🧾
  …という“全部入り”です([Firebase][1])

## 1-3. インストール確認✅

```bash
gemini extensions list
```

CLIの中から確認するなら、こういう系もあります👇（入ってる拡張一覧が見えます）([Google Developers Blog][2])

```text
/extensions list
```

## 1-4. 拡張を更新する🔁

Firebase拡張は更新が頻繁なので、たまにこれを打つのが吉👍([Firebase][1])

```bash
gemini extensions update firebase
```

---

## 2) 使い方の基本　困ったらまず“スラッシュコマンド”🧭🤖

Firebase拡張を入れると、Gemini CLI内でこういうのが使えます👇

## /firebase:init　最強の出発点🚀

```text
/firebase:init
```

このコマンドは、よくある目的を“対話で”進めてくれます。代表はこの2つ👇([Firebase][1])

* **Set up a backend**：Firestore＋Authなど、アプリの背骨づくり🦴🔥
* **Add AI features**：Firebase AI Logic をセットアップして、Gemini API をアプリから使う準備🤖✨

## /firebase:deploy　デプロイ系🚚🌍

```text
/firebase:deploy
```

既存Webアプリをデプロイする流れに乗せやすいです([Firebase][1])

---

## 3) “詰まった瞬間”の黄金ムーブ🥇💥

ここからが本題！
**何か変なエラーが出たら、順番はこれだけ**👇😄

## 3-1. エラーをそのまま貼る📎

* ブラウザのコンソール
* ターミナルのログ
* `npm run dev` の赤文字

## 3-2. まずはこれで聞く💬✨

（コピペ用テンプレ）

```text
このエラーを「原因」「最短の直し方」「どのファイルをどう直すか」の3点で教えて。
可能なら差分（diff形式）で出して。
エラー全文：
```

## 3-3. “Firebase拡張入り”の追加ワード🧰

Firebase拡張が入ってると、Firebaseまわりの作業を前提に提案が具体化しやすいです([Firebase][1])

```text
このプロジェクトはFirebaseを使ってる。初期化とconfig管理が怪しい気がする。
Viteの環境変数も前提にして、直し方を案内して。
```

---

## 4) よくある詰まり3連発　ここで8割勝てる🥊😆

## パターンA　Firebase App が作られてない系🧨

ありがちなエラー例👇

* `No Firebase App '[DEFAULT]' has been created`

よくある原因💡

* `initializeApp()` が呼ばれてない
* 初期化ファイルは作ったけど、どこからも import されてない

Gemini CLIへの投げ方👇

```text
No Firebase App '[DEFAULT]' のエラーが出た。
Vite+React+TS構成で、initializeAppの正しい置き場所とimportの流れを最短で直して。
```

---

## パターンB　config の読み込みがズレてる系🧩

ありがち👇

* `.env` に書いたのに読めない
* `import.meta.env` が undefined っぽい

よくある原因💡

* Viteの環境変数の名前が `VITE_` で始まってない
* `.env` を作ったけど dev server 再起動してない
* 参照してる変数名が微妙に違う（大文字小文字も…🥲）

Gemini CLIへの投げ方👇

```text
Viteの環境変数からFirebase configを読む作りにしたい。
.envの命名、import.meta.envの使い方、firebase.tsの構成を初心者向けに整えて。
```

---

## パターンC　ビルド・型エラーで進めない系⚡

ありがち👇

* TSの型が合わない
* importパスが迷子

Gemini CLIへの投げ方👇

```text
npm run dev が型エラーで止まる。エラー全文貼るので、原因と直し方を手順で教えて。
ついでに「初心者が次から避けるコツ」も3つ。
```

---

## 5) ハンズオン　AIに“最短で直させる”練習🏋️‍♂️🤖

## 手を動かす🖐️

1. プロジェクトのフォルダで開発サーバー起動

```bash
npm run dev
```

2. もしエラーが出たら、そのログをコピー📋
3. そのままGemini CLI起動

```bash
gemini
```

4. テンプレで質問して、返ってきた修正案を反映✍️
5. もう一回 `npm run dev` で確認✅

ポイント🌟

* **“直ったかどうか”を必ず再実行で確かめる**（AIは勢いで提案するので、検証が命😄）
* 大きめの変更を入れる前は、こまめにコミット推奨👍（公式の案内でも推奨されています）([The Firebase Blog][3])

---

## 6) ついでに触れる　Firebase AI Logic を最速で入口まで🚪🤖

Firebase拡張の `/firebase:init` には **AI Logic をセットアップする導線**があります([Firebase][1])

## 手を動かす🖐️

Gemini CLI内で👇

```text
/firebase:init
```

そこで **Add AI features**（AI Logic）を選ぶ流れに乗ると、Gemini CLIがセットアップを進めてくれます。
（プロジェクト準備、アプリ登録、必要APIの有効化、SDK初期化コードの追加…みたいな“面倒ゾーン”をまとめて寄せてくる感じです）([The Firebase Blog][3])

> ここは“未来の本番機能”というより、**「AIをアプリに組み込むルートが見えた！」**を作る場所です🤖✨

---

## 7) ミニ課題📝🎯

## お題：あなた専用の「詰まり対処メモ」を作る📌

Gemini CLIにこれを頼んでください👇

```text
このプロジェクト（Vite+React+TS+Firebase）で起きがちなミスを3つ挙げて、
それぞれ「症状」「原因」「最短の直し方」を1行ずつでまとめて。
```

出てきた結果を `docs/troubleshoot.md` とかに貼っておくと、次回から超ラクです😆✨

---

## 8) チェック✅✅✅

* `gemini extensions list` で firebase が見える✅
* `/firebase:init` が打てる✅ ([Firebase][1])
* エラーが出たとき、**ログを貼って原因→修正→再実行**まで一気に回せる✅
* Firebase AI Logic の入口が見えた✅ ([Firebase][1])

---

## 9) つまずいた時の“最短ヘルプ”集🚑💨

## 拡張がうまく動いてない気がする🤔

まずは更新👇

```bash
gemini extensions update firebase
```

それでもダメなら、拡張一覧と設定を見て原因を潰します（最近ここが改善されてます）([Google Developers Blog][2])

```bash
gemini extensions list
gemini extensions config <extension-name>
```

## Antigravity と Gemini CLI どっちで作業すべき❓

* 画面・エージェント管理込みで進めたい → Antigravity寄り🕹️
* ターミナルで軽く相談しながら進めたい → Gemini CLI寄り💻
  この住み分けが公式にも整理されています([Google Cloud][4])

---

次の章（第17章）で **dev/prod を分けて事故らない運用**に入るので、その前に第16章で「詰まっても復帰できる」感覚を固めるとめちゃ強いです🚧🔥

[1]: https://firebase.google.com/docs/ai-assistance/gcli-extension "Firebase extension for the Gemini CLI  |  Develop with AI assistance"
[2]: https://developers.googleblog.com/making-gemini-cli-extensions-easier-to-use/ "
            
            Making Gemini CLI extensions easier to use
            
            
            \- Google Developers Blog
            
        "
[3]: https://firebase.blog/posts/2025/10/ai-logic-via-gemini-cli/ "Add AI features to your app using Gemini CLI and Firebase AI Logic"
[4]: https://cloud.google.com/blog/topics/developers-practitioners/choosing-antigravity-or-gemini-cli "Choosing Antigravity or Gemini CLI | Google Cloud Blog"
