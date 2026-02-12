# 第09章：依存固定：lockfileを信じる世界 🧷

この章はひとことで言うと、**「本番ビルドが“昨日と同じ結果”になるように固定する」**回だよ😊
ローカルで動いたのに、本番ビルドで突然コケる…😇 その事故の多くは **依存関係（npmパッケージ）**が原因になりがち。そこで登場するのが **lockfile（ロックファイル）**！🔒✨

---

## この章のゴール 🎯✨

* ✅ lockfileが何で、なぜ本番で超大事か分かる
* ✅ CI / Docker build で「依存が勝手に変わらない」状態を作れる
* ✅ Dockerfileで **依存インストールがキャッシュに乗る順序**を組める ⚡
* ✅ `npm ci` / `pnpm install --frozen-lockfile` / `yarn install --immutable` を使い分けできる 🧠

---

## 1) lockfileって何？（超ざっくり）🧠🔒

`package.json` は「だいたいこのへんのバージョン使ってね（例: ^1.2.3）」みたいな **希望** を書く場所📄
一方 lockfile は「実際に入れたのはこれ！このバージョン！これ！」っていう **確定結果のメモ**🧾✨

* npm → `package-lock.json`（または `npm-shrinkwrap.json`）📌 ([npm ドキュメント][1])
* pnpm → `pnpm-lock.yaml` 📌 ([pnpm][2])
* Yarn → `yarn.lock` 📌 ([Yarn][3])

つまり lockfile をコミットしておくと、**別のPC / CI / 本番でも “同じ依存” を再現**しやすくなる💪✨
これが「そのままデプロイ」では生命線になるよ🫀🔥

---

## 2) 本番で死にがちな “依存事故” あるある ☠️💥

## あるある①：昨日は通ったのに、今日は落ちた 😭

`package.json` が `^` で範囲指定してると、**依存が勝手に新しい版にズレる**ことがある👉 で、急に壊れる🫠

## あるある②：ローカルはOK、CIだけNG 🤖❌

ローカルの `node_modules` が残ってて動いてるだけ、みたいなパターン😇
CIは毎回クリーンだから、依存のズレが即バレる。

## あるある③：Docker build が遅すぎる 🐢📦

依存インストールが毎回やり直しになる構造だと、ビルドが地獄👹
ここも lockfile と Dockerfile の順番で解決できる！

---

## 3) “固定インストール”の正解コマンド ✅🧷

## npm の場合：`npm ci` が本番・CIの基本 👑

`npm ci` は **lockfileどおりにクリーンインストール**する専用コマンド。
ポイントはこれ👇

* lockfile（`package-lock.json`等）が必須
* `package.json` と lockfile がズレてたら **エラーで止まる**（勝手に直さない）
* `node_modules` があったら **消してから入れ直す**
* lockfileや `package.json` を **絶対に書き換えない**（凍結）🧊 ([npm ドキュメント][4])

つまり CI で `npm ci` を回すと、**「ズレたら即死」＝事故が早期発見**できる😆👍 ([npm ドキュメント][4])

---

## pnpm の場合：CIだと “lockfile更新が必要なら失敗” が基本挙動 💥

pnpm はCI環境だと、lockfileが古いとインストールが失敗する（＝ズレを許さない）方向になってるよ📌 ([pnpm][2])
さらに明示するなら：

* ✅ `pnpm install --frozen-lockfile`（ズレたらエラー）🧊 ([pnpm][5])

---

## Yarn の場合：`--immutable` が “lockfile絶対変更しない” の合図 🧊

* ✅ `yarn install --immutable`（lockfile変更が必要ならエラー） ([Yarn][3])

---

## 4) “使うパッケージマネージャを固定”する（Corepack）🧰✨

チームやCIで地味に起きるのがこれ👇
「Aさんはpnpm、Bさんはnpm、CIはYarn」みたいなカオス🤯

そこで **Corepack**。Nodeに同梱される仕組みで、プロジェクト指定のYarn/pnpmを呼び出せる感じになるよ🪄 ([Node.js][6])

よくある固定方法👇（例）

```json
{
  "packageManager": "pnpm@9.0.0"
}
```

これで「このプロジェクトはpnpmのこのバージョンね」って意思表示になる✍️
Corepack自体の有効化はこういうノリ👇（1回やるやつ）

```bash
corepack enable
```

（Corepackは `corepack enable` で有効化する流れが公式に説明されてるよ）([Node.js][6])

---

## 5) Dockerfileで “依存キャッシュが効く順番” を作る ⚡🐳

ここ超重要！！🎉
Docker buildが速くなるかどうかは、だいたいこの順番で決まる👇

## ✅ 鉄板ルール：まず `package.json` と lockfile だけCOPYする 📦➡️

そして依存インストールを先にやる。
こうすると、**アプリのソースを少し変えただけなら依存レイヤーが再利用される**✨

## npm 例（ビルド用ステージ）

```dockerfile
## 依存だけ先に入れてキャッシュを効かせる
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build
```

この「COPYの順番」が命😇
`COPY . .` を先にやると、1行でもコードが変わるたびに依存が全部やり直しになりがち💥

---

## 6) さらに速くする：BuildKitのキャッシュマウント 🏎️💨

DockerのBuildKitには **“キャッシュ置き場をマウントして再利用する”**仕組みがあるよ📦✨
これを使うと、レイヤーキャッシュが崩れても「落としてきたパッケージ」が再利用されて速い⚡ ([Docker Documentation][7])

## npmの例（npmキャッシュを使い回す）

```dockerfile
## syntax=docker/dockerfile:1
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
```

Docker公式が “cache mounts” の説明と例を出してるよ📌 ([Docker Documentation][7])

---

## 7) pnpm × Dockerの“速いやつ” 🧠⚡

pnpmはDocker向けに、わりと露骨に最適化ルートが用意されてる✌️

* `pnpm fetch` は **lockfileだけで依存を先に集める**のに向いてる（Dockerレイヤーキャッシュと相性◎）([pnpm][8])
* その後 `--offline` でインストールしてネットに行かない構成にできる ([pnpm][9])

ざっくりイメージ👇

```dockerfile
WORKDIR /app
COPY pnpm-lock.yaml package.json ./
RUN corepack enable
RUN pnpm fetch
COPY . .
RUN pnpm install --offline
```

（pnpm公式がDockerでの考え方として `pnpm fetch` を推してるよ）([pnpm][8])

---

## 8) ハンズオン：依存固定の “事故らない流れ” を体に入れる 💪🧪

## Step 1：lockfileを必ずコミットする ✅

* npmなら `package-lock.json`
* pnpmなら `pnpm-lock.yaml`
* Yarnなら `yarn.lock`

## Step 2：CI / 本番用コマンドを “固定インストール” にする 🧊

* npm：`npm ci` ([npm ドキュメント][4])
* pnpm：`pnpm install --frozen-lockfile` ([pnpm][5])
* Yarn：`yarn install --immutable` ([Yarn][3])

## Step 3：Dockerfileを “依存が先にキャッシュされる順番” にする 🐳⚡

* lockfile + package.json を先にCOPY
* install
* その後にソースCOPY

---

## 9) つまずきTop5 😵‍💫🧯（最短で直す）

## ① `npm ci` が「lockfileとpackage.jsonが一致しない」って怒る

👉 それが正常！😆（ズレ検知）
直し方：**ローカルで `npm install` して lockfile を更新→コミット**。
（`npm ci` はズレてもlockfileを更新しない仕様）([npm ドキュメント][4])

## ② `npm ci` で peer deps 関連の設定が違ってコケる

👉 lockfile作成時に使った設定（例：`--legacy-peer-deps`）と同じ設定が必要なことがある。`.npmrc` をプロジェクトに置いてコミット、みたいな話が公式にもあるよ📌 ([npm ドキュメント][4])

## ③ Docker build が毎回遅い

👉 DockerfileのCOPY順が原因率高め。**依存ファイル先コピー**に直す！

## ④ pnpmでCIだけ失敗する

👉 CIだとlockfileが古いと失敗する方向なので、**lockfile更新漏れ**を疑う([pnpm][2])

## ⑤ Yarnで `--frozen-lockfile` 使って警告が出る

👉 近年は `--immutable` が推奨になりがち（Yarn公式のinstallに載ってる）([Yarn][3])

---

## 10) 章末チェックリスト ✅📌

* [ ] lockfileをコミットしてる🧷
* [ ] CI/本番は “固定インストール” コマンドにしてる🧊
* [ ] Dockerfileは「依存ファイル→install→ソース」の順になってる🐳
* [ ] さらに速くしたいなら BuildKit の cache mount を検討できる⚡ ([Docker Documentation][7])
* [ ] pnpmなら `pnpm fetch` を選択肢に入れられる📦 ([pnpm][8])

---

## 11) AIに投げるコピペ用プロンプト集 🤖📎

* 「このリポジトリの package manager（npm/pnpm/yarn）を判定して、CI向けの“lockfile固定インストール”コマンドを1つだけ提案して」
* 「Dockerfileで依存キャッシュが最大限効くCOPY順に並べ替えて。npm/pnpm/yarnのどれでも破綻しない形で」
* 「`npm ci` が失敗した。package.jsonとlockfileのズレを直す手順を“安全第一”で説明して（余計な自動更新を避けたい）」
* 「pnpm fetch を使う場合のDockerfileを、最小ステップで書いて」

---

次の第10章（`.dockerignore：速さと安全の地味王 👑🧹`）に行く前に、ここで一回だけ言わせて😆
**lockfileは“本番のタイムマシン”**だよ🕰️✨
これがあると「昨日動いた状態」を何回でも召喚できる。強い💪🔥

[1]: https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json?utm_source=chatgpt.com "package-lock.json"
[2]: https://pnpm.io/9.x/cli/install?utm_source=chatgpt.com "pnpm install"
[3]: https://yarnpkg.com/cli/install?utm_source=chatgpt.com "yarn install"
[4]: https://docs.npmjs.com/cli/v11/commands/npm-ci/ "npm-ci | npm Docs"
[5]: https://pnpm.io/cli/install?utm_source=chatgpt.com "pnpm install"
[6]: https://nodejs.org/download/release/v22.11.0/docs/api/corepack.html?utm_source=chatgpt.com "Corepack | Node.js v22.11.0 Documentation"
[7]: https://docs.docker.com/build/cache/optimize/?utm_source=chatgpt.com "Optimize cache usage in builds"
[8]: https://pnpm.io/docker?utm_source=chatgpt.com "Working with Docker"
[9]: https://pnpm.io/cli/fetch?utm_source=chatgpt.com "pnpm fetch"
