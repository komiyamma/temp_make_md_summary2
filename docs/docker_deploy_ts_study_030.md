# 第30章：1クリックデプロイ完成：push→自動でWeb更新 🤖🚀

この章は「卒業制作」だよ！🎉
**GitHub に push したら、自動でコンテナがビルドされて、Web（Cloud Run）に反映される**ところまでを“完成形”として作るよ 🐳➡️🌍✨
（Node は **v24 が Active LTS / v25 が Current** の最新状態を前提に進めるね）([nodejs.org][1])

---

## 30.0 今日つくる完成物（ゴールの絵）🗺️✨

できあがる流れはこれ👇

1. `main` に push 🧑‍💻➡️📦
2. **GitHub Actions** が動く ⚙️
3. Docker イメージをビルドして **Artifact Registry** に push 🐳📤
4. **Cloud Run** にデプロイ（新しい Revision が作られる）🚀
5. URL を開くと、新しい版が動いてる 😆🌐

ポイントはここ👇

* **毎回クリックで操作しない**（push がスイッチ）🔘
* **“どの版が本番か”が即答できる**（タグ運用）🏷️
* **鍵（長期キー）を置かずに安全に認証**（OIDC/WIF）🪪✨([GitHub][2])

---

## 30.1 “卒業制作の仕様”を先に決めよう（ミニ設計）✍️🧠

ここだけ先に決めると、その後ぜんぶ迷子にならないよ🧭

* **サービス名**：例 `my-api`
* **リージョン**：例 `asia-northeast1`（東京）🗼
* **公開/非公開**：とりあえず **公開（unauthenticated）** でOK（個人API想定）🌍
* **エンドポイント**

  * `/` : 動作確認
  * `/healthz` : ヘルスチェック用 🩺
* **環境変数**

  * `PORT`（Cloud Run 側が渡す）
  * `NODE_ENV=production`
  * `APP_VERSION`（デプロイした版を表示できると最高）🏷️

---

## 30.2 アプリ最終仕上げ（“本番で死なない”最低ライン）🧯✨

最低限ここができてると、本番が一気に安定するよ！

* `0.0.0.0` で待ち受ける（コンテナ外から入れる）🌐
* `PORT` 環境変数で起動できる 🔌
* `/healthz` を返す 🩺
* SIGTERM を受けたらキレイに終わる（Graceful shutdown）🧯⏳

例（Express）👇

```ts
// src/server.ts
import express from "express";

const app = express();

app.get("/", (_req, res) => {
  res.json({ ok: true, message: "Hello from Cloud Run!", version: process.env.APP_VERSION ?? "dev" });
});

app.get("/healthz", (_req, res) => {
  res.status(200).send("ok");
});

const port = Number(process.env.PORT ?? 8080);
const host = "0.0.0.0";

const server = app.listen(port, host, () => {
  console.log(`[boot] listening on http://${host}:${port}`);
});

// Graceful shutdown（Cloud Run は停止時に SIGTERM を送ることが多い）
process.on("SIGTERM", () => {
  console.log("[shutdown] SIGTERM received");
  server.close(() => {
    console.log("[shutdown] http server closed");
    process.exit(0);
  });

  // 念のためタイムアウト（詰まったら諦めて終わる）
  setTimeout(() => {
    console.log("[shutdown] forced exit");
    process.exit(1);
  }, 10_000).unref();
});
```

🤖AI（Copilot / OpenAI Codex など）に投げるなら：

* 「Express の `/healthz` と SIGTERM 対応を最小改修で入れて」
* 「`APP_VERSION` をレスポンスに含めて、デプロイ版が分かるようにして」

---

## 30.3 Dockerfile を“卒業制作版”にする 🐳🧱✨

ここは「サイズ最適化」より **“事故らない構成”** を優先するよ！

**マルチステージ（build → runtime）**の例👇
（Node 24 系を想定）([nodejs.org][1])

```dockerfile
## ---------- build ----------
FROM node:24-bookworm-slim AS build
WORKDIR /app

## 依存だけ先に入れてキャッシュを効かせる
COPY package*.json ./
RUN npm ci

## ソース投入 → ビルド
COPY . .
RUN npm run build

## ---------- runtime ----------
FROM node:24-bookworm-slim AS runtime
WORKDIR /app

ENV NODE_ENV=production

## 本番依存だけ
COPY package*.json ./
RUN npm ci --omit=dev

## build成果物だけ持ってくる
COPY --from=build /app/dist ./dist

## Cloud Run は PORT を渡してくれる
EXPOSE 8080
CMD ["node", "dist/server.js"]
```

`.dockerignore` も忘れずに（速度と安全の地味王👑）：

```txt
node_modules
dist
.git
.gitignore
Dockerfile
docker-compose.yml
npm-debug.log
.env
.vscode
```

---

## 30.4 まずは手動で “初回デプロイ” を通す（儀式）🔥✅

いきなり自動化に突っ込むと、どこで詰まったか分からなくなる率が上がる😵
だから **最初だけ手で通す**よ！

Cloud Run は **コンテナイメージを取り込んで Revision として保持**する仕組みがあるので、デプロイの挙動もつかみやすいよ。([GitHub Docs][3])

---

## 30.5 Google Cloud 側の準備（PowerShell コピペ用）☁️🛠️

以下は “置き換え式” でいくよ（`YOUR_...` を自分の値にするだけ）✍️

```powershell
## ===== 自分の値に変更してね =====
$PROJECT_ID   = "YOUR_GCP_PROJECT_ID"
$REGION       = "asia-northeast1"
$SERVICE      = "my-api"
$AR_REPO      = "containers"
$SA_NAME      = "gha-deployer"

$GITHUB_ORG   = "YOUR_GITHUB_OWNER"      # GitHubのユーザー名 or Organization
$GITHUB_REPO  = "YOUR_GITHUB_REPO_NAME"  # リポジトリ名
$FULL_REPO    = "$GITHUB_ORG/$GITHUB_REPO"

## ===== 1) プロジェクト設定 =====
gcloud config set project $PROJECT_ID

## ===== 2) API有効化 =====
gcloud services enable run.googleapis.com artifactregistry.googleapis.com iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com

## ===== 3) Artifact Registry（Dockerリポジトリ）作成 =====
gcloud artifacts repositories create $AR_REPO `
  --repository-format=docker `
  --location=$REGION `
  --description="Docker images for Cloud Run"

## ===== 4) デプロイ用サービスアカウント作成 =====
gcloud iam service-accounts create $SA_NAME `
  --display-name="GitHub Actions deployer"

$SA_EMAIL = "$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

## ===== 5) 権限付与（最低限スタート） =====
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$SA_EMAIL" `
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$SA_EMAIL" `
  --role="roles/iam.serviceAccountUser"

gcloud artifacts repositories add-iam-policy-binding $AR_REPO `
  --location=$REGION `
  --member="serviceAccount:$SA_EMAIL" `
  --role="roles/artifactregistry.writer"
```

---

## 30.6 GitHub Actions から安全に認証する（OIDC / Workload Identity Federation）🪪🔐✨

“長期キーをGitHubに置かない”やつね！最高にえらい👏
GitHub Actions は **OIDC トークン**を発行できて、それを使ってクラウド側で安全に認証できるよ。([GitHub][2])

Google 側では **Workload Identity Pool / Provider** を作るよ。
重要：**Attribute Condition を必ず付けて入口を絞る**（ここ超大事！）([GitHub][4])

```powershell
## ===== 6) Workload Identity Pool 作成 =====
gcloud iam workload-identity-pools create "github" `
  --project="$PROJECT_ID" `
  --location="global" `
  --display-name="GitHub Actions Pool"

## Pool のフルID取得
$POOL_FULL = gcloud iam workload-identity-pools describe "github" `
  --project="$PROJECT_ID" `
  --location="global" `
  --format="value(name)"

## ===== 7) Provider 作成（ORGで入口制限） =====
gcloud iam workload-identity-pools providers create-oidc "my-repo" `
  --project="$PROJECT_ID" `
  --location="global" `
  --workload-identity-pool="github" `
  --display-name="My GitHub repo Provider" `
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" `
  --attribute-condition="assertion.repository_owner == '$GITHUB_ORG'" `
  --issuer-uri="https://token.actions.githubusercontent.com"

## Provider のフルID取得（GitHub Actions YAMLで使う）
$PROVIDER_FULL = gcloud iam workload-identity-pools providers describe "my-repo" `
  --project="$PROJECT_ID" `
  --location="global" `
  --workload-identity-pool="github" `
  --format="value(name)"

## ===== 8) このリポジトリだけが $SA_EMAIL を使えるように紐付け =====
gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL `
  --project="$PROJECT_ID" `
  --role="roles/iam.workloadIdentityUser" `
  --member="principalSet://iam.googleapis.com/$POOL_FULL/attribute.repository/$FULL_REPO"

## 表示（あとでGitHubに登録する）
"SA_EMAIL=$SA_EMAIL"
"PROVIDER_FULL=$PROVIDER_FULL"
```

この作り方（issuer-uri / attribute-mapping / attribute-condition / principalSet）は公式の考え方に沿ってるよ。([GitHub][4])

---

## 30.7 GitHub 側の設定（Secrets/Variables）🧰🔧

GitHub のリポジトリで👇を登録する（Actions 用）：

* `GCP_PROJECT_ID`：`YOUR_GCP_PROJECT_ID`
* `GCP_REGION`：`asia-northeast1`
* `AR_REPO`：`containers`
* `CLOUD_RUN_SERVICE`：`my-api`
* `WIF_PROVIDER`：`projects/.../workloadIdentityPools/.../providers/...`
* `WIF_SERVICE_ACCOUNT`：`gha-deployer@...iam.gserviceaccount.com`

※ `WIF_PROVIDER` と `WIF_SERVICE_ACCOUNT` は秘密じゃないけど、まとめて Secrets に入れてもOK👍

---

## 30.8 ここが本体！GitHub Actions（build → push → deploy）⚙️🐳🚀

`/.github/workflows/deploy.yml` を作るよ👇
`google-github-actions/deploy-cloudrun@v3` は **コンテナイメージを指定して Cloud Run にデプロイ**できる（URL も output で取れる）([GitHub][5])
`auth@v3` は WIF で認証できるよ。([GitHub][4])

```yaml
name: deploy-cloudrun

on:
  push:
    branches: ["main"]

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest

    env:
      PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
      REGION: ${{ secrets.GCP_REGION }}
      AR_REPO: ${{ secrets.AR_REPO }}
      SERVICE: ${{ secrets.CLOUD_RUN_SERVICE }}

    steps:
      - uses: actions/checkout@v4

      # 1) OIDC/WIFでGoogleにログイン（鍵いらない）
      - id: auth
        uses: google-github-actions/auth@v3
        with:
          project_id: ${{ secrets.GCP_PROJECT_ID }}
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      # 2) gcloudセットアップ
      - uses: google-github-actions/setup-gcloud@v2

      # 3) Artifact Registry へ push できるように docker login 相当を設定
      - name: Configure Docker auth
        run: gcloud auth configure-docker ${{ env.REGION }}-docker.pkg.dev --quiet

      # 4) build & push（タグは SHA を本命にする）
      - name: Build and Push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.AR_REPO }}/${{ env.SERVICE }}:${{ github.sha }}
            ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.AR_REPO }}/${{ env.SERVICE }}:main

      # 5) Cloud Runへデプロイ（SHAタグを指定）
      - id: deploy
        uses: google-github-actions/deploy-cloudrun@v3
        with:
          service: ${{ env.SERVICE }}
          region: ${{ env.REGION }}
          image: ${{ env.REGION }}-docker.pkg.dev/${{ env.PROJECT_ID }}/${{ env.AR_REPO }}/${{ env.SERVICE }}:${{ github.sha }}
          flags: >-
            --set-env-vars=APP_VERSION=${{ github.sha }},NODE_ENV=production

      # 6) 軽いスモークテスト（/healthz が返るか）
      - name: Smoke test
        run: curl -fsS "${{ steps.deploy.outputs.url }}/healthz"
```

補足（めっちゃ大事）💡

* Cloud Run は **タグ（例: main）を digest に解決して使う**ので、**本命は SHA タグ**にすると「どの版が本番？」が一瞬で分かるよ🏷️
* `deploy-cloudrun` は Node 24 で動くので、もし self-hosted runner を使うなら runner バージョン要件に注意ね。([GitHub][5])

---

## 30.9 “公開設定”は最初だけ手でやるのが楽 👍🌍

Cloud Run の推奨として、CI/CD が **「公開/非公開をいじる」**のは避けよう、って考え方があるよ（権限事故を減らすため）([GitHub][5])
なので最初だけ手で公開にして、以後はデプロイしても公開状態を維持…がラク！

（例：gcloud で公開にするなら IAM で `allUsers` に `roles/run.invoker` を付けるやつ）

---

## 30.10 動作確認チェックリスト（卒業判定）✅🎓✨

* Actions が通ってる ✅
* Cloud Run の URL が出る ✅
* `/` が返る ✅
* `/healthz` が 200 ✅
* `APP_VERSION` が `github.sha` になってる ✅（版が見える！）🏷️
* Cloud Run のログに `boot` が出てる ✅📜

Cloud Run は **Revision 単位でイメージを保持してくれる**ので、「戻す」もやりやすいよ。([GitHub Docs][3])

---

## 30.11 つまずきTop10 😵‍💫🔧

1. **Cloud Run で 502 / 起動しない**

   * `PORT` を見てない、`0.0.0.0` じゃない、起動が遅すぎる…が多い
2. **Artifact Registry に push できない（権限）**

   * `roles/artifactregistry.writer` が足りない
3. **OIDC が通らない**

   * `permissions: id-token: write` が無いと詰む（これ超多い）([GitHub][5])
4. **WIF Provider の attribute-condition が雑で弾かれる**

   * ORG 名のミス、repo owner 違い
5. **principalSet の repo 名が間違ってる**

   * `owner/repo` の形が崩れてる
6. **`region-docker.pkg.dev` の region がズレてる**

   * Artifact Registry のリージョンと一致させる
7. **タグ `main` だけで運用して “どれが本番？”が迷子**

   * SHA タグ本命で！🏷️
8. **`--set-env-vars` が上書き事故**

   * 重要な env を消してないか確認
9. **Cloud Run の公開設定が意図せず変わる**

   * “最初だけ手で公開”が安定([GitHub][5])
10. **自動化前にローカルで動いてない**

* まずコンテナで `docker run` して `/healthz` を叩くのが最強🧪🐳
* 「push 前にテストする」考え方も公式で推奨があるよ。([Docker Documentation][6])

---

## 30.12 仕上げ（テンプレ化して“毎回これ”にする）📦✨

最後に“個人開発の最強テンプレ”に寄せるなら👇が効く！

* **リポジトリを Template 化**（新規開発は複製で開始）🧬
* `README` に「手順 3 行」だけ書く（未来の自分を救う）📝
* Actions に `concurrency` を入れて多重デプロイ事故を防ぐ 🔁🛑
* `main` 直push じゃなく PR → merge にする（落ち着く）🧘

🤖AIに投げるなら：

* 「この workflow をテンプレとして使う前提で、再利用しやすい変数設計に直して」
* 「この構成で起きがちなセキュリティ事故を、優先度順に潰す提案をして」

---

## 30.13 ボーナス：Cloud Run 側で “リポジトリから継続デプロイ” もあるよ 🎁🔁

「GitHub Actions を組むのも楽しいけど、もっとマネージドに寄せたい」なら
Cloud Run には **リポジトリ連携で継続的デプロイ**のルートも用意されてるよ。([Google Cloud Documentation][7])

---

ここまで通ったら、もう「push → Web更新」は“体に入った”はず！🎓🔥
次はこのテンプレに **DB（Cloud SQL / Neon / Supabase など）**を繋いで、環境変数・Secrets・マイグレーションまで含めた“個人開発の完成形”に育てると、さらに無敵になるよ💪😆

[1]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[2]: https://github.com/actions/checkout "GitHub - actions/checkout: Action for checking out a repo"
[3]: https://docs.github.com/ja/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-google-cloud-platform "Google Cloud Platform での OpenID Connect の構成 - GitHub ドキュメント"
[4]: https://github.com/google-github-actions/auth "GitHub - google-github-actions/auth: A GitHub Action for authenticating to Google Cloud."
[5]: https://github.com/google-github-actions/deploy-cloudrun "GitHub - google-github-actions/deploy-cloudrun: A GitHub Action for deploying services to Google Cloud Run."
[6]: https://docs.docker.com/build/ci/github-actions/test-before-push/?utm_source=chatgpt.com "Test before push with GitHub Actions"
[7]: https://docs.cloud.google.com/run/docs/quickstarts/deploy-continuously "Quickstart: Deploy to Cloud Run from a Git repository  |  Google Cloud Documentation"
