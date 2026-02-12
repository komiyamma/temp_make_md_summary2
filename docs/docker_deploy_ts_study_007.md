# 第07章：Dockerfile最小：まず“動く本番”を作る 🧱

この章は「軽量化は次章でOK！まずは **本番っぽく動くコンテナ** を“確実に1本”作る」がゴールだよ😆✨
（2026-02-12時点だと Node は v24 が Active LTS、v25 が Current だよ📌）([Node.js][1])

---

## 1) まず“完成形”を見よう 👀✨（TypeScript版）

これが **最小・実戦で通る** 形（※次章でマルチステージ化して痩せさせる）🧩

```dockerfile
## Dockerfile（TypeScript / Node API の最小例）
FROM node:24

WORKDIR /app

## 依存関係（まずは確実に入れる）
COPY package*.json ./
RUN npm ci

## ソースを入れてビルド
COPY . .
RUN npm run build

## 本番起動（dist が前提）
CMD ["node", "dist/index.js"]
```

ポイントはこの5つだけ👇

* 「FROM」から始まる（Dockerfileは基本ここから）📦([Docker Documentation][2])
* 「WORKDIR」で作業ディレクトリを固定📁([Docker Documentation][2])
* 「COPY → RUN」で依存を入れる🔧
* 「COPY . . → build」でTSをコンパイル🛠️
* 「CMD」で“起動コマンド”を固定🚀（CMDはデフォルト実行を決める命令）([Docker Documentation][2])

---

## 2) JavaScriptだけ（ビルド不要）ならもっと短い 🧃✨

```dockerfile
FROM node:24
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
CMD ["node", "src/index.js"]
```

---

## 3) ここが“最低条件”チェック ✅🔎（Dockerfileを書く前）

Dockerfileが正しくても、プロジェクト側が以下を満たしてないと動かないことが多いよ😵‍💫

**A. package.json にこれがある？**（例）

* 「build」: TypeScript を dist に出す
* 起動方法が「dist/index.js」などで決まってる

```json
{
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js"
  }
}
```

**B. dist が生成される？**
ローカルで一回だけ確認しておくと安心😌

```powershell
npm ci
npm run build
node dist/index.js
```

---

## 4) ハンズオン：Windowsで“ビルド→起動→確認”まで行く 🧑‍💻🔥

### Step 1. Dockerfile を作る 📝

プロジェクト直下（package.json がある場所）に「Dockerfile」を置くよ📌

### Step 2. イメージをビルドする 🏗️

```powershell
docker build -t myapp:local .
```

### Step 3. コンテナを起動する ▶️

アプリが 3000 で待ち受ける想定ならこう👇

```powershell
docker run --rm -p 3000:3000 myapp:local
```

ブラウザでアクセス（例）して反応を確認するよ🌐

* [http://localhost:3000](http://localhost:3000)

### Step 4. ログを見る 👀

別ターミナルで（コンテナIDは docker ps で見る）

```powershell
docker ps
docker logs <CONTAINER_ID>
```

---

## 5) “本番で死にがち”トップつまずき5 🧯😵‍💫（即解決）

### つまずき①：npm ci がコケる（package-lock が無い）💥

**症状**：npm ci が「lockfile が必要」みたいに怒る
**直し方**：package-lock.json を作ってコミットする（npm ci はCI/自動環境向けで、クリーンに固定インストールしたい時に使うやつ）([npm ドキュメント][3])

### つまずき②：npm run build が無い / dist が無い 🧱

**症状**：ビルドで失敗、または起動で dist/index.js が見つからない
**直し方**：

* package.json に build を用意
* tsconfig の outDir が dist になってるか確認

### つまずき③：コンテナは起動してるのにブラウザで見えない 👻

**原因あるある**：サーバが localhost だけで listen してる
**直し方**：listen の host を 0.0.0.0 にする（これは第6章の“0.0.0.0問題”の復習ポイントだよ🔁）

（例：Express）

```ts
app.listen(port, "0.0.0.0", () => {
  console.log("server started");
});
```

### つまずき④：ポートが合ってない 🔌

**症状**：p で開けてるのに応答なし
**直し方**：

* アプリ側の待受ポート
* docker run の「-p 外:中」
  この2つが一致してるか見る👀

（例：PORT を使う場合）

```powershell
docker run --rm -e PORT=8080 -p 8080:8080 myapp:local
```

### つまずき⑤：native addon（bcrypt等）でビルドが落ちる 🧨

**症状**：npm ci の途中で node-gyp 系エラー
**直し方（超ざっくり）**：

* まず依存の見直し（純JS実装に替える等）
* 次章の「ビルド環境と実行環境を分ける（マルチステージ）」に行くと解決しやすい✨

---

## 6) “最小”なのに強いコツ 🧠✨（今のうちに1個だけ）

**COPY の順番**は地味に大事だよ🔥
Dockerは手順ごとにキャッシュするから、依存（package*.json）が先だと速い🏎️💨

* 先に「package*.json」だけ COPY
* 依存を入れる
* 最後にソース全部 COPY

この流れ自体は、Docker公式のNodeガイドでも定番の考え方（コンテナ化〜ビルド〜実行の流れ）だよ📘([Docker Documentation][4])

---

## 7) ミニ課題（この章の“合格ライン”）✅🏁

* Dockerfile を置いて build が通る
* docker run で起動してブラウザ/HTTPクライアントで応答が返る
* 失敗したら「つまずきTop5」のどれかで直せる

---

## 8) AIに投げるプロンプト（コピペOK）🤖✨

**A. Dockerfile生成（TS向け最小）**

```text
このNode/TypeScriptプロジェクトを本番コンテナで動かしたいです。
dist にビルドして node dist/index.js で起動します。
最小のDockerfileを作って。余計な最適化は次章でやるので今回は“確実に動く”優先で。
```

**B. ビルドが落ちた時の原因切り分け**

```text
docker build が npm ci / npm run build で失敗します。
ログはこれです（貼る）。
原因の可能性を3つに絞って、確認手順→修正案の順で出して。
```

**C. ポート疎通ができない時**

```text
コンテナは起動してるのにブラウザからアクセスできません。
Docker run コマンドと、アプリの listen 部分のコードを貼るので、
原因候補と直し方を“最短ルート”で教えて。
```

---

次の第8章では、このDockerfileを **マルチステージ化**して「サイズ・安全性・速さ」が一気に良くなる体験をやるよ✂️🎒✨

[1]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[2]: https://docs.docker.com/reference/dockerfile/ "Dockerfile reference | Docker Docs"
[3]: https://docs.npmjs.com/cli/v9/commands/npm-ci/?utm_source=chatgpt.com "npm-ci"
[4]: https://docs.docker.com/guides/nodejs/containerize/ "Containerize | Docker Docs"
