# 第16章：ボリューム作成・一覧・削除（基本運用）🧰

この章は「**データが消えない箱（ボリューム）を、ちゃんと管理できる**」がゴールだよ！😆👍
ボリュームは **Docker が管理する永続データ置き場**で、コンテナを消しても中身が残るのが強み🛡️📦 ([Docker Documentation][1])

---

## 0) 今日のゴール 🎯

できるようになること👇✨

* ボリュームを **作る**（create）🧱
* ボリュームを **一覧で見る**（ls）📋
* ボリュームの中身（設定）を **確認する**（inspect）🔎
* いらないボリュームを **安全に消す**（rm / prune）🧹🗑️

---

## 1) まず超大事：ボリュームは「消したら戻らない」💥😇

ボリューム削除は、ざっくり言うと **DBのデータをゴミ箱なしで捨てる**のと同じ！😱
だからこの章は「**安全に削除する手順**」までセットで覚えるよ✅✨

---

## 2) ハンズオン：1個作って、使って、残るのを体験しよう 🧪📦

### 2-1) ボリュームを作る 🧱

ボリューム作成コマンドはこれ！
（名前を省略するとランダム名になるよ） ([Docker Documentation][2])

```bash
docker volume create todo-data
```

---

### 2-2) 一覧を見る 📋👀

ボリューム一覧はこれ！フィルタもできるよ🧠✨ ([Docker Documentation][3])

```bash
docker volume ls
```

---

### 2-3) ボリュームを「使う」：中にファイルを作ってみる ✍️📁

軽いコンテナで、ボリュームにファイルを書き込むよ😄

```bash
docker run --rm \
  --mount type=volume,src=todo-data,dst=/data \
  alpine:latest \
  sh -lc "echo 'hello volume' > /data/hello.txt && ls -la /data"
```

* `--rm`：コンテナ終了時にコンテナだけ消える（ボリュームは残る）🧹✨
* `--mount type=volume`：ここが「ボリューム使ってます」って明示できて分かりやすい👍

---

### 2-4) 「残ってる」確認：別のコンテナで読めるか ✅📖

さっき作ったファイルが読めたら勝ち🏆🎉

```bash
docker run --rm \
  --mount type=volume,src=todo-data,dst=/data \
  alpine:latest \
  sh -lc "cat /data/hello.txt && ls -la /data"
```

💡ここで体に染みるポイント：
**コンテナは使い捨てでも、データはボリュームに残せる**🛡️📦 ([Docker Documentation][1])

---

## 3) 中身（設定）を見る：inspect 🔎🧠

ボリュームの情報は `inspect` で JSON で見れるよ！ ([Docker Documentation][4])

```bash
docker volume inspect todo-data
```

さらに「出力を短くする」小技もある（format）✨ ([Docker Documentation][4])

```bash
docker volume inspect --format "{{ .Mountpoint }}" todo-data
```

⚠️補足：Docker Desktop だと、この Mountpoint は Linux 側（VM/WSL2 側）にあって、**基本は直接触らない**方が安全だよ😇
「Docker が面倒見てくれるデータ置き場」として扱うのがラク👍

---

## 4) 削除：安全に消す手順（ここが本番）🧯🗑️

### 4-1) まずルール：使用中のボリュームは消せない 🚫

`docker volume rm` は **コンテナが使ってるボリュームは消せない**よ！ ([Docker Documentation][5])

```bash
docker volume rm todo-data
```

もし「消せない！」って出たら、だいたい **どこかのコンテナが掴んでる**😵‍💫

---

### 4-2) “事故らない”削除フロー ✅（テンプレ）

これを「儀式」として覚えると強い💪😆

1. **対象の名前を確認**（消すやつ合ってる？）👀

```bash
docker volume ls
```

2. **関連コンテナを止めて消す**（コンテナが掴んでたら先に外す）🧹

```bash
docker ps -a
```

* 該当コンテナを見つけたら（例：todo-db など）

```bash
docker rm -f todo-db
```

3. **ボリュームを削除**🗑️

```bash
docker volume rm todo-data
```

---

## 5) お掃除コマンド：prune（でも慎重に！）🧹⚠️

`docker volume prune` は **未使用ボリュームをまとめて削除**するコマンドだよ🧼 ([Docker Documentation][6])
ただし挙動にクセがあるので、ここだけ超重要👇

* デフォルト：**未使用の匿名ボリューム**を削除（名前付きは基本残る） ([Docker Documentation][6])
* `--all`：**未使用の名前付きボリュームも対象**になる ([Docker Documentation][6])

```bash
docker volume prune
```

```bash
docker volume prune --all
```

💥`--all` は「育ててるDBデータ」を吹き飛ばしやすいので、慣れるまで封印でもOK😇🧯

---

## 6) Todo API（ミニ題材）に寄せた “未来の準備” 🌱📦

この先、API＋DB（Compose）に入ると **DB データの置き場**が必要になるよね😊
Compose ではトップレベル `volumes` を宣言して、サービスからマウントできるよ✨
さらに `docker compose up` で、ボリュームが無ければ作って使ってくれる（あれば再利用）🧠 ([Docker Documentation][7])

（まだ第33章で本格的にやるので、今は “こういう形になるんだ～” 程度でOK！）

```yaml
services:
  db:
    image: postgres:16
    volumes:
      - todo-db-data:/var/lib/postgresql/data

volumes:
  todo-db-data:
```

---

## 7) AI活用コーナー 🤖✨（コピペで使える）

困ったらこの辺を AI に投げると、めちゃ時短になるよ⚡😆

### 7-1) 「このボリューム消していい？」判定してもらう🧠

```text
docker volume ls の結果と、消したいボリューム名を貼ります。
安全に消していいか判断するためのチェック手順を、コマンド付きで提案して。
```

### 7-2) エラー文を貼って、原因を絞る🔍

```text
このエラーの意味を初心者向けに説明して、次に打つべきコマンドを3つに絞って。
（エラー文をここに貼る）
```

### 7-3) 「掃除したいけど事故りたくない」🧹🧯

```text
今の状態で docker volume prune を使って安全に掃除したい。
危険なパターンと、安全な実行手順（確認コマンド→実行→検証）を教えて。
```

---

## 8) よくある詰まりポイント 🪤😵（最短で抜ける）

### Q1. 「volume rm ができない（in use）」😫

➡️ **掴んでるコンテナを消す**のが先！
`docker ps -a` → 該当コンテナ `docker rm -f ...` → その後 `docker volume rm` ✅ ([Docker Documentation][5])

### Q2. 「--rm でコンテナ消したのに、容量が増えてる？」🤔

➡️ コンテナは消えても **ボリュームは残る**（だから永続化できる）📦🛡️ ([Docker Documentation][1])
不要なら、**手順通り**に volume を消す🧹

### Q3. 「Composeで down したのにデータ残ってる」🙂

➡️ それが普通！データ守るために残る設計が多いよ😊
（消す方法もあるけど、それは後の章で安全にやろう🧯）

---

## 9) ミニ課題（5分）⏱️✨

次を全部やれたら、この章はクリア🎉

1. `todo-data` を作る🧱
2. `hello.txt` をボリュームに保存する✍️
3. 別コンテナで `hello.txt` を読む📖
4. `inspect` でボリューム情報を見る🔎 ([Docker Documentation][4])
5. 安全手順で `todo-data` を削除する🗑️ ([Docker Documentation][5])

---

次の第17章は「DBデータはどう守る？」🛡️ に進むから、今日のボリューム運用がそのまま土台になるよ😆✨

[1]: https://docs.docker.com/engine/storage/volumes/?utm_source=chatgpt.com "Volumes"
[2]: https://docs.docker.com/reference/cli/docker/volume/create/?utm_source=chatgpt.com "docker volume create"
[3]: https://docs.docker.com/reference/cli/docker/volume/ls/?utm_source=chatgpt.com "docker volume ls"
[4]: https://docs.docker.com/reference/cli/docker/volume/inspect/ "docker volume inspect | Docker Docs"
[5]: https://docs.docker.com/reference/cli/docker/volume/rm/?utm_source=chatgpt.com "docker volume rm"
[6]: https://docs.docker.com/reference/cli/docker/volume/prune/ "docker volume prune | Docker Docs"
[7]: https://docs.docker.com/reference/compose-file/volumes/ "Volumes | Docker Docs"
