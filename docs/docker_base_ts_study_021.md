# 第21章：ポートって何？（入口の番号の話）🚪🔢

この章は「ネットワークって怖い😵」を、**“入口番号の話”**に落としてスッキリさせる回だよ〜😊✨
次の第22章で「ポート公開（ホスト→コンテナ）」に入るので、その前に**ポートの感覚**をつかもう！💪

---

## 1) 今日のゴール🎯✨

* **ポート＝入口番号**だと説明できる🙂
* URLの **どこがポートか** サッと見分けられる👀
* 「アクセスできない😵」ときに **まず何を確認するか** が分かる✅

---

## 2) ポートってなに？超ざっくり🍀

**ポート = そのPC（またはコンテナ）にある“入口（ドア）”の番号**だよ🚪🔢

* 住所（IP）= **どの建物か** 🏠
* ポート = **どの入口（受付）か** 🛎️
* パス `/todos` = **建物の中のどの部屋か** 🧭

たとえば👇

* `http://localhost:3000/`

  * `localhost` = このPC（今いる場所）
  * `3000` = 入口番号
  * `/` = 中の場所（ルート）

---

## 3) URLの分解ができれば勝ち🏆✨

例：`http://localhost:3000/todos?limit=10`

* `http`：通信のルール（プロトコル）
* `localhost`：行き先（ホスト名）
* `3000`：入口番号（ポート）
* `/todos`：場所（パス）
* `?limit=10`：追加情報（クエリ）

> ポートが省略されてるURLもあるよ🙂
> `https://example.com/` はだいたい `443` が暗黙（httpsの標準）って感じ！

---

## 4) よく見るポート番号・ざっくり暗記セット🧠⚡

開発で出会いがちなやつだけ、軽く覚えとくと楽😊

* `3000`：Nodeの開発サーバでよく使う
* `5173`：Viteでよく見る
* `5432`：PostgreSQLでよく見る
* `6379`：Redisでよく見る
* `80`：HTTP（標準）
* `443`：HTTPS（標準）

---

## 5) ハンズオン：ポートを“体感”する🧪✨（ミニサーバ）

ここでは **Todo API本体じゃなくて**、ポートの体感用ミニサーバを動かすよ😊
（Todo APIに組み込んでもOK！）

### 5-1) `server.ts`（超ミニ）🧩

```ts
import http from "node:http";

const PORT = Number(process.env.PORT ?? 3000);

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end(`OK! port=${PORT} path=${req.url}\n`);
});

// ここがポイント：どの入口(PORT)で待ち受けるか
server.listen(PORT, () => {
  console.log(`listening on http://localhost:${PORT}`);
});
```

### 5-2) 起動（例）▶️

（すでにTS実行環境がある前提でOK。もし迷ったら `tsx` がラク寄り🙂）

```bash
npx tsx server.ts
```

### 5-3) ブラウザでアクセス👀

* `http://localhost:3000/`
* `http://localhost:3000/todos`

文字が返ってきたらOK🎉

---

## 6) 「今、そのポート誰が使ってる？」を確認する🔍

### Windows（PowerShell）🪟

```powershell
netstat -ano | findstr :3000
```

出てきた `PID` が「その入口を使ってる犯人（プロセス）」だよ🕵️‍♂️
さらに詳細を見るなら👇

```powershell
tasklist /FI "PID eq 12345"
```

> もし **別のアプリが先に3000を使ってた**ら、サーバ起動時にコケることがあるよ（詳しくは第23章でやる🔥）

---

## 7) Docker目線の“超重要”な予告📦🌐（次章の伏線）

ここ、将来ぜったい効くので先に一言だけ！✋

### 7-1) `127.0.0.1`（localhost）は「その中」の意味になりがち🪤

Dockerだと **コンテナごとにネットワーク空間が分かれていて**、コンテナ内の `127.0.0.1` は **“そのコンテナ自身”** を指すのが基本だよ。([Stack Overflow][1])
なので、サーバが `127.0.0.1` にしか待ち受けてないと、外から繋げなくなることがある（= 第22章・第24章の核心）🧠✨([Stack Overflow][1])

### 7-2) Windows + WSL2 は「localhostだけ通る」現象が起きやすいことがある🪟🧩

最近の構成だと、WSL2バックエンドの都合で **ホストからは `localhost` で見えるけど、LANのIPでは見えにくい**みたいな挙動が報告されがち。([Docker Community Forums][2])
（ここは第22章以降で「どう確認するか」を手順化するよ✅）

---

## 8) 詰まったときの“最初の3点セット”✅✅✅

アクセスできないとき、まずこの順で見ると迷いにくいよ🙂

1. **サーバ動いてる？**（ターミナルに “listening…” 出てる？）🖥️
2. **URL合ってる？**（`localhost:3000` の **3000** 合ってる？）🔢
3. **そのポート誰か使ってない？**（`netstat`で確認）🕵️

> Firewall系は第23章でまとめて扱うけど、Windows Defender Firewallが絡むケースも普通にあるよ🧱🔥([Qiita][3])

---

## 9) AI活用コーナー🤖✨（コピペでOK）

### 9-1) 例え話を“自分の言葉”にする🏢🚪

* 「ポートをマンションで例えて。**住所/IP・部屋番号/ポート・部屋の中の棚/パス**まで対応させて、100文字くらいで！」

### 9-2) ありがちミスを先に潰す🪤

* 「`http://localhost:3000` に繋がらない時の原因候補を、**上から順に5つ**。初心者向けに“確認コマンド”も付けて！」

### 9-3) 自分の開発に寄せる📌

* 「Todo APIで使う予定のポート設計を、**衝突しにくい**ように提案して。例：API/DB/Redis/管理ツール、みたいに並べて」

---

## 10) ミニクイズ（理解チェック）📝✨

1. `http://localhost:3000/todos` のポートはどこ？
2. `localhost` は何を指す？
3. ポートが違うと、同じ `localhost` でも別アプリに繋がる？
4. `:3000` を省略した `http://example.com` のポートは暗黙で何番が多い？
5. Dockerで `127.0.0.1` が指しがちなものは？（予告のやつ）

<details>
<summary>答えを見る👀</summary>

1. `3000`
2. そのマシン自身（その環境の自分）
3. 繋がる（入口が別だから）
4. `80`（httpsなら `443`）
5. そのコンテナ自身（基本）([Stack Overflow][1])

</details>

---

## まとめ🎉

* ポートは **入口番号** 🚪🔢
* URLの `:3000` みたいな部分がポート🌐
* 詰まったら **起動してる？URL合ってる？ポート空いてる？** をまず確認✅
* 次章で「その入口をホストに公開する（ポート公開）」をやるよ〜！🚀✨

次は **第22章：ポート公開（ホスト→コンテナ）で見える化👀** に進もう😊

[1]: https://stackoverflow.com/questions/59179831/docker-app-server-ip-address-127-0-0-1-difference-of-0-0-0-0-ip?utm_source=chatgpt.com "Docker app server ip address 127.0.0.1 difference of 0.0. ..."
[2]: https://forums.docker.com/t/can-only-access-containers-using-localhost-from-the-host/150125?utm_source=chatgpt.com "Can only access containers using localhost from the host"
[3]: https://qiita.com/kodack/items/aebed2d190f5ce152d3e?utm_source=chatgpt.com "DockerコンテナからホストPCへアクセスする方法"
