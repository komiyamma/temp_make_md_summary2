# 第15章：Node標準テストランナーという選択肢🧩

第14章で **Vitest** を動かせたなら、次は「そもそも Node だけでもテストできるよね？」って視点を持つ章だよ😊✨
2026年2月時点だと、Node は **v24 が Active LTS / v25 が Current** という流れで進んでるよ📈([nodejs.org][1])

---

## この章のゴール🎯

* Node標準テスト（`node --test`）を **一度ちゃんと動かしてみる** ✅
* 「標準で足りる / ここはVitest（等）が欲しい」を **判断できる** ようになる🧠✨

---

## 1) Node標準テストって、どんな立ち位置？🤔

Node には **組み込みのテストランナー** があって、CLIはこんな感じ👇
`node --test` で、決まったパターンに合うテストファイルを自動で探して実行してくれるよ🔎([nodejs.org][2])

## 👍 標準テストがハマると嬉しい場面

* 依存を増やしたくない（特に小さめPJ・ライブラリ・CLI）📦
* 「ユニットテスト中心」でいきたい🧪
* CIで “余計なセットアップ無し” に寄せたい🤖

## 🌀 逆に、Vitestの方がラクになりやすい場面

* TSの変換（パスエイリアス含む）や、フロント寄りの機能（DOM/JSDOM）をガッツリ使う🌐
* プラグインや周辺ツール込みで「開発体験」を盛りたい🎛️

---

## 2) まずは最小で動かす🧪✨（TypeScriptでOK）

Node のテストランナーは、デフォルトで `.test.ts` なども拾える（`--no-strip-types` を付けない限り）ので、TSでも試しやすいよ👍([nodejs.org][2])
※ただし「型注釈を消すだけ」タイプのTS実行なので、後述の注意点も読んでね⚠️([nodejs.org][3])

## 2-1. 例：足し算関数をテストする➕

プロジェクトにこんな2ファイルを作る（フォルダ名は好みでOK）😊

```ts
// src/sum.ts
export function sum(a: number, b: number): number {
  return a + b;
}
```

```ts
// test/sum.test.ts
import test from "node:test";
import assert from "node:assert/strict";
import { sum } from "../src/sum.ts";

test("sum() は 2 + 3 = 5 を返す", () => {
  assert.equal(sum(2, 3), 5);
});

test("sum() は負の数もOK", () => {
  assert.equal(sum(-2, 3), 1);
});
```

## 2-2. 実行する▶️

```bash
node --test
```

> Node はデフォルトで `**/*.test.{js,cjs,mjs}` や `**/test/**/*` などのパターンを探してくれるよ（さらにTSも拾う）🔍([nodejs.org][2])

---

## 3) 便利ワザ：ファイルを絞る / 名前で絞る🎯

## 3-1. globで「このテストだけ」実行する

Windowsでも、globは **ダブルクォート** で囲むのが安全だよ（シェル展開の差を吸収しやすい）🪟✨([nodejs.org][2])

```bash
node --test "**/sum.test.ts"
```

## 3-2. テスト名で絞る（ピンポイント実行）🔎

```bash
node --test --test-name-pattern="sum\\(\\) は 2 \\+ 3"
```

テスト名パターンは「実行ファイルの集合」は変えない（あくまで “中のテスト” を絞る）って点がコツだよ🧠([nodejs.org][2])

---

## 4) watchモードで「保存→即テスト」へ🌀💨

```bash
node --test --watch
```

これ、めちゃ便利なんだけど **watchモードは Experimental** 扱いなので、挙動が将来変わる可能性はあるよ👀([nodejs.org][2])
（とはいえ学習・個人開発ではガンガン使ってOK👌）

---

## 5) package.json の “ワンコマンド化” 例🧰✨

覚えるコマンドを減らすほど、継続できるよ😊
（Dockerの中で `npm run` する前提でも同じ考え方でOK）

```json
{
  "scripts": {
    "test": "node --test",
    "test:watch": "node --test --watch",
    "test:ci:junit": "node --test --test-reporter=junit --test-reporter-destination=./test-results.xml"
  }
}
```

* `--test-reporter` は `spec / tap / dot / junit / lcov` などが標準で用意されてるよ📣([nodejs.org][2])
* `junit` はCI連携で便利（XML出せる）🧾([nodejs.org][2])

---

## 6) カバレッジも一応いける（ただし Experimental）📊⚠️

Nodeは `--experimental-test-coverage` でカバレッジ収集できるよ（実験扱い）🧪([nodejs.org][2])

```bash
node --test --experimental-test-coverage
```

lcovファイルを出したいならこう👇（ただし **lcov reporter は “テスト結果を出さない”** ので、他のreporterと併用が基本だよ）([nodejs.org][2])

```bash
node --test --experimental-test-coverage --test-reporter=lcov --test-reporter-destination=lcov.info
```

---

## 7) ここが落とし穴⚠️（TSで詰まりやすい）

NodeのTS実行は「軽量にするため、**型を消すだけ**」が基本✨
その代わり、**tsconfigのpaths** とか、**変換が必要なTS構文** は意図的に対象外だよ🧠([nodejs.org][3])

## よくある詰まり3つ😵‍💫

1. **`enum` / 実行時namespace / parameter properties** などを使うとエラー
   → これは “変換が必要” だから。必要なら `--experimental-transform-types` を検討、もしくはVitest/tsx運用へ🔧([nodejs.org][3])

2. `tsconfig.json` の設定（paths等）が効かない
   → Nodeの軽量TSは **tsconfigを読まない** 仕様。フルに使うならランナー（例：tsx）などへ🏃‍♂️([nodejs.org][3])

3. 型だけimportしてるつもりが、実行時エラー
   → `import type` が必要になるケースがあるよ（タイプストリッピングの都合）🧷([nodejs.org][3])

---

## 8) ミニ課題💡（やると一気に腹落ちする！）

## 課題A：Vitestのテストを1本だけ移植してみる🔁

* 第14章で作ったユニットテストを1つ選ぶ
* `node:test` + `node:assert/strict` に書き換える
* `node --test "**/そのファイル.ts"` で単体実行してみる✅([nodejs.org][2])

## 課題B：watchで「保存→即テスト」を体感🌀

* `npm run test:watch` を作る
* 1行わざと失敗させて、保存→すぐ赤になるのを確認😈([nodejs.org][2])

## 課題C：CI想定でJUnit出力を作る🧾

* `test:ci:junit` を用意
* `test-results.xml` が出るのを確認✅([nodejs.org][2])

---

## 9) AI拡張の使いどころ🤖✨（速く上手くなるやつ）

## そのまま使える指示例🪄

* 「この関数 `sum(a,b)` に対して、境界値テスト（0/負数/大きい数）を `node:test` で書いて。assertは `node:assert/strict` で」
* 「このVitestのテストを `node:test` に移植して。落ちやすい点（TS実行・import type・拡張子）も一緒に指摘して」
* 「`node --test` のglob指定をWindows/PowerShellで安全にする書き方に直して」

## AI出力を採用する時の“1チェック”✅

* **importの拡張子**（`.ts` / `.js`）が混ざってない？
* **`import type`** が必要なのに抜けてない？
* **enum等の“変換が必要なTS構文”** を書いてない？([nodejs.org][3])

---

## 次章へのつなぎ🚪✨

Node標準でも **mock（spy）機能が用意されてる** から、次の「モックとスタブ」編で一気にテストが “実戦的” になるよ🧸
（Node側のmock APIはこのへんから見えるよ）([nodejs.org][2])

[1]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[2]: https://nodejs.org/api/test.html "Test runner | Node.js v25.6.0 Documentation"
[3]: https://nodejs.org/api/typescript.html "Modules: TypeScript | Node.js v25.6.0 Documentation"
