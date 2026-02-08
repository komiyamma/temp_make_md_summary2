# 第34章：環境変数をcompose側で管理する🎛️

今回のゴールはこれ👇

* ✅ **APIとDBの設定（接続先・ポート・モード等）を、Composeでまとめて管理**できる
* ✅ **「どこで設定した値が勝つの？」問題（優先順位）**を卒業する
* ✅ `.env` / `environment:` / `env_file:` を **使い分け**できるようになる

---

## 1) まずここ！環境変数は「2種類」ある🧠💡

Compose界隈の環境変数は、混乱ポイントが2つに分かれてるよ👇

## A. 「Composeファイルの中で使う」変数（＝補間/Interpolation用）🧩

* 例：`ports: "${API_PORT}:3000"` みたいに **compose.yamlの文字列に埋め込む**
* どこから読む？

  1. **シェルの環境変数** → 2) **(未指定なら) PWDの `.env`** → 3) **`--env-file`で指定したファイル or project dirの `.env`**
     という優先順位だよ。([Docker Documentation][1])
* 確認コマンド：`docker compose config --environment` が超便利！([Docker Documentation][1])

## B. 「コンテナの中に入れる」環境変数（＝実行時の環境変数）📦

* 例：Nodeの `process.env.DATABASE_URL` とか、Postgresの `POSTGRES_PASSWORD` とか
* 入れ方は主に2つ👇

  * `environment:` … compose.yamlに直書き（または `${VAR}` で補間）([Docker Documentation][2])
  * `env_file:` … ファイルからまとめて注入([Docker Documentation][2])

そして優先順位はざっくり👇（重要！）

* `docker compose run -e ...` が最強
* 次に `environment:`
* 次に `env_file:`
* その下にイメージ側 `ENV`
  って感じ。([Docker Documentation][3])

---

## 2) ハンズオン：Todo API + DB で「環境変数を一元管理」してみる🚀📝

## 2-1) 置き場所を決める📁

おすすめはこう👇（シンプルで事故りにくい）

* `compose.yaml`
* `.env`（**補間用**。Gitには入れない）
* `.env.example`（**雛形**。これはGitに入れる）

## 2-2) `.env` を作る（補間の元ネタ）✍️

プロジェクト直下に `.env`：

```env
## API公開ポート（ホスト側）
API_PORT=3000

## DB（開発用）
POSTGRES_DB=todo
POSTGRES_USER=todo
POSTGRES_PASSWORD=todo_password

## たまに便利：Composeのプロジェクト名固定（任意）
COMPOSE_PROJECT_NAME=todo-api
```

💡 `.env` は漏れると悲しいので **`.gitignore` に入れる**のが基本ね🙅‍♂️
代わりに `.env.example` を作って、値はダミーにしてコミットするのが定番👍

---

## 2-3) `compose.yaml` を「環境変数前提」に書き換える🧩

（第33章のAPI＋DB構成を、envで読み替えるイメージ！）

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      # ここはDB公式イメージが読む変数たち
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - db-data:/var/lib/postgresql/data

  api:
    build: ./apps/api
    environment:
      # API側が使う接続情報（ホスト名はサービス名 "db"！）
      DB_HOST: db
      DB_PORT: "5432"
      DB_NAME: ${POSTGRES_DB}
      DB_USER: ${POSTGRES_USER}
      DB_PASSWORD: ${POSTGRES_PASSWORD}

      # 1本のURLにまとめたい派はこっちもOK（好みで）
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}

      NODE_ENV: development
    ports:
      - "${API_PORT}:3000"
    depends_on:
      - db

volumes:
  db-data:
```

ポイント🎯

* `${POSTGRES_USER}` みたいな **`${...}` は「補間」**（＝Aの世界）
* その結果を `environment:` で **コンテナへ注入**（＝Bの世界）

---

## 2-4) 起動して、コンテナ内で確認する👀🪵

```bash
docker compose up -d --build
```

✅ APIコンテナに入って、環境変数が入ってるか見る：

```bash
docker compose exec api sh -lc "printenv | sort | grep -E 'DB_|DATABASE_URL|NODE_ENV'"
```

✅ DB側も見てみる：

```bash
docker compose exec db sh -lc "printenv | sort | grep -E 'POSTGRES_'"
```

✅ さらに「Composeがどの値を使って補間したか」を確認（超おすすめ）：

```bash
docker compose config --environment
```

このコマンドで、**「あれ？なんでこの値になった？」**がかなり潰せるよ。([Docker Documentation][1])

---

## 3) 罠ポイント集中講座🪤😵‍💫（ここで詰まりがち！）

## 罠①：`.env` に書いたのに反映されない😇

原因の多くはこれ👇

* **あなたのシェル（PowerShell/WSL）の環境変数が、`.env` より優先**されて勝ってる

補間の優先順位は「シェルが最優先」だよ。([Docker Documentation][1])

対策（例）🧹

* PowerShellなら一時的に消す：`Remove-Item Env:POSTGRES_PASSWORD`
* あるいは **`--env-file` で明示**して、使うファイルを固定する

---

## 罠②：環境変数変えたのにコンテナがそのまま🤔

環境変数は **コンテナ作成時の設定**なので、変更後に反映するにはだいたい👇が必要

* `docker compose up -d`（差分があれば作り直されることが多い）
* それでもダメなら `--force-recreate`

```bash
docker compose up -d --force-recreate
```

---

## 罠③：Postgresのパスワード変えたのにログインできない😇（超ある）

`POSTGRES_PASSWORD` などは **「初期化（空のデータディレクトリ）時だけ効く」**ことがある！([Docker Hub][4])
つまり、すでにボリュームにDBが入ってる状態で `.env` を変えても、**DB内部のユーザー/パスは自動で変わらない**。

対策は2択👇

* 開発なら：**ボリューム消して初期化し直す**（データ捨ててOKなら最速）
* データ残すなら：SQLで `ALTER USER ...` とかをやる（次章以降で！）

---

## 4) いい感じの運用ルール（初心者に優しいやつ）📏😊

おすすめの結論はこれ👇

* ✅ **補間用（compose.yaml内で${...}に使う）**は `.env` を基準にする([Docker Documentation][1])
* ✅ **コンテナに入れる**のは `environment:` を基本にする([Docker Documentation][2])
* ✅ **秘密情報を環境変数で渡すのは避けたい**（本番系は特に）→ Compose **secrets** を検討([Docker Documentation][2])

---

## 5) おまけ：DBパスワードだけ “secrets” にする（安全寄せ）🔐✨

Docker公式も「パスワード等は secrets を使おう」って言ってるよ。([Docker Documentation][2])

Postgres公式イメージは `POSTGRES_PASSWORD_FILE` みたいな形で **ファイルから読む**のをサポートしてる（secretsと相性良い）([Docker Hub][4])

例（最小）👇

* `secrets/db_password.txt` を作って中にパスワードを書く（Gitには入れない）
* compose.yaml：

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

これで **compose.yaml や `.env` に生パスワードを書かずに**いける👍
（もちろん `secrets/` 自体は `.gitignore` 推奨！）

---

## 6) AI（GitHub Copilot / OpenAI Codex）に頼むと強いポイント🤖💬

そのままコピペで使える質問例👇

* 「`compose.yaml` の環境変数がどこから来て、どれが勝つか、**優先順位を図解（文章）**して」
* 「今の `compose.yaml` を貼るので、**`.env` と `environment` の設計ミス**を指摘して」
* 「DB接続情報（HOST/PORT/USER/PASS/DB）を、**名前のルール**付きで提案して（例：`DB_` 接頭辞で統一）」
* 「`docker compose config --environment` の結果を貼るので、**意図とズレてる変数だけ**教えて」

---

## まとめ🏁🎉

* 環境変数は **「補間（Composeが読む）」**と **「コンテナ注入（実行時）」**の2段構え！
* 迷ったら `docker compose config --environment` で可視化するのが最強([Docker Documentation][1])
* 優先順位は **シェルが強い**＆ **environment が env_file より強い**を覚える([Docker Documentation][1])
* DB系は「初期化時だけ効く変数」があるので、変えても反映されない罠に注意！([Docker Hub][4])

---

次の第35章は「Composeでボリューム定義」だから、今回の `.env` とセットで「DBデータを守る」まで一気に気持ちよく繋がるよ😆🧱💾

[1]: https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/ "Interpolation | Docker Docs"
[2]: https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/ "Set environment variables | Docker Docs"
[3]: https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/ "Environment variables precedence | Docker Docs"
[4]: https://hub.docker.com/_/postgres "postgres - Official Image | Docker Hub"
