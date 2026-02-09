# 第20章：TS開発は2択（王道）🛣️🧭

この章は「TypeScript で開発ループ（保存→即反映）」を作るときの **王道2ルート**を、迷わず選べるようにする回です😆✨
（Node は v24 が Active LTS / v25 が Current / v22 が Maintenance LTS という並びです🟢）([Node.js][1])
（TypeScript は 5.9 系が安定ラインで配布されています）([typescriptlang.org][2])

---

#### 🎯 この章のゴール

* 「TS開発って結局どう回すの？」が **2パターンに整理**できる🧠✨
* Docker/Compose 上で、どっちでも **保存→自動再実行**にできる🔁🐳
* 「なぜそうなるのか」も、ザックリ腑に落ちる🤝😊

---

## ✅ 結論：TS開発はこの2択！

### ルートA：`tsc -w` で `dist/` を作って Nodeで実行 🧱➡️🏃

* TS → JS に **ちゃんとビルド**してから動かす
* 開発中は `tsc -w`（watch）で **自動ビルド**
* 実行側は `node --watch dist/...` で **自動再起動**
* 「本番に近い形」で安心感が強い💪

TypeScript 側の watch（`--watch`）は公式機能です([typescriptlang.org][3])
Node 側にも `--watch` があり、変更で再起動できます👀([Node.js][4])

---

### ルートB：`tsx` などで TS を直接実行 🏃‍♂️💨

* TS を **そのまま実行**して最速ループ
* さらに `tsx watch ...` で **保存→即再実行**
* 初心者が詰まりがちな ESM/CJS 周りも “だいぶ丸く” しやすい😇

`tsx` は「node の代わりに使う」感覚で OK、watch モードも用意されています([tsx][5])
ただし **tsx 自体は型チェックしない**（＝別で型チェック工程を置くのが推奨）というのが大事ポイントです🧷([tsx][6])

---

## 🧭 どっちを選ぶ？超ざっくり診断（迷ったらコレ！）

* **とにかく早く動かして学習を進めたい** → ルートB（tsx）🏎️💨
* **本番に近い流れ（ビルド→実行）を最初から体に入れたい** → ルートA（tsc -w）🧱
* **チームで「dist を成果物」として扱う予定** → ルートA が相性◎👥
* **小さめAPI・スクリプト・検証が多い** → ルートB が超ラク😆

---

## 📦 共通：最小サンプル（この章の動作確認用）🧪✨

フォルダ構成（例）📁

```text
myapp/
  src/
    index.ts
  package.json
  tsconfig.json
  Dockerfile
  compose.yml
```

`src/index.ts`（超ミニ HTTP サーバ）🌐

```ts
import http from "node:http";

const server = http.createServer((req, res) => {
  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end("Hello TS! 👋\n");
});

server.listen(3000, () => {
  console.log("listening on http://localhost:3000 🚀");
});
```

---

## ルートA：`tsc -w` → `dist/` → `node --watch` 🧱🔁

## 1) `tsconfig.json`（まずは素直に dist 出力）🧊✨

```jsonc
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "rootDir": "src",
    "outDir": "dist",

    "strict": true,
    "esModuleInterop": true,
    "sourceMap": true
  },
  "include": ["src/**/*"]
}
```

## 2) `package.json` scripts（2ターミナルが一番わかりやすい）🧑‍💻🧑‍💻

```jsonc
{
  "scripts": {
    "dev:build": "tsc -w",
    "dev:run": "node --watch dist/index.js",
    "build": "tsc",
    "start": "node dist/index.js"
  }
}
```

* ターミナル①：`npm run dev:build`（TS を監視して dist 生成）🔁
* ターミナル②：`npm run dev:run`（dist の変更で再起動）👀🔁([Node.js][4])

> 💡 Node の `--watch` は「変更を見て再起動する」機能。開発の “自動リロード” を Node 単体でやれる感じです👀✨([Node.js][4])

## 3) Compose で動かす（例）🐳

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - node_modules:/app/node_modules
    command: sh -lc "npm run dev:build & npm run dev:run"
volumes:
  node_modules:
```

* `sh -lc "A & B"` で **2プロセス同居**（簡易）🧪
* もう少し綺麗にやるなら `concurrently` などに任せる手もあります（後でOK）😉

---

## ルートB：`tsx watch` で TS 直実行 🏃‍♂️💨

## 1) scripts：開発は tsx、型チェックは tsc に任せる🧩🧷

`tsx` は便利だけど **型チェックはしない**ので、役割分担が王道です✅([tsx][6])

```jsonc
{
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "type-check": "tsc --noEmit",
    "start": "node dist/index.js"
  }
}
```

* `dev`：保存したら即再実行（tsx watch）🔁([tsx][7])
* `type-check`：型だけチェック（CI や pre-commit、または気になったら手で実行）🧷([tsx][6])

## 2) Compose（tsx ルートはとにかくシンプル）🪄

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - node_modules:/app/node_modules
    command: npm run dev
volumes:
  node_modules:
```

> 📌 tsx は「node の代わりに使える」ノリで OK です（Node フラグも渡せます）😆([tsx][5])

---

## 🧯 ありがち事故と対処（Docker + watch 編）🐳👀

### ① 「保存しても watch が反応しない／遅い」🫠

watch は OS のファイル通知に依存するので、環境によって差が出ます📎
TypeScript 側も `fs.watch` を使うため、その挙動差や制限が公式に説明されています([typescriptlang.org][8])

さらに Docker Desktop + WSL2 では、**Linux コンテナが inotify（変更通知）を受け取れるのは “Linux 側のファイルシステム上のファイル” が基本**、というベストプラクティスが明記されています📌([Docker Documentation][9])

👉 つまり、困ったらまずこれ：

* プロジェクトを **WSL の Linux 側**に置く（/mnt/c 配下より Linux 側が安定しやすい）🐧🪟([Docker Documentation][9])

### ② 「tsx は動くけど、型ミスに気づきにくい」😇

tsx は「型チェックは別でやってね」設計です🧷([tsx][6])
👉 対処：

* `npm run type-check` を “節目” で叩く（CI に入れるのが最強）✅

---

## 🤖 AI（例：GitHub の Copilot / OpenAI 系ツール）に投げる一言テンプレ✨

* 「tsx ルートで、`dev` は `tsx watch`、`type-check` は `tsc --noEmit` の scripts を作って」🤖📝
* 「tsc -w で dist 出して、node --watch で再起動する compose コマンドを書いて」🐳🔁
* 「watch が効かない時の Windows + WSL2 の注意点を短くまとめて」🪟🐧

---

## ✅ この章のまとめ（チートシート）📌✨

* **ルートA（tsc -w → dist → node）**：本番に近い、安心感つよい🧱
* **ルートB（tsx watch）**：最速で回せる、学習が進む🏎️
* **tsx は型チェックしない** → `tsc --noEmit` を別に置くのが王道🧷([tsx][6])
* Docker + watch が怪しい時は **WSL2 のファイル置き場**が最重要ポイントになりがち📌([Docker Documentation][9])

---

次の第21章は、この2択のうち **「まずはラクな方（tsx ルート）で成功体験」**を、もっと手順化して “確実に動く” ところまで持っていく回にすると気持ちよく繋がります😆🔥

[1]: https://nodejs.org/en/about/releases/ "Node.js — Node.js Releases"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://www.typescriptlang.org/docs/handbook/compiler-options.html "TypeScript: Documentation - tsc CLI Options"
[4]: https://nodejs.org/api/cli.html "Command-line API | Node.js v25.6.0 Documentation"
[5]: https://tsx.is/ "TypeScript Execute (tsx) | tsx"
[6]: https://tsx.is/typescript "TypeScript | tsx"
[7]: https://tsx.is/watch-mode "Watch mode | tsx"
[8]: https://www.typescriptlang.org/docs/handbook/configuring-watch.html "TypeScript: Documentation - Configuring Watch"
[9]: https://docs.docker.com/desktop/features/wsl/best-practices/?utm_source=chatgpt.com "Best practices"
