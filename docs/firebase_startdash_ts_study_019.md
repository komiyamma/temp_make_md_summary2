# 第19章：これから出てくるFunctions/AIの予告：言語とバージョン感だけ先に👀⚙️

この章は「まだ実装はしないけど、**後半で絶対に出てくる“裏側（バックエンド）＋AI”の地図**」を先に持って、あとで迷子にならないための回です🗺️✨
（10〜20分：読む→手を動かす→ミニ課題→チェック✅）

---

## この章のゴール🎯

* 「フロント（React）だけじゃ足りない時、どこに何を置くか？」が分かる🙂
* **Cloud Functions / Cloud Run / AI** の役割の違いがざっくり言える🙂
* 2026年2月時点での **“選ぶべき言語＆ランタイム”** をメモできる📝

---

## 1) まず全体地図：Reactの“外側”で何が起きる？🗺️🔌

いま作ってるのはフロント中心（React）だけど、アプリって途中からこうなりがち👇

* **フロント（React）**：画面・入力・表示を担当⚛️🖥️
* **Firebase（クライアントSDK）**：ログイン、DB、保存、分析、AI呼び出し等を“直で”使える🏗️✨
* **バックエンド（Functions/Cloud Run）**：

  * 「秘密鍵を使う処理」🔑
  * 「重い処理（画像処理・集計）」🏋️
  * 「外部APIを叩く中継」🌐
  * 「決まった時間に実行」⏰
    みたいな “裏側の仕事” を担当🙂 ([Firebase][1])

---

## 2) Cloud Functions for Firebase：まずは“2nd gen＋ランタイム”だけ押さえる🔧👀

## Functionsって何するの？🧰

**イベント**（DB更新・ファイル追加・HTTPアクセス・スケジュール等）をきっかけに、サーバー側コードを自動で動かす仕組みだよ🚀
コードは Google Cloud 上で動く（サーバー管理いらない）🙂 ([Firebase][1])

## いま最重要なのは「対応ランタイム」⚙️

この章で覚えるのはここだけでOK！

* **Node.js（推奨の主役）**：**22 / 20**（18はdeprecated）
* **Python**：`python310` / `python311`（`firebase.json`で指定）
* Node 14/16 は 2025初頭に停止済み（古い記事に注意⚠️） ([Firebase][2])

> ✅ 「Functionsやるなら、Nodeは 22 or 20 で考える」
> ✅ 「Pythonなら 3.10/3.11 の範囲で考える」

---

## 3) Cloud Run functions：選べる言語が増える＆サポート期限が見える📅🚦

Functions（Firebase）の裏側は Cloud Run ベースの仕組みと相性が良くて、
**より多言語でやりたい時**や、**ランタイムの選択肢を増やしたい時**に候補になるよ🙂

たとえば Cloud Run functions だと…

* **Node.js 24 / 22 / 20** が並んでる（＝新しめも選べる） ([Google Cloud Documentation][3])
* **.NET 8 / .NET 6** がある（さらに **.NET 10 preview** も見える） ([Google Cloud Documentation][3])

しかも「いつ deprecated / decommission になるか」みたいな期限が表で見えるのが強い📅✨
例：Node 20 の deprecation が 2026-04-30 みたいに書かれてる（＝移行計画が立てやすい） ([Google Cloud Documentation][4])

---

## 4) 手を動かす①：公式ドキュメントで“正解のバージョン”を目視👀🧾

この章のハンズオンは「読むだけ」じゃなく、**自分の目で“対応バージョン”を確認してメモ**します📝✨

## やること（3分）✅

1. 「Manage functions」ページを開く
2. **Set Node.js version** で **Node 22 / 20（18 deprecated）** を確認
3. **Set Python version** で `python310` / `python311` を確認
   ([Firebase][2])

## ついでに1つだけ重要ポイント💡

2nd gen では **同時リクエスト（concurrency）** が出てくる。
これ、スケールと料金に効くので「後で必ず触るやつ」って覚えておけばOK🙂 ([Firebase][2])

---

## 5) 手を動かす②：Windowsで“今の自分のバージョン”を確認🔍💻

ここでズレると後で詰まるので、1回だけ確認しよ〜🙌

PowerShell で👇

```powershell
node -v
npm -v

py -V
python --version

dotnet --version
```

* `node`：Functions（Node）やツール類の土台🧱
* `py` / `python`：Python Functionsを使う時に必要🐍
* `dotnet`：Cloud Run functions で .NET を使う未来のため🙂

---

## 6) 手を動かす③：未来メモ（コピペ用）を書く📝✨

“今は触らない”ことほど、**メモが正義**です😇
`FUTURE_BACKEND.md` みたいなファイルを作って、これを書いておこう👇

```md
## FUTURE_BACKEND.md

## Functions（Firebase）
- Node: 22 / 20（18はdeprecated）
- Python: python310 / python311（firebase.json で指定）
- 2nd gen は concurrency がある（料金と性能に効く）

## Cloud Run functions（必要になったら）
- Node: 24 / 22 / 20
- .NET: 8 / 6（.NET 10 preview もある）
- サポート期限（deprecation / decommission）を見て選ぶ

## AI
- フロント直：Firebase AI Logic（App Check や rate limit あり）
- サーバー側：Genkit（本格派）
```

---

## 7) AIの予告：クライアント直叩き（AI Logic） vs サーバー側（Genkit）🤖🧠

ここが2026っぽい超重要分岐！🌈

## A) フロントから直接AIを呼ぶ：Firebase AI Logic（ラク側）😄✨

* Web/モバイルから **Gemini API / Imagen API** を呼ぶためのクライアントSDKが用意されてる
* **Firebase App Check** で不正クライアント対策できる
* **ユーザー単位のrate limit** が標準で入ってて、調整もできる
* Geminiのプロバイダとして **Gemini Developer API と Vertex AI** の両方を選べる
  ([Firebase][5])

> ✅「まずはAI体験を最短で出す」ならこっちが気持ちいい🙂✨

## B) サーバー側で本格AI：Genkit（強い側）💪🔥

* FirebaseのOSSフレームワークで、サーバー側AI開発向け
* モデルは OpenAI や Anthropic なども含め幅広く扱える、みたいな思想
  ([Firebase][5])

> ✅「秘密鍵を守る」「ツール実行」「複雑なフロー」になるほどサーバー側が輝く🙂🔐

---

## 8) Antigravity / Gemini CLI：Firebaseを“シームレスに扱う”導線🛸🤖

ここはちゃんと最新を確認しておくね✅

## Antigravity（WindowsでもOK）🪟🛸

Antigravity は “エージェント前提の開発環境” で、Mission Control 的に動くやつ。
Windowsでも使える前提で案内されてるよ🙂 ([Google Codelabs][6])

## Firebase MCP server：AIがFirebase操作を手伝える🧰🧠

Firebase MCP server は、いろんなAIツール（Antigravity / Gemini CLI など）から Firebase を触るための仕組み。
設定例として `npx -y firebase-tools@latest mcp` が出てる📌 ([Firebase][7])

## Gemini CLI に Firebase拡張を入れる（おすすめ）⚡

公式に、これで入る👇（コマンドが明記されてる） ([Firebase][8])

```bash
gemini extensions install https://github.com/gemini-cli-extensions/firebase/
```

入れると何が嬉しい？🎁

* MCP server を自動で入れて設定してくれる
* Firebase向けの“定番プロンプト（スラッシュコマンド）”が使える
* Firebaseドキュメント参照をAIがやりやすい形に整えてくれる
  ([Firebase][8])

---

## ミニ課題🎯（5分）

次の3つを `FUTURE_BACKEND.md` に追記して完成させてね📝✨

1. **Functionsは Node 22 で行く** or **20で行く**（どっちでもOK、理由を1行）🙂
2. Pythonを使うなら **python311** を第一候補にする（でOK）🐍
3. 「もし .NET を使うなら Cloud Run functions の .NET 8」って1行書く🙂 ([Google Cloud Documentation][3])

---

## チェック✅（口に出して言えたら勝ち）

* [ ] Functions で選ぶ Node は **22/20**（18はdeprecated）🙂 ([Firebase][2])
* [ ] Functions の Python runtime は **python310 / python311** 🐍 ([Firebase][2])
* [ ] Cloud Run functions だと **.NET 8** が選べる🙂 ([Google Cloud Documentation][3])
* [ ] AIは「フロント直（AI Logic）」と「サーバー側（Genkit）」に分かれる🤖 ([Firebase][5])
* [ ] Gemini CLI は Firebase拡張で MCP が入り、Firebase向けの導線が増える🧰 ([Firebase][8])

---

## 次章につながる話🔜✨

次に Functions を本格的に触る章では、ここで作った「未来メモ」をそのまま使って

* Node/TSでHTTP関数を作る🌐
* Firestoreトリガーで自動処理する🔥
* AIを絡めるなら「どこで呼ぶか」を決める🤖
  って流れにスムーズに入れるよ〜🙌

[1]: https://firebase.google.com/docs/functions "Cloud Functions for Firebase"
[2]: https://firebase.google.com/docs/functions/manage-functions "Manage functions  |  Cloud Functions for Firebase"
[3]: https://docs.cloud.google.com/run/docs/runtimes/function-runtimes?hl=ja "Cloud Run functions ランタイム  |  Google Cloud Documentation"
[4]: https://docs.cloud.google.com/functions/docs/runtime-support "Runtime support  |  Cloud Run functions  |  Google Cloud Documentation"
[5]: https://firebase.google.com/docs/ai-logic "Gemini API using Firebase AI Logic  |  Firebase AI Logic"
[6]: https://codelabs.developers.google.com/getting-started-google-antigravity "Getting Started with Google Antigravity  |  Google Codelabs"
[7]: https://firebase.google.com/docs/ai-assistance/mcp-server "Firebase MCP server  |  Develop with AI assistance"
[8]: https://firebase.google.com/docs/ai-assistance/gcli-extension "Firebase extension for the Gemini CLI  |  Develop with AI assistance"
