# 第03章：ConsoleでFirestoreを有効化＆触ってみる🧰👀

この章は「コード書く前に、まず“本物のDB”に触って怖さを消す回」だよ〜😌✨
Consoleで **Firestoreを有効化 → `todos` コレクションを作る → ToDoを手で3件入れる → どこに何があるか迷子にならない** までやります🗺️🧭
（※Console手順は公式のクイックスタートに沿っています）([Firebase][1])

---

## この章でできるようになること✅✨

* Firestore を Console から **有効化**できる🧱
* `todos` コレクションに **手動でToDoを追加**できる➕📄
* Consoleで **「今どこに何が入ってるか」** が分かる👀🧭
* （チラ見でOK）**Rules（ルール）** の存在を知る🔒

---

## 0) 迷子防止のミニ用語📘🧠

* **コレクション**：箱📦（例：`todos`）
* **ドキュメント**：1件のデータ📄（例：`todos/{todoId}`）
* **フィールド**：ドキュメントの中身の項目🧩（例：`title`, `done`）
* **Rules（ルール）**：誰が読める/書けるかの門番🔒

---

## 1) Firestore を有効化する（DBを作る）🛠️🗃️

1. ブラウザで Firebase Console を開く🌐
2. 対象プロジェクトを選ぶ🎯
3. 左メニューで **Build → Firestore Database** を開く🧭
4. **Create database**（作成）を押す➕
5. ここで大事ポイントが2つ👇

## A. “モード”の選択（まずは作業しやすい方でOK）🧯

* 学習・開発中は「一時的に書ける状態」にして進めるのがラク（後で必ず締める）
* 逆に最初から締めると、次章以降で「書けない😇」が発生しやすい

モードや初期ルールの考え方は公式でも説明があります🔒([Firebase][1])

## B. “ロケーション（リージョン）”の選択（ここは慎重に！）🗾

* **近い場所ほど速い**（だいたい）⚡
* **一度作るとロケーションは変更できない** ので、ここだけは丁寧に🧠
* 日本向けなら、代表例として **Tokyo（asia-northeast1）** が選択肢になることが多いよ🗼（他にも選択肢あり）([Google Cloud Documentation][2])

> もし「ロケーションが選べない/固定されてる」場合：
> そのプロジェクトで既に“デフォルトの場所”が決まってる可能性が高いです（変更できません）😵‍💫
> これは公式クイックスタート側でも注意があります。([Firebase][1])

---

## 2) Consoleで `todos` を作って、ToDoを1件入れる➕📄

Firestore Database が作れたら、次はデータ投入だよ〜💪😆

1. Firestore Database の **Data**（データ）タブへ📂
2. **Start collection**（コレクション開始）を押す➕
3. **Collection ID** に `todos` と入力✍️
4. **Document ID** は「Auto-ID（自動）」でOK（楽！）🎲
5. フィールドを追加していく🧩（例）

* `title`：string（文字列）📝
* `done`：boolean（真/偽）✅
* `createdAt`：timestamp（日時）⏱️
* `updatedAt`：timestamp（日時）⏱️
* （余裕あれば）`tags`：array（配列）🏷️

> `createdAt/updatedAt` は後で「サーバー時刻で入れる」方が強いんだけど、今は“型に慣れる”のが目的だから Console の timestamp でOKだよ🙆‍♂️✨

6. **Save**（保存）を押す💾
7. `todos` の下にドキュメントが1件できてるのを確認👀✨

---

## 3) ミニ課題：`done:false` を3件入れてみよう🧩✅✅✅

やることはシンプル！

* `todos` に **合計3件** になるまで追加
* ぜんぶ `done: false` にする

コツ：

* `title` は「洗濯する」「請求書払う」「散歩する」みたいに短くてOK🐶🧺💸
* 1件作れたら、あとはコピペ気分で増やすだけ😆

---

## 4) チェック：Consoleで迷子にならないか確認🧭👀

次の質問にスッと答えられたら勝ち🏆✨

* 「コレクション名は？」→ `todos` 📦
* 「ドキュメントは何件入ってる？」→ 3件📄📄📄
* 「`done` はどこにある？」→ ドキュメントのフィールド🧩
* 「いま見てる場所はどこ？」→ Firestore Database → Data タブ📂

---

## 5) ちょい怖ポイント：Rules（ルール）を“眺めるだけ”🔒👀

この章では **設定で詰まらないために**、Rulesは「存在だけ把握」でOK！

* Firestore の **Rules** タブを開いてみる🔒
* 「読める/書けるの条件」をここで決めるんだな〜って眺める👀
* “開発中のゆるい設定”は便利だけど、そのまま公開は危険⚠️
  公式も「安全なルールに直そう」って強く言ってるよ🧯([Firebase][3])

---

## 6) AIで時短コーナー🤖💨（Antigravity / Gemini CLI を“下調べ係”にする）

ここ、ちゃんと最新を追ってるよ！✅
いまは **MCP** という仕組みで、AIエージェント（Antigravity や Gemini CLI）から Firebase/Firestore を触れる方向が公式で整備されてきてます。([Firebase][4])

## A) Antigravityで「Console操作の迷子」を減らす🧭🤖

Antigravity は “Mission Control” でエージェントに調査させる思想のIDEだよ（公式Codelabあり）([Google Codelabs][5])
おすすめの投げ方👇

* 「Firestore Database を Console で作る最短手順を、メニュー名そのままで箇条書きにして」
* 「リージョン選択で迷ってる。日本ユーザー中心なら候補と判断軸を3つで」
* 「`todos` のフィールド設計、初心者向けにミスりにくい案を出して」

## B) Gemini CLIは“ターミナル側のAI相棒”🧑‍💻✨

Gemini CLI はターミナルで動くオープンソースのAIエージェントで、MCP連携も前提に設計されてるよ。([Google Cloud Documentation][6])
さらに Firebase 公式で **Gemini CLI拡張** や、Firestore向けの手順も用意されてる。([Firebase][7])

> ただしこの章では「Consoleで触って感覚を掴む」が主役なので、
> Gemini CLI は “調査・メモ作り” くらいに使うのがちょうどいい👌😆

---

## 7) 次章へのつながり🔌⚛️

次の第4章で、React から Firestore に接続して「0件表示」→「取得できた！」へ進むよ🚀
第3章をクリアしてると、次章でエラーが出ても **Consoleで中身を見て落ち着ける** ようになるのが強い😌✨

---

必要なら、この第3章で入れた `todos` の“例データ3件ぶん”を、あなた好み（戦国ネタToDoとか😆🏯）で作って貼れる形にして渡すよ〜🧾✨

[1]: https://firebase.google.com/docs/firestore/quickstart?utm_source=chatgpt.com "Get started with Cloud Firestore Standard edition - Firebase"
[2]: https://docs.cloud.google.com/firestore/native/docs/locations?utm_source=chatgpt.com "Locations | Firestore in Native mode"
[3]: https://firebase.google.com/docs/firestore/security/insecure-rules?utm_source=chatgpt.com "Fix insecure rules | Firestore - Firebase"
[4]: https://firebase.google.com/docs/ai-assistance/mcp-server?utm_source=chatgpt.com "Firebase MCP server | Develop with AI assistance - Google"
[5]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[6]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[7]: https://firebase.google.com/docs/ai-assistance/gcli-extension?utm_source=chatgpt.com "Firebase extension for the Gemini CLI"
