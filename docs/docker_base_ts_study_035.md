# 第35章：ボリュームをComposeで定義する🧱

この章はひとことで言うと、**「DBの中身だけは絶対に消したくない」**を、Composeでちゃんと実現する回です😆💾
APIコンテナは作り直してOK。でもDBのデータは残したい。これ、個人開発でもチームでも超重要です🔥

---

## この章のゴール🎯✨

* Composeで **名前付きボリューム（named volume）** を定義して使える🙂🧱
* **「消える」「消えない」** の境界（`down` と `down -v`）が腹落ちする🧠💡
* 「DBのデータが消えた😭」の典型事故を **先回りで回避**できる🛡️🚑
* 複数プロジェクトでも混乱しない **ボリューム名の扱い**がわかる🏷️🧹

---

## 1) ボリュームって結局なに？🤔🧱

ボリュームは「**コンテナの外にある、消えにくいデータ置き場**」です📦➡️🏠
コンテナは作り直せるけど、ボリュームに置いたデータは残る、ってイメージ💾✨

そしてComposeでは、ボリュームを「**設計図に書いて**」チーム/自分の環境で再現できるのが強い💪😄
（Composeファイルのデフォルト名は `compose.yaml` が推奨です📝）([Docker Documentation][1])

---

## 2) Composeのボリュームは「2か所に書く」🧩✍️

Composeで名前付きボリュームを使うときは、基本こう👇

1. **トップレベル（`volumes:`）で“名前”を定義**する🧱
2. **サービス（例: DB）側の `volumes:` で“どこにマウントするか”を書く**📎

この「二段構え」がわかると一気に安心します😌✨
（Composeのボリューム仕様はCompose Specification準拠が最新で、Docker DocsのCompose file referenceが基準です）([Docker Documentation][2])

---

## 3) まずは完成形：DBをボリュームで守るcompose.yaml🧱🐘✨

ここからはTodo API + Postgres想定でいきます😄
**ポイントは「Postgresのバージョンでマウント先が変わる」**ところ！これ、2025末〜で重要度が跳ね上がりました⚠️🧠

## ✅ おすすめ：PostgreSQL 18+（最新版寄り）での例🐘🆕

Postgres公式イメージは **18以上でデータディレクトリ周りが変更**されています。18+ はボリュームのマウント先が **`/var/lib/postgresql` 側**になります。([Docker Hub][3])

```yaml
services:
  api:
    # ここは前章までの内容をそのまま想定（buildやportsなど）
    # DB接続先は "db" を使うのが基本（同一Composeネットワーク）
    environment:
      DATABASE_HOST: db

  db:
    image: postgres:18
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: todo
    ports:
      - "5432:5432"
    volumes:
      - db-data:/var/lib/postgresql  # ✅ 18+ はこっち推奨

volumes:
  db-data:
```

## ✅ もし PostgreSQL 17 以下を使うなら（古めの固定タグの場合）🐘⏳

17以下は、**`/var/lib/postgresql/data` にマウントする**のが重要です。
違う場所にマウントすると、コンテナ再作成時に「保存したはずなのに消えた😱」が起きます。([Docker Hub][3])

```yaml
services:
  db:
    image: postgres:17
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: todo
    ports:
      - "5432:5432"
    volumes:
      - db-data:/var/lib/postgresql/data  # ✅ 17以下はこっち

volumes:
  db-data:
```

> なぜこんなことが起きるの？🤔
> Postgres公式イメージは「ここにデータ置くよ」って場所が決まっていて、そこにマウントしないと **匿名ボリューム（anonymous volume）が勝手に作られる** → 次の再作成で再利用されず「あれ、データどこ？」になります😵‍💫
> その注意喚起が公式に明記されています。([Docker Hub][3])

---

## 4) ハンズオン：本当に“消えない”ことを確認しよう🧪✅

## Step 1：起動🚀

```bash
docker compose up -d
```

## Step 2：ボリュームが作られたか確認👀🧱

```bash
docker volume ls
```

「`db-data` って名前のボリュームが見当たらない…？」となったら、それは**Composeがプロジェクト名を前に付けてる**可能性が高いです（例：`myproject_db-data`）🏷️🙂
プロジェクト名は基本「そのcompose.yamlがあるディレクトリ名」になります。([Docker Documentation][4])

## Step 3：DBに“印”をつける（データ作成）✍️🐘

まずpsqlで1行入れてみます（コマンドは例）🙂

```bash
docker compose exec db psql -U postgres -d todo -c "CREATE TABLE IF NOT EXISTS t (id int); INSERT INTO t (id) VALUES (1); SELECT * FROM t;"
```

## Step 4：コンテナを消して、また起動🔁

ここが本番💪😆

```bash
docker compose down
docker compose up -d
docker compose exec db psql -U postgres -d todo -c "SELECT * FROM t;"
```

`id = 1` が残ってたら勝ち🏆🎉
（`docker compose down` は **デフォルトではボリュームを消しません**）([Docker Documentation][5])

---

## 5) いちばん大事：`down` と `down -v` の違い⚠️💥

## ✅ `docker compose down`（安全寄り🛟）

* コンテナ停止＆削除
* ネットワーク削除（など）
* **でもボリュームは基本残る**🙂💾

「デフォルトで消えるもの」がDocker公式に整理されています。([Docker Documentation][5])

## ☠️ `docker compose down -v`（DB初期化スイッチ🔫）

* **Composeで定義した名前付きボリュームも消す**
* さらにコンテナに紐づく匿名ボリュームも消す

つまり **DBがまっさら** になります😇
`-v/--volumes` の説明が公式にあります。([Docker Documentation][5])

**“初期化したいときだけ”使う**のが鉄則です🧯😄

---

## 6) 「プロジェクト名」と「ボリューム名」問題🏷️🧠

## 6-1) なんで `mydir_db-data` みたいになるの？🤔

Composeは「プロジェクト名」で環境を分離します。
デフォルトは **Composeファイルがあるディレクトリ名**です。([Docker Documentation][4])

プロジェクト名は、たとえばこうやって変えられます👇

* `-p` オプション
* `COMPOSE_PROJECT_NAME`
* Composeファイルのトップレベル `name:`
  など、優先順位も公式に書かれています。([Docker Documentation][4])

## 6-2) “ボリューム名を固定”したいとき（上級寄りだけど便利）🧱🔧

トップレベルボリュームに `name:` を付けると、**実際のボリューム名を固定**できます。
この `name:` は「プロジェクト名の接頭辞が付かない（その名前がそのまま使われる）」動きになります。([Docker Documentation][6])

```yaml
volumes:
  db-data:
    name: todo-db-data
```

ただし固定名は「別プロジェクトと衝突」もしやすいので、**チーム/用途が明確なときだけ**がおすすめ🙂⚠️

---

## 7) “外部ボリューム”という安全装置🛡️🧱

たとえば「このボリュームは絶対消したくない」「別のComposeからも使いたい」みたいなとき、`external: true` が使えます🙂

* Composeは **そのボリュームを作らない**（既に存在する前提）
* `docker compose down` でも **external は消されない**

どちらも公式に明記されています。([Docker Documentation][6])

例👇

```yaml
volumes:
  db-data:
    external: true
```

> externalにしたら、先に `docker volume create db-data` を作っておくイメージです🧰🙂

---

## 8) よくある事故🪤😵‍💫 → 即治しガイド🚑✨

## 事故1：DBデータが消えた😭

**原因あるある：マウント先が違って、匿名ボリュームに逃げてた**
Postgres公式がまさにここを強めに注意しています。([Docker Hub][3])

✅ 対策

* Postgres 18+：`/var/lib/postgresql`
* Postgres 17-：`/var/lib/postgresql/data`
  をちゃんと使う🙂

---

## 事故2：うっかり `down -v` した😇

✅ 対策

* **普段は `down` だけ**
* 初期化が必要なときだけ、意図して `down -v`

`-v` が何を消すかは公式に書いてあるので、“消える範囲”を固定で覚えよう🧠✨([Docker Documentation][5])

---

## 事故3：プロジェクト複製したらDBが別物になって混乱😵

**原因：プロジェクト名が変わってボリューム名も変わった**（例：`A_db-data` と `B_db-data`）🏷️

✅ 対策（どれか1つでOK）

* `-p` でプロジェクト名を固定する
* `COMPOSE_PROJECT_NAME` を固定する
* Composeファイルに `name:` を書く

プロジェクト名の仕様と優先順位は公式にまとまってます。([Docker Documentation][4])

---

## 9) AIに手伝わせるプロンプト例🤖✨（コピペOK）

* 「この `compose.yaml` のボリューム定義、**データが消える可能性**ある？危険ポイントを箇条書きで」🧯
* 「`docker compose down` と `down -v` の違いを、**初心者向けに超短く**説明して」✂️
* 「Postgresのタグが `postgres:18` のとき、**永続化のマウント先**はどこが正しい？」🐘
* 「“DB初期化したい時だけ安全にやる手順”を、**事故らないチェックリスト**で作って」✅🧹

---

## 10) ミニ課題🎒✨（5〜10分）

1. `db-data` をComposeで定義して起動できた？🚀
2. テーブル1個作って `down → up` しても残る？💾
3. わざと `down -v` して、データが消えるのを確認（※自己責任で！）😇
4. `docker volume ls` で「どの名前で作られたか」を説明できる？🏷️🙂

---

次の章（第36章）では、複数サービスのログを**まとめて見て運用するコツ**に入ります🪵📚✨
Composeを使うと“ログの見方”が一気に重要になるので、ここでボリュームを固めておくのはめちゃ良い順番です😄👍

[1]: https://docs.docker.com/compose/intro/compose-application-model/?utm_source=chatgpt.com "How Compose works | Docker Docs"
[2]: https://docs.docker.com/reference/compose-file/ "Compose file reference | Docker Docs"
[3]: https://hub.docker.com/_/postgres "postgres - Official Image | Docker Hub"
[4]: https://docs.docker.com/compose/how-tos/project-name/ "Specify a project name | Docker Docs"
[5]: https://docs.docker.com/reference/cli/docker/compose/down/ "docker compose down | Docker Docs"
[6]: https://docs.docker.com/reference/compose-file/volumes/ "Volumes | Docker Docs"
