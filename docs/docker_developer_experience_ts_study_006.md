# 第06章：ホットリロードの選択肢マップ🗺️🔥

この章は「ホットリロード、結局どれを選べばいいの？🤔」を最短で解決する回だよ✨
ここで“地図🗺️”を持っておくと、第7章以降（実装編）が一気にラクになる👍

---

## 1) そもそも「ホットリロード」って何？🧠💡

Node系の開発で言うホットリロードは、だいたい次の2種類に分かれるよ👇

* **A：プロセス再起動型**（保存したらサーバーを再起動🔁）
  例：Nodeの`--watch`、`nodemon`、`tsx watch` など
  → APIサーバー開発ではこれが主流✨ ([Node.js][1])

* **B：HMR型**（ブラウザ側が差分更新🧩）
  例：Vite/webpack等（フロント寄り）
  → 今回の章は **“コンテナ内のNode/TSが即反映される仕組み”** が主役だよ😊
  （Docker Compose Watchの例にもHMRが出てくる） ([Docker Documentation][2])

---

## 2) 方式A/B/C：ホットリロード3兄弟👪🔥

この教材アウトラインの第6章で出てきた3つを、まずは“違いが一瞬で分かる形”にするよ👇

## 方式A：**マウント + アプリ側watch** 📂👀（王道）

**イメージ**：ソースはPC側で編集 → コンテナにそのまま見せる（マウント）→ Node側が監視して再起動🔁

* 👍 最初に試すならだいたいコレ
* 👍 Composeの設定がシンプルになりがち
* ⚠️ Windowsだと置き場所次第で「遅い/監視が不安定」になりやすい（後で対策するやつ）💣

---

## 方式B：**Compose Watch（同期/再ビルド）** 🔄🧰（“Windowsでも気持ちいい”寄り）

**イメージ**：ファイルを“マウントで共有”じゃなくて、**ルールに従ってコンテナへ同期**する📦✨
変更内容に応じて **sync / sync+restart / rebuild** を使い分けるのが強い💪

* 👍 **node_modulesを同期しない**とか、粒度を細かくできる（速い＆事故りにくい） ([Docker Documentation][2])
* 👍 `package.json`変更時だけrebuild、普段はsync…みたいに賢くできる🧠 ([Docker Documentation][2])
* ⚠️ Docker Compose **2.22.0以降**が必要だよ（古いと使えない） ([Docker Documentation][2])

---

## 方式C：**そもそもビルド不要（軽い構成）** 🪶⚡

**イメージ**：TypeScriptの“開発中だけ”は、**TSをそのまま実行してwatch**して回転数を上げる🚀
代表が **`tsx watch`**（人気者）✨

* 👍 `tsx watch` は依存ファイルも追いかけて再実行してくれる（便利） ([tsx][3])
* 👍 設定少なめで気持ちよく回りやすい😊
* ⚠️ 本番は別（開発専用の走り方、と割り切るのがコツ）🧊

---

## 3) じゃあどれを選ぶ？ “3分で決める”選択チャート⏱️🗺️

迷ったらこの順でOK👇（まずは勝ち筋から入る✨）

## ✅ まずは方式Aを試す（最短で体験）🏁

* 「保存→反映」をすぐ体験したい😊
* 設定を増やしたくない🙅‍♂️
  → **方式A**

## ✅ Windowsでファイルが多い/重い/監視が怪しいなら方式Bへ🛠️

* 反映が遅い🐢
* 監視がたまに効かない😇
* node_modulesが絡むと地獄を見る予感しかしない🔥
  → **方式B（Compose Watch）** が刺さりやすい ([Docker Documentation][2])

## ✅ TypeScriptの待ち時間がイヤなら方式Cを検討⚡

* `tsc`→`node`の二段構えで待ちたくない😵
* 開発中はとにかく回転数を上げたい🚀
  → **方式C（tsx watch）** が超ラク ([tsx][3])

---

## 4) “方式ごとの最小サンプル”を先に見て安心する👀✨

ここでは「こんな感じになるんだ〜」を掴めればOK！（第7章以降でガッツリやるよ💪）

## 方式A：マウント + watch（例）

* Compose：`.:/app` みたいにソースをマウント📂
* 実行：Nodeの`--watch`、または`nodemon` / `tsx watch` を使う

Nodeの`--watch`は「監視して変更があったら再起動」っていう公式の挙動だよ🔁 ([Node.js][1])

```yaml
services:
  api:
    build: .
    volumes:
      - .:/app
    working_dir: /app
    command: npm run dev
```

```json
{
  "scripts": {
    "dev": "node --watch dist/index.js"
  }
}
```

`--watch`の説明はNode公式CLIに載ってるよ（変更でプロセス再起動） ([Node.js][1])

> ⚠️ ちなみに `--watch-path` は **macOS/Windows限定** って注意点がある（コンテナ内Linuxだと使えない）ので、ここはハマりやすいポイント！ ([Node.js][1])

---

## 方式B：Compose Watch（例）

「普段はsync、依存関係が変わったらrebuild」みたいに賢く動かせる🧠✨ ([Docker Documentation][2])

```yaml
services:
  api:
    build: .
    command: npm run dev
    develop:
      watch:
        - action: sync
          path: .
          target: /app
          ignore:
            - node_modules/
        - action: rebuild
          path: package.json
```

起動はこんな感じ👇

```bash
docker compose up --watch
```

Docker公式にも「Watchはbind mountの代替じゃなくて“開発用の相棒”」って立ち位置で説明されてるよ🧩 ([Docker Documentation][2])

---

## 方式C：tsx watch（例）

`tsx watch` は「依存が変わったら自動で再実行」っていうノリで使える✨ ([tsx][3])

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts"
  }
}
```

tsx側のwatchは `--include` / `--exclude` も用意されてて、育てやすいよ🌱 ([tsx][3])

---

## 5) Windowsあるある詰まりポイント（先に知って勝つ）🏆🧯

## ① 「コンテナで変更検知しない」😇

マウント越し（特に“ネットワークっぽい扱い”になる環境）だと監視が効きづらいことがある💥
その場合は、`nodemon` の **`--legacy-watch`（`-L`）** が“最後の手段”として公式に案内されてるよ🛟
（ただしポーリングなので重くなりがち⚠️） ([GitHub][4])

## ② 「node_modulesを共有して爆発」💣

Docker公式も、Nodeプロジェクトで **node_modulesのsyncは非推奨** 寄りの説明をしてるよ（ネイティブ依存やマルチOS問題）🧨 ([Docker Documentation][2])
→ だから方式B（Compose Watch）で `ignore: node_modules/` が強い🔥

## ③ Docker Desktop/WSL周りの基本だけ押さえる🐳🪟

Docker DesktopのWSL2バックエンドは公式に“開発体験が良くなる”方向で整理されてる（起動や共有、リソース面など） ([Docker Documentation][5])
そして `wsl.exe -l -v` でWSLの状態を確認する導線も書かれてるよ🔎 ([Docker Documentation][5])

---

## 6) ミニ課題（第7章へ繋ぐ準備）📝✨

やることは“選ぶだけ”でOK！🥳（実装は次章で一気にやる）

1. 自分のプロジェクトに対して、方式A/B/Cをそれぞれ **「採用する/しない」** で丸を付ける✅
2. 採用候補を **1つに絞る**（迷ったらA → ダメならB → TS待ちがつらいならC）🗺️
3. 「ハマりそうポイント」を1個だけメモ🗒️

   * 例：監視が効かないかも → `nodemon -L` を覚えとく、みたいに🛟 ([GitHub][4])

---

## 7) AIで時短するプロンプト例🤖✨（コピペOK）

## ✅ 方式A（マウント + watch）を作らせる

「Composeとscriptsを最小にして」って頼むのがコツ💡

```text
Docker ComposeでNode/TypeScriptの開発用環境を作りたいです。
- ソースはマウント
- コンテナ内でホットリロード（プロセス再起動）
- node_modulesはホストと共有しない方針
compose.yamlとpackage.jsonのscripts案を出して。差分が少ない案で。
```

## ✅ 方式B（Compose Watch）を作らせる

watchルール（sync/rebuild）まで言語化すると強い🧠

```text
Docker Compose Watchを使って開発体験を良くしたいです。
- 通常は sync
- package.json が変わったら rebuild
- node_modules は同期しない
compose.yamlのdevelop.watch設定を提案して。理由も短く。
```

## ✅ 方式C（tsx watch）を作らせる

`tsx watch`で回すscriptsを出させる🚀

```text
TypeScriptを開発中だけは tsx watch で動かしたい。
package.json scriptsの dev/test/lint に馴染む形でdevだけ提案して。
```

---

## 次の章でやること（予告）🎬✨

第7章では、ここで選んだ方式を**“ちゃんと動く形”に固定**していくよ🔥
「保存→反映」が気持ちよく回り始めるのはここからだね😆💪

[1]: https://nodejs.org/api/cli.html "Command-line API | Node.js v25.6.0 Documentation"
[2]: https://docs.docker.com/compose/how-tos/file-watch/ "Use Compose Watch | Docker Docs"
[3]: https://tsx.is/watch-mode "Watch mode | tsx"
[4]: https://github.com/remy/nodemon "GitHub - remy/nodemon: Monitor for any changes in your node.js application and automatically restart the server - perfect for development"
[5]: https://docs.docker.com/desktop/features/wsl/ "WSL | Docker Docs"
