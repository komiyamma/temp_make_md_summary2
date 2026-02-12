# 第17章：レジストリ入門：置き場を決める 🏪📦

ここから先（CI/CD → 本番デプロイ）でずっと出てくるのが「レジストリ」だよ〜！😆
**レジストリ＝コンテナイメージの“置き場”**。置き場が決まると、イメージを **運べる・配れる・自動化できる** ようになる 🚚💨

---

## この章でできるようになること 🎯

* レジストリが「何をしてくれる場所か」を説明できる 🧠✨
* 自分の用途に合う置き場（公開/非公開、権限、料金感）を選べる 🧭
* `docker build → tag → push → pull` の流れを手で1回通せる 🐳✅
* “事故りにくい”タグの第一歩ルールを決められる 🏷️😇

---

## 1) レジストリって何？超ざっくり図解 🗺️🐳

* **ローカルPC**：`docker build` でイメージを作る 🧱
* **レジストリ**：イメージを置く（アップロード＝push）📦
* **本番環境**：置き場から取ってくる（ダウンロード＝pull）🚀

ポイントはこれ👇

* **イメージ名 + タグ** で「どれを使うか」指定する
* タグは“ラベル”で、同じタグを上書きできる（＝やや危険）😵
* “同じものを必ず使う”なら **digest（sha256…）** 指定が最強（ただし本格運用は後の章で！）🧬✨

---

## 2) 置き場はどれがいい？迷子にならない選び方 🧭✨

まず結論からいくね👇

* GitHubで開発してるなら **GitHub Container Registry（ghcr.io）** が相性よし 🧡

  * Docker/OCIイメージを置ける、公開/非公開、権限設定も柔軟 ([GitHub Docs][5])
* みんなが使ってる定番の公開置き場なら **Docker Hub**

  * ただし無料/個人だと pull 回数制限がある（CIでハマりやすい）⚠️ ([Docker Documentation][6])
* クラウド（Cloud Runなど）寄りなら **Google Cloud Artifact Registry** が自然

  * 置き場の名前ルールがちょい独特（後で例を出すね） ([Google Cloud Documentation][7])
* AWSなら **Amazon Elastic Container Registry** が王道

  * `aws_account_id.dkr.ecr.region.amazonaws.com/...` 形式 ([AWS ドキュメント][8])

---

## 3) “名前の読み方”が分かると一気にラク 😆📛

Dockerが扱う「イメージ参照」はだいたいこの形👇

```text
<レジストリ>/<名前空間>/<イメージ名>:<タグ>
```

例：ghcr の場合（雰囲気）

```text
ghcr.io/komiyamma/myapp:dev
```

## digest 指定（同じもの固定）も一応知っておく 🧬

```text
ghcr.io/komiyamma/myapp@sha256:xxxxxxxx...
```

「タグは動く」「digestは固定」って感覚だけ持っておけばOKだよ〜！🫶
（digest の使い分けは、後の章の“タグ戦略”で本気出す🔥）

---

## 4) 公開/非公開 と 権限の超基本 🔒🧑‍🤝‍🧑

## ざっくりルール ✅

* **公開（Public）**：誰でも pull できる（世界に配る系）🌍
* **非公開（Private）**：ログインした人だけ（個人開発/チーム）🔐

## GHCRの特徴（初心者が助かるポイント）✨

* リポジトリに紐づけて権限を継承できたり、個別に細かく権限を切れたりする ([GitHub Docs][5])
* コマンドラインで push すると、**自動ではリポジトリにリンクされない**ことがある（地味にハマる）😵

  * 対策として `org.opencontainers.image.source` ラベルをDockerfileに入れるのが推奨されてる ([GitHub Docs][5])

## Docker Hubの注意（pull制限）⚠️

* **Personal（認証あり）**：6時間あたり **200 pulls**
* **未認証**：6時間あたり **100 pulls（IP単位）**
* Pro/Team/Business は pull 制限が実質無制限 ([Docker Documentation][6])
  CI/CDが増えるとここで詰まりやすいので、教材的にも“知っておくと勝ち”だよ〜😇

---

## 5) ハンズオン：GHCRに手で push して「置き場」を体験する ✋📤🎉

ここでは **“手で1回通す”** のが目的！
（次章以降で GitHub Actions による自動化に繋がるよ🤖✨）

---

## 手順A：GHCRへ push / pull（Windows・PowerShell版）🪟⚡

## 0. 用意するもの 🧰

* GitHub の Personal Access Token（classic）

  * `write:packages`（pushに必要）などのスコープが出てくる ([GitHub Docs][9])
  * GitHub Packages のCLI認証は（少なくとも公式説明では）classic PAT を使う案内になってる ([GitHub Docs][5])

## 1. トークンを環境変数に入れる（PowerShell）🔑

```powershell
$env:CR_PAT = "ここにトークン"
$env:GITHUB_USER = "GitHubユーザー名"
$env:IMAGE_NAME = "myapp"
$env:TAG = "dev"
```

## 2. ghcr にログインする（パスワードは標準入力）🔐

```powershell
$env:CR_PAT | docker login ghcr.io -u $env:GITHUB_USER --password-stdin
```

## 3. ローカルでイメージを作る 🧱🐳

（Dockerfileがある前提）

```powershell
docker build -t "$env:IMAGE_NAME:local" .
```

## 4. “置き場用の名前”を付ける（tag付け替え）🏷️

```powershell
docker tag "$env:IMAGE_NAME:local" "ghcr.io/$env:GITHUB_USER/$env:IMAGE_NAME:$env:TAG"
```

## 5. push（アップロード）📤📦

```powershell
docker push "ghcr.io/$env:GITHUB_USER/$env:IMAGE_NAME:$env:TAG"
```

## 6. pull して起動できるか確認（同じPCでもOK）✅

```powershell
docker pull "ghcr.io/$env:GITHUB_USER/$env:IMAGE_NAME:$env:TAG"
docker run --rm -p 3000:3000 "ghcr.io/$env:GITHUB_USER/$env:IMAGE_NAME:$env:TAG"
```

---

## ついでに：リポジトリと“ちゃんと紐づく”ようにする小技 🧷✨

Dockerfileにこのラベルを入れると、GHCR側でソース元が分かりやすくなる（推奨されてる）よ！ ([GitHub Docs][5])

```dockerfile
LABEL org.opencontainers.image.source="https://github.com/<owner>/<repo>"
```

---

## 6) ここでよく詰まるやつ Top5 😵‍💫🔧

1. **login は通るのに push が denied**
   → トークンのスコープ不足（`write:packages` など）になりがち ([GitHub Docs][9])

2. **GHCRにpushしたのに、GitHubのリポジトリ側から見えない**
   → コマンドラインpushは自動リンクされない場合がある
   → `org.opencontainers.image.source` ラベルでリンクしやすくする ([GitHub Docs][5])

3. **`latest` しか使ってなくて、どれが本番か分からなくなる**
   → 次章以降でガッツリ直すけど、今は「dev と main でタグ分け」だけでも効果大 😇🏷️

4. **Docker Hub で 429（Too Many Requests）**
   → pull 制限に引っかかった可能性大（未認証100/6h、Personal200/6h） ([Docker Documentation][6])

5. **マルチアーキ/Windows系の話が不安**
   → GHCRは Docker/OCI を扱えて、Windows系のレイヤー（foreign layers）もサポートされる説明があるよ ([GitHub Docs][5])
   （ただし自分のアプリのイメージをWindowsコンテナで作るかどうかは、別の話になるので今は深追いしなくてOK！🙆‍♂️）

---

## 7) ミニ課題 🎒📝

## 課題1：置き場を1つ選ぶ 🧭

* GHCR / Docker Hub / Artifact Registry / ECR のどれを使うか決めて、理由を1行で書く✍️

## 課題2：タグ命名ルールを“3つだけ”決める 🏷️

例：

* `dev`：手元検証用
* `main`：メインブランチの最新版
* `v1.0.0`：リリース固定（※この発想が後で効く！）🔥

---

## 8) AIに投げると強いプロンプト集 🤖💬✨

* 「このリポジトリに合うコンテナイメージ名と、破綻しにくいタグ案を3パターン出して」
* 「GHCR運用で初心者がやりがちな事故（権限/公開設定/タグ）をチェックリスト化して」
* 「Docker Hubのpull制限に引っかからないCI設計の基本方針を、個人開発向けに提案して」

---

次の第18章は「手でpushして理解」だから、この章で作った置き場の感覚がそのまま効いてくるよ〜！🚀🐳💪

[1]: https://chatgpt.com/c/698d59d3-aafc-83ab-9436-9edad7644682 "Docker教材の前提"
[2]: https://chatgpt.com/c/698d93d2-f6d0-83a9-b8a2-c83197780c86 "デプロイとポート設定"
[3]: https://chatgpt.com/c/698daa71-83a4-83a3-b2ff-38fdda30889c "Graceful Shutdownの実装"
[4]: https://chatgpt.com/c/698da79d-104c-83a6-9106-b179c9e15920 "New chat"
[5]: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry "Working with the Container registry - GitHub Docs"
[6]: https://docs.docker.com/docker-hub/usage/ "Usage and limits | Docker Docs"
[7]: https://docs.cloud.google.com/artifact-registry/docs/docker/names "Repository and image names  |  Artifact Registry  |  Google Cloud Documentation"
[8]: https://docs.aws.amazon.com/ja_jp/AmazonECR/latest/userguide/docker-push-ecr-image.html?utm_source=chatgpt.com "Docker イメージを Amazon ECR リポジトリにプッシュするには"
[9]: https://docs.github.com/ja/packages/working-with-a-github-packages-registry/working-with-the-container-registry?utm_source=chatgpt.com "コンテナレジストリの利用 - GitHub ドキュメント"
