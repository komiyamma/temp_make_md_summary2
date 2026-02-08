# 第25章：サービス間通信の基本（同じネットワークで話す）🗣️🌐✨

この章はね、ひとことで言うと…  
**「コンテナ同士は“同じネットワーク”に入れれば、名前で呼び合って会話できる」**って話です😊✨  
（IP直書き地獄から解放されます👏）

---

## ✅ この章のゴール 🏁
- 「コンテナA → コンテナB」にアクセスできる仕組みがイメージできる🙂
- **ポート公開（ホスト向け）**と**サービス間通信（コンテナ間）**を混同しなくなる🧠✨
- **“接続先は名前、ポートは相手のコンテナ内ポート”**を言えるようになる📌

---

## 1) まず結論：サービス間通信の“3ルール”📌📌📌

## ルール①：同じネットワークに入れる🕸️
**ユーザー定義の bridge ネットワーク**を作ると、コンテナ同士が**自動で名前解決（DNS）**できます。  
デフォルトの `bridge` だと基本は IP 直指定になりがちで初心者にツラい…💦（`--link` はレガシー）:contentReference[oaicite:0]{index=0}

## ルール②：接続先は “相手の名前” 🏷️
同じネットワーク内なら、相手を `db` とか `api` みたいに **名前で呼べます**。:contentReference[oaicite:1]{index=1}

## ルール③：ポートは “相手のコンテナ内ポート” 🔌
ここ超重要⚠️  
- **ホストから入る**とき：`-p 8080:3000` の **左(8080) を見る**👀  
- **コンテナから相手へ**行くとき：相手の **右(3000)＝コンテナ内ポートを見る**👀

---

## 2) イメージ図：ポート公開とサービス間通信は別モノ🧩

````text
(ブラウザ) → localhost:8080 → [ホスト] → 8080:3000 → (APIコンテナ:3000)

(APIコンテナ) → http://db:5432 → (DBコンテナ:5432)
        ↑同じネットワーク内だから “db” で届く
`````

* **外から見せる**＝ポート公開（Chapter22の世界）🌍
* **中で話す**＝同一ネットワークで名前通信（この章）🏠

---

## 3) ハンズオン：2つのコンテナを“名前”で繋ぐ🎮✨

今回は「web（nginx）」に「curl」からアクセスして、**名前解決で届く**のを体験します😄
（この手の確認ができると、DB接続トラブルが一気に楽になります💪）

## Step 0：片付け用に“名前”を決める🧹

ネットワーク名：`todo-net`
コンテナ名：`web`

---

## Step 1：ユーザー定義ネットワークを作る🕸️

```bash
docker network create todo-net
docker network ls
```

> “ユーザー定義 bridge” だと名前解決が効く、が公式の推しポイントです🙂([Docker Documentation][1])

---

## Step 2：web（nginx）をネットワークに入れて起動🚀

```bash
docker run -d --name web --network todo-net nginx
docker ps
```

---

## Step 3：別コンテナ（curl）から `http://web` にアクセスしてみる🔍

```bash
docker run --rm --network todo-net curlimages/curl -sS http://web | head
```

✅ 何かHTMLっぽいものが返れば成功！🎉
**ポイントは `http://web`** です。IPじゃなくて名前で届いてます🏷️✨

---

## Step 4：ネットワークに本当にぶら下がってるか確認👀

```bash
docker network inspect todo-net
```

出力の中に `web` が見えたらOK👌
（“同じネットワークにいるか”が最優先の確認ポイントです）([Docker Documentation][2])

---

## Step 5：お片付け🧹✨

```bash
docker rm -f web
docker network rm todo-net
```

---

## 4) Todo API に繋げる：DB接続で何が変わる？🧠🧵

Todo API（APIコンテナ）からDB（DBコンテナ）に繋ぐときは、考え方がこうなります👇

* 接続先ホスト名：`db`（= DBコンテナ/サービスの名前）
* ポート：`5432`（= DBコンテナ内ポート）
* ポート公開（`5432:5432`）は **“ホストから直接DBを触りたい時だけ”**でOK

つまり **API → DB** は、**同じネットワークに入れて名前で呼ぶ**だけで成立します🙂✨([Docker Documentation][1])

---

## 5) よくあるミス Top5 🪤😵‍💫（ここ超大事）

## ミス①：そもそも同じネットワークじゃない🕸️❌

**症状**：`Could not resolve host: web` / `ENOTFOUND db`
**対処**：`docker network inspect` で両方が同じネットワークにいるか確認👀
（まずここ！）([Docker Documentation][2])

---

## ミス②：`localhost` を相手だと思ってる🪤

コンテナ内の `localhost` は **そのコンテナ自身**です😇
相手は `db` とか `api` とか **名前で指定**します🏷️

---

## ミス③：ポート番号を“ホスト側”で見ちゃう🔌😵

`-p 8080:3000` のとき

* ブラウザ：`8080`
* コンテナ間：`3000`（相手のコンテナ内）

ここが混ざると永遠にハマります😂

---

## ミス④：相手が起動してない / まだ準備できてない⏳

**症状**：`Connection refused`（名前は引けるけど拒否）
**対処**：

* 相手のログを見る：`docker logs <name>` 🪵
* 相手に入って待ち状態を確認：`docker exec -it <name> sh` 🕵️‍♂️

---

## ミス⑤：名前が違う（typo / 別名を使ってる）🏷️💥

* いま繋いでる “名前” はどれ？（コンテナ名？サービス名？エイリアス？）
  ユーザー定義ネットワークでは **名前/エイリアスで解決できる**のが強みです🙂([Docker Documentation][1])

---

## 6) 最短トラブルシュート手順（固定ルート）🧭✨

困ったらこれを上から順にやるだけでOK✅

1. **同じネットワーク？**
   `docker network inspect <net>` で両方いる？([Docker Documentation][2])
2. **名前解決できる？**
   `curl http://相手名` が “名前は引けるか”
3. **相手プロセスが待ち受けてる？**
   `docker logs` と `docker exec` で確認🪵🔦

---

## 7) AI活用プロンプト例 🤖✨（そのままコピペOK）

## ① “名前解決できない” を最短で潰す

```text
Dockerでコンテナ間通信ができません。
状況: `Could not resolve host: db` が出ます。
やったこと: docker run で2つ起動。ネットワークはよく分かってない。
最短で確認すべきコマンドを「上から順に」5つください。理由も1行で。
```

## ② “ポート混同” を一発で正す

```text
`-p 8080:3000` のとき、
(1) ホストからアクセスするポート
(2) コンテナAからコンテナBへアクセスするポート
を例つきで説明して。初心者が間違えやすい点も添えて。
```

---

## 8) 小テスト（3分で理解チェック）📝😄

**Q1.** コンテナAからコンテナBへ繋ぐとき、見るべきは「ポート公開の左？右？」
**Q2.** コンテナ内で `localhost` は誰を指す？
**Q3.** まず確認すべきは「名前」か「ネットワーク」か？

（答え）

* A1：右（コンテナ内ポート）
* A2：自分自身
* A3：ネットワーク（同じかどうか）

---

## 9) まとめ 🎉

* **サービス間通信＝同じネットワーク＋名前で呼ぶ**🕸️🏷️
* **ポート公開は“外に見せる時だけ”**🌍
* 困ったら **network inspect → 名前 → ログ** の順でOK🧭

次の章（第26章）で、ここをさらに強くする
**「サービス名で繋ぐ＝名前解決の第一歩」**に進みますよ〜🏃‍♂️💨([Docker Documentation][3])

---

[1]: https://docs.docker.com/engine/network/drivers/bridge/?utm_source=chatgpt.com "Bridge network driver"
[2]: https://docs.docker.com/reference/cli/docker/network/connect/?utm_source=chatgpt.com "docker network connect"
[3]: https://docs.docker.com/compose/how-tos/networking/?utm_source=chatgpt.com "Networking in Compose"
