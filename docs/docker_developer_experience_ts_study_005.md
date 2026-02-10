# 第05章：ワンコマンド起動の入口：Compose運用の型🧷🚀

この章で作るのは、**「迷ったらこれ」だけ覚えればOK**な運用セットです😎✨
開発って、技術そのものより「起動の儀式」で心が折れがちなので、先にそこを消します🧹💥

---

## 5.1 まずゴール：開発者の“5つのボタン”を作る🎮✨

最低限これだけあれば、だいたい勝ちです🏆

1. **起動** ▶️（up）
2. **停止** ⏹️（stop）
3. **片付け** 🧹（down）
4. **ログ見る** 👀（logs）
5. **中に入る** 🐚（exec）

この5つを「1コマンドで押せる」ようにします😊

---

## 5.2 “プロジェクト名”を固定して迷子を防ぐ🏷️🧭

Compose は、何もしないと **フォルダ名**からプロジェクト名（= コンテナ名やネットワーク名の接頭辞）を作ります。つまり、フォルダ名を変えた瞬間に「別物」扱いになって混乱しやすいんですね😵‍💫
なので、**compose.yaml に `name:` を置いて固定**します✅
`name` は Compose 仕様として定義されていて、プロジェクト名になります。([Docker Documentation][1])

例：

```yaml
name: dx-app
services:
  api:
    # ...
```

これで「コンテナ名が毎回違う…」みたいな事故が減ります🙌
（プロジェクト名の決まり方・上書き方法も公式にまとまってます）([Docker Documentation][2])

---

## 5.3 “覚えるのはこれだけ”コマンドセット📌✨

ここから先、**全部 `docker compose`（スペースあり）**で統一します👌
（旧 `docker-compose` じゃなくて、今の標準はこっちです）

## ✅ 起動：`docker compose up`

* コンテナを（再）作成して起動します
* `-d` を付けるとバックグラウンド起動になります

```bash
docker compose up -d --build
```

`up` はサービスを作って起動して、必要なら依存サービスも起動します。([Docker Documentation][3])

---

## ✅ 停止だけ：`docker compose stop`（消さない⏸️）

「とりあえず止める」用です。**再開しやすい**👍

```bash
docker compose stop
```

`stop` は **停止だけ**で、コンテナは残ります。([Docker Documentation][4])

---

## ✅ 片付け：`docker compose down`（消す🧹）

「一回全部しまう」用です。コンテナやネットワークなどを消します。

```bash
docker compose down
```

`down` は `up` で作られたコンテナ/ネットワーク等を止めて削除します。([Docker Documentation][5])

⚠️ さらに完全初期化したい時だけ（DBなどのデータも消える可能性あり）：

```bash
docker compose down -v
```

---

## ✅ ログ：`docker compose logs`

「動いてる？」「落ちてる？」はログが一番早いです👀

```bash
docker compose logs -f --tail=100
```

`--follow`（追従）や `--tail`（末尾だけ）などのオプションがあります。([Docker Documentation][6])

---

## ✅ 中に入る：`docker compose exec`

コンテナ内でコマンド叩くやつです🐚
（`docker exec` の Compose 版）

```bash
docker compose exec api sh
```

`exec` はサービス（例：api）に対してコマンドを実行できます。TTY も基本有効です。([Docker Documentation][7])

---

## ✅ 状態確認：`docker compose ps`

「起動してる？」を一瞬で見るやつ👓

```bash
docker compose ps
```

`ps` は Compose プロジェクトのコンテナ状態を一覧できます。([Docker Documentation][8])

---

## 5.4 compose.yaml に“運用しやすい形”を入れておく🧩✨

ここでは「運用で迷わない」ための最低限だけ入れます👍
（ホットリロードやWatchは後の章で！🔥）

例（超ベース）：

```yaml
name: dx-app

services:
  api:
    build:
      context: .
      dockerfile: ./docker/api/Dockerfile
    ports:
      - "3000:3000"
```

* `name:` でプロジェクト名固定🏷️ ([Docker Documentation][1])
* サービス名は短く・意味が明確に（api, db, redis…）👶✨

---

## 5.5 “ワンコマンド化”の実装：Windowsなら PowerShell が最強🪄🪟

「コマンド覚えなくていい」を本当に実現するには、**入口を1つにする**のがいちばんです🙌
Windows なら PowerShell でOK！

## ✅ `dev.ps1` を作る（プロジェクト直下）📄

```powershell
param(
  [ValidateSet("up","down","stop","start","logs","ps","sh","reset")]
  [string]$cmd = "up"
)

switch ($cmd) {
  "up"    { docker compose up -d --build }
  "down"  { docker compose down }
  "stop"  { docker compose stop }
  "start" { docker compose start }
  "logs"  { docker compose logs -f --tail=100 }
  "ps"    { docker compose ps }
  "sh"    { docker compose exec api sh }
  "reset" { docker compose down -v }
}
```

## ✅ 使い方（覚えるのはこれだけ）🎯

```powershell
.\dev.ps1 up
.\dev.ps1 logs
.\dev.ps1 sh
.\dev.ps1 down
```

もう「えっと、logs のオプションなんだっけ…」が消えます😆🎉

---

## 5.6 ミニ課題（10分）🧪✨

## 課題1：起動して状態確認しよう▶️👀

1. `.\dev.ps1 up`
2. `.\dev.ps1 ps`

成功したら、**“起動できる状態”**はクリアです🎊

## 課題2：ログ追従して「動いてる感」を掴む👀📈

* `.\dev.ps1 logs`

## 課題3：中に入ってバージョン確認🐚

* `.\dev.ps1 sh`
  入れたら：

```sh
node -v
npm -v
```

（ここで「コンテナの中で動いてる」実感が持てます😊）

---

## 5.7 よくある詰まりポイント集（先回り）🧯💡

## 😵「ポートが使われてる」(例: 3000)

* まず `.\dev.ps1 ps` で自分の Compose が掴んでるか確認👀
* それでもダメなら、別プロセスが使ってることが多いです。

PowerShell で確認：

```powershell
netstat -ano | findstr :3000
```

---

## 😇 `down -v` でデータ消えた

* `reset` は“最終兵器”です💣
* DB を後で入れたら、**リセット＝データ削除**になりがち。
  なので通常は `stop` / `down` を使い分けましょう✅
  `stop` は消さない、`down` は消す。公式の説明もここが本質です。([Docker Documentation][4])

---

## 🐢 Windows のファイル共有が遅い気がする

Docker Desktop は WSL2 を使う構成が主流で、Linux ワークスペースを活用できるよ、という説明があります。([Docker Documentation][9])
体感が重いときは「どこにプロジェクトを置くか」で改善することが多いです🛠️✨（このへんは後の章でも触れます）

ちなみに WSL2 は Microsoft の仕組みなので、WindowsとLinuxの境界で挙動が変わることがある…ってだけ覚えておけばOKです🙂

---

## 5.8 AIで時短するコツ🤖✨（ただし“丸のみ禁止”）

AI拡張に投げると速いのはここ👇

## ✅ その1：`dev.ps1` を自分用に増改築

プロンプト例：

* 「`dev.ps1` に `restart` と `build` も追加して。`api` 以外のサービス名でも使えるように引数で service 名を受けたい」

👉 出てきた差分を見て、危ないコマンド（`down -v` とか）が混ざってないかチェック😎

## ✅ その2：README の“3行”を自動生成

* 「このプロジェクトの起動/ログ/停止だけを説明する README の冒頭セクションを書いて」

README の先頭に **“迷ったらここ”**があるだけで、新しい未来が始まります🌈✨

---

次の章（第6章）で、ホットリロードの選択肢マップ🗺️に入っていきます🔥
その前に、もし今の `compose.yaml` が「第4章の最小プロジェクト」と少しズレてそうなら、**今ある構成を前提に“第5章版 dev.ps1/compose.yaml”に合わせて整形**した形も書けますよ😊

[1]: https://docs.docker.com/reference/compose-file/version-and-name/?utm_source=chatgpt.com "Version and name top-level elements"
[2]: https://docs.docker.com/compose/how-tos/project-name/?utm_source=chatgpt.com "Specify a project name"
[3]: https://docs.docker.com/reference/cli/docker/compose/up/?utm_source=chatgpt.com "docker compose up"
[4]: https://docs.docker.com/reference/cli/docker/compose/stop/?utm_source=chatgpt.com "docker compose stop"
[5]: https://docs.docker.com/reference/cli/docker/compose/down/?utm_source=chatgpt.com "docker compose down"
[6]: https://docs.docker.com/reference/cli/docker/compose/logs/?utm_source=chatgpt.com "docker compose logs"
[7]: https://docs.docker.com/reference/cli/docker/compose/exec/?utm_source=chatgpt.com "docker compose exec"
[8]: https://docs.docker.com/reference/cli/docker/compose/ps/?utm_source=chatgpt.com "docker compose ps"
[9]: https://docs.docker.com/desktop/features/wsl/?utm_source=chatgpt.com "Docker Desktop WSL 2 backend on Windows"
