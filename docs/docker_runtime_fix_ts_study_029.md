# 第29章：固定を“壊さない運用ルール”を作る📏🧠

この章は「Dockerで固定できた！🎉」の“次の壁”を超える回です。
固定って、作るより **守り続ける運用** がむずいんですよね…🥲
ここで「壊れにくいルール」を先に作っておくと、未来の自分が超ラクになります😆✨

---

## この章のゴール🎯✨

* 固定が **いつ・なぜ壊れるか** を説明できる🧠
* 「壊れないためのルール」と「壊れた時の復旧手順」が1枚にまとまる📄
* “更新のやり方”が決まっていて、怖くない状態になる🔁😌
* CIで「固定が壊れた」を自動で検知できる✅🤖

---

## まず現状確認📌 2026-02-09時点の基準

* Nodeは **v24がActive LTS**、v25がCurrent、v22がMaintenance LTS（公式の状態表）([nodejs.org][1])
* TypeScriptは npm 上の Latest が **5.9.3**（5.9系が実運用の軸にしやすい）([npm][2])

この「今の基準」を “運用ルールの初期値” にします👍

---

## 固定が壊れる典型パターン💥😱

1. **ベースイメージが勝手に更新**され、挙動が変わる
   例：`node:24-bookworm-slim` を使ってたら、内部のパッチが更新されて微妙な差分が出る…など🌀
   （公式イメージは多数タグがあり、同じ“見た目タグ”でも中身が動くことがある）([hub.docker.com][3])

2. **lockfileがズレた**のに気づかず進む
   → “誰かのローカルだけ動く” 地獄👹
   `npm ci` はズレをエラーで止めてくれる（止まるのが正しい）([docs.npmjs.com][4])

3. **更新作業が属人化**して、いつの間にか古くなる
   → まとめて更新して爆発💣 → 更新が怖くなる😇

---

## 運用ルールの「3点セット」📦✨

運用ルールは、最低これだけ決めれば勝てます👇

* **何を固定するか**（固定対象リスト）
* **どう更新するか**（更新の手順・頻度・責任）
* **壊れた時どう戻すか**（復旧の最短手順）

ここからは、そのままコピペで使える形に落としていきます💪😆

---

## 固定を壊さない運用ルール 10か条📜🔥

### ルール1：Nodeは「Active LTS系列」を基準にする🟢

* 今なら v24 系が軸（公式ステータス表に従う）([nodejs.org][1])
* “Current” は試すのはOK、でも標準にはしない（事故率が上がる）😅

### ルール2：DockerのFROMは「浮かない指定」にする🏷️🔒

おすすめ順👇

* **最強固定**：digest（完全固定）
* **次点**：`24.x.y-bookworm-slim` みたいにパッチまで固定
* **最低ライン**：`24-bookworm-slim`（更新される前提で運用する）

※ `bookworm-slim` 系のタグが用意されているのは公式一覧で確認できるよ👀([hub.docker.com][3])

### ルール3：依存は lockfile を“正”とする📌

* `package-lock.json` は **必ずコミット**✅
* lockfile を手で編集しない✋

### ルール4：インストールは「npm ci」を標準にする🧼📦

* **CI / Docker build / 検証**は `npm ci`
* `npm ci` は lockfile 前提で「クリーンに同じ依存を入れる」用コマンド([docs.npmjs.com][4])

### ルール5：ローカル起動は “必ず” Compose経由にする🐳🔁

* “ホストのNodeで動かさない” を文化にする
* コマンドを統一すると、ミスが激減する✨

### ルール6：起動時にバージョンを必ずログに出す🧾👀

* Node / npm / TypeScript の版を表示
  → 「動かない」って言われた時の初手が速くなる⚡

### ルール7：更新は「小さく・定期的に」📅🧩

* 目安：**月1回**（少なくとも四半期に1回）
* まとめ更新は爆発しやすいので避ける💣

### ルール8：更新PRは自動化する🤖✨

* 依存更新のPRをボットに任せる（例：GitHub の Dependabot / Renovate など）
* 人間はレビューに集中😆👍

### ルール9：CIで「再現性テスト」を必ずやる✅🧪

* Docker build → コンテナ内で `npm ci` → テスト
* ここが通れば「固定は壊れてない」って言える😌

### ルール10：壊れた時の復旧手順をREADMEに固定で置く🧯📄

* “手順がある” だけで心理的安全性が爆上がりする😌✨

---

## コピペで使える 運用ルールテンプレ📄✨

`docs/runtime-policy.md` として置くイメージです👇

```md
## Runtime固定 運用ルール

## 固定対象
- Node: Active LTS系列（現在は v24 系）
- OSイメージ: Debian bookworm-slim 系
- 依存: package-lock.json を正とする

## インストール規約
- CI / Docker build は npm ci
- npm install は「依存更新のときだけ」

## 更新ルール
- 毎月1回、依存更新PRを確認して取り込む
- Node更新は「パッチ更新 → 問題なければマイナー」の順で進める

## 変更手順（Nodeを上げるとき）
1. Dockerfile の FROM を更新
2. docker compose build --no-cache
3. docker compose run --rm app node -v / npm -v
4. テスト実行
5. 変更点をCHANGELOGに1行書く

## 壊れたときの復旧（まずこれ）
- docker compose down -v
- （必要なら）ローカルの node_modules を削除
- docker compose build --no-cache
- docker compose up
```

---

## ルールを“守らせる仕組み”も作ろう🔒🤖

### 1) バージョン確認コマンドを用意する✅

```json
{
  "scripts": {
    "check:versions": "node -v && npm -v && npx tsc -v"
  }
}
```

* `npx tsc -v` は “そのプロジェクトのTS” を見にいけるので事故が減ります😆

TypeScript 5.9系の変更点や方針は公式のリリースノート／ブログも雰囲気掴むのに便利だよ🧠([typescriptlang.org][5])

### 2) CIでDocker内チェックを回す✅🐳

（Microsoft の GitHub Actions を想定した例）

```yaml
name: ci

on:
  push:
  pull_request:

jobs:
  docker-repro:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: docker build -t app:ci .
      - name: Repro check
        run: |
          docker run --rm app:ci node -v
          docker run --rm app:ci npm -v
          docker run --rm app:ci npm ci
```

ポイント💡

* `npm ci` を必ず通す（ズレたら落ちる）([docs.npmjs.com][4])
* “通る = 固定できてる” の強い証拠になる😆✅

---

## Windowsで固定運用する時の注意⚠️🪟🐧

* Docker Desktop は WSL2 バックエンドが基本ルート🧭([Docker Documentation][6])
* WSL2の状態確認は `wsl.exe -l -v` でできる（公式にも記載あり）([Docker Documentation][6])

ここがグラつくと「なんか遅い」「マウントが変」「ファイル監視が変」みたいな症状が出やすいので、最初に整えるのが吉です🙏✨

---

## よくある事故と即復旧レシピ🧯💨

### 事故A：`npm ci` が lockfile のズレで落ちる😇

✅ 正しい対応：

* 依存更新のPRで `npm install` をやり直して lockfile を作り直す
* その後 `npm ci` が通ることを確認してコミット
  （`npm ci` はズレを許さないのが仕様）([docs.npmjs.com][4])

### 事故B：Dockerのキャッシュが悪さしてるっぽい🤔

✅ まずこれ：

* `docker compose build --no-cache`
* それでも怪しければ `docker compose down -v`（volumeも落とす）

### 事故C：Currentに上げたら動かなくなった💥

✅ 運用ルールで助かるやつ：

* “標準はActive LTS” なので、すぐ戻せる（戻すのが正義）🟢
  公式のリリース状態を基準にするだけで、判断がブレなくなります([nodejs.org][1])

---

## AIに手伝わせると速い🤖⚡

GitHub Copilot や OpenAI系拡張に、こんな感じで投げると一瞬で整います👇

* 「このリポジトリ用に `docs/runtime-policy.md` を作って。NodeはActive LTS、npm ci、lockfile必須、更新手順と復旧手順つき」
* 「PRテンプレを作って。変更理由、再現手順、動作確認、破壊的変更の有無、ロールバック手順を含めて」
* 「GitHub Actionsで、Docker build → npm ci → テストまで回す最小CIを作って」

---

## まとめ🎁✨

この章で作ったのは「固定そのもの」じゃなくて、**固定を守る仕組み**です😊

* NodeはActive LTS基準（今はv24）([nodejs.org][1])
* TypeScriptは5.9系が現実的な軸（npm Latest 5.9.3）([npm][2])
* `npm ci` と lockfile が再現性の心臓部([docs.npmjs.com][4])
* WindowsはWSL2前提で安定運用([Docker Documentation][6])

---

次の第30章は「テンプレ化して毎回コピペで勝つ」ですね📦🏁🎉
この第29章で作った運用ルールを、そのままテンプレに埋め込めば「最初から壊れにくいプロジェクト」が量産できます😆🔥

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://www.npmjs.com/package/typescript?activeTab=versions&utm_source=chatgpt.com "typescript"
[3]: https://hub.docker.com/_/node?utm_source=chatgpt.com "node - Official Image"
[4]: https://docs.npmjs.com/cli/v9/commands/npm-ci/?utm_source=chatgpt.com "npm-ci"
[5]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[6]: https://docs.docker.com/desktop/features/wsl/?utm_source=chatgpt.com "Docker Desktop WSL 2 backend on Windows"
