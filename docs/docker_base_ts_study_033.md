# 第33章：サービスを2つに増やす（API＋DB）🧠

この章は「APIだけ」から一歩進んで、**API＋DBを同時に起動して、ちゃんと繋がる**ところまでやります😆🎉
Composeファイルは基本 `compose.yaml` が標準扱い（推奨）なので、ここでもそれで進めます🗂️✨ ([Docker Documentation][1])

---

## 今日のゴール🏁✨

* `docker compose up` 一発で **API と DB が両方起動**できる🚀
* API から DB へ **サービス名で接続**できる（`localhost` じゃない！）🧠
* DB が起動準備できるまで **APIを待たせる**（`healthcheck`＋`depends_on`）⏳✅ ([Docker Documentation][2])
* “よくある罠”で詰まっても、自力で復帰できる🧯💪

---

## 全体像を1枚で📌🗺️

* ブラウザ → `localhost:3000` → **API**（Node/TS）
* **API** → `db:5432` → **DB**（PostgreSQL）
* Compose が同じネットワークを作ってくれるので、**サービス名（db）で名前解決**できるよ🏷️🌐 ([Docker Documentation][2])

---

## まずはフォルダ構成📁✨

こんな感じに置くのがおすすめ（例）👇

```text
todo-api/
  compose.yaml
  api/
    package.json
    package-lock.json
    tsconfig.json
    src/
      index.ts
```

---

## ステップ1：`compose.yaml` を作る🧩✍️

ルート（`todo-api/`）に `compose.yaml` を作って、これを貼ってOK👇
（Nodeは安定版として **v24（Active LTS）** を採用する想定🧱✨） ([nodejs.org][3])

> ⭐DBは **PostgreSQL 18** を例にします。
> PostgreSQL 18 から公式イメージの **データディレクトリ（VOLUME/PGDATA周り）が変更**されていて、永続化マウント先は `/var/lib/postgresql` を狙うのが推奨です⚠️（ここ超重要） ([Docker Hub][4])

```yaml
services:
  api:
    image: node:24-bookworm
    working_dir: /app

    # ホストのコードをコンテナへ共有（即反映）📎
    volumes:
      - ./api:/app
      # node_modulesはコンテナ側（ボリューム）に置くのが安定💡
      - api-node-modules:/app/node_modules

    ports:
      - "3000:3000"

    environment:
      PORT: "3000"
      # ここ超大事！ DBホストは localhost じゃなくて「サービス名 db」🏷️
      DATABASE_URL: "postgresql://todo:todo@db:5432/tododb"

      # Windowsでファイル監視が不安定ならON（必要な時だけ）🪟
      # WATCHPACK_POLLING: "true"

    depends_on:
      db:
        condition: service_healthy

    # 初回はnpm installが走る（2回目以降はnode_modulesボリュームで速い）⚡
    command: sh -c "npm install && npm run dev"

  db:
    image: postgres:18
    environment:
      POSTGRES_USER: todo
      POSTGRES_PASSWORD: todo
      POSTGRES_DB: tododb

    # DBが「接続OK」になるまでを判定する🩺
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U todo -d tododb"]
      interval: 5s
      timeout: 5s
      retries: 10

    # PostgreSQL 18+ は /var/lib/postgresql を永続化先にするのが推奨⚠️
    volumes:
      - db-data:/var/lib/postgresql

    # DBをホストに公開したい時だけ（普段は閉じてOK）🔒
    # ports:
    #   - "5432:5432"

volumes:
  api-node-modules:
  db-data:
```

## ここで覚える「最重要ポイント」3つ🧠🔥

1. **DB接続先は `db`**（サービス名）
2. `depends_on` は “順番” だけじゃ不十分なことがある → **`healthcheck`＋`condition: service_healthy`** が安心😌✅ ([Docker Documentation][2])
3. PostgreSQL 18 は **永続化先パスが変わった**（古い記事の `/var/lib/postgresql/data` だと事故りやすい）⚠️ ([Docker Hub][4])

---

## ステップ2：API側を最小で用意（Node/TS）🛠️✨

`api/` に移動して、必要なものを入れます👇

```bash
cd api
npm init -y
npm i express pg
npm i -D typescript tsx @types/express @types/node
npx tsc --init
```

`api/package.json` の scripts をこんな感じに（例）👇

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts"
  }
}
```

`api/src/index.ts` を作って貼る👇（**DBに繋いで `SELECT 1`** するだけの健康診断付き🩺）

```ts
import express from "express";
import { Pool } from "pg";

const app = express();

const port = Number(process.env.PORT ?? 3000);
const databaseUrl = process.env.DATABASE_URL;

if (!databaseUrl) {
  throw new Error("DATABASE_URL is missing");
}

const pool = new Pool({ connectionString: databaseUrl });

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ ok: true });
  } catch (e: any) {
    res.status(500).json({ ok: false, error: String(e?.message ?? e) });
  }
});

app.listen(port, () => {
  console.log(`API listening on http://localhost:${port}`);
});
```

---

## ステップ3：起動する🚀🎉

ルート（`compose.yaml` がある場所）で👇

```bash
docker compose up -d
docker compose ps
```

ログも見よう👀（困ったらここ！）

```bash
docker compose logs -f db
docker compose logs -f api
```

---

## ステップ4：動作確認✅🌟

## 1) API が生きてる？

ブラウザで👇
`http://localhost:3000/health`

* `{"ok":true}` が返ったら勝ち🏆✨

## 2) DB に入って確認（最短）🧑‍🔧

```bash
docker compose exec db psql -U todo -d tododb -c "select now();"
```

---

## よくある罠🪤😵‍💫（ここだけで30分溶けるやつ）

## 罠1：`localhost` でDBに繋ごうとして死ぬ💥

* **APIコンテナの中の `localhost` は「APIコンテナ自身」**だよ😇
* DBは別コンテナだから、接続先は **`db`**（サービス名）にする🏷️✨ ([Docker Documentation][2])

✅ 対策：`DATABASE_URL` のホストを `db` にする（この章の compose.yaml はOK）

---

## 罠2：`ECONNREFUSED`（DBがまだ準備中）⏳💥

DBって “コンテナ起動” と “接続受付OK” の間にタイムラグがあるんだよね😅
Compose公式も「起動時、コンテナが ready になるのを待たない（running まで）」って明言してて、だから **healthcheck が必要**になることがあるよ、って説明してる📘 ([Docker Documentation][2])

✅ 対策：この章の通り

* `db.healthcheck` を入れる
* `depends_on: condition: service_healthy` で待つ

---

## 罠3：パスワード変えたのに反映されない🔐😵

PostgreSQL公式イメージは、**初期化は「データディレクトリが空のときだけ」**走るタイプ。
だから一度ボリュームにデータが入ると、`POSTGRES_PASSWORD` を変えても “既存DB” はそのまま…ってことがある😇 ([Docker Hub][5])

✅ 対策（開発中だけ使う奥義⚠️）

* ボリュームごと作り直す（データ消えるよ！）🧨

```bash
docker compose down -v
docker compose up -d
```

---

## ちょい設計メモ📏🧠（超入門者向け）

* **DBは外にポート公開しなくてOK**（まずは内部だけで安全運用🔒）
* DB接続文字列はひとまず `DATABASE_URL` に1本化でOK（次章で整理🎛️）
* “起動を待つ” は Compose だけに任せず、アプリ側も将来的にリトライ持てると強い💪✨（本番っぽくなる）

---

## AI活用コーナー🤖✨（そのままコピペOK）

* 「この `compose.yaml` で初心者がハマりそうな点を **優先順位つきで5個** 教えて」
* 「`ECONNREFUSED` が出た。ログ（貼る）から **原因候補トップ3** と **確認コマンド** を出して」
* 「`DATABASE_URL` を環境ごとに分けたい。次章の方針（`.env`/profilesなど）を先に設計案で」
  （AIは GitHub の Copilot や OpenAI 系でもOK👌🤖）

---

## まとめ🎓✨

* Composeで **API＋DBの2サービス** にできた🎉
* 接続先は `localhost` じゃなくて **サービス名（db）**🏷️
* **healthcheck＋service_healthy** で “DB待ち問題” を潰した🧯✅ ([Docker Documentation][2])
* PostgreSQL 18 の永続化パス変更も踏まえた（2026対応）⚠️ ([Docker Hub][4])

---

次の第34章は、ここで直書きした環境変数たちを **Compose側で気持ちよく管理**して「設定迷子」を卒業する回だよ🎛️😆

[1]: https://docs.docker.com/compose/intro/compose-application-model/?utm_source=chatgpt.com "How Compose works | Docker Docs"
[2]: https://docs.docker.com/compose/how-tos/startup-order/ "Control startup order | Docker Docs"
[3]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[4]: https://hub.docker.com/_/postgres?utm_source=chatgpt.com "postgres - Official Image"
[5]: https://hub.docker.com/_/postgres "postgres - Official Image | Docker Hub"
