# 第15章：ヘルスチェック：死活と準備の2段階 🩺✅

この章は「公開してから詰むポイント」を先に潰す回だよ😆
**ヘルスチェックがちゃんと入ると、デプロイ後に落ちても“勝手に戻る”サービス**に近づく👍

---

## 15.1 今日のゴール 🎯✨

最終的にこうなるのがゴール👇

* ✅ アプリに **/healthz**（生きてる？）を実装できる
* ✅ 必要なら **/readyz**（今トラフィック受けて平気？）も作れる
* ✅ **startup / liveness / readiness** を「いつ・何を見てるか」で説明できる
* ✅ **Cloud Run でヘルスチェック設定**して、落ちたら復旧できるようにする

（この3種類の考え方は Kubernetes の用語として有名で、Cloud系もだいたい同じノリで来るよ）([Kubernetes][1])

---

## 15.2 まず“3種類”を超ざっくり理解しよう 🧠💡

### 🍳 たとえ：飲食店で考える

* **startup（開店準備できた？）**：厨房の火入れ、仕込み、レジ起動…「開店前」チェック
* **readiness（今、お客さん入れていい？）**：混みすぎ・材料切れ・回線不調…「今は新規客ムリ」
* **liveness（店、死んでない？）**：店員が固まって動かない（デッドロック）とか「店として終わってる」

定義をちゃんと見るとこう👇

* liveness は「再起動すべきか」を判断
* readiness は「トラフィック受けていいか」を判断（ダメなら外される）
* startup は「起動が遅い子を殺さないため」に最初だけ見て、成功するまで他を止める ([Kubernetes][1])

---

## 15.3 “2段階”って結局なに？🩺✅➡️🔁

この教材の「2段階」はこう覚えると強い💪

1. **準備OK？（startup / readiness）**
2. **生きてる？（liveness）**

特に Google の Cloud Run だと、startup probe を入れると **成功するまで liveness / readiness を走らせない**ので、起動が遅いアプリが事故りにくくなるよ。([Google Cloud Documentation][2])

---

## 15.4 エンドポイント設計：まずはこの2本でOK 🧩🪄

### ✅ /healthz（浅いチェック）

**目的：死活（liveness）用**

* 200 を返せばOK（本文は “ok” で十分）
* **DBや外部APIに触らない**（重くすると自爆する💥）

例：

* Node のイベントループが生きてる
* “プロセスが固まってない”程度の確認

### ✅ /readyz（少し深いチェック）

**目的：準備（readiness）用**

* 依存先（DB/Redis/外部API）が必要ならここで確認
* ただし「毎回重い問い合わせ」はダメ🙅‍♂️
  → “疎通できるか”程度にする（キャッシュでもOK）

---

## 15.5 TypeScript（Express例）で実装してみよう 🛠️✨

ここでは最低限の構成でいくよ（まず動くのが正義👑）

### ① health ルートを作る（浅い）🩺

```ts
// src/health.ts
import type { Request, Response } from "express";

export function healthz(_req: Request, res: Response) {
  // 超軽量：プロセスが動いてるならOK
  res.status(200).type("text/plain").send("ok");
}
```

### ② readiness を作る（必要なら）🚦

「初期化が完了したか」だけでも readiness っぽくなるよ👍
（DBがある人は、あとでここに“軽い疎通”を足す）

```ts
// src/ready.ts
import type { Request, Response } from "express";

let isReady = false;

// 例：起動後の初期化が終わったら true にする想定
export function markReady() {
  isReady = true;
}

export function readyz(_req: Request, res: Response) {
  if (!isReady) {
    return res.status(503).type("text/plain").send("not ready");
  }
  return res.status(200).type("text/plain").send("ready");
}
```

### ③ app に組み込む 🌐

```ts
// src/app.ts
import express from "express";
import { healthz } from "./health";
import { readyz, markReady } from "./ready";

const app = express();

app.get("/healthz", healthz);
app.get("/readyz", readyz);

// 例：起動時の初期化（本当はDB接続など）
async function bootstrap() {
  // ここで「重い初期化」をやる想定
  await new Promise((r) => setTimeout(r, 500)); // ダミー
  markReady();
}

bootstrap().catch((e) => {
  // 起動に失敗したらログ出して落ちる（中途半端に生きない）
  console.error(e);
  process.exit(1);
});

const port = Number(process.env.PORT ?? "8080");
app.listen(port, "0.0.0.0", () => {
  console.log(`listening on ${port}`);
});
```

---

## 15.6 ローカルで確認（Windows）🧪🪟

### ① コンテナ起動（例）

```bash
docker build -t myapp .
docker run --rm -p 8080:8080 -e PORT=8080 myapp
```

### ② 動作確認

PowerShell でも curl は使えるよ👍

```bash
curl -i http://localhost:8080/healthz
curl -i http://localhost:8080/readyz
```

---

## 15.7 Cloud Run での設定イメージ（重要）☁️⚙️

Cloud Run のヘルスチェックは **HTTP/TCP/gRPC** で設定できて、HTTP なら **HTTP/1 のエンドポイント**をアプリ側に用意する必要があるよ（Cloud Run のデフォルトは HTTP/2 じゃない点に注意）。また、HTTP のヘルスチェック用エンドポイントは **外部から到達可能**なので、普通の公開APIと同じ発想で扱うのが大事。([Google Cloud Documentation][2])

### ✅ 設定おすすめ（最初のテンプレ）📌

* **startup**：`/healthz`（起動が遅いならここを厚めに）
* **liveness**：`/healthz`（軽いのでこれでOK）
* **readiness**：`/readyz`（依存先があるならここ）

Cloud Run の liveness は、規定回数（`failureThreshold * periodSeconds`）失敗すると **コンテナを SIGKILL で落として、新しいインスタンスを起動**して復旧させる動き。([Google Cloud Documentation][2])

### ⚠️ readiness は “Preview” 扱い（2026-02 時点）

readiness probes は Preview として案内されていて、いくつか制限も書かれてるよ。例えば session affinity を有効にしていると、readiness が落ちても同じインスタンスに送られ続ける…など。([Google Cloud Documentation][2])

### 💰 地味だけど大事：プローブにもCPU課金がある

Cloud Run は「プローブ実行時はCPUが割り当てられる」「CPU/メモリ使用分は課金対象（ただしリクエスト課金は無し）」と明記されてる。だからヘルスチェックは軽く作るのが正義👑([Google Cloud Documentation][2])

---

## 15.8 “重すぎないヘルスチェック”の鉄則 🧯😇

**/healthz でやっていいこと ✅**

* 固まってないか（即レスできるか）
* 返す情報は最小（`ok` だけ）

**/healthz でやっちゃダメ 🙅‍♂️**

* DBに毎回クエリ
* 外部APIへアクセス
* 重い計算（暗号化、画像処理…）

**/readyz の現実的なライン ✅**

* DBが必須なら「接続が生きてるか」程度（短いタイムアウト）
* 外部API必須なら「最近成功した結果を数秒キャッシュ」して返す、みたいな工夫

---

## 15.9 よくある詰まり Top5 😵‍💫🧨

1. **パスが違う**（設定は `/healthz` なのにアプリが `/health` とか）
2. **PORT違い**（Cloud Run 側の設定ポートとコンテナの待受ポートがズレる）
3. **重すぎてタイムアウト**（Timeout は period を超えられない）([Google Cloud Documentation][2])
4. **readiness を “いつまでも503” にしてる**（初期化完了フラグを立て忘れ）
5. **readiness の仕様を誤解**（「落ちたら再起動」じゃなく「一時的にトラフィック止める」側）([Kubernetes][1])

---

## 15.10 ミニ課題（やると一気に腹落ち）📘✨

* ✅ 課題1：/healthz を **100回叩いても遅くならない**（軽いことが勝ち）🏃‍♂️💨
* ✅ 課題2：/readyz を、起動直後だけ 503 → 数秒後に 200 に変える（「準備」の感覚）🚦
* ✅ 課題3：擬似的に “固まった” 状態を作る（例：無限ループを仕込む）→ liveness の価値を体感 😇
  ※本番では絶対やらないやつ！ローカルだけね！😂

---

## 15.11 AIに投げるコピペ用プロンプト集 🤖📎

* 「この Express + TypeScript に /healthz と /readyz を追加して。/healthz は軽く、/readyz は初期化完了フラグで 503→200 にして」
* 「Cloud Run の startup / liveness / readiness を、このアプリ構成だとどう割り当てるのが安全？推奨値（period/timeout/failureThreshold）も理由つきで」
* 「ヘルスチェックが重くなる典型パターンを列挙して、避け方をコード例込みで」

---

## おまけ：Dockerfile の HEALTHCHECK って使うべき？🐳🧩

ローカル（Docker単体/Compose）では、Dockerfile の HEALTHCHECK が効く場面があるよ。
Docker の HEALTHCHECK には interval/timeout/start-period/retries などがあり、Docker Engine 25.0+ では start-interval も使える、と公式に書かれてる。([Docker Documentation][3])

ただし **Cloud Run 側は Cloud Run のプローブ設定が主役**なので、まずは「HTTPエンドポイントでのヘルスチェック」を固めるのが一番コスパ良い👍([Google Cloud Documentation][2])

---

次の章に進む前に、/healthz と /readyz の2本が手元で安定して返る状態にしておくと、後でめちゃくちゃ楽になるよ😆🩺✨

[1]: https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/ "Liveness, Readiness, and Startup Probes | Kubernetes"
[2]: https://docs.cloud.google.com/run/docs/configuring/healthchecks "Configure container health checks for services  |  Cloud Run  |  Google Cloud Documentation"
[3]: https://docs.docker.com/reference/dockerfile/ "Dockerfile reference | Docker Docs"
