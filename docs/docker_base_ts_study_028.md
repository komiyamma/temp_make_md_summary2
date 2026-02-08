# 第28章：疎通がダメな時の基本チェック（3点セット）🔍

「DBに繋がらない」「APIが見えない」「名前で繋げない」…このへん、最初はみんな通ります😇
でも大丈夫。**調査の順番**を固定すると、毎回スッと直せるようになります💪✨

この章は、困ったらこれだけ見ればOKな **“3点セット”** を体に染み込ませます🔥

---

## まず最初に（超大事）🧭：「どこから試してる？」問題

同じ `localhost` でも意味が変わります😵‍💫

* **ホスト（Windows）から** → ブラウザ / PowerShell から叩く
* **コンテナの中から** → `docker exec` で入って叩く
* **別コンテナから** → “隣の箱” から叩く（ネットワーク確認に最強）

この章のチェックは、**「どこから」→「どこへ」→「通る？」**の順に進めます🚦✨

---

## ✅ 疎通チェック 3点セット（この順でやる）✅✅✅

## ① 相手は生きてる？（起動・ログ・待受）🫀🪵👂

まず「相手（DBやAPI）が本当に起動してるか」です😊

**見るもの（最短）**

* コンテナは動いてる？
* ログにエラー出てない？
* そのポートで“待受（listen）”してる？

**すぐ使うコマンド**

```bash
## 走ってる？（Composeなら docker compose ps でもOK）
docker ps

## ログ（Composeなら docker compose logs -f サービス名）
docker logs <container>

## もし "起動してすぐ落ちる" なら、まずログが本体👀
```

> Compose系の確認コマンド（`ps` / `logs` / `exec` / `port` など）は `docker compose` にまとまっています。([Docker Documentation][1])

**よくある“生きてない”パターン😵**

* DBが起動直後でまだ準備中（コンテナは “Up” でも、中のサービスがまだ未起動）
* 環境変数ミスでアプリが即死
* ポート被りで起動できてない（ホスト側公開で詰まる）

👉 **Compose** なら「依存先が “healthy” になるまで待つ」設計ができます（健康診断＝healthcheck）🩺
`depends_on: condition: service_healthy` が公式の考え方として案内されています。([Docker Documentation][2])

---

## ② 宛先は合ってる？（名前・ポート・localhost罠）🎯🏷️🔢

次に「その接続先、ほんとに合ってる？」を確認します😊

## 🪤 localhost罠（超ある）

* **コンテナ内の `localhost`** は **そのコンテナ自身** を指します😵‍💫
  DBは別コンテナなのに `localhost` に繋ぎに行くと当然ダメ🙅

## 🏷️ 名前（ホスト名）を使うなら「同じネットワーク」が基本

ユーザー定義ネットワークを使うと、**コンテナ名/サービス名で名前解決**できます（Dockerの仕組み）🧠✨([Docker Documentation][3])

## 🪟 コンテナ → ホスト（Windows）へ繋ぎたいとき

ホストのIPは変わりがちなので、Docker Desktop では **専用のDNS名**が用意されています👇

* `host.docker.internal`（ホストに繋ぐ）
* `gateway.docker.internal`（Docker VMのゲートウェイ）([Docker Documentation][4])

---

## ③ “通る？”を最短で試す（DNS → ポート）🌐🧪🚪

最後に「実際に通るか」を、**小さい道具**で確認します🧰✨
ポイントは「アプリで試す前に、通信だけ試す」こと👍

## 🧰 おすすめ：ネットワーク用のデバッグコンテナ（最強）

`nicolaka/netshoot` はネットワーク調査ツール入りで超便利です🕵️‍♂️✨([GitHub][5])

---

## ハンズオン：わざと失敗して、3点セットで切り分ける😈➡️😄

ここでは「Todo API（想定）＋DB（Postgres想定）」っぽい状況を、**最小**で再現します🌱
（API本体がまだでも、疎通チェックの練習はできます👍）

---

## 準備：ネットワークとDBを用意する🌐🐘

```bash
## 1) ネットワーク作成（名前解決の恩恵を受けるため）
docker network create todo-net

## 2) DB起動（例：Postgres）
## ホスト公開は "必要なときだけ" でOK（まずはコンテナ間で繋ぐ練習）
docker run -d --name todo-db --network todo-net ^
  -e POSTGRES_PASSWORD=pass ^
  -e POSTGRES_DB=todo ^
  postgres:16
```

> 「ユーザー定義ネットワーク上でのサービスディスカバリ（名前解決）」は Docker のネットワーク機能として説明されています。([Docker Documentation][3])

---

## ① 生存確認：DBは生きてる？🫀

```bash
docker ps
docker logs todo-db
```

* ログに「起動完了っぽいメッセージ」が出てればOK🙆‍♂️
* もしエラーなら、②③に行く前にここで止めて直すのが最速です🪵✨

---

## ② 宛先確認：名前は合ってる？🏷️

**別コンテナ（デバッグ役）**から確認します👇

```bash
## netshoot を同じネットワークに入れて、シェル起動
docker run --rm -it --network todo-net nicolaka/netshoot bash
```

netshoot の中で👇

```bash
## 名前解決できる？（IPが返ればOK）
getent hosts todo-db
```

* 返らない → **②（宛先）で詰まってる**可能性大😵

  * ネットワーク違う
  * 名前を間違えてる（`todo-db` じゃなく `db` と打ってた等）

---

## ③ “通る？”確認：ポートが開いてる？🚪

netshoot の中で👇

```bash
## 5432 に繋がる？（Postgresのデフォ）
nc -vz todo-db 5432
```

* `succeeded` なら “通る”✅
* `refused` なら、DBがまだ待受してない / ポート違い / 起動失敗のどれか😵

---

## わざと失敗パターン3連発（超よくある）💣💣💣

## 失敗A：DB_HOST を `localhost` にしてた🪤

症状：APIからDBに繋がらない（でもDBは動いてる）😵‍💫

**3点セットで見ると…**

* ① 生きてる：DBはUp ✅
* ② 宛先：`localhost` は “APIコンテナ自身” 🙅
* ③ 通る：`todo-db:5432` は通る ✅（netshootで確認済み）

👉 修正：**DB_HOST はサービス名（例 `todo-db`）** にする
（Composeなら `db` みたいなサービス名にするのが一般的✨）

---

## 失敗B：ホスト公開ポートとコンテナ内ポートをごっちゃにした🔢😵

例：ホスト側で `-p 54320:5432` にしたのに、**コンテナから 54320 に繋ぎに行く**やつ💥

**覚え方（これだけ）**

* **コンテナ→コンテナ**：基本 **“コンテナのポート”**（例 5432）
* **ホスト→コンテナ**：**“ホストに公開したポート”**（例 54320）

👉 “どこから試してる？” がズレてるパターンです🧭

---

## 失敗C：パスワード違い（通信は通るのにログイン失敗）🔐

症状：`password authentication failed` みたいなログ😇

**3点セットで見ると…**

* ① 生きてる：DBはUp ✅
* ② 宛先：`todo-db:5432` で合ってる ✅
* ③ 通る：`nc` もOK ✅
  → なのに失敗：**認証情報（USER/PASS/DB名）**が怪しい🔍

👉 このタイプは **DBログ**がいちばん喋ってくれます🪵✨

---

## すぐ使える「固定チェックリスト」📋✅（コピペ推奨）

## ✅ ① 生きてる？

* `docker ps`（Up？再起動ループしてない？）
* `docker logs <container>`（エラーは？）
* （Composeなら）`docker compose ps` / `docker compose logs -f <service>` ([Docker Documentation][1])

## ✅ ② 宛先合ってる？

* `localhost` になってない？🪤
* サービス名/コンテナ名が正しい？
* 同じネットワークにいる？
* コンテナ→ホストなら `host.docker.internal` を使う([Docker Documentation][4])

## ✅ ③ 通る？

* DNS：`getent hosts <name>`
* ポート：`nc -vz <host> <port>`
* “アプリで試す前に” 通信だけ試す🧪

---

## AI活用（この章と相性バツグン）🤖✨

## 1) ログ→原因候補トップ3→確認手順

AIにこう投げると強いです👇

```text
以下の状況で疎通できません。3点セット（生存/宛先/通る）で
原因候補トップ3と、確認コマンドを順番に出して。

- どこから: （ホスト or コンテナ名）
- どこへ: （ホスト名:ポート）
- エラー全文:
- docker ps:
- docker logs:
- （あれば）docker compose.yml該当部分:
```

## 2) “再発防止”のルール化

```text
このトラブルを再発させないために、
.env命名/ポート運用/healthcheckの方針を1枚ルールにして。
初心者向けに短く。
```

---

## ミニまとめ🎉：この章で強くなること💪

* 困ったら **①生存 → ②宛先 → ③通る** の順で調べる🔍✅
* `localhost` の意味が「今どこにいるか」で変わる🧭
* デバッグ用コンテナ（netshoot）を使うと切り分けが爆速🕵️‍♂️✨([GitHub][5])
* 2026-02-08 時点の Node.js は **v24 系が Active LTS**なので、Todo API のベースイメージも `node:24` で考えるのが無難です🟩✨([Node.js][6])

---

次の章（第29章）は「ポート設計のルール化」なので、今回の“切り分けの型”がそのまま設計にも効いてきますよ📏✨

[1]: https://docs.docker.com/reference/cli/docker/compose/?utm_source=chatgpt.com "docker compose"
[2]: https://docs.docker.com/compose/how-tos/startup-order/?utm_source=chatgpt.com "Control startup order - Docker Compose"
[3]: https://docs.docker.com/engine/network/?utm_source=chatgpt.com "Networking | Docker Docs"
[4]: https://docs.docker.com/desktop/features/networking/networking-how-tos/?utm_source=chatgpt.com "Explore networking how-tos on Docker Desktop"
[5]: https://github.com/nicolaka/netshoot?utm_source=chatgpt.com "nicolaka/netshoot: a Docker + Kubernetes network trouble- ..."
[6]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
