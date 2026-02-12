# 第12章：Secrets超入門：焼かない・置かない・漏らさない 🔑🙅

この章はひとことで言うと——
**「秘密（Secrets）で事故らない体質」を作る回**だよ😆✨

---

## 0. この章のゴール 🎯✨

読み終わったら、こんな状態になってれば勝ち🏆

* 「これはSecrets」「これはただの設定」を**サッと線引き**できる👀
* 秘密を **Dockerイメージに入れない**（焼かない🔥）
* 秘密を **Gitに置かない**（置かない📦）
* 秘密を **ログやCIで漏らさない**（漏らさない🗣️💥）
* ついでに、クラウド（例：Cloud Run）での **Secrets注入**もできる☁️🔐 ([Google Cloud Documentation][1])

---

## 1. そもそもSecretsって何？🤔🔐

「漏れたら困るやつ」全部がSecretsだよ💣

## ✅ Secretsの代表例

* DBのパスワード / 接続文字列 🔑
* JWT_SECRET / セッション署名キー 🧾
* APIキー（Stripe / OpenAI / GitHubなど）🪪
* OAuthのクライアントシークレット 🕵️‍♂️
* プライベートnpmのトークン（NPM_TOKEN）📦

## ✅ Secretsじゃない寄り（ことが多い）

* PORT / NODE_ENV / LOG_LEVEL 🔌
* 公開してもいい「ただのURL」🌐
  （ただし“管理画面URL”とかなら怪しいので要注意👀）

---

## 2. 事故が起きる「3大ルート」☠️➡️✅

Secrets事故はだいたいこの3つから起きるよ👇

1. **焼く🔥**：Dockerfileやビルド手順のせいで、イメージに混入
2. **置く📦**：Gitに置いて、pushした瞬間に詰む
3. **漏らす🗣️**：ログ/CI/スクショ/エラー画面に出して終わる

この章はここを全部つぶす💪✨

---

## 3. 焼かない🔥：DockerイメージにSecretsを入れない 🐳🚫

## ❌ よくある「焼きパターン」例 😱

* DockerfileにENVで書く
* DockerfileのARGに入れてRUNで使う
* `.env` や `.npmrc` をCOPYしてあとで消す
  → **消してもレイヤーに残る**ことがあるから危険☠️

---

## ✅ 正解：BuildKitの「Build secrets」を使う 🔐🧰

Dockerの公式にも「ビルド時にSecretsを渡す」やり方がちゃんとあるよ✨
ポイントは **2ステップ**👇

1. **ビルドコマンドでSecretsを渡す**（`docker build --secret ...`）
2. **Dockerfile側で `RUN --mount=type=secret` で受け取る**

公式：Docker Build secrets（シークレットマウント） ([Docker Documentation][2])

---

## ハンズオン：プライベートnpmを安全にインストールする 📦🔑

「npmのトークン」を **イメージに残さず** 使う定番パターンだよ✨
npm公式にも“`--mount=type=secret`で`.npmrc`を渡せ”って書いてある👍 ([docs.npmjs.com][3])

### ① `.npmrc` をローカルに置く（※Gitには置かない）🫥

例（イメージ）：トークンを使う設定が入った`.npmrc`がある想定。

### ② Dockerfile（builder側）でsecret mountしてnpm install

```dockerfile
## syntax=docker/dockerfile:1

FROM node:24-slim AS builder
WORKDIR /app

COPY package.json package-lock.json ./

## .npmrc を secret として一瞬だけ渡して npm ci
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci

COPY . .
RUN npm run build
```

### ③ ビルド時に secret を渡す（ファイルを渡す版）🧰

```powershell
docker build --secret id=npmrc,src=.npmrc -t myapp:build .
```

> `--secret` で「ファイル」や「環境変数」から渡せるのも公式に明記されてるよ✅ ([Docker Documentation][2])

---

## ✅ 覚え方（超大事）🧠✨

* **ビルドで必要な秘密**（例：npmトークン）
  → **Build secrets（BuildKit）**
* **実行時に必要な秘密**（例：DBパスワード、JWT_SECRET）
  → **クラウドのSecrets機能 / Secret Manager / GitHub Secrets**

---

## 4. 置かない📦：GitにSecretsを置かない 🧯🙅‍♂️

## ✅ “ローカルだけ”の秘密ファイル運用 🏠🔐

よくある形👇

* `.env`：自分のPC用（秘密入り）
* `.env.example`：配る用（ダミー）
* `.gitignore`：`.env`は必ず無視

### `.gitignore` に入れる（例）

```gitignore
.env
.env.*
!.env.example

.npmrc
```

> 「`.env`はコミットするな」は鉄板ルールだよ🧨（うっかりが一番多い）

---

## ✅ 置き事故が起きる場所リスト（超あるある）😇

* Issue / PR本文に貼る（ログを貼ったつもりが混入）🧾💥
* スクショに写る（設定画面、CLI出力）📸💀
* サンプルコードに「仮」で入れて、そのまま😵

---

## 5. 漏らさない🗣️：ログとCIでSecretsを出さない 🤖🧯

## ✅ GitHub Actionsは「Secretsを安全に扱う場所」👮‍♂️

GitHub公式のSecretsドキュメントでも、
**最小権限（least privilege）** を強く推してるよ🪓✨ ([GitHub Docs][4])

そしてGitHub公式のセキュリティ注意点として👇

* 「Secretsは変換されたりして、**自動マスクが保証されない**ことがある」
* 「だから運用でリスクを減らせ」
  みたいな話も出てくる⚠️ ([GitHub Docs][5])

---

## ✅ 絶対やる：ログにSecretsを出さない（出しそうならマスク）🙊➡️😷

GitHub Actionsには `add-mask` があるよ👍
（PowerShell例も公式に載ってる） ([GitHub Docs][6])

例：動的に生成した値をマスクしたいとき

```powershell
Write-Output "::add-mask::$env:MY_SECRET"
```

---

## ✅ ActionsでSecretsを使う最小例（雰囲気）🧪

```yaml
name: build

on:
  push:
    branches: [ "main" ]

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build (example)
        run: |
          echo "build..."
        env:
          JWT_SECRET: ${{ secrets.JWT_SECRET }}
```

⚠️ ここで **`echo $JWT_SECRET`** とかやったら即アウト💥
「デバッグしたい気持ち」わかるけど、別のやり方でやろうね🙏

---

## 6. Cloud RunでSecretsを注入する☁️🔐（実行時Secretsの王道）

Cloud RunはSecret ManagerのSecretsを **環境変数として注入**したり、**ファイルとしてマウント**できるよ✨ ([Google Cloud Documentation][1])

## ✅ どっちがいい？（初心者はこの感覚でOK）🧠

* **環境変数**：アプリが扱いやすい（まずこれ）🔌
* **ファイル**：秘密が「ファイルとして必要」なとき（証明書など）📄🔐

---

## ① 環境変数としてSecretsを入れる（gcloud）🚀

Cloud Run公式にある形👇 ([Google Cloud Documentation][1])

```bash
gcloud run deploy SERVICE \
  --image IMAGE_URL \
  --update-secrets=ENV_VAR_NAME=SECRET_NAME:VERSION
```

## ② 既存のSecretsを“入れ替える”（set-secrets）🔄

```bash
gcloud run services update SERVICE \
  --set-secrets="ENV_VAR_NAME=SECRET_NAME:VERSION"
```

## ③ Secret Manager側の権限（最低限ここ）🪪

サービスアカウントに **secretAccessor** を付けるのが基本だよ✅ ([Google Cloud Documentation][1])

---

## 7. つまずきTop3 😵‍💫➡️😆

## ① 「消したのに漏れた」系（COPYしてRUN rmした）🧨

→ レイヤーに残ることがあるから、**そもそも入れない**（Build secretsへ） ([Docker Documentation][2])

## ② Actionsで「マスクされてると思った」😇

→ 自動マスクは保証されない話があるので、
**ログに出さない設計**＋必要なら `add-mask` ([GitHub Docs][5])

## ③ Cloud Runに入れたのにアプリが読めない🤔

→ `dotenv` が「`.env`を上書き」してたり、読み込み順で事故ることがある
（本番は“注入された環境変数をそのまま読む”のが安定👌）

---

## 8. ミニ課題 📝✨（10〜20分）

## 課題A：Secrets候補を洗い出す🔎

* 自分のアプリで「漏れたら困る値」を全部リスト化
* **“権限が取れる系（トークン/パス）”は最優先でSecrets**にする

## 課題B：危険チェックリストを作る🧯

* DockerfileにENV/ARGで秘密を書いてない？🔥
* `.env`や`.npmrc`がGitに入ってない？📦
* Actionsのログに出してない？🗣️

---

## 9. AIに投げる質問テンプレ 🤖💬（コピペOK）

* 「このリポジトリでSecretsになりそうな項目を全部列挙して、理由もつけて」🔍
* 「Dockerfile内でSecretsが混入する可能性がある箇所を指摘して、Build secretsで直して」🐳🔐 ([Docker Documentation][2])
* 「GitHub ActionsでSecretsを使ってるけど、ログ漏洩しないように危険箇所を直して。必要ならadd-maskも入れて」🧯🤖 ([GitHub Docs][6])
* 「Cloud RunにSecret Managerの値を環境変数で注入するgcloudコマンドを、変数名込みで作って」☁️🔐 ([Google Cloud Documentation][1])

---

次の章（第13章）は「ログはstdoutへ：まず“見える化”📜👀」だったよね？
第12章でSecretsの事故ルートを潰したから、次は**安全に観測できる形**にしていこう😆📈

[1]: https://docs.cloud.google.com/run/docs/configuring/services/secrets "Configure secrets for services  |  Cloud Run  |  Google Cloud Documentation"
[2]: https://docs.docker.com/build/building/secrets/ "Secrets | Docker Docs"
[3]: https://docs.npmjs.com/docker-and-private-modules/?utm_source=chatgpt.com "Docker and private modules"
[4]: https://docs.github.com/en/actions/concepts/security/secrets "Secrets - GitHub Docs"
[5]: https://docs.github.com/en/actions/reference/security/secure-use "Secure use reference - GitHub Docs"
[6]: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands?utm_source=chatgpt.com "Workflow commands for GitHub Actions"
