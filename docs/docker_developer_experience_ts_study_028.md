# 第28章：Compose操作もワンコマンドにまとめる🧱➡️🖱️

この章は「長い `docker compose ...` を暗記しない」で勝ちます😎✨
やることはシンプル👇

* ✅ **よく使うCompose操作（up/down/logs/exec/watch）を “短いコマンド入口” に集約**
* ✅ 迷わず回る「開発ループ」を作る（起動→ログ→中に入る→更新→終了）🔁🔥
* ✅ 事故りやすい操作（特に `down -v`）に“安全ガード”を付ける🧯💥

---

## 1) まず「よくやる5操作」だけを固定する🧠✨

あなたが毎日やるのって、だいたいこの5つです👇

1. 起動する ▶️（`up`）
2. 止める ⏹️（`down`）
3. ログを見る 👀（`logs -f`）
4. コンテナに入る 🐚（`exec`）
5. 保存したら反映（watch）⚡（`up --watch` / `watch`）

`docker compose up` は **ログを全部まとめて表示**して、コマンドが終わると **コンテナも止まる**（`--detach` なら裏で動き続ける）という性質があります。([Docker Documentation][1])
→ つまり「普段は detach で起動して、ログは別コマンドで見る」のがわかりやすいです😊

---

## 2) “短い入口” は npm scripts がいちばんラク🧰✨

Windowsでもそのまま通りやすいし、チームでも「同じコマンド名」を共有できます👍
ここでは `compose:*` で揃えます（好みで `dc:*` でもOK）🎮

## ✅ 例：`package.json` にこれを追加（最小セット）

```json
{
  "scripts": {
    "compose:up": "docker compose up --build -d",
    "compose:down": "docker compose down",
    "compose:logs": "docker compose logs -f --tail=200",
    "compose:ps": "docker compose ps",
    "compose:sh": "docker compose exec app sh",
    "compose:watch": "docker compose up --watch",
    "compose:watch:only": "docker compose watch --no-up",
    "compose:reset": "docker compose down -v --remove-orphans"
  }
}
```

## 使い方（覚えるのはこれだけ）😆✨

* 起動：`npm run compose:up` ▶️
* ログ：`npm run compose:logs` 👀
* 中に入る：`npm run compose:sh` 🐚
* 終了：`npm run compose:down` ⏹️
* watch：`npm run compose:watch` ⚡

> `docker compose down` は **upで作ったコンテナ/ネットワーク等を止めて消す**コマンドです。([Docker Documentation][2])
> ただし **ボリュームは基本残る**ので、DBデータは守られやすいです🛡️（ただし例外あり）

---

## 3) watch を「運用に統合」する（ここが第28章のキモ）🔥

## 3-1) watch は2つの起動スタイルがある👀

* **A: `docker compose up --watch`**
  → アプリログも、watchのログも混ざる（でも1コマンドで済む）([Docker Documentation][1])
* **B: `docker compose watch`**
  → “watch専用表示”にできて見やすい（`--no-up` で「起動済み前提」にもできる）([Docker Documentation][3])

上の scripts では両方用意しました✌️

* `compose:watch` → 1発で全部
* `compose:watch:only` → すでに起動してる前提で監視だけ

## 3-2) `compose.yaml` 側に watch ルールを書く📝✨

Compose Watchは **Compose 2.22.0以降**が前提で、`develop: watch:` にルールを書きます。([Docker Documentation][4])
例（サービス名 `app` の例）👇

```yaml
services:
  app:
    build: .
    command: npm run dev
    develop:
      watch:
        - action: sync
          path: ./src
          target: /app/src
          ignore:
            - node_modules/
        - action: rebuild
          path: package.json
```

ポイント💡

* `sync`：ファイルをコンテナに同期（ホットリロード系に相性◎）([Docker Documentation][4])
* `rebuild`：依存関係が変わる（例：`package.json`）ときに再ビルドする流れが自然👌([Docker Documentation][4])
* `node_modules/` は同期しないのが安全＆速い（ネイティブ依存が混じることがある）([Docker Documentation][4])
* パスは基本プロジェクト相対、`.dockerignore` が効く、globは非対応などルールがあるよ📌([Docker Documentation][4])

---

## 4) “事故る操作” に名前でブレーキをかける🧯💥

## `compose:down` と `compose:reset` は別物にする（超重要）⚠️

* `docker compose down`：基本は **コンテナ/ネットワーク等を消す**（データは残りやすい）([Docker Documentation][2])
* `docker compose down -v`：**named volume も消す** → DBデータが消えることがある💀([Docker Documentation][2])

だから scripts では👇

* `compose:down`：日常用
* `compose:reset`：**「全部消してやり直す」用**（名前からして怖い）😇

---

## 5) 「中に入る」「1回だけ実行」もワンコマンド化する🐚🧪

## 5-1) コンテナに入る：`exec`

`docker compose exec` は **サービスのコンテナ内でコマンド実行**できて、TTYもデフォルトで割り当てられます。([Docker Documentation][5])
→ だから `compose:sh` を作ると便利😊

## 5-2) 1回だけコマンド：`run`

マイグレーションとか「1回だけ」やりたい時に便利✨
ただし `docker compose run` は **サービス定義のポートを作らない**（衝突回避のため）ので、必要なら `--service-ports` を使います。([docs.docker.jp][6])

例👇

```bash
npm run compose:run:migrate
```

…みたいに、必要に応じて scripts を追加していく感じです🧩

---

## 6) よくある詰まりポイント集（先に潰す）🪓😅

## 詰まり1：watchが効かない😵

Compose Watchは **ローカルのソースから `build` するサービス向け**で、`image:` だけのサービスの変更追跡は基本しません。([Docker Documentation][4])
→ 監視したいのはだいたいアプリ側なので、そこだけ watch を入れるのが正解🙆

## 詰まり2：ログがカオス🤯

* `up` はログもまとめて出す（便利だけど混ざる）([Docker Documentation][1])
* 混ざるのがイヤなら **`docker compose watch` を使う**（専用ログで見やすい）([Docker Documentation][4])

## 詰まり3：Docker Desktopが重い/ディスクが…🥲

WSL2エンジン利用時の保存先や、WSL側の設定で体感が変わることがあります（Docker DesktopのWSL2案内に詳細あり）。([Docker Documentation][7])

---

## 7) ミニ課題（15〜30分）🧩🕒

## 課題A：コマンド入口を完成させる🎯

* `compose:up / down / logs / sh / ps` を追加
* `npm run compose:up` → `npm run compose:logs` の流れで動作確認👀

## 課題B：watch を統合する⚡

* `compose.yaml` に `develop: watch:` を追加
* `npm run compose:watch` で保存→反映を体感✨([Docker Documentation][4])

## 課題C：安全なリセット導線を作る🧯

* `compose:reset` を作る（中身は `down -v --remove-orphans`）
* READMEに「これはデータ消える可能性あり⚠️」を1行だけ書く（未来の自分を救う）🙏

---

## 8) AIで時短するなら（でも最後は人間の目でチェック👀）🤖✨

## Copilot / Codex に投げると速いプロンプト例💬

* 「package.json の scripts に、docker compose の up/down/logs/exec/watch/reset を追加して。サービス名は app。Windowsでも通る書き方で」
* 「compose.yaml に develop.watch を追加して。src は sync、package.json は rebuild、node_modules は ignore」

AIが出したものは👇だけ必ず目視チェック✅

* `down -v` が日常コマンドに混ざってないか💀
* サービス名（`app` など）が合ってるか🔍
* `watch` の `path/target` がズレてないか📁

---

次の章（第29章）で、この“短い入口”に **コミット前フック（軽めの自動チェック）** をつなげると、さらに「うっかり事故」が減って気持ちよくなります🪝✨

[1]: https://docs.docker.com/reference/cli/docker/compose/up/ "docker compose up | Docker Docs"
[2]: https://docs.docker.com/reference/cli/docker/compose/down/ "docker compose down | Docker Docs"
[3]: https://docs.docker.com/reference/cli/docker/compose/watch/ "docker compose watch | Docker Docs"
[4]: https://docs.docker.com/compose/how-tos/file-watch/ "Use Compose Watch | Docker Docs"
[5]: https://docs.docker.com/reference/cli/docker/compose/exec/?utm_source=chatgpt.com "docker compose exec"
[6]: https://docs.docker.jp/engine/reference/commandline/compose_run.html?utm_source=chatgpt.com "docker compose run — Docker-docs-ja 24.0 ドキュメント"
[7]: https://docs.docker.com/desktop/features/wsl/ "WSL | Docker Docs"
