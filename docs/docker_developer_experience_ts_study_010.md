# 第10章：nodemonは必要？判断基準を作る🤔🧰

この章のテーマはシンプル！
**「nodemonを“入れるべき時”と、“入れなくていい時”を迷わない」**です😊✨

---

## 1) まず結論：nodemonは「困った時に効く強い味方」👑

最近の開発は、最初から選択肢が多いです👇

* **Node標準の watch（`node --watch`）**：標準機能で軽い⚡ ([Node.js][1])
* **tsx watch（`tsx watch`）**：TS開発の体験が良い💨 ([tsx][2])
* **Compose Watch（`docker compose up --watch` / `docker compose watch`）**：コンテナ開発で“同期/再起動/再ビルド”まで面倒見れる🧱 ([Docker Documentation][3])
* **nodemon**：**「監視したいものが増えた時」「動かし方が複雑になった時」**に強い🧰 ([DigitalOcean][4])

なので最初は **Node watch / tsx watch** で走って、
「足りない！」となったら **nodemon** に“昇格”するのが気持ちいいです😄✨

---

## 2) nodemonの強みは何？どこが嬉しい？😋

nodemonはざっくり言うと👇
**「ファイルが変わったら、指定コマンドでアプリを再起動してくれる係」**です🔁

特に効くのはここ👇

* **監視対象を好きに増やせる**（例：`.env` / `*.graphql` / `*.sql` / 設定ファイル）🧠
  → そもそもデフォルトだと `.js/.mjs/.json` だけ見てることがあるので、`ext` や `watch` を明示できるのは大きいです ([DigitalOcean][4])
* **`--exec` で“実行エンジン”を差し替えできる**（TSなら `tsx` / `ts-node` など）🏃‍♂️
  → TSでも全然いけます ([DigitalOcean][4])
* **`delay` で連続保存の“二重再起動”を抑えられる**（地味に超大事）⏱️ ([DigitalOcean][4])
* **「再起動しないファイル」を ignore で切れる**（テスト書いてる時に便利）🙅‍♂️ ([DigitalOcean][4])

逆に注意点もあります👇

* **`-L`（legacy watch）を使うとCPUが上がることがある**（ポーリング監視になる）🔥 ([DigitalOcean][4])

---

## 3) Node標準 watch（`node --watch`）はどこまでいける？🧩

Node標準の watch は、最近かなり実用的です✨

* watchモードは **安定版（stable）になっている** ([Node.js][1])
* デフォルトでは **エントリポイント＋import/requireされたモジュール**の変更で再起動します ([Node.js][1])
* 出力を消したくない人は `--watch-preserve-output` が使えます🧼 ([Node.js][1])
* 再起動時に送るシグナルを変えたいなら `--watch-kill-signal` もあります（比較的新しめ）🧯 ([Node.js][1])

ただし弱点もはっきりしてます👇

* **「importされないファイル」**（`.env` や設定、テンプレ等）を監視しにくい
* `--watch-path` で監視パス指定ができるけど、**macOS/Windows限定**で、Linuxだと例外が出ます（＝コンテナ内Linuxで使うと刺さることがある）💥 ([Node.js][1])
* `--watch-path` を使うと、**import/requireの追跡監視がオフになる**（挙動が変わる）🔁 ([Node.js][1])

👉 なので **Dockerコンテナ内（Linux）で運用するなら**、`--watch-path` 前提の設計にはしない方が安全です😇 ([Node.js][1])

---

## 4) tsx watch は「TS開発の気持ちよさ」に強い🏄‍♂️

tsx の watch はこういう設計👇

* **依存（importされたファイル）が変わったら再実行** 💡 ([tsx][2])
* デフォルトで `node_modules` や `dist` などを避ける（余計な監視をしない）🧹 ([tsx][2])
* `--include` / `--exclude` で監視対象を調整できる🧷 ([tsx][2])

👉 「TSをサクサク回す」なら、**まず tsx watch が最短**になりやすいです😊 ([tsx][2])

---

## 5) Compose Watch は “コンテナ開発の最終兵器”👀🧱

Compose Watch は、アプリ内の再起動だけじゃなくて👇

* **sync**：ホストの変更をコンテナへ同期（ホットリロードがある前提に相性◎） ([Docker Documentation][3])
* **sync+restart**：同期して、そのサービスを再起動 ([Docker Documentation][3])
* **rebuild**：必要な変更（例：`package.json`）なら再ビルドして差し替え ([Docker Documentation][3])

さらに👇

* **`docker compose up --watch`** で起動できる（あるいは `docker compose watch`） ([Docker Documentation][3])
* **Docker Compose 2.22.0+ が必要** ([Docker Documentation][3])

👉 「Windowsのマウント越しでファイルイベントが不安定😇」みたいな時、
アプリ内watchより **Compose Watchの方が安定する**ことが多いです✨ ([Docker Documentation][3])

---

## 6) nodemonを入れるべき“判断軸”チェックリスト🧭✅

## ✅ nodemonが“必要になりやすい”条件

* `.env` や設定ファイル変更でも再起動したい（= importされない）🔧 ([DigitalOcean][4])
* `watch / ignore / ext / delay` を **プロジェクト方針として固定**したい📌 ([DigitalOcean][4])
* 実行コマンドが **`tsx` や `ts-node` などで一捻りある**🌀 ([DigitalOcean][4])
* “二重保存で2回再起動”みたいなガチャを減らしたい（`delay`が効く）⏱️ ([DigitalOcean][4])

## ✅ nodemonを“入れなくていい”ことが多い条件

* TSは `tsx watch` で十分回ってる🏎️ ([tsx][2])
* JS中心で、importされたコードだけ見ていればOK（Node標準 watch で足りる）🧊 ([Node.js][1])
* 変更同期や再ビルドも含めてDocker側で面倒見たい（Compose Watchへ）🧱 ([Docker Documentation][3])

---

## 7) ハンズオン：nodemonを“必要な分だけ”導入する🛠️😄

ここでは **「TSを `tsx` で実行しつつ、`.env` も監視したい」**という、よくある形で作ります✨
（`.env` の監視は nodemon の得意技！）([DigitalOcean][4])

## 手順①：インストール📦

```bash
npm i -D nodemon
```

## 手順②：`nodemon.json` を作る🧾

> “長いコマンド列”はファイルに逃がすのが正解🙆‍♂️ ([DigitalOcean][4])

```json
{
  "watch": ["src", ".env"],
  "ext": "ts,tsx,json,env",
  "ignore": ["node_modules/", "dist/", "**/*.test.ts"],
  "delay": 1,
  "exec": "tsx src/server.ts"
}
```

ポイント👇

* `.env` を watch に入れる（**環境変数の変更→再起動**ができる）([DigitalOcean][4])
* `ext` で監視拡張子を明示（デフォルト監視に入ってないことがある）([DigitalOcean][4])
* `delay` で連続保存のバタつきを抑える ([DigitalOcean][4])
* `ignore` をちゃんと書く（CPU暴騰の予防）([DigitalOcean][4])

## 手順③：`package.json` にスクリプトを追加🧩

```json
{
  "scripts": {
    "dev": "nodemon",
    "start": "node dist/server.js"
  }
}
```

これで **`npm run dev`** だけで動きます😊✨ ([DigitalOcean][4])

---

## 8) もし再起動しない時は？（Docker/Windowsあるある）😇💥

## 症状A：変更したのに再起動しない🙃

原因の上位はこのへん👇

* 監視対象の拡張子じゃない（`.env` とか）→ `ext` を追加 ([DigitalOcean][4])
* ignore に引っかかってる → `ignore` を見直す ([DigitalOcean][4])

## 症状B：エディタの“安全な保存”でイベントが飛ばない📝

エディタが **一旦別ファイルに書いてリネーム**する方式だと、監視がズレることがあります。
その時は **`-L`（legacy watch）**で回避できます（ポーリング監視）([DigitalOcean][4])

例👇

```bash
nodemon -L
```

ただし注意！
`-L` は **CPUが上がることがある**ので、常用は慎重に🔥 ([DigitalOcean][4])

👉 ここでのおすすめ判断：

* 小規模なら `-L` でOK😄
* 重くなるなら **Compose Watch（sync / sync+restart）**へ寄せるのが綺麗✨ ([Docker Documentation][3])

---

## 9) ミニ課題（15分で“判断できる人”になる）🎒✨

## 課題①：`.env` を変えたら再起動するようにする🌱

* `.env` を編集して保存
* ターミナルに再起動ログが出ればOK🙆‍♂️ ([DigitalOcean][4])

## 課題②：テスト編集で再起動しないようにする🧪

* `**/*.test.ts` を `ignore` に入れる
* テストを書きながらAPIが落ちないと最高👍 ([DigitalOcean][4])

## 課題③：二重再起動を止める⏱️

* `delay: 1` を試す
* 保存連打しても落ち着いてたら勝ち🏆 ([DigitalOcean][4])

---

## 10) AIで時短するプロンプト例🤖✨

そのままコピペでOKです😄（生成物は必ず目視チェック！）

* 「このプロジェクト構成（src/, dist/, .env）で、nodemon.json を最適化して。watch/ext/ignore/delay を理由付きで提案して」
* 「Docker上でファイル変更が拾えない時の対処を、nodemon（-L含む）とCompose Watch（sync/sync+restart）で比較して、最小の変更案を出して」([Docker Documentation][3])
* 「tsx watch と nodemon の使い分けを、監視対象（import外のファイル）観点で判断フローにして」([tsx][2])

---

## まとめ：この章の“持ち帰り”🎁😊

* まずは **tsx watch / Node watch** でシンプルに回す💨 ([tsx][2])
* **`.env` や設定ファイル、監視の細かい制御が欲しくなったら nodemon** 🧰 ([DigitalOcean][4])
* Windows＋Dockerで監視が怪しい時は、**Compose Watch** という選択肢が強い🧱 ([Docker Documentation][3])
* `-L` は最終手段（便利だけどCPU注意）🔥 ([DigitalOcean][4])

次の章（Compose Watch）に進むと、「保存したら勝手に反映」の世界が一気に完成します👀✨

[1]: https://nodejs.org/api/cli.html "Command-line API | Node.js v25.6.0 Documentation"
[2]: https://tsx.is/watch-mode "Watch mode | tsx"
[3]: https://docs.docker.com/compose/how-tos/file-watch/ "Use Compose Watch | Docker Docs"
[4]: https://www.digitalocean.com/community/tutorials/workflow-nodemon "How To Restart Your Node.js Apps Automatically with Nodemon | DigitalOcean"
