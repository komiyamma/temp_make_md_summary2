# 第08章：Nodeのwatch機能で最短ホットリロード⚡

この章は「いちばん手軽に、保存→自動再起動→すぐ確認」を作る回だよ〜😊✨
まずは **Node標準の `--watch`** で“最短の気持ちよさ”を手に入れよう🚀
（より高度なやつ＝TS実行の快適化やCompose Watchは次章以降で育てる🌱）

---

## 1) まずイメージを掴もう🧠💡

ホットリロードって言っても色々あるけど、ここでやるのはシンプル👇

✅ **Nodeプロセスを自動で再起動**して、変更を反映する方式🔥

* 保存する
* Nodeが「変更を検知」する
* Nodeがプロセスを再起動する
* ブラウザ/ curlで確認する

Nodeの `--watch` は **v22.0.0 と v20.13.0 で Stable 扱い**になってるよ👍✨ ([Node.js][5])

---

## 2) Node `--watch` の基本ルール📌

## 何を見張るの？👀

`node --watch` は基本的に👇を監視するよ✨

* **エントリーファイル**
* **そこから `import/require` されているモジュール**
  変更があると **Nodeプロセスが再起動**される💥 ([Node.js][5])

## 使えない組み合わせ⚠️

`--watch` はいくつか制限あり👇

* `--eval` や REPL と一緒に使えない
* **ファイルパス必須**（無いと終了コード9で終わる）
* `--run` と一緒だと `--run` が優先されて watch が無視される ([Node.js][5])

## ログを消したくない人へ🧻✨

watchの再起動でコンソールがクリアされるのが嫌なら👇

* `--watch-preserve-output`（ログが残る） ([Node.js][5])

---

## 3) 手順：Docker内で“最短ホットリロード”を作る🏃‍♂️💨

ここでは依存ゼロのミニAPIで体感していくよ😊
（Expressとかは第7章の「node_modules事故らせない」土台があると安定👍）

## 3-1. ファイルを用意📁

```text
myapp/
  compose.yaml
  src/
    server.js
```

`src/server.js`（超ミニHTTPサーバ）👇

```js
import http from "node:http";

const PORT = process.env.PORT ?? 3000;

const server = http.createServer((req, res) => {
  res.setHeader("content-type", "text/plain; charset=utf-8");
  res.end(`Hello! time=${new Date().toISOString()}\n`);
});

server.listen(PORT, () => {
  console.log(`listening on http://localhost:${PORT}`);
});
```

## 3-2. `compose.yaml` を用意🧩

```yaml
services:
  api:
    image: node:24
    working_dir: /app
    volumes:
      - ./:/app
    command: node --watch --watch-preserve-output src/server.js
    ports:
      - "3000:3000"
```

## 3-3. 起動▶️

```bash
docker compose up
```

ブラウザで `http://localhost:3000` を開く😊✨
そして `server.js` の文字を変えて保存してみてね👇
例：`Hello!` → `Hello Reload!`

保存後にもう一回アクセスすると、内容が変わってるはず🔥

---

## 4) Windowsで“反映が遅い/反映されない”を避けるコツ🪤➡️✅

ここ、**体感スピードが10倍変わる**ことあるやつ😇💦

Docker公式のおすすめはめちゃハッキリしてて👇

* **プロジェクトはWSL2側のファイルシステムに置く**
* **dockerコマンドもWSL2側から叩く**
* Windows側のファイル（`/mnt/c/...`）はなるべく避ける
  WSL2側に置くと bind mount が速く、inotifyイベントも伝播しやすいよ〜って話🥳 ([Docker][6])

なのでおすすめムーブはこう👇✨

* VS Codeで **WSL上のフォルダ**を開く（Remote WSL）
* そのVS Code内ターミナルから `docker compose up`

---

## 5) よくある詰まり🐛💥 → 直し方🔧✨

## 詰まり1：保存しても再起動しない😵

**原因あるある**👇

* プロジェクトが Windows側（`/mnt/c`）にある
* ファイルイベント伝播が遅い/途切れる

**解決**👇

* プロジェクトをWSL2側に移動（`~/projects/...`）
* docker CLIもWSL2から実行 ([Docker][6])

---

## 詰まり2：新しいファイルを作ったのに反応しない😇

`--watch` は基本「エントリ＋import/requireされてるファイル」を追うから、
**作っただけでどこからも参照されてないファイル**は対象外になりがち💡 ([Node.js][5])

**解決**👇

* その新規ファイルをどこかから `import` して“ルートに繋げる”✅

---

## 詰まり3：`--watch-path` を使おうとしたらエラー😲

ここ超重要⚠️
`--watch-path` は **macOS と Windows のみ対応**で、対応してないプラットフォームだと例外が出るよ、って明記されてる👀 ([Node.js][5])

つまり… **Linuxコンテナ内では `--watch-path` が使えない**可能性が高い😇
（DockerのNodeコンテナは基本Linuxだよね）

**じゃあどうする？**👇

* まずはこの章の通り **素直に `--watch`**（importされてる範囲で十分なこと多い）
* もっと柔軟に監視したくなったら、次の選択肢へ✨

  * nodemon系（第10章で判断基準を作る）
  * Compose Watchの `sync+restart`（第11章） ([Docker Documentation][7])

---

## 詰まり4：再起動時にサーバがキレイに落ちない😵‍💫

DB接続とかキューとか持ってると、再起動が気持ち悪くなることあるよね💦

Nodeはwatch再起動時に送るシグナルを変えられるオプションがあるよ👇

* `--watch-kill-signal`（Active Development扱い） ([Node.js][5])

たとえばSIGINTで落としたいなら👇

```yaml
command: node --watch --watch-kill-signal SIGINT --watch-preserve-output src/server.js
```

（SIGINTに合わせて終了処理を書くと安定しやすいよ〜🧯）

---

## 6) ミニ課題🎯✨

## 課題A：最短の成功体験🏁

1. `docker compose up`
2. ブラウザで表示確認
3. `Hello` を変えて保存
4. 再アクセスして反映確認 🎉

## 課題B：importされないと追われないを体験🧪

1. `src/message.js` を作る
2. 何もimportしないまま編集して保存 → 反応しにくい/しないことがある
3. `server.js` から `import "./message.js";` してみる → 反応しやすくなる

## 課題C：ログを育てる📜✨

* `--watch-preserve-output` あり/なしで、ログの見え方の違いを確認してみよ😊 ([Node.js][5])

---

## 7) AIで時短🤖✨（Copilot / Codex向け）

そのまま貼れるプロンプト例いくよ〜💨

**プロンプト1：最小のNode watch構成を作らせる**

* 「Nodeの `--watch` で保存→自動再起動できる最小構成を作って。`compose.yaml` と `src/server.js` を出して。ポート3000。依存ゼロ。」

**プロンプト2：watch再起動を“わかりやすく”する**

* 「watch再起動が起きたときにログで分かるように、起動時ログを工夫して。`--watch-preserve-output` も使う前提で。」

**プロンプト3：Windows/WSL2で遅い時の切り分け表を作らせる**

* 「Windows + Docker Desktop(WSL2) でwatchが遅い/反応しない時の原因候補と対策を、優先順位つきで箇条書きにして。」

コツはね👇😊

* AIが出した `compose.yaml` は **“volumesでnode_modules上書き事故”**が混ざりやすいから、そこだけ目を皿にする👀🍿
* 動いたら勝ち！次章でTS実行を快適にして“待ち時間”を削っていくよ🔥

---

## 8) まとめ📦✨

* Node標準の `node --watch` は **保存→自動再起動**の最短ルート🚀 ([Node.js][5])
* Windows環境は **WSL2側にプロジェクトを置く**と体感が激変しやすい🧊➡️🔥 ([Docker][6])
* 監視をもっと賢くしたくなったら、次の章でTS実行ランナー、さらにCompose Watchへ進化だよ〜😊✨ ([Docker Documentation][7])

次は第9章（TS実行を気持ちよくする🏃‍♂️）に進める形で、`node --watch` と“相性の良いTS実行”を組み立てていこうか？😆

[1]: https://chatgpt.com/c/698a1db7-f628-83a3-aba9-689020cf16ce "Windows詰まり回避法"
[2]: https://chatgpt.com/c/698a1ae7-abcc-83a8-a45b-4ad0bb688064 "開発体験の土台"
[3]: https://chatgpt.com/c/698a727d-1a74-83a8-9b86-9b3110f15a7d "ワンコマンド起動設定"
[4]: https://chatgpt.com/c/698a208c-2cb0-83a4-adda-cb8e0f853658 "第4章 プロジェクト作成"
[5]: https://nodejs.org/api/cli.html "Command-line API | Node.js v25.6.0 Documentation"
[6]: https://www.docker.com/blog/docker-desktop-wsl-2-best-practices/ "Docker Desktop: WSL 2 Best practices | Docker"
[7]: https://docs.docker.com/compose/how-tos/file-watch/ "Use Compose Watch | Docker Docs"
