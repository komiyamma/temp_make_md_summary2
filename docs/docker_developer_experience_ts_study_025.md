# 第25章：VS Codeと連携：保存したら全部済む💾✨

この章のゴールはこれ👇
**Ctrl+S（保存）した瞬間に…**

* ✨Prettierで整形
* 🧹ESLintで「直せる問題は自動修正」
* 🧩importの並び替え＆未使用importの整理
* 🪶差分（diff）が最小になる（余計な空白・改行で荒れない）

---

## 25.1 まず、VS Code拡張を入れる🧩

VS Codeの拡張機能（Extensions）で、次の2つを入れてね👇

* **ESLint**（拡張ID: `dbaeumer.vscode-eslint`）([Visual Studio Marketplace][1])
* **Prettier - Code formatter**（拡張ID: `esbenp.prettier-vscode`）([Visual Studio Marketplace][2])

入れたら、次は**チーム共有できる形**にするよ🤝✨

---

## 25.2 チームでも崩れない「.vscode/」を作る📁✨

プロジェクト直下にこれを作る👇

* `.vscode/settings.json`（保存時の自動処理）
* `.vscode/extensions.json`（入れてほしい拡張のおすすめ）

まずは `extensions.json` から👇

```json
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode"
  ]
}
```

これがあると、別の人が開いたときに「この拡張入れてね」ってVS Codeが優しく促してくれるよ😊✨

---

## 25.3 “保存したら全部済む” の基本セット（いちばん王道）💾✅

次に `.vscode/settings.json` を作って、これを入れる👇
（**TS/JSだけに効かせる**ようにして、事故を防ぐスタイル🧯）

```jsonc
{
  // ✅ まずはTS/JSだけを「保存時フォーマット」対象にする（安全！）
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[typescriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },
  "[javascriptreact]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode",
    "editor.formatOnSave": true
  },

  // ✅ 保存したら：ESLintの自動修正 + import整理
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit",
    "source.organizeImports": "explicit"
  },

  // ✅ 差分最小化：余計な空白や改行でPRが荒れない
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true
}
```

ポイント解説🥰👇

* `editor.formatOnSave` は「保存時にフォーマットする」スイッチだよ✨([Visual Studio Code][3])
* `editor.codeActionsOnSave` は「保存時に自動で直す系の処理」を走らせる設定だよ🛠️([Visual Studio Code][4])
* 値の `"explicit"` は「**明示的に保存したときだけ**走る」って意味（`always` / `never` もある）📌([Visual Studio Code][4])
* `source.organizeImports` は import を並べ替え＆未使用を消してくれるやつ🧩✨([Visual Studio Code][5])

---

## 25.4 「Flat Config（eslint.config.*）」のときのVS Code側スイッチ🔧🧾

ESLintがFlat Config中心になってる流れに合わせて、VS CodeのESLint拡張にも設定があるよ👇

```jsonc
{
  "eslint.useFlatConfig": true
}
```

この `eslint.useFlatConfig` は、ESLintのバージョン帯によって既定値や扱いが変わる（そしてESLint 10以降はFlat Configが完全にデフォルトでオフにできない）…みたいな挙動が整理されてるよ🧠([Visual Studio Marketplace][1])

---

## 25.5 「PrettierとESLintの順番」をもっとガッチリ固定したい人向け🧷✨

基本セットでも十分だけど、
「Prettier → ESLint の順で必ず走ってほしい！」みたいなケースもあるよね😊

Prettier拡張は `editor.codeActionsOnSave` で **PrettierのFix**を走らせる方法を案内してる👇([Visual Studio Marketplace][2])

```jsonc
{
  "editor.codeActionsOnSave": {
    "source.fixAll.prettier": "explicit",
    "source.fixAll.eslint": "explicit",
    "source.organizeImports": "explicit"
  }
}
```

さらにVS Code側は **Code Actionを順番つきで実行**できる（順番保証したいとき便利）🧠([Visual Studio Code][4])
ただし、環境や拡張によってIntelliSenseに出る候補が違うことがあるので、迷ったら上の「object形式」でOKだよ👌

**補足（超だいじ）**
Prettierの `source.fixAll.prettier` は `editor.defaultFormatter` を見て動く仕様があるから、二重フォーマット防止にもなってるよ🧯([Visual Studio Marketplace][2])

---

## 25.6 Prettierは「設定ファイルを置く」のが正解ルート📌✨

VS Code設定だけでも動くけど、Prettier拡張は
**“プロジェクトにPrettier設定ファイルを置く”**のを強くおすすめしてるよ（CLIでも同じ結果にしたいから）📄✨([Visual Studio Marketplace][2])

例：`prettier.config.js`（プロジェクト直下）

```js
export default {
  semi: true,
  singleQuote: true,
  trailingComma: "all"
};
```

Prettier拡張は設定の優先順位も明確で、
**(1) Prettier設定ファイル → (2) .editorconfig → (3) VS Code設定（ただしローカル設定があるとVS Code設定は無視）** という流れだよ🧠([Visual Studio Marketplace][2])

---

## 25.7 “保存したら全部済む” 動作確認🧪✨

チェックは簡単！わざと壊す😈→保存する💾→直る🎉

1. TSファイルで、わざとこんな感じにする👇

* 余計な空白
* 使ってないimport
* クォートやセミコロンがぐちゃぐちゃ

2. **Ctrl+S**

3. こうなってたら成功✅

* Prettierで整形される✨
* ESLintで直せるものが直る🧹
* importが整理される🧩

---

## 25.8 よくある詰まりポイント集💥（ここ超あるある）

* 🌀 **保存しても整形されない**

  * `editor.defaultFormatter` が別の拡張になってることが多い（TS/JSの言語別設定で固定すると安定）([Visual Studio Marketplace][2])

* 😵 **Auto Save（自動保存）だとESLint修正が走らない**

  * `"explicit"` は「明示保存だけ」だからね！
  * Auto Saveでも走らせたいなら `"always"` を検討（ただし重くなることも）([Visual Studio Code][4])

* 🐢 **保存が重い／遅い**

  * VS Codeにはフォーマットのタイムアウト設定もある（遅い拡張がいると保存に影響する）([Visual Studio Code][6])
  * まずは「TS/JSだけ対象」に絞るのが効くよ👍

* 🔒 **Prettierが“プラグイン無視”みたいな挙動**

  * ワークスペースが “Trusted” じゃないと、Prettier拡張は内蔵Prettierのみで動く（ローカルpluginが効かない）ことがあるよ🛡️([Visual Studio Marketplace][2])

---

## 25.9 ミニ課題🎓✨（10分で終わる）

**課題A：保存だけで直る体験を作る💾**

* 未使用importを入れる
* わざとインデント崩す
* Ctrl+S
* ✅ import整理＆整形されたらクリア🎉

**課題B：差分を最小化する🧼**

* 行末スペースを入れる
* ファイル末尾の改行を消す
* Ctrl+S
* ✅ 余計な差分が出にくくなったらクリア🎉

---

## 25.10 AIで時短するプロンプト例🤖✨（コピペOK）

* 「このプロジェクト（TS/Node）向けに、PrettierとESLintを“保存時に全部自動”にする `.vscode/settings.json` を提案して。TS/JSだけ対象、`source.fixAll.eslint` と `source.organizeImports` を入れて」
* 「Prettierの設定ファイル（prettier.config.js）を、ESLintと衝突しにくい王道で作って」
* 「この `eslint.config.js` に合わせて、VS Code保存時のCode Action順（Prettier→ESLint→Organize Imports）を提案して」

👉 AIが出した設定は、**“どのファイルに入れるか” と “どの範囲に効くか”**だけ目で確認すれば安全に採用しやすいよ😄✅

---

## まとめ🎁✨

この章で作ったのは、**“保存＝自動整形＋自動修正＋import整理”**の開発体験💾✨
これがあると、コードの見た目や細かい指摘に脳みそを使わずに済むから、設計や実装に集中できるよ🧠🔥

次（第26章）の「Biome」という別解に行くと、ここで作った思想（保存で全部終わらせる）がさらに加速するよ⚡

[1]: https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint "
        ESLint - Visual Studio Marketplace
    "
[2]: https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode "
        Prettier - Code formatter - Visual Studio Marketplace
    "
[3]: https://code.visualstudio.com/docs/getstarted/tips-and-tricks?utm_source=chatgpt.com "Visual Studio Code tips and tricks"
[4]: https://code.visualstudio.com/docs/editing/refactoring "Refactoring"
[5]: https://code.visualstudio.com/docs/languages/javascript "JavaScript in Visual Studio Code"
[6]: https://code.visualstudio.com/updates/v1_22?utm_source=chatgpt.com "March 2018 (version 1.22)"
