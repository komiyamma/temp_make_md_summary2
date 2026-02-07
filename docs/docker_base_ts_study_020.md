# 第20章：ミニまとめ：個人開発の“データ運用ルール”を作る📜✨

この章はズバリ「事故っても復帰できる“自分ルール”を1枚にまとめる回」だよ😊✨
Docker開発って、動けば勝ち🏆…なんだけど、**データが消えた瞬間に地獄**になるので、ここで“保険”を作っちゃおう💾🛟

---

## 0) 今日つくる成果物（これがゴール）🎯📝

あなたのTodo APIを題材に、次の2つを完成させるよ✨

* **DATA_RULES.md**：データの扱い（消してOK/NG、バックアップ頻度、seed方針）
* **RESTORE_RUNBOOK.md**：復旧の手順（バックアップ→リストア→起動確認）

「未来の自分」が読んで、**迷わず戻せる**状態にするのがポイント😄👍

---

## 1) まず知っておく“危険ボタン”3つ💣😇

事故りやすいのはこのへん👇

1. `docker compose down -v`（**-v が付くとボリューム消える**ことがある😱）
2. `docker volume prune`（未使用ボリュームを一括削除🧹）
3. “ボリュームの実体フォルダを直接いじる”（**非推奨**：壊れる可能性）
   ボリュームは「マウントして触る」が安全だよ✅（直接触るのは未定義で壊れうる、と明記されてる）([Docker Documentation][1])

---

## 2) データ棚卸し（あなたのTodo APIには何がある？）📦🔍

まず、データをこの5種類に分けると一気に整理できるよ😊✨

### A. 消えてもOK（再生成できる）🧻

* ビルド成果物（distなど）
* キャッシュ類
  -（方針によっては）開発用ログ

### B. 消えると困る（守る）🛡️

* DBデータ（Postgres/MySQLなどの永続データ）
* アップロードファイル（画像など）
* 手で作った検証データ（再現が大変なやつ）

### C. “seedで復活できる”系🌱

* 開発DBの初期データ（テスト用ユーザー、初期Todoなど）
* これは「壊して作り直す」運用に向く👍

### D. コード（Gitにある）📚

* ソースコード、設定（Composeファイル等）
* 原則バックアップより「Gitが正」✅

### E. 依存（node_modules問題）📦😵

* 置き場所の方針がブレると事故りがち
  → ここは“自分ルール”で固定するのが勝ち🏆

---

## 3) 現状確認コマンド（棚卸しの“証拠”を取る）🧾👀

まず、ボリュームが何あるか見る👇

```bash
docker volume ls
docker compose ps
docker compose config
```

* 「どのサービスがどのボリュームを使ってるか」は `docker compose config` が超便利だよ😊

> ちなみに、ボリュームは永続化の第一候補で、バックアップもしやすい（bind mountより楽）と公式でも説明されてるよ💡([Docker Documentation][2])

---

## 4) “1枚ルール”のテンプレ（コピペして埋めるだけ）📜✨

`DATA_RULES.md` を作って、まずこれを貼って埋めよう😄✍️

```md
## Todo API - データ運用ルール v1.0 📜✨

## 1. 消してOK（再生成できる）🧻
- [ ] dist / build成果物（生成物）
- [ ] キャッシュ（例：.cache など）
- [ ] （任意）開発ログ（必要なら残す）

## 2. 消したらダメ（守る）🛡️
- [ ] DBデータ（ボリューム：__________）
- [ ] アップロード（ボリューム or ディレクトリ：__________）
- [ ] その他（例：__________）

## 3. seed方針（開発を速くする）🌱
- seedの正体：__________（例：SQL / Prisma seed / 自作スクリプト）
- seed投入コマンド：__________
- 方針：DBが壊れたら「seedで作り直す」/「バックアップから戻す」どっち？ → _________

## 4. バックアップ方針 💾
- バックアップ対象ボリューム：
  - DB：__________
  - uploads：__________
- いつ取る？
  - [ ] 週1
  - [ ] 重要作業の前（例：Dockerfile/Compose大改造）
  - [ ] リリース前
- 保管先：__________（例：cloud drive / 外付け / 別PC）

## 5. 禁止事項（事故防止）💣
- [ ] docker compose down -v を雑に打たない
- [ ] docker volume prune は“対象確認してから”
- [ ] ボリュームの実体フォルダを直接編集しない
```

---

## 5) 最小バックアップ＆リストア（“戻せる”を確定させる）🛟💾

ここは公式ドキュメントに載ってる方法が安心✅
「一時コンテナを作って、tarで固める」やつだよ📦
（例では `--volumes-from` を使ってる）([Docker Documentation][2])

### 5-1) バックアップ（例：DBボリュームを固める）📦➡️💾

**あなたのボリューム名**を `todo_db_data` みたいに読み替えてね👇

```bash
mkdir -p backup

## 例：todo_db_data を backup/todo_db_data.tar に保存
docker run --rm \
  --mount source=todo_db_data,target=/data \
  -v "$(pwd)/backup:/backup" \
  ubuntu \
  tar cvf /backup/todo_db_data.tar /data
```

### 5-2) リストア（例：バックアップから戻す）💾➡️📦

```bash
docker run --rm \
  --mount source=todo_db_data,target=/data \
  -v "$(pwd)/backup:/backup" \
  ubuntu \
  bash -c "cd /data && tar xvf /backup/todo_db_data.tar --strip 1"
```

> 公式例は「`--volumes-from` + tar」で同じ考え方だよ😊([Docker Documentation][2])

---

## 6) 復旧手順書（Runbook）を完成させよう🧯📘

`RESTORE_RUNBOOK.md` に、これを貼って埋めよう👇

```md
## Todo API - 復旧手順（Runbook）🧯📘

## 0. 事故の種類を選ぶ😵
- [ ] DBだけ壊れた
- [ ] uploadsだけ壊れた
- [ ] ぜんぶ壊れた（最悪）

## 1. まず止める🛑
docker compose down

## 2. ボリュームを戻す（必要なものだけ）💾➡️📦
- DB：backup/__________.tar を使用
- uploads：backup/__________.tar を使用

## 3. 起動する🚀
docker compose up -d

## 4. 動作確認✅
- [ ] APIのヘルスチェック
- [ ] DB接続OK
- [ ] サンプルTodoが読める

## 5. 追記メモ📝
- 原因：
- 再発防止：
```

---

## 7) 速くするコツ：bind mountの置き場所（Windowsで体感差が出る）⚡🪟

ソースコードをコンテナにbind mountする時、ファイル配置で速度とホットリロードが変わりやすいよ😵
公式のベストプラクティスとして「Linux側ファイルシステムに置くと速い」「inotify（変更検知）も安定」って明記されてる✅([Docker Documentation][3])

これを `DATA_RULES.md` の「備考」に1行だけ入れとくと未来の自分が助かる😊✨

---

## 8) さらに保険：Docker Desktop自体が壊れた時の考え方🧯🧊

「Docker Desktopが起動しない😭」みたいなケース向けに、公式に“バックアップ/リストア”手順があるよ。
普段はボリューム（DBなど）を別途バックアップしておけば十分なことが多いけど、**引っ越し・復旧**の時に役立つ👍([Docker Documentation][4])

---

## 9) AIの使いどころ（ここで使うと気持ちいい）🤖✨

この章はAIとの相性が最高👍（文章整形・チェックリスト化が得意！）

* GitHub Copilot向け：
  「このDATA_RULES.mdを、初心者が迷わない文章に整形して。見出しは短く、箇条書き多め、注意点は⚠️で強調して」

* OpenAI 系AI向け：
  「このRunbookに“ありがちな失敗トップ5”と、その回避策を追記して。コマンド例も添えて」

* Microsoft 系のWSL/Windows周り：
  「このバックアップコマンドを“自分の環境でコピペで動く形”に調整して。パスの違いで事故らないよう注意点も付けて」

* Docker 公式準拠チェック：
  「このバックアップ方針が危険じゃないか、Docker公式の考え方（ボリュームの扱い）に照らしてレビューして」

---

## 10) 仕上げチェック（“卒業テスト”）🎓✅

次の質問にスラスラ答えられたら、この章はクリアだよ😄🎉

* 「消してOKなデータ」と「守るデータ」、あなたのTodo APIでそれぞれ何？🧠
* DBが壊れた時、**seedで戻す**？ **バックアップで戻す**？どっち？（使い分けも）🌱💾
* `docker compose down -v` が危険な理由を説明できる？💣
* バックアップtarを作って、別PCでも復旧できるイメージが持てる？🛟

---

## 次章につながる一言🌈

この“データ運用ルール”があると、第21章以降（ネットワーク＆Compose）で構成が複雑になっても怖くなくなるよ💪😆✨

[1]: https://docs.docker.com/engine/storage/ "Storage | Docker Docs"
[2]: https://docs.docker.com/engine/storage/volumes/ "Volumes | Docker Docs"
[3]: https://docs.docker.com/desktop/features/wsl/best-practices/ "Best practices | Docker Docs"
[4]: https://docs.docker.com/desktop/settings-and-maintenance/backup-and-restore/ "Backup and restore data | Docker Docs"
