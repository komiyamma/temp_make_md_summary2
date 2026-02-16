# 第17章：プロジェクト分け（dev/prod）の超基本：事故らない運用の入口🧠🚧

この章でやることはシンプル！✨
**「開発用(dev)」と「本番用(prod)」を“別のFirebaseプロジェクト”として分けて、アプリ側は設定を切り替えて動かす**——これだけです😊
Firebase公式も、**開発フローでは環境ごとに別プロジェクトを推奨**しています。([Firebase][1])

---

## この章のゴール🎯✅

* dev/prod を分ける“理由”を、ざっくり説明できる🙂
* dev/prod の **2つのFirebaseプロジェクト**を作れる🏗️
* React(Vite)+TypeScript側で **configをdev/prodで差し替え**できる🔁
* Firebase CLIで **プロジェクト（エイリアス）を切り替え**できる🧰([Firebase][2])

---

## 1) なんで分けるの？（ここが一番大事）💥🧯

分けないと、初心者ほどこうなりがち👇

* **データ事故**：テストのつもりで本番DBを消す/汚す😱
* **設定事故**：本番のAPIキーや通知先に、テストが飛ぶ📣💥
* **課金事故**：実験コードで本番の課金やクォータが増える💸

特にAI絡み（Firebase AI Logic / Genkit / Gemini API など）を使うと、**キー管理・呼び出し回数・ログ**が絡んでくるので、dev/prod分離の価値が跳ね上がります⚡
Firebase AI Logicの本番チェックリストでも、**開発/テスト/本番は別Firebaseプロジェクト**が推奨されています。([Firebase][3])

---

## 2) 手を動かす①：dev/prodプロジェクトを作る🏗️🧭

やることは「2個作る」だけ！😆

* 例：

  * `myapp-dev`（開発用）
  * `myapp-prod`（本番用）

App Hostingなど“環境”の考え方が出てくる機能では、**productionをproductionとしてタグ付け**する導線もあります（後で効いてきます）。([Firebase][4])

💬 Geminiに聞く例（そのままコピペOK）🤖

* 「Firebaseで dev と prod を分けたい。プロジェクト名のおすすめ命名と、最低限の分離ルールを3つで教えて」

---

## 3) 手を動かす②：Webアプリ登録を “dev/prod両方” でやる🏷️🌐

第12章でやった「Webアプリ登録」を、**devプロジェクトでもprodプロジェクトでも**やります。

* dev側：Webアプリ登録 → configを控える📝
* prod側：Webアプリ登録 → configを控える📝

ポイント：**configはプロジェクトごとに違う**ので、混ぜるとすぐ迷子になります🌀

---

## 4) 手を動かす③：Viteの.envで “dev/prod config差し替え” を作る🔁⚛️

Viteは `.env` と `.env.[mode]` を読み分けできます。
たとえば `.env.production` は `.env` より優先されます。([vitejs][5])

## 4-1. envファイルを作る📝

プロジェクト直下（`package.json` と同じ階層）に置くよ👇

```txt
## .env（dev用）
VITE_FIREBASE_API_KEY=xxxx_dev
VITE_FIREBASE_AUTH_DOMAIN=xxxx_dev
VITE_FIREBASE_PROJECT_ID=myapp-dev
VITE_FIREBASE_STORAGE_BUCKET=xxxx_dev
VITE_FIREBASE_MESSAGING_SENDER_ID=xxxx_dev
VITE_FIREBASE_APP_ID=xxxx_dev
```

```txt
## .env.production（prod用）
VITE_FIREBASE_API_KEY=xxxx_prod
VITE_FIREBASE_AUTH_DOMAIN=xxxx_prod
VITE_FIREBASE_PROJECT_ID=myapp-prod
VITE_FIREBASE_STORAGE_BUCKET=xxxx_prod
VITE_FIREBASE_MESSAGING_SENDER_ID=xxxx_prod
VITE_FIREBASE_APP_ID=xxxx_prod
```

> ✅ ここで覚えたい感覚：
> **「ビルドした時点で“どっちの設定で固まるか”が決まる」**（Viteはビルド開始時に.envを読み込む）([v2.vitejs.dev][6])

## 4-2. `src/firebase.ts` を作る（configをenvから組み立て）🧩

```ts
// src/firebase.ts
import { initializeApp } from "firebase/app";

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY as string,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN as string,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID as string,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET as string,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID as string,
  appId: import.meta.env.VITE_FIREBASE_APP_ID as string,
};

export const app = initializeApp(firebaseConfig);

// “今どっちで動いてる？”確認用に出しておくと事故が減る🙏
export const firebaseProjectId = firebaseConfig.projectId;
```

## 4-3. 画面に「今どっち？」を出す（事故防止の最強お守り🧿）

```tsx
// src/App.tsx
import { firebaseProjectId } from "./firebase";

export default function App() {
  return (
    <div style={{ padding: 16 }}>
      <h1>環境チェック✅</h1>
      <p>mode: {import.meta.env.MODE}</p>
      <p>firebase projectId: {firebaseProjectId}</p>
    </div>
  );
}
```

## 4-4. 起動して確認👀

* 開発（dev想定）：`npm run dev`
* 本番ビルド（prod想定）：`npm run build`

💡 ここで “projectIdがmyapp-prodになってたら” 超危険⚠️
（テストしてるつもりで本番を触るやつ！😱）

---

## 5) 手を動かす④：Firebase CLIで dev/prod を切り替える🧰🔁

Firebase CLIは **同じコードフォルダ**に対して、**複数Firebaseプロジェクトをエイリアス登録**できます。
`firebase use --add` で追加し、`.firebaserc` に書かれます。([Firebase][2])

## 5-1. エイリアス追加

```bash
firebase use --add
```

（対話で `dev` と `prod` を作るイメージ）

## 5-2. “今どれ？”を見る / 切り替える

```bash
firebase use          # エイリアス一覧
firebase use dev      # devをアクティブに
firebase use prod     # prodをアクティブに
firebase use --clear  # 解除
```

## 5-3. 1回だけprodへ…みたいに上書きもできる

```bash
firebase deploy --project=prod
```

この `--project` 上書きがあるので、**“普段はdev固定、必要な時だけprod”**もできます👍([Firebase][2])

🧠 さらに事故防止：
デプロイ前に必ず `firebase use` を叩いて **“今のアクティブプロジェクト”** を見る癖をつけると強い💪

---

## 6) AI時代の「分け方」ポイント（Functions / App Hosting / AI Logic）🤖🧠

ここは“予告”だけど、**第17章の分離がそのまま効く**ので先に触れます👀✨

## Functions：環境変数も dev/prod で分けられる🌿

Cloud Functions for Firebase は、`.env.<project or alias>` を使って **ターゲットプロジェクトごとに変数を変える**やり方があります。([Firebase][7])

* 例：`functions/.env.dev` と `functions/.env.prod` を作って、`firebase use dev` / `firebase use prod` でデプロイ先を切り替えるイメージ。([Firebase][8])
* さらに機密情報は **Google Cloud Secret Manager** を使う導線が公式にあります。([Firebase][8])

Genkit系の関数でも、**APIキーをSecret Managerに保存してFunctionsから使える**、という説明が公式にあります。([Firebase][9])

## App Hosting：prod/staging を “別Firebaseプロジェクト” にデプロイする導線📦

App Hostingの複数環境デプロイガイドは、**prodとstagingを別Firebaseプロジェクトに**デプロイする流れです。([Firebase][4])
さらに `apphosting.yaml` で環境変数や、**Secret Manager参照のsecrets**を扱えるので、設定を安全に運用しやすいです。([Firebase][4])

## AI Logic：本番に入る前に「プロジェクト分離」がまず前提🧱

AI Logicの本番チェックでも、**まずプロジェクト管理のベストプラクティス（開発/テスト/本番を分ける）**が入ってきます。([Firebase][3])

## Gemini CLI：AI Logicの初期セットアップも“プロジェクト単位”で進む🧰🤖

Gemini CLI + Firebase拡張の流れでは、`/firebase:init` で **プロジェクト作成・アプリ登録・API有効化・SDK初期化コード追加**みたいなセットアップを進める導線があります。([The Firebase Blog][10])
なので最初は **devプロジェクトで試す → OKならprod** が超安全😌

## MCP：AIエージェントが「どのプロジェクト？」を扱ってるか要確認👀

Firebase MCP Serverは、AIツールが **プロジェクト作成や、クライアントSDK configのダウンロード**までできる、とされています。([The Firebase Blog][11])
便利だけど、だからこそ **「今dev？prod？」を毎回確認**しようね🧯

---

## 7) よくある事故トップ5🧨 → 即死回避チェック✅

1. **envファイルを間違えて本番でビルド** → 画面に `projectId` 表示で防ぐ🧿
2. **Firebase Consoleでプロジェクト切替し忘れ** → 右上のプロジェクト名、毎回見る👀
3. **CLIでprodがアクティブのままデプロイ** → `firebase use` を儀式にする🙏([Firebase][2])
4. **AIに貼る情報の線引きが曖昧** → “秘密はSecret Manager、画面に出るものは秘密じゃない”で整理🧠([Firebase][8])
5. **AI機能の実験が本番プロジェクトで走る** → AI Logicの本番前チェックを一度見る📝([Firebase][3])

---

## ミニ課題🎒✨

## ミニ課題A（最重要）🧿

* dev/prodの2プロジェクトを作る
* Viteの `.env` / `.env.production` を用意
* 画面に `mode` と `firebase projectId` を表示して、

  * `npm run dev` → devのprojectId
  * `npm run build` → prodのprojectId
    になってるのを確認✅

## ミニ課題B（CLI）🧰

* `firebase use --add` で `dev` / `prod` を登録
* `firebase use` で一覧が出るのを確認✅([Firebase][2])

---

## チェック問題✅📝（3問）

1. dev/prodを分ける最大の理由を1つ、あなたの言葉で言うと？🙂
2. “今どっちのFirebaseプロジェクトで動いてるか”を確認する方法を2つ言える？👀
3. CLIで「普段dev固定、1回だけprodにデプロイ」するときのやり方は？🧰([Firebase][2])

---

次の章（第18章）は「課金・クォータ事故」を先に潰す安全装置💸🧯だけど、**第17章の分離ができてると“事故の半分”が自然に消える**よ〜😆✨

[1]: https://firebase.google.com/docs/projects/dev-workflows/general-best-practices "General best practices for setting up Firebase projects  |  Firebase Documentation"
[2]: https://firebase.google.com/docs/cli "Firebase CLI reference  |  Firebase Documentation"
[3]: https://firebase.google.com/docs/ai-logic/production-checklist?utm_source=chatgpt.com "Production checklist for using Firebase AI Logic - Google"
[4]: https://firebase.google.com/docs/app-hosting/multiple-environments "Deploy multiple environments from a codebase  |  Firebase App Hosting"
[5]: https://vite.dev/guide/env-and-mode?utm_source=chatgpt.com "Env Variables and Modes"
[6]: https://v2.vitejs.dev/guide/env-and-mode?utm_source=chatgpt.com "Env Variables and Modes"
[7]: https://firebase.google.com/docs/functions/config-env "Configure your environment  |  Cloud Functions for Firebase"
[8]: https://firebase.google.com/docs/functions/config-env?utm_source=chatgpt.com "Configure your environment | Cloud Functions for Firebase"
[9]: https://firebase.google.com/docs/functions/oncallgenkit?utm_source=chatgpt.com "Invoke Genkit flows from your App | Cloud Functions for Firebase"
[10]: https://firebase.blog/posts/2025/10/ai-logic-via-gemini-cli/?utm_source=chatgpt.com "Add AI features to your app using Gemini CLI and ..."
[11]: https://firebase.blog/posts/2025/05/firebase-mcp-server/ "Firebase MCP Server"
