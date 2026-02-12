# 第16章：開発では「ソースはマウント」して最速ループ🌀🧑‍💻

この章の主役は **バインドマウント（bind mount）** です🐳✨
「ローカルのソースコードをコンテナに“共有”して、保存した瞬間にコンテナ側へ反映」→ **ビルドし直し地獄から脱出**します🏃‍♂️💨
（Docker公式の入門でも、開発時は“ソースをマウントすると保存した変更が即見える”と説明されています）([Docker Documentation][1])

---

## 1) “マウント”って何がうれしいの？🎁✨

Dockerfileの `COPY . .` は「**イメージの中にコードをコピー**」するやつ📦
一方、バインドマウントは「**ホストのフォルダをコンテナに直結**」するやつ🔌

* ✅ `COPY`：本番向き（固めて配る）🏗️
* ✅ `bind mount`：開発向き（編集→即反映）🧑‍💻⚡

Docker公式の説明でも、bind mount は「ホストのディレクトリをコンテナへマウントする」方式として整理されています([Docker Documentation][2])

---

## 2) Windowsで最速にする“置き場所”のコツ🪟🐧⚡

ここが超重要ポイントです📌💥
Docker Desktop（WSL2バックエンド）では、**ソースコードは“Linux側（WSLのファイルシステム）”に置く方が速い**です🚀
さらに、**ファイル変更イベント（inotify）がちゃんと届く**ので、watch系が気持ちよく動きます👀✨

Docker公式のWSL2ベストプラクティスでも、**Windows側(`/mnt/c/...`) を避けて、Linux側のファイルシステムを使う**ことが推奨されています([Docker Documentation][3])

* 🟢 おすすめ：`\\wsl$\Ubuntu\home\<you>\projects\myapp` みたいな場所
* 🧊 できれば避けたい：`C:\Users\...\myapp`（※遅くなったり、watchが鈍ったりしがち）

> もし「無料枠で爆速にしたい」なら、**WSL内に置く**が最強です😆🔥
> なおDocker Desktopには、bind mount性能を上げる別方式（Synchronized file shares）もありますが、利用条件がプラン依存です([Docker Documentation][4])

---

## 3) まずは体験：`docker run` でソースをマウントする🐳💨

ここでは「編集→即反映」を体験するために、**srcだけをマウント**します🧠✨
（プロジェクト全体を丸ごとマウントすると、`node_modules` が絡んでハマりやすいので、そこは次章で爆破解決します💣➡️第17章へ）

### ✅ 3-1. コンテナ側の作業ディレクトリを `/app` にする📁

（Dockerfileで `WORKDIR /app` を使っている想定と相性が良いです👍）

### ✅ 3-2. 例：PowerShell で “srcだけ” マウント（安全ルート）🪟✨

```powershell
## まずはイメージを作る（依存入り）
docker build -t myapp-dev .

## srcだけをコンテナへ共有して dev 起動
docker run --rm -it -p 3000:3000 `
  --mount type=bind,src="${PWD}\src",target=/app/src `
  myapp-dev npm run dev
```

* `--mount type=bind,...` が「共有する（マウントする）」指定です📌([Docker Documentation][1])
* `src` を編集して保存すると、**コンテナ側の `/app/src` に即反映**されます🌀✨

### ✅ 3-3. 例：WSL（Ubuntu）ターミナルならこう🐧✨

```bash
docker build -t myapp-dev .

docker run --rm -it -p 3000:3000 \
  --mount type=bind,src="$(pwd)/src",target=/app/src \
  myapp-dev npm run dev
```

---

## 4) watch の動きも“今どき仕様”でいこう👀🔁

Nodeには `--watch` があって、ファイル変更で自動再起動できます♻️✨
しかも **v22.0.0 / v20.13.0 以降で stable 扱い**になっています（もちろん v24 でもOK）([Node.js][5])

たとえば `package.json` の `dev` をこんな感じにしておくと便利です👇

```json
{
  "scripts": {
    "dev": "node --watch src/index.js",
    "start": "node src/index.js"
  }
}
```

---

## 5) “マウントできてるか”一瞬で確認する✅👀

「反映されない…😢」って時は、まず **中身が見えてるか**を確認します💡

```powershell
docker run --rm -it `
  --mount type=bind,src="${PWD}\src",target=/app/src `
  node:24-bookworm-slim bash -lc "ls -la /app/src"
```

* ここで `/app/src` にファイルが見えてたら、マウント自体は成功🎉
* 見えてないなら **srcパスの指定ミス**が多いです（`src=` の部分を疑う）🔍

---

## 6) ありがちトラブル集（ここだけ見ればだいたい勝てる）🧯🔥

### ❌ 変更しても自動反映しない／watchが鈍い👀💦

* ✅ プロジェクトが **Windows側（Cドライブ）** にあると起きやすいです
* ✅ **WSL内に移す**と改善しやすいです（公式推奨）([Docker Documentation][3])

### ❌ とにかく遅い🐢💤

* ✅ まずは「置き場所」をWSLへ🗂️🐧（公式が“避けろ”って言うレベル）([Docker Documentation][3])
* ✅ もし契約的にOKなら、Docker Desktopの高速化機能（Synchronized file shares）も選択肢です([Docker Documentation][4])

### ❌ 依存を入れ替えたのに反映されない📦😵

* ✅ `package.json` / lockfile を変えたら、**イメージを作り直す**（`docker build ...`）が基本です🔁
  （srcだけマウントは“ソース編集専用の高速ループ”と思うと混乱しません👍）

---

## 7) この章の「できた！」判定🎯✨

* ✅ コンテナを起動したまま
* ✅ VS Codeで `src` のファイルを編集して保存すると
* ✅ コンテナ側の挙動（ログ・画面・レスポンス）が **即変わる** 🎉🌀

ここまで来たら、開発スピードが一気に上がります🔥🔥🔥

---

## 8) 次章の予告：node_modules問題💣📦➡️

次の第17章は、みんなが一度は踏む **「node_modulesをホストと混ぜて地獄」**を、**volumeで安全に分離して勝つ**回です😆✨
第16章の“速さ”に、第17章の“安定”が合体して無敵になります🛡️⚡

---

## 9) AIに投げる一言（デバッグ爆速）🤖⚡

* 「WindowsのPowerShellで、srcだけをbind mountして `npm run dev` を回す `docker run` を作って。改行はバッククォートで」
* 「watchが反応しない。WSL2前提で“置き場所”とコマンドの見直しチェックリスト作って」

---

必要なら、第16章の実習を **“最小API（Node/TS）”** で丸ごとテンプレとして（ファイル構成＋コマンド＋確認用curlまで）作って出します🐳📦✨
次に進めるなら「第17章（node_modulesをvolumeに隔離）」もセットで一気に完成形にしちゃいましょう😆🔥

[1]: https://docs.docker.com/get-started/workshop/06_bind_mounts/?utm_source=chatgpt.com "Part 5: Use bind mounts"
[2]: https://docs.docker.com/engine/storage/bind-mounts/?utm_source=chatgpt.com "Bind mounts"
[3]: https://docs.docker.com/desktop/features/wsl/best-practices/?utm_source=chatgpt.com "Best practices"
[4]: https://docs.docker.com/desktop/settings-and-maintenance/settings/?utm_source=chatgpt.com "Change your Docker Desktop settings"
[5]: https://nodejs.org/api/cli.html?utm_source=chatgpt.com "Command-line API | Node.js v25.6.1 Documentation"
