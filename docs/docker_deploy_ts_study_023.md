# 第23章：SBOM入門：中身の棚卸し 🧾📚

この章は「**いま動いてるコンテナの中身**を、あとから説明できる状態にする」回だよ〜！😆✨
いわゆる **SBOM（Software Bill of Materials）**＝「ソフトの原材料ラベル」🍱みたいなものを作って、CIで自動生成までやっちゃう💪

---

## この章でできるようになること ✅🎯

* SBOMが「何のためにあるか」を説明できる 🗣️✨
* **SPDX / CycloneDX** の違いをざっくり掴む 🧠
* ローカルでSBOMを1回作る（手で棚卸し）🧾
* GitHub Actionsで **SBOMを自動生成して保存**できる 🤖📦
* （おまけ）依存関係を「Dependency Graph」に反映させる入口も知る 🔍

---

## 1) SBOMってなに？🤔🍳

SBOMは、ざっくり言うと **「このソフトは何でできてる？」の機械可読な一覧**だよ🧾✨
NIST でも SBOM を「部品とサプライチェーン関係を含む正式な記録」みたいに定義してる📌([NIST][1])
NTIA も同様に「構成要素の詳細と関係を記録するもの」として整理してて、政府調達などでも重要になってるよ🧾([ntia.gov][2])

**超かんたんに言うと👇**

* 何が入ってる？（依存パッケージ、OSライブラリなど）
* バージョンは？
* どの成果物（コンテナ/ビルド結果）に対応？

これがまとまってると、事故対応が早くなる🔥

---

## 2) どんな時に効くの？💥🧯

SBOMが刺さるシーンはだいたいこれ👇

* **脆弱性が出たとき**：「うち入ってる？」を即答できる ⚡
* **ライセンス確認**：「この依存、商用OK？」が追える 📜
* **取引・監査**：「中身出して」要求に応えやすい 🧾
* **サプライチェーン対策**：あとで「誰が何を作ったか」系と繋がる🔗

GitHub のドキュメントでも、SBOMは依存の透明性やサプライチェーンリスク低減に役立つって説明してるよ🧠([GitHub Docs][3])

---

## 3) まず重要：SBOMは「どれ」に対して作る？🎯🐳

ここが初心者が迷いやすいポイント！😵‍💫

## A. リポジトリ（ソース）に対するSBOM 🧑‍💻

* lockfile等から「JS依存」を中心に出る
* 速い・簡単👍
* でも「コンテナに入ったOSパッケージ」は載らないことがある

## B. **コンテナイメージに対するSBOM（おすすめ）** 🐳✅

* 実際にデプロイする「完成品」を棚卸しできる
* OSライブラリも含めやすい（ツール次第）
* 「本番の中身」を説明するのに強い💪

この教材の流れ（コンテナをWebへ）だと、**B（イメージSBOM）**が気持ちよくハマる✨

---

## 4) 形式（フォーマット）は2強：SPDX と CycloneDX 🥊📄

## SPDX（まず覚えるならこっち）📄✨

* Linux Foundation 系の標準で、**ISO/IEC 5962:2021** の国際標準でもあるよ📌([spdx.dev][4])
* GitHub の依存グラフからのSBOMエクスポートも **SPDX** が基本🧾([GitHub Docs][3])

## CycloneDX（セキュリティ寄りで人気）🌀🔐

* OWASP の CycloneDX は **ECMA-424** として標準化されてるよ📌([owasp.org][5])
* ツールやエコシステムが大きいのも強み💪🧰([cyclonedx.org][6])

**結論（迷ったら）**

* まず **SPDX JSON** で1本作れるようになろう 😆
* 必要になったら CycloneDX も出せばOK 👍

---

## 5) ハンズオンA：ローカルでSBOMを1回作る 🧪🧾✨

ここは「SBOMってこういうファイルか〜！」って掴むパート😆
今回は Anchore の **Syft** を使うよ（コンテナ/ファイルシステムからSBOM生成できる）🐳🧾([GitHub][7])

---

## A-1) リポジトリ（フォルダ）からSBOMを作る📁➡️🧾

VS Codeのターミナル（PowerShell想定）で、プロジェクトルートにいて👇

```powershell
docker run --rm -v ${PWD}:/src anchore/syft:latest dir:/src -o spdx-json > sbom.spdx.json
```

できた `sbom.spdx.json` を開いてみよう👀✨
「packages」とか「name」「version」っぽいのがいっぱい並んでたら成功🎉

---

## A-2) コンテナイメージからSBOMを作る🐳➡️🧾（本命）

まずイメージを作る（例）👇

```powershell
docker build -t myapp:sbom .
```

次にそのイメージを棚卸し👇

```powershell
docker run --rm anchore/syft:latest myapp:sbom -o spdx-json > image.sbom.spdx.json
```

フォルダSBOMと比べると、**より「本番っぽい中身」**が出てきやすいよ😆🐳

---

## A-3) CycloneDXも出してみる（お試し）🌀

```powershell
docker run --rm -v ${PWD}:/src anchore/syft:latest dir:/src -o cyclonedx-json > sbom.cdx.json
```

---

## A-4) “ざっくり読む”ミニスクリプト（NodeでOK）🔍✨

SBOMってデカいので、目視がつらい😂
「名前とバージョンだけ雑に一覧」する例👇

```js
// scripts/peek-sbom.mjs
import fs from "node:fs";

const sbom = JSON.parse(fs.readFileSync("sbom.spdx.json", "utf-8"));
const pkgs = sbom.packages ?? [];

for (const p of pkgs.slice(0, 30)) {
  console.log(`${p.name ?? "?"}@${p.versionInfo ?? "?"}`);
}

console.log(`\nTotal packages: ${pkgs.length}`);
```

実行👇

```powershell
node scripts/peek-sbom.mjs
```

---

## 6) ハンズオンB：CIでSBOMを自動生成して保存する 🤖📦🧾

ここからが「運用に効く」やつ！😎✨
Anchore の `anchore/sbom-action` は、ワークスペースや**コンテナイメージ**をスキャンして、SBOMを**Workflow Artifactとして保存**できるよ📦([GitHub][8])

---

## B-1) まずは最小：pushしたらSBOM作って保存 🧾📦

`.github/workflows/sbom.yml` を作って👇

```yaml
name: sbom

on:
  push:
    branches: ["main"]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  build-sbom:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      # まずは「リポジトリ（フォルダ）」を棚卸し（簡単で速い）
      - name: Generate SBOM (repo)
        uses: anchore/sbom-action@v0
        with:
          format: spdx-json
          artifact-name: sbom-repo.spdx.json
```

これで Actions の実行結果に **SBOMが成果物として残る**🎉
（`anchore/sbom-action` の「デフォルトはワークスペースをスキャンしてSPDXで出して成果物アップロード」って挙動そのものだよ）([GitHub][8])

---

## B-2) ちょい本番寄り：イメージSBOMも作る🐳🧾

「デプロイする完成品（イメージ）」を棚卸ししたいので、イメージを作ってからSBOM👇

```yaml
name: sbom

on:
  push:
    branches: ["main"]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  image-sbom:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Generate SBOM (image)
        uses: anchore/sbom-action@v0
        with:
          image: myapp:${{ github.sha }}
          format: spdx-json
          artifact-name: sbom-image.spdx.json
```

`image:` でコンテナイメージをスキャンできるのがポイント！🐳✨([GitHub][8])

---

## B-3) （おまけ）Dependency Graphに反映させる🔍✨

GitHub の **dependency submission API** は、ビルド時に解決された依存を送って、Dependency Graphをより正確にできる仕組みだよ📮
送った依存は **Dependabot Alerts / security updates** の対象にもなる📌([GitHub Docs][9])

`anchore/sbom-action` には **dependency-snapshot** オプションがある（SBOMを生成しつつ送れる）🧠([GitHub][8])

例👇（まずは雰囲気だけでOK！）

```yaml
permissions:
  contents: write

- name: Generate SBOM + submit snapshot
  uses: anchore/sbom-action@v0
  with:
    format: spdx-json
    artifact-name: sbom-repo.spdx.json
    dependency-snapshot: true
```

※このへんはプロジェクトの公開/非公開や権限設計でも話が広がるので、**「動いた！」を優先して一歩ずつ**でOKだよ😆👍
（SBOMのエクスポートやActionsでの生成についてもGitHub Docsが整理してる）([GitHub Docs][3])

---

## 7) つまずきTop3 😵‍💫➡️😆

## ① SBOMファイルがデカい😂

→ 正常！まずは「出せた」ことが勝ち🏆
必要になったら “差分” で追う方が楽（後でやる✨）

## ② 「ソースSBOM」と「イメージSBOM」が違う😵

→ それも正常！
**デプロイするのはイメージ**なので、最終的にはイメージSBOMが強い🐳💪

## ③ SBOM作ったけど何が嬉しいの？🤔

→ “事件が起きた時” に真価が出る🔥
「入ってるか？」が即答できるのはデカいよ⚡([NIST][1])

---

## 8) ミニ課題（手を動かす）📝🔥

1. `sbom.spdx.json` から **自分のアプリ名**っぽい項目を探す🔎
2. `image.sbom.spdx.json` で **OS系っぽいパッケージ**が増えてるか観察👀
3. Actionsで生成したSBOM成果物をダウンロードして、ローカルのと比較してみる📦🧾

---

## 9) AIプロンプト例（コピペOK）🤖📝✨

* 「この `sbom.spdx.json` を読んで、主要ライブラリTop20を表にして」
* 「このSBOMから、ライセンスが不明（または要注意）っぽい項目を抽出する方針を考えて」
* 「ソースSBOMとイメージSBOMが違う理由を、初心者向けにたとえ話で説明して」
* 「このActions workflowで、SBOMのファイル名にコミットSHAを入れて追跡しやすくして」

---

## 次章へのつなぎ 🔗✨

この章で「棚卸し（SBOM生成）」ができた！🧾🎉
次の **第24章（SBOM attestation）** では、ここに「**このSBOMは本当にこのビルドから出たよ**」っていう **証明（attestation）** を付けて、信頼性を上げるよ🔏😎

[1]: https://www.nist.gov/itl/executive-order-14028-improving-nations-cybersecurity/software-security-supply-chains-software-1?utm_source=chatgpt.com "Software Bill of Materials (SBOM)"
[2]: https://www.ntia.gov/report/2021/minimum-elements-software-bill-materials-sbom?utm_source=chatgpt.com "The Minimum Elements For a Software Bill of Materials ..."
[3]: https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/exporting-a-software-bill-of-materials-for-your-repository "Exporting a software bill of materials for your repository - GitHub Docs"
[4]: https://spdx.dev/ "SPDX – Linux Foundation Projects Site"
[5]: https://owasp.org/www-project-cyclonedx/?utm_source=chatgpt.com "CycloneDX Bill of Materials Specification (ECMA-424)"
[6]: https://cyclonedx.org/tool-center/ "CycloneDX Tool Center | CycloneDX"
[7]: https://github.com/anchore/syft?utm_source=chatgpt.com "anchore/syft: CLI tool and library for generating a Software ..."
[8]: https://github.com/anchore/sbom-action "GitHub - anchore/sbom-action: GitHub Action for creating software bill of materials using Syft."
[9]: https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/using-the-dependency-submission-api "Using the dependency submission API - GitHub Docs"
