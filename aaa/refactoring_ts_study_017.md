# 第17章 リファクタの優先順位（どこから直す？）🧭✨

## ねらい🎯

* 「どこから直すか」を**迷わず決める**基準を持つ🧠✨
* 効果が大きい場所（＝“痛い場所”）から直して、**バグと手戻りを減らす**🐛➡️😌
* 「全部直したい…！」をやめて、**安全に前へ進む**👣🛟

---

## まず結論（超ざっくり）⚡

優先順位は、だいたいこれで決まります👇

**よく変わる（変更頻度）🔁 × 難しい（複雑さ）🌀 × 壊れやすい（バグ履歴）🐛**
この3つが重なる場所が、いわゆる **Hotspot（ホットスポット）🔥** です。
ホットスポットを使って技術的負債や保守の問題を優先的に直そう、という考え方が実務でも定番です。 ([CodeScene][1])

---

## なぜ優先順位が必要？😵‍💫➡️😌

* リファクタは時間が無限じゃない⏳
* 「一番汚いコード」から直すと、**全然触らない場所**で空振りしがち🥲
* 逆に「よく触る場所」を整えると、毎回の変更がラクになって**バグも減りやすい**✅

特に、**変化（churn）が高い領域での継続的な変更**は、欠陥（defects）と強く結びつく指標として語られています。 ([SonarSource][2])

---

## 優先順位の“3本柱”🧱✨

### 1) 変更頻度（Code Churn）🔁

* ざっくり言うと「そのファイル、最近めっちゃ触ってる？」ってこと👀
* churn は「どれくらい頻繁に変更されているか」の指標として説明されます。 ([Stepsize][3])
* **触る回数が多い＝将来も触る可能性が高い** → 直す価値が高い📈

### 2) 複雑さ（理解コスト）🌀

* ネストが深い、条件が難しい、関数が長い、名前が曖昧…😵‍💫
* “難しいところ”は、少しの変更でも事故りやすい💥
* churn と complexity を組み合わせて優先順位をつける（ホットスポット分析）は実務でよく使われます。 ([DEV Community][4])

### 3) 壊れやすさ（バグ履歴・事故履歴）🐛🚑

* 「ここ、よく障害が出る」「バグ修正コミットが多い」みたいな場所
* churn（変更量）や変更範囲（変更ファイル数）は、修正の影響や作業量の予測にも関係します。 ([ACM Digital Library][5])

---

## すぐ使える！ホットスポット採点（1〜5点）🧮✨

難しい計測ツールがなくても、まずはこの“雑でも強い”やつでOKです👌💕

### 採点表📝

| 軸       | 1点     | 3点       | 5点              |
| ------- | ------ | -------- | --------------- |
| 変更頻度🔁  | ほぼ触らない | ときどき触る   | 毎週触る／PRが集中      |
| 複雑さ🌀   | すぐ読める  | 少し読むのに時間 | ネスト地獄／巨大関数／読めない |
| 壊れやすさ🐛 | バグほぼ無し | ときどきバグ   | バグ修正多い／事故が出る    |

**合計が高いほど優先🔥（まずは上位1〜2個だけ！）**

---

## データの集め方（最小セット）🔎✨

### A. Gitで「最近よく変わるファイル」を出す🔁

#### PowerShell（Windows向け）🪟

```powershell
git log --since="90 days ago" --name-only --pretty=format: |
  Where-Object { $_ -ne "" } |
  Group-Object |
  Sort-Object Count -Descending |
  Select-Object -First 20 Count, Name
```

👉 これで「直近90日でコミットに登場回数が多いファイル」が上から出ます📈
（期間は 30 days / 180 days でもOK！）

#### Git Bash（使ってる人向け）🐧

```bash
git log --since="90 days ago" --name-only --pretty=format: \
 | sort | uniq -c | sort -nr | head -20
```

高 churn は「よく更新される＝ホットスポット候補」になりやすい、というのはよく使われる考え方です。 ([Embedded Artistry][6])

---

### B. VS Codeで「複雑そう」を嗅ぎ分ける👃✨

次のサインが多いほど、複雑さスコアを上げてOK👇

* 関数が長い（目安：40行〜）📏
* if/for/switch のネストが深い（3段〜）🪆
* 変数名が曖昧（data, tmp, flag, list2…）😶
* 例外・戻り値・状態がぐちゃぐちゃ😵

---

### C. バグ履歴の見つけ方（ざっくりでOK）🐛

* PR/コミットのタイトルに `fix`, `bug`, `hotfix` が多いファイル
* Issueで頻出するモジュール名
* 「ここ触ると壊れる」ってみんなが言う場所（チームの知識）🗣️

---

## ワーク：優先順位付け（テンプレ）📝✨

### 手順👣

1. Gitで churn 上位10ファイルを出す🔁
2. それぞれに「複雑さ🌀」を1〜5で付ける（読むのに何分かかる？でOK）⏱️
3. 「壊れやすさ🐛」を1〜5で付ける（バグ修正の多さ・事故感）
4. 合計点を出して、**上位1〜2個だけ**を今週の対象にする🔥

---

## 例：3つの候補、どれから？🎬

### 状況（よくある）📦

* `src/checkout/checkout.ts`：毎週触る、条件分岐だらけ、過去にバグ多い
* `src/utils/date.ts`：たまに触る、短い、安定
* `src/admin/report.ts`：触る回数は少ないけど、巨大で読みにくい

### 採点してみる🧮

| ファイル        | 変更頻度🔁 | 複雑さ🌀 | 壊れやすさ🐛 |     合計 |
| ----------- | -----: | ----: | ------: | -----: |
| checkout.ts |      5 |     4 |       5 | **14** |
| report.ts   |      2 |     5 |       2 |      9 |
| date.ts     |      2 |     1 |       1 |      4 |

✅ **最優先：checkout.ts**（ホットスポット🔥）
次点：report.ts（ただし「触らないなら後回し」もアリ）

ホットスポットを使って「よく触る×難しい」を優先しよう、という方針は技術的負債の優先付けでもよく語られます。 ([CodeScene][7])

---

## ビフォー/アフター（優先順位の付け方）🔀✨

### ビフォー😇（ありがち）

* 「一番汚い見た目のファイル」から着手
* 途中で別の問題が出て寄り道
* いつの間にか大改造になって疲れる😵‍💫

### アフター😌（この章のやり方）

* churn 上位から候補を出す🔁
* 複雑さ🌀とバグ🐛で点を付ける
* 上位1〜2個に絞って“安全に小さく”進める👣🛟

---

## よくある失敗パターン集💥（回避しよ〜！）

* **「全部直す」宣言** → 永遠に終わらない🌀
* **触らない場所を完璧にする** → コスパ最悪🥲
* **大改造（ビッグバン）** → レビュー地獄＆バグ祭り🎆
* **数字だけ信じる** → “現場の痛み”も一緒に見るのが正解👀

---

## ミニ課題✍️🌸

1. 自分のリポジトリで、PowerShellコマンドを実行して「churn上位10」を出す🔁
2. 上位10に、複雑さ🌀（1〜5）と壊れやすさ🐛（1〜5）を付ける
3. 合計点の上位2つを選ぶ
4. それぞれについて「なぜ今やる？」を1行で書く📝✨

---

## AI活用ポイント🤖✅（お願い方テンプレつき）

AIには「判断」じゃなくて、**材料の整理**をやってもらうのがコツです💡

### 1) churn結果を貼って、要約してもらう🧾

お願い例👇

```text
以下は git log から集計した「直近90日でよく変更されたファイル一覧」です。
上位10個について、(1)ホットスポット候補の理由を短く、(2)追加で確認すべき情報（テスト有無、依存、バグ履歴など）を箇条書きで出して。
最後に「今週やるなら上位1〜2個」に絞って、根拠も添えて提案して。
```

### 2) “根拠つき”で優先順位を文章化してもらう🧠

お願い例👇

```text
次の候補A/B/Cを、変更頻度・複雑さ・バグリスクの3軸で比較して、
優先順位を付けて。各軸の判断は「観測できる事実（例：変更回数、ネストの深さ、fixコミットの多さ）」に紐づけて説明して。
```

### 3) 注意⚠️（ここ大事）

* AIが「雰囲気でAが良さそう」と言ったら、**即アウト**🙅‍♀️
* 必ず「観測できる根拠」に戻す✅（churn、複雑さサイン、バグ履歴）

---

## まとめ🧁✨

* 優先順位は **変更頻度🔁・複雑さ🌀・バグ履歴🐛** の3点で決める
* **Hotspot（よく変わる×難しい）** から直すのがコスパ最強🔥 ([CodeScene][1])
* churn が高い領域の継続的な変化は欠陥リスクのシグナルとして語られるので、見逃さない👀✨ ([SonarSource][2])
* 上位1〜2個に絞って、次章の「変更を分割する設計🧩👣」へ進もう💨

[1]: https://codescene.io/docs/guides/technical/hotspots.html?utm_source=chatgpt.com "Technical Debt — CodeScene 1 Documentation"
[2]: https://www.sonarsource.com/blog/seven-indicators-your-codebase-is-unmanageable/?utm_source=chatgpt.com "Seven indicators your codebase is unmanageable"
[3]: https://stepsize.com/blog/code-churn?utm_source=chatgpt.com "What Lies Beneath Hard Work: Code Churn"
[4]: https://dev.to/nicoespeon/focus-refactoring-on-what-matters-with-hotspots-analysis-3l1b?utm_source=chatgpt.com "Focus refactoring on what matters with Hotspots Analysis"
[5]: https://dl.acm.org/doi/full/10.1145/3593802?utm_source=chatgpt.com "Predicting the Change Impact of Resolving Defects ..."
[6]: https://embeddedartistry.com/blog/2018/06/21/gitnstats-a-git-history-analyzer-to-help-identify-code-hotspots/?utm_source=chatgpt.com "GitNStats: A Git History Analyzer to Help Identify Code ..."
[7]: https://codescene.com/blog/tech-debt-examples-prioritize-technical-debt-with-codescene?utm_source=chatgpt.com "Tech Debt - prioritize technical debt with CodeScene"
