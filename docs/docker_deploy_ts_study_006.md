# 第06章：“0.0.0.0問題”とPORT環境変数 🔌😵

この章は、**「ローカルだと動くのに、本番（クラウド）だと死ぬ」あるあるNo.1**を先に潰す回だよ〜！😆
原因はだいたいこの2つ👇

* **(A) 127.0.0.1（localhost）にしか待ち受けてない** → 外部から来たリクエストが入れない😵
* **(B) ポートを固定（3000決め打ち等）** → 本番が指定するポートとズレて起動失敗😇

特に **Cloud Run系**は「こうしてね」って契約がハッキリしてるから、そこに寄せて書くと移植性が上がる👍
「コンテナは `0.0.0.0` で待ち受けて、ポートは `PORT` 環境変数で受け取ってね」ってやつ。([Google Cloud Documentation][1])

---

## 1) まず“0.0.0.0問題”を超ざっくり理解 🧠✨

**結論：コンテナの中のWebサーバは `0.0.0.0` で待ち受けるのが安全**（本番で詰みにくい）✅

* `127.0.0.1` / `localhost`
  → **そのマシン（コンテナ）自身からしかアクセスできない**番地🏠
* `0.0.0.0`
  → **「全部の入口で待つよ」**って意味（全ネットワークIF）🚪🚪🚪

クラウドのルーティング（入口の仕組み）は、だいたい **コンテナの外から**入ってくる。
だから `127.0.0.1` だけで待ってると、「中では開いてるのに、外から入れない」状態になる😵‍💫

実際にCloud Runの公式ドキュメントでも
**「`0.0.0.0` で待て」「`127.0.0.1` で待つな」**って明記されてるよ。([Google Cloud Documentation][1])

---

## 2) PORT環境変数って何？なんで必要？ 🏷️🔧

本番環境は、都合により「このポートで待ってね」を勝手に決めることが多い。
Cloud Runは **`PORT` 環境変数**でそれを渡してくるし、**デフォルトは `8080`**（変更もできる）って公式に書いてある。([Google Cloud Documentation][1])

なので、アプリ側は👇の発想で作るのが安定！

* **ポートは `process.env.PORT` を最優先**
* ローカル用に、無ければ `8080`（または3000）などにフォールバック

（環境変数の読み方自体は Node の公式がそのまま `process.env` を案内してるよ）([Node.js][2])

---

## 3) ハンズオン：Expressを“本番で死なない起動”にする 🛠️🔥

ここからは、**最小でOK**な「待ち受け＆ポート対応」の型を作るよ💪
（Expressじゃなくても考え方は同じ！）

### 3-1. `src/server.ts`（待ち受けの型）🧩

```ts
import express from "express";

const app = express();

// 疎通確認用（本番でも役立つ）
app.get("/", (_req, res) => {
  res.status(200).send("OK ✅");
});

// 重要：PORTは環境変数優先
const port = Number.parseInt(process.env.PORT ?? "8080", 10);

// 重要：0.0.0.0 で待つ（コンテナ/クラウドで詰みにくい）
const host = process.env.HOST ?? "0.0.0.0";

app.listen(port, host, () => {
  console.log(`Listening on http://${host}:${port} 🚀`);
});
```

ポイントはこれだけ👇

* `host = "0.0.0.0"`
* `port = process.env.PORT ?? "8080"`

Cloud Runは **`PORT` を注入する**ので、これで素直に動く方向に寄る。([Google Cloud Documentation][1])

---

## 4) Windowsでローカル確認（PORTを変えて起動）🪟✅

**PowerShell**なら👇（そのターミナルだけ有効）

```powershell
$env:PORT="4000"
node dist/server.js
```

**cmd**なら👇

```bat
set PORT=4000 && node dist/server.js
```

ブラウザで `http://localhost:4000/` を開いて **OK ✅**が出たら勝ち🎉

---

## 5) Dockerで確認：ポートのズレを体で覚える 🐳🧪

### 5-1. まず“普通に”ポート公開（基本形）📦

例：コンテナ内が `8080` で待つ想定なら、こう👇

```bash
docker run --rm -e PORT=8080 -p 8080:8080 your-image
```

* `-e PORT=8080` → **アプリが待つポート**
* `-p 8080:8080` → **ホスト:コンテナ の通路**

Dockerの公式も「`-p HOST:CONTAINER` だよ」って説明してる。([Docker Documentation][3])

### 5-2. “よくある事故”：ホスト3000で開きたいのに…😇

ホスト側を3000にしたいなら、こう👇

```bash
docker run --rm -e PORT=8080 -p 3000:8080 your-image
```

ここで **-e PORT=3000** にしちゃうと、コンテナ内が3000で待っちゃって
**`-p 3000:8080` とズレる** → 「開かない」事故が起きる😵‍💫

---

## 6) “0.0.0.0”の別の罠：ホスト側への公開範囲 🌍⚠️

ここ、ちょい大事👀
Docker Desktopは設定によって、**ホスト側のポート公開が `0.0.0.0`（LAN含め公開）**になり得る。
「ローカルだけで見たいのに、同じWi-Fiの人からも見える」みたいなやつ😇

Docker Desktopの設定にも「デフォルトで `0.0.0.0` にbindする」と書かれてるよ。([Docker Documentation][4])

もし「自分のPCだけから見れればいい」なら、（環境によっては）👇みたいに **host側を127.0.0.1に縛る**のもアリ：

```bash
docker run --rm -e PORT=8080 -p 127.0.0.1:3000:8080 your-image
```

※ただしこれは「ホスト側の公開範囲」の話で、**コンテナ内の待ち受けは 0.0.0.0 のまま**が基本だよ👍

---

## 7) 本番で落ちた時の“即チェック”リスト 🧯🔍

Cloud Runでよく見るエラー系のときは、公式がほぼ答えを書いてる👇

* **ローカルでコンテナが起動できる？**
* **`PORT` のポートで待ってる？**
* **`0.0.0.0` で待ってる？（127.0.0.1で待ってない？）**
* **ログ（stdout/stderr）に原因出てる？**([Google Cloud Documentation][5])

---

## 8) ミニ課題 📝✨（5分で終わる）

1. `PORT=5000` で起動して、`/` が返るのを確認✅
2. Dockerで `-p 3000:8080` を使い、**ホスト3000でアクセス**できるのを確認✅
3. わざと `host="127.0.0.1"` にして、Dockerで「開かない」を再現して原因を説明できたら完全勝利🏆

---

## 9) AIに投げるプロンプト例 🤖💡（コピペ用）

* 「このNode/TSサーバを、`PORT` 環境変数対応＋ `0.0.0.0` バインドに直して。変更点を最小にして」
* 「Dockerで `-p 3000:8080` にしたのに開かない。あり得る原因を優先度順に5つ」
* 「Cloud Runで “PORT=8080 をlistenしろ”系のエラー。ログの見方と切り分け手順を初心者向けに」

---

## まとめ 🎯✨

* **本番で死なない型はこれだけ**👇

  * **`0.0.0.0` で待つ**（localhost待ちは危険）([Google Cloud Documentation][1])
  * **`process.env.PORT` を最優先**（固定ポート決め打ちは危険）([Google Cloud Documentation][1])
* Dockerの `-p HOST:CONTAINER` は **“通路”**で、アプリが待つポートとズレると詰む😇([Docker Documentation][3])

次の章以降でDockerfile最小〜マルチステージに入るけど、ここ（第6章）の型が入ってると、Cloud Runでも他でも生存率が一気に上がるよ🚀🔥

[1]: https://docs.cloud.google.com/run/docs/container-contract "Container runtime contract  |  Cloud Run  |  Google Cloud Documentation"
[2]: https://nodejs.org/en/learn/command-line/how-to-read-environment-variables-from-nodejs "Node.js — How to read environment variables from Node.js"
[3]: https://docs.docker.com/get-started/docker-concepts/running-containers/publishing-ports/ "Publishing and exposing ports | Docker Docs"
[4]: https://docs.docker.com/desktop/settings-and-maintenance/settings/ "Change settings | Docker Docs"
[5]: https://docs.cloud.google.com/run/docs/troubleshooting "Troubleshoot Cloud Run issues  |  Google Cloud Documentation"
