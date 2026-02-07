# 第05章：イメージの一覧と掃除（images / rmi）🧽🗑️

## 今日のゴール 🎯✨

* 「イメージが増える理由」をざっくり説明できる🙂
* “今どれが容量食ってる？”をサクッと把握できる👀
* **安全に**いらないイメージを消せる（怖くない！）💪😄
* 「消して良い/ダメ」の判断ができる🧠⚖️

---

## 1) そもそも、なんでイメージが溜まるの？📦📈

開発してると、イメージは放っておくと増えます😅

よくある増え方👇

* 同じベース（例：Node）でもタグ違いを何回も引く（pull）🧲
* buildを繰り返して**古い版が残る**🧱
* build中の“途中レイヤ”が残って「<none>」が増える（いわゆる dangling）👻
* buildの**キャッシュ**が便利すぎて裏で育つ🌱（速くなる代わりに容量を食う）

Dockerのイメージはレイヤ構造で、途中レイヤをキャッシュとして持てるのが強みです（速い！）が、掃除しないと容量が増えます。([Docker Documentation][1])

---

## 2) まずは現状把握！「何が容量食ってる？」🔍📊

いきなり消す前に、**見える化**しよう😄✨

### 2-1. Docker全体の使用量を見る（超おすすめ）👀

```bash
docker system df
```

これで、Dockerが使ってるディスク量が分かります。([Docker Documentation][2])

さらに詳しく（どれが大きいか）見たいなら👇

```bash
docker system df -v
```

（環境によって出力は違うけど、だいたい「イメージ・コンテナ・ボリューム・ビルドキャッシュ」の内訳が見えます）([Docker Documentation][2])

---

## 3) イメージ一覧の見方：これが読めると勝ち🏆✨

### 3-1. 一覧を見る

```bash
docker image ls
```

通常は「REPOSITORY / TAG / IMAGE ID / CREATED / SIZE」みたいな列が出ます。([Archマニュアルページ][3])

> ✅ポイント
>
> * **REPOSITORY + TAG** = 人間が読む“名前”🏷️
> * **IMAGE ID** = 本体の識別子（同じ本体にタグが複数付くこともある）🆔
> * **SIZE** = 目安（レイヤ共有があるので厳密な合計とはズレることがある）📏

### 3-2. 「<none>」が増殖してたら要注意（だいたい掃除対象）👻🧹

「タグが付いてない」「宙ぶらりん」なイメージは、**dangling** と呼ばれます。
ただし、普段の `docker image ls` では **隠れてる**ことがあります。([Docker Documentation][1])

全部見たい時は👇

```bash
docker image ls -a
```

`-a` を付けると、中間レイヤやdanglingも表示されます。([Docker Documentation][1])

### 3-3. dangling だけ絞って見る（めちゃ便利）🎯

```bash
docker image ls --filter "dangling=true"
```

フィルタ `dangling=true/false` は公式にサポートされています。([Docker Documentation][1])

---

## 4) 「消して良い / ダメ」判断軸 ⚖️🧠

ここが一番大事！🥹✨

### ✅ 基本：消して良い寄り（初心者でも安全ゾーン）

* **dangling（<none>）** で、もう使ってないやつ👻
* 「古い版っぽい」「今の開発で使ってない」イメージ🧹
* “コンテナに紐づいてない”イメージ（後述の prune -a）🗑️

### ⛔ ちょい注意（消す前に一呼吸😌）

* いま動いてるコンテナが使ってるイメージ（消せない/壊れる）🚫
* 「次も使う」ベースイメージ（次回pullが必要になるだけだけど、通信＆時間コストが増える）⏳
* ビルドキャッシュ（消すと次のbuildが遅くなる）🐢

---

## 5) ハンズオン：安全に段階お掃除🧽✨

いきなり“全部消す系”に行かず、**安全な順番**でいきます😄

---

### ステップA：danglingだけ消す（まずはここ）👻🗑️

1. まず「消える予定のもの」を確認

```bash
docker image ls --filter "dangling=true"
```

2. OKなら実行

```bash
docker image prune
```

`docker image prune` はデフォルトで **dangling イメージを削除**します。([Docker Documentation][4])

> ここまでで「<none> が大量」だった人は、だいぶスッキリすること多いよ😆✨

---

### ステップB：未使用イメージも含めて整理（慎重に）🧹⚠️

「danglingはもう無いのに、まだ容量がデカい…」って時に使うやつ。

```bash
docker image prune -a
```

`-a` を付けると、**“少なくとも1つのコンテナに紐づいていないイメージ”**も削除対象になります（確認プロンプトが出る）。([Docker Documentation][5])

#### さらに安全に：古いものだけ消す（おすすめ）🧠✨

「直近のイメージは残して、古いのだけ消したい」ならフィルタ！

```bash
docker image prune -a --filter "until=168h"
```

`--filter "until=..."`（指定時間より前のものだけ）や `label` フィルタが使えます。([Docker Documentation][5])

---

### ステップC：特定イメージをピンポイントで消す（rmi / image rm）🎯🗑️

一覧を見て「これ要らん！」って決め打ちできる時。

```bash
docker image rm <IMAGE_ID>
```

または名前で👇

```bash
docker image rm <REPOSITORY>:<TAG>
```

このコマンドは「イメージを削除（＋タグ外し）」します。
**同じ本体にタグが複数ある**場合、タグ指定だと“タグだけ外れる”こともあります（なるほど便利）。([Docker Documentation][6])

> ⚠️ 実行中コンテナが使ってるイメージは、普通は消せません（強制 `-f` は上級者向け）。([Docker Documentation][6])

---

### ステップD：「ビルドキャッシュ」が太ってる時の掃除🧱🐘

`docker system df -v` で **Build Cache** が大きい時、ここが本丸なことがあります😇

```bash
docker builder prune
```

Build Cache を削除できます。([Docker Documentation][7])

「全部消すと遅くなるのが怖い…」って時は、**残す容量**を決めるのもアリ👇

```bash
docker builder prune --keep-storage 10GB
```

（オプションとして公式にあるよ）([Docker Documentation][7])

さらに、BuildKit は一定条件でガベージコレクション（自動掃除）もあります。([Docker Documentation][8])

---

## 6) “危ない掃除”と“便利な掃除”の違い🧯😵

### 便利だけど強い：system prune（使うなら意味を理解してから）

```bash
docker system prune
```

これは **停止中コンテナ・未使用ネットワーク・未使用イメージ（dangling含む）・ビルドキャッシュ** をまとめて消します。([Docker Documentation][9])
（ボリュームはデフォでは消えないけど、`--volumes` を付けると消えるので注意！）([Docker ドキュメント][10])

> 初心者の最適解はだいたい
> ✅「image prune（まず）→ 必要なら prune -a（古いのだけ）→ builder prune（キャッシュ）」
> って順番です🙂✨

---

## 7) よくある詰まり & 解決🪤🛠️

### Q1. 「イメージ消せない」って怒られた😭

だいたい理由はこの2つ👇

* そのイメージを使うコンテナが残ってる（停止中でも）📦
* 実行中コンテナが使ってる🏃‍♂️

まず「そのイメージを使ってるコンテナ」を探す👇

```bash
docker ps -a --filter "ancestor=<REPOSITORY>:<TAG>"
```

見つかったら、（第04章でやった）コンテナ削除 → その後イメージ削除、の順にするとスムーズです🙂

---

### Q2. 掃除したのに、Windowsの空き容量が増えない…😵‍💫

WSL2（Docker Desktop の内部）だと、仮想ディスク（VHDX）が一度膨らむと、**ファイルを消しても自動で縮まない**ことがあります。([GitHub][11])

この場合は「Dockerの掃除」とは別に、VHDXの圧縮が必要になるケースがあります（やるなら手順をちゃんと確認してね）。([RandomDev][12])

> ここは第02章（Windows/WSL2まわり）寄りの話なので、深追いは後でOK！
> でも「掃除したのに増えない」の正体としては超ありがちです😅

---

## 8) ミニ課題（Todo APIを育てる準備運動）🏋️‍♂️🌱

やることはシンプル！“掃除の型”を体に入れる😄✨

1. `docker system df` を実行して現状メモ📝
2. `docker image ls` でイメージ一覧を見る👀
3. `docker image ls --filter "dangling=true"` で <none> があるか確認👻
4. あれば `docker image prune` で掃除🧹
5. もう一回 `docker system df` で変化を見る📉

できたら勝ち🏆🎉

---

## 9) AI活用プロンプト集（コピペOK）🤖✨

### プロンプトA：削除候補の優先順位を決めてもらう🥇

```text
docker system df -v の結果を貼るので、
初心者でも安全な順番で「どれを消すと効果が大きいか」を3段階で提案して。
注意点（遅くなる・復旧方法）も短く添えて。
```

### プロンプトB：「これ消していい？」判断を会話形式にする🧑‍🏫

```text
docker image ls の結果を貼るから、
「消して良い/保留/残す」を会話形式で仕分けして。
仕分け基準も一緒に。
```

### プロンプトC：コマンド短縮チートシート作成📄

```text
Windows + Docker Desktop 環境で、
イメージの確認→掃除→確認までの最短コマンドセットを
5行くらいのチートシートにして。
```

### プロンプトD：エラー文の翻訳＆次の一手🔍

```text
このエラー文を初心者向けに日本語で要約して、
次に確認すべきコマンドを上から順に3つ教えて。
（エラー文貼ります）
```

---

## 10) 章末チートシート（これだけ覚えればOK）🧠⚡

```bash
## どれが容量食ってる？
docker system df
docker system df -v

## イメージ一覧
docker image ls
docker image ls -a

## dangling（<none>）だけ見る
docker image ls --filter "dangling=true"

## danglingだけ掃除（安全）
docker image prune

## 未使用も掃除（慎重に）
docker image prune -a

## 古いものだけ掃除（さらに安全）
docker image prune -a --filter "until=168h"

## ピンポイント削除
docker image rm <IMAGE_ID>
```

---

## 次章へのつながり 🚀

第05章で「溜まったものを安全に片付ける」力が付くと、
この先 Dockerfile / Compose をガンガン回しても、PCが苦しくなりにくいです😄✨

次は第06章（logs）で「困ったらまずログ！」を身につけて、トラブル対応力を上げよう🪵👀🔥

---

※ 本章の内容は Docker の公式CLIリファレンスと prune/df/prune関連ドキュメントに基づいて構成しています。([Docker Documentation][4])

[1]: https://docs.docker.com/reference/cli/docker/image/ls/?utm_source=chatgpt.com "docker image ls"
[2]: https://docs.docker.com/reference/cli/docker/system/df/?utm_source=chatgpt.com "docker system df"
[3]: https://man.archlinux.org/man/docker-image-ls.1.en?utm_source=chatgpt.com "docker-image-ls(1) - Arch manual pages"
[4]: https://docs.docker.com/engine/manage-resources/pruning/?utm_source=chatgpt.com "Prune unused Docker objects"
[5]: https://docs.docker.com/reference/cli/docker/image/prune/?utm_source=chatgpt.com "docker image prune"
[6]: https://docs.docker.com/reference/cli/docker/image/rm/?utm_source=chatgpt.com "docker image rm"
[7]: https://docs.docker.com/reference/cli/docker/builder/prune/?utm_source=chatgpt.com "docker builder prune"
[8]: https://docs.docker.com/build/cache/garbage-collection/?utm_source=chatgpt.com "Build garbage collection"
[9]: https://docs.docker.com/reference/cli/docker/system/prune/?utm_source=chatgpt.com "docker system prune"
[10]: https://docs.docker.jp/config/pruning.html?utm_source=chatgpt.com "使用していない Docker オブジェクトの削除（prune）"
[11]: https://github.com/microsoft/WSL/issues/4699?utm_source=chatgpt.com "WSL 2 should automatically release disk space back to the ..."
[12]: https://btburnett.com/docker/2021/09/06/reclaiming-hd-space-from-docker-desktop-on-wsl-2.html?utm_source=chatgpt.com "Reclaiming HD Space from Docker Desktop on WSL 2"
