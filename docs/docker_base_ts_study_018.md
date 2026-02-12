# 第18章：初期データ（seed）と“開発データの作り直し”🌱

## 0) まずイメージ🍀

開発中って、こうなるよね👇😵‍💫

* 変なデータ入れた → 画面がおかしい🙃
* 仕様変えた → 旧データが邪魔😇
* 直したい → でも「DB初期化が怖い」😱

そこで **seed** の出番！✨
seedがあると、DBが壊れても **「よし、作り直そ😄」** ができるようになるよ👍

---

## 1) seedってなに？（超ざっくり）🌰

**seed = “最初から入っててほしいデータ”** のこと🌱
例：

* 開発用のサンプルTodo（「牛乳買う」🥛）
* 開発用のユーザー（admin / test）👤
* マスタ（ステータス一覧：TODO/DOING/DONE）🏷️

ポイントはこれ👇✨
✅ **「何度でも同じ状態に戻せる」**
✅ **「やり直しが速い」**

---

## 2) seedには“2種類”ある（ここ大事）🧠✨

## A. 初回だけ自動で入るseed（自動初期化）🤖🌱

PostgreSQL公式イメージは、`/docker-entrypoint-initdb.d` に置いた `*.sql` や `*.sh` を**初回起動時（DBが空のとき）だけ**実行してくれる仕組みがあるよ📦✨
※逆に言うと、**一度DBが作られると2回目以降は走らない**（「なんで実行されないの😭」の原因No.1） ([Docker Hub][1])

## B. 何度でも入れ直せるseed（手動 or コマンド化）🔁🌱

開発ではこっちが超大事💪

* `TRUNCATE`（全消し）→ `INSERT`（入れ直し）で、いつでもリセットできる✨

---

## 3) ハンズオン：PostgreSQLにseedを入れて、作り直せるようにする🐘🎮

## ゴール🏁

* DBを起動した瞬間に「サンプルTodoが入ってる」🌱
* 失敗したら「DBを初期化してやり直し」できる🧯

---

## Step 1：seed用ファイルを作る📁✍️

プロジェクト直下にこんなフォルダを作るよ👇

* `db/init/10_seed.sql`（初回自動用）
* `db/reset/90_reset_and_seed.sql`（何度でも用）

## `db/init/10_seed.sql`（初回だけ走るやつ）🌱

```sql
-- 例：超ミニTodoテーブル（まずは体験用にSQLで作っちゃう）
CREATE TABLE IF NOT EXISTS todos (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  done BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 初期データ
INSERT INTO todos(title, done) VALUES
  ('牛乳を買う🥛', false),
  ('Dockerのseedを理解する🌱', false),
  ('Todo APIを育てる🌱📦', false);
```

> ※本格運用では「テーブル作成」は migrations（Prisma/TypeORM等）に寄せたいけど、
> この章はまず “seedの手触り” を最優先でOK🙆‍♂️✨

---

## Step 2：PostgreSQLを“初回seed付き”で起動する🚀

## 重要：PostgreSQL 18+ は **Volumeのマウント先が変わった**よ⚠️

* 18+ は `VOLUME` が `/var/lib/postgresql` に変わって、`PGDATA` もバージョン付きになった（例：`/var/lib/postgresql/18/docker`）
  なので **Volumeは `/var/lib/postgresql` に付けるのが安全**🧱 ([Docker Hub][1])

起動コマンド（VS CodeのWSLターミナル想定）👇🐧🪟

```bash
docker rm -f todo-db 2>/dev/null || true
docker volume rm todo_pgdata 2>/dev/null || true
docker volume create todo_pgdata

docker run -d --name todo-db \
  -e POSTGRES_PASSWORD=pass1234 \
  -e POSTGRES_DB=todo \
  -p 5432:5432 \
  --mount type=volume,src=todo_pgdata,dst=/var/lib/postgresql \
  -v "$PWD/db/init:/docker-entrypoint-initdb.d:ro" \
  postgres:18
```

ログを見る👀（seedが走ると、それっぽいログが出ることが多いよ）

```bash
docker logs -f todo-db
```

中身チェック✅

```bash
docker exec -it todo-db psql -U postgres -d todo -c "SELECT * FROM todos;"
```

🎉 3件くらい出たら勝ち！🏆🥳

---

## 4) “作り直し”のやり方は2つ（開発はここが本番）🧯✨

## 方式①：完全リセット（最強だけど雑に消える）🗑️💥

**Volumeを消す** → **初回扱いになる** → initが走る🌱

```bash
docker rm -f todo-db
docker volume rm todo_pgdata
docker volume create todo_pgdata

docker run -d --name todo-db \
  -e POSTGRES_PASSWORD=pass1234 \
  -e POSTGRES_DB=todo \
  -p 5432:5432 \
  --mount type=volume,src=todo_pgdata,dst=/var/lib/postgresql \
  -v "$PWD/db/init:/docker-entrypoint-initdb.d:ro" \
  postgres:18
```

👍 良いところ：確実に最初からやり直せる
⚠️ 注意：本当に消える（“守るべきデータ”でやらない！）

---

## 方式②：データだけリセット（普段はこっちが便利）🔁🌱

initは初回しか走らないから、**開発用に「何度でもseedできるSQL」**を用意するよ💪✨
PostgreSQL公式の “initは初回のみ” 仕様があるからね🧠 ([Docker Hub][1])

## `db/reset/90_reset_and_seed.sql`（いつでも戻せるやつ）🧹🌱

```sql
-- ぜんぶ消して、IDもリセット（TodoならこれでOK）
TRUNCATE TABLE todos RESTART IDENTITY;

INSERT INTO todos(title, done) VALUES
  ('リセット完了！✨', false),
  ('また最初から育てよう🌱', false),
  ('DBは怖くない😄', false);
```

実行コマンド👇

```bash
docker exec -i todo-db psql -U postgres -d todo < ./db/reset/90_reset_and_seed.sql
docker exec -it todo-db psql -U postgres -d todo -c "SELECT * FROM todos;"
```

🎉 これで「やらかしたら戻す」が秒速になる⚡

---

## 5) seed設計の“ミニルール”（事故りにくくなる）📏✨

## ルールA：seedは“作業用”と“マスタ用”で分ける🏷️🧰

* **マスタ（ステータス等）**：基本ずっと必要
* **作業用データ（サンプルTodo等）**：いつでも捨ててOK

→ `seed/master.sql` と `seed/dev.sql` みたいに分けると気持ちいい😄

## ルールB：何度やっても同じ結果にする（または一回消してから入れる）🔁

* 初心者はまず **「TRUNCATE → INSERT」方式**が安心🧯
* 慣れてきたら `ON CONFLICT DO NOTHING` などで **二重投入に強く**できる💪

## ルールC：Windows + WSL2は“置き場所”で速度が変わる⚡🪟🐧

bind mountするソースは、Windows側より **Linux側ファイルシステム（WSL側）**に置くのが推奨だよ（速い＆安定）🚀 ([Docker Documentation][2])

---

## 6) よくある詰まり集（この章の罠トップ3）🪤😭

## 詰まり①：initが実行されない😱

原因あるある👇

* すでにVolumeにデータが入ってる（= “初回”じゃない）
  対処👇
* **Volume消す** or **別Volume名にする** or **方式②（TRUNCATE→seed）**に切り替える
  （initが初回のみ仕様） ([Docker Hub][1])

## 詰まり②：PostgreSQL 18に上げたら永続化が壊れた💥

原因👇

* 18+でマウント先が変わったのに、昔のまま `/var/lib/postgresql/data` に付けてる
  対処👇
* Volumeは **`/var/lib/postgresql` に付ける**（公式の変更点）🧱 ([Docker Hub][1])

## 詰まり③：改行や権限でSQLがコケる😵

対処のコツ👇

* `docker logs todo-db` を見る👀
* WSL側でファイル作る（改行トラブル減りやすい）🐧🪟
* `:ro` を付けて “読み取り専用” にすると事故が減る🛡️

---

## 7) AI活用コーナー🤖✨（この章はAIが強い）

## プロンプト例①：seed案を作らせる🌱

「Todo APIの開発用seedを考えて。ユーザー、Todo、ステータスの例を作って。SQLで。初心者向けで。」

## プロンプト例②：リセットSQLを安全にしてもらう🧯

「PostgreSQLで、テーブルを安全に初期化してseed入れるSQLを書いて。TRUNCATEの注意点も短く。」

## プロンプト例③：エラー貼って“次の一手”を聞く🔍

「このdocker logsのエラーの原因候補トップ3と、確認コマンドを順番に：＜ログ＞」

---

## まとめ🏁🎉

* **seedがあると、開発が爆速になる⚡🌱**
* **init（初回だけ）**と**reset（何度でも）**を分けるのがコツ🧠✨ ([Docker Hub][1])
* PostgreSQL 18+ は **Volumeの付け先に注意**🧱 ([Docker Hub][1])
* Windows+WSL2は、bind mountの置き場所で体感が変わる⚡ ([Docker Documentation][2])

---

## ミニ確認クイズ🎓📝

1. `/docker-entrypoint-initdb.d` のSQLが実行されるのは「いつ」？🤔
2. 開発で何度もseedを入れ直すなら、どんな方式が楽？🔁
3. PostgreSQL 18+ でVolumeを付ける“おすすめ先”は？🐘

（答え）

1. **DBが空の初回だけ** ([Docker Hub][1])
2. **TRUNCATE → INSERT（reset SQLを用意）** 🌱
3. **`/var/lib/postgresql`** 🧱 ([Docker Hub][1])

次の章は **バックアップ/リストア最小セット💾**！「やらかしても戻せる保険」へ進むよ〜😄🛡️

[1]: https://hub.docker.com/_/postgres?utm_source=chatgpt.com "postgres - Official Image"
[2]: https://docs.docker.com/desktop/features/wsl/best-practices/?utm_source=chatgpt.com "Best practices"
