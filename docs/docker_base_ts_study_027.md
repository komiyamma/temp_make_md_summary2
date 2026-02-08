# 第27章：DBに繋ぐ前の準備（接続文字列の考え方）🧵

この章は「DB接続がうまくいかない😭」の **8割を事前に潰す** 章だよ〜！💪🐣
まだDBには繋がないけど、**接続文字列（Connection String / DB URL）を“迷わず作れる・読める”** ようにするよ！🚀

---

## 1) 接続文字列って結局なに？🤔➡️「DBの住所＋鍵＋オプション」🔑🏠

一言でいうと、**DBに行くためのURL** みたいなもの！🌐✨
（例：PostgreSQLだとこんな形）

* 例（PostgreSQL）
  postgresql://ユーザー:パスワード@ホスト:ポート/DB名?オプション=値

この “形” 自体は、PostgreSQL公式の接続URI仕様に沿ってるよ。([PostgreSQL][1])

---

## 2) まずは分解できるようになろう🔍🧩（ここが超大事！）

たとえばこう👇（見た目はゴチャつくけど、**部品は少ない**）

* スキーム（種類）: postgresql://（または postgres://）([PostgreSQL 日本][2])
* ユーザー名: user
* パスワード: pass
* ホスト: host（どこにあるDB？）
* ポート: 5432（入口番号）
* DB名: mydb
* クエリ（追加オプション）: ?sslmode=require など（必要な時だけ）([Prisma][3])

---

## 3) 初心者が一番ハマるのは「hostは何を書くの？」問題🪤😵‍💫

ここだけ先に結論！📌✨
**“API（あなたのNode/TS）がどこで動くか”** で変わるよ👇

## パターンA：APIがホスト（Windows）で動く 🪟➡️DBはどこ？

* DBが同じPCで動く（例：WindowsにDB）なら host は **localhost** になりがち👍

## パターンB：APIもDBもコンテナ 🐳🐳（次章以降の王道）

* host は **DBコンテナのサービス名（例：db）** になる（Composeで自然にそうなる）🧩✨
  ※「IP直書きしない」が正義🫶（前章の“名前解決”の続きだね！）

## パターンC：APIはコンテナ、DBはホスト（Windows側）🪟🐳

* 開発中なら **host.docker.internal** が便利なことが多いよ👍
  これは Docker Desktop が用意してくれる “特別な名前” で、**開発用途向け**（本番のLinuxサーバ等では基本そのまま使えない）って注意があるよ。([Docker ドキュメント][4])

---

## 4) 接続文字列は「環境変数」に逃がす🎚️🌱（コードに直書きしない！）

理由はシンプル👇

* パスワードをコードに書くと、うっかりGitに入る😱🧨
* 環境ごと（開発/本番）に切り替えが大変😵
* Composeでもクラウドでも、環境変数が基本ムーブ🧩✨

---

## 5) ハンズオン：まずは「接続文字列を環境変数化」して、分解チェックする✅🔍

ここでは **“繋がらない前提で、文字列が正しいか検査”** だけやるよ！😄
（次の章で “疎通がダメな時のチェック” に繋がる！🔗）

## 5-1. .env を作る📝✨

プロジェクト直下に .env を作って、DATABASE_URL を置く（例はPostgreSQL）👇

```bash
## .env（例：APIがホストで動いていて、DBがホストの想定）
DATABASE_URL=postgresql://todo_user:todo_pass@localhost:5432/todo_db
```

> ※ DBをDockerで動かして、APIもDockerになるなら host は localhost じゃなくなるよ（上のパターンB）🧠✨

---

## 5-2. .env.example も作る（超おすすめ）📦💡

```bash
## .env.example（Gitに入れてOKな“雛形”）
DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/DBNAME
```

そして .gitignore に .env を入れておく（もう入ってるならOK）🧹

```txt
.env
```

---

## 5-3. Nodeで「URLとして正しく読めるか」チェックする👀🧪

dotenv を入れる（すでに入ってたらスキップでOK）📦

```bash
npm i dotenv
```

src/dev/printDbUrl.ts を作る👇

```ts
import 'dotenv/config'

function mask(s: string | null | undefined) {
  if (!s) return '(none)'
  return s.length <= 2 ? '**' : s[0] + '*'.repeat(Math.max(1, s.length - 2)) + s[s.length - 1]
}

const raw = process.env.DATABASE_URL
if (!raw) {
  console.error('❌ DATABASE_URL が未設定だよ！ .env を確認してね')
  process.exit(1)
}

let u: URL
try {
  u = new URL(raw)
} catch (e) {
  console.error('❌ DATABASE_URL が URL として壊れてるかも！')
  console.error('   ありがち：パスワードに @ / : などが入っててURLが崩れる')
  console.error('   → URLエンコード（%xx）を検討してね')
  throw e
}

const dbName = u.pathname.replace(/^\//, '') || '(empty)'

console.log('✅ DATABASE_URL 解析結果')
console.log('  scheme   :', u.protocol)
console.log('  user     :', mask(u.username))
console.log('  password :', mask(u.password))
console.log('  host     :', u.hostname)
console.log('  port     :', u.port || '(default)')
console.log('  dbname   :', dbName)
console.log('  params   :', u.search || '(none)')

// 最低限チェック
const missing = []
if (!u.hostname) missing.push('host')
if (!dbName) missing.push('dbname')
if (missing.length) {
  console.log('⚠️ 足りない項目があるかも:', missing.join(', '))
}
```

package.json にスクリプトを足す👇

```json
{
  "scripts": {
    "dev:dburl": "node --loader ts-node/esm src/dev/printDbUrl.ts"
  }
}
```

> ts-node の構成は人によって違うので、もしここが合わなければ「今のプロジェクトのTS実行方法」に合わせてOKだよ😊
> 目的は “DATABASE_URL を new URL() で解析できる” を確認すること！🎯

実行👇

```bash
npm run dev:dburl
```

---

## 6) よくある落とし穴ランキング🏆🪤（ここだけで事故が減る！）

## ① パスワードに記号が入ってURLが壊れる🔐💥

URLには “予約文字” があるから、混ざると壊れることがあるよ😵
必要なら **%エンコード**（URLエンコード）する！
MySQLの公式ドキュメントでも、URL中の予約文字はパーセントエンコードが必要って注意があるよ。([MySQL][5])

さらに嫌な話だけど、壊れたURLをそのまま例外ログに出すと **認証情報がログに出ちゃう** 可能性もあるので、例外処理は丁寧にね😱🧯([GitHub][6])

## ② “localhost” の意味が変わる（ホスト vs コンテナ）🔁😵

* ホストで動くアプリの localhost：ホスト自身
* コンテナで動くアプリの localhost：コンテナ自身（別物！）

## ③ APIとDBが両方コンテナなのに host=localhost にしてる🐳❌

こういう時はだいたい host は **db** みたいなサービス名になる（次の章でガッツリやる！）🧩✨

## ④ Docker Desktop の host.docker.internal を本番でも使えると思う🚨

開発では便利だけど、Docker Desktop外（本番サーバ等）では前提が変わりやすいよ⚠️
“開発用途向け” って明記があるので、用途を分けようね😊([Docker ドキュメント][4])

## ⑤ Composeの環境変数が「どれが勝つか」混乱する🎚️😵

同じ変数が複数箇所にあると、優先順位があるよ（公式が順番を説明してる）📚([Docker Documentation][7])
さらに env_file は optional にできる（最近のComposeの改善点）ってのも覚えておくと便利！([Docker Documentation][8])

---

## 7) Todo APIに向けた“小さな設計”🧱🌱（超かんたん版）

接続文字列は、アプリ内で **1か所だけ** から読むのがおすすめ！📌✨

* src/config/db.ts（みたいな場所）で

  * DATABASE_URL を読む
  * 無ければわかりやすく落とす
  * ログに “生パスワード” を出さない

これだけで、将来Composeやクラウドに行ってもラクになるよ😆🚀

---

## 8) AI活用（コピペでOK）🤖✨

## 接続文字列テンプレを作らせる📝

* 「PostgreSQLのDATABASE_URLのテンプレを作って。user/pass/host/port/dbname をプレースホルダにして、例も2つ（localhost用、dbサービス名用）つけて」

## 今あるDATABASE_URLを“分解して説明”させる🔍

* 「このDATABASE_URLを、scheme/user/password/host/port/dbname/params に分解して、間違いがありそうなら指摘して：（ここに貼る）」

## 記号入りパスワード対策を聞く🔐

* 「DATABASE_URLのパスワードに @ や : が入るとき、どこをURLエンコードすべき？例も出して」

---

## 9) ミニクイズ（3問）🎓✨

1. **APIがコンテナ、DBもコンテナ** のとき、host は何になりがち？🤔
   → **サービス名（例：db）** 🧩

2. host.docker.internal はいつでも使える？🤔
   → **Docker Desktopの開発用途で便利**。本番では前提が変わることが多い⚠️([Docker ドキュメント][4])

3. DATABASE_URL が壊れやすい原因トップは？🤔
   → **パスワードの記号でURLが崩れる**（必要なら%エンコード）🔐💥([MySQL][5])

---

## 次の章へのつながり🔗😄

この章で「接続文字列の部品」がわかったから、次は **“繋がらない時にどこから疑う？”** を固定化していくよ！🔍✅（第28章へGO〜！🚀）

[1]: https://www.postgresql.org/docs/current/libpq-connect.html?utm_source=chatgpt.com "18: 32.1. Database Connection Control Functions"
[2]: https://www.postgresql.jp/docs/9.5/libpq-connect.html?utm_source=chatgpt.com "31.1. データベース接続制御関数"
[3]: https://www.prisma.io/docs/orm/overview/databases/postgresql?utm_source=chatgpt.com "PostgreSQL database connector | Prisma Documentation"
[4]: https://docs.docker.jp/desktop/networking.html?utm_source=chatgpt.com "ネットワーク機能を見渡す — Docker-docs-ja 24.0 ドキュメント"
[5]: https://dev.mysql.com/doc/connector-j/en/connector-j-reference-jdbc-url-format.html?utm_source=chatgpt.com "6.2 Connection URL Syntax"
[6]: https://github.com/brianc/node-postgres/issues/3145?utm_source=chatgpt.com "Invalid connection strings can cause credentials to leak to ..."
[7]: https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/?utm_source=chatgpt.com "Environment variables precedence"
[8]: https://docs.docker.com/compose/how-tos/environment-variables/set-environment-variables/?utm_source=chatgpt.com "Set environment variables"
