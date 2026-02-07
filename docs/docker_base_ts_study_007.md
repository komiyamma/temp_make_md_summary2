# 第07章：中に入る（exec / shell）“箱の中を覗く”🕵️‍♂️🐳✨

## この章のゴール🎯

* 起動中コンテナに **入って調査**できる（シェルでうろうろできる）🐾
* **1発コマンド**で「ファイル/環境変数/プロセス」を確認できる🔦
* 「bashが無い😵」「コンテナ止まってる😇」みたいな **あるある詰まり**を自力で回避できる🛟

---

## まずは超重要：`docker exec`って何？🤔

`docker exec` は **“起動中のコンテナの中で、新しいコマンドを実行する”** ためのコマンドです。
ポイントはこれ👇

* **コンテナが動いてる時だけ**使える（PID 1 が動いてないとダメ）
* `exec`で動かしたコマンドは、**その場限り**（コンテナ再起動しても勝手に復活しない）
* 文字列でコマンドをつなげたい時は、**`sh -c` が必要**（直に `"echo a && echo b"` はNG） ([Docker Documentation][1])

---

## `exec`の最小セット（これだけ覚えればOK）🧠⚡

* **シェルで入る（対話）**

  * `-it`（`-i`=入力を開く / `-t`=TTYを割り当て） ([Docker ドキュメント][2])
* **1発で調査（非対話）**

  * `docker exec <container> <command> ...`

---

## ハンズオン🧪：まず「調査用コンテナ」を用意しよう📦

この章は「中を覗く練習」なので、まずは **覗く対象**を作ります🙂

### 1) Nodeで“動きっぱなし”の簡易APIを起動🚀

```bash
docker run -d --name todo-api -p 3000:3000 node:lts-alpine \
  node -e "require('http').createServer((req,res)=>{res.end('ok');}).listen(3000)"
docker ps
```

※もし `node:lts-alpine` が見つからない環境なら `node:alpine` に差し替えてOK🙆‍♂️（タグ事情はたまに変わるので…）

---

## ハンズオン🧪：`exec`で「1発調査」してみる🔍

### 2) OS情報を取る（中が何者か確認）🧾

```bash
docker exec todo-api cat /etc/os-release
```

「Alpineっぽいな〜」とか、ここで分かります😄

### 3) 作業ディレクトリと中身を見る📁👀

```bash
docker exec todo-api pwd
docker exec todo-api ls -la
```

`pwd` と `ls` は最強の初手セットです💪

### 4) 環境変数を見る（設定探し）🎚️

```bash
docker exec todo-api env | sort
```

「PORTどこ？」「NODE_ENVどこ？」みたいな時に超使います✨

---

## ハンズオン🧪：シェルで“中に入る”🕳️➡️🏠

### 5) `sh` で入る（`bash`じゃなくてOK）🐚

Alpine系は `bash` が無いことが多いので、まず `sh` が安定です🙂

```bash
docker exec -it todo-api sh
```

入れたら、中でこれを試してみよう👇

```bash
pwd
ls -la
node -v
ps
env | sort | head
```

終わったら `exit` で出ます🚪

```bash
exit
```

---

## よく使う “中の確認コマンド” テンプレ🧰✨

困ったらこれを順番に打つと、状況がだいたい掴めます😄

```bash
## ① 何が動いてる？
docker exec todo-api ps

## ② 設定は？
docker exec todo-api env | sort

## ③ どこに何がある？
docker exec todo-api pwd
docker exec todo-api ls -la

## ④ OS/配布物の情報
docker exec todo-api cat /etc/os-release
```

---

## `exec`で「コマンド連結」がしたい時の罠🪤😵

Docker公式でも注意されてるやつです👇
`docker exec` に **文字列をそのまま渡しても**、シェルが解釈してくれません。なので…

❌ ダメ例（連結が効かない）

```bash
docker exec -it todo-api "echo a && echo b"
```

✅ OK例（`sh -c` に解釈させる）

```bash
docker exec -it todo-api sh -c "echo a && echo b"
```

この挙動は公式説明にもあります。 ([Docker ドキュメント][2])

---

## ちょい応用：ユーザー/作業ディレクトリ/環境変数を指定する🎛️🧭

### 1) 作業ディレクトリを変える（`-w`）🧭

```bash
docker exec -w / tmp todo-api ls -la
```

`--workdir`（`-w`）は公式オプションです。 ([Docker ドキュメント][3])

### 2) 環境変数を一時的に足す（`-e`）➕

```bash
docker exec -e DEBUG=1 todo-api env | grep DEBUG
```

`--env`（`-e`）も公式オプションです。 ([Docker ドキュメント][3])

### 3) 別ユーザーで実行する（`-u`）👤

```bash
docker exec -u node -it todo-api sh
```

「rootで全部やっちゃう」より安全寄りにできます🛡️
（イメージによって `node` ユーザーが居ない場合もあるので、その時はエラーになります😅）
`--user`（`-u`）も公式オプションです。 ([Docker ドキュメント][3])

---

## 似てるけど違う：`attach` と `exec`⚖️

* `attach`：**元から動いてるメインのプロセス（PID 1）**にくっつく
* `exec`：コンテナ内で **新しいプロセス**を起動して実行する

なので、調査・デバッグ目的なら基本は `exec` が使いやすいです🙂 ([Stack Overflow][4])

---

## よくある詰まりポイント集🧯😵‍💫（ここ超大事）

### ① `Container ... is not running` と言われる😇

→ **コンテナが止まってる**ので `exec` できません。
`exec`は「起動中のコンテナでだけ動く」がルールです。 ([Docker Documentation][1])

まずこれ👇

```bash
docker ps -a
```

止まってたら起動（この章の前後で扱ってるはずのやつ）▶️

```bash
docker start todo-api
```

### ② `bash: not found` 😵

→ イメージによっては `bash` が入ってないです。
まずは **`sh`** を使おう🙂

```bash
docker exec -it todo-api sh
```

### ③ `executable file not found in $PATH` 😭

→ コマンド名が無い／PATHに無い、が原因。
`which <cmd>` したいけど `which` すら無いイメージもあります（Alpineあるある）😅
そういう時は **最小イメージ**の世界なので、次の章（Dockerfile）で「必要コマンドを組み込む」方向に繋がります📦✨

---

## ちょい未来の話：シェルが無いイメージ（distroless等）どうする？🧊🪛

最近の本番イメージは「小さくて安全」寄りで、**シェル無し**が普通にあります。
その場合、`exec sh` ができないので、**debug用イメージ**や別手段で調査します。 ([GitHub][5])

（ここは第6章デバッグや後半の運用でめっちゃ効いてきます🔥）

---

## AI活用コーナー🤖✨（この章にピッタリの使い方）

### ① “調査コマンドセット”を自分用に作らせる📌

プロンプト例👇

* 「Nodeのコンテナで、**プロセス/環境変数/ファイル/OS** を確認するコマンドを、短い順で10個にまとめて」

### ② 出力を貼って「次に何見る？」を聞く🔍

* `docker exec ... env` の出力
* `ps` の出力
* `ls` の出力
  これを貼って「疑う順番トップ3」って聞くと、調査が速くなります⚡

### ③ “やっちゃダメ”のブレーキ役にする🛑

* 「本番相当のコンテナに `apk add` でツール入れていい？代替は？」
  みたいに聞くと、安全側の案が出やすいです🛡️

---

## ミニ課題🎒（Todo APIを覗いてみよう）🕵️‍♀️

1. `todo-api` の中に入って、`node -v` を確認✅
2. `ps` で **Nodeプロセスが動いてる**のを確認✅
3. `env` を見て、気になる変数を3つメモ📝
4. `sh -c` を使って `echo` を2回連結して表示✅

---

## 理解チェック（5問）✅😄

1. `docker exec` は **止まっているコンテナ**でも使える？
2. `-it` の `i` と `t` は何のため？
3. `bash` が無い時、まず何を試す？
4. `docker exec todo-api "echo a && echo b"` がダメな理由は？
5. `attach` と `exec` の違いを一言で！

---

## 片付け（使い終わったら掃除🧹）

この章のコンテナ、もう要らなければ消してOK🙆‍♂️

```bash
docker stop todo-api
docker rm todo-api
```

---

次の章（第08章）では、ここで見た `env` が主役になります🎚️✨
「設定をコードに直書きしない」方向へ進もう〜😆🚀

[1]: https://docs.docker.com/reference/cli/docker/container/exec/?utm_source=chatgpt.com "docker container exec"
[2]: https://docs.docker.jp/engine/reference/commandline/exec.html?utm_source=chatgpt.com "docker exec — Docker-docs-ja 24.0 ドキュメント"
[3]: https://docs.docker.jp/v20.10/engine/reference/commandline/container_exec.html?utm_source=chatgpt.com "docker container exec — Docker-docs-ja 20.10 ドキュメント"
[4]: https://stackoverflow.com/questions/30960686/difference-between-docker-attach-and-docker-exec?utm_source=chatgpt.com "difference between docker attach and docker exec"
[5]: https://github.com/GoogleContainerTools/distroless/blob/main/README.md?utm_source=chatgpt.com "distroless/README.md at main"
