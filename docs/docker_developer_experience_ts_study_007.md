# 第07章：まずは王道：ソースはマウントする📂✨

この章は「編集はホスト（VS Code）」「実行はコンテナ」っていう、開発DXの“王道フォーム”を作る回だよ〜😄👍
ホットリロードやテスト自動実行も、まずこの土台がないと始まらない！🔥

---

## この章のゴール🎯

* ✅ コンテナの中に **プロジェクトのソースコードが見える**（＝マウント成功）
* ✅ **編集→コンテナに即反映** を確認できる
* ✅ Windowsで事故りがちな **node_modules問題** を避けられる 🙆‍♂️

---

## まず結論：Windowsは「置き場所」で勝負が決まる🪟⚔️

ホットリロード系（次章以降でやるやつ）は「ファイル変更イベント（inotify）」が超重要なんだけど、これが **Linux側のファイルシステムに置いてないと期待通り来ない/遅い** ことがあるんだ🥲
なので、**プロジェクトはWSLの中（Linuxファイルシステム）に置く**のが鉄板！🚀 ([Docker Documentation][1])

## ✅ OKな置き場所（おすすめ）🐧✨

* `~/projects/myapp`（WSLのUbuntu内）
* エクスプローラだと `\\wsl$\Ubuntu\home\{ユーザー名}\projects\myapp`

## ❌ 事故りやすい置き場所（避けたい）😇

* `/mnt/c/...`（Cドライブ直下相当）
  → パフォーマンスが落ちやすい＆変更検知が不安定になりやすい、って公式も言ってるやつ！ ([Docker Documentation][1])

---

## “マウント”って何してるの？🧠📦

ざっくりこう👇

* VS Codeで編集する場所（ホスト側フォルダ）を
* コンテナ内の `/app` に **そのまま写し鏡みたいに見せる**（= bind mount）

これができると、コンテナは「常に最新のソース」を見ながら動ける✨

---

## ハンズオン：まず動く“王道マウント構成”を作る🛠️😺

ここでは **Node 24（Active LTS）** の公式イメージを例にするよ（2026/02時点）📌 ([Node.js][2])
（あなたのプロジェクトに置き換えてOK！）

---

## 1) WSL内にプロジェクトを置いて、VS Codeで開く📂🧑‍💻

WSLのターミナルで👇

```bash
mkdir -p ~/projects/dx-mount-sample
cd ~/projects/dx-mount-sample
code .
```

`code .` で **WSL側のVS Code** として開ければOK（ここが超大事）😄✨

---

## 2) `compose.yaml` を作る（これが本体）🧩

```yaml
services:
  app:
    image: node:24-bookworm-slim
    working_dir: /app
    ports:
      - "3000:3000"
    volumes:
      # ✅ ソースコードを /app にマウント（王道）
      - type: bind
        source: .
        target: /app

      # ✅ node_modules はコンテナ側に隔離（事故防止）
      - app_node_modules:/app/node_modules
    command: npm run dev

volumes:
  app_node_modules:
```

ポイントはここ👇😍

* `.:/app` でソースを見せる📂
* `app_node_modules:/app/node_modules` で **node_modules をホストに作らせない**（Windowsで特に効く）🧨➡️🛡️

---

## 3) 最小の `package.json` と `src/index.js` を置く（確認用）🧪

```json
{
  "name": "dx-mount-sample",
  "private": true,
  "scripts": {
    "dev": "node src/index.js"
  }
}
```

```js
// src/index.js
const http = require("http");

const server = http.createServer((req, res) => {
  res.end("mount OK! 😄📦\n");
});

server.listen(3000, () => {
  console.log("listening on http://localhost:3000 🚀");
});
```

---

## 4) 起動して、依存をコンテナ内に入れる📦⬇️

まず起動（まだ依存入れてないから、次で入れる）👇

```bash
docker compose up -d
```

依存が必要なプロジェクトなら、**初回だけ**こう👇（サンプルは依存ないけど、型として覚える用）

```bash
docker compose run --rm app npm ci
```

最後にログ見て起動確認👀✨

```bash
docker compose logs -f app
```

ブラウザで `http://localhost:3000` を開いて
`mount OK! 😄📦` が出たら成功〜！🎉

---

## ミニ課題：マウントが効いてるか“目で見る”👀💡

## 課題A：ホストで編集 → コンテナに即反映される？✍️➡️📦

1. `src/index.js` の文字をこう変える👇
   `"mount OK! 😄📦"` → `"changed! ✨🛠️"`
2. そのままブラウザ更新
3. 表示が変わったら勝ち🏆（＝マウントでソースが共有されてる）

## 課題B：コンテナからもファイルが見える？🔍

```bash
docker compose exec app node -p "require('fs').readFileSync('src/index.js','utf8').slice(0,80)"
```

---

## よくある詰まりポイント集🚧😵‍💫（ここだけ見れば大体直る）

## 1) 変更しても反映されない / 反映が遅い🐢

* プロジェクトが `/mnt/c/...` に置かれてるパターンが多い
  → **WSLの `~/projects/...` に移動**が最強✨ ([Docker Documentation][1])

## 2) `node_modules` がホスト側にできて地獄😇

* `.:/app` だけにしてると、インストール時にホストへ出たりして事故る
  → この章の構成どおり **`/app/node_modules` を named volume にする**のが鉄板👍

## 3) Windows側パスをマウントしたら「共有が必要」って怒られる🙀

* Windowsファイルシステムを使う場合、Docker Desktopの共有設定が絡むことがあるよ（WSL内なら基本ラク） ([Docker Community Forums][3])

---

## どうしても「C:\に置きたい」派へ🪟🫶（救済ルート）

「会社ルールでC:\配下じゃないと無理😇」みたいな時は、Docker Desktopの **Synchronized file shares** が効くことがあるよ⚡
ホスト↔VM間の共有をキャッシュ＋同期で速くする仕組み（Mutagen統合）って説明されてる📌 ([Docker Documentation][4])

ただし注意点もあって👇

* Composeのbind mountで `:consistent` を指定すると、Synchronized file shares を **バイパス**することがあるよ⚠️ ([Docker Documentation][4])

（このへんは環境差あるので、“最後の手札”くらいで覚えとけばOK！🃏）

---

## AIで時短コーナー🤖✨（Copilot/Codex/ChatGPT向け）

そのままコピペで使えるプロンプト置いとくね😄🧠

* ✅ **あなたのプロジェクト用に compose.yaml を最適化**

  * 「Node/TSプロジェクトで、Windows+WSL2前提。`.:/app` のbind mountと `node_modules` をnamed volumeにした `compose.yaml` を作って。ポートは3000。`npm run dev`起動」

* ✅ **node_modules問題の診断**

  * 「Docker Composeで `.:/app` をマウントしたら依存関係が壊れた。`node_modules` をコンテナ側に隔離するベストプラクティスを、compose.yaml差分で教えて」

* ✅ **“遅い”の原因切り分け**

  * 「Windows+Docker Desktop(WSL2)でbind mountが遅い。プロジェクト位置（/mnt/c vs WSL）と対策（Synchronized file shares含む）をチェックリストで出して」

---

## まとめ🎉📌

この章で作ったのは、DX強化の“地盤”だよ🏗️✨
次からホットリロードや自動テストを入れていくけど、**マウントが安定してると全部ラクになる**😄👍

次章（第8章）で、この土台の上に **watchで最短ホットリロード**を乗せよう🔥🚀

[1]: https://docs.docker.com/desktop/features/wsl/best-practices/?utm_source=chatgpt.com "Best practices"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://forums.docker.com/t/mounts-denied-the-path-is-not-shared-to-the-host-when-it-is/142364?utm_source=chatgpt.com "Mounts denied: The path is not shared to the host; when it is"
[4]: https://docs.docker.com/desktop/features/synchronized-file-sharing/?utm_source=chatgpt.com "Synchronized file shares"
