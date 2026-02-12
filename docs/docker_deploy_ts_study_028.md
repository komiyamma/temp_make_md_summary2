# 第28章：Azure Container Apps：似てるけど違うを知る☁️🔁

この章は、「Cloud Runで一回“外に出す”を体験した人」が、**別クラウドでも同じ考え方で動けるようになる**回だよ😆✨
結論から言うと、Container Appsは **“Cloud Runっぽい手軽さ” + “Kubernetesっぽい選択肢”** が同居してる感じ！🧠🛠️

---

## 1) まずは1枚の地図：Cloud Run ↔ Container Apps 対応表🗺️

| やりたいこと        | Cloud Runのイメージ | Container Appsのイメージ                                                 |
| ------------- | -------------- | ------------------------------------------------------------------- |
| 「URLで公開したい」   | Serviceを作って公開  | Container Appで**Ingress**を有効化して公開（外部公開/内部のみ） ([Microsoft Learn][1]) |
| 「新しい版を出したい」   | Revisionができる   | **Revision**ができる（Single/Multiple運用あり） ([Microsoft Learn][2])        |
| 「ちょいずつ切り替えたい」 | トラフィック分割       | リビジョンへ**Traffic splitting**できる ([Microsoft Learn][3])               |
| 「オートスケールしたい」  | リクエストに応じて伸び縮み  | **KEDAベース**で伸び縮み（HTTPやCPUなどでスケール） ([Microsoft Learn][4])            |
| 「ログ見たい」       | Logs/Traceを見る  | Portal/CLIでログをリアルタイム表示できる ([Microsoft Learn][5])                    |

---

## 2) Container Appsの主役3人（ここだけ押さえる）🎭

Container Appsは、ざっくりこの3つを覚えると迷子になりにくいよ🙂✨

* **Container App**：あなたのアプリ本体（Web APIとか）📦
* **Environment**：アプリ達の“敷地”🏡（同じ環境に複数アプリを置ける）
* **Revision**：アプリの“版”📌（デプロイのたびに新しい版ができる、みたいな感覚） ([Microsoft Learn][2])

そして重要ポイント👇
**Ingress（公開設定）はアプリ全体の設定**で、変更は全リビジョンに同時に効く＆新リビジョンは作られないんだ（ここ、Cloud Runと感覚がズレやすい！）😵‍💫 ([Microsoft Learn][1])

---

## 3) ハンズオン：既存イメージを“最短で”公開する🚀🌐

ここは **`az containerapp up`** を使うのが一番ラク！
このコマンドは「リソースグループ作る→環境作る→Log Analytics作る→アプリ作る→外部公開」までまとめてやってくれるよ🙌 ([Microsoft Learn][6])

### 3-1. まずはCLI側の準備🔧

PowerShellでOK👍

```powershell
az login
az extension add --name containerapp --upgrade
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
```

この流れは公式の“upコマンド”手順そのまま💡 ([Microsoft Learn][6])

### 3-2. 公開（外部Ingress + target port指定）🌍

※ `<...>` は自分用に置き換えてね。

```powershell
az containerapp up `
  --name <CONTAINER_APP_NAME> `
  --image <REGISTRY_SERVER>/<IMAGE_NAME>:<TAG> `
  --ingress external `
  --target-port <PORT_NUMBER>
```

* プライベートレジストリなら `--registry-server --registry-username --registry-password` が必要だよ🧷 ([Microsoft Learn][6])
* 成功すると **出力にURLが出る**（ブラウザで開けばOK）🌐 ([Microsoft Learn][6])

---

## 4) つまずきNo.1：ポート問題を“ここで”潰す🔌😵

Container AppsのHTTP公開は、外からは基本 **443(HTTPS)** で来るんだけど、**コンテナが待ち受けるポート（targetPort）**は別だよ⚠️ ([Microsoft Learn][1])

ポイントはこれ👇

* `--target-port` は **コンテナがlistenしてるポート**を指定する🎯 ([Microsoft Learn][1])
* `--target-port` を省略すると自動検出されることもあるけど、
  **複数ポートが開いてると自動で決められず失敗しやすい**（だから最初は明示が安心）😇 ([Microsoft Learn][1])
* もしあとからIngressを有効化するなら👇（コマンドもあるよ）

  ```powershell
  az containerapp ingress enable `
    --name <app-name> `
    --resource-group <resource-group> `
    --target-port <target-port> `
    --type external
  ```

  ([Microsoft Learn][1])

---

## 5) ログを見る（最短のデバッグ眼👀）📜

「動かん！😇」のときは、まずログを見よう。Container AppsはCLIでリアルタイム表示できるよ🔥 ([Microsoft Learn][5])

### 5-1. システムログ（基盤側）🧠

```powershell
az containerapp logs show `
  --name <CONTAINER_APP_NAME> `
  --resource-group <RESOURCE_GROUP> `
  --type system `
  --follow
```

([Microsoft Learn][5])

### 5-2. コンソールログ（アプリのstdout）🗣️

```powershell
az containerapp logs show `
  --name <CONTAINER_APP_NAME> `
  --resource-group <RESOURCE_GROUP> `
  --type console `
  --follow
```

([Microsoft Learn][5])

さらに「どのリビジョン見てるの？」って時は、リビジョン一覧も取れるよ👇 ([Microsoft Learn][5])

```powershell
az containerapp revision list `
  --name <CONTAINER_APP_NAME> `
  --resource-group <RESOURCE_GROUP> `
  --query "[].name"
```

---

## 6) “設定”の扱い：環境変数とSecrets（設計超入門の実戦版）🧩🔐

### 6-1. 環境変数を入れる（あとから変更）✍️

```powershell
az containerapp update `
  --name <CONTAINER_APP_NAME> `
  --resource-group <RESOURCE_GROUP> `
  --set-env-vars "NODE_ENV=production" "LOG_LEVEL=info"
```

([Microsoft Learn][2])

「ビルドしたイメージは同じ、設定だけ変える」をここで体に入れる感じ💪✨

### 6-2. Secretsを使う（値をコードに書かない！）🙅‍♂️🔑

Secretsは `--secrets` で定義できて、環境変数から `secretref:` で参照できるよ👇 ([Microsoft Learn][7])

```bash
az containerapp create \
  --resource-group "my-resource-group" \
  --name myQueueApp \
  --environment "my-environment-name" \
  --image demos/myQueueApp:v1 \
  --secrets "queue-connection-string=<CONNECTION_STRING>" \
  --env-vars "ConnectionString=secretref:queue-connection-string"
```

さらに上級だけど、**Key Vault参照**もできる（個人開発でも“事故らない”側に寄せられる）🔒 ([Microsoft Learn][7])

---

## 7) リビジョン運用：ロールバックが“楽になる”コツ🔁🛟

Container Appsは「デプロイ＝新リビジョン」が基本の世界🌱
**Single / Multiple** のモードがあって、Multipleにするとトラフィックを分けて段階移行できるよ。 ([Microsoft Learn][8])

ただし注意👇
Ingress設定みたいな**アプリ全体設定**は「全リビジョンに一気に効く」ので、リビジョン切り替えとは別物だよ⚠️ ([Microsoft Learn][1])

---

## 8) スケール：Cloud Runの“同時実行っぽい”感覚を持ち込む📈💰

Container AppsはKEDAを使ってスケールする設計で、HTTPやCPUなどの条件で伸び縮みできるよ📌 ([Microsoft Learn][4])

初心者向けの“まずの型”はこれ👇（例：最小0〜最大3）

* **minReplicas=0**（アクセスなければ縮む）
* **maxReplicas=3**（暴走しない上限）
* HTTPの同時リクエスト数などをトリガーにする（考え方として） ([Microsoft Learn][4])

---

## 9) よくある詰まりTop5（先にワナを踏み抜く🪤😂）

1. **target port間違い**（コンテナがlistenしてるポートとズレる）🔌
2. **複数ポートが開いてて自動検出が効かない** → `--target-port` を明示🎯 ([Microsoft Learn][1])
3. **Ingress変えたらリビジョンで切り戻せると思った** → それはアプリ全体に効くやつ😇 ([Microsoft Learn][1])
4. **SecretsをDockerfileやGitに入れちゃう** → `--secrets` + `secretref:`へ避難🧯 ([Microsoft Learn][7])
5. **ログを見てない** → `az containerapp logs show --follow` が最短の目👀 ([Microsoft Learn][5])

---

## 10) ミニ課題✅（“移植性チェック”で理解が固定される）

**課題：Cloud Runで動かしたイメージを、そのままContainer Appsで動かす**🧳✨

* 同じ `ghcr.io/...` などのイメージを `az containerapp up --image ...` でデプロイ
* `--target-port` だけ合わせる
* ログで起動確認
* 余裕があれば `az containerapp update --set-env-vars` で設定だけ変えて挙動が変わるのを確認🧪 ([Microsoft Learn][6])

---

## 11) AIに投げる用プロンプト（コピペOK🤖✨）

* 「このDockerイメージのアプリがlistenしてるポートを推測して、Container AppsのtargetPort候補を出して」
* 「Cloud Runの設定（環境変数/ヘルスチェック/同時実行）を、Container Appsの設定に“概念対応”で変換して」
* 「Container Appsで起動失敗した。以下のログから原因候補を3つと、確認コマンドを出して」

---

この第28章が終わると、「Cloud Runで学んだ“デプロイ脳”がクラウドをまたいでも通用する」って感覚がかなり強くなるよ💪😆☁️

次の第29章（ECS+Fargate）は、Container Appsより“管理が増える世界”に入るから、ここで**“手軽系”の比較軸**を作っておくとめっちゃ効く🔥

[1]: https://learn.microsoft.com/en-us/azure/container-apps/ingress-how-to "Configure Ingress for your app in Azure Container Apps | Microsoft Learn"
[2]: https://learn.microsoft.com/en-us/azure/container-apps/environment-variables "Manage environment variables on Azure Container Apps | Microsoft Learn"
[3]: https://learn.microsoft.com/en-us/azure/container-apps/traffic-splitting?utm_source=chatgpt.com "Traffic splitting in Azure Container Apps | Microsoft Learn"
[4]: https://learn.microsoft.com/en-us/azure/container-apps/scale-app?utm_source=chatgpt.com "Set scaling rules in Azure Container Apps"
[5]: https://learn.microsoft.com/ja-jp/azure/container-apps/log-streaming "Azure Container Apps でログ ストリームを表示する | Microsoft Learn"
[6]: https://learn.microsoft.com/en-us/azure/container-apps/containerapp-up "Deploy Azure Container Apps with the az containerapp up Command | Microsoft Learn"
[7]: https://learn.microsoft.com/en-us/azure/container-apps/manage-secrets "Manage secrets in Azure Container Apps | Microsoft Learn"
[8]: https://learn.microsoft.com/en-us/azure/container-apps/revisions?utm_source=chatgpt.com "Update and deploy changes in Azure Container Apps"
