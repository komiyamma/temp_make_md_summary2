# 第10章：ミニまとめ：1人で「動かして直して片付け」できる🎓🎉

この章は **“通し運転（起動→ログ→中確認→停止→削除）”** を1人で回せるようになる総合回です💪😆
Dockerを触ってて一番強くなるのは、**失敗して→ログ見て→直して→片付ける** を身体に覚えさせることだよ〜🔥

---

## 今日のゴール🎯✅

次の3つを、**迷わず**できたら合格です🥳

1. コンテナを起動できる🚀
2. ログで状況をつかめる🪵👀（追尾もできる）
3. 中に入って確認できる🕵️‍♂️🔦（環境変数・プロセス・ファイル）
4. 止めて、消して、一覧で“キレイになった”確認できる🧹✨
5. ついでに「安全な掃除」ができる🧽🗑️（やりすぎない）

---

## まずは“通し運転”Aルート（10〜15分）🏃‍♂️💨

### A-1. 状態チェック（0分）🔍

```bash
docker version
docker ps -a
docker images
```

`docker version` は、CLI/Engineなどのバージョンをまとめて出してくれます🧾✨。([Docker Documentation][1])

---

### A-2. ログが流れ続けるコンテナを起動（2分）🪵➡️♾️

“ログを見る練習用”に、わざとずっと喋るコンテナを起動します😄

```bash
docker run --name ch10-logger -e INTERVAL=2 alpine sh -c 'while true; do echo "tick $(date) interval=$INTERVAL"; sleep ${INTERVAL:-2}; done'
```

ポイント👇

* `--name`：後で扱いやすくする🏷️
* `-e`：環境変数を渡す🎚️
* `sh -c`：シェルに「ループ」みたいな複合コマンドを渡す🌀

---

### A-3. ログを見る（3分）👀🪵

まずは普通に見てみる👇

```bash
docker logs ch10-logger
```

次に「追尾（リアルタイム）」👇

```bash
docker logs -f --tail 20 ch10-logger
```

`docker logs --follow`（=`-f`）で新しい出力を流し続けられます。`--tail` で末尾だけもOK👌。([Docker Documentation][2])

> ✅ ここで「ログが見れる＝トラブル対応の入口」クリア！🎉

---

### A-4. 中に入って“現場確認”（3分）🕵️‍♂️🔦

別ターミナルで、コンテナへ突入！💥

```bash
docker exec -it ch10-logger sh
```

中に入れたら、これを確認👇

```bash
pwd
ls
ps
env | head
cat /etc/os-release
```

終わったら `exit` で抜ける🏃‍♂️

`docker exec` は **「動いてるコンテナ」** に対して、追加コマンドを実行するやつです（PID1が生きてる間だけ）。([Docker Documentation][3])
また、複合コマンドを直接渡すのが難しいときは **`sh -c "..."`** を使うのが定番です👌。([Docker ドキュメント][4])

---

### A-5. 止める→消す→一覧で確認（3分）🧹✅

```bash
docker stop ch10-logger
docker rm ch10-logger
docker ps -a
```

ここで `docker ps -a` を見て、**ch10-logger が消えてる**のを確認できたら勝ち🏆✨

---

### A-6. イメージ確認＆“安全な掃除”（2分）🧽🗑️

まずは現状を見る👇

```bash
docker images
```

**使ってないイメージを消す**（例：alpine）👇

```bash
docker image rm alpine
```

イメージ削除は「タグだけ外れる」場合もあるし、実行中コンテナがいると普通は消せません（`-f` は最終手段）⚠️。([Docker Documentation][5])

**さらに軽い掃除（おすすめ）**👇

```bash
docker image prune
```

`docker image prune` は “未使用（特にダングリング）” を消す掃除🧽。`-a` を付けるとガッツリ消えるので初心者は慎重に⚠️。([Docker Documentation][6])

---

## 次は“仕込みトラブル”Bルート（最強の上達）🧯😆

Aルートが通ったら、わざと転んで強くなる！🔥

### B-1. 名前かぶり事故（あるある）🏷️💥

同じ名前でもう一回起動しようとしてみて👇（失敗してOK）

```bash
docker run --name ch10-logger alpine echo hello
```

たぶん「名前が使われてる」系で怒られます😵
解決はこれ👇

```bash
docker rm -f ch10-logger
```

`rm -f` は「止める＋消す」一気技⚔️（便利だけど乱用はしない）

---

### B-2. exec できない事故（止まってる）🧊🚫

わざと止めてから `exec` してみる👇

```bash
docker run --name ch10-sleep alpine sh -c 'sleep 1000'
docker stop ch10-sleep
docker exec -it ch10-sleep sh
```

`exec` は **動いてる間だけ** だから失敗します💡（それが正しい挙動）([Docker Documentation][3])
直し方は「起動し直す」か「run し直す」です👌

---

### B-3. 環境変数ミスで落ちる事故🎚️💥

```bash
docker run --name ch10-badenv -e INTERVAL=abc alpine sh -c 'while true; do echo "tick"; sleep $INTERVAL; done'
```

落ちたら👇

```bash
docker ps -a
docker logs ch10-badenv
```

ログに原因が出ます🪵👀（これが超大事！）

片付け👇

```bash
docker rm ch10-badenv
```

---

## 合格ライン（セルフ採点）📝✅

次を満たしたら、**第01〜10章クリア**です🎉🎉

* `docker logs -f --tail 20 <name>` が使える👀🪵 ([Docker Documentation][2])
* `docker exec -it <name> sh` で中に入れる🕵️‍♂️ ([Docker Documentation][3])
* `stop → rm` して、`docker ps -a` で消えたのを確認できる🧹
* `docker image rm` / `docker image prune` の違いをざっくり説明できる🧽 ([Docker Documentation][5])

---

## つまずき救急箱🧯😵（よくある5つ）

1. **ログが出ない** → まず `docker ps -a` で “動いてる？” を確認📋
2. **コンテナがすぐ落ちる** → `docker logs <name>` が最優先🪵👀 ([Docker Documentation][2])
3. **exec できない** → “そのコンテナ動いてる？”（停止中は無理）🧊🚫 ([Docker Documentation][3])
4. **名前がかぶる** → `docker rm -f <name>` で片付け🏷️🧹
5. **イメージ消せない** → そのイメージを使うコンテナが残ってないか確認（`ps -a`）📦

---

## AI活用（コピペ用プロンプト）🤖✨

### 1) “弱点診断”してもらう🩺

```text
Dockerの第10章の総合演習をしています。
下を見て「次に覚えるべき順番トップ3」と「いま詰まっている可能性が高い点」を教えて。

- docker ps -a の結果:
（ここに貼る）
- docker images の結果:
（ここに貼る）
- docker logs の一部:
（ここに貼る）
```

（貼るだけでかなり当ててくれます😄）

### 2) エラー文を“日本語で短く”してもらう🧾✂️

```text
このエラーを「原因」「確認するコマンド」「直し方」の3つに分けて説明して。
（エラー文貼る）
```

### 3) 自分用チートシートを作る📄✨

```text
第1〜10章で使うDockerコマンドを、初心者向けに「目的→コマンド→よくある罠」でA4一枚にまとめて。
```

---

## 次の章へのつなぎ🌱📦

第10章ができた人は、もう **“Dockerで困っても自力で戻れる”** 入口に立ってます👏😆
次（第11章〜）は「コードはホスト、実行はコンテナ」を成立させる **マウント＆ボリューム** が主役だよ〜📁🔁

ちなみに最近の流れとして、Composeは `docker compose` が標準の呼び方で、Composeは仕様ベースで進化してます（Compose v5 もその流れ）。([Docker Documentation][7])

---

必要なら、この第10章を「チェックシート形式（印刷して潰せる✅）」に整形した版も作るよ📋✨

[1]: https://docs.docker.com/reference/cli/docker/version/?utm_source=chatgpt.com "docker version"
[2]: https://docs.docker.com/reference/cli/docker/container/logs/?utm_source=chatgpt.com "docker container logs"
[3]: https://docs.docker.com/reference/cli/docker/container/exec/?utm_source=chatgpt.com "docker container exec"
[4]: https://docs.docker.jp/engine/reference/commandline/exec.html?utm_source=chatgpt.com "docker exec — Docker-docs-ja 24.0 ドキュメント"
[5]: https://docs.docker.com/reference/cli/docker/image/rm/?utm_source=chatgpt.com "docker image rm"
[6]: https://docs.docker.com/reference/cli/docker/image/prune/?utm_source=chatgpt.com "docker image prune"
[7]: https://docs.docker.com/compose/intro/history/?utm_source=chatgpt.com "History and development of Docker Compose"
