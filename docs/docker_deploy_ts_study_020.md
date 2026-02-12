# 第20章：タグ戦略：latest地獄を回避 😇🏷️

この章は「どれが本番？😵」を**二度と起こさない**ための回だよ！
結論から言うと、**デプロイは “タグ” じゃなく “ダイジェスト（@sha256…）固定” が最強**です🔒✨（タグは便利だけど、動く＝危ない時がある）

---

## この章のゴール 🎯

* `latest` を“便利タグ”として扱いつつ、**事故らない運用**にする ✅
* **タグ（mutable）** と **ダイジェスト（immutable）** を区別できる ✅
* **個人開発でも破綻しないタグ規約**を作る ✅
* **GitHub Actionsでタグを自動生成**して、手作業をなくす ✅

---

## 1) まず怖い話：`latest` が地雷な理由 💣

`latest` は「最新っぽい」けど、実は **“最新版” を意味しない**し、そして何より **上書きできる（＝中身が変わる）** のが本質的に危険😱
これがいわゆる **「latest地獄」**：

* 昨日デプロイしたのと同じ `:latest` を指定してるのに、今日引っ張ったら**中身が違う**
* 「動いてたのに急に壊れた」→ 原因が **タグの上書き** だと気づきにくい
* ロールバックしたいのに「昨日のlatestって何？」ってなる 😇

こういう「タグが突然変異する」現象は、セキュリティ的にも運用的にも危険って話が昔からあります。([sysdig.com][1])

---

## 2) 基礎：タグ 🏷️ とダイジェスト 🔒 の違い

## タグ（例：`app:latest` / `app:v1.2.3`）

* **人間に優しい名前**
* でも基本は **付け替え可能（mutable）**
  → 同じタグ名が別のイメージを指すことがある

## ダイジェスト（例：`app@sha256:...`）

* イメージ内容のハッシュで、**完全に固定（immutable）**
* つまり「いつ pull しても同じもの」を保証できる🎯 ([Docker Documentation][2])
* OCIの世界でも参照は **tag または digest** で扱えます ([oras.land][3])

---

## 3) 個人開発で“破綻しない”タグ設計：おすすめ最小セット 🧩

ここからは「最小で強い」やついくよ🔥

## ✅ 推奨セット（まずこれだけでOK）

1. **コミットSHAタグ**：`sha-<短いSHA>`（例：`sha-a1b2c3d`）

   * “このソースの成果物”が一発で特定できる
2. **ブランチタグ**：`main`（または `master`）

   * “今の開発の先頭” を指す動くタグ（CI用）
3. **リリースタグ（SemVer）**：`v1.2.3`

   * “人間のバージョン”として残す（配布・告知にも便利）

> `latest` は「付けてもいい」けど、**“デプロイに使わない”** をルール化すると超安全😇

---

## 4) 「タグ規約」を1枚にまとめる 📄✨（コピペ用）

最低限、これだけ決めると強いよ👇

* **CIで必ず付けるタグ**

  * `sha-<shortsha>`
  * `main`（mainブランチ時だけ）
* **リリース時に付けるタグ**

  * `vX.Y.Z`（Gitタグ `v*.*.*` のとき）
* **禁止**

  * すでに存在する `vX.Y.Z` を上書きしない（＝同じバージョンで再ビルドしない）

「上書き禁止」を仕組みで守れるレジストリもあります。たとえば **Docker Hub** は immutable tag 設定があり、`latest` も含めて “更新不可” にできます。([Docker Documentation][4])
**Amazon Web Services** の ECR も “タグを上書き不可” にする設定があります。([AWS ドキュメント][5])

---

## 5) ハンズオン：GitHub Actionsでタグを自動生成 🤖🏷️

ここが本番！
やりたいことはシンプル👇

* push したら自動で build
* `sha-xxx` と `main`（mainだけ）を付けて push
* さらに `v1.2.3` の Gitタグを切ったら、`v1.2.3` を付けて push

GitHub の公式ドキュメントでも、コンテナのビルド＆pushの流れ、そして **ActionsはSHAピン推奨**（改ざんリスクを減らす）という方針が明記されています。([GitHub Docs][6])
また、タグ生成は **Docker公式の “metadata-action”** を使うのが王道です。([Docker Documentation][7])

---

## 5-1) まずはレジストリ名を決めよう 🏪

例：**GitHub Container Registry**（GHCR）を使うと楽（GitHubと相性良い）

イメージ名の例：

* `ghcr.io/<owner>/<repo>`

---

## 5-2) ワークフロー例（最小・実戦向け）🛠️

> これは「読みやすさ優先」で **タグ参照**にしてるよ。
> セキュリティ強めにしたい場合は、後で **commit SHAでピン**に切り替えるのが◎（GitHub推奨）([GitHub Docs][6])

```yaml
name: container-ci

on:
  push:
    branches: [ "main" ]
    tags: [ "v*.*.*" ]

permissions:
  contents: read
  packages: write

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Docker meta (tags/labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            # 1) コミットSHAタグ（常に付ける）
            type=sha,prefix=sha-,format=short

            # 2) mainブランチ時だけ main タグを付ける
            type=ref,event=branch

            # 3) v1.2.3 のGitタグなら、そのまま v1.2.3 を付ける
            type=semver,pattern={{version}}

          # latest を付けたい場合（付けるなら main のときだけ、くらいが無難）
          # flavor: |
          #   latest=false

      - name: Build and push
        id: build
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

ポイント解説🧠✨

* `type=sha`：**事故りにくい最重要タグ**（必ず残る）
* `type=ref,event=branch`：mainなら `:main` が付く（動くタグ）
* `type=semver`：`v1.2.3` のときに `:1.2.3` などを生成できる（metadata-actionの機能）([GitHub][8])
* `build-push-action` は Buildx/BuildKit を前提にした定番アクション ([GitHub][9])

---

## 6) デプロイは「ダイジェスト固定」が最強 🔒🚀

ここが“勝ち筋”だよ😆
タグは動くことがあるけど、ダイジェストは固定。**同じものが必ず動く**。([Docker Documentation][2])

## ダイジェスト指定の形

* `ghcr.io/owner/repo@sha256:xxxxxxxx...`

CIの `build-push-action` は **digest を出力**できるので（公式例にも `steps.push.outputs.digest` が出てる）、それをデプロイ側に渡すと鉄壁。([GitHub Docs][6])

---

## 7) ロールバックが秒でできる設計 🕐↩️

ルールがあると、戻すのも簡単👇

* 「本番は常に `@sha256:...` 固定」
* 事故ったら **ひとつ前の digest に戻す**
* もしくは **前の `vX.Y.Z` を指定**（ただし、上書きしない運用が前提）

---

## 8) つまずきTop5 😵‍💫➡️✅

1. **`latest` を本番設定に書いちゃう** → やめよう😇
2. **同じ `v1.2.3` をもう一回push** → それは別物（事故のもと）
3. **`main` タグを本番で使う** → mainは動くタグ（CI用が無難）
4. **「タグ＝固定」だと思い込む** → タグは基本“付け替え可能” ([sysdig.com][1])
5. **再現性が欲しいのにタグ運用だけで頑張る** → ダイジェスト固定に寄せる（依存も同じ発想） ([docs.renovatebot.com][10])

---

## 9) ミニ課題 ✅📝

## 課題A（超重要）🏷️

あなたのプロジェクトのタグ規約を、次の3行で書いてみて👇

* 「必ず付けるタグ：＿＿＿＿」
* 「mainのときだけ付けるタグ：＿＿＿＿」
* 「リリース時のタグ：＿＿＿＿」

## 課題B（1分でできる）🚀

`v0.1.0` の Gitタグを切って push して、レジストリに `v0.1.0` が増えるのを確認！

```powershell
git tag -a v0.1.0 -m "release v0.1.0"
git push origin v0.1.0
```

---

## 10) AIに投げると強いプロンプト集 🤖✨

* 「このリポジトリに合う Docker イメージのタグ戦略を、個人開発向けに最小構成で提案して。`latest` の扱いも含めて」
* 「この GitHub Actions を“事故りにくい”ように改善して。mainだけに `latest` を付けたい」
* 「本番を digest 固定にしたい。CIの outputs.digest をデプロイへ渡す設計案を3つ出して」
* 「ロールバック手順を、人間が迷わないチェックリストにして」

---

## まとめ 🎉

* `latest` は便利だけど、**本番の基準にしない**のが正解😇
* **タグ＝人間向け／ダイジェスト＝機械向けの確実性** 🔒
* まずは **shaタグ + mainタグ + semver** の3点セットで勝てる🏆
* 自動化は **metadata-action** が王道だよ🤖 ([Docker Documentation][7])

---

次の章（第21章）は「鍵を置かない認証：OIDC」だよね？🪪✨
第20章のワークフローをベースに、**長期キーなしでクラウドに安全ログイン**する流れに繋げると、気持ちいいくらい理解が繋がるよ〜🚀

[1]: https://www.sysdig.com/blog/toctou-tag-mutability?utm_source=chatgpt.com "Attack of the mutant tags! Or why tag mutability is a real ..."
[2]: https://docs.docker.com/dhi/core-concepts/digests/?utm_source=chatgpt.com "Image digests"
[3]: https://oras.land/docs/concepts/reference/?utm_source=chatgpt.com "Reference | OCI Registry As Storage"
[4]: https://docs.docker.com/docker-hub/repos/manage/hub-images/immutable-tags/?utm_source=chatgpt.com "Immutable tags"
[5]: https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html?utm_source=chatgpt.com "Preventing image tags from being overwritten in Amazon ECR"
[6]: https://docs.github.com/ja/actions/tutorials/publish-packages/publish-docker-images "Docker イメージの発行 - GitHub ドキュメント"
[7]: https://docs.docker.com/build/ci/github-actions/manage-tags-labels/ "Tags and labels | Docker Docs"
[8]: https://github.com/docker/metadata-action "GitHub - docker/metadata-action: GitHub Action to extract metadata (tags, labels) from Git reference and GitHub events for Docker"
[9]: https://github.com/docker/build-push-action "GitHub - docker/build-push-action: GitHub Action to build and push Docker images with Buildx"
[10]: https://docs.renovatebot.com/docker/?utm_source=chatgpt.com "Docker - Renovate Docs"
