## 第2章 改修・バグ修正と混ぜないコツ🔀🚧

### ねらい🎯

* 「今日の変更は何？」を1つに絞れるようになる✂️✨
* 差分（diff）が読みやすくなって、レビューも自分の理解もラクになる👀💡
* “壊さずに改善”の土台（リファクタの信頼）を作る🛟🌸

---

### まず結論：混ぜないコツはこれだけ🍱✨

* **1つの変更単位に、目的は1つ**（改善か？修正か？追加か？）🎯
* **「ふるまい（挙動）」を変える変更**と、**「内部構造」を整える変更**を分ける🧩➡️🧼
* **説明文（コミットメッセージ/PR説明）を、読んだ人が1回で理解できる**ようにする📝💞

---

### なぜ混ぜると危ないの？😵‍💫💥

混ぜると、こんな事故が起きやすいよ👇

* **バグ修正の差分に、見た目変更や命名変更が混ざる**
  → 「結局どこが直ったの？」が分からない👻
* **リファクタの途中に仕様変更を入れる**
  → 「壊したのか、変えたのか」が判別不能😱
* **レビューが遅くなる／通らない**
  → 変更意図が多すぎると、人は確認できない🌀

---

### 「混ざってるかも…」のサイン👃⚠️

次のどれかが出たら、だいたい混ざってる🫣

* diffがでっかい（変更行が多い）📏
* ファイルがめっちゃ増える📁📁📁
* 「ついでに…」が3回以上出てくる🙈
* 説明文が「あとで口で説明します」になりがち🗣️💦

---

### いまどき事情（2026っぽい話）🧁✨

* TypeScriptは **5.9.3** が安定版として出ていて、次の大きめ更新（6.0/7.0）が話題になってるよ📈🧷 ([GitHub][1])
* VS Codeでは、Copilotで **変更差分からコミット文を作る “sparkle（キラキラ）”** が使える（ただし内容チェックは必須！）✨📝 ([Visual Studio Code][2])
* そのコミット文も、**自分のルール（日本語・Conventional Commits など）を設定で指示**できるよ🧭🧠 ([Visual Studio Code][3])

---

## 混ぜないための「分け方」3パターン🍱💡

### ① 目的で分ける（いちばん強い）🎯

目的のラベルを、まず口に出して決める😆👇

* **Refactor**：動作を変えずに、読みやすく/直しやすくする🧼
* **Fix**：間違った動作を正しくする🩹
* **Feature**：新しい動作を追加する🆕
* **Chore**：ビルド設定・依存更新など（中身の都合）🧰

👉 **1つの変更単位で、これを混ぜない**のが最優先！

---

### ② 層で分ける（「挙動」と「構造」）🧱

* **挙動を変える**：仕様・バグ修正・条件追加・戻り値変更 など
* **構造を変える**：命名・関数抽出・重複除去・整理 など

👉 リファクタの安心は「挙動は同じです」が言えること💞

---

### ③ 時間で分ける（手が止まったら分割）⏱️

作業中に「やば、混ざりそう」って思ったら👇

* いったん **“リファクタだけ”** で区切る🧼
* 次に **“修正だけ”** で区切る🩹

（この“区切り”は、コミットでもブランチでもOKだよ🌿）

---

## コード例（ビフォー/アフター）🧩➡️✨

### お題：送料計算が読みづらい＆バグもありそう😵‍💫📦

#### Before（ぐちゃっと版）🙈

```typescript
type User = {
  isPremium: boolean;
  country: "JP" | "US";
};

export function calcShippingFee(user: User, total: number): number {
  // 送料：JPは基本500、USは基本1500
  // プレミアムは無料...のはず？
  // 5000円以上で送料無料...のはず？
  if (user.country === "JP") {
    if (user.isPremium) {
      return 0;
    }
    if (total > 5000) {
      return 0;
    }
    return 500;
  } else {
    if (user.isPremium && total > 5000) {
      return 0;
    }
    return 1500;
  }
}
```

ここ、気になる点いっぱい👃💦

* 「…のはず？」がコメントにある（仕様があいまい）🫧
* JPとUSで条件がズレてそう（USは premium でも無料にならないことがある）🤔
* マジックナンバー（5000, 500, 1500）🔢

---

## ✅ 分けて直す（超重要）：まずはリファクタだけ🧼✨

### Step 1：リファクタ（挙動は変えない）👣

ポイントはこれ👇

* **定数化**（意味を名前に）🏷️
* **条件を整理**（読みやすく）📚
* **国別ルールを “表現” する**（だけ。変更しない！）🧊

#### After（Refactor-only）🧼

```typescript
type User = {
  isPremium: boolean;
  country: "JP" | "US";
};

const FREE_SHIPPING_THRESHOLD = 5000;
const BASE_FEE_BY_COUNTRY: Record<User["country"], number> = {
  JP: 500,
  US: 1500,
};

export function calcShippingFee(user: User, total: number): number {
  const baseFee = BASE_FEE_BY_COUNTRY[user.country];

  const qualifiesFreeShipping =
    user.country === "JP"
      ? user.isPremium || total > FREE_SHIPPING_THRESHOLD
      : user.isPremium && total > FREE_SHIPPING_THRESHOLD;

  return qualifiesFreeShipping ? 0 : baseFee;
}
```

✅ これで「読みやすくなった」けど、**USのルールはまだ同じ（＝怪しいまま）**だよ🫣
ここが大事で、**リファクタの段階では “怪しさ” を勝手に直さない**！🚧

---

## ✅ 次にバグ修正（挙動を変える）🩹✨

### Step 2：バグ修正は “それだけ” の変更にする👣

たとえば「Premiumは国に関係なく無料」が正しい仕様だったなら👇

```typescript
export function calcShippingFee(user: User, total: number): number {
  const baseFee = BASE_FEE_BY_COUNTRY[user.country];

  const qualifiesFreeShipping =
    user.isPremium || total > FREE_SHIPPING_THRESHOLD;

  return qualifiesFreeShipping ? 0 : baseFee;
}
```

ここで初めて、**挙動が変わった**って胸を張って言える💪✨
レビューする人も「なるほど、仕様こう変えたのね」って追えるよ👀🌸

---

## もし途中でバグを見つけたら？🫨🧯（混ぜない判断ルール）

状況別に、こう決めると迷いにくいよ👇

### A）仕様が明確（正解が分かる）✅

* **先にバグ修正**（小さく）🩹
* 次に **リファクタ**（同じ挙動のまま整える）🧼

### B）仕様があいまい（正解が分からない）🫧

* 先に **リファクタだけ** して読みやすくする🧼
* 仕様確認してから **別の変更** として直す🩹

👉 仕様が曖昧なまま直すと、バグ修正じゃなくて“改造”になりがち⚠️

---

## 手順（小さく刻む）👣🛟

### 変更に入る前（30秒）⏱️

1. 今日の変更を1行で言う📝

   * 例：「送料計算を読みやすくする（挙動は変えない）」🧼
2. 変更をラベル付けする🏷️

   * Refactor / Fix / Feature / Chore

### 作業中（混ざりそうになったら）🚧

1. いったん “Refactorだけ” で区切る✂️
2. そのあと “Fixだけ” を別でやる🩹
3. それぞれ説明文を書く📝

---

## ミニ課題✍️🎀（分類してみよ〜！）

次の変更は、どれ？（Refactor / Fix / Feature / Chore）🎯

1. 変数名 `a` を `totalPrice` に変えた🏷️
2. `total > 5000` を `total >= 5000` に変えた🔧
3. 新しく「北海道は送料+300」を追加した🆕
4. Prettierでフォーマットを整えた🎀
5. 例外メッセージを読みやすい文章に変えた📝

### 解答例✅

1. Refactor 🧼
2. Fix 🩹（挙動が変わる可能性が高い！）
3. Feature 🆕
4. Chore（または RefactorでもOKだけど、目的が見た目ならChoreが分かりやすい）🧰
5. Refactor（挙動が同じなら）🧼

---

## AI活用ポイント🤖✨（お願い方＋チェック観点✅）

### ① 変更を「混ざってない？」って監査してもらう👮‍♀️

プロンプト例👇

```text
このdiff（または変更内容）を、Refactor / Fix / Feature / Chore に分類して。
混ざっている場合は「どう分けると安全か」を2案出して。
それぞれの案で、レビューが楽になる理由も一言添えて。
```

チェック観点✅

* 1つの変更単位に目的が1つ？🎯
* 挙動が変わる行が混ざってない？🧠

---

### ② コミットメッセージをAIに作らせる（でも採用は自分！）📝🤖

VS CodeのSource Control入力欄にある **✨（sparkle）でコミット文生成**ができるよ。([Visual Studio Code][2])
ただし、AIのコミット文は間違うことがあるので、**必ずdiffと一致してるか確認**しようね🔍 ([GitHub Docs][4])

---

### ③ 生成ルールを「日本語・短め・分類つき」に固定する🧭

Copilotには **コミット文生成の指示**を設定できるよ（設定名も公式で載ってる！）🧩 ([Visual Studio Code][3])

例：指示ファイル（`copilot/commit-message.md` みたいな名前でOK）📄

```text
- 日本語で1行（最大60文字）
- 先頭に種別を付ける: refactor:, fix:, feat:, chore:
- 「何を」「なぜ」を最小で
- 挙動変更がある場合は必ず明記
```

---

## 今日のまとめ🌷✨

* **目的は1つに絞る**（混ぜないのが最強）🎯🍱
* **リファクタ（挙動そのまま）→ 修正（挙動変える）** の順に分けると安全🧼➡️🩹
* **AIは“提案係”**。採用する前に **diffと一致**してるか必ず確認👀🤖✅

[1]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[2]: https://code.visualstudio.com/docs/copilot/copilot-smart-actions?utm_source=chatgpt.com "AI smart actions in Visual Studio Code"
[3]: https://code.visualstudio.com/docs/copilot/customization/custom-instructions?utm_source=chatgpt.com "Use custom instructions in VS Code"
[4]: https://docs.github.com/en/copilot/responsible-use/copilot-commit-message-generation?utm_source=chatgpt.com "Responsible use of GitHub Copilot commit message ..."
