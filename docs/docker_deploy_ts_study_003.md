# 第03章：“設計”の超入門：本番で死にやすい3つ ☠️➡️✅

この章はね、「ローカルだと動くのに、本番に出した瞬間に事故る😇」を**先回りで潰す回**だよ〜！🚀
コンテナをWebへ出すと、実行環境が“やさしくない世界”になるのがポイント🥶

---

## まず結論：本番で死にやすい3つ 💥💥💥

1. **ステートレスじゃない**（メモリ・ローカルファイルに頼ってる）🧠📁
2. **設定を埋め込んでる**（環境変数/Secretsに逃がしてない）🧩🔑
3. **落ちたとき戻れない**（ヘルスチェック/自己復旧の前提がない）🩺🔁

この3つを「最低限」押さえるだけで、Cloud Runみたいな環境（= いつでも増える/消える）でも生き残りやすくなるよ✨
（Cloud Run は “stateless container” を前提にした世界観だよ、というのが公式トレーニングの説明にも出てくるよ）([Google Cloud Documentation][1])

---

## 1) ステートレス：コンテナは“使い捨て”のつもりで 🧻🐳

## 何が起きるの？😵

本番（特にサーバレス系）は、ざっくりこう👇

* アクセス増える → **インスタンスが増える**📈
* 暇になる → **インスタンスが消える**💨
* 何か起きる（メモリ不足など）→ **インスタンスが強制終了**💥（処理中リクエストは 500 になりうる）([Google Cloud Documentation][2])

つまり…
**「このコンテナのメモリやディスクに置いた状態は、いつでも消える」**が基本ルールだよ🫠

## ステート（状態）ってどれ？🧠

初心者がやりがちなのはこの辺👇

* メモリ変数にカウンタ、ログイン状態、キャッシュを持つ🧠
* `uploads/` にアップロードファイルを保存する📁
* セッションをメモリに置く（再起動でログアウト祭り）🍂

## 正しい逃がし先（ざっくり）🏃‍♂️💨

* 永続データ → **DB**（例：Cloud SQL / Firestore など）🗄️
* ファイル → **オブジェクトストレージ**（例：Cloud Storage）🪣
* セッション → **外部ストア or 署名付きトークン**🍪

---

## 💥ミニ実験：メモリに状態があると“増えた瞬間”壊れる

「同じアプリを2つ起動」して、カウンタがズレるのを見てみよう😈

### ① わざと“地雷コード”を用意する💣

```ts
// src/index.ts
import express from "express";

const app = express();
const port = Number(process.env.PORT ?? 8080);

// 🚨地雷：メモリに状態（インスタンスごとに別）
let counter = 0;

app.get("/", (_req, res) => {
  res.send("OK 😺");
});

app.get("/counter", (_req, res) => {
  counter += 1;
  res.json({ counter, pid: process.pid });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`listening on ${port}`);
});
```

### ② “2個のコンテナ”を別ポートで動かす🐳🐳

（Dockerfileは後の章でちゃんとやるけど、この実験だけの最小版👇）

```dockerfile
## Dockerfile (実験用ミニ)
FROM node:24-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
CMD ["node", "dist/index.js"]
```

```powershell
## PowerShell（VS CodeのターミナルでOK）
docker build -t ch3-demo .

docker run --rm -p 3001:8080 ch3-demo
## 別ターミナルでもう1個
docker run --rm -p 3002:8080 ch3-demo
```

### ③ 叩いてみる🔨

```powershell
curl http://localhost:3001/counter
curl http://localhost:3001/counter
curl http://localhost:3002/counter
curl http://localhost:3002/counter
```

結果はだいたいこうなる👇

* `3001` 側の counter が 1,2…
* `3002` 側の counter が 1,2…（別世界）

👉 **これが本番で“勝手に増えた瞬間”起きる事故**だよ😇

---

## 2) 設定外出し：同じイメージで、環境だけ変える 🧩🌍

## なんで必要？🤔

本番って、

* URL が違う
* DB が違う
* APIキーが違う
* ログの出し方が違う

みたいに「環境ごとに違い」が出るよね🧠
それをコードにベタ書きしてると、**事故る or 管理不能**になるやつ😵‍💫

## 最低限の正解：環境変数（Env）に逃がす🌱

Cloud Run でも「環境変数を設定してデプロイ」が公式の基本導線だよ([Google Cloud Documentation][3])

例👇

```ts
// src/config.ts
function must(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

export const APP_ENV = process.env.APP_ENV ?? "local";
export const DATABASE_URL = must("DATABASE_URL"); // 本番は必須
```

💡ポイント

* **“無いなら落ちる”**（= 変な設定で動き続けない）🧯
* `APP_ENV` みたいな“切り替えスイッチ”は便利🎛️

## Secrets（秘密）は別枠！🔑🙅‍♂️

APIキーやDBパスワードを `.env` や Git に置きっぱなし…は超危険⚠️
Cloud Run は **Secret Manager の秘密を「環境変数」または「ファイルマウント」で渡せる**よ([Google Cloud Documentation][4])

---

## 🤖AIに投げると強いプロンプト例（コピペ用）✨

* 「このNode/TSプロジェクトで、環境変数にすべき値を一覧化して。名前案も付けて」🧩
* 「Secretsにすべき値と、通常の設定値を分けて提案して」🔑
* 「起動時に“必須の環境変数がないと落ちる”チェックを追加して」🧯

※ただし **秘密（実キー）を貼らない**のは絶対守ってね🙅‍♂️🙅‍♂️🙅‍♂️

---

## 3) 落ちても復帰：ヘルスチェックで“自己回復”前提に 🩺🔁

## そもそもヘルスチェックって？👀

「このコンテナ、ちゃんと生きてる？」「準備できた？」を外から判断する仕組みだよ🩺
Cloud Run は **startup / liveness / readiness** みたいなプローブを用意してて、

* 起動できた？（startup）
* 死んでない？（liveness → 必要なら再起動）
* 受け付けていい？（readiness）
  を調整できるよ([Google Cloud Documentation][5])

（Readiness は Preview 扱いとして明記されてるよ）([Google Cloud Documentation][5])

## 最小の実装：`/healthz` を作る ✅

```ts
app.get("/healthz", (_req, res) => {
  // ⚠️重い処理しない（DB全件読み込みとか絶対ダメ😇）
  res.status(200).send("ok");
});
```

## ちょい上級：`/readyz`（依存先OKなら ready）🔧

DBが必要なアプリなら「DBに繋がるか」まで見たいことがあるよね🗄️
超ざっくり例👇（雰囲気だけ掴めればOK）

```ts
let ready = false;

async function warmup() {
  // ここでDB接続チェックなどをする想定（実装は後の章でOK）
  ready = true;
}
warmup();

app.get("/readyz", (_req, res) => {
  res.status(ready ? 200 : 503).send(ready ? "ready" : "not-ready");
});
```

💡Cloud Run 側も、プローブ失敗が続くと“暴走再起動ループ”を抑える動きがあるよ、って公式にも書かれてる🧯([Google Cloud Documentation][5])

---

## ここまでを“1枚のチェックリスト”にする ✅📝

## ✅あなたのアプリ、今すぐ自己点検（Yes/NoでOK）

* [ ] メモリ変数に「ログイン状態」「カウンタ」「キュー」を持ってない？🧠
* [ ] `uploads/` や `tmp/` に“残したいデータ”を書いてない？📁
* [ ] 画像/CSVなどのファイルは外部ストレージに逃がす前提？🪣
* [ ] 設定値（URL/モード/閾値）がコードに直書きされてない？🧩
* [ ] APIキー/パスワードがGit、Dockerfile、ログに混ざってない？🔑
* [ ] `/healthz` はある？🩺
* [ ] “依存先が死んでる時”に、落ち方が分かりやすい？（ログ/ステータス）😵‍💫
* [ ] 環境変数が無いとき、起動直後に気づける？🧯

---

## ミニ課題（やると一気に強くなる）🔥

あなたの今のアプリ（または作りたいアプリ）について👇を作ってみて！

1. **「状態」を洗い出す**🔎

   * メモリにあるもの
   * ローカルファイルにあるもの
   * DB等にあるもの

2. **設定値とSecretsを分ける**🧩🔑

   * 設定（環境で変わるけど秘密じゃない）
   * Secrets（漏れたら即死）

3. **`/healthz` を入れる**🩺✅

   * まずは軽いOK応答だけでOK！

---

## おまけ：Cloud Runで“基本の約束”っぽいやつ（1個だけ覚えればOK）📌

Cloud Run のサービスは、**`PORT` 環境変数で渡されるポートに `0.0.0.0` で待ち受ける**のが契約だよ（`127.0.0.1`待ち受けはNG）([Google Cloud Documentation][2])
これ、後の章で必ず効いてくるやつ😵‍💫➡️😆

---

次の章に行く前に、もしよければ👇だけ教えて！😊✨
あなたが「そのままデプロイ」したいのって、どっち寄り？

* **API（Express/Fastify）**🧩
* **Web（Next/Vite + SSRなど）**🌐
* **バッチ/ジョブ寄り**⚙️

（どれでも進められるけど、例がより刺さるように寄せられるよ〜！🎯）

[1]: https://docs.cloud.google.com/run/docs "Cloud Run documentation  |  Google Cloud Documentation"
[2]: https://docs.cloud.google.com/run/docs/container-contract "Container runtime contract  |  Cloud Run  |  Google Cloud Documentation"
[3]: https://docs.cloud.google.com/run/docs/configuring/services/environment-variables "Configure environment variables for services  |  Cloud Run  |  Google Cloud Documentation"
[4]: https://docs.cloud.google.com/run/docs/configuring/services/secrets "Configure secrets for services  |  Cloud Run  |  Google Cloud Documentation"
[5]: https://docs.cloud.google.com/run/docs/configuring/healthchecks "Configure container health checks for services  |  Cloud Run  |  Google Cloud Documentation"
