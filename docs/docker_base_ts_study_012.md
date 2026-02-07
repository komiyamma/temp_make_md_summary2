# 第12章：マウントの基本（ホスト↔コンテナ）を体験📎

ここは「Dockerで開発がラクになる瞬間」トップクラスの章です😆🌱
**ホストで編集 → コンテナで即反映**ができると、開発スピードが一気に上がります⚡️

---

## 1) 今日のゴール🎯

* **マウント（bind mount）**で「ホストのフォルダ」を「コンテナの中」に見せられる🙂📁
* 「編集はホスト」「実行はコンテナ」を**ストレスなく**回せる🚀
* Windows環境での **パスの罠** を回避できる🪤😵

---

## 2) まず超ざっくり理解🧠✨

### マウントって何？📎

**ホストのフォルダを、コンテナのあるフォルダに“つなぐ”**ことです🙂
だから…

* ホストでファイルを保存 💾
* コンテナ側でそのファイルを読む 👀
* 変更がすぐ見える ⚡️

これが実現します😄

> 大事な注意：**マウント先のフォルダは“上書き表示”**になります。
> つまり、コンテナ側に元からあった同名フォルダの中身は「見えなくなる」ことがあります🫥（あとでハマりポイントで説明！）

---

## 3) 3分で体験ハンズオン🔥（まずは最小のやつ）

### 3-1. 作業フォルダを作る📁

ホスト側で適当にフォルダを作って、ファイルも1個作ります🙂

例：`hello.txt` に `hello mount!` と書く✍️

### 3-2. コンテナを起動して、ホストのフォルダをマウントする🐳

#### ✅ WSLターミナルでやる（おすすめ）🐧✨

WSL2上のLinuxファイルシステムにプロジェクトを置くと、**ファイル変更検知（inotify）が効きやすく、速度も出やすい**です🏎️💨（Windows側 `/mnt/c` に置くより有利）([Docker Documentation][1])

```bash
docker run --rm -it \
  -v "$PWD:/work" \
  -w /work \
  alpine sh
```

コンテナの中で👇

```sh
ls
cat hello.txt
```

### 3-3. “即反映”を確認する⚡️

コンテナを開いたまま、ホストで `hello.txt` を書き換える（例：`hello updated!`）✍️✨
そしてコンテナ側で再度👇

```sh
cat hello.txt
```

更新が見えたら勝ち🏆🎉

---

## 4) Windowsでの「置き場所」超重要ルール🪟📌

### 結論：プロジェクトは “WSL側” に置くのが強い💪🐧

Docker Desktop + WSL2では、**Linuxファイルシステム上のファイルをマウントしたほうが速い**＆**ファイル変更イベントが届きやすい**です⚡️([Docker Documentation][1])

* ✅ 例：`~/projects/todo-api`（WSLのホーム配下）
* ⚠️ 例：`/mnt/c/...`（Windowsドライブ＝DrvFs。遅くなったりイベントが弱くなりがち）([Microsoft Learn][2])

VS Codeも **Remote - WSL** で開くのが鉄板です🧑‍💻✨
（編集：Windows、ファイル実体：WSL、実行：Docker…が気持ちよく繋がる😄）

---

## 5) Todo APIで「開発っぽい」動きを体験🌱📦

ここから “育てる題材” に寄せます😆
（まだDBなしの段階でもOK！）

### 5-1. 例：Nodeコンテナで起動（コードをマウント）▶️

プロジェクトルートにいる前提で👇

```bash
docker run --rm -it \
  -p 3000:3000 \
  -v "$PWD:/app" \
  -w /app \
  node:20-bullseye \
  bash
```

コンテナ内で👇

```bash
npm ci
npm run dev
```

ホスト側でTS/JSを編集して保存→APIがホットリロードされるなら最高です😆🔥
（もしホットリロードが効かないなら “置き場所” が `/mnt/c` 側じゃないかチェック✅）

---

## 6) Windowsマウントの「あるある罠」まとめ🪤😵（超重要）

### 罠1：`/app` が空になった！？😱

**原因**：マウントは「そのフォルダを置き換える」ので、コンテナ側の `/app` に元から入ってたものが見えなくなります🫥
**対処**：マウント先は「最初から空でOK」な場所にする / 置き換え前提で設計する🙂

---

### 罠2：`node_modules` が消えた／変なフォルダができた📦💥

**原因**：`/app` をマウントすると、コンテナ内の `node_modules` がホスト側と衝突しがちです。さらに `/app` をbindしつつ `/app/node_modules` を別ボリュームにすると、ホスト側に「空の node_modules フォルダだけ」できる挙動も起きます（中身はボリューム側）🌀([Docker Community Forums][3])
**対処**：この問題は第15章でガッツリやるけど、先に結論だけ言うと👇

* 「コードはbind」＋「node_modulesは**名前付きvolume**」が定番💡（衝突回避）

---

### 罠3：変更が反映されない／ホットリロードしない😵‍💫

**原因**：Windowsドライブ（`/mnt/c`）のマウントだと、ファイル変更イベントが弱かったり遅かったりすることがある🪫([Docker Documentation][1])
**対処**：プロジェクトをWSLのLinuxファイルシステムへ移す（これが一番効く）💪

---

### 罠4：パスの書き方で死ぬ（空白・記号・引用符）🪦

**症状**：`-v` でエラー / 変な場所がマウントされる
**対処**：

* できるだけ **WSLの `$PWD`** を使う（ラク）🙂
* Windowsパス直指定は “慣れてから” でOK🙆‍♂️

---

### 罠5：改行（CRLF）でスクリプトが動かない🧨

**症状**：`/bin/sh^M: bad interpreter` とか
**対処**：VS Codeの改行設定を `LF` に寄せる、または対象ファイルだけ変換🙂
（第13章で再現して直すやつ！）

---

## 7) さらに今どきの選択肢：Compose Watch（マウント代替にもなる）👀⚡️

最近は **Docker Compose Watch** で、編集→同期→再起動/コマンド実行 を自動化できます🤖✨
公式でも「`docker compose up --watch`」が案内されています([Docker Documentation][4])

`compose.yaml` の例（雰囲気だけ掴めばOK）👇

```yaml
services:
  api:
    build: .
    ports:
      - "3000:3000"
    develop:
      watch:
        - action: sync
          path: .
          target: /app
```

さらに `sync+restart` や `sync+exec` みたいな挙動も仕様として整理されています（Composeバージョン条件つき）([Docker Documentation][5])

> ただし第12章ではまず **bind mountの感覚** を体に入れるのが最優先です😊
> Watchは「便利な強化パーツ」って感じ✨

---

## 8) AI活用コーナー🤖💬（この章と相性よすぎ）

### そのままコピペで使える質問例📌

* 「Windows + Docker Desktop + WSL2 で bind mount が反映されない。原因候補を優先度順に3つ、確認コマンドもつけて」
* 「`docker run -v` のパスが怪しい。PowerShellとWSLそれぞれで安全な書き方を教えて」
* 「node_modules が消える問題を避けたい。bind mount と volume の使い分けを “超初心者向け” に説明して」

エラー文や `docker run` のコマンドを貼ると精度が跳ね上がります📈✨

---

## 9) ミニ演習📝✨（手を動かすやつ）

### 演習A：即反映を100%体感する🔥

1. `hello.txt` をマウント
2. ホストで3回書き換え
3. コンテナで毎回 `cat` して確認
4. ついでに `ls -la` も見る👀

### 演習B：わざと失敗して直す🧪

* プロジェクトを `/mnt/c/...` に置いて同じことをやってみる
* 反映の遅さ・ホットリロード差を観察する
  → 「なんで？」を言語化できたら強い💪😆（公式にも “Linux側の方が速い” と明記）([Docker Documentation][1])

---

## 10) 理解チェック✅（サクッと）

* Q1. マウントは「コピー」？「接続」？どっち？🙂
* Q2. マウント先のフォルダは、コンテナ内の元の中身がどう見える？🫥
* Q3. WSL2環境で、プロジェクトを置くおすすめ場所はどっち？（WSL側 or /mnt/c）🐧🪟
* Q4. `/mnt/c` でホットリロードが効かない時の第一手は？🔧

---

## 次章へのつながり🔜😊

第13章は、この章で触れた **Windows特有の罠（改行/パス/権限）** を「わざと踏んで」「安全に直す」回です🪤➡️✅
ここまで来たら、もうDocker怖くなくなってきますよ😆🔥

[1]: https://docs.docker.com/desktop/features/wsl/best-practices/?utm_source=chatgpt.com "Best practices"
[2]: https://learn.microsoft.com/ja-jp/windows/wsl/wsl-config?utm_source=chatgpt.com "WSL での詳細設定の構成"
[3]: https://forums.docker.com/t/an-empty-node-modules-folder-is-being-created-at-the-host-whenever-a-container-is-spun-up/146574?utm_source=chatgpt.com "An empty node_modules folder is being created at the host ..."
[4]: https://docs.docker.com/compose/how-tos/file-watch/?utm_source=chatgpt.com "Use Compose Watch"
[5]: https://docs.docker.com/reference/compose-file/develop/?utm_source=chatgpt.com "Compose Develop Specification"
