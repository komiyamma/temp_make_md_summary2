# 第19章：GitHub Actions最小：pushでイメージができる 🔁📦

この章は **「main に push したら、自動で Docker イメージが作られてレジストリに置かれる」**ところまでやるよ〜！😆✨
（ここができると、次の章で“タグ運用”に進めるし、Cloud Run みたいな実行環境にも渡せるようになる！🚀）

---

## この章のゴール 🥅✨

* push するだけで **Docker build → push** が勝手に走る 🤖
* レジストリ（今回は GHCR）に **新しいイメージが並ぶ** ✅
* Actions の最小構成で、**権限（permissions）と認証**の超基本がわかる 🔐

---

## 1) まず全体像を1枚で🧠🗺️

```text
git push
  ↓
GitHub Actions（Ubuntuランナーが起動）
  ↓
ghcr.io にログイン（GITHUB_TOKEN）
  ↓
Docker build（Dockerfile）
  ↓
ghcr.io に push（イメージが保存される）
```

ポイントはこれ👇

* GHCR（GitHub Container Registry）に push するには、**GITHUB_TOKEN に packages:write が必要**だよ🧾✍️ ([GitHub Docs][1])
* 公式の例でも、GHCR のログインは `registry: ghcr.io` + `username: ${{ github.actor }}` + `password: ${{ secrets.GITHUB_TOKEN }}` が推奨されてるよ✅ ([GitHub Docs][2])

---

## 2) 今回は「GHCR」に置こう 🏪📦（いちばん楽！）

理由👇

* 追加のシークレットを作らなくても、**GITHUB_TOKEN だけで動かせる**（同一リポジトリのパッケージに publish する用途）🧪 ([GitHub Docs][3])
* 権限は workflow 側で **最小に絞れる**（contents:read / packages:write）🔐 ([GitHub Docs][1])

> ⚠️ たまにハマる罠
> **過去に同じ名前空間へ別の方法で push 済み**だと、`GITHUB_TOKEN` で push できないことがある（パッケージとリポジトリの紐付け問題）😵‍💫
> その場合は「Packages 側でリポジトリに接続」すると直るケースが多いよ。 ([GitHub Docs][3])

---

## 3) まずは“超最小”ワークフローを作る 🧩🛠️

## 手順（VS Code でOK）🪟🧑‍💻

1. リポジトリにフォルダを作る
   `.github/workflows/`
2. その中にファイルを作る
   `container-image.yml`
3. 下の YAML をコピペして commit → push！✅

---

## ✅ 超最小：build & push（タグは commit SHA）🏷️

```yaml
name: build-and-push-image

on:
  push:
    branches: ["main"]

permissions:
  contents: read
  packages: write

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Set up Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
```

### ここで何をしてるの？👀

* `permissions` で **最小権限**にする（contents read / packages write）🔐 ([GitHub Docs][1])
* `docker/setup-buildx-action` は Buildx をセットアップ（推奨）🧰 ([GitHub][4])
* `docker/build-push-action` は build & push の定番アクション 🐳📦 ([GitHub][5])

---

## 4) push したらどこを見る？✅👀

## ① Actions が通ってるか

* リポジトリの **Actions** タブ
  → `build-and-push-image` が ✅ になってたら成功！🎉

## ② イメージができたか

* リポジトリの **Packages**
  → `ghcr.io/<owner>/<repo>` が増えてたら勝ち！🏆

---

## 5) ローカルで pull して動作確認（任意だけど超おすすめ）🧪🪟

PowerShell でだいたいこんな感じ👇（※ `<...>` は自分の値に置換ね）

```powershell
docker login ghcr.io -u <GitHubUserName>
## パスワードは PAT を聞かれることがある（ローカルpull用）
## ※ Actions で push するだけなら GITHUB_TOKEN でOK

docker pull ghcr.io/<owner>/<repo>:<commitSha>
docker run --rm -p 3000:3000 ghcr.io/<owner>/<repo>:<commitSha>
```

> ローカル pull は、リポジトリやパッケージの公開/権限設定によって必要な認証が変わるよ🙏
> （“Actions で push できた”だけでもこの章は合格！💮）

---

## 6) つまずきTop5 😵‍💫🧯（よくある！）

## ① `denied: permission_denied: write_package` 系

* 原因：`packages: write` が無い / workflow 権限が制限されてる
* 対策：workflow に `permissions: packages: write` を入れる ✅ ([GitHub Docs][1])
* それでもダメなら：リポジトリの Actions 設定で “Workflow permissions” を確認（制限が強すぎると詰むことがある）⚙️ ([GitHub Docs][6])

## ② GHCR にログインできない

* `registry: ghcr.io` になってる？
* `username: ${{ github.actor }}` / `password: ${{ secrets.GITHUB_TOKEN }}` になってる？ ✅ ([GitHub Docs][2])

## ③ `Dockerfile not found`

* `context: .` の位置に Dockerfile がある？
* サブディレクトリにあるなら `context` と `file:` を合わせよう📁

## ④ ビルドは通るのにアプリが起動しない

* 第6章の **PORT / 0.0.0.0** をもう一回チェック！🔌😵
* 起動コマンド（CMD）とビルド成果物の場所も確認👀

## ⑤ さっき言った “パッケージ紐付け問題” で push できない

* 「以前に同じ名前で別ルート push 済み」だと詰むことがある😇
* Packages 側で **リポジトリを接続**すると直るケースがあるよ ([GitHub Docs][3])

---

## 7) Copilot / Codex に投げる“勝ちプロンプト”集 🤖💬✨

* 「この workflow を **最小権限**（contents read / packages write）で GHCR push できる形に整えて」
* 「Dockerfile がサブフォルダにある。`context` と `file` を正しく書き換えて」
* 「push が重い。**キャッシュ**（Buildx + GHA cache）を入れたい。最小の追加案ちょうだい」

---

## 8) ミニ課題 📝🎯

1. `branches: ["main"]` を `["release"]` に変えて、**release ブランチ push だけ**で動くようにする✅
2. `tags:` にもう1つ追加して、`latest` も同時に push してみる（※次章の“タグ地獄回避”の入口だよ😇🏷️）

---

## 次章予告：第20章「タグ戦略：latest地獄を回避」😇🏷️

この章で「自動で push」はできた！🎉
次は **“どのイメージが本番？”問題**を潰して、運用が事故らない形にしていくよ🔥

[1]: https://docs.github.com/en/packages/managing-github-packages-using-github-actions-workflows/publishing-and-installing-a-package-with-github-actions "Publishing and installing a package with GitHub Actions - GitHub Docs"
[2]: https://docs.github.com/ja/actions/tutorials/publish-packages/publish-docker-images "Docker イメージの発行 - GitHub ドキュメント"
[3]: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry "Working with the Container registry - GitHub Docs"
[4]: https://github.com/docker/setup-buildx-action "GitHub - docker/setup-buildx-action: GitHub Action to set up Docker Buildx"
[5]: https://github.com/docker/build-push-action "GitHub - docker/build-push-action: GitHub Action to build and push Docker images with Buildx"
[6]: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository "Managing GitHub Actions settings for a repository - GitHub Docs"
