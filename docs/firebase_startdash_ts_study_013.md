# 第13章：SDK導入→初期化→起動確認：最小の「繋がった！」🌱⚡

この章は **「Firebaseをアプリに入れて、初期化して、画面で“OK”を確認する」** だけに全集中します💪😄
（ここが通ると、次の認証・DB・AIもぜんぶ同じ土台に乗ります🧱✨）

---

## 1) まず“何が起きる？”を超ざっくり理解🙂🧠

Firebaseは、あなたのReactアプリの中で

* **Firebaseの設定（config）を読み込み** 🏷️
* **`initializeApp()` で接続の土台（FirebaseApp）を作る** 🌱
* その上に **Auth / Firestore / Storage / AI Logic** などが乗る🚃

…って流れです。公式のWebセットアップでも、まず `npm install firebase` → `initializeApp` がスタート地点になってます。([Firebase][1])

---

## 2) 手を動かす：SDK導入 → 初期化ファイル作成 → 起動確認💻🚀

### 2-0. Nodeの確認（ここだけ最初に）🔎

PowerShell（またはターミナル）で👇

```bash
node -v
npm -v
```

本日時点のNodeは **v24 が Active LTS**、v25 が Current、v22/v20 は Maintenance 側です。できれば v24 を使うと気持ちがラクです🙂([Node.js][2])

---

### 2-1. Firebase JS SDK を入れる📦✨

プロジェクト直下で👇

```bash
npm install firebase
```

入ったバージョン確認（任意）👇

```bash
npm ls firebase
```

npm上の `firebase` は本日時点で **12.x 系**が配布されています。([npm][3])

---

### 2-2. `firebase.ts` を作って初期化する🌱⚡

おすすめ配置：`src/lib/firebase.ts`（迷子防止に“住所”を固定📍）

```ts
// src/lib/firebase.ts
import { initializeApp, getApps, type FirebaseApp } from "firebase/app";

// 第12章で取得した firebaseConfig をここに貼る（あとで.envへ移すのは第14章で！）
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID",
};

// ✅ ViteのHMR（自動リロード）でも二重初期化しにくい書き方
export const app: FirebaseApp =
  getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
```

ポイント👀✨

* `initializeApp(firebaseConfig)` が“接続の始点”です。([Firebase][1])
* configの取り直し場所は **Firebase Console → Project settings → Your apps → Config** です（迷子になったらここ🏃‍♂️💨）。([Googleヘルプ][4])

---

### 2-3. 画面に「Firebase初期化OK」を出す✅🖥️

`src/App.tsx` を最小でこうします👇（成功/失敗で表示を変える✨）

```tsx
// src/App.tsx
import { useMemo } from "react";
import "./App.css";
import { app } from "./lib/firebase";

export default function App() {
  const status = useMemo(() => {
    try {
      // app が import できていれば、基本的に初期化は通ってる
      return `✅ Firebase初期化OK！ (projectId: ${app.options.projectId ?? "?"})`;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return `❌ Firebase初期化NG… ${msg}`;
    }
  }, []);

  return (
    <div style={{ padding: 24, fontFamily: "system-ui" }}>
      <h1>スタートダッシュ 🌱</h1>
      <p>{status}</p>
    </div>
  );
}
```

---

### 2-4. 起動して確認する🚀🔍

```bash
npm run dev
```

ブラウザで開いて👇

* 画面に `✅ Firebase初期化OK！` が出る
* DevTools（F12）Console に赤エラーが出てない

これでこの章はクリア🎉🎉🎉

---

## 3) よくある詰まりポイント集（初心者の沼を先回り）🧯😇

### A. `YOUR_API_KEY` のまま動かしてた😅

**貼り忘れあるある**です。第12章の config をそのまま貼ってOK。取り直し場所も上の通り。([Googleヘルプ][4])

### B. `Firebase App named '[DEFAULT]' already exists` 系💥

原因：**`initializeApp()` が複数回**呼ばれてる。
対策：この章の `getApps().length === 0 ? initializeApp(...) : ...` 方式にしておくとラクです🙂（HMRでも起きがち⚡）([Stack Overflow][5])

### C. `process is not defined` / 環境変数が読めない🤔

Viteでは **`import.meta.env`** を使います。`process.env` じゃないです🧠
さらにクライアントで読めるのは基本 `VITE_` プレフィックス付き。([vitejs][6])
（この話は第14章でちゃんとやります📦🔐）

---

## 4) 🤖AIと一緒に“爆速で詰まり解除”するコツ（Gemini CLI / Agent）🏃‍♂️💨

困ったら、エラーを **そのまま貼って**（鍵や個人情報は隠してOK🙈）こう聞くと強いです👇

* 「このエラーの原因を“1行”で言って」🧩
* 「直す手順を “1→2→3” で出して」🛠️
* 「Vite + React + firebase.ts の最小構成を、今のフォルダ構成に合わせて生成して」📁✨

“長文で聞かない”のがコツです😄（短いほどAIが当てやすい🎯）

---

## 5) 🤖FirebaseのAIサービスも“ここから繋がる”✨（AI Logicの入口案内）

いま作った `app`（FirebaseApp）が、**Firebase AI Logic** を使う時の“土台”にもなります🧱
AI Logic のWeb手順でも **「npm install firebase → initializeApp」** が最初のステップです。([Firebase][7])

さらに最近のAI Logicは、Webで **`firebase/ai`** を使って **オンデバイス推論↔クラウド推論** を切り替える“ハイブリッド”も案内されています。([Firebase][8])
しかも本日時点では、フォールバックの既定モデル（例）や、モデルの退役日などもドキュメントに明記されてます（古い例を踏まないの大事🧯）。([Firebase][8])

> つまり：**第13章が通った時点で「AIを載せる準備もOK」** ってことです😎✨
> （実際にAIを呼ぶのは、Console側のセットアップも絡むので“次の章以降”で安全にやるのがスムーズ👍）

---

## 6) ミニ課題🎯：成功/失敗で表示を変える（もうやってたらOK）✅

* 成功：`✅ Firebase初期化OK！`
* 失敗：`❌ Firebase初期化NG…（エラー文）`

さらに余裕があれば、画面に `projectId` を表示して「ちゃんと自分のプロジェクトにつながってる感」を出してみてね😄✨

---

## 7) チェック問題✅📝（3つ答えられたら合格🎉）

1. `initializeApp()` は何を作る？🌱
2. config を見失ったら Console のどこで拾える？🧭
3. Viteで環境変数は何で読む？（`process.env`？それとも…）⚡([vitejs][9])

---

次の章（第14章）で、いよいよ **configの置き場所**（公開していい/ダメ、`.env` の扱い、Gitに入れない🧯）を“事故らない形”に整えます🔐📦

[1]: https://firebase.google.com/docs/web/setup?utm_source=chatgpt.com "Add Firebase to your JavaScript project"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://www.npmjs.com/package/firebase?utm_source=chatgpt.com "firebase"
[4]: https://support.google.com/firebase/answer/7015592?hl=en&utm_source=chatgpt.com "Download Firebase config file or object"
[5]: https://stackoverflow.com/questions/44034691/react-nextjs-firebase-error-refresh-firebase-app-named-default-already-exist?utm_source=chatgpt.com "React NextJS Firebase error refresh Firebase App named ' ..."
[6]: https://vite.dev/guide/env-and-mode?utm_source=chatgpt.com "Env Variables and Modes"
[7]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
[8]: https://firebase.google.com/docs/ai-logic/hybrid-on-device-inference "Build hybrid experiences with on-device and cloud-hosted models  |  Firebase AI Logic"
[9]: https://ja.vite.dev/guide/env-and-mode?utm_source=chatgpt.com "環境変数とモード"
