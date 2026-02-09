# 第09章：固定できてるか“毎回チェック”する癖✅🔁

この章はひとことで言うと、**「壊れてから気づく」をやめて、** **「壊れた瞬間に気づく」** ための習慣づくりです😎✨
（ランタイム固定の世界では、**“気づける仕組み”が正義**！）

---

## ゴール🎯

* コンテナ起動時に **Node / npm /（必要ならtsc）** の版が **毎回ログに出る** ✅
* もし“固定”がズレたら **起動前に止まる**（＝即発見）✅
* さらに **ワンコマンドで確認できる** ようにする✅

---

## まず結論：チェックすべき3点セット✅✅✅

1. **Nodeのメジャー版**（例：v24系か？）
   → 2026年時点の「安定ど真ん中」は **v24がActive LTS**、v25はCurrent、v22はMaintenance LTS です。([Node.js][1])
2. **npm（or pnpm/yarn）の版**（“地味に事故る”）
3. **TypeScript（tsc）の版**（ビルド結果が変わるので）
   → npm上のTypeScript “Latest” が **5.9.x** 表示（例：5.9.3）です。([npm][2])

---

## レベル1：最速チェック（公式イメージで確認）🐳💨

「そもそも今使うベースが正しい？」を秒速で確認します⚡

```powershell
docker run --rm node:24-bookworm-slim node -v
docker run --rm node:24-bookworm-slim npm -v
```

ここで **v24.x.x** が出ればOK👍
（Currentのv25に寄ってないことを確認できるのが大事！）([Node.js][1])

---

## レベル2：自分のイメージが固定できてるか確認🧱🔍

ビルドした“自分のアプリ用イメージ”に対して、**CMDを上書きして版だけ確認**します（これ超便利）✨

```powershell
docker build -t myapp:dev .
docker run --rm myapp:dev node -v
docker run --rm myapp:dev npm -v
```

> これ、起動が壊れてても “node -v” は確認できることが多いので、切り分けが早くなります🧯

---

## レベル3：起動ログに「必ず」出す（習慣化の最強手）🧠✅

## 方式：エントリーポイント（起動前チェック）を1枚かませる🍞

`docker-entrypoint.sh` を作ります👇

```sh
#!/bin/sh
set -eu

echo "✅ runtime check"
echo "node: $(node -v)"
echo "npm : $(npm -v)"

## TypeScript（入ってる時だけ表示）
if [ -x "./node_modules/.bin/tsc" ]; then
  echo "tsc : $(./node_modules/.bin/tsc -v)"
fi

echo "----"

## ここから“メジャー固定の安全装置”🚨
EXPECTED_NODE_MAJOR=24
ACTUAL_NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"

if [ "$ACTUAL_NODE_MAJOR" != "$EXPECTED_NODE_MAJOR" ]; then
  echo "❌ Node major mismatch! expected v${EXPECTED_NODE_MAJOR}.x but got $(node -v)" >&2
  exit 1
fi

## 最後に本来のコマンドへ
exec "$@"
```

次に `Dockerfile` 側で組み込みます👇

```dockerfile
FROM node:24-bookworm-slim
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["npm", "start"]
```

ポイントはここ👇

* 起動時に **node/npm/tsc が必ずログに出る**✅
* しかも **Nodeがv24以外なら起動前に即死**💥（＝気づける）

※ `npm ci` は lockfile 必須で、ズレてたらエラーで止まる挙動が公式に明記されています（＝固定を守る“検知器”にもなる）([docs.npmjs.com][3])

---

## レベル4：更新漏れを防ぐ“チェック用コマンド”を固定🧷

「毎回同じコマンドで確認」が一番強いです💪✨

おすすめはこれ👇（覚えるのは1つでOK）

```powershell
docker build --pull -t myapp:dev .
docker run --rm myapp:dev node -v
```

* `--pull` を付けると、ベースイメージの更新取りこぼしが減ります🧼
  （Docker公式のビルドベストプラクティスでも `--pull` が紹介されています）([Docker Documentation][4])

---

## ミニ演習🧪（“壊して直す”が最速で身につく）😆🔥

## 演習1：わざと壊して「即検知」を体験💥

`Dockerfile` の `FROM node:24-...` を一瞬だけ `node:25-...` に変えてビルド→起動してみてください。
→ **エントリーポイントが怒って止まる**のを見たら勝ち🏆
（v25はCurrentで、LTS運用の固定から外れることがあるので、検知できるのが大事）([Node.js][1])

## 演習2：ログで“固定”を目視確認👀

起動ログ先頭に
`node: v24...` / `npm: ...` / `tsc: Version 5.9...`
が出るのを確認✅
→ これが「毎回チェックする癖」の完成形です🎉

---

## AIに投げると速い“指示文”🤖✨

* GitHub Copilot向け：
  「Docker起動時に node -v / npm -v / tsc -v をログ出力して、Nodeのメジャーが24以外なら起動失敗する entrypoint を作って」

* OpenAI Codex向け：
  「Dockerfileに entrypoint を追加して、Nodeのメジャー固定（24）チェックを実装。tscは存在する場合のみ表示。Windowsで動く手順も出して」

（こういう“儀式化”はAIが得意です👍）

---

## よくあるつまずき😵‍💫→回避法🛟

* 「`node -v` が思ったのと違う」
  → **ホストのNodeじゃなく、コンテナ内で確認**してる？（`docker run myapp node -v` が正解）✅

* 「毎回確認するの忘れる」
  → **ログに出す**が最強（忘れようがない）✅

* 「なんで patch 更新でもズレるの？」
  → それは普通に起きます。**“メジャーだけ固定して、パッチ更新は許す”** のが現実的バランスです😌
  逆に“完全固定”したいときは digest 固定（上級）へ🚀

---

次の第10章（最小Dockerfile）に入る前に、今の状態で
**「起動ログにnode/npm/tscが出る」** ができてたら、もう一段強いです😆✨

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[3]: https://docs.npmjs.com/cli/v9/commands/npm-ci/?utm_source=chatgpt.com "npm-ci"
[4]: https://docs.docker.com/build/building/best-practices/?utm_source=chatgpt.com "Building best practices"
