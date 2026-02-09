# 第04章：「固定」には3段階ある📦📦📦

この章は、**「どこまで固定すればいいの？」問題に“答え”を作る回**です✍️✨
結論から言うと、固定は **3レイヤー**に分けると一生迷いません👍

---

## 🎯 この章のゴール

* 「固定すべき場所」を **3つに分解**できる🧠✨
* “最小の固定” と “ガチ固定” の違いが分かる😎
* どのプロジェクトでも使える **判断軸**が手に入る🧭

---

## ✅ 2026-02-09 時点の前提になる事実（超重要）🧱

* **Nodeは v25 が Current、v24 が Active LTS、v22 が Maintenance LTS** という状態です。([Node.js][1])
* Dockerの公式Nodeイメージには、**`24-bookworm-slim` や `24.13.0-bookworm-slim`** みたいな “固定しやすいタグ” が揃っています。([Docker Hub][2])
* TypeScriptは 5.9 系が現行で、npmの “Latest” も 5.9.3 です。([typescriptlang.org][3])

---

## 🌈 固定の3段階（これが全体像！）

固定対象を **ごちゃ混ぜ**にすると、初心者は100%混乱します😇
なので、こう分ける👇

1. **Node本体（ランタイム）** 🟢🐳
2. **パッケージマネージャ（npm / pnpm / yarn）** 🧰🔧
3. **依存（lockfile）** 📌🔒

---

## 1) Node本体を固定する🟢🐳（土台）

## なぜ必要？🤔

Nodeは “同じコード” でも、**バージョン差で挙動が変わる**ことがあります（特に ESM/CJS、標準API、ビルド周り）💥
だから最初に **Nodeを閉じ込めて固定**します🔒

## ✅ どう固定する？

Dockerなら「イメージタグで固定」が最強です💪
公式イメージには、LTS系の `24-...` と、さらに細かい `24.13.0-...` みたいなタグが用意されています。([Docker Hub][2])

## 💡固定タグの“おすすめ段階”🧭

* **初心者の最適解（バランス型）**：`node:24-bookworm-slim`

  * “v24系” の範囲で更新される（セキュリティ面に強い）🛡️
* **ガチ固定（再現性MAX）**：`node:24.13.0-bookworm-slim` のように **パッチまで固定**

  * まったく同じ環境が再現できる（ただし更新は自分でやる）🔁

> 「最初はバランス型」→ 慣れたらガチ固定、が事故りにくいです😄✨

---

## 2) パッケージマネージャを固定する🧰🔧（道具）

## ここ、地味にハマりポイント💣

同じ `package-lock.json` でも、**npmのバージョン差**で微妙に挙動が変わることがあります😇
さらに pnpm/yarn もバージョン差で lockfile の形式・解釈が変わります🌀

## ✅ どう固定する？

ここで出てくる救世主が **Corepack** です🦸‍♂️✨
Corepackは **Nodeに同梱される範囲があり**、少なくとも「Node 25 以降は同梱されない」扱いです（なので LTSの v24 が安定運用向き）。([GitHub][4])

そして **`package.json` の `packageManager` フィールド**で「このプロジェクトはこのpmでこのバージョンね！」を宣言できます📣

* pnpm の最新は **10.29.1**。([npm][5])
* Yarn（Berry系）は npmの `@yarnpkg/cli` が **4.12.0**。([npm][6])

## 例（pnpmに固定する）

```json
{
  "packageManager": "pnpm@10.29.1"
}
```

（※数字は例。チーム/自分の運用で“揃える版”を決めて書く感じです👍）

## 例（Yarn 4系に固定する）

```json
{
  "packageManager": "yarn@4.12.0"
}
```

> もし「npmで行く！」なら、まずは **Nodeを固定＝npmもほぼ一緒に固定**になるので、最初はそれでも全然OKです😆
> （後で必要になったら、npm自体を特定バージョンに上げ下げする運用もできます）

---

## 3) 依存を固定する（lockfile）📌🔒（本丸）

## lockfileは「依存の設計図」🗺️

`package.json` は「希望（範囲指定）」
lockfile は「決定（このバージョン！）」
って感覚です😄

固定の心臓部はここ❤️‍🔥

---

## ✅ lockfile別の“固定コマンド”まとめ

## npm（package-lock.json）

* **`npm ci`** を使う（CI向け・クリーンインストール）🧼
  `npm install` と違う前提が明確に書かれています。([npmドキュメント][7])

## pnpm（pnpm-lock.yaml）

* **CIだと lockfile がズレてたら失敗**する方向（`--frozen-lockfile` 相当がデフォルト）です。([pnpm][8])

## Yarn（yarn.lock）

* **`yarn install --immutable`** で lockfile がズレたら止めるのが王道です。([Yarn][9])

---

## 🧠 “最小の固定セット”はこれだけでOK（まず勝とう😆🔥）

初心者が最初に採用するなら、この3点セットが鉄板です👇

* **Node**：`node:24-bookworm-slim`（LTS固定）([Docker Hub][2])
* **パッケージマネージャ**：まずは **npmでOK**（必要なら Corepack + `packageManager` で固定）([GitHub][4])
* **依存**：lockfileをコミットして、**npmなら `npm ci`** を使う([npmドキュメント][7])

これで「PC差で動かない」系の事故が激減します🥳✨

---

## 🧪 ミニ演習（5分）🕔✨：あなたのプロジェクトはどこまで固定できてる？

プロジェクトに対して、次の3つをチェック✅

1. **Node固定**：Dockerfileの `FROM node:...` に “意図したタグ” が書いてある？([Docker Hub][2])
2. **PM固定**：`package.json` に `packageManager` を書く運用にする？（pnpm/yarnなら特に強い）([npm][10])
3. **依存固定**：lockfileがコミットされていて、インストールが “ズレたら止まる” 設定？([npmドキュメント][7])

---

## 💥 よくある事故と対策（ここだけ覚えればOK）😇

* **事故①：Nodeだけ固定して満足 → lockfileが無い**
  → 依存が毎回変わって「昨日動いたのに…」になる💀
* **事故②：lockfileはあるのに `npm install` で更新される**
  → “いつの間にかlockが書き換わる” 事故
  → npmなら `npm ci` を基本にすると安定🧼([npmドキュメント][7])
* **事故③：pnpm/yarn のバージョン差でlockfileが変わる**
  → Corepack + `packageManager` で揃えると強い🧰([GitHub][4])

---

## 🤖 Copilot/Codexに投げる一言（そのままコピペOK）✨

「このリポジトリを“3段階固定（Node / パッケージマネージャ / lockfile）”にしたい。
Nodeは v24(LTS) の `bookworm-slim` 系で、依存はズレたらエラーで止めたい。
npmなら `npm ci`、pnpmなら frozen、yarnなら immutable の方針で、必要な設定ファイルと最小手順を提案して。」

---

## 🏁 まとめ：固定は“レイヤーで考える”だけで勝てる🎉

* **Node固定**＝環境の土台を揃える🧱
* **PM固定**＝道具の挙動を揃える🧰
* **lockfile固定**＝依存の中身を揃える🔒

次の第5章では、この固定の考え方を使って「できた判定（動くの定義）」を作って、迷いをゼロにします😆✨

[1]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[2]: https://hub.docker.com/_/node "node - Official Image | Docker Hub"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[4]: https://github.com/nodejs/corepack?utm_source=chatgpt.com "nodejs/corepack: Package manager version ..."
[5]: https://www.npmjs.com/package/pnpm?utm_source=chatgpt.com "pnpm"
[6]: https://www.npmjs.com/package/%40yarnpkg/cli?utm_source=chatgpt.com "yarnpkg/cli"
[7]: https://docs.npmjs.com/cli/v9/commands/npm-ci/?utm_source=chatgpt.com "npm-ci"
[8]: https://pnpm.io/9.x/cli/install?utm_source=chatgpt.com "pnpm install"
[9]: https://yarnpkg.com/cli/install "yarn install | Yarn"
[10]: https://www.npmjs.com/package/corepack?utm_source=chatgpt.com "corepack"
