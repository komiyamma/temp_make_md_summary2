# 第30章：テンプレ化して完成🎁 新規PJで即コピペ

この章のゴールはこれ👇
**「新規プロジェクトを作ったら、5分で “dev起動 + 保存で自動整形 + テスト/Lint + コミット前チェック + CI” まで動く」**状態を“テンプレ”として固定することです🚀✨

---

## 1) まず最初にやること：テンプレに「する/しない」を決める✅

テンプレ化で一番つらいのは、「毎回変える場所」と「絶対変えたくない場所」が混ざることです😇
なので、次の2つに分けます✂️

## 毎回変える（プロジェクト固有）

* アプリ名（package.json の name）
* ポート番号
* 環境変数（APIキー等）
* READMEの説明文（最初だけ）

## 絶対変えない（テンプレの核）

* `docker compose` 運用（watch含む）
* `npm scripts` のコマンド体系（dev/test/lint/format/check など）
* Lint/Format/テストの設定一式
* `.vscode/` の設定（保存で整形、拡張提案）
* `.gitattributes` / `.editorconfig`（Windows事故対策）
* CI（最低限のチェック）

---

## 2) テンプレの完成形フォルダ🧩

こんな構成にしておくと、コピペ耐性が高いです💪

```text
.
├─ compose.yaml
├─ Dockerfile
├─ package.json
├─ package-lock.json
├─ tsconfig.json
├─ eslint.config.mjs
├─ .prettierrc.json
├─ .prettierignore
├─ .editorconfig
├─ .gitattributes
├─ .gitignore
├─ .env.example
├─ src/
│  └─ index.ts
├─ .vscode/
│  ├─ settings.json
│  └─ extensions.json
└─ .github/
   └─ workflows/
      └─ ci.yml
```

---

## 3) コピペ用 “テンプレ核” セット🧱✨

> ※ ここから先は **そのまま貼れる** 形で置きます✂️📋
> （すでに出来てるなら「差分がある所だけ」採用でOKです👌）

---

## 3.1 compose.yaml 🐳✨（watch 付き）

Docker Compose の watch は、`watch` セクションを書いた上で `docker compose up --watch` で起動します。ログを分けたい場合は `docker compose watch` でもOKです👀📦 ([Docker Documentation][1])

```yaml
name: ts-dx-template

services:
  app:
    build:
      context: .
      target: dev
    working_dir: /workspace
    command: npm run dev:in-container
    ports:
      - "${APP_PORT:-3000}:3000"
    environment:
      NODE_ENV: development
    volumes:
      - .:/workspace:cached
      - node_modules:/workspace/node_modules
    watch:
      # ソースは同期（基本これで速い）
      - action: sync
        path: .
        target: /workspace
        ignore:
          - node_modules/
          - .git/
          - dist/
      # 依存やDockerfile変更時はビルドし直し
      - action: rebuild
        path: package-lock.json
      - action: rebuild
        path: Dockerfile

volumes:
  node_modules:
```

---

## 3.2 Dockerfile 🧱（dev / prod 分離）

```dockerfile
## syntax=docker/dockerfile:1

FROM node:24-slim AS base
WORKDIR /workspace
COPY package.json package-lock.json ./
RUN npm ci

FROM base AS dev
COPY . .
CMD ["npm","run","dev:in-container"]

FROM base AS build
COPY . .
RUN npm run build

FROM node:24-slim AS prod
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /workspace/dist ./dist
COPY --from=base /workspace/node_modules ./node_modules
COPY package.json ./
EXPOSE 3000
CMD ["node","dist/index.js"]
```

---

## 3.3 package.json 🧰（ワンコマンド体系を固定）

* `dev` は **Compose watch起動**に固定（覚えるコマンド1個化）🧠✨
* `check` は「CIで叩く1本」にする（初心者が迷わない）🧪🧹
* Nodeは “LTS系” を基準に（2026時点は v24 が Active LTS、v25 は Current） ([Node.js][2])

```json
{
  "name": "ts-dx-template",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=24 <25"
  },
  "scripts": {
    "dev": "docker compose up --watch",
    "down": "docker compose down",
    "logs": "docker compose logs -f --tail=200",
    "shell": "docker compose exec app bash",

    "dev:in-container": "tsx watch src/index.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js",

    "test": "vitest run",
    "test:watch": "vitest",

    "lint": "eslint .",
    "format": "prettier -w .",
    "check": "npm run lint && npm run test"
  },
  "devDependencies": {
    "eslint": "^9.0.0",
    "prettier": "^3.0.0",
    "tsx": "^4.0.0",
    "typescript": "^5.0.0",
    "vitest": "^2.0.0"
  }
}
```

> TypeScript は 5.9 系のリリースノートが 2026-02-10 時点で更新されています（追従しやすい） ([TypeScript][3])

---

## 3.4 .vscode/settings.json 💾✨（保存で全部済む）

```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "eslint.useFlatConfig": true
}
```

## 3.5 .vscode/extensions.json 🧩（入れると快適）

```json
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode"
  ]
}
```

---

## 3.6 Windows事故を減らすセット🧯

## .editorconfig

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
trim_trailing_whitespace = true
```

## .gitattributes（改行事故の保険💣）

```gitattributes
* text=auto eol=lf
*.bat text eol=crlf
*.ps1 text eol=crlf
```

---

## 3.7 .env.example 🔑（秘密は入れない！）

```dotenv
APP_PORT=3000
```

`.env` は `.gitignore` に入れてね🙅‍♂️

---

## 3.8 GitHub Actions CI 🧪✅（最小で強い）

`actions/setup-node` は Node導入＋依存キャッシュができるので、CIの基本形はこれでOKです([GitHub Docs][4])

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - uses: actions/setup-node@v4
        with:
          node-version: "24"
          cache: "npm"

      - run: npm ci
      - run: npm run check
```

---

## 4) テンプレを “本当に再利用できる形” にする手順🧷

## A. テンプレ専用リポジトリにする🎛️

1. 今のプロジェクトから「固有情報」を削る（名前/README/ポート/環境変数）
2. テンプレ用にコミット
3. GitHub の **Template repository** 機能をON
4. 新規作成時は **Use this template** で一発作成🎉 ([GitHub Docs][5])

---

## 5) ミニ課題🎓✨（15分）

1. テンプレから新規リポジトリを作る
2. `APP_PORT=3001` にして起動（ポート変更できたら勝ち🏆）
3. `src/index.ts` を1行変えて保存 → 自動反映されるのを確認👀
4. `npm run check` が通ることを確認✅
5. pushしてCIが緑になるのを確認🟩

---

## 6) よくある詰まり集🧱😵‍💫

## 6.1 watchが遅い / 反映が重い

* 「ファイル共有が重い」系は、Docker Desktop + WSL2 まわりが効いてることが多いです。Dockerは “より良い体験のために WSL2 ディストリビューションを入れて統合する” 方向を推奨しています([Docker Documentation][6])
* 対処はだいたい「コード置き場」「同期対象の絞り込み」「ignoreの徹底」のどれかで改善します🔥

## 6.2 ログがごちゃごちゃして見づらい

* `docker compose up --watch` は便利だけど、ログが混ざるのが気になるなら `docker compose watch` を分離で使えます([Docker Documentation][1])

## 6.3 コミットフックが重すぎて心が折れる

* ここは第29章の思想そのまま：**コミット前は軽く、CIでしっかり** が長続きです🙂🪝

---

## 7) AI拡張で時短するコツ🤖✨（安全運転）

AIに任せていいのは「ひな形作り」まで！最後は必ずあなたがチェック👀🔍

## 使える依頼例（そのまま投げてOK）📨

* 「このテンプレの `compose.yaml` を、watchのignoreをもっと安全にして」
* 「CIを “PRのときだけ” 実行に変えて」
* 「READMEに Quick Start を3行で足して」

## 受け取り方のコツ✅

* **“全文置き換え” じゃなくて “差分提案”** にさせる（事故減る）
* 出てきた変更は `git diff` で確認して、納得したら採用👍

---

## 8) テンプレの保守ルール📅✨

* Nodeは LTS の表を見て「次のLTS移行」を決める（2026時点：v24 Active LTS / v25 Current）([Node.js][2])
* 月1くらいで `npm outdated` → まとめて更新（細切れにしない）🧹
* テンプレ更新したら「テンプレ自身のCIが通る」までがワンセット✅

---

ここまでできたら、もう **“次の新規PJが怖くない”** です🎉🎉🎉
次は、このテンプレを「用途別に派生（API/React/DB付き）」して、スターターキット化していくと最強になります🔥

[1]: https://docs.docker.com/compose/how-tos/file-watch/ "Use Compose Watch | Docker Docs"
[2]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html "TypeScript: Documentation - TypeScript 5.9"
[4]: https://docs.github.com/ja/actions/tutorials/build-and-test-code/nodejs "Node.js のビルドとテスト - GitHub ドキュメント"
[5]: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-repository-from-a-template "Creating a repository from a template - GitHub Docs"
[6]: https://docs.docker.com/desktop/features/wsl/ "WSL | Docker Docs"
