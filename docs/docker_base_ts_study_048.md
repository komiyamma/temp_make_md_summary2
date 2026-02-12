# 第48章：ビルド（build）とタグ運用（名前の付け方）🏷️

今日は **「イメージを作る（build）」→「ちゃんと名前を付けて管理する（tag）」** を、手を動かして身につける回だよ😆✨
（※2026-02-13 時点の Docker 最新ドキュメントを踏まえて構成してるよ📚）([Docker Documentation][1])

---

## 0) 今日のゴール🎯✨

この章が終わったら、次のことができれば勝ち🏆

* `docker build` で Todo API のイメージを作れる🐳
* `-t`（タグ）で **dev/prod/release** を名前で区別できる🏷️
* `docker tag` で **「付け替え」「別名追加」** ができる🔁
* **`:latest` 事故** を避ける“自分ルール”を作れる🚫😵

---

## 1) まずは超重要：タグって何？（1分でわかる）⏱️🧠

## イメージの名前はこういう形👇

* `名前:タグ`
  例：`todo-api:dev` / `todo-api:prod` / `todo-api:0.1.0`

タグはイメージに貼る **“付箋”** みたいなもの🏷️✨
同じイメージに **複数のタグ** を付けられるよ（別名を増やせる）🪄

## じゃあ「完全に同じもの」を指す識別子は？🤔

それが **digest（ダイジェスト）**（`sha256:...`）だよ🔒
digest は内容のハッシュで、**同じ内容なら同じ**・**違えば別物**になるやつ💡
タグは付箋（変えられる）だけど、digest は指紋（ほぼ固定）って感じ👍
OCI の仕様でも、Tag と Digest は別物として定義されてるよ📘([https://opencontainers.github.io][2])

---

## 2) `:latest` の正体（ここで事故が減る）💣➡️🛟

よくある勘違い😇

* 「`:latest` って “最新バージョン” でしょ？」
  → **違うことが多い** 😵‍💫

`:latest` は **“そのレジストリに最後に push されたもの”** ってだけで、
「最新版」や「安定版」を保証しないよ〜って Docker 側も注意してる🧯([Docker][3])

なのでこの教材では基本こうする👇

* **ローカル用**：`dev` / `prod`（分かりやすさ重視）
* **リリース用**：`0.1.0` みたいに “具体的な番号” を付ける（再現性重視）

---

## 3) build の今どき事情：BuildKit が基本🧰⚡

Docker のビルドは今は **BuildKit** が標準になってて、Docker Desktop でもデフォルトだよ✨
（ビルドが速い・キャッシュが賢い・いろいろ便利）([Docker Documentation][4])

---

## 4) ハンズオン：dev と prod を “タグで” 管理する🏷️🧪

前章で Dockerfile を **dev/prod のステージ**に分けたよね（ここを使うよ）🎭

ここからは「タグで迷子にならない」を体に覚えさせる💪😆

---

## Step A：まずは基本の build（タグ付き）🏗️🏷️

プロジェクトのルート（Dockerfile がある場所）で👇

```powershell
## dev 用イメージを作る（ステージ dev を選ぶ）
docker build -t todo-api:dev --target dev .

## prod 用イメージを作る（ステージ prod を選ぶ）
docker build -t todo-api:prod --target prod .
```

ポイント✅

* 最後の `.` は **ビルドコンテキスト**（“このフォルダの中身を材料にする”）だよ📦
* `--targるか** を選ぶスイッチ🎛️

---

## Step B：イメージ一覧で「名前が付いた！」を確認👀✨

```powershell
docker image ls
```

`todo-api` が出てきて、`dev` と `prod` が付いてたらOK🎉

---

## Step C：動かしてみる（タグで起動先が変わる）▶️🐳

```powershell
## dev を起動（例：3000）
docker run --rm -p 3000:3000 todo-api:dev

## 別ターミナルで prod を起動して比較したいなら、ポートを変える（例：3001）
docker run --rm -p 3001:3000 todo-api:prod
```

* `todo-api:dev` と `todo-api:prod` を **名前で選べる**のが最高にえらい🏷️✨
* これで「あれ？どっち動かしてるんだっけ？」事故が減る😆

---

## 5) “おすすめタグ設計” テンプレ（個人開発で強い）📏🧩

ここは超実戦的にいくよ💪🔥
Todo API なら、まずこの3段で十分✨

## レベル1：ローカル運用（迷子防止）🧭

* `todo-api:dev`
* `todo-api:prod`

## レベル2：リリース運用（再現性）🔁

* `todo-api:0.1.0`（SemVerっぽく具体的に）
* `todo-api:0.1`（大枠の互換ラインを指す用 ※任意）

## レベル3：追跡用（いつのビルドか分かる）🕵️‍♂️

* `todo-api:git-abc1234`（コミット短縮SHA）
* `todo-api:2026-02-13`（日付）

**コツ**💡

* 「人間が読めるタグ」＋「戻せるタグ」＝強い🏋️‍♂️
* `latest` は“使ってもいいけど信用しない”くらいが安全🚫([Docker][3])

---

## 6) `docker tag` で「別名を増やす」練習🔁🏷️

たとえば、今の `prod` を「0.1.0」として固定したいなら👇

```powershell
## 既存イメージに “別のタグ” を追加する（コピーじゃなくて同じものに別名）
docker tag todo-api:prod todo-api:0.1.0
```

確認👇

```powershell
docker image ls todo-api
```

ここで大事な感覚😊✨

* `todo-api:prod` と `todo-api:0.1.0` が **同じ IMAGE ID** を指してたら、
  「同じ中身に付箋が2枚」状態だよ🏷️🏷️

---

## 7) digest を見て「同一性」を確認（ちょい上級だけど効く）🔒👀

「タグは変えられる」＝「厳密には不安」って場面があるよね😵
そういう時は digest を見ると安心✨

```powershell
docker image inspect todo-api:0.1.0
```

出力の中に `RepoDigests` とか `sha256:...` が見えるはず🔍
digest で参照すると **“これそのもの”** を指せる（強い）💪
digest の考え方は OCI/クラウドの解説でも「不変の識別子」として扱われてるよ📘([https://opencontainers.github.io][2])

---

## 8) ビルドが「反映されない😵」ときの対処3点セット🧯

## ① ベースイメージも新しくしたい

```powershell
docker build --pull -t todo-api:prod --target prod .
```

## ② キャッシュ無視で作り直したい（最終手段）

```powershell
docker build --no-cache -t todo-api:prod --target prod .
```

## ③ そもそも `.` を忘れてる（あるある）

```powershell
## ❌ docker build -t todo-api:prod --target prod
## ✅ docker build -t todo-api:prod --target prod .
```

BuildKit はキャッシュが賢いぶん、「あえて更新したい」時だけスイッチを使うのがコツだよ⚡([Docker Documentation][4])

---

## 9) ちょい未来の話：マルチプラットフォーム🏗️🌍（知ってると得）

今どきは `linux/amd64` と `linux/arm64` を同時に作ることも多いよ〜ってやつ🐳
このへんは **buildx** が担当で、Docker 公式にも手順がある📘([Docker Documentation][5])

今日は深入りしないけど、将来「クラウド配布」するときに効いてくる💪✨

---

## 10) よくある事故あるある😇💥（先に潰す）

* **タグ付け忘れて、`latest` 扱いになって混乱**😵
  → 必ず `-t todo-api:dev` みたいに付ける🏷️([Datadog インフラ & アプリ監視][6])

* **`dev` を `prod` だと思ってデプロイ準備し始める**🎭➡️💣
  → タグを役割名にする（dev/prod/release）だけで激減👍

* **ビルド対象フォルダを間違える（コンテキスト違い）**📦😇
  → Dockerfile のある場所で build する（`.` は今いる場所）

---

## 11) AI活用（この章向け・即効プロンプト）🤖✨

* **タグ設計を作ってもらう🏷️**

  * 「Todo API の Docker イメージ用に、dev/prod/release のタグ命名規則を提案して。ロールバックしやすさ重視で！」

* **コマンドを短縮する🧪**

  * 「PowerShell 用に、dev/prod の build と run を 1発でできるコマンド集を作って（コメント付き）」

* **事故レビュー👀**

  * 「この `docker image ls` の結果から、混乱の原因になりそうなタグ運用の問題点を3つ指摘して」

---

## 12) ミニ問題（3分）🧠⏱️

1. `todo-api:prod` と `todo-api:0.1.0` が **同じ IMAGE ID** のとき、何が起きてる？🏷️
2. `:latest` が “最新版” を保証しない理由を一言で言うと？😵‍💫
3. `docker build ... .` の最後の `.` は何？📦

---

## 次（第49章）につながる一言🐢➡️🐇

タグ運用ができるようになると、次は自然に **「サイズと速度（重いを避ける）」** に進めるよ🔥
「タグで管理しつつ、イメージを軽くする」＝めちゃ実務っぽくなる😆✨

[1]: https://docs.docker.com/get-started/docker-concepts/building-images/build-tag-and-publish-an-image/?utm_source=chatgpt.com "Build, tag, and publish an image"
[2]: https://specs.opencontainers.org/distribution-spec/?v=v1.0.0&utm_source=chatgpt.com "The OpenContainers Distribution Spec"
[3]: https://www.docker.com/blog/docker-best-practices-using-tags-and-labels-to-manage-docker-image-sprawl/?utm_source=chatgpt.com "Using Tags and Labels to Manage Docker Image Sprawl"
[4]: https://docs.docker.com/build/buildkit/?utm_source=chatgpt.com "BuildKit | Docker Docs"
[5]: https://docs.docker.com/build/building/multi-platform/?utm_source=chatgpt.com "Multi-platform builds"
[6]: https://docs.datadoghq.com/security/code_security/static_analysis/static_analysis_rules/docker-best-practices/tag-image-version/?utm_source=chatgpt.com "Always tag the version of an image"
