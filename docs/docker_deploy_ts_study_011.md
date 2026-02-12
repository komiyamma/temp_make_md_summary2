# 第11章：環境変数設計：設定は外へ🧩

この章はひとことで言うと、**「同じイメージを、設定だけ変えて dev / prod で使い回せる状態にする」**回です😎✨
（コードをいじらず、環境変数で挙動を変えられるようにするやつ！）

---

## 1) そもそも「設定を外へ」って何？🤔📦

アプリには、ざっくり2種類の情報があります👇

* **コード（ロジック）**：Gitで管理する、みんな同じ
* **設定（Config）**：環境ごとに変わる（ローカル/本番で違う）

この「設定」を **環境変数（env）**として外から渡すのが、クラウド＆コンテナの基本作法です💡
「設定は環境に置け」が有名な考え方としてまとまっています。([12Factor][1])

---

## 2) 何を環境変数にする？しない？🧠✅

### 環境変数にするもの（例）🧩

* `PORT`（待ち受けポート）
* `PUBLIC_BASE_URL`（自分の公開URL）
* `LOG_LEVEL`（ログの出し方）
* `CORS_ORIGIN`（許可するフロントURL）
* `FEATURE_X=true`（機能フラグ）

### 環境変数に「しがちだけど注意」⚠️

* **APIキー / DBパスワードなどの秘密情報（Secrets）**
  → “環境変数に入れる運用”もできますが、**次章（Secrets）で「安全に扱う正攻法」**をやります🔑😇
  Cloud Runも「シークレットを環境変数として公開する」公式導線があります。([Google Cloud Documentation][2])

---

## 3) 命名ルール（迷子防止）🏷️🧭

おすすめはこのへん👇（迷子になりにくい）

* **大文字＋アンダースコア**：`LOG_LEVEL`, `PUBLIC_BASE_URL`
* **意味がぶれない名前**：`BASE_URL`より `PUBLIC_BASE_URL`
* **塊（カテゴリ）で揃える**：

  * `DB_HOST`, `DB_PORT`, `DB_NAME`
  * `AUTH_JWT_...`
  * `MAIL_...`

そして超大事👇
**「コードのあちこちで `process.env.X` を直接読まない」**🙅‍♂️
→ “設定読み取り専用の場所（config）” を1個作って、そこだけ見るのが安全です🧯✨

---

## 4) env設計のキモ：「文字列」問題と「起動時チェック」🧪🧱

環境変数は **全部文字列**です😵‍💫
だから `PORT=3000` も `"3000"`。

ここで差が出ます👇

* ✅ **起動時にまとめて読み取り＆検証**（足りない/壊れてるなら即エラー）
* ❌ リクエスト中にその場で読む（壊れてても気づくのが遅い）

---

## 5) ハンズオン：config.ts を作って「設定を外へ」する🛠️✨

以下は **TypeScript向けの“鉄板テンプレ”**です（コピペOK）😋

## 5-1) `.env.example` を用意する📄✨

プロジェクト直下に作る：

```txt
## .env.example（これはGitに入れる）
PORT=3000
PUBLIC_BASE_URL=http://localhost:3000
LOG_LEVEL=info
CORS_ORIGIN=http://localhost:5173
```

そしてローカル用は `.env.local` とかにして **Gitに入れない**🙈

```gitignore
## .env 系は基本コミットしない（例外で .env.example だけOK）
.env*
!.env.example
```

---

## 5-2) Nodeの標準機能で `.env` を読む（dotenv無しでもOK）📦✨

最近のNodeは `.env` を読む仕組みが標準で入っています。
CLIなら `--env-file` / `--env-file-if-exists` が使えます。([Node.js][3])

さらに **コードから読み込む**なら `process.loadEnvFile()` が使えます。([Node.js][4])

`src/bootstrap-env.ts`（最初に必ず実行される場所）を作って👇

```ts
// src/bootstrap-env.ts
import process from "node:process";

if (process.env.NODE_ENV !== "production") {
  try {
    // 例：ローカル専用の env ファイル
    process.loadEnvFile(".env.local");
  } catch {
    // ファイルが無い環境（CI等）では無視でOK
  }
}
```

> ポイント💡：本番では env ファイルが無いのが普通なので、`try/catch` で“無くても死なない”ようにします🙂

---

## 5-3) `src/config.ts`（設定の唯一の入口）を作る🚪🧩

```ts
// src/config.ts
import process from "node:process";

type LogLevel = "debug" | "info" | "warn" | "error";

function mustGet(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

function getNumber(name: string, fallback?: number): number {
  const v = process.env[name];
  if (v == null || v === "") {
    if (fallback != null) return fallback;
    throw new Error(`Missing env: ${name}`);
  }
  const n = Number(v);
  if (!Number.isFinite(n)) throw new Error(`Invalid number env: ${name}=${v}`);
  return n;
}

export const config = {
  nodeEnv: (process.env.NODE_ENV ?? "development") as
    | "development"
    | "production"
    | "test",

  port: getNumber("PORT", 3000),
  publicBaseUrl: mustGet("PUBLIC_BASE_URL"),

  logLevel: (process.env.LOG_LEVEL ?? "info") as LogLevel,

  corsOrigin: process.env.CORS_ORIGIN ?? "",
} as const;
```

---

## 5-4) エントリポイントで “最初にenv → 次にconfig” の順にする🥇

`src/index.ts` みたいな起動ファイルで👇

```ts
import "./bootstrap-env";
import { config } from "./config";
import express from "express";

const app = express();

app.get("/healthz", (_, res) => {
  res.json({ ok: true, env: config.nodeEnv });
});

app.listen(config.port, "0.0.0.0", () => {
  console.log(`[start] ${config.publicBaseUrl} (port=${config.port})`);
});
```

> これで「設定を外から変えられるアプリ」完成！🎉🎉

---

## 6) ローカルでの渡し方（Docker / Compose）🐳🔌

## 6-1) `docker run` で渡す（env-file）📄➡️🐳

```bash
docker run --rm -p 8080:3000 --env-file .env.local your-image:dev
```

## 6-2) `docker compose` で渡す（env_file / environment）🧱✨

Composeは `env_file` でファイルから注入できます。([Docker Documentation][5])

```yaml
services:
  api:
    build: .
    ports:
      - "8080:3000"
    env_file:
      - .env.local
    environment:
      LOG_LEVEL: "debug"
```

> 小技😋：`environment` は上書きに使うと便利！

---

## 7) 本番での渡し方（Cloud Runを例に）☁️🚀

Cloud Runは **サービス設定として環境変数を登録**して、コンテナ起動時に注入します。([Google Cloud Documentation][6])

CLIだとだいたいこんなノリ👇（雰囲気でOK）

```bash
gcloud run services update SERVICE_NAME ^
  --set-env-vars PORT=8080,LOG_LEVEL=info,PUBLIC_BASE_URL=https://example.com
```

そして秘密情報は **Secret Manager連携**が王道で、Cloud Run公式も「シークレットを環境変数として公開」する手順を用意しています。([Google Cloud Documentation][2])
（ここは次章でガッツリやります🔑🔥）

---

## 8) ありがち事故トップ5 😵‍💫🧯

## ① 変数名ミス（`PUBLIC_BASEURL` とか）😭

→ `mustGet()` で **起動時に即死**させるのが正解👍

## ② `PORT` を number にしてない🤯

→ `getNumber()` で変換＆検証！

## ③ 「本番で `.env` を読み込む」前提にしちゃう🙅‍♂️

→ 本番は “環境が注入する” が基本。`--env-file-if-exists` や `try/catch` が効く！([Node.js][3])

## ④ Dockerfile の `ARG` で秘密を渡す💣

`ARG` はイメージ履歴などから漏れる可能性があり危険、という注意が繰り返しされています。([Microsoft for Developers][7])
→ ビルド時の秘密は Docker BuildKit の “build secrets” が公式ルートです。([Docker Documentation][8])

## ⑤ どこでも `process.env` を直読みしてグチャる🍝

→ `config.ts` 以外は触らないルールで一気に治ります😎✨

---

## 9) VS Codeデバッグで環境変数を渡す（超便利）🐞✨

デバッグ構成 `launch.json` では `env` や `envFile` が使えます。([Visual Studio Code][9])

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "API Debug",
      "program": "${workspaceFolder}/dist/index.js",
      "envFile": "${workspaceFolder}/.env.local",
      "env": {
        "LOG_LEVEL": "debug"
      }
    }
  ]
}
```

---

## 10) この章のまとめ📌✨

* **同じイメージを、設定だけ変えて動かす**ために env を設計する🧩
* `config.ts` を作って **起動時に検証**する🧪
* ローカルは `.env.local`、本番は Cloud Run 等の **設定画面/CLIで注入**☁️
* 秘密情報は次章で **Secret Manager/安全な渡し方**へ🔑🔥

---

## コピペ用：AIプロンプト集🤖📋✨

* 「このNode/TSアプリで環境変数に外出しすべき設定値を列挙して。命名案も付けて」
* 「`config.ts` で required/optional を整理して、起動時に落ちるように実装して」
* 「この `.env.example` を見て、足りない設定項目の候補を提案して」
* 「Cloud Runで env を設定する時の“ありがちミス”を10個、原因と対策つきで」

---

次の **第12章（Secrets超入門）🔑🙅** は、ここで触れた「秘密情報をどう安全に扱うか」を **Docker/CI/Cloud Run ぜんぶ繋げて**やります。
続きも同じテンションで作れるよ〜😆🔥

[1]: https://12factor.net/config?utm_source=chatgpt.com "Store config in the environment"
[2]: https://docs.cloud.google.com/run/docs/configuring/services/secrets?utm_source=chatgpt.com "Configure secrets for services | Cloud Run"
[3]: https://nodejs.org/api/cli.html?utm_source=chatgpt.com "Command-line API | Node.js v25.6.1 Documentation"
[4]: https://nodejs.org/en/learn/command-line/how-to-read-environment-variables-from-nodejs?utm_source=chatgpt.com "How to read environment variables from Node.js"
[5]: https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/?utm_source=chatgpt.com "Set environment variables"
[6]: https://docs.cloud.google.com/run/docs/configuring/services/environment-variables?utm_source=chatgpt.com "Configure environment variables for services | Cloud Run"
[7]: https://devblogs.microsoft.com/ise/hidden-risks-of-docker-build-time-arguments-and-how-to-secure-your-secrets/?utm_source=chatgpt.com "The Hidden Risks of Docker Build Time Arguments and ..."
[8]: https://docs.docker.com/build/building/secrets/?utm_source=chatgpt.com "Build secrets"
[9]: https://code.visualstudio.com/docs/debugtest/debugging-configuration?utm_source=chatgpt.com "Visual Studio Code debug configuration"
