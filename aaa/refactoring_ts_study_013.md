# 第13章 ゴールデンマスター（テストが無いときの守り）👑🛟

## ねらい🎯

* 既存コードの「今の動き」を先に固定して、安心してリファクタできるようになる🛟✨
* ゴールデンマスター（承認テスト／スナップショット）で、差分を“見て判断”できるようになる👀✅
* スナップショットがブレる原因（日時・乱数・順序など）を潰して、安定したテストにする🧹🧷

---

## 今日のキーワード📌

### ゴールデンマスターってなに？👑

「既存の動作をそのまま保存して、次回以降に差分が出たら気づけるようにする」テクニックだよ🛟
別名がたくさんあって、Characterization tests（特性テスト）、Approval tests（承認テスト）、Snapshot testing（スナップショット）などが“ほぼ同じ文脈”で使われることが多いよ📚✨ ([tdd.mooc.fi][1])

### いつ使うの？🕰️

* テストがほぼ無い😇
* でも直さなきゃいけない（怖い）😱
* まず「壊してない」ことを担保したい🛡️

こういうとき、理解が完璧じゃなくても「今の出力を記録して守る」ことで、リファクタのスタートラインに立てるよ👣✨ ([tdd.mooc.fi][1])

---

## ざっくり手順（これだけ覚えればOK）👣🛟

1. **入口（関数/処理）を1つ決める**🎯
2. **いくつかの入力で実行して、出力を保存**💾
3. **以後は毎回“差分”を見て判断**👀✅
4. リファクタ後、差分が出たら

   * 想定外 → バグかも😵‍💫
   * 想定内 → 出力変更をレビューしてスナップショット更新🔁 ([vitest.dev][2])

---

## コード例（ビフォー／アフター）🧩➡️✨

### ビフォー：テストがなくて怖いレシート生成🧾😱

（例：文字列でレシートを作る。日時が混ざってブレやすい…）

```ts
// src/legacy/receipt.ts
export type Item = { name: string; price: number; qty: number };

export function buildReceipt(items: Item[]): string {
  const now = new Date().toISOString(); // ← これが毎回変わる😵
  let total = 0;

  const lines: string[] = [];
  lines.push(`Receipt date: ${now}`);

  for (const it of items) {
    const subtotal = it.price * it.qty;
    total += subtotal;
    lines.push(`${it.name} x${it.qty} = ${subtotal}`);
  }

  lines.push(`Total: ${total}`);
  return lines.join("\n");
}
```

---

### アフター：ゴールデンマスターで“今の動き”を固定👑🛟

ポイントは2つ👇

* **出力を正規化（ブレ要素を消す）**🧹
* **スナップショットで保存＆差分レビュー**👀

```ts
// test/receipt.golden.test.ts
import { describe, it, expect } from "vitest";
import { buildReceipt, type Item } from "../src/legacy/receipt";

// 🧹 ブレる要素（日時など）を置き換えて安定化
function normalizeReceipt(s: string): string {
  return s.replace(/Receipt date: .+/g, "Receipt date: [date]");
}

describe("Golden Master: buildReceipt", () => {
  it("case 1: normal items", () => {
    const items: Item[] = [
      { name: "Apple", price: 120, qty: 2 },
      { name: "Milk", price: 210, qty: 1 },
    ];

    const out = normalizeReceipt(buildReceipt(items));
    expect(out).toMatchSnapshot();
  });

  it("case 2: empty", () => {
    const out = normalizeReceipt(buildReceipt([]));
    expect(out).toMatchSnapshot();
  });

  it("case 3: includes zero qty", () => {
    const items: Item[] = [{ name: "Banana", price: 80, qty: 0 }];
    const out = normalizeReceipt(buildReceipt(items));
    expect(out).toMatchSnapshot();
  });
});
```

✅ 初回実行でスナップショット（期待値ファイル）が作られて、次回からは差分が出たらテストが落ちるよ🛡️
Vitest は値をスナップショットとして保存して比較できて、必要なら更新もできるよ（更新フラグ -u / --update、watch中はキー u）🔁 ([vitest.dev][2])

---

## 実行してみよう（最短ルート）🚀🪟

### 1) テスト実行🧪

```bash
npm test
```

初回はスナップショットが生成されるよ（例：テストファイルと同階層に __snapshots__ フォルダができる）📁✨ ([Qiita][3])

### 2) リファクタして再実行🔁

* 関数の中を整理（変数名・抽出など）🧹
* もう一度 npm test
* **差分が出たら“何が変わったか”をレビュー**👀✅

### 3) 変更が意図したものならスナップショット更新🔁

```bash
npx vitest -u
```

（watchで動かしてるなら、失敗したときにターミナルで u を押して更新もできるよ）⌨️✨ ([vitest.dev][2])

---

## 失敗しないコツ（ここ超大事）🧷⚠️

### コツ1：スナップショットは“コード扱い”でレビューする👀📝

スナップショットは生成物だけど、**コミットしてレビュー対象にする**のが基本だよ✅ ([jestjs.io][4])
差分を見ずに更新連打しちゃうと、守りにならない…😵‍💫

### コツ2：テストは“毎回同じ結果”になるようにする🎲❌

日時・乱数・順序・環境依存の文字列は、スナップショットを壊しやすいよ💥

* 日時 → 固定値に置き換える / モックする🕰️
* 乱数 → seed固定 / モック🎰
* オブジェクト順序 → 並び替え / 出力を整形🧹

「決定的（deterministic）にしよう」っていうのはスナップショットの大原則だよ🧷 ([jestjs.io][4])

### コツ3：入力パターンは“少なすぎ”が一番危ない😇

「通常」「空」「境界」「変な値」みたいに、代表ケースを増やすと守りが強くなるよ🛡️
（入力を増やしていろんなシナリオをカバーするのが大事、という流れもよく語られるよ）📌 ([Understand Legacy Code][5])

### コツ4：並列テストのときは注意（上級者向け豆知識）🫘

Vitestで concurrent（並列）を使う場合、スナップショットやアサーションは「ローカルの expect」を使う注意があるよ⚠️ ([vitest.dev][2])
（今は気にしなくてOK！でも“罠がある”って覚えておくと助かる😊）

---

## ミニ課題✍️（15〜25分）⏱️✨

### 課題A：出力のブレを1つ潰す🧹

1. レシートに「注文ID（ランダム）」っぽい行を追加したくなるケースを想像してみよう🎲
2. そのままだとスナップショットが毎回変わるはず…😇
3. normalizeReceipt に置換ルールを足して、安定化してね🧷✅

### 課題B：入力ケースを2つ増やす🛡️

* qty がマイナス（来ちゃダメだけど来るかも😱）
* price が 0（無料サンプル🎁）
  みたいなケースを追加して、スナップショットが増える感覚をつかもう📌

### 課題C：小さなリファクタをして守れてるか確認👣

* subtotal計算を関数に抽出✂️
* 変数名をわかりやすく🏷️
* 配列 lines の作り方を整理🧺

→ 最後に npm test で「出力が同じ」を確認✅

---

## AI活用ポイント🤖✨（お願い方＋チェック観点✅）

### 1) 入力パターン生成を手伝ってもらう🧠

お願い例：

* 「この関数のゴールデンマスター用に、代表入力を10個考えて。通常・空・境界・変な値のバランスで！」

チェック観点✅

* 同じ系統の入力ばかりになってない？（全部“通常”とか）
* 例外系がゼロじゃない？😇

### 2) “ブレ要素”を洗い出してもらう🔍

お願い例：

* 「この出力がテストで不安定になる原因を列挙して。日時・乱数・順序・環境依存を中心に見て！」

チェック観点✅

* 置換で潰せる？それとも設計で注入（Clockを渡す等）が必要？🧩

### 3) 正規化（Printer）案を出してもらう🧾🧹

お願い例：

* 「スナップショット比較しやすいように、出力文字列を人間が読みやすく整形して。不要情報は削る方針で！」

チェック観点✅

* “削りすぎ”て大事な差分まで消してない？⚠️
* 差分レビューで意味が分かる見た目になってる？👀

---

## まとめ🌸

* ゴールデンマスターは「テストが無いときの最短の守り」👑🛟 ([tdd.mooc.fi][1])
* スナップショットは **差分レビューが命**👀✅（更新は -u / watchの u でできる）🔁 ([vitest.dev][2])
* ブレ要素を潰して“毎回同じ結果”にするのが成功のカギ🧷✨ ([jestjs.io][4])

[1]: https://tdd.mooc.fi/4-legacy-code/ "Chapter 4: Legacy code - Test-Driven Development MOOC"
[2]: https://vitest.dev/guide/snapshot "Snapshot | Guide | Vitest"
[3]: https://qiita.com/mattsu_mocha/items/ef15540fff4561c9757e "Vitestでスナップショットテストをやってみる #Vitest - Qiita"
[4]: https://jestjs.io/docs/snapshot-testing "Snapshot Testing · Jest"
[5]: https://understandlegacycode.com/blog/characterization-tests-or-approval-tests/ "What's the difference between Regression Tests, Characterization Tests, and Approval Tests?"
