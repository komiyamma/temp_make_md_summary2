# 第02章：DXの土台「開発用」と「本番用」を分けて考える🧠✨

この章はね、**「開発が遅い・不安・怖い」を一気に減らす土台づくり**だよ💪😆
結論からいくね👇

---

## 1) いきなり結論：開発と本番は“目的”が違う🎯

* **開発（Dev）**：とにかく速く回す🏃‍♂️💨
  変更→反映→確認（できれば即）を最優先✨
* **本番（Prod）**：軽く・安全に・壊れにくく🛡️📦
  “余計なもの”を持ち込まないのが正義😇

だから、**同じDockerでも設計が変わる**んだよね😉

（2026/02/10時点の目安：Nodeはv24がActive LTS、v25がCurrentとして更新されてるよ📌）([Node.js][1])

---

## 2) 分けないと何が起きる？あるある事故💥😵

## 事故①：本番が重い＆遅い🐢

開発用の道具（テスト/Lint/型チェック/ビルドツール）を本番に全部入れると、イメージが巨大化しがち😇
**“動かすだけ”の本番に、工作機械ごと持っていく**イメージ🧰➡️🏭

→ Dockerは**multi-stage build**で“必要な成果物だけ”を最終イメージに入れるのが王道だよ✨([Docker Documentation][2])

## 事故②：本番に開発ツールが残ってセキュリティ面が不利🕳️

本番に不要な依存が増えるほど、攻撃面（攻撃されうる範囲）が増える…って考え方だね🛡️
Nodeのコンテナ運用でも「本番は最小」「rootで動かさない」みたいな基本が推奨されてるよ🔒([cheatsheetseries.owasp.org][3])

## 事故③：本番の動きが“開発と違う”😱

開発では「ソースをマウントして動かす」けど、本番は「ビルド成果物だけで動かす」ことが多い。
ここが混ざると、**“本番だけで落ちる”**が起きやすい😵‍💫

---

## 3) どう分ける？初心者が迷わない“3点セット”🧩✨

ここだけ覚えればOK👍😆

## ✅ A. npm scriptsで入口を固定する🪄

* 開発用：`dev`
* 本番用：`start`
* ビルド：`build`

「何を叩けばいいか」を固定すると、迷いが消える🫠✨

## ✅ B. Dockerfileは“開発用ステージ”と“本番用ステージ”に分ける🏗️

multi-stage buildで

* dev：便利ツール入り（開発の速さ）
* prod：成果物だけ（軽さと安全）

が作れるよ🧠✨([Docker Documentation][2])

## ✅ C. Composeは「共通（base）」＋「開発だけ上書き（override）」にする🎛️

Docker Composeはデフォルトで **compose.yaml + compose.override.yaml** を読み込んでマージするよ📌([Docker Documentation][4])
なので、

* compose.yaml：みんなで共有してOKな“共通”
* compose.override.yaml：開発だけの上書き（ローカル都合も入れやすい）

が自然にできる👍✨

---

## 4) ハンズオン：最小構成で“分離”を体で覚える🧪🎉

ここからは、**「分けるとこうなる」**を一発で体感するセットだよ😆✨
（そのままコピペでOK👌）

---

## 4-1) まずはファイル構成📁

* src/index.ts
* package.json
* tsconfig.json
* Dockerfile
* compose.yaml
* compose.override.yaml
* .dockerignore

---

## 4-2) package.json（入口を固定🧷）

```json
{
  "name": "dx-sample",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "express": "^4.19.0"
  },
  "devDependencies": {
    "tsx": "^4.0.0",
    "typescript": "^5.9.0",
    "@types/express": "^4.17.0"
  }
}
```

ポイント👉

* devは“開発用ランナー”で速く回す🏃‍♂️💨
* startは“成果物”だけで動かす📦✨

（TypeScript 5.9のリリースノートも公開されてるよ📌）([TypeScript][5])

---

## 4-3) tsconfig.json（最小）

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "sourceMap": true
  }
}
```

---

## 4-4) src/index.ts（超ミニ）

```ts
import express from "express";

const app = express();

app.get("/", (_req, res) => {
  res.send("Hello DX! 🚀");
});

app.listen(3000, () => {
  console.log("Listening on http://localhost:3000 🥳");
});
```

---

## 4-5) Dockerfile（dev/prodをステージで分ける🏗️）

```dockerfile
## syntax=docker/dockerfile:1

FROM node:24-bookworm-slim AS base
WORKDIR /app

## 依存を入れる（ビルド用・開発用で使う）
FROM base AS deps
COPY package*.json ./
RUN npm ci

## 開発用（便利なもの入り）
FROM deps AS dev
ENV NODE_ENV=development
COPY . .
CMD ["npm", "run", "dev"]

## ビルド用（tscでdistを作る）
FROM deps AS build
COPY . .
RUN npm run build

## 本番用（成果物だけ＆依存も最小）
FROM base AS prod
ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=build /app/dist ./dist

USER node
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

ここが“分ける”の核心💡

* multi-stage buildで、最終（prod）に余計なものを持ち込まない✨([Docker Documentation][2])
* `--omit=dev` で **devDependenciesを物理的に入れない**（本番の軽量化）📦✨([docs.npmjs.com][6])
* rootで動かさない（`USER node`）🔒（セキュリティ基本）([cheatsheetseries.owasp.org][3])

---

## 4-6) compose.yaml（共通＝本番寄りの“型”📦）

```yaml
services:
  app:
    build:
      context: .
      target: prod
    ports:
      - "3000:3000"
```

---

## 4-7) compose.override.yaml（開発だけ上書き⚡）

```yaml
services:
  app:
    build:
      target: dev
    environment:
      NODE_ENV: development
    volumes:
      - .:/app
      - /app/node_modules
    ports:
      - "3000:3000"
```

ポイント👉

* デフォルトで compose.yaml と compose.override.yaml がマージされるよ🧩([Docker Documentation][4])
* `- /app/node_modules` を入れると、マウントで node_modules が潰れにくくなる（地味に効く）😇✨

---

## 4-8) .dockerignore（ビルドを軽くする🧹）

```gitignore
node_modules
dist
.git
.DS_Store
```

---

## 5) 起動して“分離”を確認しよう🎮✨

## ✅ 開発として起動（override込み）

```bash
docker compose up --build
```

## ✅ 本番っぽく起動（override無し）

```bash
docker compose -f compose.yaml up --build
```

## ✅ “合体結果”を見て理解を固める👀

```bash
docker compose config
```

「今、どんな設定で動いてるの？」が見えるから超おすすめ😆🧠

---

## 6) この章のチェックリスト✅😊

* 「開発は速さ」「本番は軽さ＆安全」って言える🎯
* npm scripts が dev / build / start で分かれてる🧩
* Dockerfile が dev/prod で分かれてる🏗️
* Compose が base + override で分かれてる🎛️
* `docker compose -f compose.yaml up` で“本番っぽく”動かせる📦

ここまでできたら、DXの土台は完成だよ🎉🎉🎉

---

## 7) よくある詰まり💣（先回り）

* 「本番でもホットリロードが走ってる」😇
  → prodステージの CMD は start（dist実行）だけにする
* 「本番でTypeScriptが必要になってる」😵
  → 本番は “distだけ” を動かす設計にする（tscはbuildステージ）([Docker Documentation][2])
* 「compose.override.yaml のせいで本番が汚れる」🌀
  → 本番起動は `-f compose.yaml` を使う（意図して外す）([Docker Documentation][4])

---

## 8) AI時短コーナー🤖✨（安全に使うコツ付き）

**使い方は簡単：AIに“案を出させて”、自分は差分だけ確認🔍**
（丸投げ禁止ね😆）

* 「このDockerfileで本番に不要なものが残ってないかレビューして。特にdevDependenciesやroot実行を重点的に。」
* 「compose.override.yamlで開発体験を上げたい。ホットリロード/デバッグを追加するとしたら、最小の差分だけ提案して。」
* 「npm scriptsの命名を dev/build/start に揃えたい。既存のscriptsを崩さずに移行案を出して。」

---

次の第3章で、ここで作った“分離の型”をベースに、**詰まりやすいポイント（ファイル同期・パス・改行・権限）を先回り**して、さらに快適にしていくよ💣➡️😆✨
（この章の構成のまま続けていけるようにしてある！）

[1]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[2]: https://docs.docker.com/build/building/multi-stage/?utm_source=chatgpt.com "Multi-stage builds"
[3]: https://cheatsheetseries.owasp.org/cheatsheets/NodeJS_Docker_Cheat_Sheet.html?utm_source=chatgpt.com "NodeJS Docker - OWASP Cheat Sheet Series"
[4]: https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/?utm_source=chatgpt.com "Merge Compose files"
[5]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html "TypeScript: Documentation - TypeScript 5.9"
[6]: https://docs.npmjs.com/cli/v8/commands/npm-install?utm_source=chatgpt.com "npm-install"
