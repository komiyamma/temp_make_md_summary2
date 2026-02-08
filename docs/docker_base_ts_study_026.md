# 第26章：名前解決（“サービス名で繋ぐ”の第一歩）🏷️

> **今日のテーマ**：コンテナ同士は **IPじゃなくて「サービス名」** でつなぐ！
> これができると、Composeでの開発が一気に“それっぽく”安定します😄✨

---

## 1) この章のゴール🎯

* **IP直書きがダメな理由**を説明できる🙂
* Composeの中で、**`db` とか `api` みたいな“サービス名”で通信できる**🙂
* つながらない時に、**「DNSが死んでるのか？アプリが死んでるのか？」**を切り分けられる🙂🔍

---

## 2) まず結論（1分）⏱️✨

* `docker compose` は、アプリ用に **ネットワークを1つ作って**、各サービスをそこに参加させます。
* そのネットワーク内では、各コンテナは **サービス名で見つかる（名前解決される）** ようになります。つまり **`http://db:5432`** みたいに書ける！✨ ([Docker Documentation][1])
* 逆に言うと、**コンテナのIPは変わりやすい**ので、IPでつなぐとすぐ壊れます😇

---

## 3) IP直書きがなぜ危険？💣

コンテナのIPは、こんな理由でコロコロ変わります👇

* 再起動した
* 作り直した（イメージ更新・設定変更）
* Composeを `down` して `up` し直した
* サービスを増やしてネットワーク内の割り当てが変わった

だから、**「IPでつなぐ＝運ゲー」**になっちゃうんですね😂

---

## 4) 仕組みをざっくり理解🧠🌐

## Composeのネットワークはどうなってる？🧩

* Composeは基本、プロジェクトごとに **デフォルトネットワーク**を作ります（名前はディレクトリ名などに依存）。 ([Docker Documentation][1])
* そのネットワークにいるサービスは、**お互いを“サービス名”で発見できる**。 ([Docker Documentation][1])

## DNSはどこが担当？🛰️

Dockerは、**カスタムネットワーク（Composeのネットワーク含む）では“組み込みDNS”を使う**動きになります。外の名前解決も必要ならホスト側のDNSへ転送します。 ([Docker Documentation][2])

---

## 5) ハンズオン①：サービス名でHTTPアクセスしてみる😆📡

ここでは「**whoami（HTTPサーバ）**」に「**tools（確認用）**」からアクセスして、
**`whoami` というサービス名が名前解決できてる**のを確かめます🔍✨

## 5-1. `compose.yml` を作る📝

適当なフォルダを作って、`compose.yml` を作成👇

```yaml
services:
  whoami:
    image: traefik/whoami
    # ※ ports は付けない（コンテナ同士通信の確認が目的だから）

  tools:
    image: alpine:3.20
    command: sh -c "sleep infinity"
```

> `ports:` を付けない理由：
> この章は「**ホスト公開**」じゃなく「**コンテナ同士通信**」が主役だからです😉

## 5-2. 起動🚀

```bash
docker compose up -d
docker compose ps
```

`whoami` と `tools` が `running` になってたらOK👌✨

---

## 5-3. toolsコンテナに入って、名前解決チェック🔍

まずDNSツールを入れます（alpineは最小なので追加が必要）📦

```bash
docker compose exec tools sh
apk add --no-cache bind-tools busybox-extras
```

## ✅ 1) `whoami` のIPを引ける？

```bash
nslookup whoami
```

## ✅ 2) もっと “それっぽい” DNS確認（dig）

```bash
dig whoami
```

## ✅ 3) 実際にHTTPアクセスできる？

```bash
wget -qO- http://whoami
```

**whoamiの情報（ホスト名とかIPっぽい表示）が返ってきたら大成功🎉🎉🎉**

---

## 6) ハンズオン②：Todo APIに寄せる（DB_HOST を “db” にする）🧵🧠

ここからが超重要ポイントです👇

## “接続先”はIPじゃなくて「名前」＋「環境変数」で持つ🎚️✨

たとえば、将来 `api` と `db` をComposeで動かすなら、API側はこういう発想になります👇

* `DB_HOST=db`
* `DB_PORT=5432`
* `DB_USER=...`
* `DB_PASSWORD=...`

つまりコード側は **`process.env.DB_HOST` を読むだけ**にしておいて、
**Compose側で `DB_HOST=db` を渡す**のが勝ち筋です🏆✨

例（まだDBを本格導入しない“形だけ”の例）👇

```yaml
services:
  api:
    image: node:22-alpine
    environment:
      DB_HOST: db
      DB_PORT: "5432"
    command: sh -c "node -e \"console.log('DB_HOST=', process.env.DB_HOST)\""

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: example
```

> ここでは **「db という名前が使える」** という事実が主役です。
> DB接続の本番は次の章（接続文字列）でガッツリやると気持ちいいです😄✨

---

## 7) よくあるハマりポイント🪤😵‍💫（超あるある）

## ❶ ホスト（Windows）から `http://whoami` で開けない😇

それ正常！
**サービス名の名前解決は“Composeネットワークの中限定”**です。ホストのブラウザは別世界🏙️

ホストから見たいなら `ports:` で公開が必要（第22章の話）🔌✨

---

## ❷ 別ネットワークにいると名前解決できない🙅‍♂️

「同じComposeプロジェクト」でも、サービスごとにネットワークを分けたら、分断されます⚡

Composeは基本1つのネットワークにまとめてくれますが、カスタムで触ったら要注意です。 ([Docker Documentation][1])

---

## ❸ `depends_on` があるのに繋がらない😵

`depends_on` は **起動順のヒント**であって、
「DBが起動完了して接続受付OK」まで待つ保証は薄いです（だから “待ち戦略” が次で出てきます）⌛

---

## ❹ “名前解決はOK” なのに繋がらない（真犯人はポート）🔌💥

例：`db` のポートは普通 **5432** だけど、間違えて `http://db:3000` に繋いでる…みたいなやつ😂

---

## 8) つながらない時のデバッグ手順（テンプレ）🧯🔍

## ✅ 手順A：まず生存確認

```bash
docker compose ps
docker compose logs --tail=200
```

## ✅ 手順B：名前解決だけ確認（ここが第26章の本体！）

```bash
docker compose exec tools nslookup whoami
docker compose exec tools getent hosts whoami || true
```

## ✅ 手順C：DNSの設定を覗く👀

```bash
docker compose exec tools cat /etc/resolv.conf
```

Composeネットワークなど「カスタムネットワーク」に接続しているコンテナは、Dockerの組み込みDNSを使う挙動になります。 ([Docker Documentation][2])

---

## 9) ちょい設計メモ（初心者が勝ちやすい型）📐✨

* **サービス名＝接続先名（安定）**
* **実際の接続情報は env（環境変数）で注入**
* **コード側は env を読むだけ**（IPや環境ごとの分岐はしない）
* `container_name:` は、あとでスケールや再利用で邪魔になることがあるので、基本は触らない方が安全🙂

---

## 10) ついでに覚えとくと便利：`host.docker.internal` 🏠🧩

これは **コンテナ→ホスト（Windows側）** にアクセスしたい時の名前です。
Docker Desktop（WSL2バックエンド）でも使えるケースが多いです。 ([Qiita][3])

ただしこれは **Docker Desktop向けの“便利名”**なので、環境によっては本番でそのまま使えない・推奨されないことがあります。 ([Docker Community Forums][4])

> 第26章の主役は「コンテナ↔コンテナ」なので、ここは“豆知識”扱いでOK😄✨

---

## 11) AI活用（この章で効くプロンプト）🤖✨

## ✅ 理解を固めたい

* 「Docker Composeでサービス名がDNSで解決される仕組みを、図解っぽい文章で説明して」

## ✅ つながらない時（ログ貼り付け）

* 「この `nslookup` と `curl` 結果から、原因候補を優先度順に3つ出して。次に打つコマンドもセットで」

## ✅ 設計寄り（次章につなぐ）

* 「Todo API + DBの接続設定を env で管理する場合の `DB_HOST/DB_PORT/...` 命名ルール案を出して」

---

## 12) ミニ課題🎯（5〜10分で終わるやつ）

## 課題A：サービス名を変えてみる🏷️

* `whoami` → `web` に変更
* toolsから `nslookup web` / `wget http://web` が通るのを確認✨

## 課題B：わざと壊して、直す🪤

* `wget http://whoami` を `wget http://whoami:9999` にして失敗させる
* 「名前解決はOKだがポートが違う」パターンだと説明できたら勝ち🏆

---

## まとめ🎉

この章で一番大事なのはこれ👇

* **“同じComposeネットワーク内”なら、サービス名でつながる**（IP直書き卒業！） ([Docker Documentation][1])
* **カスタムネットワークではDockerの組み込みDNSが効く**（外のDNSにも転送する） ([Docker Documentation][2])

次の第27章で、これを使って **接続文字列（接続情報）を迷わず組み立てる**のに入ると、いよいよ「API→DB」が現実になります😆🔥

[1]: https://docs.docker.com/compose/how-tos/networking/?utm_source=chatgpt.com "Networking in Compose"
[2]: https://docs.docker.com/engine/network/?utm_source=chatgpt.com "Networking | Docker Docs"
[3]: https://qiita.com/kodack/items/aebed2d190f5ce152d3e?utm_source=chatgpt.com "DockerコンテナからホストPCへアクセスする方法"
[4]: https://forums.docker.com/t/host-docker-internal-in-production-environment/137507?utm_source=chatgpt.com "Host.docker.internal in production environment - General"
