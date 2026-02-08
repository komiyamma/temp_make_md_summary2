# 第22章：ポート公開（ホスト→コンテナ）で見える化👀🔌

この章はひとことで言うと——
**「コンテナの中で動いてるWeb/APIを、Windowsのブラウザで見えるようにする」**回です😆✨

---

## 1) まず超ざっくりイメージ🧠💡

* **コンテナの中**：アプリが `3000` とか `80` で待ち受けしてる（でも外からは見えない）
* **Windows側**：ブラウザは `http://localhost:XXXX` にアクセスしたい
* そこで **ポート公開（publish）** をして
  **Windowsのポート → コンテナのポート** をつなぎます🔌

例：`8080:80`

* `8080` = Windows側（ホスト）の入口🚪
* `80` = コンテナ側（アプリが聞いてるポート）📦

この考え方は公式ドキュメントでも同じ説明です。([Docker Documentation][1])

---

## 2) いきなり動くやつで体感しよう🎮🐳

まずは「とにかく見えた！」を作るのが最強です💪😄
公式の例と同じく、ポートを `-p` で公開します。([Docker Documentation][1])

```powershell
docker run -d --name port-demo -p 8080:80 docker/welcome-to-docker
```

✅ できたらブラウザでこれ👇
`http://localhost:8080`

Docker Desktopの画面でも、コンテナの「Port(s)」にリンクが出ます（公式手順でも案内あり）。([Docker Documentation][1])

---

## 3) 「公開できてるか」確認コマンド3点セット✅🕵️‍♂️

## A. いまの公開状況を見る👀

```powershell
docker ps
```

`PORTS` 欄に `0.0.0.0:8080->80/tcp` みたいなのが出ていればOK👍
（`-P` でランダムポートになった例も公式に載ってます）([Docker Documentation][1])

## B. コンテナ名で「どのポート出してる？」を見る🔎

```powershell
docker port port-demo
```

これは公式のCLIリファレンスにもある確認方法です。([Docker Documentation][2])

## C. 実際にアクセスしてみる🌐

PowerShellならこれが楽👇（JSON返すAPIでも見やすい）

```powershell
irm http://localhost:8080
```

---

## 4) Todo APIに当てはめるとこうなる📝✨

あなたのTodo APIが **コンテナ内で `3000` で待ち受け**してるとします（よくあるやつ）🙂
Windows側では `http://localhost:3001` で見たいとき：

```powershell
docker run -d --name todo-api -p 3001:3000 your-todo-api-image
```

* `3001`（Windows側）→ `3000`（コンテナ側）
* ブラウザ：`http://localhost:3001`

**ポイント：コンテナ内アプリは `0.0.0.0` で listen してる必要がある**ことが多いです（`127.0.0.1` だけで待つと外から来れない）😵
※この「コンテナ内localhost罠」は次の章でガッツリやるやつです🪤

---

## 5) Compose版：`ports:` で同じことをする📦📦

`docker run -p` と同じことを `compose.yaml` で書くとこう👇
（公式の “publishing ports” 手順でも `ports: - 8080:80` が紹介されています）([Docker Documentation][1])

```yaml
services:
  app:
    image: docker/welcome-to-docker
    ports:
      - "8080:80"
```

起動👇

```powershell
docker compose up -d
```

停止＆片付け👇

```powershell
docker compose down
```

---

## 6) よく使う `ports` の書き方パターン集📚✨

Composeの公式リファレンスに沿って、実用でよく使う形だけ抜き出します。([Docker Documentation][3])

## パターンA：いちばん基本

* `"HOST_PORT:CONTAINER_PORT"`

```yaml
ports:
  - "3001:3000"
```

## パターンB：**ホスト側ポートを省略**して、空いてるやつを自動で使う🎲

* `"CONTAINER_PORT"` だけ書くと、ホスト側は自動割り当てになります。([Docker Documentation][3])

```yaml
ports:
  - "3000"
```

どこに割り当てられたか確認👇

```powershell
docker compose ps
docker compose port app 3000
```

`docker compose port` は公式CLIにもあるコマンドです。([Docker Documentation][4])

## パターンC：**localhost（127.0.0.1）に縛って安全寄り**🔒

* `"127.0.0.1:HOST:CONTAINER"`
  これで「同じPCからだけアクセス可」にしやすいです。([Docker Documentation][3])

```yaml
ports:
  - "127.0.0.1:3001:3000"
```

---

## 7) `EXPOSE` と `-p` は別モノだよ⚠️📌

ここ、初心者がめっちゃ混乱しがち😅

* `EXPOSE`：**「このアプリはこのポート使うよ」っていう宣言（目印）**
* `-p` / `ports:`：**実際に外へ公開する設定**

`EXPOSE` だけじゃ公開されません。`-P`（publish-all）を使うと、EXPOSEされたポートをまとめてランダム公開できます。([Docker Documentation][1])

```powershell
docker run -d -P --name autoport nginx
docker ps
```

`PORTS` に `0.0.0.0:54772->80/tcp` みたいに **ホスト側がランダム**で出ます🎲([Docker Documentation][1])

---

## 8) ちょい大事：公開は基本「外にも開く」ので注意🚨🌍

Dockerの公式ドキュメントでは、**ポート公開はデフォルトだと外部からも到達し得るので危ない**、だから必要なら `127.0.0.1` に縛ろう、とはっきり書かれています。([Docker Documentation][5])

さらに細かい話として、**Docker Engine 28.0.0 より前**は条件によって「localhostに公開したはずが同一L2から到達される可能性」が注意書きされています（かなりニッチだけど、最新情報として知っておく価値あり）😳([Docker Documentation][5])

---

## 9) Windowsで「localhostで見える」理由を軽く理解🪟🧠

Docker Desktopでは、`-p` で公開すると
**Windows側で待ち受け → VM内のコンテナに転送** という流れになります。
公式のNetworkingページに仕組みがまとまってます。([Docker Documentation][6])

---

## 10) AIに手伝わせると爆速🤖⚡

コピペして使えるプロンプト例👇（短くて実用系）

* 「`docker ps` のPORTSがこう出てる。`http://localhost:xxxx` で開けない原因候補を3つと確認コマンドを出して」
* 「Composeの `ports` を **開発用は localhost 縛り**、本番想定は **外部アクセス可** で書き分けたい。yaml例を2つ出して」
* 「`HOST:CONTAINER` の考え方を、マンションの例えで説明して」

---

## まとめ🎉

* ポート公開は **Windowsの入口ポート** と **コンテナ内の待受ポート** をつなぐだけ🔌
* `docker run -p HOST:CONTAINER` / Composeの `ports: - "HOST:CONTAINER"` が基本形([Docker Documentation][1])
* **localhost縛り（127.0.0.1）** は安全寄りでおすすめ🔒([Docker Documentation][5])
* 見えないときは `docker ps` / `docker port` / `docker compose port` で事実確認👀([Docker Documentation][2])

次の第23章で「ポート被り」「起動してない」「Firewall」みたいな **“よくある失敗”の倒し方**を、わざと事故らせながら覚えます🔥😆

[1]: https://docs.docker.com/get-started/docker-concepts/running-containers/publishing-ports/ "Publishing and exposing ports | Docker Docs"
[2]: https://docs.docker.com/reference/cli/docker/container/port/?utm_source=chatgpt.com "docker container port"
[3]: https://docs.docker.com/reference/compose-file/services/ "Services | Docker Docs"
[4]: https://docs.docker.com/reference/cli/docker/compose/port/?utm_source=chatgpt.com "docker compose port"
[5]: https://docs.docker.com/engine/network/port-publishing/ "Port publishing and mapping | Docker Docs"
[6]: https://docs.docker.com/desktop/features/networking/ "Networking | Docker Docs"
