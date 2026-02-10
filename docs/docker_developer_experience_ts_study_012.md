# 第12章：VS Codeデバッグ（ブレークポイント）を通す🧲🚦

> ログだけじゃなく「止めて中を見る」デバッグを、コンテナ内のNodeに“ちゃんと”通します💪✨

---

## 1) まずイメージを掴む🧠💡

コンテナ内のNodeをデバッグする時は、ざっくりこうです👇

* Nodeを **Inspectorモード** で起動する（`--inspect` / `--inspect-brk`）
  すると **デバッグ用のポート（既定 9229）** で待ち受けます。既定では `127.0.0.1:9229` です。([Node.js][1])
* そのInspectorポートへ、エディタのデバッガ（VS Code）が接続する🔌
* **ローカルのソース** と **コンテナ内のソース** を “対応付け” できると、ブレークポイントが効く🎯

ここで超重要ポイント👇
コンテナ内で `--inspect` を既定のまま使うと、Inspectorが **コンテナ内の127.0.0.1** にしか開かず、外（ホスト）から繋げません。なので **Docker向けには 0.0.0.0 で待ち受け** にします。([Node.js][1])

---

## 2) Composeで「デバッグ用ポート」を開ける🧷🧱

まず `compose.yaml`（または `docker-compose.yml`）のAPIサービスに、Inspector用ポートを追加します👇

* 9229をホストへ公開（でも **localhost限定** にして安全寄りにする🔒）

```yaml
services:
  api:
    ports:
      - "3000:3000"
      - "127.0.0.1:9229:9229"
```

`127.0.0.1:...` のように **ホストIPを指定してポート公開できる** のがCompose仕様です。([docs.docker.jp][2])

> 🔥ここ大事：Inspectorを `0.0.0.0` にバインドして公開すると危険になり得る、という注意がNode公式にもあります。だから “公開範囲をlocalhostに絞る” のが安心設計です。([Node.js][1])

---

## 3) Nodeを「Inspector付き」で起動する🐛⚡

やり方は2パターン用意しておくとラクです（どっちでもOK）👇

---

### パターンA：まずは王道 `--inspect`（いつでも接続できる）🔌🙂

アプリ起動コマンドに `--inspect=0.0.0.0:9229` を足します。

例：`package.json` の `scripts` をこんな感じに（例です）👇

```json
{
  "scripts": {
    "dev": "node --watch ./dist/index.js",
    "dev:debug": "node --inspect=0.0.0.0:9229 --watch ./dist/index.js"
  }
}
```

* `--inspect` を付けるとInspectorが起動します（既定は `127.0.0.1:9229`）([Node.js][1])
* Dockerでは外から繋ぐため `0.0.0.0` にするのが定石（ただし公開範囲は絞る！）([Node.js][1])

> 📝 もしTSを直接実行していて、ソースマップ周りで詰まるなら「いったんdistをデバッグ」すると最短で成功します😺
> （ブレークポイントが“刺さる体験”を先に作るのが勝ち✨）

---

### パターンB：`tsx` を使ってるなら `--inspect-brk`（最初で止まる）🧊🛑

`tsx` 公式も、VS Codeでのデバッグに `--inspect-brk` を案内してます👇([tsx][3])

```sh
tsx --inspect-brk ./src/index.ts
```

* `--inspect-brk` は **起動直後に止まる** ので「起動時に一瞬で通り過ぎる処理」を追うのに最強です🕵️‍♂️✨([Node.js][1])

> 💡 コンテナ内で実行するなら、`--inspect-brk=0.0.0.0:9229` みたいに **hostも指定** するのが安全です（外から繋ぐため）🔌

---

## 4) VS Codeの `launch.json`（Attach）を書く🧲🧩

次に `.vscode/launch.json` を作って、**実行中のNodeへ接続（attach）** します。

最小のおすすめ👇（TypeScriptでもJSでもまず動くやつ）

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to Node in Docker",
      "type": "pwa-node",
      "request": "attach",
      "address": "localhost",
      "port": 9229,
      "restart": true,
      "localRoot": "${workspaceFolder}",
      "remoteRoot": "/app",
      "skipFiles": ["<node_internals>/**"]
    }
  ]
}
```

* `localRoot` / `remoteRoot` は「ローカルとリモートの対応付け」で、VS Code公式でも重要項目として説明されています。([Visual Studio Code][4])
* `skipFiles` はNode内部をすっ飛ばして、自分のコードに集中するための定番です🧹([Visual Studio Code][4])

> 🧠 `remoteRoot` は **コンテナ内の作業ディレクトリ** に合わせてね！
> 例：DockerfileやComposeで `/app` にしてるなら `/app`。`/usr/src/app` ならそれ。

---

## 5) 実際にブレークポイントを当てる手順🎯🚀

1. `docker compose up`（デバッグ用の起動コマンドにする）🐳

   * 例：Composeの `command:` を `npm run dev:debug` にすると固定化できてラク🙂
2. VS Codeの「実行とデバッグ」▶️ で `Attach to Node in Docker` を選んで ▶ を押す（F5）⌨️
3. ルートやハンドラにブレークポイントを置く📍
4. ブラウザ or `curl` で該当APIを叩く🌐
5. 止まったら勝ち！🥳

   * 変数を見る（Variables）👀
   * 1行ずつ進む（Step Over / Into）👣
   * Debug Consoleで式を評価する🧪

---

## 6) ありがち詰まりポイント集（ここが9割）😇🧯

### ① 接続できない（タイムアウト）⌛

原因の定番👇

* Nodeを `--inspect` で起動してない
* Inspectorが `127.0.0.1` で待ってて、外から繋げない（コンテナあるある）
* Composeで `9229` を `ports` してない

対策👇

* コンテナ内：`--inspect=0.0.0.0:9229` にする([Node.js][1])
* Compose：`127.0.0.1:9229:9229` で公開（localhost限定）([docs.docker.jp][2])

---

### ② ブレークポイントが灰色（Unbound）👻

原因あるある👇

* `remoteRoot` が違う（コンテナのパスと一致してない）
* TSのソースマップが合ってない（distの配置・sourceMap設定など）
* そもそも「止めたいコード」が実行されてない😅

対策👇

* まず `remoteRoot` を **実際のコンテナパスに合わせる**（最優先）([Visual Studio Code][4])
* “一旦distをデバッグ” に逃げて成功体験を作る🏃‍♂️💨
* どうしてもTS直デバッグしたいなら `tsx --inspect-brk` で「最初で止める」([tsx][3])

---

### ③ デバッグポートを外へ開けるの怖い😱🔒

その感覚は正しいです🙆‍♂️
Node公式も「公開IPや0.0.0.0へのバインドは危険になり得る」と注意しています。([Node.js][1])

なのでこの章のおすすめは👇

* コンテナ内：`0.0.0.0`（外から接続できるように）
* ホスト側公開：`127.0.0.1:9229:9229`（LANや外部に出さない）([docs.docker.jp][2])

---

## 7) “もっとラクする”ルート（Docker拡張で自動生成）🧰✨

VS CodeのContainer Toolsは、コンテナ向けのデバッグ設定を **`launch.json` と連携して支援** してくれます。([Visual Studio Code][5])
ただ、プロジェクトの構成が多様すぎて自動生成だけでは合わないこともあるので、まずはこの章の **Attach構成を手で作れる** のが強いです💪😺

---

## 8) ミニ課題（15分）🧩⏱️

**課題A：変数を覗く👀**

* どこかのハンドラで `req` / `params` / `body` を覗く
* Debug Consoleで `JSON.stringify(...)` して確認してみる🧪

**課題B：条件付きブレークポイント🎯**

* 「特定のidの時だけ止める」みたいに条件を付ける
  例：`id === "42"` の時だけ止める✨

**課題C：Logpoint（止めずにログだけ）🪵**

* ブレークポイントを “止めないログ” にして、負荷を減らしつつ追跡する
* 「ログ地獄」になりにくいので超おすすめ🙂

---

## 9) AI拡張の使いどころ（速く・安全に）🤖✨

GitHub Copilot や OpenAI Codex 系が使える前提なら、こう使うと時短です👇

* 「今のcompose.yamlとDockerfileを貼る → `remoteRoot` どれが正しい？」って聞く🧠
* 「ブレークポイントがUnbound。`launch.json` の改善案を3つ」って出させる🧰
* **提案は丸呑みしない**：差分を見て、`remoteRoot` と `ports` と `--inspect` だけは自分で最終確認✅

---

## 10) 1分チェックリスト✅🧷

* [ ] Composeで `127.0.0.1:9229:9229` を公開してる？([docs.docker.jp][2])
* [ ] Nodeは `--inspect=0.0.0.0:9229`（または `--inspect-brk`）で起動してる？([Node.js][1])
* [ ] `launch.json` の `remoteRoot` はコンテナ内の実パス？([Visual Studio Code][4])
* [ ] ブレークポイントを置いたコード、実際に通ってる？😅

---

次の章（テスト編🧪）に行く前に、ここで「止めて見る」ができるようになると、以降の学習スピードが一気に上がるよ🚀✨
もし、あなたの現在の `compose.yaml` / 起動コマンド（dev）/ コンテナ内の作業ディレクトリ（例：`/app`）が分かれば、それに合わせた `launch.json` を“ぴったり版”にして提示するね😺🧲

（ちなみにVS Codeは Microsoft 製なので、公式ドキュメントの通りにやるのが一番近道です🧭）

[1]: https://nodejs.org/en/learn/getting-started/debugging "Node.js — Debugging Node.js"
[2]: https://docs.docker.jp/compose/compose-file/ "Compose Specification（仕様） — Docker-docs-ja 24.0 ドキュメント"
[3]: https://tsx.is/vscode "VS Code debugging | tsx"
[4]: https://code.visualstudio.com/docs/nodejs/nodejs-debugging "Node.js debugging in VS Code"
[5]: https://code.visualstudio.com/docs/containers/debug-common "Debug containerized apps"
