# 第31章：CIで自動チェックして「壊してない自信」を毎回つける🤖✅

この章で作るのはコレ👇✨
**Pull Request を出したら、自動で `lint / test / typecheck` が走って、落ちたら赤く知らせてくれる仕組み**です🚦
（「自分のPCでは動いたのに…😇」を減らすやつ！）

---

## 1) まず“CIで回すコマンド”を1つにまとめる🧩✨

CIで複数コマンドを並べるより、**ローカルと同じ“合格条件”を1コマンド**にしておくのが超ラクです🙂👍

例：`package.json` に “CI用まとめコマンド” を作る（すでに第27章で作ってたらそのままでOK）🧠

```json
{
  "scripts": {
    "lint": "eslint .",
    "test": "vitest run",
    "typecheck": "tsc -p tsconfig.json --noEmit",
    "check": "npm run lint && npm run typecheck && npm run test"
  }
}
```

ポイント💡

* CIは基本 **`npm ci`**（ロックファイル通りにクリーンインストール）で安定させるのが王道🧼
* `check` が通れば「最低限の品質ゲート突破🎉」が揃う

---

## 2) GitHub Actionsのワークフローを追加する📦⚙️

リポジトリにこのファイルを作ります👇
`/.github/workflows/ci.yml`

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [ main ]

## まずは最小権限（読むだけ）🛡️
permissions:
  contents: read

## 同じブランチで連打しても、古い実行を自動キャンセル🧹
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout 🧾
        uses: actions/checkout@v6

      - name: Setup Node 🧰
        uses: actions/setup-node@v6
        with:
          node-version: 24
          cache: npm

      - name: Install 📥
        run: npm ci

      - name: Check ✅
        run: npm run check
```

これで、PRを作るだけで CI が動きます🎉

* `ubuntu-latest` は現在 **Ubuntu 24.04** が標準になっています🧊（CI環境の前提が揃いやすい）([GitHub][1])
* Node は **24系が Active LTS** なので、CIも 24 に揃えるのが安心です🔒([Node.js][2])

> `actions/checkout@v6` は v6 系の最新版に追随する指定です🧷（v6 のリリースが出ています）([GitHub][3])
> `actions/setup-node` は npm/yarn/pnpm のキャッシュ機能を内蔵しています📦⚡([GitHub][4])

---

## 3) 速くするコツ：キャッシュは“迷わずON”⚡🧠

上の例だと `cache: npm` を入れてるので、依存インストールが速くなりやすいです🏎️💨([GitHub][4])

さらに補足💡

* `actions/setup-node` はバージョンによって **自動キャッシュ挙動が変わる**ことがあります（特に `package.json` の `packageManager` を使っている場合）🧷
  もし変なハマり方をしたら、`package-manager-cache: false` で一旦OFFにできます🧯([GitHub][5])

---

## 4) DBあり統合テストもCIで回したいとき🧱🧪（任意）

「DBコンテナ立てて統合テストもやりたい！」なら、**ジョブを分ける**のが分かりやすいです🙂✨
（ユニットテストは速い＝毎回、統合テストは重い＝必要なとき、にしやすい）

例：`compose.test.yml` を使って統合テストする（雰囲気サンプル）👇

```yaml
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: 24
          cache: npm

      - run: npm ci

      - name: Start deps (db etc.) 🐳
        run: docker compose -f compose.test.yml up -d

      - name: Run integration tests 🧪
        run: npm run test:integration

      - name: Shutdown 🧹
        if: always()
        run: docker compose -f compose.test.yml down -v
```

コツ💡

* `if: always()` を付けると、落ちても後片付けが走ってログが見やすいです🧹✨
* 統合テストは「1日1回/PRだけ」など、重さに合わせてトリガー設計してOK🙂

---

## 5) “落ちたらマージできない”を完成させる🔐🚧

ワークフローができたら、最後に **ブランチ保護**を入れると強いです💪
やることはシンプル👇

* リポジトリ設定 → Branch protection
* `Require status checks` をON
* `CI / check`（や `integration`）の成功を必須にする✅

これで「CIが赤いのにマージされる😇」が消えます🎉

---

## ミニ課題🎒✨

1. わざと `lint` が落ちるコードを1行入れる（例：未使用変数）😈
2. PRを作る
3. CIが赤くなるのを確認
4. 修正して緑に戻す✅🌿

→ この流れを一回体験すると「CI＝味方」になります🙂🤝

---

## よくある詰まりポイント集🧯😵‍💫

* **`npm ci` が失敗する**
  → `package-lock.json` が無い／ズレてる可能性大。ローカルで `npm install` → lock をコミット🧩
* **ローカルはOKなのにCIで落ちる**
  → Node バージョン差・OS差・環境変数差が多いです。まず CI の Node をローカルと揃える🔁
* **キャッシュ周りで謎エラー**
  → 一旦キャッシュOFF（または自動キャッシュOFF）で切り分けが最速🧯([GitHub][5])

---

## AIで時短するプロンプト例🤖✨（そのままコピペOK）

## 例1：いまの scripts に合わせてCI作らせる🧠

```text
package.json の scripts はこうです:
- lint: ...
- typecheck: ...
- test: ...
- check: ...

GitHub Actions の ci.yml を作って。
要件:
- PR と main への push で動く
- Node 24
- npm ci
- npm キャッシュ
- 失敗したら分かりやすい step 名
```

## 例2：統合テストも回す設計を相談する🧱

```text
統合テストは DB が必要で docker compose で起動できます。
CIで「速いチェック」と「重い統合テスト」を分けたいです。
最小の構成案（yaml例つき）を提案して。
```

---

## ちょい上級：CIの安全性を上げる🛡️🔒（興味あれば）

* `GITHUB_TOKEN` の権限は **最小権限**が推奨です（まず `contents: read`）🧰([GitHub Docs][6])
* さらに厳密にするなら、**ActionsをコミットSHA固定**（サプライチェーン対策）も推奨されています🔐([The GitHub Blog][7])

---

次の章があるなら、流れ的におすすめは
**「CIの結果を“見える化”（カバレッジ・テストレポート・失敗ログの読み方）📊👀」**か、
**「リリース/デプロイの入口（ステージングだけ自動）🚀」** が気持ちよく繋がります🙂✨

[1]: https://github.com/actions/runner-images/issues/10636?utm_source=chatgpt.com "Ubuntu-latest workflows will use Ubuntu-24.04 image"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://github.com/actions/checkout/releases?utm_source=chatgpt.com "Releases · actions/checkout"
[4]: https://github.com/actions/setup-node?utm_source=chatgpt.com "actions/setup-node"
[5]: https://github.com/actions/setup-node/releases?utm_source=chatgpt.com "Releases · actions/setup-node"
[6]: https://docs.github.com/en/actions/reference/security/secure-use?utm_source=chatgpt.com "Secure use reference - GitHub Docs"
[7]: https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/?utm_source=chatgpt.com "GitHub Actions policy now supports blocking and SHA ..."
