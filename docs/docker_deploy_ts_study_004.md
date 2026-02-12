# 第04章：最初の到達点：Cloud Runで“まず公開”を最短でやる🚀

この章は **“まず公開できた！”の成功体験** を最短で作る回だよ😆✨
Dockerfileをガチ最適化するのは後ろの章でやるので、ここでは **最短ルートでWebに出す** ことに集中するね💪

---

## 4.1 この章のゴール🎯✨

この章を終えると、次ができるようになるよ👇

* ✅ 自分のアプリを **Cloud Runにデプロイ**して **URLを発行**できる
* ✅ **公開（誰でもアクセスOK）/ 非公開（認証が必要）** を切り替えられる
* ✅ 「動かない！」ときに **ログを見て原因の当たりを付けられる** 👀

---

## 4.2 ざっくり仕組み（超イメージ）🧠🗺️

最短ルート（ソースからデプロイ）だと流れはこう👇

1. ローカルのソースをアップロード📦
2. Cloud側でビルドされてコンテナイメージになる🏗️
3. そのイメージがレジストリに保存される🏪
4. Cloud Runがそのイメージを起動してURLが出る🌍

この「ソースから一発デプロイ」は `gcloud run deploy --source .` でできるよ、って公式にも書いてあるやつ👍 ([Google Cloud Documentation][1])
（裏側では Cloud Build と Artifact Registry が動く、ってイメージでOK）([Google Cloud Documentation][1])

> もちろん「すでに作ったコンテナイメージをデプロイ」もできるよ（後半で本格的にやるやつ）([Google Cloud Documentation][2])

---

## 4.3 まず「Cloud Runで動く最低条件」だけ押さえる🔑🧯

Cloud Runで初心者が一番ハマるのはココ👇

* **アプリが `0.0.0.0` で待ち受けてない**（`localhost` のままだと外から来れない）
* **`PORT` 環境変数のポートで待ち受けてない**（Cloud Run側が指定するポートでListen必須）

これを守らないと、よくあるこのエラーになる😵
「コンテナが起動したけど `PORT=8080` で待ち受けなかった」みたいなやつ。公式トラブルシュートにも載ってる💥 ([Google Cloud Documentation][3])

### 最小のTypeScript（Express例）✅

（すでに別フレームワークでも考え方は同じだよ👌）

```ts
import express from "express";

const app = express();

app.get("/", (_req, res) => {
  res.status(200).send("Hello from Cloud Run! 🚀");
});

const port = Number(process.env.PORT ?? "8080");

// Cloud Runでは 0.0.0.0 で待つのが大事！
app.listen(port, "0.0.0.0", () => {
  console.log(`Listening on port ${port}`);
});
```

---

## 4.4 ハンズオン：最短でデプロイしてURLを出す🛠️🚀（10ステップ）

ここからは **Windows + PowerShell** で進めるよ🪟✨
（コマンドはコピペでOK👌）

### Step 1：プロジェクトとリージョンを決める🧭

日本なら東京リージョンが扱いやすい（例：`asia-northeast1`）🌸

### Step 2：ログイン＆プロジェクト指定🔐

```powershell
gcloud auth login
gcloud config set project <YOUR_PROJECT_ID>
```

### Step 3：必要なAPIを有効化⚙️

```powershell
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com
```

### Step 4：デプロイ！（ソースから一発）🚀

プロジェクトのルート（`package.json` がある場所）で👇

```powershell
gcloud run deploy <SERVICE_NAME> --source . --region asia-northeast1
```

* 実行すると途中で聞かれることがある👇（環境や設定による）

  * 「認証なしで呼べるようにする？」みたいな質問
  * **最短で動作確認したいなら “Yes”** にするとラク😆

> ちなみに Cloud Runは「呼び出し元IAMチェック（＝認証必須）」が **デフォルトで有効** になってる、って公式にも書いてあるよ。([Google Cloud Documentation][4])

### Step 5：表示されたURLを開いて確認🌍👀

最後に `Service URL: https://...` が出るのでブラウザで開く！

### Step 6：ログを見る📜👀

「動いたけど不安！」ならログ見るのが最速😎
（Cloud ConsoleからでもOK。まずは“見える化”が正義✨）

---

## 4.5 公開/非公開の切り替え（超重要）🔒↔️🌐

ここ、あとで事故りやすいから今のうちに感覚だけ掴もう🧯

### A) 公開（誰でもアクセスOK）にしたい🌐

公式は「**Invoker IAMチェックを無効化するのがおすすめ**」って言ってる👍 ([Google Cloud Documentation][5])

新規デプロイ時にやるなら👇（公式例）

```powershell
gcloud run deploy <SERVICE_NAME> --source . --region asia-northeast1 --no-invoker-iam-check
```

([Google Cloud Documentation][4])

### B) 非公開（認証が必要）にしたい🔒

これがセキュリティ的には基本形。
`gcloud run deploy` に `--no-allow-unauthenticated` を付ける例が公式ブログにもあるよ。([Google Cloud][6])

```powershell
gcloud run deploy <SERVICE_NAME> --source . --region asia-northeast1 --no-allow-unauthenticated
```

---

## 4.6 「最短デプロイ」でよくある詰まりTop5😵‍💫➡️✅

### 1) “PORT=8080 で待ち受けてない”エラー💥

* 原因：`localhost` でlistenしてる / `PORT` を読んでない
* 対策：**`0.0.0.0` + `process.env.PORT`** を使う（4.3のコード）
  公式にも典型例として載ってるよ ([Google Cloud Documentation][3])

### 2) 403/401でアクセスできない🔒

* 原因：非公開設定（認証必須）になってる
* 対策：まず動作確認だけなら `--no-invoker-iam-check` で公開にする
  （公開/非公開の考え方は公式にまとまってる）([Google Cloud Documentation][4])

### 3) ビルドが落ちる（依存やスクリプト）🧱

* 原因：`package.json` の `build/start` が想定と違う、lockfile無い等
* 対策：この章は「動いた」優先でOK。後半章で綺麗に整える👍

### 4) リージョン混乱（どこに作られた？）🌀

* 原因：リージョンを毎回指定してない
* 対策：**リージョンは毎回コマンドに書く**（迷子防止）🧭

### 5) 「お金かかるの怖い」💰😨

Cloud Runは **使った分だけ課金**で、リソース使用は **100ms単位で丸め**って明記されてるよ。([Google Cloud][7])
さらに同時実行（concurrency）で1インスタンスを共有できる、って話も公式にある（ただしこの章では触るだけ）。([Google Cloud][7])

---

## 4.7 ミニ課題（“公開できた”を脳に焼く🔥）📝✨

1. ✅ `/` で文字を返す（HelloでOK）
2. ✅ `PORT` を読んで `0.0.0.0` でlisten
3. ✅ Cloud RunにデプロイしてURLで表示
4. ✅ 公開→非公開→公開を1回ずつ切り替えてみる（触って覚える）🔒↔️🌐

---

## 4.8 AIに投げるコピペ用プロンプト集🤖✨（Copilot/Codex向け）

* 🧠 **ポート対応チェック**

  * 「このNode/TSサーバがCloud Runで動くように、PORT環境変数対応と0.0.0.0待受けに直して。差分で出して」
* 🧯 **Cloud Runの起動失敗ログを読ませる**

  * 「このCloud Runログから“最有力原因”を3つに絞って。各原因の確認手順もつけて」
* 🔒 **公開/非公開の判断**

  * 「個人開発のAPIをCloud Runで公開する。公開（誰でも）と非公開（認証必須）の判断基準を、事故例つきで説明して」

---

次の第5章では、ここで“動いたもの”を **「本番らしいコンテナ」** に整えていくよ🏗️🐳
もし今のリポジトリ構成（`package.json` とフォルダ構成）を貼ってくれたら、この章の手順に合わせて **“そのままコピペで通る deploy コマンド”** に寄せて書き換え案も作れるよ😆👍

[1]: https://docs.cloud.google.com/run/docs/deploying-source-code?utm_source=chatgpt.com "Deploy services from source code | Cloud Run"
[2]: https://docs.cloud.google.com/run/docs/deploying?utm_source=chatgpt.com "Deploying container images to Cloud Run"
[3]: https://docs.cloud.google.com/run/docs/troubleshooting?utm_source=chatgpt.com "Troubleshoot Cloud Run issues"
[4]: https://docs.cloud.google.com/run/docs/authenticating/public?utm_source=chatgpt.com "Allowing public (unauthenticated) access | Cloud Run"
[5]: https://docs.cloud.google.com/run/docs/securing/managing-access?utm_source=chatgpt.com "Access control with IAM | Cloud Run"
[6]: https://cloud.google.com/blog/ja/products/identity-security/securing-cloud-run-deployments-with-least-privilege-access/?utm_source=chatgpt.com "最小権限の原則による Cloud Run のデプロイ保護"
[7]: https://cloud.google.com/run/pricing?utm_source=chatgpt.com "Cloud Run pricing"
