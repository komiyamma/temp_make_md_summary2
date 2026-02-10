# 第19章：カバレッジは「数字」より「穴」を見る🕳️✨

カバレッジって、つい「%を上げるゲーム」になりがちなんだけど…本当に欲しいのは **“壊れやすい所にテストが当たってる安心感”** だよね😊
この章は、**数字に振り回されずに「穴（守れてない分岐・例外・境界）」を見つけて埋める** 練習をする回だよ🧠🧪

---

## この章でできるようになること🎯

* カバレッジの種類（line / branch など）を “使い分け” できる🙂
* レポートを見て **「危ない穴」** を発見できる🔍🕳️
* 100%を目指さず、**重要分岐だけ堅く守る** 判断ができる🛡️
* Vitestで **カバレッジ計測 → HTMLで確認** ができる📄✨
  （Vitestのカバレッジは v8 / istanbul を選べて、デフォルトは v8 だよ）([vitest.dev][1])

---

## 1) そもそもカバレッジって何を測ってるの？📏

カバレッジはざっくり言うと、

* ✅ **通った行**（line）
* ✅ **実行された分岐**（branch：if/else、三項演算子、switch など）
* ✅ **呼ばれた関数**（function）
* ✅ **実行された文**（statement）

…みたいな “通過チェック” だよ🙂

でも注意⚠️
カバレッジが高くても…

* 期待値が雑（assertが弱い）
* 重要な例外ルートを通してない
* 境界値（0/1、空文字、上限など）に弱い

みたいなケースは普通に起こる😇
だから **「%」より「穴」** を見るのが大事🕳️👀

---

## 2) 「穴」を見るときの最強3点セット🧰✨

## A. branch（分岐）に赤が残ってない？🔀🟥

lineが緑でも、**分岐が片側しか通ってない** パターンがあるよ。
ここが一番 “事故りやすい穴” になりがち💥

## B. 例外・エラーハンドリングが未テストじゃない？🚨

「正常系しか書いてない」は初心者あるある🙂
でも実務で飛ぶのはだいたい異常系😇

## C. 境界値が抜けてない？🧱

* 空配列 / 空文字
* 0 / 1 / -1
* 上限ちょうど
* “未設定” (undefined/null)

このへんは **バグの宝庫** 💎（やばい意味で）

---

## 3) Vitestでカバレッジを出す（最短ルート）⚡

Vitestはカバレッジ機能が「別パッケージ」扱いで、v8プロバイダが王道＆速め🏃‍♂️💨
`@vitest/coverage-v8` は普通に最新が更新されてるよ。([npmjs.com][2])

## 3-1. 追加インストール📦

```bash
npm i -D @vitest/coverage-v8
```

## 3-2. vitest.config.ts に coverage を足す🧩

（デフォルトは v8 だけど、明示しておくと迷子になりにくい🙂）([vitest.dev][1])

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov'],
      reportsDirectory: 'coverage',
      // まずは “下げすぎ防止” のゆるい基準でOK（後で育てる）
      thresholds: {
        lines: 60,
        branches: 50,
        functions: 60,
        statements: 60,
      },
    },
  },
})
```

※ `reporter` や `reportOnFailure` など、カバレッジ設定は色々用意されてるよ。([vitest.dev][3])

## 3-3. package.json にコマンド追加🧷

```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:cov": "vitest run --coverage"
  }
}
```

実行👇

```bash
npm run test:cov
```

---

## 4) レポートの読み方：数字より「赤い理由」を見る🟥🔍

カバレッジHTMLはだいたい `coverage/index.html` に出るよ📄✨

見るときのコツはこれ👇

1. **“branches” 列を最優先**（分岐の穴はバグ直結しやすい）🔀
2. その次に **functions**（呼ばれてない関数は「存在してるのに守ってない」）
3. lineは最後（lineは上がりやすい）

そして一番大事なのは👇

> 「赤い行を緑にする」じゃなくて
> **「この赤は、壊れたら困る赤なのか？」** を考える🧠✨

---

## 5) 100%にしない勇気💪😎

カバレッジ100%を狙うと、だいたいこうなる👇

* 意味の薄いテストが増える（維持コスト爆増）💸
* 重要分岐より「埋めやすい行」から埋め始める（本末転倒）😇
* リファクタが怖くなる（テストが足かせ）🧱

だからおすすめはこの方針👇

## ✅ “守りたい場所” を決めて、そこだけ強くする🛡️

* ビジネスルール（値チェック、認可、料金計算…）
* 失敗したらヤバい処理（課金、削除、権限）
* バグが出やすい境界（ifが多い、変換が多い）

---

## 6) 実例で「穴」を埋める練習🕳️➡️🧪

## 6-1. 例：よくある分岐関数（穴が出やすい）🔀

```ts
// src/price.ts
export function calcPrice(base: number, coupon?: string) {
  if (base <= 0) throw new Error('base must be positive')

  let price = base

  if (coupon === 'HALF') price = Math.floor(price / 2)
  else if (coupon === 'MINUS100') price = Math.max(0, price - 100)

  if (price >= 1000) price = Math.floor(price * 0.9) // 10% off

  return price
}
```

ありがちな穴👇

* `base <= 0` の例外ルート🟥
* クーポンの else-if の片側しか通ってない🟥
* `price >= 1000` の境界（999 / 1000）🟥

## 6-2. テストで “穴” を狙い撃ち🎯

```ts
// src/price.test.ts
import { describe, it, expect } from 'vitest'
import { calcPrice } from './price'

describe('calcPrice', () => {
  it('base <= 0 は例外', () => {
    expect(() => calcPrice(0)).toThrow('base must be positive')
  })

  it('HALF クーポン', () => {
    expect(calcPrice(100, 'HALF')).toBe(50)
  })

  it('MINUS100 クーポン（下限0）', () => {
    expect(calcPrice(50, 'MINUS100')).toBe(0)
  })

  it('1000以上は10%オフ（境界も見る）', () => {
    expect(calcPrice(999)).toBe(999)
    expect(calcPrice(1000)).toBe(900)
  })
})
```

こうやって **“分岐・例外・境界”** を狙うと、数字より価値が出るよ😊✨

---

## 7) “計測のブレ” にびっくりしないでね😲

ツール更新でカバレッジが上下することがあるよ。
たとえばVitestは、V8カバレッジのリマップ（TSの行番号対応）周りが改善されて、更新で数値が変わることがあるって書かれてる。([vitest.dev][4])

ポイントはこれ👇

* **増減した理由をレポートで確認**（数字だけ見ない）
* “重要分岐” が守れてるならOK🙂

---

## 8) 「ここは測らなくてOK」も作れる（やりすぎ防止）✂️🙂

どうしても意味が薄い行（到達不能、防衛的コード、ログだけ等）を埋めるために、変なテストを書くのはしんどい😇
V8系カバレッジでは、特定行を無視するコメント指示が使われることがあるよ（例：`/* c8 ignore next */`）。([Modern Web][5])

※ ただし乱用はNG🙅‍♂️
「重要なのに無視して逃げる」になりがちだから、**“理由を書いて最小限”** が大人のやり方😎✍️

---

## 9) CIへつなぐ入口（軽くでOK）🚪✨

この章では深追いしないけど、今やった `lcov` 出力は後でCIやPR表示に使いやすいよ🙂
まずはローカルで **`npm run test:cov` が常に通る** 状態を作れたら勝ち🏆

---

## 10) ミニ課題（手を動かすやつ）🧑‍💻🔥

1. `npm run test:cov` を回して、HTMLレポートを開く📄👀
2. **branches が低いファイルを1つ** 選ぶ🔀🟥
3. 赤い行を眺めて、次をメモする✍️

   * これは **例外？境界？片側分岐？**
   * 壊れたら困る？（YES/NO）
4. YESのやつだけテストを足して、branchesを改善する✅✨
5. `thresholds` を “今の現実” に合わせて調整（高すぎて毎回落ちないように）🙂

---

## 11) よくある詰まり（先回り）🧯😅

* **coverageフォルダが見当たらない**
  → `vitest run --coverage` で実行してる？（watchモードだと挙動が違うことがある）🙂
* **Docker内で生成されてホストで見えない**
  → `coverage` がソースマウント領域に出る設定になってるか確認📂
* **TypeScriptの行番号がズレて見える**
  → ツール更新で改善されたり変動したりするので、まずは最新版で再実行🔁（Vitest側でも改善が入ることがある）([vitest.dev][4])
* **実行が遅い**
  → まずは “重要ファイルだけ穴埋め” に絞る（全体100%は狙わない）🏃‍♂️💨

---

## 12) AIで時短（穴埋めにめっちゃ効く）🤖✨

AIはこの章と相性いい！理由は簡単で、**「赤い行」＝AIに具体的な材料を渡せる** から🎯

## 使い方テンプレ🧠

* HTMLレポートで赤い関数/行を見つける
* その関数コードと「未カバーの条件」をAIに渡す
* **“分岐・例外・境界” を狙ったテスト案** を出させる

## 例プロンプト（コピペOK）📋

```text
この関数のカバレッジで branches が落ちています。
未カバーになりそうな分岐（if/else、例外、境界値）を洗い出して、
Vitestで書く最小のテストケースを提案してください。
モックは必要最小限にして、期待値は具体的にしてください。
```

## 最後に人間チェック✅

AIが出したテストは便利だけど、ここは必ず見る👀

* assertが弱くない？（“動いた” だけになってない？）
* 実装の詳細に依存しすぎてない？（リファクタで壊れるやつ）😇
* “守りたい仕様” を守ってる？🛡️

---

## おまけ：Node標準テストでもカバレッジは取れる🧩

将来「Vitestじゃなくて標準で行きたい」派になっても大丈夫🙂
Nodeのテストランナーは `--experimental-test-coverage` でカバレッジ収集できるよ。([nodejs.org][6])

（この章では深入りしないけど、“選択肢を知っておく” だけで強い💪）

---

次の第20章は、ここで出てきた「遅い…続かない…😇」を **速くして継続できる形にする** 回だよ🏎️💨

[1]: https://vitest.dev/guide/coverage.html?utm_source=chatgpt.com "Coverage | Guide"
[2]: https://www.npmjs.com/package/%40vitest/coverage-v8?utm_source=chatgpt.com "vitest/coverage-v8"
[3]: https://vitest.dev/config/coverage?utm_source=chatgpt.com "coverage | Config"
[4]: https://vitest.dev/guide/migration.html?utm_source=chatgpt.com "Migration Guide"
[5]: https://modern-web.dev/docs/test-runner/writing-tests/code-coverage/?utm_source=chatgpt.com "Writing Tests: Code Coverage"
[6]: https://nodejs.org/en/learn/test-runner/collecting-code-coverage?utm_source=chatgpt.com "Collecting code coverage in Node.js"
