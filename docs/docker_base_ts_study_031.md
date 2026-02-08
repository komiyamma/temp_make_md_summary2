# 第31章：Composeって何？（なぜ便利？）📦📦📦

この章は「**docker run の長い呪文を卒業して、アプリ一式を“1コマンドで起動”できるようになる**」のがゴールだよ〜！🎉😆
Composeに慣れると、個人開発のスピードが一気に上がる🔥

---

## 1) Composeは何者？🤔✨

ざっくり言うと **「複数コンテナの起動・配線・設定を、1つのYAMLにまとめる仕組み」** だよ〜📜🧩
アプリって普通、APIだけじゃなくてDBとかキャッシュとか、いろいろ必要になるよね？
Composeはそれを **“ひとつのアプリ（スタック）”として管理**できるようにするやつ！🚀
（公式も、1つの設定ファイルでサービス群をまとめて起動できる、って立ち位置だよ）([Docker Documentation][1])

---

## 2) なんで便利？（docker run地獄からの解放）😵➡️😄

## docker run だけで頑張ると起きがち💥

* コマンドが長くなる（オプションが増えるほど地獄）🌀
* DBも起動して…ネットワークも…環境変数も…って手順が増える🧠💦
* 「自分のPCでは動く」けど、別PCだと再現がズレる😇

## Composeだとこうなる🌈

* 起動：`docker compose up` で一発🎮✨
* 停止＆片付け：`docker compose down` で一発🧹
* 設定がファイルに残るから「再現性」が強い💪
* サービス / ネットワーク / ボリューム等をまとめて定義できる([Docker Documentation][2])

---

## 3) Composeファイルの名前：いまの推奨は `compose.yaml` 📄✅

最近の公式では、Composeファイルのデフォルトは **`compose.yaml`（推奨） or `compose.yml`**。
昔よく見た `docker-compose.yml` も互換のために読めるよ、という扱いだよ〜([Docker Documentation][3])

> なので、この教材では **`compose.yaml`** を使うよ！😄✨

---

## 4) Composeのコマンドは `docker compose` が基本🐳🔧

ComposeはDocker Desktopに同梱されるのが一番一般的なルートだよ〜([Docker Documentation][4])
そして今の標準は **`docker-compose` じゃなくて `docker compose`**（スペース入り）🧠✨
（古い記事を読むと混ざってるけど、迷ったら `docker compose` を使うのが安全！）

---

## 5) ⚠️ `version:` は基本いらない（むしろ警告になりがち）🚨

Compose V2系では、トップレベルの `version:` は **“互換のために残ってるだけ”**で、使うと「obsolete（古いよ）」って警告が出ることがあるよ〜😅
Composeは `version` に関係なく常に最新スキーマで検証する、という扱い！([Docker Documentation][5])

> だからこの教材の例では **`version:` は書かない**でいくよ✍️✨

---

## 6) ハンズオン：2つのサービスを “一発起動” してみよう！🎉🚀

ここでは「Webサーバ（nginx）＋キャッシュ（redis）」を同時に立ち上げて、
**Composeの気持ちよさ**を体験するよ😆✨

## 6-1) フォルダ作成📁✨

VS Codeのターミナルで、作業フォルダを作るよ！

```bash
mkdir compose-intro
cd compose-intro
```

## 6-2) `compose.yaml` を作る📝

`compose-intro` の中に `compose.yaml` を作って、これを貼り付けてね👇

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"

  cache:
    image: redis:7-alpine
```

ポイント💡

* `services:` の下に「登場人物（サービス）」を並べる感じ！🧑‍🤝‍🧑
* `ports: "8080:80"` は「ホスト8080 → コンテナ80」だよ🚪🔌
* redisは今回は外に公開しない（中で動いてればOK）🙂

## 6-3) 起動！ `docker compose up` 🚀

まずはフォアグラウンドで起動してログを眺めてみよう👀🪵

```bash
docker compose up
```

止めるときは `Ctrl + C` ✋

次は “裏で起動（常駐）” してみるよ！

```bash
docker compose up -d
```

状態確認📋✨

```bash
docker compose ps
```

## 6-4) ブラウザで確認🌐👀

ブラウザでこれを開く👇

* [http://localhost:8080](http://localhost:8080)

nginxのWelcomeページっぽいのが出たら勝ち〜！🏆🎉

## 6-5) ログを見る🪵✨（webだけ追う）

```bash
docker compose logs -f web
```

アクセスした時にログが増えたりするのが見えるよ😆

## 6-6) コンテナの中でredisを叩く（PONGが出ればOK）🏓✨

```bash
docker compose exec cache redis-cli ping
```

`PONG` が返ったら、redisが元気に動いてる合図！💪😄

---

## 7) 終了＆お片付け🧹✨

「止める＋ネットワーク等も片付け」まで一発でやってくれるのが `down` 😍

```bash
docker compose down
```

> 今回はボリューム使ってないからこれでOK！
> DBを入れるとボリュームが関わってくる（次章以降でやるよ）🧠✨

---

## 8) よくあるつまずき（この章のうちに潰す💥）😵‍💫➡️🙂

## 8-1) `no configuration file provided` 😭

* `compose.yaml` がそのフォルダに無い、名前が違う、場所が違う、が多い！
* Composeはデフォルトで `compose.yaml` を探す（しかも親ディレクトリまで遡って探す挙動もある）([Docker Documentation][6])
  → 迷ったら `ls` して、今いる場所とファイル名を確認！🔍

## 8-2) `port is already allocated`（8080が被ってる）🚪💥

* 8080を別アプリが使ってるパターン
  → `compose.yaml` の `"8080:80"` を `"8081:80"` に変えて再挑戦してOK👌😄

---

## 9) AI活用：Composeの雛形を“速攻で”作らせる🤖📝✨

「自分のプロジェクトに合わせた叩き台」をAIに出させると早いよ〜🚀
（そのまま貼るんじゃなく、**ports/環境変数/ボリューム**あたりだけは必ず目視チェックね👀✅）

## プロンプト例①（最小の叩き台）

* 「nginxとredisをcompose.yamlで起動したい。portsは8080→80。versionは書かない。初心者向けにコメントも付けて」

## プロンプト例②（次章への布石）

* 「API（Node）＋DB（Postgres）をComposeで起動する構成を作りたい。接続情報は環境変数にする前提で、初心者でも読める形で」

---

## 10) まとめ🎓🎉

この章でできたこと✨

* Composeが「複数サービスをまとめて管理する仕組み」だと掴めた🧠
* `compose.yaml` を書いて、`docker compose up` で一発起動できた🚀
* `logs / exec / down` まで “運用の基本セット” を触れた🧰✨
* `version:` は基本いらない、の感覚もOK([Docker Documentation][5])

次の第32章は **compose.yamlの読み方（最低限の項目）** を練習して、怖さを消していくよ！👀✨

[1]: https://docs.docker.com/compose/?utm_source=chatgpt.com "Docker Compose"
[2]: https://docs.docker.com/reference/compose-file/?utm_source=chatgpt.com "Compose file reference"
[3]: https://docs.docker.com/compose/intro/compose-application-model/?utm_source=chatgpt.com "How Compose works | Docker Docs"
[4]: https://docs.docker.com/compose/install/?utm_source=chatgpt.com "Overview of installing Docker Compose"
[5]: https://docs.docker.com/reference/compose-file/version-and-name/?utm_source=chatgpt.com "Version and name top-level elements"
[6]: https://docs.docker.com/reference/cli/docker/compose/?utm_source=chatgpt.com "docker compose"
