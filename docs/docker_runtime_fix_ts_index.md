# ランタイム固定（Node/TSなど“インタープリタ環境の閉じ込め”）30章カリキュラム🚀🐳

（※Nodeは **v24 が Active LTS**、v25がCurrent、v22がMaintenance LTS という状態です）([nodejs.org][1])
（※TypeScriptは **5.9系が安定版**として案内されていて、npm上の “Latest” も 5.9.x 系表示です）([typescriptlang.org][2])


## 第1章：ランタイム固定って結局なに？🤔🔒

* 🎯 ゴール：**「PCのNode事情に左右されない」状態がイメージできる**
* ✅ やること：失敗例（Node版違い・依存事故）を想像して「固定の価値」を言語化
* 🧠 重要ワード：再現性・同じ手順で同じ結果・環境差ゼロ

## 第2章：2026年の“正解っぽいNode選び”🎯🟢

* 🎯 ゴール：**なぜ LTS を選ぶのか**が腹落ちする
* ✅ やること：Nodeのリリース状態（Current / Active LTS / Maintenance LTS）を理解
* ✅ 結論：基本は **Active LTS（いまはv24）** を使う([nodejs.org][1])

## 第3章：TypeScript側も“固定”がいる理由🧩🧷

* 🎯 ゴール：TSは「型」だけじゃなく**ビルド結果**にも影響するのが分かる
* ✅ やること：TSのバージョン差で `tsc` 挙動が変わることを知る
* 📌 参考：TypeScript 5.9系の変更点の雰囲気を掴む([typescriptlang.org][2])

## 第4章：「固定」には3段階ある📦📦📦

* 🎯 ゴール：どこまで固定すべきか迷わない
* ✅ やること：固定対象を3つに分ける

  1. Node本体（Dockerイメージ）
  2. パッケージマネージャ（npm/pnpm/yarnの版）
  3. 依存（lockfile）

## 第5章：最初のゴール設定🎯✨（“動く”の定義）

* 🎯 ゴール：あなたの中の「できた！」基準を作る
* ✅ できた判定：

  * `docker build` が通る
  * `docker run` でアプリが起動する
  * Node/TSの版が**毎回同じ**になる

---

## 第6章：まずは `docker run` で「閉じ込め」体験🐳💨

* 🎯 ゴール：PCのNodeを使わずに Node が動く
* ✅ やること：`node:24` 系で `node -v` を実行して確認
* 🧠 ポイント：「ホストにNodeいらないじゃん！」が体感できる

## 第7章：Node公式イメージの“タグ”読み方👀🏷️

* 🎯 ゴール：`node:24` と `node:24-bookworm-slim` の違いが分かる
* ✅ やること：Docker Hubの node 公式イメージの存在を確認([hub.docker.com][3])
* 🧠 ざっくり：

  * `bookworm` = Debian系
  * `slim` = 小さめ
  * `alpine` = さらに小さいが相性注意（初心者は後回しでOK）

## 第8章：最初の固定は “LTS + Debian slim” でいこう🟢📦

* 🎯 ゴール：迷わずベースを決める
* ✅ おすすめ：`node:24-bookworm-slim`（LTSで安定 + 事故りにくい）([nodejs.org][1])

## 第9章：固定できてるか“毎回チェック”する癖✅🔁

* 🎯 ゴール：環境固定が壊れたら即気づける
* ✅ やること：起動ログに `node -v` を出す、または起動前に確認する

## 第10章：最小Dockerfileを作る（まずはJS）🧱✨

* 🎯 ゴール：**“最小で再現できる”Dockerfile** が書ける
* ✅ 成果物：Dockerfile（最小）

```dockerfile
FROM node:24-bookworm-slim
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
CMD ["node", "src/index.js"]
```

（`npm ci` は lockfile 前提で “ズレたらエラーで止まる” ＝再現性に強いです）([docs.npmjs.com][4])

---

## 第11章：`npm ci` を味方につける🧼📦

* 🎯 ゴール：依存を“毎回同じ”にできる
* ✅ やること：`package-lock.json` を必ずコミットする
* ⚠️ つまずき：「lockとpackage.jsonがズレてる」→ `npm ci` が怒る（それが正しい）([docs.npmjs.com][4])

## 第12章：Dockerビルドを速くする“基本の型”⚡🧠

* 🎯 ゴール：変更のたびに依存インストールしない
* ✅ やること：`COPY package*.json → npm ci → COPY .` の順にする
* 🧠 理由：package類が変わらない限りキャッシュが効く

## 第13章：`.dockerignore` を入れて“地味に爆速”🚀🧹

* 🎯 ゴール：余計なファイルを送らない
* ✅ 成果物：`.dockerignore`

```text
node_modules
dist
.git
.gitignore
Dockerfile
docker-compose*.yml
npm-debug.log
```

（プロジェクトに合わせて増減でOK）

## 第14章：Nodeの“実行モード”を分ける意識🎭

* 🎯 ゴール：「開発」と「本番」が別物だと分かる
* ✅ やること：今は“開発寄りDockerfile”でOK、ただし区別だけ覚える

## 第15章：`node:alpine` をいきなり使わない理由🧊⚠️

* 🎯 ゴール：小さい＝正義、ではないと理解する
* ✅ やること：まずDebian系で安定→慣れたらAlpine検討

---

## 第16章：開発では「ソースはマウント」して最速ループ🌀🧑‍💻

* 🎯 ゴール：毎回buildしなくても編集→反映できる
* ✅ やること：`docker run -v`（または後のCompose）でソース共有

## 第17章：**node_modules問題**（初心者が100%踏むやつ）💣📦

* 🎯 ゴール：`node_modules` をホストと混ぜて地獄を見ない
* ✅ 結論：**node_modules はコンテナ側（volume）に置く**のが安全寄り

## 第18章：Composeで“開発用の型”を作る📄✨

* 🎯 ゴール：`docker compose up` で開発が始まる
* ✅ 成果物：`compose.yml`（Node固定 + ソース共有 + node_modulesはvolume）

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

（これでホスト側の `node_modules` と混ざりにくくなります👍）

## 第19章：Nodeの `--watch` を知る👀🔁

* 🎯 ゴール：ホットリロードの基本が分かる
* ✅ やること：Nodeには `--watch` がある（v22+やv20.13+で安定扱い）

## 第20章：TS開発は2択（王道）🛣️🧭

* 🎯 ゴール：混乱しない選択肢が持てる
* ✅ 2択：

  1. `tsc -w` で `dist/` を作って Nodeで実行
  2. `tsx` などで TS を直接実行（開発が速い）

## 第21章：まずは“ラクな方”で成功体験😆✨（tsxルート）

* 🎯 ゴール：TSでも即動く
* ✅ やること：`tsx` をdevDependencyに入れて `npm run dev` で起動
* 🧠 気持ち：最初は速いほうが正義🥳

---

## 第22章：`package.json` の最小設計📦📝

* 🎯 ゴール：実行コマンドが迷子にならない
* ✅ やること：`scripts` を揃える（dev/build/start）

## 第23章：`tsconfig.json` は “まず薄く”🧊➡️🧠

* 🎯 ゴール：TS設定で溺れない
* ✅ やること：まずは `tsc --init` → ちょい調整
* 📌 5.9系では `tsc --init` 体験も改善の流れがあります([Microsoft for Developers][5])

## 第24章：ESM/CJSで詰まない最低ライン🧯📦

* 🎯 ゴール：`import` でコケても原因が分かる
* ✅ やること：`"type": "module"` の意味を知る（必要な時だけ付ける）

## 第25章：ソースマップでデバッグが幸せになる🕵️‍♂️✨

* 🎯 ゴール：TSの行番号で追える
* ✅ やること：Nodeの `--enable-source-maps` を知っておく

---

## 第26章：VS Code の Dev Containers で“開発環境ごと固定”🧰🐳

* 🎯 ゴール：VS Codeごとコンテナに入って開発できる
* ✅ やること：Dev Containers拡張を使うと、フォルダを“コンテナとして開く”ができる([Visual Studio Marketplace][6])
* 🧠 うれしい：拡張機能・ツール・Node版が“プロジェクトに紐づく”

## 第27章：`.devcontainer/devcontainer.json` 最小を置く📁✨

* 🎯 ゴール：ワンクリックで開発環境が立ち上がる
* ✅ 成果物：`devcontainer.json`（最小）

```json
{
  "name": "node-ts",
  "build": { "dockerfile": "../Dockerfile" }
}
```

（Dev Container仕様の考え方も公式で整理されています）([devcontainers.github.io][7])

## 第28章：WindowsでのDockerはWSL2が基本路線🐧🪟

* 🎯 ゴール：変な不調に強くなる
* ✅ やること：Docker DesktopのWSL2バックエンド周りの注意だけ知る（WSLは新しめ推奨）([Docker Documentation][8])

## 第29章：固定を“壊さない運用ルール”を作る📏🧠

* 🎯 ゴール：チームでも未来の自分でも困らない
* ✅ ルール例：

  * ベースは `node:24-...`（LTS）
  * 依存は lockfile必須
  * `npm ci` を使う（ズレは直してから進む）([docs.npmjs.com][4])

## 第30章：テンプレ化して“毎回コピペで勝つ”📦🏁🎉

* 🎯 ゴール：新規PJで悩まず始められる
* ✅ 最終成果物（セット）：

  * `Dockerfile`
  * `.dockerignore`
  * `compose.yml`
  * （任意）`.devcontainer/devcontainer.json`
  * `package.json`（scripts整備）
* 🤖 AIに投げる一言例：
  「この構成を“最小＆再現性重視”でテンプレ化して。node_modulesはvolume、npm ci、NodeはActive LTSで！」

---

## 30章終わったら何が手に入る？🎁✨

* 🧱 **Node/TSのバージョンが毎回同じ**（PC差が消える）([nodejs.org][1])
* 📦 **依存が毎回同じ**（lockfile + `npm ci`）([docs.npmjs.com][4])
* 🌀 **開発ループが速い**（Compose + mount + watch）
* 🧰 **VS Codeごと固定もできる**（Dev Containers）([Visual Studio Marketplace][6])
* 🪟🐧 Windowsでも **WSL2前提で安定運用**に寄せられる([Docker Documentation][8])

---

次は、この30章のうち「第10章〜第18章（Dockerfile〜Composeで開発ループ完成）」を、**実際のサンプル（Node+TSの最小API）**で“丸ごと教材ページ”にして出す形にすると、めちゃ定着します😆🔥
「APIはExpress系がいい」「Fastifyがいい」「ただのHelloでいい」みたいな好みがあれば、それに寄せて書きます✨

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://hub.docker.com/_/node?utm_source=chatgpt.com "node - Official Image"
[4]: https://docs.npmjs.com/cli/v9/commands/npm-ci/?utm_source=chatgpt.com "npm-ci"
[5]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
[6]: https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers&utm_source=chatgpt.com "Visual Studio Code Dev Containers"
[7]: https://devcontainers.github.io/implementors/json_reference/?utm_source=chatgpt.com "Dev Container metadata reference"
[8]: https://docs.docker.com/desktop/features/wsl/?utm_source=chatgpt.com "Docker Desktop WSL 2 backend on Windows"
