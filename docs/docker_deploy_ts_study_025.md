# 第25章：Cloud Run “最短デプロイ回”：まず公開して勝つ 🏁

この章は「**すでにコンテナ化できてるNode/TSアプリ**」を、**Cloud RunでURL公開**まで一気に持っていく回だよ😆✨
Cloud Runは「指定したコンテナイメージをデプロイするだけ」でサービスになるのが強み！しかもデプロイ時にCloud Run側がイメージを取り込んで保持する仕組みだから、起動のたびにレジストリから毎回pullされる前提で考えなくてOK🙆‍♂️📦 ([Google Cloud Documentation][1])

---

## この章のゴール🎯

* Cloud Runに**新しいサービス**を作って公開URLを得る🌍
* **環境変数**を渡して動かす🧩
* **ログを見て**「動いてる！」を確認する👀📜

---

## 0) まず“Cloud Runの約束事”だけ押さえる🤝🧠

## ポートはここが重要！🔌

Cloud Runはコンテナに `PORT` 環境変数を渡してくるよ。HTTPサーバは **そのPORTで待ち受け**する必要がある（例：`8080`）📌 ([Google Cloud Documentation][2])

> つまりアプリ側は「`process.env.PORT` を読む」＆「`0.0.0.0`でlisten」が基本（第6章の復習だね）😉

---

## 1) Google Cloud側：プロジェクトとAPIを準備する🧰☁️

## コンソールでやること🖱️

1. プロジェクト作成（＋課金アカウント紐付け）💳
2. **Cloud Run** と **Artifact Registry** を有効化✅

   * 画面操作で有効化する流れの例（API Library → Enable） ([Google Cloud Documentation][3])
   * Artifact Registryの有効化について ([Google Cloud Documentation][4])

> ここで詰まりがちなのは「課金が無いと作れない系」😵💦（エラーが出たらまず課金を疑う！）

---

## 2) Artifact Registry：イメージ置き場を作る🏪📦

Cloud Runは **Artifact Registryのイメージ**をそのまま使えるよ🙌
（他レジストリもいけるけど、最短ならここがラク） ([Google Cloud Documentation][5])

## 置き場（リポジトリ）を作る

* コンソールで作る手順（Repositories → Create） ([Google Cloud Documentation][6])
* 「Docker形式」「Standard」「リージョン」を選ぶのが基本✨ ([Google Cloud Documentation][7])

---

## 3) ローカルからpush：最短でイメージを置く📤🐳

## 3-1. Docker認証を通す🔐

Artifact Registryへpushするには、DockerがGoogle認証で喋れる必要があるよ。

```powershell
gcloud auth login
gcloud auth configure-docker <REGION>-docker.pkg.dev
```

`gcloud auth configure-docker` はDocker設定を更新して認証できるようにするコマンドだよ🧩 ([Google Cloud Documentation][7])

---

## 3-2. タグ付け→push🏷️➡️📦

Artifact RegistryのイメージURLはこの形👇（覚えゲー！）

`LOCATION-docker.pkg.dev/PROJECT_ID/REPO_NAME/IMAGE:TAG` ([Google Cloud Documentation][8])

例（雰囲気）：

```powershell
docker tag myapp:local <REGION>-docker.pkg.dev/<PROJECT_ID>/<REPO_NAME>/myapp:v1
docker push <REGION>-docker.pkg.dev/<PROJECT_ID>/<REPO_NAME>/myapp:v1
```

push/pull手順の公式ガイドもここにまとまってるよ📚 ([Google Cloud Documentation][9])

---

## 4) Cloud Runにデプロイ！🚀🌐（最短ルート）

Cloud Runは**デフォルトで「非公開」**（認証必須）になってるよ。公開したい場合は設定が必要🔒→🌍 ([Google Cloud Documentation][10])

## 4-1. gcloudで一発デプロイ（おすすめ）⚡

```powershell
gcloud run deploy <SERVICE_NAME> `
  --image <REGION>-docker.pkg.dev/<PROJECT_ID>/<REPO_NAME>/myapp:v1 `
  --region <REGION> `
  --allow-unauthenticated
```

* `--allow-unauthenticated` を付けると「公開サービス」になる（public API/website向け）🌍 ([Google Cloud Documentation][1])
* もし付けないと、実行時に公開するか確認を求められる動きになるよ📝 ([Google Cloud Documentation][1])

> 「公開したくない」なら `--no-allow-unauthenticated` で明示的に閉じるのもアリ🔒 ([Google Cloud Documentation][1])

---

## 4-2. 公開設定を後から変える（コンソール派向け）🖱️

「Security」タブで **Allow public access** にできるよ。手順の流れはこれ👇 ([Google Cloud Documentation][8])

---

## 4-3. 環境変数を渡す（最低限だけ）🧩

例：APIの動作モードや外部URLなど

```powershell
gcloud run deploy <SERVICE_NAME> `
  --image <IMAGE_URL> `
  --region <REGION> `
  --allow-unauthenticated `
  --set-env-vars NODE_ENV=production,APP_ENV=prod
```

※Cloud Runはコンテナへ環境変数を渡せる（`PORT` もそのひとつ）🔌 ([Google Cloud Documentation][2])

---

## 5) 動作確認：URLを取り出して叩く🧪✅

## 5-1. サービスURLを取得する🔎

```powershell
gcloud run services describe <SERVICE_NAME> --region <REGION> --format "value(status.url)"
```

この形でURLが取れるよ🌍 ([Google Cloud Documentation][11])

## 5-2. 叩く（curl）🎯

```powershell
curl "<URL>/healthz"
```

（`/healthz` は第15章で作った想定。無ければトップや適当なAPIでOK！）

---

## 6) ログを見る：Cloud Runの“目”を手に入れる👀📜

* Cloud Runは「stdout/stderrに出たログ」を基本の観測軸にしやすい構造になってるよ（運用の入口！）
* コンソールのCloud Runサービス画面からログを見て、「リクエスト来た？」を確認しよう👣

※ローカルでCloud Runサービスをテストする話（環境変数 `K_REVISION` など）も公式にまとまってるよ🧪 ([Google Cloud Documentation][12])

---

## つまずきTop10😵‍💫➡️😆（最短デプロイ編）

1. **「起動したのにアクセスできない」**
   → まず「非公開のまま」じゃない？（Cloud Runはデフォルト非公開）🔒 ([Google Cloud Documentation][10])

2. **「403/401」**
   → 公開したいなら `--allow-unauthenticated`（or コンソールでAllow public access）🌍 ([Google Cloud Documentation][1])

3. **「コンテナが起動即落ち」**
   → `PORT` を読んでない / `0.0.0.0` でlistenしてない疑い🔌 ([Google Cloud Documentation][2])

4. **「イメージが見つからない / pull権限が無い」**
   → Artifact RegistryとCloud Runの権限（Reader等）を確認🧾 ([Google Cloud Documentation][5])

5. **「レジストリpushが通らない」**
   → `gcloud auth configure-docker` をやり直す🔐 ([Google Cloud Documentation][7])

6. **「どのURLを叩けばいい？」**
   → `gcloud run services describe ... value(status.url)` で取る🌍 ([Google Cloud Documentation][11])

7. **「公開URLが毎回変わる？」**
   → Cloud RunのURLの考え方がある（サービスURLの説明）📌 ([Google Cloud Documentation][11])

8. **「コンソールでどこから作るの？」**
   → Services → Deploy container（手順の導線あり）🖱️ ([Google Cloud Documentation][13])

9. **「IAMの公開設定が組織ポリシーで禁止」**
   → allUsers付与が制限されるケースがある（ドキュメント注意書き）⚠️ ([Google Cloud Documentation][8])

10. **「え、Cloud Runってpullしないの？」**
    → デプロイ時に取り込んだイメージのコピーを使う仕組みだよ📦 ([Google Cloud Documentation][1])

---

## Copilot/Codexに投げる“勝ちプロンプト”集🤖✨

* 「Cloud Runで動くように、Expressのlistenを `process.env.PORT` と `0.0.0.0` 前提に直して。差分パッチで」🔌
* 「Cloud Run用に、起動ログとリクエスト1行ログを最小で入れて」📜
* 「この環境変数一覧から、本番で必須・任意を分類して、Cloud Runの `--set-env-vars` 形式に整形して」🧩
* 「`gcloud run deploy` のコマンドを、リージョンとイメージURLと公開設定込みで作って」🚀

---

## この章のミニ課題🎒✅

1. Cloud Runにデプロイして **URLが出る**🎉
2. `curl` で叩いて **レスポンスが返る**🎯
3. Cloud Runのログで **リクエストが記録されてる**👀📜

---

## 次章へのつなぎ🧭

次は「**スケールと同時実行**」で、**料金💰と性能📈**の調整ツマミを触っていくよ！（第26章）😆

[1]: https://docs.cloud.google.com/run/docs/deploying?utm_source=chatgpt.com "Deploying container images to Cloud Run"
[2]: https://docs.cloud.google.com/run/docs/container-contract?utm_source=chatgpt.com "Container runtime contract | Cloud Run"
[3]: https://docs.cloud.google.com/endpoints/docs/openapi/enable-api?utm_source=chatgpt.com "Enabling an API in your Google Cloud project"
[4]: https://docs.cloud.google.com/artifact-registry/docs/enable-service?utm_source=chatgpt.com "Enable and disable the service | Artifact Registry"
[5]: https://docs.cloud.google.com/artifact-registry/docs/integrate-cloud-run?utm_source=chatgpt.com "Deploying to Cloud Run | Artifact Registry"
[6]: https://docs.cloud.google.com/artifact-registry/docs/repositories/create-repos?utm_source=chatgpt.com "Create standard repositories | Artifact Registry"
[7]: https://docs.cloud.google.com/artifact-registry/docs/docker/store-docker-container-images?utm_source=chatgpt.com "Quickstart: Store Docker container images in Artifact Registry"
[8]: https://docs.cloud.google.com/run/docs/authenticating/public?utm_source=chatgpt.com "Allowing public (unauthenticated) access | Cloud Run"
[9]: https://docs.cloud.google.com/artifact-registry/docs/docker/pushing-and-pulling?utm_source=chatgpt.com "Push and pull images | Artifact Registry"
[10]: https://docs.cloud.google.com/run/docs/authenticating/overview?utm_source=chatgpt.com "Authentication overview | Cloud Run"
[11]: https://docs.cloud.google.com/run/docs/triggering/https-request?utm_source=chatgpt.com "Invoke with an HTTPS Request | Cloud Run"
[12]: https://docs.cloud.google.com/run/docs/testing/local?utm_source=chatgpt.com "Test a Cloud Run service locally"
[13]: https://docs.cloud.google.com/run/docs/configuring/services/containers?utm_source=chatgpt.com "Configure containers for services | Cloud Run"
