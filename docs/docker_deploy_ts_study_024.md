# 第24章：SBOM attestation：棚卸しにも“証明”を付ける 🔏🧾

今回は「SBOMを作った！」で終わらずに、**そのSBOMが“本当にこのイメージに対応している”って証明（＝attestation）まで付ける**ところまでやります💪🐳
GitHub Actions の `actions/attest-sbom` を使うと、**SBOM（SPDX/CycloneDX）を “in-toto 形式の署名付き証明書” として保存**できます。([GitHub][1])

---

## この章でできるようになること 🎯✅

* SBOMに**署名付きの証明（attestation）**を付けられる 🔏
* “どのコンテナイメージの中身”のSBOMなのかを **digest（sha256）でガチ固定**できる 🧷
* `gh` コマンドで **あとから検証（verify）**できる 👀✅([GitHub][1])
* （おまけ）**レジストリに attestation を push**して、イメージにくっつけられる 📦➡️🏷️([GitHub][1])

---

## 1) まずイメージ：attestationって何？🤔💡

SBOMは「部品表」🧾
でも、SBOMだけだとこう言われたら困ります👇

> 「そのSBOM、ほんとにこのイメージのやつ？」😇

そこで **attestation（証明書）**です🔏
`actions/attest-sbom` は、
**“この digest の成果物（＝コンテナイメージ）” と “このSBOM” を結びつけて署名する**仕組み。([GitHub][1])

しかも署名は、GitHub Actions の OIDC を使って、短命証明書でサインする方式（Sigstore）なので、長期鍵を抱えずに済みます🪪✨([GitHub][1])
（ここで Sigstore が出てくるよ）

---

## 2) 重要ワード3つだけ覚えよう 🧠🧷

## ✅ subject（対象）

証明したい “モノ”
→ ここでは **コンテナイメージ** 🐳

## ✅ digest（sha256:...）

対象を一意に固定する “指紋”🫆
→ **タグより強い**（タグは動くけど digest は固定）🏷️❌🧷✅

## ✅ predicate（SBOM側）

SBOM（SPDX or CycloneDX）🧾
`actions/attest-sbom` は **SPDX / CycloneDX の JSON**に対応してます。([GitHub][1])

---

## 3) ハンズオン：コンテナイメージに SBOM attestation を付ける 🚀🐳🔏

ここでは例として **GHCR（GitHub Container Registry）**に push する形で書くよ📦
他のレジストリでも考え方は同じで、`subject-name` をフルのイメージ名にするだけ👍

## ステップA：workflow に必要な権限を付ける 🪪✅

`actions/attest-sbom` には最低これが必要👇

* `id-token: write`（Sigstore用のOIDCトークン発行）
* `attestations: write`（GitHubに証明を保存）([GitHub][1])

さらに「イメージをpushする」ので `packages: write` も付けます📦

---

## ステップB：最小の workflow サンプル（コピペOK）🧩✨

`.github/workflows/build.yml` みたいなファイルにしてね👇

```yaml
name: build-image-with-sbom-attestation

on:
  push:
    branches: [ main ]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push
        id: build
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}

      - name: Generate SBOM (SPDX JSON)
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Attest SBOM
        uses: actions/attest-sbom@v3
        with:
          subject-name: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          subject-digest: ${{ steps.build.outputs.digest }}
          sbom-path: sbom.spdx.json
          push-to-registry: true
```

ポイントだけ解説するね👇😊

* `steps.build.outputs.digest` が **sha256:...** を返す前提（これが最強の固定キー🧷）
* `subject-name` は **タグを含めない**（例：`ghcr.io/owner/repo` まで）
  ※タグ込みにすると “名前” がブレやすいので、ここはルールで固定が安全✨([GitHub][1])
* `sbom-path` のSBOMは **JSONで16MB以内**（超えるとアウト）([GitHub][1])
* `push-to-registry: true` にすると、**レジストリにもattestationをpush**して「イメージ側にくっつく」状態にできます📦🔏([GitHub][1])

（SBOM生成で使ってる `anchore/sbom-action` は、外部ツールでSBOMを作って `attest-sbom` に渡す典型パターンとして公式例にも出てきます）([GitHub][1])
（ここで Anchore が登場）

---

## 4) できたか確認：verify（検証）して「本物」を味わう 👀✅🔎

## ✅ コンテナイメージの SBOM attestation を verify する（SPDX版）

```bash
gh attestation verify \
  oci://ghcr.io/OWNER/REPO:TAG \
  --predicate-type https://spdx.dev/Document/v2.3
```

`--predicate-type` がキモで、SPDXのときはこれです🧾✨([GitHub Docs][2])

> ここ、地味に最高ポイント😆
> **「そのSBOMが正しい形式で、しかも署名されてて、対象のイメージに結びついてる」**が確認できます。

---

## ✅ CycloneDX でやるなら predicate-type はこれ 🌀🧾

CycloneDX の公式 predicate-type はこれ、って明記されています👇([cyclonedx.org][3])

```bash
gh attestation verify \
  oci://ghcr.io/OWNER/REPO:TAG \
  --predicate-type https://cyclonedx.org/bom
```

（ここで OWASP Foundation が関係してるよ）([cyclonedx.org][3])

---

## 5) よくある詰まりポイント 😵‍💫🧯（超重要）

## 😭 1) “permission denied” 系

だいたいこれ👇

* `id-token: write` がない
* `attestations: write` がない([GitHub][1])

→ まず `permissions:` を疑うのが最短🏃‍♂️💨

---

## 😭 2) subject-digest の形式が違う

`subject-digest` は **`sha256:...` 形式が必須**です。([GitHub][1])
`docker/build-push-action` の digest をそのまま入れればOKにしとくのが安全🧷

---

## 😭 3) SBOMファイルが見つからない

`sbom-path` は「その場にファイルがある」前提📄

* `output-file` の名前と一致してる？
* working directory変えてない？（地味にある😇）

---

## 😭 4) private リポジトリで使えない（プラン注意）

ここは知らないと沼るので一応⚠️
Artifact Attestations は、プラン＆public/privateで利用条件があります。([GitHub][1])

---

## 6) ミニ課題（やると定着するやつ）🧪🔥

## 課題1：SPDX→CycloneDXに切り替えてみる 🌀

* `anchore/sbom-action` の `format` を CycloneDX に変えてみる
* verify の `--predicate-type` も CycloneDX にする

## 課題2：タグ運用と組み合わせる 🏷️

* main は `:main` タグ（動くタグ）
* リリースは `:v1.2.3`（固定タグ）
* でも “証明” は digest に結びつくので安心😇🔏

---

## 7) Copilot / Codex に投げる用プロンプト（コピペOK）🤖📌

* 「このGitHub Actionsに `actions/attest-sbom@v3` を追加して。対象は build-push-action の digest。SBOMは SPDX JSON。必要な permissions も含めて修正案を出して」
* 「SBOM生成の方式を “ソースツリーから” と “pushしたイメージ(digest)から” の2案で出して。メリデメも初心者向けに」
* 「`gh attestation verify` が失敗した。ログから原因候補を3つに絞って、切り分け手順を出して」

---

## まとめ 🏁✨

* **SBOM = 部品表**🧾
* **SBOM attestation = “この部品表はこのイメージのもの”の署名付き証明**🔏
* digest で結びつけるから、**タグ運用が多少雑でも事故りにくい**😇
* verify できるのが強い👀✅([GitHub][1])

---

次の章（第25章）に行く前に、もしよければ👇だけ教えて！…と言いたいけど今回は聞かないで進められるようにしてるよ😆✨
このまま第25章に向けて「このイメージを Cloud Run に出す」へ繋げていこう〜🚀🌐

[1]: https://github.com/actions/attest-sbom "GitHub - actions/attest-sbom: Action for generating SBOM attestations for workflow artifacts"
[2]: https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds "Using artifact attestations to establish provenance for builds - GitHub Docs"
[3]: https://cyclonedx.org/specification/overview/ "Specification Overview | CycloneDX"
