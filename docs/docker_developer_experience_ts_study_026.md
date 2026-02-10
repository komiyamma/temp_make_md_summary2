# 第26章：Biomeという別解（速さで勝つ）⚡

この章は **「ESLint + Prettier」以外の“速い一体型”**として、**Biome**を触って「使い分けの判断」ができるようになる回だよ😊🚀
（2026-02-10時点で `@biomejs/biome` の latest は **2.3.14**）([npm][1])

---

## 1) この章のゴール🎯✨

* **Lint + Format + import整理**を、Biomeの **1コマンド**で回せるようにする🧹⚡([Biome][2])
* VS Codeで **保存したら自動で整う**（整形＋安全な修正＋import整理）状態にする💾✨([Biome][3])
* 「今のプロジェクトはESLint/Prettierのままが良い？」「Biomeに寄せる？」の判断軸を作る🧭🙂

---

## 2) Biomeって何？ざっくり🍱✨

Biomeは **“Web開発のツールチェーン”**で、**formatter / linter / import sorting** などをまとめて扱えるよ⚡
CLIとしても **`biome check` / `biome ci`** みたいに「まとめて走らせる」設計が中心になってる🧩([Biome][2])

---

## 3) まず結論：Biomeが刺さる場面🧭⚡

**Biomeが向いてる👍**

* 「設定を分けたくない！」→ **LintとFormatを一体で**サクッと回したい🧹✨([Biome][2])
* 「とにかく軽くしたい！」→ **実行が速い系**へ寄せたい🏎️💨
* 「保存したら勝手に整ってほしい！」→ VS Code連携が気持ちいい💾🌈([Biome][3])

**ESLint/Prettierを残したい（or 併用）🤝**

* 特定のESLintプラグイン依存が強い（フレームワーク固有ルール等）
* 既存のチーム規約がESLintルールでガッチガチに固まってる
* Prettierの運用がすでに完全に安定してる（ちなみに Prettier は 2026-01-14 に 3.8 が出てるよ）([prettier.io][4])
* ESLintは **Flat Config + extends** など進化中（最近の方針も押さえたいならここ）([eslint.org][5])

---

## 4) 10分ハンズオン：導入 → 1回で体感🏃‍♂️💨

### 4-1. インストール📦✨

プロジェクト直下（`package.json` がある場所）で👇

```bash
npm install --save-dev --save-exact @biomejs/biome
```

([Biome][6])

### 4-2. 初期化（biome.jsonを作る）🧩

```bash
npx biome init
```

Biomeの `init` は **設定ファイルを作ってくれる**よ🛠️([Biome][2])

### 4-3. まず“全部まとめて”走らせる✅🧹

```bash
npx biome check --write .
```

`check` は **formatter + linter + import sorting** をまとめて実行するコマンド✨([Biome][2])
`--write` で **ファイルを実際に直す**よ✍️

### 4-4. “CI用（書き換えない）”で走らせる🔒✅

```bash
npx biome ci .
```

`ci` は **CI向けの読み取り専用**（ファイルを書き換えない）なのがポイント！🧯([Biome][2])

---

## 5) biome.json 最小理解🧠✨（ここだけ押さえればOK）

Biomeの設定は `biome.json` / `biome.jsonc` で管理するよ🗂️
モノレポなどでは `extends` で“親設定を継承”できるのも便利✨([Biome][7])

**まずは超ミニマム例👇（イメージ）**

```json
{
  "$schema": "https://biomejs.dev/schemas/2.3.14/schema.json",
  "formatter": { "enabled": true },
  "linter": { "enabled": true },
  "organizeImports": { "enabled": true }
}
```

* `$schema` を置くと **補完が効いて設定ミスが減る**🧠✨（スキーマは公式が提供）([Biome][8])
* まずは「全部ON」でOK。細かい流儀は後で育てれば大丈夫🙂🌱

---

## 6) VS Codeで「保存したら全部」💾✨（ここが超気持ちいい）

### 6-1. 拡張機能を入れる🧩

Biome公式のVS Code拡張があるよ✅
「Format on save」「Quick fix」などが入る✨([Visual Studio Marketplace][9])

### 6-2. 保存時フォーマットON🧹

Biome拡張は formatter として登録されて、`editor.formatOnSave` で保存時整形ができるよ💾([Biome][3])

### 6-3. 保存時に“安全な修正”もON🛠️

`editor.codeActionsOnSave` に `source.fixAll.biome` を足すと、**安全な修正だけ**を保存時に適用できる👌✨([Biome][3])

### 6-4. import整理も保存時にON📚✨

`source.organizeImports.biome` を足すと、importの整理も保存時に回るよ🔁([Biome][3])

**`.vscode/settings.json` の例（この章のゴール形）👇**

```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.biome": "explicit",
    "source.organizeImports.biome": "explicit"
  },
  "biome.requireConfiguration": true
}
```

* `biome.requireConfiguration` を `true` にすると、**biome.json がある時だけ**拡張が有効になって事故りにくい🙆‍♂️([Biome][3])

---

## 7) 速度をさらに上げる小技🚀💨（やりたい人だけ）

### 7-1. “変更されたファイルだけ”チェック🧠⚡

`ci` には `--changed` / `--since=REF` があって、差分だけに絞れるよ（大規模PJで効く！）([Biome][2])

例👇

```bash
npx biome ci --changed --since=origin/main .
```

### 7-2. デーモンサーバー（さらに速く）🛰️⚡

Biomeは **daemon server** も持ってて、`start` / `stop` が用意されてるよ🧩([Biome][2])
頻繁に叩く環境だと、体感で速くなることがある🚀

---

## 8) ESLint/Prettierとどう共存する？🤝🧭

ここ、超大事☺️✨
“正解は1つじゃない”から、現場でよくある型を置いとくね👇

**A. Biome一本化（スッキリ最速）⚡**

* Lint/Format/import整理が全部Biome
* コマンドも設定も最少で済む🧹✨

**B. 段階移行（安全）🪜**

* まずは Biome を入れて `check --write` を小さい範囲で実行
* 「気持ちよさ」と「既存ルールの差」を見て、徐々に移す🙂

**C. 併用（必要なところだけ）🧰**

* “この領域はESLintプラグインが必須”みたいな場合だけESLintを残す
* ただし、**同じ仕事（整形など）を二重にしない**のがコツ😅

---

## 9) よくある詰まりポイント🧯😇

* **保存しても整形されない**

  * Biome拡張が入ってるか確認✅([Visual Studio Marketplace][9])
  * `biome.requireConfiguration: true` にしてるなら、`biome.json` があるか確認🗂️([Biome][3])
  * 他のformatter（Prettier等）が“デフォルト”になってると、そっちが勝つことがある⚔️ → ワークスペースのformatter設定を見直し🙂

* **モノレポで設定が効かない / 変な設定を拾う**

  * `biome.configurationPath` で明示できる（Biome v2）🧭([Biome][3])
  * 親子で `extends` を使うのもアリ✨([Biome][7])

* **Biome更新で設定が壊れたっぽい**

  * `biome migrate` が “破壊的変更に追従するためのコマンド”として用意されてる🛠️([Biome][2])

---

## 10) ミニ課題🎓✨（手を動かすと一気に身につく）

**課題A：まず成功体験💪**

1. `npx biome init`
2. わざとインデント崩し＋不要importを作る😈
3. `npx biome check --write .`
4. 差分が整うのを確認✅✨

**課題B：保存だけで自動化💾**

1. `.vscode/settings.json` を入れる
2. ファイルを保存して、**整形＋安全修正＋import整理**が走るか確認🌈([Biome][3])

**課題C：CI想定（書き換えない）🔒**

* `npx biome ci .` を走らせて、問題があったら **CIが落ちる**イメージを掴む✅([Biome][2])

---

## 11) AIで時短🤖✨（Copilot/Codex前提の使い方）

AIは **設定たたき台**にめちゃ強いよ👍
ただし「丸呑み」は事故るので、**“生成 → 差分確認 → Biomeで検証”** の順が安全😊🛡️

**おすすめプロンプト例👇**

* 「このプロジェクト構成（src/ 配下TS中心）で、Biomeの `biome.json` を最小から段階的に強化する案を3つ出して」
* 「ESLint/Prettierの役割分担を壊さないように、Biome導入の“段階移行手順”をチェックリスト化して」
* 「VS Codeで保存時に format + safe fixes + import整理 をBiomeで動かす設定を書いて」([Biome][3])

そして最後に必ず👇で“現実チェック”✅

```bash
npx biome check --write .
npx biome ci .
```

---

次の第27章（npm scripts設計）に繋げるなら、Biomeのコマンドを `lint` / `format` / `check` / `ci` みたいに **覚えなくていい名前**に固定していくのが気持ちいいよ🧩✨

[1]: https://www.npmjs.com/package/%40biomejs/biome?utm_source=chatgpt.com "biomejs/biome"
[2]: https://biomejs.dev/reference/cli/ "CLI | Biome"
[3]: https://biomejs.dev/reference/vscode/ "VS Code extension | Biome"
[4]: https://prettier.io/blog/2026/01/14/3.8.0?utm_source=chatgpt.com "Prettier 3.8: Support for Angular v21.1"
[5]: https://eslint.org/blog/2025/03/flat-config-extends-define-config-global-ignores/?utm_source=chatgpt.com "Evolving flat config with extends"
[6]: https://biomejs.dev/ja/guides/getting-started/?utm_source=chatgpt.com "はじめる - Biome"
[7]: https://biomejs.dev/reference/configuration/?utm_source=chatgpt.com "Configuration - Biome"
[8]: https://biomejs.dev/ja/internals/changelog/version/2-3-14/?utm_source=chatgpt.com "2.3.14 | 変更履歴 - Biome.js"
[9]: https://marketplace.visualstudio.com/items?itemName=biomejs.biome "
        Biome - Visual Studio Marketplace
    "
