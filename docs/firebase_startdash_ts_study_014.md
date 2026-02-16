# 第14章：設定の置き場所：公開していいもの/ダメなもの🔐📦

この章はズバリ、**「どの設定はフロントに置いてOK？」「どれは絶対NG？」**を“事故らない形”で身につける回だよ〜🧯✨
（やること：`firebaseConfig` を **Viteの `.env`** に移して、**Gitに入れない**ように整える🧪）

---

## 1) まず大前提：フロントに入れた時点で「公開される」🌍👀

Vite + React のフロントコードは、最終的に **ブラウザに配られるJavaScript** になるよね⚛️📦
つまり…

* ✅ `.env` を使っても、**フロントで参照する値はビルド成果物に入る**（＝見ようと思えば見える）👀
* ✅ だから「`.env` に入れた＝秘密になった」ではない🙅‍♂️

ここ、めちゃ大事！！🔔

---

## 2) 「公開していいもの / ダメなもの」仕分け一覧🧠🗂️

### ✅ 公開してOK（フロントに置いてOK）🟢

* **FirebaseのWebアプリ設定（firebaseConfig）**

  * `apiKey`, `authDomain`, `projectId` など
  * これは**認可の鍵じゃなくて“どのプロジェクトに接続するかの目印”**に近い扱いだよ🙂
  * 実際、Firebase公式も **「FirebaseのAPIキーは秘密じゃない」** と明記してる✅ ([Firebase][1])

> ただし！「公開してOK」＝「何しても安全」じゃないよ⚠️
> データ保護は **Security Rules**（Firestore/Storage）でやるのが本筋🔥 ([Firebase][1])

### ❌ 絶対に公開しちゃダメ（フロントに置いたら即アウト）🔴🚫

* 外部サービスの **秘密鍵**（例：決済、メール送信、AIのサーバー用キー等）🔑💥
* サービスアカウントJSON（管理者権限のやつ）🧨
* “管理者として操作できる”系トークン（長期トークン）🧟‍♂️

これらは **サーバー側（Functions/Cloud Runなど）** に持たせる領域だよ🏰✨
（このスタートダッシュでは「フロントに置かない」だけ覚えればOK！👍）

---

## 3) じゃあ、なぜ `.env` に移すの？🤔💡

秘密にするためじゃなくて、主にこれ👇

* ✅ **dev/prod 切り替えがラク**（あとで環境分けする時に効く）🔁
* ✅ コードにベタ書きしないから、**見通しが良くなる**👀✨
* ✅ 誤って公開リポジトリに貼る事故が減る🧯

---

## 4) Viteの環境変数ルール（ここだけ覚えればOK）⚡

Viteは `.env` を読み込んで、フロントからは `import.meta.env` で参照するよ📦
そして超重要ポイント👇

* ✅ **`VITE_` で始まる変数だけがフロントに公開される**
* ✅ `.env` を変えたら **開発サーバー再起動が必要**
* ✅ `process.env` じゃないよ！ **`import.meta.env`** だよ！
  （全部Vite公式に書いてある🧾） ([vitejs][2])

---

## 5) 手を動かす：firebaseConfig を `.env.local` に移す🛠️🧪

## Step 1：プロジェクト直下に `.env.local` を作る📄✨

`package.json` と同じ階層に `.env.local` を作って、こう書く👇

```dotenv
VITE_FIREBASE_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
VITE_FIREBASE_AUTH_DOMAIN=yourapp.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=yourapp
VITE_FIREBASE_STORAGE_BUCKET=yourapp.appspot.com
VITE_FIREBASE_MESSAGING_SENDER_ID=1234567890
VITE_FIREBASE_APP_ID=1:1234567890:web:abcdef123456
```

ポイント📝

* 余計なクォートは基本いらない（必要な文字が入ってる時だけ `"..."`）🙂
* これは **ローカル専用** にするため `.local` でいくのが安心👍

---

## Step 2：`.gitignore` に追加して、Gitに入らないようにする🙈🧯

プロジェクト直下の `.gitignore` に追記👇

```gitignore
## local env files
.env.local
.env.*.local
```

これで **うっかりコミット事故**が激減するよ〜💥➡️🧯

---

## Step 3：`firebase.ts`（または初期化ファイル）を修正する✍️⚡

例：`src/firebase.ts`

```ts
import { initializeApp } from "firebase/app";

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

export const app = initializeApp(firebaseConfig);
```

✅ できたら **開発サーバーを再起動**（重要）🔁
Viteは起動時に `.env` を読むから、再起動しないと反映されないことが多いよ🌀 ([vitejs][2])

---

## Step 4：動作チェック✅👀

* ブラウザで起動してエラーが出ないか確認👀
* もし `undefined` 系が出たら、だいたいこれ👇

  * `VITE_` 付け忘れ🙃 ([vitejs][2])
  * サーバー再起動忘れ🔁 ([vitejs][2])
  * `.env.local` の置き場所が違う（ルートじゃない）📁💦

---

## 6) よくある詰まりポイント集🧩🩹

## 詰まり1：`import.meta.env.VITE_...` が `undefined` 😭

* `.env.local` が **プロジェクト直下**にある？（`package.json` と同じ？）📁
* 変数名は **`VITE_`** で始まってる？ 🔤 ([vitejs][2])
* **再起動**した？🔁 ([vitejs][2])

## 詰まり2：「`.env` に入れたから秘密！」と思ってた😇

* フロントで読む以上、最終的に配布物に入るよ📦
* 秘密にしたいなら **サーバー側**へ🏰（この先の章でやるやつ！）

## 詰まり3：Firebaseの `apiKey` が漏れたら終わり？😱

* Firebase公式は **「FirebaseのAPIキーは秘密ではない」** と明記してるよ🙂 ([Firebase][1])
* でも安全の本体は **Rules** と **APIキー制限**（必要なら）だよ🛡️

  * APIキーの扱い・ベストプラクティスは公式にまとまってる🧾 ([Firebase][3])

---

## 7) 🤖 AI（エージェント/CLI）に“安全チェック”を手伝わせる🧠🧯

ここからが2026っぽいやつ✨
**AIにやらせるのは「整理・検査・提案」**が相性いいよ👍

## ✅ AIに頼むと強いこと3つ🔥

1. **設定のベタ書き探し**（firebaseConfigが複数箇所にないか）🔎
2. **`.gitignore` の提案**（漏れやすいファイルが入ってないか）🧯
3. **コミット前チェック**（“っぽい秘密鍵”が混ざってないか）🚨

### 使えるプロンプト例（貼るのは“伏せ字”でOK）🫶

* 「`src` 以下で `apiKey:` とか `AIza` っぽい文字列が入ってる箇所を探して、`.env.local` へ移すパッチ案を出して」🔎✍️
* 「`.env.local` をGit管理しないように `.gitignore` を最小変更で直して」🧯
* 「外部サービスの“秘密鍵っぽい”値が紛れてないか、チェック観点を箇条書きで」✅

そして、もしGemini CLIを使うなら、Firebase公式が **Gemini CLI向けのFirebase拡張**を用意していて、MCPサーバーのセットアップもまとめて面倒を見てくれる流れがあるよ（便利！）🧰✨ ([Firebase][4])

---

## 8) ミニ課題🎯✨（10分）

## お題：`.env.example` を作って “共有できる形” にする📄🤝

1. ルートに `.env.example` を作る（これはGitに入れてOK）
2. 値はダミーにする（`xxxx` でOK）
3. READMEに1行だけ書く：「`.env.local` を作って `.env.example` を埋めてね」📝

例：

```dotenv
VITE_FIREBASE_API_KEY=xxxx
VITE_FIREBASE_AUTH_DOMAIN=xxxx.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=xxxx
VITE_FIREBASE_STORAGE_BUCKET=xxxx.appspot.com
VITE_FIREBASE_MESSAGING_SENDER_ID=xxxx
VITE_FIREBASE_APP_ID=xxxx
```

---

## 9) チェック✅🧠（答えられたら勝ち！🎉）

1. `.env` に入れた値は「フロントで使った時点で公開されうる」って説明できる？🌍
2. Viteでフロントに公開される環境変数の接頭辞は？🔤 ([vitejs][2])
3. `.env` を変更したのに反映されない時、まず何を疑う？🔁 ([vitejs][2])
4. Firebaseの `apiKey` は“秘密鍵”として扱う必要がある？（理由も）🗝️ ([Firebase][1])
5. 「絶対にフロントに置いちゃダメ」な情報を3つ言える？🔴

---

次の章（第15章）で、AIエージェントにFirebase操作を“道具として”手伝わせる話に入っていくと、**config取得→配置→検証**がもっとスムーズになるよ🛠️🤖✨

[1]: https://firebase.google.com/support/guides/security-checklist?utm_source=chatgpt.com "Firebase security checklist"
[2]: https://vite.dev/guide/env-and-mode?utm_source=chatgpt.com "Env Variables and Modes"
[3]: https://firebase.google.com/docs/projects/api-keys?utm_source=chatgpt.com "Learn about using and managing API keys for Firebase - Google"
[4]: https://firebase.google.com/docs/ai-assistance/gcli-extension?utm_source=chatgpt.com "Firebase extension for the Gemini CLI"
