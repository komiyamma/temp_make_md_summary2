# 第18章：初期データ（seed）と“開発データの作り直し”🌱

この章は「開発を速く回すために、データをいつでも作り直せるようにする」がゴールだよ⚡
Todo API を育てる上で、**DBの中身がゴチャついたら一撃で初期状態に戻す**のが最強です😆💪

---

## 1) まず “seed” って何？🌱

**seed（シード）**＝「開発用の初期データ」のことだよ🙂
例：ユーザー1人＋Todoが3件入ってる状態を、いつでも再現できる✨

seedがあると…👇

* 手元の環境を作り直しても、すぐ同じ状態で動かせる🏃‍♂️💨
* “動作確認の基準データ” が固定されるので、バグ調査が速い🕵️‍♂️✨
* 「データが壊れた/汚れた」を怖がらず、気軽に試せる🎮🔥

---

## 2) 今日のミニ構成（章内ハンズオン）🧩

今回は **PostgreSQL** を使って「seed → 壊す → 戻す」を体験するよ🧪
PostgreSQL は **18系** が最新メジャー（2025-09-25リリース）なので、それでいくね🆕🐘 ([PostgreSQL][3])

> ※ この章ではまだネットワーク章じゃないので、**ホストから繋がず**に `docker exec` でDBの中を触る形にするよ🔦（超ラク！）

---

## 3) seed の “2大方式” を先に知っておこう⚖️

### 方式A：**“初回だけseed”**（公式イメージの仕組みを使う）🌱

PostgreSQL公式イメージは、初期化時に `/docker-entrypoint-initdb.d` に置いた `*.sql` を自動実行してくれるよ✅ ([Docker Hub][4])
ただし **「データディレクトリが空のときだけ」** 実行される（ここ超重要！）⚠️ ([GitHub][5])

* 👍 良い：最初の立ち上げが超ラク
* 👎 注意：やり直したい時は **ボリューム削除** が必要になりがち

### 方式B：**“いつでもseed”**（あとからSQLを流し込む）🧯

`docker exec` で `psql` にSQLを流して、いつでも “初期化し直す” 方法。

* 👍 良い：ボリューム消さずに戻せる
* 👎 注意：作り方をミスると “上書きで増殖” しがち（設計が大事）

この章では **両方やる**よ😄✨

---

## 4) ハンズオン：seed を作る（ファイル準備）📁✍️

プロジェクト直下に、こんな構成を作ろう👇

* `db/init/00_schema.sql`
* `db/init/10_seed.sql`
* `db/reset.sql`（あとで使う・方式B用）

### 4-1) `db/init/00_schema.sql`（テーブル作成）🧱

```sql
-- db/init/00_schema.sql
-- Todo API 用：最低限のテーブル

CREATE TABLE IF NOT EXISTS app_users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS todos (
  id SERIAL PRIMARY KEY,
  user_id INT NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  done BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_todos_user_id ON todos(user_id);
```

### 4-2) `db/init/10_seed.sql`（初期データ投入）🌱

```sql
-- db/init/10_seed.sql
-- まずは “基準データ” を少なめに入れるのがコツ🙂

INSERT INTO app_users (name)
VALUES ('dev-user')
ON CONFLICT DO NOTHING;

-- SERIALなので、id=1 になる前提に寄せる（開発用ならOK）
-- もっと堅くしたいなら、RETURNING でidを受けて使う設計にしよう👍

INSERT INTO todos (user_id, title, done)
VALUES
  (1, 'Dockerのseedを理解する', FALSE),
  (1, 'データを壊して戻す', FALSE),
  (1, '次章でバックアップもやる', FALSE);
```

> 💡 seedは **“少なめ・軽め・固定”** が超おすすめ！
> 入れすぎると遅いし、レビューも地獄になる😇🔥

---

## 5) ハンズオン：Postgres を “ボリューム付き” で起動する🐳🗄️

Dockerは永続化に **volume を推奨**してるよ（ホスト依存が少なくて管理しやすい）🧠✨ ([Docker Documentation][6])

### 5-1) まずボリューム作成🧰

```bash
docker volume create todo_pgdata
```

### 5-2) Postgresコンテナ起動（seed自動実行）🚀

#### ✅ WSL（bash）例

```bash
docker run --name todo-db ^
  -e POSTGRES_PASSWORD=postgres ^
  -e POSTGRES_DB=todo ^
  -v todo_pgdata:/var/lib/postgresql/data ^
  -v "$(pwd)/db/init:/docker-entrypoint-initdb.d" ^
  -d postgres:18
```

> `db/init` を `/docker-entrypoint-initdb.d` にマウントしてるので、**初回起動でSQLが自動実行**されるよ✅ ([Docker Hub][4])

### 5-3) seedされたか確認🔍

```bash
docker logs todo-db --tail 100
```

次にDBの中を覗くよ🕵️‍♂️✨（ホストから繋がなくてOK）

```bash
docker exec -it todo-db psql -U postgres -d todo -c "\dt"
docker exec -it todo-db psql -U postgres -d todo -c "select * from app_users;"
docker exec -it todo-db psql -U postgres -d todo -c "select * from todos order by id;"
```

---

## 6) ハンズオン：わざと壊す😈🧨 → 戻す😇✨

### 6-1) 壊す（ぐちゃぐちゃにする）🧪

```bash
docker exec -it todo-db psql -U postgres -d todo -c "update todos set done=true;"
docker exec -it todo-db psql -U postgres -d todo -c "insert into todos(user_id,title,done) values (1,'ゴミデータ',true);"
docker exec -it todo-db psql -U postgres -d todo -c "select * from todos order by id;"
```

はい、汚れた😆🗑️

---

## 7) 戻し方A：ボリュームごと消して “完全初期化” 🧼🗑️

`/docker-entrypoint-initdb.d` の自動実行は **「データディレクトリが空のときだけ」** なので、戻すには **ボリューム削除**が効くよ⚠️ ([GitHub][5])

### 7-1) コンテナ削除 → ボリューム削除 → 作り直し🔁

```bash
docker stop todo-db
docker rm todo-db
docker volume rm todo_pgdata
docker volume create todo_pgdata

docker run --name todo-db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=todo \
  -v todo_pgdata:/var/lib/postgresql/data \
  -v "$(pwd)/db/init:/docker-entrypoint-initdb.d" \
  -d postgres:18
```

### 7-2) 確認（初期状態に戻ってる？）✅

```bash
docker exec -it todo-db psql -U postgres -d todo -c "select * from todos order by id;"
```

**戻ったー！🎉** これが “壊してOK” になる感覚だよ💪😄

> ⚠️ `docker volume prune` は「未使用ボリュームをまとめて消す」コマンド。便利だけど、勢いでやると事故るので要注意だよ😇 ([Docker Documentation][7])

---

## 8) 戻し方B：ボリュームは残して “再seed” する（方式B）🔁🌱

「毎回ボリューム消すのは重い/怖い」って時は、**reset用SQLを流し込む**が便利✨

### 8-1) `db/reset.sql` を作る🧯

```sql
-- db/reset.sql
-- “今あるデータを捨てて、初期状態を作り直す” 用
-- 開発専用だよ⚠️ 本番でやったら泣く😭

BEGIN;

TRUNCATE TABLE todos RESTART IDENTITY CASCADE;
TRUNCATE TABLE app_users RESTART IDENTITY CASCADE;

INSERT INTO app_users (name) VALUES ('dev-user');

INSERT INTO todos (user_id, title, done)
VALUES
  (1, 'Dockerのseedを理解する', FALSE),
  (1, 'データを壊して戻す', FALSE),
  (1, '次章でバックアップもやる', FALSE);

COMMIT;
```

### 8-2) reset.sql を流す（bash）📨

```bash
cat db/reset.sql | docker exec -i todo-db psql -U postgres -d todo
```

### 8-3) reset.sql を流す（PowerShell）📨🪟

```powershell
Get-Content db\reset.sql | docker exec -i todo-db psql -U postgres -d todo
```

### 8-4) 確認✅

```bash
docker exec -it todo-db psql -U postgres -d todo -c "select * from todos order by id;"
```

---

## 9) seed設計のコツ（ここが上手いと開発が爆速）⚡🧠

### ✅ コツ1：seedは “少なく・固定” が最強🌱

* ユーザー1人＋Todo3件、みたいな **再現用の最小セット**でOK🙆‍♂️

### ✅ コツ2：毎回同じ結果になる（決定的）🔁

* 「実行するたびに件数が増える」seedはストレスMAX😇
* 方式A（初回のみ）なら増殖しにくい
* 方式B（いつでも）なら **TRUNCATE + RESTART IDENTITY** みたいに “消してから入れる” が安全👍

### ✅ コツ3：seed失敗時は “空じゃないと再実行されない” を思い出す⚠️

* init用SQLは、初回起動時にまとめて走るけど
  途中で失敗して再起動すると「もう空じゃない扱い」になって続きが走らない…が起きうる😵‍💫
  その時は **ボリュームを消してやり直す**のが早いよ🧹 ([GitHub][5])

---

## 10) AI活用コーナー🤖✨（ここめっちゃ効く）

### 🧠 ① seedの“最小データ”を一緒に決める

* 「Todo APIの動作確認に必要な最小のseedデータを提案して。ユーザー1、Todo3、完了/未完了の混在、期限あり/なし、みたいに“テスト観点”で。」

### 🧠 ② reset.sql をレビューさせる

* 「このreset.sql、増殖や参照整合性の事故が起きない？危ない点があれば直して。」

### 🧠 ③ “壊して戻す” 用のコマンドを短縮する

* 「Windows（PowerShell）用に、DBリセットを1コマンドにまとめたい。安全に書くならどうする？」

---

## 11) 章末チェック✅（できたら勝ち🏆）

* [ ] seedが何のためにあるか説明できる🙂
* [ ] `/docker-entrypoint-initdb.d` 方式で初期投入できた🌱 ([Docker Hub][4])
* [ ] データを壊して、ボリューム削除で戻せた🧼
* [ ] `reset.sql` を `docker exec -i` で流して戻せた📨✨

---

## 12) おまけ：今回の “最新寄りメモ” 📝🆕

* Nodeは **v24がActive LTS**、v25はCurrent（奇数系）だよ🟩🟨 ([Node.js][8])
  （開発教材は基本LTSを軸にすると安心😌）
* TypeScriptは **5.9系のリリースノートが公開**されてるよ🧩 ([typescriptlang.org][9])
* PostgreSQLは **18系が最新メジャー**（2025-09-25）🐘🆕 ([PostgreSQL][3])

---

## 次章につながる一言🎯

seedができると「戻せる安心」が手に入るけど、さらに強くするなら **バックアップ/リストア**（第19章）で“保険”を持つと無敵になるよ💾🛡️😄

[1]: https://chatgpt.com/c/6987a62e-9edc-83a2-a862-5cb722c08a5b "Docker bind mount vs volume"
[2]: https://chatgpt.com/c/6987816a-1010-83a3-94b5-dc0ee44e07b9 "Docker準備ガイド"
[3]: https://www.postgresql.org/about/news/postgresql-18-released-3142/?utm_source=chatgpt.com "PostgreSQL 18 Released!"
[4]: https://hub.docker.com/_/postgres?utm_source=chatgpt.com "postgres - Official Image"
[5]: https://github.com/docker-library/docs/blob/master/postgres/README.md?utm_source=chatgpt.com "docs/postgres/README.md at master · docker-library/docs"
[6]: https://docs.docker.com/engine/storage/volumes/?utm_source=chatgpt.com "Volumes"
[7]: https://docs.docker.com/reference/cli/docker/volume/prune/?utm_source=chatgpt.com "docker volume prune"
[8]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[9]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
