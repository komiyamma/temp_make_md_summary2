# 第18章：DBありの統合テスト（Composeで起動）🧱🧪

この章では「**本物のDB（Postgres）を、Docker Composeで起動して**」「**Vitestで統合テストを回す**」ところまで作ります😊
モックじゃ拾えない **制約（UNIQUE/NOT NULL）・SQLの挙動・実DB接続の落とし穴**を、ちゃんとテストできるようにするのがゴールです🔥

---

## 1) まず“統合テスト”って何を守るの？🧠✨

ユニットテストが「関数の正しさ」を守るなら、DBあり統合テストはこういうのを守ります👇

* ✅ **SQLが正しい**（JOIN/WHERE/ORDERのミスを拾う）
* ✅ **制約が効いてる**（UNIQUE違反、外部キー、NULL禁止など）
* ✅ **実際の接続情報で動く**（接続先ホスト名・認証・タイムアウト）
* ✅ **マイグレーション/初期化が成立してる**（起動したらスキーマがある）

そしてComposeで起動すると「**DBが必要な時だけ**」「**同じ手順で**」「**CIでもそのまま**」が作れます💪

---

## 2) 今回の“正解ルート”🧭（初心者でも事故りにくい）

ここは超大事。Composeは **起動順は見てくれるけど、準備完了までは待たない** んです😇
なので **healthcheck + depends_on(condition: service_healthy)** を入れて「DBが起きるまで待つ」を作ります。([Docker Documentation][1])

さらに、DB初期化（`/docker-entrypoint-initdb.d`）は **“空のデータディレクトリ”の時だけ実行**されます。([Docker Hub][2])
→ だからテストでは **匿名ボリューム + `docker compose up -V`（匿名ボリューム再生成）**が相性いいです👍([Docker Documentation][3])

---

## 3) Composeを“テスト用プロファイル”に分離する🧩

「普段の開発ではDBテスト用コンテナはいらない」ので、Composeの **profiles** を使います。([Docker Documentation][4])
テスト時だけ `--profile test` で起動できるようにします😊

---

## 4) 実装：compose.yaml（テスト用DB + テスト実行サービス）🛠️

プロジェクト直下に `compose.yaml` がある想定で、こうします👇

```yaml
services:
  db:
    image: postgres:18
    profiles: ["test"]
    environment:
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
      POSTGRES_DB: app_test
    # DBが本当に“接続可能”になるまで待てるようにする
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 20
      start_period: 5s
    volumes:
      # 初期SQL（空のDBのときだけ実行される）
      - ./db/init:/docker-entrypoint-initdb.d:ro
      # 匿名ボリューム（-V で毎回作り直せる）
      - /var/lib/postgresql/data

  test:
    profiles: ["test"]
    build:
      context: .
    environment:
      DATABASE_URL: postgres://test:test@db:5432/app_test
    depends_on:
      db:
        condition: service_healthy
    command: ["npm", "run", "test:integration"]
```

ポイント👀

* `profiles: ["test"]` → テスト時だけ起動（普段は無視される）([Docker Documentation][4])
* `depends_on: condition: service_healthy` → DBのhealthcheck成功まで待つ([Docker Documentation][1])
* `./db/init` → 初期スキーマを入れる（ただし空DBのときだけ）([Docker Hub][2])
* `DATABASE_URL` のホストは `db`（Composeのサービス名）✨

---

## 5) DB初期化SQLを置く🧱📄

`db/init/001_schema.sql` を作ります👇

```sql
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL
);
```

UNIQUE制約があるので、「重複メール」を入れた時にちゃんと落ちるかがテストできます😊

---

## 6) Node側：最小のDBアクセス（pg）🐘

`pg` を使う例にします（軽くて分かりやすい）✨

## 6-1) 依存追加

```bash
npm i pg
npm i -D @types/pg
```

## 6-2) `src/db.ts`

```ts
import { Pool } from 'pg'

const connectionString = process.env.DATABASE_URL
if (!connectionString) throw new Error('DATABASE_URL is missing')

export const pool = new Pool({ connectionString })
```

## 6-3) `src/userRepo.ts`

```ts
import { pool } from './db'

export async function createUser(email: string, name: string) {
  const result = await pool.query(
    'INSERT INTO users(email, name) VALUES($1, $2) RETURNING id, email, name',
    [email, name],
  )
  return result.rows[0] as { id: number; email: string; name: string }
}

export async function findUserByEmail(email: string) {
  const result = await pool.query('SELECT id, email, name FROM users WHERE email = $1', [email])
  return (result.rows[0] ?? null) as null | { id: number; email: string; name: string }
}

export async function truncateAll() {
  await pool.query('TRUNCATE TABLE users RESTART IDENTITY CASCADE')
}
```

---

## 7) Vitest：統合テスト用の設定を分ける🧪⚙️

統合テストは **遅いし、並列で壊れやすい**ので「別設定」にするのが勝ちです😊
Vitestは **projects（旧workspace相当）**で “設定違いのテスト” を同居できます。([Vitest][5])

## 7-1) `vitest.integration.config.ts`

```ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['test/integration/**/*.test.ts'],
    testTimeout: 30_000,
    hookTimeout: 30_000,
    maxWorkers: 1, // DB共有するならまず1が安全👍
  },
})
```

## 7-2) `package.json` に追加

```json
{
  "scripts": {
    "test:integration": "vitest -c vitest.integration.config.ts run"
  }
}
```

---

## 8) 統合テストを書く（DBを本当に叩く）🧪🔥

`test/integration/users.test.ts`

```ts
import { beforeAll, beforeEach, afterAll, test, expect } from 'vitest'
import { pool } from '../../src/db'
import { createUser, findUserByEmail, truncateAll } from '../../src/userRepo'

beforeAll(async () => {
  // ここで接続できる＝Composeの起動待ちが効いてる👍
  await pool.query('SELECT 1')
})

beforeEach(async () => {
  await truncateAll()
})

afterAll(async () => {
  await pool.end()
})

test('ユーザーを作って検索できる', async () => {
  await createUser('a@example.com', 'Alice')
  const user = await findUserByEmail('a@example.com')
  expect(user?.name).toBe('Alice')
})

test('メール重複はUNIQUE制約で落ちる', async () => {
  await createUser('dup@example.com', 'A')

  await expect(() => createUser('dup@example.com', 'B')).rejects.toThrow()
})
```

Vitestの `beforeAll/beforeEach/afterAll` はこういう用途にピッタリです👌
重い処理（seedやサーバ起動）は “setupFilesよりglobal setup/ beforeAll” が向いてるよ、という話も公式で触れられてます。([Vitest][6])

---

## 9) いよいよ「Composeで起動してテスト」🚀

## 9-1) まずは手動で動作確認（2コマンド）

VS Codeのターミナルで👇

```bash
docker compose --profile test up --build -V --abort-on-container-exit --exit-code-from test
```

* `--exit-code-from test` は「testサービスの終了コードを返す」オプションで、同時に `--abort-on-container-exit` も効きます。([Docker Documentation][3])
* `-V` は匿名ボリュームを作り直すので、DB初期化SQLが毎回ちゃんと走りやすくなります👍([Docker Documentation][3])

終わったら後片付け👇

```bash
docker compose --profile test down --volumes --remove-orphans
```

## 9-2) “ワンコマンド化”する（失敗してもdownする）🧰✨

Windowsだと `&&` だけだと失敗時に掃除が飛びがちなので、Nodeスクリプトで安全にまとめます🙂

`scripts/test-it.mjs`

```js
import { spawnSync } from 'node:child_process'

function run(cmd, args, { allowFail = false } = {}) {
  const r = spawnSync(cmd, args, { stdio: 'inherit' })
  if (!allowFail && r.status !== 0) {
    process.exitCode = r.status ?? 1
    throw new Error(`${cmd} failed`)
  }
  return r.status ?? 0
}

let exitCode = 0
try {
  exitCode = run('docker', [
    'compose', '--profile', 'test',
    'up', '--build', '-V',
    '--abort-on-container-exit',
    '--exit-code-from', 'test',
  ])
} catch {
  // exitCodeは process.exitCode に入ってるのでOK
} finally {
  run('docker', ['compose', '--profile', 'test', 'down', '--volumes', '--remove-orphans'], { allowFail: true })
  process.exit(exitCode || process.exitCode || 0)
}
```

`package.json`

```json
{
  "scripts": {
    "test:it": "node scripts/test-it.mjs"
  }
}
```

これで👇が完成！🎉

```bash
npm run test:it
```

---

## 10) ミニ課題🎯（ここまでできたら強い）

## 課題A：制約テストを増やす🧩

* `name` を空で入れたら落ちる（NOT NULL）
* 期待：テストがfailするのを確認 → 正しい入力だけ通す設計に寄せる🙂

## 課題B：テストデータの“片付け”を変える🧹

* `TRUNCATE` を「各テスト（beforeEach）」→「各ファイル（beforeAll）」にして、速さの差を体感🏎️
  （ただし独立性は下がるので、どっちが好みか考える）

---

## 11) よくある詰まり💣（だいたいここ）

## ❌ `ECONNREFUSED` / `getaddrinfo ENOTFOUND db`

* テストがコンテナ内ならホストは `db`（サービス名）
* ローカルから叩くなら `localhost:5432`（ポート公開が必要）

## ❌ 初期SQLが反映されない

* `/docker-entrypoint-initdb.d` は **空DBの時だけ**なので、データが残ってると動かない😇([Docker Hub][2])
* 対策：`-V` を付ける / `down --volumes` で消す

## ❌ たまに落ちる（フレーク）

* 統合テストの並列が原因のこと多い
* 対策：`maxWorkers: 1`（まず安定させる！）

---

## 12) AIで時短🤖✨（GitHub Copilot / OpenAI Codex 使いどころ）

## 使えるプロンプト例💡

* 「compose.yamlに test profile を追加して、dbのhealthcheckとdepends_on(service_healthy)付きで、testサービスが `npm run test:integration` を実行する形にして」
* 「Vitestの統合テスト用設定ファイルを作って。DB共有だから maxWorkers=1、timeout長め。includeは test/integration/** にしたい」
* 「UNIQUE制約違反をちゃんとテストで検知する例を書いて。落ちるのを `rejects.toThrow()` で確認したい」

## AI出力の“確認ポイント”✅

* `DATABASE_URL` のホストが **db** になってる？
* `healthcheck` と `depends_on: condition: service_healthy` がある？([Docker Documentation][1])
* ボリュームが残って初期SQLが走らない罠にハマってない？([Docker Hub][2])

---

ここまでで「DBあり統合テストを、Composeで起動して、ワンコマンドで回す」基礎が完成です🧱🧪✨
次の章（カバレッジ）に行く前に、**“統合テストは少数精鋭でいい”**感覚だけ掴めると超強いですよ😊

[1]: https://docs.docker.com/compose/how-tos/startup-order/ "Control startup order | Docker Docs"
[2]: https://hub.docker.com/_/postgres "postgres - Official Image | Docker Hub"
[3]: https://docs.docker.com/reference/cli/docker/compose/up/ "docker compose up | Docker Docs"
[4]: https://docs.docker.com/reference/compose-file/profiles/ "Profiles | Docker Docs"
[5]: https://vitest.dev/guide/projects "Test Projects | Guide | Vitest"
[6]: https://vitest.dev/guide/lifecycle "Test Run Lifecycle | Guide | Vitest"
