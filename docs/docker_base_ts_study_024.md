# 第24章：コンテナ内のlocalhost罠（自分自身を指す）🪤😵‍💫

この章は **「え、localhostってホストPCのことじゃないの！？」** を卒業する回です💪✨
ここを突破すると、Dockerのネットワークが急にラクになります🎉

---

## この章でできるようになること✅😄

* **コンテナ内の `localhost` が “自分自身(そのコンテナ)” を指す** と説明できる🧠
* 「どこで動いてるプロセスに繋ぎたい？」を整理して、接続先を選べる🎯
* **ホストPCに繋ぐ** ときの定番 `host.docker.internal` を使える🌐✨（Docker Desktop向け）

---

## まず結論：`localhost` は「今いる場所」🏠🔁

Dockerのコンテナは、ざっくり言うと **別の小さなPC** みたいなものです💻📦
だからコンテナの中で `localhost` と言ったら…

> **そのコンテナ自身の中**（自分のループバック）を指します😇

そして Docker Desktop は、Docker Engine を **軽量なLinux VMの中で動かす** 仕組みです（Windowsでも同じ考え方になります）🐧🧊 ([Docker Documentation][1])

---

## 「3つのlocalhost」が混乱の正体🌀😵

| あなたがいる場所         | `localhost` が指すもの | 例                                    |
| ---------------- | ----------------- | ------------------------------------ |
| Windows（ホストPC）🪟 | ホストPC自身           | ブラウザで `http://localhost:3000`        |
| コンテナA📦          | コンテナA自身           | コンテナA内で `curl http://localhost:3000` |
| コンテナB📦          | コンテナB自身           | コンテナB内で `curl http://localhost:3000` |

つまり…
**「コンテナ内で localhost にアクセスしたら、同じコンテナに当たる」** これが罠です🪤😵‍💫

---

## Docker DesktopでホストPCに繋ぐときの合言葉🪄✨

Docker Desktop では、コンテナからホストPC上のサービスに繋ぐために **特別なDNS名** が用意されています👇

* `host.docker.internal`：ホストPCの内部IPに解決される（ホスト上サービスに接続用）
* `gateway.docker.internal`：Docker VMのゲートウェイに解決される

([Docker Documentation][2])

---

## ハンズオン🔥：罠をわざと踏んで、正しく直す🧪🐳

## ① ホストPC側で “仮のサーバ” を起動する🪟▶️

PowerShell（またはVS Codeのターミナル）でこれを実行👇

```powershell
node -e "require('http').createServer((req,res)=>{res.end('HELLO from HOST');}).listen(8000); console.log('http://localhost:8000');"
```

ブラウザで `http://localhost:8000` を開いて **HELLO from HOST** が出たらOK🎉

---

## ② コンテナから `localhost:8000` にアクセスしてみる（失敗する）😇💥

別ターミナルで👇（curl入りの軽いイメージを使います）

```powershell
docker run --rm curlimages/curl:latest http://localhost:8000
```

だいたい **繋がらない** はずです（Connection refused など）💥
なぜなら…

> コンテナ内の `localhost:8000` は **コンテナ自身の8000番** を見にいくから🪤😵‍💫

---

## ③ 正解：`host.docker.internal:8000` にアクセスする（成功する）✅✨

```powershell
docker run --rm curlimages/curl:latest http://host.docker.internal:8000
```

今度は **HELLO from HOST** が返ってきたら勝ち🏆✨
これで「localhost罠」を完全に体感できました🙌😆

---

## Todo API題材で「やらかし例」を理解する😂📦

たとえば Todo API（コンテナ内）が、外部サービスにHTTPで繋ぐ設定があるとします👇

* 間違い例：`TODO_WORKER_URL=http://localhost:8000`

  * コンテナ内のlocalhostなので **ホストの8000には行けない**🪤
* 正しい例：`TODO_WORKER_URL=http://host.docker.internal:8000`

  * ホスト側の8000に繋がる🌟 ([Docker Documentation][2])

---

## Composeでの “次章へのチラ見せ” 👀✨

Composeを使うと、デフォルトで **同じネットワーク** が作られて、**サービス名で名前解決** できます📛🌐
なので「別コンテナに繋ぎたい」のに `localhost` を使うのはNGになりがちです🙅‍♂️

> Composeのネットワークでは、サービスは **サービス名で到達できる**（例：`db`） ([Docker Documentation][3])

（ここは次の第25章でガッツリやります💪😄）

---

## よくある症状→原因の当たりをつける表🩺🔍

| 症状                             | ありがちな原因                          | まずやること                      |
| ------------------------------ | -------------------------------- | --------------------------- |
| コンテナから `localhost:XXXX` が繋がらない | そもそも **そのコンテナ内で** そのポートが開いてない    | 「どこで動いてる？」を言語化する🧠          |
| ホストPCでは見えるのに、コンテナから見えない        | `localhost` の意味違い（今回の罠）🪤        | `host.docker.internal` に変える |
| `host.docker.internal` でも繋がらない | ホスト側のサービスが特定IFにしかバインドしてない / FWなど | サービスを `0.0.0.0` で待つ、FW確認🔥  |

---

## 補足：Docker Desktop以外（Linux/CI等）でホストに繋ぎたいとき🧩🐧

Docker Desktopじゃない環境だと `host.docker.internal` がそのまま使えないことがあります。
その時は **`--add-host` の `host-gateway`** が定番です👇

```bash
docker run --add-host host.docker.internal:host-gateway ...
```

この `host-gateway` は Dockerが用意している特別値で、**ホスト側アドレスに解決させる** ために使えます ([Docker Documentation][4])

（ただし、いまはWindows + Docker Desktop運用がメインなら、この補足は「そういうのもあるんだ」くらいでOKです😊）

---

## AI活用（コピペで使える）🤖✨

## ① 状況整理をAIにやらせる🧠🧹

* 「私は *どこ* から *どこ* に繋ぎたい？（ホスト/コンテナA/コンテナB）を質問して、最終的な接続先URLを1つに決めて」

## ② 図解してもらう🗺️✨

* 「Docker Desktop(Windows+WSL2)で、ホスト/VM/コンテナの関係を、初心者向けにASCII図で描いて」

## ③ エラー貼って切り分け順を作る🔍🧯

* 「このエラーから考えられる原因トップ5と、確認コマンドを優先順で出して」

---

## ミニ問題（定着チェック）📝😆

1. コンテナ内からホストPCの `localhost:8000` に繋ぎたい → 何を使う？
2. コンテナAからコンテナBへ繋ぎたい（Compose）→ 何を使う？

**答え**✅

1. `host.docker.internal:8000` ([Docker Documentation][2])
2. `コンテナBのサービス名:ポート`（例：`db:5432`） ([Docker Documentation][3])

---

## 2026年2月時点の「最新」メモ🗒️✨

Docker Desktop のリリースノート上では **4.59.1（2026-02-03）**、その直前に **4.59.0（2026-02-02）** が掲載されています（段階ロールアウトの注意書きもあり）🆙 ([Docker Documentation][5])
（この章の内容は、この世代のDocker Desktopでもそのまま通用します👍）

---

次の第25章では、ここでチラ見せした **「サービス名で繋ぐ」** を、Todo API + DB の実戦で一気に固めますよ〜！🗣️🌐🔥

[1]: https://docs.docker.com/desktop/features/networking/ "Networking | Docker Docs"
[2]: https://docs.docker.com/desktop/features/networking/networking-how-tos/ "How-tos | Docker Docs"
[3]: https://docs.docker.com/compose/how-tos/networking/ "Networking | Docker Docs"
[4]: https://docs.docker.com/reference/cli/dockerd/ "dockerd | Docker Docs"
[5]: https://docs.docker.com/desktop/release-notes/ "Release notes | Docker Docs"
