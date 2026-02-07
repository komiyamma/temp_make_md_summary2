# 第17章：DBデータはどう守る？（永続化の考え方）🛡️

この章のゴールはシンプル👇
**「消えて困るデータ」と「消えても平気なデータ」を仕分けして、DBだけは確実に残せるようになる**ことです😊✨

---

## 1) まず結論：DBは“箱（コンテナ）”に入れっぱなしにしない！📦❌

コンテナは**気軽に作り直す前提の使い捨ての箱**です🧹
なので、DBみたいな「中身が大事」なものを箱の中だけに入れてると…

* コンテナを `rm` した瞬間に「あれ、データどこ…？😇」
* あるいは、**匿名ボリューム**が勝手に増えて、ディスクがじわじわ圧迫😵

そこで登場するのが **ボリューム（volume）** です✨
ボリュームは**コンテナの寿命とは別に生きる保管庫**なので、コンテナを消してもデータは残ります👍 ([Docker Documentation][1])

---

## 2) DBデータ仕分けの超ざっくりルール📌🧠

Todo APIを育てていく前提で、こんな感じで仕分けできると強いです💪😄

### ✅ 基本：永続化 “いる” もの（消えると泣く😭）

* DBの中身（Todo一覧など）🗃️
* ユーザーがアップロードしたファイル📷（もし扱うなら）
* 生成された重要データ（請求書PDFとか）📄

### ✅ 基本：永続化 “いらない” もの（消えても作り直せる😄）

* `node_modules`（再インストールで復活）📦
* ビルド成果物（`dist`など）🏗️
* キャッシュ類🧊

※ ボリュームは「バックアップしやすい」「Dockerが管理する」などの理由で、DBには特に相性がいいです👍 ([Docker Documentation][1])

---

## 3) ハンズオン：PostgresのDBを“確実に”残す🐘💾

ここでは **PostgreSQL（Docker公式イメージ）** を使って、
「コンテナを消してもTodoデータが残る！」を体験します🎮✨

> 🔥 重要：2026の“新しめ事情”
> **PostgreSQL 18以降**は、ボリュームの考え方（マウント先）が変わっています。
> 18+ は **`/var/lib/postgresql`** 側を狙うのが推奨です📌 ([Docker Hub][2])
> （昔の定番 `.../data` は 17以下向けの注意が出ています⚠️） ([Docker Hub][2])

---

### Step A：名前付きボリュームを作る🧰

```bash
docker volume create todo_pgdata
docker volume ls
```

---

### Step B：Postgresコンテナを起動（ボリューム接続つき）🚀

```bash
docker run -d --name todo-db ^
  -e POSTGRES_PASSWORD=postgres ^
  -e POSTGRES_DB=todo ^
  -p 5432:5432 ^
  -v todo_pgdata:/var/lib/postgresql ^
  postgres:18
```

* `-v todo_pgdata:/var/lib/postgresql` ← **ここが“データ金庫”**🔐
* もし `5432` が埋まってたら `-p 15432:5432` みたいに変えてOKです🔁😄

起動ログをチラ見👀

```bash
docker logs -f todo-db
```

---

### Step C：テーブルを作って、Todoを1件入れてみる📝✨

```bash
docker exec -it todo-db psql -U postgres -d todo
```

入れたら、SQLを実行👇

```sql
CREATE TABLE todos (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  done BOOLEAN NOT NULL DEFAULT false
);

INSERT INTO todos (title, done) VALUES ('DockerでDB永続化できた🎉', false);

SELECT * FROM todos;
```

`SELECT` で1件見えたら成功です🥳🎊

> ちなみに：公式イメージは「初期化は“データディレクトリが空のときだけ”」などのクセがあります（後でハマりポイントで触れます）⚠️ ([Docker Hub][2])

---

### Step D：コンテナを消す → でもデータは残るの？😳

まず消す👇

```bash
docker stop todo-db
docker rm todo-db
```

そして「同じボリューム」で作り直し👇

```bash
docker run -d --name todo-db ^
  -e POSTGRES_PASSWORD=postgres ^
  -e POSTGRES_DB=todo ^
  -p 5432:5432 ^
  -v todo_pgdata:/var/lib/postgresql ^
  postgres:18
```

もう一回 `psql` で確認👇

```bash
docker exec -it todo-db psql -U postgres -d todo -c "SELECT * FROM todos;"
```

**さっきのTodoが残ってたら勝ち🏆✨**
これが「DBはボリュームで守る」ってことです😆

---

## 4) “やっちゃいがち”事故パターン集🪤😵

### 事故1：ボリューム付け忘れで「データ消えた😭」

Postgres公式イメージは、マウントがズレると「別の匿名ボリュームに書いちゃう」系の罠があります⚠️ ([Docker Hub][2])
→ **対策：タグを固定（例：`postgres:18`）＋マウント先を固定**👍

---

### 事故2：ボリュームが残り続けてディスク圧迫😇

ボリュームはコンテナ消しても残ります（仕様です）📦➡️💾 ([Docker Documentation][1])
不要なら掃除👇

```bash
docker volume ls
docker volume rm todo_pgdata
## 使われてないボリュームを一括掃除（慎重に！）
docker volume prune
```

---

### 事故3：初期化スクリプトが走らない（“前は動いたのに…”）😵‍💫

公式イメージの重要ルール👇
**初期化（ユーザー作成・SQL投入など）は「データ領域が空のときだけ」**です⚠️ ([Docker Hub][2])

* つまり、すでにデータが入ったボリュームを使うと「初期化はスキップ」されます
  → 対策：**開発中は「作り直し用のボリューム」と「残すボリューム」を分ける**のが強い💪✨

---

## 5) “守るべきデータ”を迷わないためのテンプレ📋✨

Todo APIでよくある分類テンプレを置いときます👇（そのまま使ってOK）

* 🟥 **絶対に残す**：DB（todos）、uploads（あれば）
* 🟨 **状況次第で残す**：ログ（調査用に一時的に）、開発用ダンプ
* 🟩 **消してOK**：node_modules、キャッシュ、ビルド成果物、テストDB

---

## 6) AI活用（この章はAIがめっちゃ便利🤖✨）

そのままコピペで使える「聞き方」を置いときます💬

### ① データ仕分け（永続化いる？いらない？）

「Todo APIの開発で、次のデータを **永続化“必要/不要”** に分類して。理由も1行で。
対象：DBデータ、アップロードファイル、node_modules、dist、ログ、キャッシュ」

### ② ボリューム運用ルールを1枚にして

「このプロジェクト向けに、ボリューム運用ルール（作る/消す/初期化/バックアップ方針）を箇条書きで。初心者が迷わない順番で」

### ③ ハマりそうポイントの先回り

「PostgresをDockerで使う時の“初心者がやりがちミスTop10”と、確認コマンドをセットで」

---

## 7) ミニ理解チェック✅🎯

最後にこれ答えられたらOKです😄✨

1. コンテナを `rm` してもDBデータを残すには何を使う？🧠
2. “ボリューム付け忘れ”が怖い理由は？😇
3. 初期化SQLが走らない典型原因は？🪤

---

## 次の章へのつなぎ🌱➡️

次（第18章）は **seed（初期データ）と「気軽に作り直す開発データ」** です🎮✨
この章で「守るべきもの」が分かったので、次は「壊してもすぐ戻せる」を作って開発速度を上げます⚡😆

---

必要なら、次章で使うために **Todo API用の“最小Postgres設定（環境変数名・命名ルール）”** もこの場で一緒に決めちゃえますよ🤝😊

[1]: https://docs.docker.com/engine/storage/volumes/ "Volumes | Docker Docs"
[2]: https://hub.docker.com/_/postgres "postgres - Official Image | Docker Hub"
