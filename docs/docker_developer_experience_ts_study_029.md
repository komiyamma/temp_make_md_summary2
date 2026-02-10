# 第29章：コミット前に自動チェック（軽めに）🪝✨

この章は「うっかりミス」を**コミット直前にサクッと止める**仕組みを作ります😎
ポイントはただ一つ：**重くしない！**（重いと人は使わなくなる…🥺）

---

## この章のゴール🎯

* `git commit`した瞬間に、**最低限のチェック**（Lint/Format）だけ自動で走る✅
* 失敗したらコミットを止めて、**その場で直せる**🛠️
* しかも、**遅くならない**🏃‍♂️💨

---

## 1) まず全体像を1枚で🗺️✨

開発の「自動チェック」は、強さ（重さ）が違う3層で考えるとラクです🙂

1. **保存時（最速）**：VS Codeの自動整形・自動修正💾
2. **コミット前（軽め）**：今回ここ🪝 → “ステージされた差分だけ”をサッと見る
3. **CI（重め）**：PR/Pushで全テスト・全Lint・ビルド確認🚀

コミット前を軽くするコツは、**「全部やらない」勇気**です😌✨

---

## 2) 最小構成：Husky + lint-staged 🧩

* Husky：Gitフック（pre-commitとか）をプロジェクトに入れる役🪝
* lint-staged：**ステージしたファイルだけ**にLinter/Formatterを当てる役✂️✨（だから軽い！）([GitHub][1])

---

## 3) セットアップ手順（コピペでOK）📌

## 3-1) 依存を追加📦

```bash
npm i -D husky lint-staged
```

## 3-2) Huskyを初期化🪝

```bash
npx husky init
```

これで `.husky/pre-commit` が作られて、`prepare` スクリプトも設定される流れが基本です。([typicode.github.io][2])

## 3-3) pre-commit で lint-staged を実行する💡

`npx husky init` で作られた `.husky/pre-commit` を、だいたいこんな感じにします👇

```sh
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx lint-staged
```

---

## 4) lint-staged の設定（軽さの核心🔥）

一番簡単なのは `package.json` に書く方法です🙂
（すでにESLint/Prettierを入れてる前提でいきます🧹✨）

## 4-1) 例：package.json に lint-staged を追加📝

```json
{
  "scripts": {
    "lint": "eslint .",
    "format": "prettier . --write"
  },
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md,yml,yaml}": [
      "prettier --write"
    ]
  }
}
```

lint-staged は「**ステージされてるファイル一覧**」をコマンドに渡して実行してくれるので、全体Lintにならず速いです🚀([GitHub][1])
さらに安全のため、デフォルトで **git stash をバックアップとして作る**挙動もあります🧯（万一の保険）([GitHub][1])

---

## 5) ちゃんと動くか確認する✅✨

1. どれかファイルをちょい編集✍️
2. `git add .`（または部分的に `git add -p`）
3. コミット！

```bash
git commit -m "chore: test hooks"
```

* ここで自動整形が走って、必要ならファイルが書き換わります🧹✨
* 変更されたら、**もう一回ステージして**コミットし直しになります（最初は「えっ」となるやつ😳）

---

## 6) “軽め”に保つ設計ルール🏃‍♂️💨（超重要）

コミット前にやっていいのは、だいたいこれ👇

* ✅ **eslint --fix / prettier --write（ステージ対象だけ）**
* ✅ **型チェックは基本やらない**（重いならCIへ）
* ✅ **テストは基本やらない**（やるなら “超速いユニット数本だけ”）
* ✅ 外部サービス/DBアクセスは絶対NG🙅‍♂️（コミットが止まる地獄）

「コミット前は3〜10秒以内」を目標にすると折れにくいです🙂✨

---

## 7) どうしても詰まったとき（よくあるやつ）🧯

## 7-1) そもそもフックが動かない😵

Gitはフックの場所を `core.hooksPath` で変えられます。Huskyはここを使うタイプなので、**`.husky` が参照されてるか**が大事です🔍([git-scm.com][3])

確認コマンド：

```bash
git config core.hooksPath
```

## 7-2) “今だけ急いでるからスキップしたい”🏃‍♀️💦

`git commit --no-verify` で **pre-commit / commit-msg をバイパス**できます。([git-scm.com][3])
（ただし常用すると意味が薄れるので、緊急避難用で！🚨）

## 7-3) lint-staged が stash を作っててビビる😳

仕様です🙂
バックアップが残ったときも `git stash list` で確認できる想定になってます。([GitHub][1])

## 7-4) “重くて嫌になってきた”😇

やりがちなのは「コミット前に全部やる」病です😂
重いものは **CIか、せいぜいpre-push** に逃がしましょ💨

---

## 8) ミニ課題（10分）🧪✨

1. わざとインデントぐちゃぐちゃ＆unused変数を作る🙃
2. ステージしてコミットする
3. **自動で直る / コミットが止まる**のを体験する
4. 直った差分を見て「ESLint/Prettierが何をしたか」説明できたら勝ち🏆🎉

---

## 9) AIで時短する🤖✨（導入済み前提の勝ち筋）

## 9-1) まずAIに「最小で軽い案」を出させる🧠

例プロンプト（そのまま使ってOK）👇

```text
Husky + lint-stagedで、コミット前チェックを“軽め”にしたい。
ESLint/Prettierは導入済み。ステージしたファイルだけを対象にしたい。
package.json の lint-staged 設定案と .husky/pre-commit の内容を提案して。
重くなる要素（型チェック/全テスト/外部アクセス）は入れないで。
```

## 9-2) AIの出力は「差分」で採用する🧾✨

* AIに「変更点をdiff形式で出して」って言う
* それを見ながら **自分のルールとズレてないか**だけチェック👀
  （“設定はAI、判断は人間”が最強です😎）

---

## まとめ🎁

* コミット前は **「ステージ差分だけ」×「自動修正中心」** が正義🪶✨
* `Husky + lint-staged` で、**うっかりをコミット前に潰せる**🪝
* 重いチェックはCIへ逃がして、**続く仕組み**にする😊

次の章（テンプレ化🎁）に繋げるためにも、ここは“軽くて気持ちいい”状態に仕上げよう〜！🚀✨

[1]: https://github.com/lint-staged/lint-staged "GitHub - lint-staged/lint-staged:  — Run tasks like formatters and linters against staged git files"
[2]: https://typicode.github.io/husky/get-started.html "Get started | Husky"
[3]: https://git-scm.com/docs/githooks "Git - githooks Documentation"
