# 第30章：テンプレ化して“毎回コピペで勝つ”📦🏁🎉

ここまでで「ランタイム固定」の材料（Dockerfile / lockfile / Compose / Dev Containers）が揃ったので、最後は **“毎回ゼロから悩まない”** ために、**雛形（テンプレ）を完成**させます😆✨
この章のゴールはシンプル👇

* 新規PJで「フォルダ丸ごとコピー」→ 即 `docker compose up` で動く🐳💨
* Node/TS/依存が固定されて、PC差分で事故らない🔒
* “未来の自分”が見ても迷子にならない構造📁🧭

ちなみに今の前提として、Nodeは **v24がActive LTS / v25がCurrent / v22がMaintenance** という状態です。([nodejs.org][1])
TypeScriptは npm 上の “Latest” が **5.9.3** 表示になっています。([npm][2])

---

## 30章テンプレの「設計ルール」📐🧠

テンプレは盛りすぎると死にます💀（改造が怖くなる）
なのでルールはこれだけ👇

1. **固定するものは固定**（NodeはDockerで固定、依存はlockfileで固定）🔒
2. **変えるものは1〜2箇所**（アプリ名、ポート、起動コマンドくらい）🛠️
3. **同じ情報を二重管理しない**（Dev ContainerはComposeを使って使い回す）♻️
4. **“安定する設定”を選ぶ**（TSのmodule周りは“揺れにくい選択肢”へ）🧯

TS 5.9 では `--module node20` / `--moduleResolution node20` みたいに、挙動が揺れにくい “安定オプション” が用意されています（`nodenext` より将来変わりにくい意図）。([typescriptlang.org][3])
テンプレ化にめちゃ向いてます💪✨

---

## 完成形：フォルダ構成（これを丸ごとコピペ）📁✨

```text
my-node-ts-template/
  Dockerfile
  compose.yml
  .dockerignore
  package.json
  package-lock.json   ← npm installで生成してコミットする
  tsconfig.json
  src/
    index.ts
  .devcontainer/
    devcontainer.json  ← 任意（VS Codeごと固定したい人向け）
```

Composeファイルは **Compose Specification が推奨**、最近は `compose.yml` でOKです。([Docker Documentation][4])

---

## テンプレ本体（コピペOK）🧩📦

### 1) Dockerfile（固定の核）🧱🟢

ポイントは👇

* ベースは **Active LTS系**（例：`node:24-...`）([nodejs.org][1])
* `npm ci` 前提（lockfileで再現性）
* Dev と Prod を “同じDockerfileの別ステージ”で切り替え（テンプレに強い）✨

```dockerfile
## syntax=docker/dockerfile:1

## 1) ベース（Nodeを固定）
FROM node:24-bookworm-slim AS base
WORKDIR /app

## 2) 依存インストール専用ステージ（キャッシュ効かせる）
FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci

## 3) 開発用（devDependencies込み）
FROM deps AS dev
COPY . .
CMD ["npm", "run", "dev"]

## 4) ビルド用（TSをdistへ）
FROM deps AS build
COPY . .
RUN npm run build

## 5) 本番用（devDependenciesを抜いて小さく）
FROM base AS prod
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
CMD ["node", "--enable-source-maps", "dist/index.js"]
```

---

### 2) compose.yml（開発ループ最強化）🐳🌀

* ソースはマウントで即反映⚡
* `node_modules` は **volume**（ホストと混ぜない💣回避）
* Dockerfileは dev ステージを使う

```yaml
services:
  app:
    build:
      context: .
      target: dev
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - node_modules:/app/node_modules
    environment:
      # Windows + Dockerでwatchが効きにくいとき用（効くなら消してOK）
      - CHOKIDAR_USEPOLLING=true
    command: npm run dev

volumes:
  node_modules:
```

---

### 3) .dockerignore（地味に超重要）🧹🚀

```text
node_modules
dist
.git
.vscode
.DS_Store
npm-debug.log
Dockerfile
compose*.yml
```

---

### 4) package.json（迷子にならない scripts 設計）📦🧭

* `dev/build/start/typecheck` を揃える（これだけで勝てる🥳）
* TS 5.9 系を使う（lockfileで固定される）([npm][2])
* ESMはテンプレだと便利なので `"type": "module"` を採用（※第24章で学んだ“最低ライン”がここで効く🔥）

```json
{
  "name": "my-node-ts-template",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node --enable-source-maps dist/index.js",
    "typecheck": "tsc -p tsconfig.json --noEmit"
  },
  "dependencies": {},
  "devDependencies": {
    "tsx": "^4.20.0",
    "typescript": "^5.9.3"
  }
}
```

> ✅ ここで `npm install` を一回実行して `package-lock.json` を作り、**必ずコミット**してください📌
> これで `npm ci` が “ズレたら止める” ＝ 再現性の守護神になります🛡️

---

### 5) tsconfig.json（“揺れにくい”設定に寄せる）🧊🧯

TS 5.9 の意図に乗って、module系を **`node20` で固定**しておくとテンプレ向きです。([typescriptlang.org][3])

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "node20",
    "moduleResolution": "node20",

    "rootDir": "src",
    "outDir": "dist",

    "strict": true,
    "skipLibCheck": true,

    "sourceMap": true
  },
  "include": ["src"]
}
```

---

### 6) src/index.ts（最小の動作確認）✅✨

```ts
import http from "node:http";

const port = 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end("Hello from fixed runtime! 🎉🐳\n");
});

server.listen(port, () => {
  console.log(`listening on http://localhost:${port} 🚀`);
});
```

---

### 7) （任意）.devcontainer/devcontainer.json（VS Codeごと固定）🧰🐳

「VS Codeの中身ごとプロジェクトに紐づけたい」人はこれを追加すると最強です🔥
Dev Containers は、フォルダを“コンテナとして開く”開発を支える仕組みです。([Visual Studio Code][5])

```json
{
  "name": "node-ts-template",
  "dockerComposeFile": ["../compose.yml"],
  "service": "app",
  "workspaceFolder": "/app",
  "shutdownAction": "stopCompose",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-azuretools.vscode-docker",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode"
      ]
    }
  }
}
```

---

## 使い方（新規PJで毎回これ）🚀🪄

1. テンプレフォルダをコピーして名前変更📁✂️
2. そのフォルダで（WindowsのターミナルでOK）👇

   * `docker compose build` 🐳
   * `docker compose up` 🌀
3. ブラウザで `http://localhost:3000` を開く🌐✨

終わり！🥳（これが“勝ちテンプレ”です）

---

## よくある詰まりポイント（最終章なので潰す🧯）💥

### 🌀 watch が反応しない

Windows + Docker だとファイル更新通知が届きにくい時があります。
その場合は compose.yml の `CHOKIDAR_USEPOLLING=true` が効くことが多いです✅（効くならそのままでOK）

### 💣 node_modules が変になる

ホストとコンテナで `node_modules` を共有すると壊れがちです。
このテンプレは **volumeに逃がしている**ので、基本は安全ルート👍

### 🧩 ESM/CJSで混乱した

このテンプレは `"type":"module"` の ESM 寄りです。
もしCJSに寄せたいなら、まず `"type":"module"` を消して、tsconfigのmodule設定も合わせて調整（第24章の知識がここで活きる🔥）

---

## AIに投げる“勝ちプロンプト”例 🤖✨

* 「このテンプレに **Express（またはFastify）** を追加して、`/health` を生やして。Docker/Compose/DevContainerの構造は維持してね🙏」
* 「`npm run dev/build/start/typecheck` は崩さず、**ログとエラーハンドリングだけ整えて**」
* 「Nodeは **Active LTS系（v24）**、TSは **5.9系**、依存は lockfile 固定、`npm ci` 前提で」([nodejs.org][1])

---

## この章を終えると手に入るもの🎁✨

* ✅ 新規PJが“雛形コピペ”で秒速スタート🏎️💨
* ✅ Node/TS/依存が固定され、PC差分事故が激減🔒
* ✅ Composeで開発ループが回り続ける🌀
* ✅ （任意）VS Codeごと環境固定まで到達🧰🐳([Visual Studio Code][5])

---

次の一歩（おすすめ）😆🔥
このテンプレを **GitHubのTemplate Repository** にして、ボタン1発で新規PJ生成できるようにすると、さらに“勝ち”が加速します🏁✨
（「Expressがいい」「Fastifyがいい」「Next.js寄りがいい」みたいな方向性があれば、その派生テンプレも同じ思想で作れますよ🫶）

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[4]: https://docs.docker.com/reference/compose-file/?utm_source=chatgpt.com "Compose file reference"
[5]: https://code.visualstudio.com/docs/devcontainers/containers?utm_source=chatgpt.com "Developing inside a Container"
