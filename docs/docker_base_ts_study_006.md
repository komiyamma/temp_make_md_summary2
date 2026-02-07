# 第06章：ログを見る（logs）＝トラブル対応の第一歩🪵👀✨

## 今日のゴール🎯

* 「困ったらまずログ！」が反射でできるようになる💪😄
* `docker logs` で **確認・追尾・絞り込み（時間/件数）** ができるようになる⏱️🔎
* ログが出ないときに、落ち着いて原因を切り分けられるようになる🧘‍♀️🧠

---

## まず知っておく超大事ポイント🌟（ここだけで半分勝ち）

Dockerの「ログ」って、基本は **コンテナの STDOUT / STDERR（画面に出る出力）** のことだよ🙂
だから、アプリが **ファイルにだけ** ログを書いてると、`docker logs` では見えないことがあるよ⚠️
（Nodeなら `console.log` / `console.error` が最強🥇） ([Docker Documentation][1])

それと、`docker logs` は `docker container logs` の **別名（エイリアス）**！覚えやすい方でOK😆 ([Docker Documentation][2])

---

## 今日のチートシート📝✨（これだけ覚えれば戦える）

* 全ログを見る：`docker logs <container>`
* 追尾する：`docker logs -f <container>`（止めるのは `Ctrl + C`）
* 最後だけ見る：`docker logs --tail 50 <container>`
* 時間で絞る：`docker logs --since 10m <container>` / `--until 2m <container>`
* タイムスタンプ付ける：`docker logs -t <container>` ([Docker Documentation][2])

---

## ハンズオン①：ログが出続けるコンテナを作って練習🎮🐳

### 1) まずは「ログ出すだけ」コンテナを起動🚀

```bash
docker run --name log-demo -d alpine sh -c 'i=0; while true; do echo "$(date) hello $i"; i=$((i+1)); sleep 1; done'
```

（`-d` なので裏で動くよ🫥✨）

### 2) ログを見てみる👀

```bash
docker logs log-demo
```

### 3) リアルタイム追尾（超よく使う）🏃‍♂️💨

```bash
docker logs -f log-demo
```

止めたいときは `Ctrl + C`（コンテナは止まらないよ！）🙆‍♂️

### 4) 「最後の20行だけ」見る（長いログに効く）✂️🪵

```bash
docker logs --tail 20 log-demo
```

### 5) タイムスタンプ付きで見る🕒✨

```bash
docker logs -t --tail 5 log-demo
```

`-t` は各行に **RFC3339Nano** 形式の時刻を付けてくれるよ📌 ([Docker Documentation][2])

---

## ハンズオン②：「落ちたコンテナ」の原因をログで掘る🕵️‍♂️💥

### 1) すぐ落ちるコンテナをわざと作る😈

```bash
docker run --name crash-demo busybox sh -c 'echo "boot..."; echo "ERROR: something bad" 1>&2; exit 1'
```

### 2) 動いてないのを確認（ここ大事）📋

```bash
docker ps -a
```

### 3) ログを見る（落ちてもログは残る）🪵👀

```bash
docker logs crash-demo
```

「何が起きたか」がまず見える！これが第一歩💪😄 ([Docker Documentation][2])

---

## 便利オプション完全に理解するコーナー🧠✨

### `--since` / `--until`（時間で絞る）⏱️🔍

* `--since 10m`：**直近10分** だけ
* `--until 2s`：**今から2秒前まで**（ログの“切り取り”に便利）
* 時刻指定は RFC3339 / UNIX timestamp / そして `10m` みたいな相対指定もOK👍 ([Docker Documentation][2])

例：

```bash
docker logs --since 30s log-demo
docker logs --until 2s log-demo
docker logs -f --since 1m log-demo
```

### `--details`（追加情報も付ける）🧾✨

ログドライバの設定（`--log-opt`）で付けた属性（ラベルや環境変数など）を出せることがあるよ🧩
「ログに情報足りない…」ってときの伸びしろ枠🌱 ([Docker Documentation][2])

---

## 「ログが出ない😵」ときの切り分けチェック✅✅✅

### ① そもそもコンテナ名ちがう/存在しない🙃

```bash
docker ps -a
```

### ② アプリが STDOUT/STDERR に出してない📄➡️🗑️

* コンテナ内のファイルにだけ書いてると `docker logs` は薄い/空になりがち
* Nodeならまず `console.log` / `console.error` に出すのが定石👍 ([Docker Documentation][1])

### ③ ロギングドライバが `none` になってる🚫🪵

`none` だとログが保存されないので、`docker logs` は何も返さないよ😇 ([Docker Documentation][3])

### ④ 「どのロギングドライバでも docker logs が使える」けど…最近分だけかも📦🧯

Docker Engine は **dual logging（デュアルログ）** って仕組みで、たとえリモート転送系ドライバでも `docker logs` で読めるように **ローカルキャッシュ** を持つよ🙂
ただしデフォルトで **最大 5ファイル×20MB/コンテナ（圧縮前）** みたいな上限があるので、「古いログは消える」可能性はあるよ⚠️ ([Docker Documentation][4])

### ⑤ ログがディスクを食い尽くす問題🍔➡️💽💥（軽く知っておく）

デフォルトのロギングドライバは `json-file` だよ📌 ([Docker Documentation][3])
「ログが増え続けるとヤバい」ので、本気運用ではローテーション/制限を必ず考える（後半でやると最強）😎

---

## ちょい番外：Docker自体が怪しいときは「デーモンのログ」もある🧰🪟

もし **コンテナのログじゃなくて Docker が不安定**（起動しない/固まる）なら、Dockerデーモン側のログも見ることがあるよ👀
Windows（WSL2）だと `dockerd` / `containerd` のログ位置がドキュメントにまとまってる📍 ([Docker Documentation][5])

---

## AI活用🤖✨（この章は相性バツグン！）

ログは「文章」だから、AIがめっちゃ強い💪😆
コピペするときは、できればこの3点セットを渡すと精度UP⬆️

* ① `docker logs ...` の出力（長ければ末尾50行でOK）
* ② 直前に打ったコマンド
* ③ `docker ps -a` の該当行

### そのまま使えるプロンプト例🧠📝

* 「このログを **3行で要約**して、**原因候補トップ3** と **次に確認するコマンド** を教えて」🤖🔍
* 「このエラーの可能性が高い順に、**確認手順チェックリスト** 作って」✅
* 「Node/TSのアプリだとして、**修正方針（ログの出し方含む）** を提案して」🛠️✨

---

## ミニ課題（5分）⏳🎓

1. `log-demo` を `--tail 5` で見てみる✂️
2. `--since 10s` で「直近10秒だけ」にしてみる⏱️
3. `-f` で追尾して、`Ctrl + C` で戻ってこれるようにする🏃‍♂️💨
4. `crash-demo` のログから「落ちた理由」を日本語で1行説明してみる🪵🧠

---

## 卒業チェック✅🏁

* [ ] `docker logs` を迷わず打てる🙂
* [ ] `-f / --tail / --since` を使い分けられる😆
* [ ] 「ログが出ない」時に、最低3パターンは切り分けできる🕵️‍♂️✅

---

次の章（execで中に入る🕵️‍♂️）に行くと、**「ログ→中で確認」** の最強コンボが完成するよ💪🔥

[1]: https://docs.docker.com/engine/logging/?utm_source=chatgpt.com "Logs and metrics"
[2]: https://docs.docker.com/reference/cli/docker/container/logs/ "docker container logs | Docker Docs"
[3]: https://docs.docker.com/engine/logging/configure/?utm_source=chatgpt.com "Configure logging drivers"
[4]: https://docs.docker.com/engine/logging/dual-logging/?utm_source=chatgpt.com "Use docker logs with remote logging drivers"
[5]: https://docs.docker.com/engine/daemon/logs/ "Read the daemon logs | Docker Docs"
