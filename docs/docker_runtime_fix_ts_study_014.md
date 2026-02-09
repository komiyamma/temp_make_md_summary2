# 第14章：Nodeの“実行モード”を分ける意識🎭

この章でやることはシンプルです😊
同じアプリでも、**開発（いじる）** と **本番（動かし続ける）** で「走らせ方」が別物だと理解して、最低限の切り替えを作ります🎛️✨

ちなみに本日時点だと、Node は **v25 が Current / v24 が Active LTS / v22 が Maintenance LTS** という並びです。([nodejs.org][1])
この教材では「固定＝安定」を狙うので、基本は Active LTS 側で考えるのがラクです🟢

---

#### 1) まず結論：開発＝速さ🏎️ / 本番＝安定🪨

* **開発モード（dev）** 🧑‍💻
  目的：変更をすぐ反映して、爆速で試す
  例：ファイル監視で自動再起動、エラー表示が親切、デバッグしやすい

* **本番モード（prod）** 🏭
  目的：落ちない・軽い・余計なものを入れない
  例：ビルド済み成果物だけで起動、監視や開発ツールは入れない、ログが運用向け

ここを混ぜると「動くけど遅い」「本番だけ落ちる」「コンテナが太る」みたいな事故が増えます😇💥

---

#### 2) “分ける”って、具体的に何を分けるの？🧠🪓

最低限はこの3つだけでOKです👌✨

1. **起動コマンド（scripts）**
2. **依存関係（devDependencies を本番に入れるか）**
3. **Dockerの動かし方（マウントで回すか、成果物だけで起動するか）**

---

#### 3) scripts を「dev / build / start」に揃える📦📝

ここが“設計の入口”です🚪✨
**コマンド名が揃うと、迷子が消えます**🧭

例：TypeScriptプロジェクトの最小イメージ👇

```json
{
  "scripts": {
    "dev": "node --watch src/index.js",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js"
  }
}
```

ポイント🌟

* **dev**：開発用。速く動けば勝ち🏁
* **build**：本番に持っていく成果物を作る🏗️
* **start**：本番用。成果物を静かに起動する🤫

> ちなみに Node の `--watch` は v22.0.0 / v20.13.0 で stable 扱いになっています👀🔁([nodejs.org][2])
> 「開発での自動再起動」を Node 標準でやれる、ってことです👍

---

#### 4) NODE_ENV の使い方：雑に “staging” とか入れない😅⚠️

ありがちな罠がこれ👇

* `NODE_ENV=development` で動くのに
* `NODE_ENV=production` にしたら挙動が変わって壊れる

Node公式も、**環境名によって最適化や挙動を変えすぎると、信頼できるテストができなくなる**という趣旨で注意しています。([nodejs.org][3])

おすすめの考え方🍀

* `NODE_ENV` は **production / development** くらいに留める
* staging や preview を分けたいなら **別の変数**（例：`APP_ENV=staging`）でやる

---

#### 5) 依存関係：本番は “devDependencies を入れない” が基本📦🧊

開発には必要だけど、本番には不要なものって多いです😌
例：TypeScript本体、ts-node/tsx系、eslint、テスト系…など

npm 側の基本ルールとして、**`NODE_ENV=production` だと devDependencies を入れない**挙動になります。([docs.npmjs.com][4])

さらに、再現性重視なら `npm ci` が強いです💪
`npm ci` は lockfile 前提で、ズレたらエラーにしてくれるので「毎回同じ」を作りやすいです。([docs.npmjs.com][5])

---

#### 6) Dockerでの “開発” と “本番” の違い🐳🎭

ここが一番大事かもです👇

| 項目  | 開発コンテナ🧑‍💻           | 本番コンテナ🏭        |
| --- | --------------------- | --------------- |
| ソース | **マウント**して即反映🌀       | **コピー**して固定📦   |
| 監視  | `--watch` / devサーバ等👀 | 基本しない（運用側で監視）🧯 |
| 依存  | 開発用も全部入りが多い🧰         | 余計なものを減らす🧊     |
| 目的  | 速く回す🏎️               | 小さく安全に動かす🪨     |

そして本番に寄せるなら、Docker の **マルチステージビルド**が王道です👑
ビルド環境と実行環境を分けて、最終イメージを小さく・攻撃面も減らせます。([Docker Documentation][6])

---

#### 7) “本番用Dockerfile”の型（まずは雰囲気でOK）🧱✨

「今すぐ完全理解」じゃなくて大丈夫🙆‍♂️
**“ビルド用ステージ” と “実行用ステージ” を分ける**だけ覚えればOKです🧠

```dockerfile
## 1) build stage
FROM node:24-bookworm-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

## 2) runtime stage
FROM node:24-bookworm-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
CMD ["node", "dist/index.js"]
```

* 前半：ビルドに必要なもの全部使ってOK🏗️
* 後半：実行に必要なものだけに絞る🧊

マルチステージの「要らないものを最終イメージに残さない」考え方は Docker 公式でも強く推されています。([Docker Documentation][7])

---

#### 8) この章のミニ演習🎮✨（10〜20分）

1. `package.json` に `dev / build / start` を用意する📝
2. 開発：`npm run dev` で自動再起動を体験👀🔁
3. 本番：`npm run build` → `npm run start` で「成果物起動」を体験🏭
4. できたら Docker：

   * 開発はマウントで回す🌀
   * 本番はマルチステージで“成果物だけ”を入れる📦

---

#### 9) つまずきポイント集（先に潰す）🧯😆

* ✅ **「開発だけ動く」**：watchやdevDependenciesに依存してる可能性大
* ✅ **「本番が重い」**：ビルドツールやテストツールがイメージに残ってるかも
* ✅ **「stagingだけ壊れる」**：`NODE_ENV` に環境名を混ぜて挙動が分岐してないか確認🔍([nodejs.org][3])

---

#### 10) AIに投げると速い“指示文”🤖💬

* 「`dev / build / start` が揃う `package.json` を最小で作って」
* 「Dockerfile をマルチステージで、本番イメージを小さくして。devDependencies を本番に入れない形にして」
* 「開発はマウント＆watch、本番は成果物起動の2モード構成にして」

---

次の章（第15章）に行くと、「じゃあなんで alpine をいきなり使わないの？」がスッキリ繋がります🧊➡️🧠
この第14章で“モード分離の感覚”を持ててると、あとの判断がめちゃ楽になりますよ😆👍

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://nodejs.org/api/cli.html "Command-line API | Node.js v25.6.0 Documentation"
[3]: https://nodejs.org/en/learn/getting-started/nodejs-the-difference-between-development-and-production "Node.js — Node.js, the difference between development and production"
[4]: https://docs.npmjs.com/cli/v8/commands/npm-install/ "npm-install | npm Docs"
[5]: https://docs.npmjs.com/cli/v9/commands/npm-ci/ "npm-ci | npm Docs"
[6]: https://docs.docker.com/build/building/best-practices/?utm_source=chatgpt.com "Building best practices"
[7]: https://docs.docker.com/build/building/multi-stage/?utm_source=chatgpt.com "Multi-stage builds"
