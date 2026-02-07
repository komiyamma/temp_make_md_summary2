# 第19章：バックアップ/リストア超入門（最小でOK）💾

この章はひとことで言うと…
**「やらかしても戻れる“保険”を、最小コストで持とう」** です🛟😄

---

## この章でできるようになること ✅😊

* **ボリューム（volume）の中身を .tar に固めてバックアップ**できる📦💾
* **バックアップから“別ボリュームへ”リストアして動作確認**できる🧪🔁
* DBを使い始めたときに、**より安全なバックアップ（pg_dump など）**へ移行する判断ができる🛡️🗄️

---

## まず結論：バックアップ対象は3つだけ！🎯

1. **コード**（Gitで管理）📁✨
2. **設定**（compose.yml / .env など）⚙️🧾
3. **データ**（DBやアップロード等＝volumeに入るやつ）🗃️💥

この章は **3) データ（volume）** を守るのがメインだよ！😄

---

## “最小でOK”のバックアップ方針（超現実）🧠✨

### 方針A：volumeを丸ごと固める（tar）📦➡️💾

* 速い・簡単・覚えやすい👍
* ただし **DBが動きながら**だと“状態がズレる”可能性がある（開発なら停止してからが安全）⚠️
  Docker公式も、volumeを別コンテナでマウントして tar する方法を紹介してるよ。([Docker Documentation][1])

### 方針B：DBはDBの道具でダンプする（例：Postgresなら pg_dump）🛡️🗄️

* ちょい手間だけど **整合性が高い**✨
  `pg_dump` はDB全体をエクスポートして、`pg_restore` で戻すのが基本の流れだよ。([PostgreSQL][2])

---

## ちょい重要：バックアップ置き場のおすすめ 🗂️🚀

bind mountのパフォーマンスやファイル変更検知の安定性のために、**プロジェクト（＋バックアップ）をWSL側ファイルシステムに置く**のが推奨されてるよ（公式のbest practices）。([Docker Documentation][3])

---

## ハンズオン①：volumeを tar でバックアップする（最小セット）💾📦😄

## 0) どのvolumeを守る？を見つける🔎

まず一覧を見る：

```bash
docker volume ls
```

Composeを使ってる場合は、**プロジェクト名が先頭につく**ことが多いよ（例：`todo_postgres-data` みたいに）🙂

---

## 1) バックアップ用フォルダを作る📁✨

```bash
mkdir -p ./_backup
```

（本当は日付フォルダにすると神運用だけど、ここでは最小でOK👍）

---

## 2) バックアップを取る（volume名を直接マウントする版）📦💾

例：volume名が `todo-db-data` だとするね。

```bash
docker run --rm \
  -v todo-db-data:/dbdata \
  -v "$(pwd)/_backup":/backup \
  ubuntu \
  tar cvf /backup/todo-db-data.tar /dbdata
```

* `todo-db-data:/dbdata` ← バックアップしたいvolumeを `/dbdata` にくっつける
* `$(pwd)/_backup:/backup` ← バックアップファイルの保存先
* `tar cvf ...` ← 固める📦

この「別コンテナでvolumeをマウントしてtarする」流れ自体は、Docker公式のvolumeバックアップ手順と同じ発想だよ。([Docker Documentation][1])

---

## 3) “取れた気になる”を防ぐ：中身チェック👀✅

```bash
ls -lh ./_backup
tar tf ./_backup/todo-db-data.tar | head
```

---

## 4) いちばん大事：別volumeにリストアしてテストする🧪🏥✨

### 4-1) テスト用の空volumeを作る

```bash
docker volume create todo-db-data-restoretest
```

### 4-2) リストア（展開）

```bash
docker run --rm \
  -v todo-db-data-restoretest:/dbdata \
  -v "$(pwd)/_backup":/backup \
  ubuntu \
  bash -c "cd /dbdata && tar xvf /backup/todo-db-data.tar --strip 1"
```

この `--strip 1` は、`/dbdata` まで含めて固めたときに階層を整えるためのテクだよ👍
（Docker公式のリストア例も “展開して戻す” って流れを紹介してるよ）([Docker Documentation][1])

### 4-3) 中身を確認する（検証）

```bash
docker run --rm -v todo-db-data-restoretest:/dbdata ubuntu ls -la /dbdata | head
```

👑 ここまでできたら、バックアップは「使える保険」になった！🛟🎉

---

## ハンズオン②：DBは “DBのバックアップ” を使う（Postgres例）🗄️🛡️✨

> 将来ComposeでDBを動かし始めたら、**tarよりこっちが本命**になりやすいよ🙂

## 1) pg_dumpでバックアップを作る💾

`pg_dump` は、DBをエクスポートして保存するコマンドだよ。([PostgreSQL][2])

例：DBコンテナ名が `todo-db`、DB名が `todo` の場合：

```bash
docker exec -t todo-db pg_dump -U postgres -Fc todo > ./_backup/todo.dump
```

* `-Fc`（custom形式）は `pg_restore` で扱いやすい（選択復元や再構築がやりやすい）🧰✨([PostgreSQL][2])

## 2) pg_restoreで戻す🔁

`pg_restore` は `pg_dump` の（custom等の）バックアップを復元する道具だよ。([PostgreSQL][4])

例（ざっくり復元）：

```bash
cat ./_backup/todo.dump | docker exec -i todo-db pg_restore -U postgres -d todo
```

※ ここはDB状態（DBが存在するか等）でコマンドが変わるので、困ったらAIに「自分のcompose.ymlと状況」を貼って最短手順に整えてもらうのが早い🤖💨

---

## よくある事故と回避テク（初心者がハマるやつ）🪤😵‍💫➡️😄

## 事故1：DB動かしたままtarして、戻したら壊れたっぽい🤯

✅ 回避：**バックアップ中はDBを止める**（開発ならこれで十分）

* 例：`docker stop <db-container>` とかね🛑

## 事故2：バックアップはあるのに、戻したことがない😇

✅ 回避：この章の通り **“別volumeへ復元テスト”** をやる🧪✨
→ 「戻せる」ことが証明されて初めてバックアップ💯

## 事故3：Windows側パスでマウントして遅い＆ハマる🐢

✅ 回避：WSL側に置くと快適（公式推奨）🚀([Docker Documentation][3])

---

## AI活用（この章はAIが強い！）🤖✨

## 1) “自分用の短縮手順”を作らせる✂️📝

**プロンプト例：**

* 「`todo-db-data` をバックアップして、別volumeへリストア検証するコマンドだけ、最短の3本にして」
* 「PowerShellで実行する版に書き換えて（パス表現も含めて）」

## 2) 自動化スクリプトにする🧰

**プロンプト例：**

* 「上の手順を `backup-volume.sh` にして。失敗したら即終了、成功したらファイルサイズ表示もつけて」

---

## ミニチェックテスト（5問）📝😄

1. バックアップ対象を3つ言える？（コード/設定/データ）
2. volumeバックアップで、**“別volumeに復元テスト”**が大事な理由は？
3. DBはtarより何が安全になりやすい？（例：pg_dump）
4. `docker volume ls` は何を見るコマンド？
5. WSL側に置くと嬉しいことを1つ言える？（パフォーマンス/変更検知など）([Docker Documentation][3])

---

## まとめ：この章のゴール🏁🎉

* volumeを **tarでバックアップ**できた📦💾
* **別volumeへリストアして検証**できた🧪✅
* DBが入ったら **pg_dump/pg_restore みたいな“DB正規ルート”**も選べるようになった🛡️🗄️([PostgreSQL][2])

---

次の章（第20章）では、ここまでの知識を使って **「個人開発の“データ運用ルール”を1枚にする」**よ📜✨
「消してOK/NG」「戻し方」「seed方針」まで、迷わない状態にしよ〜！😄🔥

[1]: https://docs.docker.com/engine/storage/volumes/ "Volumes | Docker Docs"
[2]: https://www.postgresql.org/docs/current/app-pgdump.html?utm_source=chatgpt.com "PostgreSQL: Documentation: 18: pg_dump"
[3]: https://docs.docker.com/desktop/features/wsl/best-practices/ "Best practices | Docker Docs"
[4]: https://www.postgresql.org/docs/current/app-pgrestore.html?utm_source=chatgpt.com "Documentation: 18: pg_restore"
