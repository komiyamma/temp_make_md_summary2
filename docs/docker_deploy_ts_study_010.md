# 第10章：.dockerignore：速さと安全の地味王 👑🧹

「なんかDocker build遅い…😵」「うっかり秘密ファイル入ってそうで怖い…😱」
この2つ、**.dockerignore でかなり解決**します✨

---

## この章でできるようになること 🎯✨

* `docker build` が遅くなる“真犯人”＝**ビルドコンテキスト**を説明できる 📦🕵️
* **.dockerignore を自分のプロジェクトに合わせて書ける** 📝✅
* **秘密情報（.env とか）を混入させない習慣**がつく 🔒🧯

---

## 10.1 .dockerignore は「荷物を減らす袋」だよ 📦➡️🪶

`docker build .` をやると、Docker はまず **“ビルドに使う材料一式（＝ビルドコンテキスト）”** を集めます。
このとき `.dockerignore` があると、**いらないファイルを事前に落としてから**ビルダーへ送ります🚚💨
結果として **ビルドが速く**なるし、**余計なもの（秘密・巨大ログ等）が混ざりにくく**なります✨ ([Docker Documentation][3])

さらに最近の Docker Build / BuildKit は、**コンテキスト転送を賢く省略したり、差分転送**をしたりもします。とはいえ「そもそも送らない」効果が強いので、`.dockerignore` はまだまだ重要です⚡ ([Docker Documentation][4])

---

## 10.2 .dockerignore の基本ルール（ここだけ覚えれば勝ち）🏆📝

## 置き場所 📍

* `docker build` すると、**コンテキストのルート**にある `.dockerignore` を探して使います。 ([Docker Documentation][3])

## 書き方 📜

* **1行＝1パターン**（Unix の glob っぽい書き方） ([Docker Documentation][3])
* `#` で始まる行はコメント（無視される）💬 ([Docker Documentation][3])
* 先頭/末尾の `/` は基本あまり気にしなくてOK（無視される扱い）✂️ ([Docker Documentation][3])
* `**` は **“何階層でも”**にマッチする特別ワイルドカード 🌲🌲🌲 ([Docker Documentation][3])

  * 例：`**/*.log` → どこにある `.log` でも対象
* `!` は **除外の例外（戻す）** ✅ ([Docker Documentation][3])

  * しかも **後に書いたルールが勝つ**（順番が超大事）🔥 ([Docker Documentation][3])

## ちょい注意ポイント ⚠️

* `.dockerignore` で除外したファイルは、**ビルド材料から消える**ので、`COPY`/`ADD` しようとしても **ビルドエラー**になります😵 ([Docker Documentation][5])
  → 「あ、これコンテキストに存在しないよ？」って怒られるやつです💥

---

## 10.3 コピペでOK：Node/TypeScript向け .dockerignore テンプレ 🧩✨

まずはこれを入れて、あとから調整が一番ラクです😆
（“本番イメージはDocker内で依存を入れてビルドする”想定の定番セット）

```text
## ===== 依存フォルダ（ホスト側） =====
node_modules
**/node_modules

## ===== Git・エディタ系 =====
.git
.gitignore
.vscode
.idea

## ===== ローカル設定/秘密系（事故防止） =====
.env
.env.*
*.pem
*.key
*id_rsa*
*id_ed25519*
npmrc
.yarnrc
.pnpmrc

## ===== 生成物・キャッシュ =====
dist
build
coverage
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
.cache
tmp
temp

## ===== OS系のゴミ =====
.DS_Store
Thumbs.db
```

> ポイント🙂
>
> * `node_modules` は **ほぼ毎回入れる**やつです（巨大＆いらない代表）👑 ([Docker Documentation][3])
> * `.env` や `.git` も “うっかり混入” しがちなので、早めにガード🔒 ([Docker Documentation][6])

---

## 10.4 ハンズオン：速くなるのを目で見る 👀⚡

## Step 1：いったん「遅い状態」を観察する 🐢

プロジェクトのルートで👇

```powershell
docker build --progress=plain -t demo:before .
```

出力ログのどこかに **“transferring context”** みたいな行が出ます。
ここが **デカい＝荷物が重い** ってことです📦💦（とくにリモートビルダーだと効きます） ([Docker Documentation][3])

## Step 2：.dockerignore を作って貼る 🧹

さっきのテンプレを `.dockerignore` に保存📝

## Step 3：もう一回ビルドして比較 🔥

```powershell
docker build --progress=plain -t demo:after .
```

✅ 期待する変化

* “transferring context” のサイズが **激減** 📉✨
* 体感でもビルドが **速くなる** 🚀

---

## 10.5 セキュリティ的に「地味だけど最重要」🔒🧯

`.dockerignore` の価値は速さだけじゃないです👀
**秘密ファイルが“ビルド材料に入らない”** だけで、事故率がガクッと落ちます😇✨ ([Docker Documentation][6])

ただし⚠️

* 「ビルド時に秘密が必要」なケース（プライベート依存、秘密トークンでの取得など）は、
  `.env` をコピーするんじゃなくて、**Docker Build の secrets 機能**を使う方向が安全です🔑✨ ([Docker Documentation][7])

---

## 10.6 つまずきTop6 😵‍💫🧩（めっちゃあるある）

1. **ビルドが急に失敗した（COPYできない）** 😱
   → `.dockerignore` に入れたせいで、コンテキストから消えてます。`COPY` 対象を見直すか、除外ルールを調整！ ([Docker Documentation][5])

2. `dist` を無意識に除外して、**「dist前提のDockerfile」**と衝突する 🧨
   → どっちの方式？

* Docker内でビルドするなら `dist` 除外でOK
* ホストでビルドして `dist` をコピーするなら `dist` は除外しない

3. `node_modules` を除外し忘れて、**ビルドが重すぎ問題** 🐘
   → `node_modules` と `**/node_modules` を入れよう ([Docker Documentation][3])

4. `!`（例外）を書いたのに効かない 😭
   → **順番が命**！最後にマッチしたルールが勝ちます🔥 ([Docker Documentation][3])

5. 「/foo って書いたら foo の直下だけだよね？」と思う 🙃
   → `.dockerignore` の `/` は **直感と違う動き**になりやすいので、迷ったら `--progress=plain` で確認が早いです（まず動かして確認😆） ([Docker Documentation][3])

6. `.dockerignore` に Dockerfile を書いて「隠した！」と思う 🥷
   → Dockerfile と `.dockerignore` 自体は、ビルドに必要なので送られます。しかも `COPY` もできません（＝隠し持てない） ([Docker Documentation][3])

---

## 10.7 応用：Dockerfileが複数あるなら、ignoreも分けられる 🧠✨

プロジェクトによっては

* `build.Dockerfile`（本番用）
* `lint.Dockerfile`（Lintだけ用）
* `test.Dockerfile`（テスト用）
  みたいに分けたくなりますよね🙂

そのとき Docker は **Dockerfileごとの ignore** もサポートしてます👇
`build.Dockerfile.dockerignore` みたいに **Dockerfile名をprefix**にするやつです✨ ([Docker Documentation][3])

---

## 10.8 ミニ課題（手を動かすやつ）✅🔥

* ✅ ① いまのプロジェクトで `.dockerignore` を作る
* ✅ ② `docker build --progress=plain` で **transferring context のサイズ**をメモる📝
* ✅ ③ `.env` / `.git` / `node_modules` が確実に除外されてるか確認👀
* ✅ ④ もしビルドが壊れたら「どの COPY が原因か」突き止める（超成長ポイント）💪 ([Docker Documentation][5])

---

## 10.9 Copilot / Codex に投げるプロンプト例 🤖💡

* 「このリポジトリ構成（ツリー貼る）から、.dockerignore の最適案を作って。安全優先で！🔒」
* 「Dockerfile の COPY と .dockerignore を照合して、壊れそうな箇所を指摘して😵」
* 「monorepo なんだけど、packages ごとに node_modules がある。無駄なく除外するパターン教えて（** の使い方込み）🌲」
* 「“秘密が混ざりそうなファイル名”を列挙して、.dockerignore に入れる候補リスト作って🧯」

---

次の章（第11章）が「環境変数設計」なので、ここで `.env` を除外できてると超スムーズです😆🔑✨

[1]: https://chatgpt.com/c/698d59d3-aafc-83ab-9436-9edad7644682 "Docker教材の前提"
[2]: https://chatgpt.com/c/698d93d2-f6d0-83a9-b8a2-c83197780c86 "デプロイとポート設定"
[3]: https://docs.docker.com/build/concepts/context/ "Build context | Docker Docs"
[4]: https://docs.docker.com/build/buildkit/?utm_source=chatgpt.com "BuildKit | Docker Docs"
[5]: https://docs.docker.com/reference/build-checks/copy-ignored-file/?utm_source=chatgpt.com "CopyIgnoredFile | Docker Docs"
[6]: https://docs.docker.com/guides/reactjs/containerize/?utm_source=chatgpt.com "Containerize React.js application"
[7]: https://docs.docker.com/build/ci/github-actions/secrets/?utm_source=chatgpt.com "Using secrets with GitHub Actions - Docker Build"
