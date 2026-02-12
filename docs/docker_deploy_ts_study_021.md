# 第21章：鍵を置かない認証：OIDCの感覚を掴む 🪪✨

この章は「GitHub Secrets にクラウドの長期キーを置かずに」GitHub Actions から安全にクラウドへアクセスできるようになる回です🔐🚀
ポイントは **OIDC（OpenID Connect）で“短命トークン”をもらう** こと！🧠✨ ([GitHub Docs][1])

---

## この章でできるようになること 🎯

* 「長期キー（JSONキー / Access Key）」を GitHub に置かない運用がわかる🙅‍♂️🔑
* OIDC の流れ（身分証 → 入館証）をイメージできる🪪➡️🎫
* GitHub Actions で **`id-token: write`** を正しく付けて、最小権限で動かせる✅ ([GitHub Docs][2])
* （Cloud Run ルート向け）**GCP Workload Identity Federation** で認証できるようになる☁️🔁 ([GitHub][3])

---

## 1) そもそも「鍵を置かない」って何が嬉しいの？😊🔒

昔ながらのやり方👇

* クラウドでキー発行（例：サービスアカウントキー）
* それを GitHub Secrets に登録
* Actions が毎回そのキーでログイン

これ、地味に怖いです😇💥

* 秘密が漏れたら「誰でもログイン」になりがち
* ローテーション（鍵の更新）も面倒
* 権限が強くなりがち

OIDC だと👇

* GitHub Actions が **その実行ごとに** “身分証（OIDC トークン）” を発行
* クラウド側が「その身分証、信用していい実行？」をチェック
* OK なら **短時間だけ有効なアクセス権（短命トークン）** を渡す

つまり、**盗まれても寿命が短い**＆**そもそも長期キーを置かない**ができる！🧯✨ ([GitHub Docs][1])

---

## 2) OIDC の超ざっくり図解 🗺️✨（身分証→入館証）

イメージはこの4ステップです👇 ([GitHub Docs][1])

1.（事前）クラウド側で「この GitHub のこのリポジトリのこの条件だけ信用する」って信頼関係を作る🤝
2.（実行）Actions 実行ごとに GitHub が OIDC の “身分証（JWT）” を作る🪪
3.（提示）Workflow がその身分証をクラウドへ見せる📨
4.（交換）クラウドが検証して、短命のアクセス権を払い出す🎫⏱️

その身分証には、リポジトリ名・ブランチ・実行者などの **claims（主張情報）** が入ってます🧾
例：`iss` は `https://token.actions.githubusercontent.com`、`sub` や `repository` なども含まれるよ〜📌 ([GitHub Docs][1])

---

## 3) GitHub Actions 側で絶対に必要な設定 ✅🧩

OIDC トークンを要求するには、Workflow か Job に **`id-token: write`** が必須です。これが無いと、OIDC の JWT が取得できません🙅‍♀️ ([GitHub Docs][2])

最小のイメージ👇（だいたいこれでOK）

```yaml
permissions:
  id-token: write   # OIDCトークン取得に必須
  contents: read    # checkoutに必要
```

> これを付けても「GitHub リソースへの書き込み権限」が増えるわけじゃないので安心してOK👌 ([GitHub Docs][2])

---

## 4) ハンズオン：GCP（Cloud Run ルート）で “鍵なし認証” を作る ☁️🔁

ここからは **GCP Workload Identity Federation** の定番手順でいきます💪
（狙い：GitHub Actions → GCP に “短命” で入れるようにする）

## 4-1. GCP 側：Workload Identity Pool / Provider を作る 🏗️

GCP 側は大きく👇

* Workload Identity Pool（受け口）
* Provider（GitHub の発行元を登録）
* Service Account への紐付け（この SA の権限で動く）

作成コマンド例はこんな感じ（公式 Action の手順がまとまってます）👇 ([GitHub][3])

```bash
## 1) サービスアカウント作成（既にあればスキップOK）
gcloud iam service-accounts create "my-service-account" \
  --project "${PROJECT_ID}"

## 2) Workload Identity Pool 作成
gcloud iam workload-identity-pools create "github" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

## 3) Provider 作成（重要：attribute mapping と condition）
gcloud iam workload-identity-pools providers create-oidc "my-repo" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --display-name="My GitHub repo Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == '${GITHUB_ORG}'" \
  --issuer-uri="https://token.actions.githubusercontent.com"
```

💡ここが超大事！

* **attribute mapping**：GitHub の claims を “属性” に写して、後で条件判定できるようにする🧩
* **attribute condition**：Pool への入場条件（例：自分の GitHub Org だけ）をまず狭める🔒 ([GitHub][3])

次に、GitHub から来た外部IDに対して「この Service Account を使っていいよ」を付けます👇 ([GitHub][3])

```bash
gcloud iam service-accounts add-iam-policy-binding \
  "my-service-account@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${REPO}"
```

最後に Provider のリソース名を取り出します（Workflow の `workload_identity_provider` に入れるやつ）👇 ([GitHub][3])

```bash
gcloud iam workload-identity-pools providers describe "my-repo" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --format="value(name)"
```

---

## 4-2. GitHub Actions 側：`google-github-actions/auth` を使う 🤖🔐

`google-github-actions/auth` は「OIDC で GCP にログインする」をやってくれる公式寄りの定番です。
`actions/checkout` が先に必要（`$GITHUB_WORKSPACE` の都合）っていう注意点もあります📌 ([GitHub][3])

最小構成イメージ👇

```yaml
name: build-and-push

on:
  push:
    branches: [ "main" ]

permissions:
  id-token: write
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v3
        with:
          project_id: YOUR_PROJECT_ID
          workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/github/providers/my-repo
          service_account: my-service-account@YOUR_PROJECT_ID.iam.gserviceaccount.com

      - uses: google-github-actions/setup-gcloud@v2

      - name: Docker login for Artifact Registry
        run: gcloud auth configure-docker asia-northeast1-docker.pkg.dev --quiet

      - name: Build
        run: docker build -t asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/YOUR_REPO/app:${{ github.sha }} .

      - name: Push
        run: docker push asia-northeast1-docker.pkg.dev/YOUR_PROJECT_ID/YOUR_REPO/app:${{ github.sha }}
```

> この Action は、後続ツールが使えるように **認証情報ファイルの生成・環境変数エクスポート** も面倒見てくれます（デフォルト動作含む）📦✨ ([GitHub][3])

---

## 5) つまずきポイント Top6 😵‍💫🧯（超あるある）

1. **`id-token: write` を付け忘れ**
   → OIDC トークンが取れないです🙅‍♂️ まずここ確認！ ([GitHub Docs][2])

2. **クラウド側の条件がゆるすぎ or きつすぎ**

* ゆるい：誰でも入れる穴になる😱
* きつい：正規の実行でも弾かれる😇
  → GitHub の claims（`repository`, `ref`, `environment` など）で狭めるのがコツ🧾🔒 ([GitHub Docs][1])

3. **attribute mapping してないのに attribute condition で参照してる**
   → “その属性、存在しないよ” で失敗します💥
   → mapping → condition の順番が大事！ ([GitHub][3])

4. **リポジトリ名（org/repo）が微妙に違う**
   → `principalSet ... attribute.repository/...` のところは特にコピペミス注意✍️ ([GitHub][3])

5. **pull_request 系トリガーで外部PRを混ぜる**
   → “予期しない実行” が起きやすいので、まずは `push`（main）や `workflow_dispatch` に寄せるのが安全🛡️
   （慣れてきたら Environment 保護などもセットで使うと堅いよ）🧱

6. **claims を目で確認したい**
   → GitHub 公式のデバッグ用 Action で “実際に飛ぶ claims” を可視化できます👀 ([GitHub Docs][2])

---

## 6) ミニ課題 🧪✨（手を動かすと一気に理解できる）

## 課題A：最小権限に削る 🪓

* Workflow の `permissions` を必要最小限にする
* 余計な `contents: write` とかが付いてたら削る✂️

## 課題B：クラウド側の条件を1段だけ強くする 🔒

* GCP Provider の `attribute-condition` を
  「Org だけ」→「Org かつ Repo だけ」みたいに狭める（やりすぎ注意！）

## 課題C：自分の “本番” を定義する 🏷️

* `main` ブランチだけOK
* もしくは `environment: prod` を使って `sub` に環境が入る形にする
  （`sub` が認可の軸になる、って感覚が掴めるよ🧠） ([GitHub Docs][1])

---

## 7) Copilot / Codex に投げる用プロンプト集 🤖💬（コピペOK）

* 「この GitHub Actions workflow の `permissions` を最小化して。OIDC 前提で `id-token: write` は必要。危険な権限があれば理由付きで指摘して」
* 「GCP の Workload Identity Federation で、`attribute-condition` と IAM binding を “repo 単位” で絞る設定例を作って」
* 「この workflow が `pull_request` で動く場合のリスクを列挙して、安全寄りのトリガー構成に直して」
* 「OIDC の claims（repository/ref/environment）を使って、クラウド側で信頼条件を絞る設計を提案して」 ([GitHub Docs][2])

---

## 8) まとめ 🏁✨

* OIDC は「長期キーを置かずに、実行ごとの短命トークンで入る」仕組み🪪➡️🎫 ([GitHub Docs][1])
* GitHub 側はまず **`permissions: id-token: write`** が必須✅ ([GitHub Docs][2])
* GCP は **Workload Identity Pool/Provider + 条件 + IAM binding** の3点セットで固まる🔧 ([GitHub][3])

次の章（Provenance / Attestation）に進むと、「誰が作ったイメージか」まで証明できるようになって、CI/CDがさらに強くなるよ〜💪🔥

[1]: https://docs.github.com/en/actions/concepts/security/openid-connect "OpenID Connect - GitHub Docs"
[2]: https://docs.github.com/ja/actions/reference/security/oidc "OpenID Connect リファレンス - GitHub ドキュメント"
[3]: https://github.com/google-github-actions/auth "GitHub - google-github-actions/auth: A GitHub Action for authenticating to Google Cloud."
