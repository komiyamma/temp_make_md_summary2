# 第22章：Provenance（来歴）：誰がどう作ったかを証明 🔏🧬

この章はひとことで言うと👇
**「このコンテナ、ほんとに“そのリポジトリのそのワークフロー”で作られたやつ？」を、あとから証明できるようにする**回です 😎✨
GitHub ではこれを **Artifact Attestations（成果物の“証明書”）** として提供していて、ビルドの来歴（provenance）を残せます。([GitHub Docs][4])

---

## この章のゴール 🎯✨

* **コンテナイメージに「ビルド来歴の証明（provenance attestation）」を付ける**
* **ローカル（Windows）から `gh` コマンドで検証できる**
* 「どこで詰まるか」を先に知って、事故を回避できる 🧯

---

## まず1分でわかる：Provenanceってなに？🧠💡

* **Provenance（来歴）**：
  「いつ・どこで・どんな手順で、その成果物が作られたか」という履歴のこと 🧾
* **Attestation（証明/署名つき主張）**：
  「この成果物はこうやって作りました！」という主張を**改ざんできない形で署名**して残すもの 🔏([GitHub Docs][4])

GitHub CLI の説明もこの考え方そのままで👇
**actor（作った人＝ワークフロー）**が、**subject（対象＝成果物）**について主張する、って整理になってます。([GitHub CLI][5])

---

## なにが嬉しいの？（ありがちな事故3つ）😱➡️😇

1. **「タグは同じなのに中身が違う」事故** 🏷️💥
   `latest` だけじゃなく、運用が雑だと「これ本番どれ？」が起きがち。
   → タグ戦略（第20章）で減るけど、さらに「その中身がどこで作られたか」を証明できると強い 💪

2. **レジストリ側で“差し替え”が起きても気づきにくい** 🕵️
   → “来歴の証明”があると、**正しいワークフロー由来か**を検証できる

3. **ビルド環境が汚染された/乗っ取られた時の被害がでかい** ☠️
   → “いつ・どのワークフローで”作ったかを追跡できるので、切り戻しが速くなる 🏃‍♂️💨

---

## ハンズオン：コンテナイメージに来歴を付ける 🐳🔏

ここでは GitHub 公式の **`actions/attest-build-provenance`** を使います。
コンテナの場合は **イメージ名（タグ無し）＋digest（sha256:〜）** を渡すのがポイントです。([GitHub][6])

---

## Step 1) workflow に “必要な権限” を足す 🔑

最小の考え方はこれ👇

* **`id-token: write`**：署名に使う（短命）トークン発行用
* **`attestations: write`**：attestation を作る権限
* **`packages: write`**：GHCRへpushするなら必要
* **`contents: read`**：checkout等の最低限

GitHub公式もこの権限セットを案内しています。([GitHub Docs][7])

---

## Step 2) “digest” を取れるように build step に id をつける 🧱➡️🧬

`docker/build-push-action` は `digest` を出力できます（これを attestation に使う）([GitHub Docs][7])
※Docker側でも provenance attestation を扱える流れが増えていて、`docker/build-push-action@v6` を使う例も公式に載っています。([Docker Documentation][8])

---

## Step 3) `attest-build-provenance` を追加する ✅

例：`.github/workflows/container-image.yml`（**必要部分だけ**を“完成形”で置きます👇）

```yaml
name: build-and-attest-image

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write

    env:
      REGISTRY: ghcr.io
      IMAGE_NAME: ${{ github.repository }} # owner/repo

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push image
        id: push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:main

      - name: Attest build provenance
        uses: actions/attest-build-provenance@v3
        with:
          # ✅タグは付けない（重要！）…digestが“どの中身か”を指す
          subject-name: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          subject-digest: ${{ steps.push.outputs.digest }}
          # ✅レジストリに attestation も一緒に保存
          push-to-registry: true
```

ポイントは2つだけ覚えればOKです😆✨

* `subject-name` は **フルのイメージ名（タグ無し）**([GitHub][6])
* `subject-digest` は **`sha256:...` のdigest**（build stepの出力をそのまま使える）([GitHub Docs][7])

---

## Step 4) 付いたか確認する 👀✅

* ワークフロー実行後、GitHub の Actions 実行結果から **attestation を確認**できます（GitHub公式が案内）([GitHub Docs][7])
* `push-to-registry: true` にしているので、**レジストリ側（OCI）にも一緒に保存**されます。([GitHub][6])

---

## ハンズオン：Windows で “検証” してみる 🪟🔍✨

GitHub CLI の `gh attestation verify` で検証できます。
デフォルトでは SLSA provenance（`https://slsa.dev/provenance/v1`）の predicate を前提にチェックします。([GitHub CLI][5])

```powershell
## 1) GitHubにログイン（まだなら）
gh auth login

## 2) （GHCRを見るので）docker login
docker login ghcr.io

## 3) 検証（タグ付きで参照してOK。裏ではdigestとattestationで検証する）
gh attestation verify oci://ghcr.io/OWNER/REPO:main -R OWNER/REPO
```

GitHub Docs でも、コンテナの検証は `oci://...` 形式でやる案内になっています。([GitHub Docs][7])

---

## よくある詰まりポイント Top6 😵‍💫➡️✅

1. **`subject-name` にタグを付けちゃう** 🏷️❌
   → **タグ無し**が正解！「どの中身か」はdigestが握ってます。([GitHub][6])

2. **`subject-digest` が `sha256:...` 形式じゃない** 🧬❌
   → `steps.push.outputs.digest` をそのまま使うのが安全。([GitHub Docs][7])

3. **`attestations: write` を付け忘れる** 🔑❌
   → これが無いと作れません。([GitHub Docs][7])

4. **GHCR push するのに `packages: write` が足りない** 📦❌
   → pushするなら必要。([GitHub Docs][7])

5. **private リポで「機能が使えない？」となる** 🔒❓
   GitHubのプラン/公開設定によって利用条件があります（公開リポなら使える、など）。
   もし挙動が違ったら、この条件を見に行くのが近道です。([GitHub Docs][7])

6. **ビルド引数（build-arg）に秘密を入れてた** 🤫💥
   Docker公式が強めに警告していて、**provenanceに build args が含まれる場合がある**ので漏れます。
   → 秘密は build-arg じゃなく、secret mounts 等へ逃がすのが安全。([Docker Documentation][8])

---

## ミニ課題（やると身につく💪）📝✨

1. 自分の workflow に provenance attestation を付ける
2. `gh attestation verify` を1回通す
3. 「このイメージの“出どころ”を一言で説明」できる文章を作る（30秒でOK）✍️

---

## 🤖 AIプロンプト例（コピペOK）

* 「この `.github/workflows/*.yml` に、`actions/attest-build-provenance@v3` を追加して。コンテナは GHCR に push 済みで、digest は `docker/build-push-action` の出力を使いたい」
* 「`permissions` を最小にして、必要なものだけ残して（`id-token` と `attestations` を忘れないで）」
* 「`gh attestation verify` が失敗した。出力ログから原因候補を3つに絞って、確認順も提案して」

---

## ちょいコラム：Docker側の“自動Provenance”もあるよ 🐳📌

最近は `docker/build-push-action` 自体が provenance attestation を扱う流れも強くて、条件によっては自動で付いたり、`provenance: mode=max` みたいに指定して強化もできます。([Docker Documentation][8])
ただこの章の主役は「GitHubのattestation（GitHub UI + `gh` で検証しやすい）」なので、まずは **`attest-build-provenance` を確実に1回通す**のがおすすめです 😄👍

---

次の第23章（SBOM）に行くと、今度は「中身の棚卸し（依存の一覧）」までセットで“証明”できるようになって、さらに強くなります 🧾🔥

[1]: https://chatgpt.com/c/698db897-76e0-83aa-a043-86455b1b49bf "GitHub Actionsで自動ビルド"
[2]: https://chatgpt.com/c/698db5c3-0c30-83a6-8284-414af574121e "第18章 手でpush体験"
[3]: https://chatgpt.com/c/698db01a-4ea0-83a6-a85d-ad8aab890c1f "第16章 HTTPSとドメイン"
[4]: https://docs.github.com/en/actions/concepts/security/artifact-attestations?utm_source=chatgpt.com "Artifact attestations"
[5]: https://cli.github.com/manual/gh_attestation_verify "GitHub CLI | Take GitHub to the command line"
[6]: https://github.com/actions/attest-build-provenance "GitHub - actions/attest-build-provenance: Action for generating build provenance attestations for workflow artifacts"
[7]: https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds "Using artifact attestations to establish provenance for builds - GitHub Docs"
[8]: https://docs.docker.com/build/ci/github-actions/attestations/ "Attestations | Docker Docs"
