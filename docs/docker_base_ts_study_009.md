# 第09章：よく使うコマンド“最短セット”を覚える🧠⚡（build/run/stop/rm/logs/exec）

この章は、「Dockerで何かあっても最低限まわせる」状態を作る回だよ〜😆✨
コマンドを“暗記”じゃなくて、「1周ループ🔁」で体に入れます💪🐳

---

## 今日のゴール🏁🎯

次の6つを、**迷わず1周**できるようになること！✨

* `build`：イメージ作る🧱
* `run`：コンテナ起動🚀
* `logs`：状況を見る👀🪵
* `exec`：中に入って確認🕵️‍♂️
* `stop`：止める⛔
* `rm`：消す🧹

---

## まず“最短セット6兄弟”の役割を一言で💬✨

* `docker build`：フォルダ（Dockerfile）→ **イメージ**を作る🧪
* `docker run`：イメージ→ **コンテナ**を起動する🎬
* `docker logs`：コンテナの“しゃべり”を見て原因を探す🪵
* `docker exec`：コンテナの中でコマンド実行（中に入る）🔦
* `docker stop`：コンテナを止める（まず穏やかに止める）🧘→（必要なら強制）💥

  * 中のメインプロセスへ `SIGTERM` → 猶予後に `SIGKILL` の流れだよ📌 ([Docker Documentation][1])
* `docker rm`：止まったコンテナを削除🗑️（後片付け）

---

## ハンズオン：練習用“ミニTodo風サーバ”を作って回す🌱🧪

### 1) 作業フォルダを用意📁✨

```bash
mkdir ch09-min && cd ch09-min
```

### 2) `server.js` を作る📝（依存ゼロの超ミニHTTP）

```bash
cat > server.js <<'EOF'
const http = require('http');

const PORT = process.env.PORT || 3000;
const APP_NAME = process.env.APP_NAME || 'todo-api';

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true, app: APP_NAME, time: new Date().toISOString() }));
    return;
  }
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  res.writeHead(200, { 'content-type': 'text/plain' });
  res.end(`Hello from ${APP_NAME}\n`);
});

server.listen(PORT, () => {
  console.log(`✅ ${APP_NAME} listening on :${PORT}`);
});
EOF
```

### 3) `Dockerfile` を作る🍳（この章は“練習用”として最小だけ）

```bash
cat > Dockerfile <<'EOF'
FROM node:lts-alpine
WORKDIR /app
COPY server.js .
ENV PORT=3000
CMD ["node", "server.js"]
EOF
```

---

## ここから本番！6兄弟を“1周ループ🔁”で叩き込む💪😄

### Step A：build（イメージ作成）🧱

```bash
docker build -t todo-api:ch09 .
```

✅ 見どころ👀

* 失敗したら、どの行で止まったかを見て原因特定（ここでAIが強い🤖✨）

---

### Step B：run（コンテナ起動）🚀

```bash
docker run --name todo9 -p 3000:3000 -e APP_NAME=todo9 -d todo-api:ch09
```

* `--name`：あとで扱いやすい名前をつける🏷️
* `-p 3000:3000`：ホストの3000 → コンテナの3000につなぐ🌐
* `-e`：環境変数で設定切り替え🎚️
* `-d`：裏で動かす（detached）🫥

動いてるか確認✅

```bash
docker ps
```

ブラウザで確認したい人は👇

* `http://localhost:3000/health` を開くとOK🙆‍♀️

---

### Step C：logs（まずログ！）🪵👀

```bash
docker logs todo9
```

追いかけたいとき（リアルタイム）👇

```bash
docker logs -f todo9
```

`docker compose up` でもログが“まとめ表示”されるのは同じノリだよ📚✨ ([Docker Documentation][2])

---

### Step D：exec（箱の中へ）🕵️‍♂️🔦

中に入る（シェル起動）👇

```bash
docker exec -it todo9 sh
```

中で確認してみよう😆

```bash
echo $APP_NAME
ps
ls -la
exit
```

---

### Step E：stop（止める）⛔

```bash
docker stop todo9
```

---

### Step F：rm（消す）🧹🗑️

```bash
docker rm todo9
```

これで **「build→run→logs→exec→stop→rm」完成🎉**
この1周ができれば、Docker初心者としてはかなり強いよ💪🐣✨

---

## おまけ：イメージも消したい時🧽（必要な時だけ！）

```bash
docker rmi todo-api:ch09
```

---

## “掃除”の最小知識🧹（容量が苦しい時だけ使う⚠️）

### まず安全寄り：未使用をまとめて整理🧼

`docker system prune` は未使用のコンテナ・ネットワーク・イメージ（dangling等）・ビルドキャッシュを掃除するショートカットだよ🧯 ([Docker Documentation][3])
※ **ボリュームはデフォでは消えない**（消すなら `--volumes` が必要）📌 ([Docker Documentation][4])

```bash
docker system prune
```

イメージだけ掃除なら👇（`-a` は強め⚠️）

```bash
docker image prune
## docker image prune -a  # ←強いので慣れてから！
```

`-a` は「コンテナに紐づいてないイメージも消す」ので注意だよ🫣 ([Docker Documentation][5])

---

## よくある詰まりポイント“即復帰”🚑✨

### ① ポートが使われてる（起動できない）🔌💥

* 症状：`bind: address already in use` 系
* 対処：別ポートにする（例：`-p 3001:3000`） or 競合プロセスを止める

### ② 名前がかぶった（`--name todo9` が使えない）🏷️😵

* まず確認👇

```bash
docker ps -a
```

* 既にあるなら消す👇

```bash
docker rm todo9
```

### ③ ログが何も出ない😶

* `-d` で起動してるなら `docker logs -f` を試す🪵
* そもそも落ちてるかも → `docker ps -a` で状態見る👀

---

## ちょい予習：Composeだとどう見える？🧩✨

（この章は“単体コンテナ”中心だけど、頭の片隅に置くと後で楽😆）

* 単体：`docker run ...`
* Compose：`docker compose up`（作って起動してまとめる）🚀 ([Docker Documentation][2])
* 止めて片付け：`docker compose down`（upで作ったものを止めて消す）🧹 ([Docker Documentation][6])

今どきは Compose は `docker compose` が基本で、Docker Desktop経由なら一式入るよ📦 ([Docker Documentation][7])
（`docker-compose` の打ち方が残ってても、Desktop側で `docker compose` へ寄せる仕組みがあるよ〜という感じ）([Docker][8])

---

## AI活用コーナー🤖✨（この章と相性よすぎ）

### 🔥おすすめプロンプト（コピペでOK）

1. **ログ解析（最強）**🪵
   「このログの原因候補トップ3と、確認コマンドを順番に出して」
   （ログをそのまま貼る）

2. **チートシート自動生成**📄
   「第9章の6コマンドを、用途・よく使うオプション・例つきでA4 1枚にまとめて」

3. **自分の癖に合わせた最短手順**🏃‍♂️
   「僕は *run→logs→exec* をよくやる。最短で回す手順を“3手”に圧縮して」

ちなみに公式のCLIチートシートもあるよ📌（見比べると覚えやすい） ([Docker][9])

---

## ミニテスト✅🎓（3分で復習）

1. `docker build` の成果物は何？📦
2. 起動中コンテナのログを見るコマンドは？🪵
3. コンテナの中で `env` を確認したい。どれ使う？🕵️
4. 止めて、消す。2手で何？⛔🗑️

---

## 宿題（軽め）📝✨

* ✅ **1周ループ🔁を3回**やる（スラスラ言えるまで）
* ✅ 自分用チートシートを `docs/ch09-cheatsheet.md` に作る📄
* ✅ どこで詰まったかを1行メモ（次章以降の伸びが爆速になる）🚀

---

必要なら、この章の内容を **A4一枚チートシート化📄✨**（コマンド＋用途＋ミス例＋復帰手順）した版も作るよ😆

[1]: https://docs.docker.com/reference/cli/docker/container/stop/?utm_source=chatgpt.com "docker container stop"
[2]: https://docs.docker.com/reference/cli/docker/compose/up/?utm_source=chatgpt.com "docker compose up"
[3]: https://docs.docker.com/reference/cli/docker/system/prune/?utm_source=chatgpt.com "docker system prune"
[4]: https://docs.docker.com/engine/manage-resources/pruning/?utm_source=chatgpt.com "Prune unused Docker objects"
[5]: https://docs.docker.com/reference/cli/docker/image/prune/?utm_source=chatgpt.com "docker image prune"
[6]: https://docs.docker.com/reference/cli/docker/compose/down/?utm_source=chatgpt.com "docker compose down"
[7]: https://docs.docker.com/compose/install/?utm_source=chatgpt.com "Overview of installing Docker Compose"
[8]: https://www.docker.com/blog/announcing-compose-v2-general-availability/?utm_source=chatgpt.com "Announcing Compose V2 General Availability"
[9]: https://www.docker.com/resources/cli-cheat-sheet/?utm_source=chatgpt.com "CLI Cheat Sheet"
