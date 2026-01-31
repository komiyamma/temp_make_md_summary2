# 5章：GitHubとAI拡張の“使い方の型”🤖🧠✨

## この章でできるようになること🎯

* 変更を **Git** で安全に積み上げて、**Pull Request（PR）** で気持ちよくレビューできるようになる💪✨
* **AI（Copilot / Codex など）** を “丸投げ” じゃなく、**安定して当てる型** で使えるようになる🧩🤖
* 「生成 → 自己レビュー → テスト追加 → 仕上げ」を **毎回同じ手順** で回せるようになる🔁✅

---

## 5-1. まず「GitHubで何を管理するか」超ざっくり整理🧺✨

**GitHub** で管理するのは、ざっくりこの3つだよ😊

* **Issue**：やることメモ（目的・完了条件）📝
* **Branch**：作業用の分岐（本線を汚さない）🌿
* **Pull Request**：変更の説明書＋レビューの場（差分を見てもらう）🔍✨

ここが揃うと、AIにも「今どこまでやったか」「何が正解か」を渡しやすくなるよ🤖📦

---

## 5-2. AIを強くするコツは「順番を固定」すること🔁✨

AIに強い人ほど、実は **プロンプトが上手い** というより、**作業の順番がいつも同じ** なんだよね😊🧠
この章では、次の **4ステップ型** を“型”として固定するよ👇

1. **下書き生成**（まず形にする）🧱
2. **レビュー**（危ない所を自分＆AIで洗い出す）🔍
3. **テスト追加**（壊してない証拠を作る）🧪
4. **手直し**（読みやすさ・保守性・命名を整える）✨✍️

> GitHub Copilot Chat は、GitHub上やモバイル、主要IDE（Visual Studio / VS Code など）でも使えるよ。([GitHub Docs][1])
> Visual Studio側は「補完＋チャット」が統合された体験として案内されてるよ。([Visual Studio][2])

---

## 5-3. “AIに渡す情報”は最小でOK！でも「形」は揃える📌😊

AIが迷子になるのは、だいたい **前提がバラバラ** なとき😵‍💫
だから、毎回この **4点セット** を渡すのがおすすめ✨

* **目的（Goal）**：何をしたい？🎯
* **制約（Constraints）**：やっちゃダメなこと・守ること🧷
* **入力（Inputs）**：対象ファイル、現状コード、仕様メモ📄
* **出力（Outputs）**：完成条件、期待する挙動✅

### 🧰 プロンプト雛形（コピペ用）

```text
【Goal】
（例）〇〇ができるAPIを追加したい

【Constraints】
- 変更は最小限
- 例外は投げっぱなしにしない
- public APIをむやみに増やさない

【Context】
- 現状の仕様（箇条書き）
- 関連ファイル（貼る/列挙）
- 既存の設計ルール（あれば）

【Acceptance Criteria】
- 期待する動作（例：AならB）
- 追加すべきテスト（例：正常系1本＋異常系1本）
```

---

## 5-4. PR（Pull Request）を“レビューしやすい形”にする🧁🔎

PRは「差分」だけじゃなくて、**説明** が超大事！
説明が揃ってると、AIレビューも人間レビューも当たりやすいよ😊✨

### ✅ PRテンプレを入れよう（おすすめ）

PRテンプレは、指定の場所にファイルを置くだけで使えるよ。([GitHub Docs][3])

```md
# 概要 🧾
（このPRで何が変わる？ 1〜3行で）

# 関連Issue 🔗
- #

# やったこと ✅
- 
- 

# やってないこと 🙅‍♀️
- （今回スコープ外のもの）

# 影響範囲 🌍
- （例：API / DB / UI / パフォーマンス など）

# 動作確認 / テスト 🧪
- [ ] ローカルでテスト実行
- [ ] 主要ケース確認（簡単でOK）

# スクショ（必要なら）📸
（UIがある場合だけ）
```

---

## 5-5. “レビューを自動で呼ぶ”CODEOWNERS（チーム開発の入口）👥✨

ちょっと背伸びだけど、**レビュー担当を自動で割り当て** できる仕組みもあるよ📌
`CODEOWNERS` は `.github/` などに置ける（場所の優先順位も決まってる）よ。([GitHub Docs][4])

```text
# 例：ドメイン層はAさん、インフラ層はBさんにレビューを依頼したい
/Domain/   @team-domain
/Infra/    @team-infra
```

---

## 5-6. GitHub Actionsで「テストは自動で回す」🌀🧪

PRを出したら、**自動でテストが走る** ようにすると最高にラク😊
ワークフローは `.github/workflows` に YAML を置く仕組みだよ。([GitHub Docs][5])

### ✅ 最小のテスト実行ワークフロー（例）

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [ "main" ]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "10.0.x"
      - name: Restore
        run: dotnet restore
      - name: Test
        run: dotnet test --configuration Release
```

`.NET 10` は LTS で、3年間サポートされる案内になってるよ。([Microsoft for Developers][6])

---

## 5-7. この章のメイン！「AI活用 4ステップ型」を回してみよう🤖🔁✨

ここからが実戦💪
題材は小さくてOK（ボタン1つ追加、バリデーション1個追加、ログ1行追加…でも十分！）😊

---

# ✅ ステップ① 下書き生成：まず“形”を作る🧱

## やること

* AIに「変更のたたき台」を作ってもらう
* ただし **一気に全部** じゃなくて、**小さく** ね🙏✨

### 💬 例プロンプト

```text
【Goal】
〇〇機能を追加したい（具体的に）

【Constraints】
- 変更は最小限
- 既存のpublic APIを壊さない
- 追加でテストも入れる

【Context】
- 対象ファイル：A.cs / B.cs
- 現状：〜〜（2〜5行で）
- 期待：〜〜

【Acceptance Criteria】
- 条件Aなら結果B
- 異常系はResultで扱う（例外投げっぱなし禁止）
```

📝 コツ：**「どのファイルを触る？」をAIに先に提案させる** と、暴走が減るよ😊

---

# ✅ ステップ② レビュー：AIに“自分でダメ出し”させる🔍🤖

## やること

* AIに **自分の出したコードをレビュー** させる
* “観点” を固定すると強い✅

### ✅ レビュー観点テンプレ（まずはこれだけでOK）🧾

* 仕様：要件を満たしてる？抜けてない？🎯
* 安全：null / 例外 / 境界値は大丈夫？🧯
* 可読性：命名・責務の分離が変じゃない？📚
* 影響：別機能を壊してない？🔧
* テスト：壊れやすい所が検証されてる？🧪

### 🧩 ミニ演習（この章の指定）

AIに「レビュー観点チェックリスト」を作らせる✅

```text
目的：このリポジトリ用のレビュー観点チェックリストを作りたい
条件：C#、小規模、設計は超入門者向け、でも事故は防ぎたい
出力：チェック項目をカテゴリ分け（仕様/安全/設計/テスト/運用）して、各5項目ずつ
```

---

# ✅ ステップ③ テスト追加：AIに“壊してない証拠”を作らせる🧪✨

## やること

* AIに **テストの叩き台** を作ってもらう
* でも最終判断は自分（テスト名・期待値は必ず目視）👀

### 💬 例プロンプト（テスト生成）

```text
この変更に対してテストを追加したいです。
- 正常系：1本
- 異常系：1本（境界値 or ルール違反）
テスト名は読みやすく、Arrange/Act/Assertを明確にしてください。
```

🧠 ここで効く小技：

* **「失敗してほしいケース」を先に文章で書く** → AIが当てやすい😊
* テストが通ったら、PRの説明にも **“何を検証したか”** を1行書く📝✨

---

# ✅ ステップ④ 手直し：最後に“読みやすさ”で勝つ✨✍️

ここはAIが得意💪🤖
でも「やりすぎリファクタ」は事故るので、**小さく** が正義👑

## 💬 例プロンプト（仕上げ）

```text
命名・コメント・重複の整理だけして、挙動は変えないでください。
- 変更前後でpublic APIを変えない
- ついでにnullガードや例外メッセージを改善
```

---

## 5-8. Copilot / Codex を“用途で使い分ける”感覚🧠🎛️

* **Copilot Chat**：いま開いてるコードの相談、短い修正、IDE内の反復に強い📌
  （対応環境として VS / VS Code などが挙がってるよ）([GitHub Docs][1])
* **Codex（エージェント系）**：まとまった作業を“任せてPR提案まで”みたいな方向が得意（研究プレビューとして、PR提案も説明されてる）🚀([OpenAI][7])
  変更履歴（changelog）も公開されてるよ。([OpenAI Developers][8])

---

## 5-9. よくある事故ポイント3つ😵‍💫🧯

1. **AIの出力をそのままコミット**（後で直せなくなる）🙅‍♀️
   → 小さく刻んで、差分を理解してから✅

2. **仕様が曖昧なまま書かせる**（それっぽい嘘が混ざる）🤥
   → Goal / Constraints / Acceptance Criteria を必ず書く📌

3. **テストを後回し**（最後に地獄）🔥
   → ステップ③を“儀式”にしちゃう🧪✨

---

## 5-10. 章末ミニチェック（サクッと）📝💗

**Q1.** PRテンプレのファイル名として推奨される場所の一つは？
A. `.github/pull_request_template.md` ✅（ドキュメントで案内あり）([GitHub Docs][3])

**Q2.** GitHub Actions のワークフローはどこに置く？
A. `.github/workflows` ✅([GitHub Docs][5])

**Q3.** AI活用4ステップ型の順番は？
A. 生成 → レビュー → テスト → 手直し ✅🔁

---

## まとめ🌸✨

* GitHubは「Issue / Branch / PR」で、変更を見える化する🧺
* AIは“上手い文章”より、**順番固定（4ステップ型）** が勝ち🔁🤖
* PRテンプレ＋Actions（テスト自動化）で、レビューが一気にラクになる🧁🧪
* 次章では、CRUDを一度作って「状態保存の限界」を体験していくよ😺🧱

[1]: https://docs.github.com/en/copilot/get-started/features?utm_source=chatgpt.com "GitHub Copilot features"
[2]: https://visualstudio.microsoft.com/github-copilot/?utm_source=chatgpt.com "Visual Studio With GitHub Copilot - AI Pair Programming"
[3]: https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository?utm_source=chatgpt.com "Creating a pull request template for your repository"
[4]: https://docs.github.com/articles/about-code-owners?utm_source=chatgpt.com "About code owners"
[5]: https://docs.github.com/actions/using-workflows/about-workflows?utm_source=chatgpt.com "Workflows"
[6]: https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/?utm_source=chatgpt.com "Announcing .NET 10"
[7]: https://openai.com/index/introducing-codex/?utm_source=chatgpt.com "Introducing Codex"
[8]: https://developers.openai.com/codex/changelog/?utm_source=chatgpt.com "Codex changelog"
