# 第14章 デバッグとログ（観測してから触る）🔍🪵

### ねらい🎯

* 「怖いコード」でも、まず状況を**観測**して安心して触れるようになる👀✨
* ブレークポイントで**止めて見る**／ログで**流して見る**を使い分けられるようになる🧠🧷
* 直す前に「どこが変」かを、根拠つきで説明できるようになる📝✅

---

### 今日のゴール🌸（できたら勝ち！）

* 1回はブレークポイントで止めて、変数の中身を見られる🛑🔍
* 「ここにログ置けば原因が見える」ポイントを3つ言える🪵✨
* ログポイント（Logpoint）で**コードを汚さず**観測できる🙌🧼 ([Visual Studio Code][1])

---

## 1) デバッグとログの違い🤔（ざっくりでOK！）

### デバッグ🛑🔍（止めて見る）

* 実行を一時停止して、**その瞬間の状態**（変数・呼び出し順）をチェックできる
* VS Code は JavaScript/TypeScript/Node のデバッグを標準でサポートしてるよ🧑‍💻✨ ([Visual Studio Code][2])

向いてる場面✅

* 「この行で何が入ってる？」を確実に見たい
* ループの途中とか、条件分岐の中で止めたい

### ログ🪵📣（流して見る）

* 実行は止めずに、**通った道**と**値**を記録する
  向いてる場面✅
* 再現が難しい・タイミングが絡む・何回も通る処理
* 本番環境っぽい状況で観測したい

---

## 2) ブレークポイントの基本🛑✨（まず1回止めよう）

### 見るべき場所はこの4つ📌

* **Variables**：今の変数の中身🧺
* **Watch**：気になる式を固定で監視👀
* **Call Stack**：どこから呼ばれたか（道のり）🧗‍♀️
* **Debug Console**：その場で式を評価できる🧪

### 「TypeScriptで止まらない…😭」の最重要ポイント

TypeScriptは実行時にはJavaScriptになるので、**ソースマップ（source map）**で「TSの行」と「実行中のJS」を対応づけるのが超大事だよ🗺️🧷 ([Visual Studio Code][3])

---

## 3) 便利ブレークポイント3点セット🧠🧷

### ① 条件付きブレークポイント（特定の時だけ止める）🚦

「この時だけ止めたい！」ができる✨
例：`userId === "A001"` の時だけ止める、みたいな感じ🧩 ([Stack Overflow][4])

### ② ヒットカウント（10回目だけ止める）🔁

ループで毎回止まるのを回避できる🌀

### ③ ログポイント（Logpoint）🪵✨（止めないのに観測できる）

ブレークポイントの仲間で、**止まらずにログだけ出す**やつ！
「ログ入れたいけどコードは変えたくない…」時の救世主🦸‍♀️ ([Visual Studio Code][1])

---

## 4) ログの置き方：最小で効く🪵🎯

### ログの“置きドコロ”はここ！

1. **入口**：入力（引数・リクエスト）📥
2. **分岐**：どっちルートに入った？🔀
3. **出口**：結果（戻り値・レスポンス）📤
4. **例外**：catchした時は「何が起きたか」⚠️

### “良いログ”の型🧩✨

* 「何の処理？」＋「重要なID」＋「重要な値」
* 文字列を並べるより、**オブジェクトで出す**と読みやすい（検索もしやすい）🧠🔍

---

## 5) コード例（ビフォー/アフター）🧩➡️✨

題材：割引計算がたまにおかしい…という想定💸😵‍💫

### Before：何が起きてるか見えない😶‍🌫️

```ts
// src/checkout.ts
export function calcTotal(price: number, coupon?: { percent: number }, shippingFee = 500) {
  // たまに合計が変に見える…という想定
  const discounted = coupon ? price - price * (coupon.percent / 100) : price;
  const total = Math.round(discounted) + shippingFee;
  return total;
}
```

### After：観測ポイントを追加🪵🔍（直す前に「事実」を集める）

```ts
// src/checkout.ts
export function calcTotal(price: number, coupon?: { percent: number }, shippingFee = 500) {
  console.debug("[calcTotal] input", { price, coupon, shippingFee });

  const discounted = coupon ? price - price * (coupon.percent / 100) : price;
  console.debug("[calcTotal] discounted", { discounted });

  const total = Math.round(discounted) + shippingFee;
  console.debug("[calcTotal] total", { total });

  return total;
}
```

> ポイント🌸：この段階では「直す」じゃなくて「見える化」！
> そして可能なら、ログは Logpoint で代用してコード変更を減らすのもアリだよ🧼🪵 ([Visual Studio Code][1])

---

## 6) 「落ちた時の手がかり」を強くする🧷🗺️（スタックトレース編）

### Nodeのソースマップ対応で、エラーの行が読みやすくなる📍

Node には `--enable-source-maps` があって、トランスパイル後のJSじゃなく**元のソース位置に寄せた**スタックトレースを出せるよ🧭 ([Node.js][5])
※ただし `Error.stack` を頻繁に触るケースでは性能影響がありえる、という注意も公式にあるよ⚠️ ([Node.js][5])

---

## 7) サクッと始めるデバッグ方法2つ🚀

### 方法A：launch.json で“いつもの起動”を固定する📌

VS Codeは Run and Debug から `launch.json` を作って、デバッグ起動の設定をプロジェクトに置けるよ🧷📁 ([Visual Studio Code][6])

### 方法B：Auto Attach（ターミナル実行に自動でくっつく）🧲

VS Code の Auto Attach を有効にすると、統合ターミナルから起動した Node プロセスにデバッガが自動で付いてくるよ🧑‍💻🧲 ([Visual Studio Code][7])

---

## 8) 2026っぽいデバッグ小ネタ🤏✨（知ってると楽）

### tsx を使うと、TSをそのままデバッグしやすい💡

tsx 側も VS Code でのデバッグ手順を案内していて、デバッグの選択肢として「tsx」を使う流れがまとまってるよ🧷🚀 ([tsx][8])

---

## 手順（小さく刻む）👣✅：バグっぽい挙動を観測する👀

1. **再現手順を1行で書く**（例：「クーポン30%で合計が想定よりズレる」）📝
2. 怪しい場所を3つだけ予想する（入口／分岐／出口）🔮
3. まずはブレークポイントを1つ置いて、`price / coupon / discounted / total` を見る🛑🔍
4. 次に Logpoint で「止めずに」同じ情報を出してみる🪵✨ ([Visual Studio Code][1])
5. 取れた事実から「原因候補」を1つに絞る（まだ直さない）🧠✅

---

## ミニ課題✍️🌼（10〜15分）

### 課題1：条件付きで止めてみよう🚦

* `coupon.percent === 30` の時だけ止まるように条件付きブレークポイントを設定して、`discounted` を確認してね🛑🔍 ([Stack Overflow][4])

### 課題2：Logpointで観測しよう🪵✨

* `discounted` 計算の行に Logpoint を置いて、`price/coupon/discounted` をログに出してね（コードは変更しない）🧼 ([Visual Studio Code][1])

---

## AI活用ポイント🤖✅（お願い方＋チェック観点）

### お願い方テンプレ🪄

* 「この関数のバグ調査で、観測すべき変数と置き場所を3案出して。入口/分岐/出口に分けて」🤖📝
* 「ログメッセージを短く、検索しやすい形式（固定プレフィックス＋JSON）で提案して」🤖🔍
* 「ブレークポイントで見るべき順番（Watch候補も）を手順化して」🤖👣

### チェック観点✅

* ログに **個人情報・秘密情報** を入れない（メール、トークン、パスワード系）🔒⚠️
* “何を見たいログ？”が1行で説明できるか📝
* そのログは「原因特定」に効く？ただの雑談ログになってない？🪵😵‍💫

---

## よくあるつまずき🐣💥（ここだけ見ても助かる）

* ブレークポイントが灰色：ソースマップ設定や、実行してるファイルと開いてるTSがズレてることが多い🗺️🧷 ([Visual Studio Code][3])
* ログだらけで逆に迷子：入口/分岐/出口の3点に絞ると勝ちやすい🧭✨
* 何回も止まってしんどい：条件付き or ヒットカウント or Logpoint へ切替🪄🧠 ([Visual Studio Code][1])

---

## まとめ🎀✅

* **止めて見る＝デバッグ**、**流して見る＝ログ**🛑🪵
* まずは「入口/分岐/出口」を観測して、直す前に事実を集める👀🧠
* Logpoint と Auto Attach を覚えると、観測が一気にラクになるよ🪄✨ ([Visual Studio Code][1])

[1]: https://code.visualstudio.com/blogs/2018/07/12/introducing-logpoints-and-auto-attach?utm_source=chatgpt.com "Introducing Logpoints and auto-attach"
[2]: https://code.visualstudio.com/docs/debugtest/debugging?utm_source=chatgpt.com "Debug code with Visual Studio Code"
[3]: https://code.visualstudio.com/docs/nodejs/browser-debugging?utm_source=chatgpt.com "Browser debugging in VS Code"
[4]: https://stackoverflow.com/questions/43311058/how-to-add-conditional-breakpoints-vscode-debugger?utm_source=chatgpt.com "How to add conditional breakpoints? (VSCode debugger)"
[5]: https://nodejs.org/api/cli.html?utm_source=chatgpt.com "Command-line API | Node.js v25.4.0 Documentation"
[6]: https://code.visualstudio.com/docs/typescript/typescript-debugging?utm_source=chatgpt.com "Debugging TypeScript"
[7]: https://code.visualstudio.com/docs/nodejs/nodejs-debugging?utm_source=chatgpt.com "Node.js debugging in VS Code"
[8]: https://tsx.is/vscode?utm_source=chatgpt.com "VS Code debugging"
