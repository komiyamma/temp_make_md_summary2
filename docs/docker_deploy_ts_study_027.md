# 第27章：ヘルスチェック実装＆設定：落ちたら戻る🩺🔁

この章のゴールはこれ👇
**「Cloud Runが“壊れてるインスタンス”を見つけて、勝手に立て直せる状態」**を作ることです 😌✨
（そして、落ちても “すぐ戻る” サービス運用の第一歩を踏みます🚀）

---

## 1) ヘルスチェックって何？超ざっくり🧠💡

Cloud Run から見ると、コンテナって **“箱”** です📦
箱の中身（あなたのアプリ）が、

* ✅ 起動できた？
* ✅ 生きてる？
* ✅ 今トラフィック受けていい？

を **定期テスト**してくれるのがヘルスチェックです🩺✨

Cloud Run 側でできるのは主にこの3つ👇（※Readinessはプレビュー）

* **Startup probe**：起動できた？（起動が遅い子を守る）
* **Liveness probe**：生きてる？（死んでたら再起動）
* **Readiness probe（Preview）**：今トラフィック受けていい？（混雑や依存NGなら外す）

Cloud Run公式でも、これらの役割が明確に説明されています。([Google Cloud Documentation][1])

---

## 2) まず大事な“使い分けのコツ”🧩✨

ここ、設計初心者が一番事故りやすいので先に結論いきます😇

### ✅ Startup（起動チェック）

* **「起動が遅い」せいで落とされる**のを防ぐのが目的🐢
* Startup を設定すると、**Startupが成功するまで他のチェックは邪魔しない**（= 起動中に殺されにくい）([Google Cloud Documentation][1])
* なお **何も設定しない場合でも** Cloud Run は **デフォルトのTCP Startup probe** を自動で入れます（timeout/period 240秒、failureThreshold 1）([Google Cloud Documentation][1])

### ✅ Liveness（生存チェック）

* **「プロセスは生きてるっぽいけど、固まって動かない」**を検知したい😵‍💫
* 失敗が続くと **SIGKILLで強制終了** → 残ってたリクエストは **503** で切られることがある（そして新しいインスタンスが起動）([Google Cloud Documentation][1])
  → だから **“軽く・速く・確実に返る”** チェックが正義です🏃‍♂️💨

### ✅ Readiness（受け入れ可否チェック：Preview）

* Startup成功後に開始され、失敗が続くと **そのインスタンスに新規トラフィックを送らない**（でも**落とさない**）([Google Cloud Documentation][1])
* しかも今は **Preview（Pre-GA）** 扱いです([Google Cloud Documentation][1])
  → **本教材では「任意の上級オプション」**として扱います🙆‍♂️✨

---

## 3) ハンズオン：Node.js + TypeScriptでヘルスエンドポイントを作る🛠️✨

ここでは「安全でよくある形」を作ります👇

* `/healthz`：軽い“動いてる？”（Liveness用にしやすい）
* `/readyz`：依存が生きてる？（Readiness用にしやすい・任意）

> 💡注意：Cloud Run の HTTP プローブは **HTTP/1** のエンドポイントが前提です。([Google Cloud Documentation][1])
> そしてヘルス用エンドポイントは **外部からアクセス可能**なので、情報を出しすぎないのが大事です🫣（バージョンや内部構成をベラベラ喋らない！）

### 3-1) 例：Expressで最小実装（コピペOK）📋✨

```ts
import express from "express";

const app = express();

// ここは「軽く」「速く」「副作用なし」🪽
app.get("/healthz", (_req, res) => {
  res.status(200).send("ok");
});

// 任意：依存確認（例：DBなど）を“短いタイムアウト”で
// ※最初は「常にOK」で運用に慣れてからでもOK🙂
let dependenciesOk = true;

app.get("/readyz", (_req, res) => {
  if (!dependenciesOk) return res.status(503).send("not ready");
  res.status(200).send("ready");
});

const port = Number(process.env.PORT ?? 8080);

// Cloud RunはPORT環境変数で来るのが基本（第6章の復習）🔌
app.listen(port, "0.0.0.0", () => {
  console.log(`listening on :${port}`);
});
```

✅ ここでのポイント

* `healthz` は **軽く**（DB接続テストとか重いのは避ける）⚡
* `readyz` は「依存が死んでる時は 503」みたいな運用がしやすい👍
* ただし最初は `readyz` を **常にOK** でも全然OK（慣れてから育てる）🌱

---

## 4) ローカルで動作確認（最低限）🔍✨

### 4-1) コンテナ起動（例）

```bash
docker run --rm -p 8080:8080 YOUR_IMAGE
```

### 4-2) 疎通確認

```bash
curl -i http://localhost:8080/healthz
curl -i http://localhost:8080/readyz
```

* 200が返ればOK🙆‍♂️
* 503になるのは readiness 的には正常なケースもある（“今は受けない”の意思表示）😌

---

## 5) Cloud Run 側でプローブ設定する（3ルート）🧭

Cloud Run は **Console / gcloud / YAML** で設定できます。
そして、設定変更は **新しいリビジョン作成**につながります([Google Cloud Documentation][1])

---

## 5-A) Consoleで設定（いちばん分かりやすい）🖱️✨

1. Cloud Run で対象サービスを開く
2. **Edit and deploy**（編集してデプロイ）
3. **Container(s)** の中の **Health checks** を探す
4. **Add health check**
5. Type を選ぶ（Startup / Liveness / Readiness）
6. Probe type を選ぶ（HTTP / TCP / gRPC）
7. Path に `/healthz` などを入れる
8. Deploy 🚀

※手順と注意点は公式にもまとまっています。([Google Cloud Documentation][1])

---

## 5-B) gcloudで設定（再現性が高い）⌨️✨

## ✅ Startup（HTTP）

```bash
gcloud run deploy SERVICE ^
  --image=IMAGE_URL ^
  --startup-probe httpGet.path=/healthz,httpGet.port=8080,initialDelaySeconds=0,failureThreshold=12,timeoutSeconds=1,periodSeconds=5
```

* `failureThreshold * periodSeconds` が「起動猶予（最大240秒）」のイメージ🐢([Google Cloud Documentation][1])
* 例だと `12*5=60秒` まで起動を待つ感じです⌛

## ✅ Liveness（HTTP）

（公式ページの「Liveness probes」セクションに沿って設定します）([Google Cloud Documentation][1])
Consoleで入れるのが簡単ですが、YAML運用するなら次のYAML例が分かりやすいです👇

---

## 5-C) YAMLで設定（“最終的に強い”やつ）📄🔥

「Startup + Liveness +（任意で）Readiness」までまとめて管理できます。

## ✅ サンプル（Startup + Liveness）

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: SERVICE
spec:
  template:
    spec:
      containers:
        - image: IMAGE_URL
          ports:
            - containerPort: 8080

          startupProbe:
            httpGet:
              path: /healthz
              port: 8080
            failureThreshold: 12
            periodSeconds: 5
            timeoutSeconds: 1

          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            failureThreshold: 3
            periodSeconds: 10
            timeoutSeconds: 1
```

> 💡Liveness は失敗が続くと **SIGKILL → 503で切断**が起きうるので、`/healthz` は“超軽量”推奨です⚡([Google Cloud Documentation][1])

---

## 🌟（上級・任意）Readiness（Preview）を使う場合

Readiness は **Preview** 扱いで、YAMLでは `run.googleapis.com/launch-stage: BETA` の注釈が必要です([Google Cloud Documentation][1])

```yaml
metadata:
  name: SERVICE
  annotations:
    run.googleapis.com/launch-stage: BETA
spec:
  template:
    spec:
      containers:
        - image: IMAGE_URL
          readinessProbe:
            httpGet:
              path: /readyz
              port: 8080
            successThreshold: 2
            failureThreshold: 3
            periodSeconds: 10
            timeoutSeconds: 1
```

Readiness は失敗しても **インスタンスを落とさず**、新規トラフィックを止めるだけ（復帰したら戻る）という挙動です。([Google Cloud Documentation][1])

---

## 6) “起動が遅いケース”の考え方（超重要）🐢⚙️

起動が遅い理由って、だいたいこのへん👇

* 初回のビルドキャッシュ作成
* DBマイグレーション
* 外部APIに依存した初期化
* 大量ファイル読み込み

こういう時は、**Startup を長めに**して守ります🛡️

* `periodSeconds` を 5〜10 秒
* `failureThreshold` を増やす
* ただし Startup は **猶予上限が240秒** なので、そこを超えるなら起動設計そのものを見直すのが現実的です([Google Cloud Documentation][1])

---

## 7) つまずきTop5 😵‍💫➡️✅

1. **ヘルスが重い**（DB接続チェックを毎回やる等）
   → Liveness で自爆しがち。まずは **軽い /healthz** に寄せる⚡

2. **ヘルスに“内部情報”を返してしまう**
   → ヘルスは外部から叩ける前提で設計（余計な情報は返さない）([Google Cloud Documentation][1])

3. **HTTP/2で作っちゃった**
   → Cloud Run のHTTPプローブは **HTTP/1** 前提なので、別口でHTTP/1のヘルスを用意する([Google Cloud Documentation][1])

4. **起動が遅くてStartupが間に合わない**
   → `failureThreshold * periodSeconds` を増やす（ただし上限240秒）([Google Cloud Documentation][1])

5. **Readinessを入れたのに効かない/挙動が想像と違う**
   → Readiness は Preview で制約あり。さらに過去の構成が残ると効かないケースもあるので公式の注意点を読む([Google Cloud Documentation][1])

---

## 8) ミニ課題（やると身につく💪✨）

* ✅ `/healthz` を追加して、Cloud Run の **Startup + Liveness** を Console で設定
* ✅ 起動にわざと `setTimeout` を入れて（例：10秒待つ）、Startup の設定値をチューニングしてみる🐢
* ✅ `/readyz` を 503 にしてみて、（Preview で）Readiness が “新規トラフィック停止” になる感覚を掴む（できたらでOK）🧪

---

## 9) Copilot / AI に投げるプロンプト（コピペ用）🤖🧠

* 「Express/TypeScriptで `/healthz` と `/readyz` を追加して。`/readyz` は依存がNGなら 503 で返したい」
* 「Cloud Run の startupProbe と livenessProbe を、このサービスの起動時間に合わせて安全寄りに提案して（数値も）」
* 「ヘルスチェックに入れてはいけない処理（重い/危険/副作用）を具体例付きで教えて」
* 「起動が遅い（〜60秒）Cloud Run サービス向けの startupProbe 設計テンプレを作って」

---

次の章（第28章）は別クラウドに移植して「同じ脳みそで動ける」体験に入るので、ここで **“落ちたら戻る” の型**を作れてるとめちゃ強いです😆🔥

[1]: https://docs.cloud.google.com/run/docs/configuring/healthchecks "Configure container health checks for services  |  Cloud Run  |  Google Cloud Documentation"
