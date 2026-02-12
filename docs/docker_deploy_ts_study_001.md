# 第01章：ゴールの景色：URLで開けるまでの一本道 🌍➡️

この章は「細かい最適化」は一旦おいといて、**“公開までの一本道”を頭に入れる回**だよ〜😆✨
最後にミニハンズオンもあるので、まずは「流れが見える」状態を作ろう！🐳💨

---

## 1) まず結論：公開って何をするの？🧭

**コンテナをWebへ出す**って、やることは基本この3点セットだけ👇

1. **イメージを作る**（＝アプリを“箱詰め”する）📦
2. **置き場に置く**（＝レジストリへpush）🏪
3. **動かす場所で起動する**（＝デプロイ）🌐

この「一本道」を覚えるだけで、迷子率が一気に下がるよ👍✨

---

## 2) 地図を1枚で：ローカル→URLまでの流れ 🗺️

イメージとしてはこんな感じ👇

* あなたのPC（ローカル）💻
  ↓ build
* **コンテナイメージ**（アプリ入りの箱）📦
  ↓ push
* **レジストリ**（箱の倉庫）🏪
  ↓ deploy
* **実行環境**（箱を動かす場所）🏃‍♂️
  ↓
* **公開URL**（世界からアクセスできる入口）🔗🌍

そして重要なのがこれ👇
**ローカルは“自分だけ”**、本番は **“世界に公開”** 😳
だから本番では「増える責任」があるんだよね〜。

---

## 3) ローカルと本番で“増える責任”って何？🧨➡️✅

本番で急に大事になるのは、だいたいこのへん👇（初心者がハマりやすい順）

* **設定が変わる**：ポート番号、接続先、URL、モード…🔧
* **秘密が混ざると事故る**：APIキーをGitに入れたら終わり😇🔑
* **落ちる前提で動かす**：再起動・更新・スケールが普通に起きる🔁
* **ログが命綱**：止まったとき、ログがないと詰む👀🧯
* **外から来る**：変なリクエスト、攻撃、負荷…🌪️

ここは「怖がらせる」ってより、**“本番はそういう場所”**って知るだけでOKだよ😊✨

---

## 4) この章で覚える用語ミニ辞典 📚🐳

* **イメージ（image）**：アプリ＋実行に必要なものを詰めた“箱”📦
* **コンテナ（container）**：箱（イメージ）を“起動した状態”🏃‍♂️
* **レジストリ（registry）**：箱の倉庫（push/pullする場所）🏪
* **build**：箱を作る🧱
* **push/pull**：倉庫に置く／倉庫から取る📤📥
* **tag**：箱のラベル（どの版？を示す）🏷️
* **deploy**：箱を本番環境で動かす🚀
* **PORT**：本番が「この番号で待ち受けてね」と渡してくることがある🔌

※特に **PORT** は超重要！
たとえば Cloud Run だと **`PORT` 環境変数が注入されて、そのポートで listen しないと起動失敗**になりがちだよ〜😵‍💫
（この罠は後の章でガッツリ潰す！）([Google Cloud Documentation][1])

---

## 5) 2026年2月時点の「Nodeの選び方」超ざっくり 🟢📌

本番では基本、**安定版（LTS）**を使うのが安心👍
2026-02-09 時点のステータスだと、**v24 が Active LTS、v25 が Current**になってるよ。([Node.js][2])

「LTSって何？」は、ざっくり言うと
**長めに安定サポートされる版**＝本番向け、って覚え方でOK😊
（Current→LTS→…みたいな流れの説明もあるよ）([endoflife.date][3])

---

## 6) ミニハンズオン：まず“一本道”を体験しよう 😆🧪

ここは **TypeScriptの凝った構成はまだやらない**よ（後でちゃんとやる！）
目的は **「イメージ作る→コンテナ起動→ブラウザで見える」** を最速で体験すること！🚀

### Step 1：最小のWebサーバを作る 🧱🌐

フォルダ作って `server.mjs` を作成👇

```js
import http from "node:http";

const port = Number(process.env.PORT ?? 3000);
// 本番で大事：0.0.0.0 で待ち受ける（ローカルだけなら localhost でも動くけどね）
const host = "0.0.0.0";

const server = http.createServer((req, res) => {
  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end("Hello from container! 🐳✨\n");
});

server.listen(port, host, () => {
  console.log(`listening on http://${host}:${port}`);
});
```

### Step 2：Dockerfileを置く 🐳📄

```dockerfile
FROM node:24-slim

WORKDIR /app
COPY server.mjs /app/server.mjs

ENV NODE_ENV=production
CMD ["node", "server.mjs"]
```

### Step 3：ビルドして起動！🚀

PowerShellで👇

```powershell
docker build -t hello-web:1 .
docker run --rm -p 8080:8080 -e PORT=8080 hello-web:1
```

ブラウザで👇
`http://localhost:8080` を開いて、 **Hello from container!** が出たら勝ち🏆✨

✅ ここまでで「一本道」の最初の2割は体験できたよ！
（この後、倉庫＝レジストリへ push → クラウドで deploy に進む！）

---

## 7) ミニ課題：外に出ると困る点を3つ書き出そう 📝😵‍💫➡️😎

あなたのアプリを“公開する”ってなったとき、困りそうなのを3つ👇

* 例）「APIキーってどこに置けばいい？」🔑
* 例）「DBってローカルファイルに保存してるけど…？」💾
* 例）「落ちたらどうやって気づく？」👀

これ、正解は一旦なくてOK！
**“気づく”ことが最強の前進**だよ👍✨

---

## 8) つまずき先読みTop5（今は名前だけ覚えればOK）😇🧨

1. **PORT / 0.0.0.0 問題**（本番で起動しない）🔌😵
2. **Secrets混入**（Gitに入れてしまう）🔑☠️
3. **ローカルファイル依存**（本番は消える/増える）📁💥
4. **ログが見れない**（原因が追えない）📜🙈
5. **タグ運用が雑**（どれが本番かわからない）🏷️😵‍💫

特に「レジストリに push」は **`docker image push` で“倉庫に置く”操作**だよ、って感覚だけ持っておくと次が楽！([Docker Documentation][4])

---

## 9) AI活用コーナー（コピペ用）🤖✨

どれもそのまま投げてOKだよ〜👇

* 「このアプリを本番に出すとき、増える論点を初心者向けに箇条書きで教えて」🧭
* 「このコードで“秘密情報になりそうなもの”を列挙して、環境変数名案も出して」🔑
* 「DockerでWeb公開するときの“よくある事故トップ10”と予防策を短く」🧯
* 「このアプリ、外部公開するなら最低限どんなログが必要？」📜👀

---

## 10) まとめ：この章で“もう勝ち”なこと 🏁😆

この章で手に入ったのはこれ👇

* 公開までの **一本道（イメージ→レジストリ→実行環境→URL）** が見えた🗺️
* ローカルと本番で **責任が増える場所** を知った🧠
* まずコンテナで **ブラウザ表示まで体験**できた🐳✨

次章では、この一本道の「分岐（どこへデプロイするか）」を整理して、迷子を完全に減らしていくよ〜🧭🚀
（Cloud / VM / オーケストレータ…を“分類で理解”してラクにするやつ！）

[1]: https://docs.cloud.google.com/run/docs/configuring/services/containers?utm_source=chatgpt.com "Configure containers for services | Cloud Run"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://endoflife.date/nodejs?utm_source=chatgpt.com "Node.js"
[4]: https://docs.docker.com/reference/cli/docker/image/push/?utm_source=chatgpt.com "docker image push"
