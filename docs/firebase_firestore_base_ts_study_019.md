# 第19章：安全に壊して練習する（Emulator + サーバー側投入）🧪🧯

この章は「本番DBを一切汚さずに、思いっきりCRUDして壊して直す」回です💪✨
さらに、サーバー側（Admin SDK）から **seedデータをドバッと投入**して、開発スピードを上げます🚀

---

## 📖 読む：Emulatorって何が嬉しいの？😆

* **Firestore Emulator** はローカルPCで動く “擬似Firestore” です🧪
  → 追加/更新/削除をミスっても、本番に傷がつかない！🛡️
* Emulator Suite UI（ブラウザ画面）で、
  **どのリクエストが飛んで、Rulesがどう評価されたか** まで見えるのが強いです👀✨ ([Firebase][1])
* Firestore Emulatorは **デフォルトで 8080番**、UIは **4000番** など、決まったポートで起動します🔌 ([Firebase][2])

> ⚠️ 重要：Emulatorは便利だけど、本番と完全一致ではありません。
> 例えば **複合インデックスを追跡せず、通るクエリは実行してしまう** ので、インデックス要件は最後に本番でも確認が必要です📌 ([Firebase][1])

---

## 🛠️ 手を動かす：Emulatorを動かす（Windows）🪟⚙️

## 1) 必要なものをサクッと確認✅

Emulator Suiteは基本的にこれが必要です👇

* Node.js 16+
* Java JDK 11+
* Firebase CLI 8.14.0+（firebase-tools） ([Firebase][2])

さらに、Firestore Emulatorは **近い将来 Java 21 が必要になる予定**のアナウンスも出ています☕️📈（早めに21へ上げるのが安心） ([Firebase][1])

PowerShellでチェックするならこんな感じ👇

```bash
node -v
java -version
firebase --version
```

---

## 2) Emulator設定（firebase init emulators）🧰

プロジェクト直下で👇

```bash
firebase init
firebase init emulators
```

ここで **Firestore Emulator** と **Emulator Suite UI** を選ぶ感じです👍
設定は `firebase.json` に書かれます（ポートもここで変更できます）🔧 ([Firebase][2])

> ⚠️ Rulesや設定をちゃんと指定しないと、Firestore/RTDB/Storage系エミュレータは **open（ガバ開放）** で動くことがあります😱
> 「ローカルだから大丈夫」ではあるけど、習慣としてRulesをセットしようね🛡️ ([Firebase][2])

---

## 3) 起動してUIを開く🚀

まずはFirestoreだけでOK👇

```bash
firebase emulators:start --only firestore
```

UIはブラウザで `http://localhost:4000`（開けたら勝ち🎉） ([Firebase][2])
Firestoreは `localhost:8080` で待ってます🧪 ([Firebase][2])

---

## 🛠️ 手を動かす：ReactアプリをEmulatorにつなぐ⚛️🔌

ポイントは1つだけ！

> **Firestoreに触る前に** `connectFirestoreEmulator()` を呼ぶこと！
> （後から切り替えようとするとエラーになりがち😵）

例：`src/lib/firebase.ts`（構成は好きでOK）

```ts
import { initializeApp } from "firebase/app";
import { getFirestore, connectFirestoreEmulator } from "firebase/firestore";

const firebaseConfig = {
  // いつものやつ
};

export const app = initializeApp(firebaseConfig);

export const db = getFirestore(app);

// 開発時だけエミュレータへ
if (import.meta.env.DEV) {
  connectFirestoreEmulator(db, "127.0.0.1", 8080);
}
```

> 🧠 ちょい注意：エミュレータは停止するとDBが空になります。
> SDKのオフラインキャッシュとズレるのが嫌なら、永続化は切っておくのが安全（Web SDKはデフォルトで永続化OFF）です🧯 ([Firebase][1])

---

## 👀 ついでに：Emulator UIの “Requests” が神✨

UIで **Firestore > Requests** を開くと👇

* どんな read/write が来たか
* Rulesがどの順番で評価されたか
  が見えます🔍✨ ([Firebase][1])

さらに、Rulesのカバレッジ（どの条件分岐が踏まれたか）レポートも出せます📊
`ruleCoverage.html` がブラウザで見れるよ〜🧠 ([Firebase][1])

---

## 🧯 DBをリセットしたい（超便利）💥

本番Firestoreは「全部消す」みたいなSDK機能が無いけど、エミュレータには **DELETEで全消し** が用意されています🧨 ([Firebase][1])

PowerShell（curlは標準で入ってることが多い）：

```bash
curl -v -X DELETE "http://localhost:8080/emulator/v1/projects/firestore-emulator-example/databases/(default)/documents"
```

※ `firestore-emulator-example` は自分の projectId に置き換えてね📝 ([Firebase][1])

---

## 💾 データを保存してチーム共有したい（import/export）📦

毎回まっさらは辛いので、**ベースデータを保存**できるのが最高です😆

* エクスポート：`firebase emulators:export ./dir`
* 起動時インポート：`firebase emulators:start --import=./dir`
* 終了時に自動エクスポート：`--export-on-exit` ([Firebase][1])

例：

```bash
firebase emulators:start --only firestore --import=./.emulator-data --export-on-exit
```

---

## 🛠️ ついでに：サーバー側（Admin SDK）で seed 10件流し込む🌱🔥

ここからが「開発が一気に速くなる」やつ！🚀
**Admin SDKは `FIRESTORE_EMULATOR_HOST` を設定すると自動でエミュレータに接続**します✨
しかも **`http://` を付けない**のがルールです⚠️ ([Firebase][1])

## ✅ Node（おすすめ：一番ラク）🟩

## 1) 依存追加

```bash
npm i firebase-admin
```

## 2) `scripts/seed.mjs` を作る

```js
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

// 重要：Emulator接続は環境変数で行う（http://は付けない）
const projectId = process.env.GCLOUD_PROJECT ?? "demo-firestore";
initializeApp({ projectId });

const db = getFirestore();

const now = FieldValue.serverTimestamp();

const todos = Array.from({ length: 10 }).map((_, i) => ({
  title: `seed todo #${i + 1}`,
  done: false,
  tags: ["seed", i % 2 === 0 ? "easy" : "hard"],
  createdAt: now,
  updatedAt: now,
}));

async function main() {
  const batch = db.batch();
  todos.forEach((t) => {
    const ref = db.collection("todos").doc();
    batch.set(ref, t);
  });
  await batch.commit();
  console.log("✅ Seeded 10 todos into emulator!");
}

main().catch((e) => {
  console.error("❌ Seed failed:", e);
  process.exit(1);
});
```

## 3) PowerShellで実行

```bash
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
$env:GCLOUD_PROJECT="demo-firestore"
node scripts/seed.mjs
```

> `FIRESTORE_EMULATOR_HOST` の形式は `127.0.0.1:8080` みたいに **プロトコル無し**ね！ ([Firebase][1])

---

## 🟦 Python / 🟪 .NET でやりたい人へ（バージョン目安）📌

* Admin Python：7.1.0（Python 3.10+ 推奨の流れ） ([Firebase][3])
* Admin .NET：3.4.0（.NET 8.0 以上を使うよう案内） ([Firebase][4])

どちらも「基本は同じで、`FIRESTORE_EMULATOR_HOST` を設定してから実行」でOKです👍 ([Firebase][1])
（この章はまずNodeで成功体験を作るのがいちばん速いです🧠✨）

---

## 🤖 AIで“seed作り”と“デバッグ”を爆速にする💨

## 1) Firebase AI Logicで seed案を作る🧠✨

「ToDoタイトル10件を自然な日本語で」「タグも提案して」みたいなデータ作りをAIに投げると超ラクです📝
Firebase AI LogicはアプリからGemini APIを安全に呼ぶための仕組みとして案内されています🤖🔐 ([Google Cloud][5])

例プロンプト（コピペ用）👇

* 「ToDoタイトルを10件、日本語で。短め。タグ候補も2つずつ。JSON配列で。」

できたJSONをそのまま `todos` に貼り付ければseed完成🌱✨

## 2) Gemini CLI / Antigravityで“調査→修正”を短縮🔧🤝

* Gemini CLIはターミナルから調査・修正を回すためのツールとして案内があり、コード支援の入口として使えます🧑‍💻✨ ([Google Cloud Documentation][6])
* Antigravityはエージェント的に「計画→実装」を進める導線が用意されてるので、Emulator周りのセットアップ手順の整理にも相性いいです🛰️🧭

---

## 🧩 ミニ課題：安全に壊して、復活させよう🎮🧪

1. Emulatorを起動（Firestoreのみ）
2. Reactアプリをエミュレータ接続に切り替え
3. `todos` を10件、画面に表示（リアルタイム購読でもOK）⚡
4. seedスクリプトで **10件投入** → UIに即反映されるのを確認👀
5. 全消しDELETEを叩いて、一覧がゼロに戻るのを確認💥 ([Firebase][1])
6. import/exportも1回だけ試す📦 ([Firebase][1])

---

## ✅ チェック：ここまで来たら勝ち🏆

* 「本番を汚さずにCRUDを試す」手順を説明できる🛡️
* UIのRequestsで「何が飛んでるか」追える👀 ([Firebase][1])
* seed投入→確認→全消し→復元（import）まで回せる🌱➡️🧹➡️📦 ([Firebase][1])

---

次の章（第20章）で、ここまでの全部を合体させて **ミニアプリ完成🎯**＋AIで“実用っぽさ”を足していきます🤖✨

[1]: https://firebase.google.com/docs/emulator-suite/connect_firestore "Connect your app to the Cloud Firestore Emulator  |  Firebase Local Emulator Suite"
[2]: https://firebase.google.com/docs/emulator-suite/install_and_configure?utm_source=chatgpt.com "Install, configure and integrate Local Emulator Suite - Firebase"
[3]: https://firebase.google.com/support/release-notes/admin/python "Firebase Admin Python SDK Release Notes"
[4]: https://firebase.google.com/support/release-notes/admin/dotnet "Firebase Admin .NET SDK Release Notes"
[5]: https://codeassist.google/?utm_source=chatgpt.com "Gemini Code Assist | AI coding assistant"
[6]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
