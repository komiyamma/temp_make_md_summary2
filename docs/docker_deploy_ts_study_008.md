# 第08章：マルチステージ入門：ビルド用と実行用を分ける ✂️🎒

この章は「**TypeScriptをビルドする環境**」と「**本番で動かす環境**」を、Dockerfileの中でキレイに分離する回だよ〜😆✨
これができると、**イメージが軽くなる**し、**余計なものが入らない**し、**セキュリティ的にも有利**になって一気に“本番っぽさ”が出る！🛡️📦
（マルチステージはDockerの公式で「おすすめの作り方」として説明されてるよ）([Docker Documentation][1])

---

## この章でできるようになること ✅😺

* **ビルド用（builder）** と **実行用（runner）** を分けたDockerfileを書ける ✍️🐳
* `COPY --from=...` で「必要な成果物だけ」を最終イメージへ持っていける 🎯📁
* “デカい・遅い・危ない” になりがちなDockerfileを、かなりマシにできる 💪🔥

---

## 1) なんで分けるの？（超ざっくり）🤔💡

TypeScript系のNodeプロジェクトって、ビルドする時にだいたい👇が必要になるよね？

* `typescript` みたいな **devDependencies**
* ビルドツール（bundlerやlint系）
* ビルドのための一時ファイル

でも本番で動かす時は…

* **ビルド済みの `dist/`**
* **本番依存（dependencies）だけ**
  があればOKなことが多い👍✨

マルチステージにすると、**ビルドに必要なものを最終イメージに残さず捨てられる**ので、サイズが減って、攻撃面（入ってるツールや依存）が減る＝安全寄りになる、って感じだよ🛡️🧹([Docker Documentation][1])

---

## 2) まずは「ありがちな単一ステージ」😵‍💫（重くなりやすい例）

「全部入り」で作ると、最終イメージにも **ビルド道具が残りがち**😇

```dockerfile
FROM node:24-bookworm-slim
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

EXPOSE 8080
CMD ["npm", "start"]
```

これ、動くことは多いけど…

* `typescript` など devDependencies も入りやすい
* `src/` とかテストとかも入りやすい
* ビルド用のゴミも残りやすい
  ってなりがち🙃🌀

---

## 3) ここから本題：マルチステージにする ✂️🎒✨

ポイントは超シンプル👇

* ステージ1（builder）：**依存入れて→ビルドして→distを作る** 🏗️
* ステージ2（runner）：**distと本番依存だけを持っていく** 🏃‍♂️

Docker公式の説明どおり、`FROM` を複数回書いてステージを分けるよ🧱([Docker Documentation][1])

---

## 4) ハンズオン：Dockerfileを書き換える（Windows + VS Code）🪟🧑‍💻🐳

ここでは **Node 24（Active LTS）** を例にするよ（2026-02時点のステータスも公式に載ってる）([Node.js][2])
Docker Hubにも `node:24-bookworm-slim` みたいなタグがちゃんとある👍([Docker Hub][3])

## ステップ0：前提チェック（プロジェクト側）🔍✅

`package.json` にだいたいこういうのがある想定だよ👇

* `build`：`tsc` などで `dist/` を作る
* `start`：`node dist/index.js` みたいに **distを起動**する

---

## ステップ1：マルチステージDockerfile（コピペOK）📋✨

```dockerfile
## --------
## 1) builder：ビルド専用ステージ
## --------
FROM node:24-bookworm-slim AS builder
WORKDIR /app

## 依存のインストール（再現性重視なら npm ci）
COPY package*.json ./
RUN npm ci

## ソースを入れてビルド
COPY . .
RUN npm run build


## --------
## 2) runner：本番実行専用ステージ
## --------
FROM node:24-bookworm-slim AS runner
WORKDIR /app

## 本番依存だけ入れる（devDependenciesを落とす）
COPY package*.json ./
RUN npm ci --omit=dev

## builderで作った成果物だけ持ってくる
COPY --from=builder /app/dist ./dist

## 必要なら静的ファイル等も追加でcopy（例）
## COPY --from=builder /app/public ./public

ENV NODE_ENV=production
EXPOSE 8080

## npm start が "node dist/index.js" になってる想定
CMD ["npm", "start"]
```

### ここがキモ！🐳🔥

* `AS builder` / `AS runner`：ステージに名前をつける🪪
* `COPY --from=builder ...`：**builderから必要なものだけ**コピー🎯
* `npm ci --omit=dev`：本番依存だけ入れる（npm v8+で一般的）🧹([Stack Overflow][4])

---

## ステップ2：ビルドしてサイズ比較する📏📦（これ超気持ちいいやつ）

PowerShell（またはVS Codeのターミナル）で👇

```bash
docker build -t myapp:multistage .
docker image ls myapp
```

もし前の単一ステージも残してあるなら、タグ変えて比較すると最高にわかるよ😆📉

```bash
docker image ls | findstr myapp
```

---

## ステップ3：動作確認する（起動）🚀🌐

```bash
docker run --rm -p 8080:8080 myapp:multistage
```

ブラウザで `http://localhost:8080` を開いて確認だ！🕺✨
（APIなら `curl` でもOK👌）

---

## 5) “よくあるハマり”Top5 😵‍💫🧯

## ① `npm start` が `src` を見に行ってる

**本番は `dist` を起動**するのが基本だよ〜！
`start` を `node dist/index.js` に寄せよう🎯

## ② `dist/` がコピーされてない

`COPY --from=builder /app/dist ./dist` のパスを確認！📁👀
（`out/` や `build/` 使ってる人もいるので注意）

## ③ `npm ci` が失敗する

`package-lock.json` が無いと `npm ci` は基本ムリ🙃
（無いなら `npm install` にするか、lockfileを作る方向へ）

## ④ `--omit=dev` したら起動に必要なものまで消えた

それ、依存の分類ミスの可能性大！😇
「本番で必要なもの」は `dependencies` に入れよう📦

## ⑤ ポートが合ってない

コンテナの中でアプリが `8080` を listen してる？
（この教材だと第6章でやった `0.0.0.0` / `PORT` の話に繋がるやつ！🔌😵）

---

## 6) チェックリスト ✅✅✅（提出前にこれ見る）

* [ ] 最終イメージに `src/` やテストが入ってない
* [ ] 最終イメージに `typescript` など devDependencies が入ってない
* [ ] `dist/` だけで起動している
* [ ] `COPY --from=builder` を使ってる
* [ ] `npm ci --omit=dev` で本番依存だけにしてる ([Stack Overflow][4])

---

## 7) ミニ課題 🎯📉

1. 単一ステージ版とマルチステージ版を作って、`docker image ls` でサイズ差をメモしよう📝
2. `runner` 側で `COPY --from=builder` するものを増減して、何が必要か観察しよう👀
3. `node:24-bookworm-slim` と `node:24-slim` の違いを Docker Hub で眺めてみよう（タグの存在はここで確認できる）([Docker Hub][3])

---

## 8) AIに投げるコピペ質問（そのまま使ってOK）🤖✨

* 「このDockerfileをマルチステージ化して。builderとrunnerに分けて、最終イメージにはdistと本番依存だけ残して」
* 「`npm start` が src を参照してそう。dist起動に直す案を出して」
* 「`npm ci --omit=dev` で落ちた。ログ貼るので原因と直し方を3案で」
* 「最終イメージに入ってるファイルを減らしたい。`COPY --from=builder` の最小セットを提案して」

---

## おまけ：最新状況メモ（章の安心材料）🧷📌

* Node 24 は Active LTS、Node 25 は Current として公式に掲載されてる（更新日も2026-02で出てる）([Node.js][2])
* `node:24-bookworm-slim` などのタグは Docker Hub の公式イメージ一覧にある([Docker Hub][3])
* マルチステージはDocker公式が「サイズ削減・分離のベストプラクティス」として明確に推してる([Docker Documentation][5])

---

次の章（第9章）は、このマルチステージをさらに強くする「依存固定＆キャッシュ」系に繋がるよ〜⚡😆
もし手元のリポジトリ構成（フォルダ構造と `package.json` の scripts）を貼ってくれたら、この第8章のDockerfileを**そのプロジェクト専用に最適化**した版も作るよ🛠️🐳✨

[1]: https://docs.docker.com/build/building/multi-stage/?utm_source=chatgpt.com "Multi-stage builds"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://hub.docker.com/_/node?utm_source=chatgpt.com "node - Official Image"
[4]: https://stackoverflow.com/questions/9268259/how-do-you-prevent-install-of-devdependencies-npm-modules-for-node-js-package?utm_source=chatgpt.com "How do you prevent install of \"devDependencies\" NPM ..."
[5]: https://docs.docker.com/build/building/best-practices/?utm_source=chatgpt.com "Building best practices"
