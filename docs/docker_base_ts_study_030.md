# 第30章：ミニまとめ：Web/API開発で毎回使うネットワーク筋トレ🏋️‍♂️

この章は「ネットワークで詰まった時に、毎回“同じ順番”で直せるようになる」ための総復習だよ〜💪😆
（2026-02-08時点の Docker 公式ドキュメント前提で整理してるよ📚✨） ([Docker Documentation][1])

---

## 1) まずは脳内に“3パターン”を固定しよう🧠🔒

ネットワークの詰まりは、だいたいこの3つのどれかで起きるよ👇

## A. ホスト → コンテナ（ブラウザからAPIへ）🪟➡️🐳

* これは **ポート公開（publish）** の世界🌐
* 「ホストのポート」→「コンテナのポート」に穴あけする感じ🕳️✨
* Docker Desktop は「ホスト側で待ち受け → VMへ転送 → コンテナへ」って流れで中継してくれるよ📮 ([Docker Documentation][1])

## B. コンテナ → コンテナ（API → DB）🐳➡️🐳

* これは **同じネットワークに入れる** のが基本🎯
* **ユーザー定義ネットワーク** だと、**コンテナ名（サービス名）で名前解決**できるのが超重要🏷️✨ ([Docker Documentation][2])

## C. コンテナ → ホスト（コンテナからPC上の何かへ）🐳➡️🪟

* Docker Desktop には **host.docker.internal** っていう “特別な名前” があるよ🧙‍♂️
* 「ホストのIPは状況で変わる」ので、**この名前を使うのが安全**👍 ([Docker Documentation][3])

---

## 2) 今日の“筋トレメニュー”🏋️‍♂️🔥（やるほど強くなるやつ）

> 目標：**公開・接続・切り分け**を「手が勝手に動く」くらい反復する😆✨
> 仕上げに「API＋DB接続“手前”」まで通すよ🚀

---

## 筋トレ①：ポート公開の型（ホスト→コンテナ）🔌👀

## ①-1. “正しい待ち受け”を体感する（0.0.0.0が大事）💡

**ポイント：コンテナ内で 127.0.0.1（localhost）待ち受けすると外から来れない**ことが多い😵
なのでまずは **0.0.0.0** で待ち受ける癖をつけるよ🏃‍♂️💨

```bash
docker run -d --name net-gym-api -p 3000:3000 node:24-alpine \
  sh -lc "node -e \"require('http').createServer((req,res)=>{res.end('OK net-gym 🐳✨')}).listen(3000,'0.0.0.0')\""
```

✅ 確認（ホスト側）

* ブラウザで「localhost:3000」を開く👀✨

> Docker Desktop のポート公開は、ホスト側で待ち受けてVMへ転送する仕組みだよ📮 ([Docker Documentation][1])

---

## ①-2. “待ち受けIPを間違えると死ぬ”をわざと体験🪤😇

次はわざと「127.0.0.1」で待ち受けしてみる（外から来れない系）💥

```bash
docker rm -f net-gym-api

docker run -d --name net-gym-api -p 3000:3000 node:24-alpine \
  sh -lc "node -e \"require('http').createServer((req,res)=>{res.end('OK? 🤔')}).listen(3000,'127.0.0.1')\""
```

✅ 確認

* ブラウザで「localhost:3000」→ うまくいかない可能性が高い😵‍💫
  （環境によって挙動に差はあるけど、**“コンテナの外から入る通信”に弱い**のは確実に覚えてOK）

---

## 筋トレ②：localhost罠（“それ、自分自身”問題）🪤🏠

コンテナ内で言う「localhost」は **そのコンテナ自身** のことだよ🫠
「ホスト（Windows）のlocalhost」と別物！ってのを体に染み込ませよう🔥

```bash
docker exec -it net-gym-api sh
```

中でこれ👇（もし curl 無ければ後述の筋トレ③で curl 専用コンテナ使うのでOK🙆‍♂️）

* 「localhost:3000」→ **自分（net-gym-api）**
* 「host.docker.internal:xxxx」→ **ホスト（Windows）** ([Docker Documentation][3])

---

## 筋トレ③：コンテナ間通信（API → DB）🐳🤝🐳

## ③-1. ユーザー定義ネットワークを作る🛠️

```bash
docker network create todo-net
```

> ユーザー定義ネットワークに入れると、**コンテナ名で通信できる**ようになるよ（これが超でかい）🏷️✨ ([Docker Documentation][2])

---

## ③-2. DBコンテナを起動（最新系でOK）🐘✨

2026-02-08時点だと PostgreSQL の最新メジャーは18系（2025年秋リリースの流れ）だよ🐘📈 ([PostgreSQL][4])

```bash
docker run -d --name todo-db --network todo-net \
  -e POSTGRES_USER=todo \
  -e POSTGRES_PASSWORD=todo_pass \
  -e POSTGRES_DB=todo \
  postgres:18
```

※もし postgres:18 が取得できない環境なら、まずは postgres:17 に落としてOK👌（学習目的なら十分） ([PostgreSQL][4])

---

## ③-3. “APIっぽい箱”を同じネットワークで起動🐳✨

```bash
docker rm -f net-gym-api

docker run -d --name todo-api --network todo-net -p 3000:3000 node:24-alpine \
  sh -lc "node -e \"require('http').createServer((req,res)=>{res.end('todo-api OK ✅')}).listen(3000,'0.0.0.0')\""
```

---

## ③-4. “疎通だけ”確認（DB接続の手前まで）🔍✅

ここが今回のゴールの核心🎯
**まだアプリからDBへログインしない**。まずは「ネットワーク的に届く？」だけを見る👀

## ✅ 方法A：DBの準備状態をDB側で確認（pg_isready）🐘

```bash
docker exec -it todo-db pg_isready
```

## ✅ 方法B：curl専用コンテナで「名前解決→到達」を確認🧪

（curl入りの軽量イメージを使うよ。道具箱みたいなもん🧰）

```bash
docker run --rm --network todo-net curlimages/curl:latest \
  http://todo-api:3000
```

* これが通れば、**コンテナ名で名前解決できてる**ってことだよ🏷️✨ ([Docker Documentation][2])

> ちなみに Docker Desktop は「ホストからコンテナへはポート公開」で行くのが基本で、コンテナのIPに直接 ping したりはできない（制限）って明言されてるよ📌 ([Docker Documentation][3])

---

## 筋トレ④：接続文字列（connection string）の型🧵🧠✨

ここは「設計の超入門」的に、**書き方のルール**を決めちゃうのが勝ち🏆

## ④-1. “分解して環境変数”が基本🎛️

接続情報を “1本の文字列” で持つより、まずは分解がわかりやすいよ😊

* DB_HOST：todo-db（← **サービス名**）
* DB_PORT：5432
* DB_USER：todo
* DB_PASSWORD：todo_pass
* DB_NAME：todo

「DB_HOST に IP を書かない」が超大事ね🧠✨
同一ネットワークなら **コンテナ名でOK** だから！ ([Docker Documentation][2])

---

## ④-2. “API側に設定が入ってるか”だけ確認（接続はまだ）👀

```bash
docker exec -it todo-api sh -lc "env | sort | head -n 30"
```

（この章は “接続手前” がゴールなので、ここまでで十分👍）

---

## 筋トレ⑤：詰まった時の切り分けテンプレ（3点セット）🧯🧠

ネットワーク詰まりを **毎回これで殴る** っていうテンプレを渡すよ🥊😆
（これができると「怖くない」が手に入る✨）

---

## ✅ 3点セット①：プロセスは生きてる？（落ちてない？）💓

```bash
docker ps
docker logs --tail 80 todo-api
docker logs --tail 80 todo-db
```

* “起動直後に落ちる”ならネットワーク以前の問題かも😵

---

## ✅ 3点セット②：ポート公開は合ってる？（ホスト→コンテナ）🔌

```bash
docker port todo-api
```

* 「ホストの3000」→「コンテナの3000」になってる？👀

Docker Desktop のポート公開は、ホストで待ち受けてVMに転送する仕組みで、設定で localhost バインドに寄せることもできるよ🔧 ([Docker Documentation][1])

---

## ✅ 3点セット③：同じネットワーク？名前解決できてる？（コンテナ→コンテナ）🏷️

```bash
docker network inspect todo-net
```

* todo-api と todo-db が入ってる？✅
* “default bridge” じゃなく “ユーザー定義ネットワーク” を使うと名前で繋げられるよ🏷️✨ ([Docker Documentation][2])

---

## 3) 仕上げ：今日の達成チェック✅🎉

できたら合格〜〜〜！🥳✨

* ✅ ブラウザで「localhost:3000」にアクセスできる（ホスト→コンテナ） ([Docker Documentation][3])
* ✅ curl専用コンテナで「[http://todo-api:3000」が叩ける（コンテナ名で通信）](http://todo-api:3000」が叩ける（コンテナ名で通信）) ([Docker Documentation][2])
* ✅ todo-api と todo-db が同じネットワークにいる（inspectで確認できる）
* ✅ localhost罠を言葉で説明できる（“それ自分自身”）🪤

---

## 4) AI（Copilot / Codex）に投げると強いプロンプト集🤖✨

GitHub OpenAI 系の支援ツールがある前提で、こう投げると早いよ🚀

## 🩺 プロンプト①：原因候補トップ3を即出し

* 「Dockerのネットワーク不調。いまの状況はこれ：

  1. docker ps の結果（貼る）
  2. docker port todo-api の結果（貼る）
  3. docker network inspect todo-net の結果（貼る）
  4. docker logs todo-api の末尾（貼る）
     原因候補トップ3と、確認コマンドを順番つきで出して。」

## 🧭 プロンプト②：ミスを“再現→修正”で覚える課題化

* 「Docker Desktop + Node API + Postgres のネットワークで、初心者がやりがちなミスを3つ。
  それぞれ『わざと失敗させる手順』→『直す手順』をコマンドで。」

## 🧹 プロンプト③：片付け安全手順を作る

* 「今日作ったコンテナ/ネットワークを安全に消す手順を、確認コマンド付きで短くまとめて。」

---

## 5) 後片付け（環境をキレイに）🧹✨

```bash
docker rm -f todo-api todo-db
docker network rm todo-net
```

---

## ちょい補足：最近のDocker Desktopで“DNS/IPv6まわり”が詰まる人へ🧩🌀

Docker Desktop 4.42以降は「デフォルトのネットワークモード」や「DNSのフィルタ挙動」を設定で調整できて、IPv4/IPv6のミスマッチによるタイムアウトを避けやすくなってるよ🛠️ ([Docker Documentation][3])

---

次の第31章からは、ここまで手でやってた複数コンテナ起動を **Composeで“一発起動”** にしていくよ🎉
この第30章の筋トレができてると、Composeで詰まっても直せる率が一気に上がる💪😄

[1]: https://docs.docker.com/desktop/features/networking/ "Networking | Docker Docs"
[2]: https://docs.docker.com/engine/network/ "Networking | Docker Docs"
[3]: https://docs.docker.com/desktop/features/networking/networking-how-tos/ "How-tos | Docker Docs"
[4]: https://www.postgresql.org/support/versioning/?utm_source=chatgpt.com "Versioning Policy"
