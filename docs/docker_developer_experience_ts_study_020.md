# 第20章：テストを速くするコツ（並列・分離・再利用）🏎️🧪✨

テストって、**速いほど続きます**🙂
逆に遅いと「あとでやるか…」になって、だんだん回らなくなるんだよね…🥺

この章は、**「遅い→速い→気持ちいい」**を作る章です💨💨

---

## この章でできるようになること ✅✨

* 🕵️‍♂️ **どこが遅いか**を見つけられる（計測）
* 🧪 **ユニットと統合テストを分けて**普段の実行を爆速にする（分離）
* 🧵 **並列実行でCPUを働かせる**（並列）
* ♻️ **重い準備を再利用**してムダを減らす（再利用）
* 🧊 **キャッシュ**や**差分実行**で「変更した分だけ」回す（再利用その2）

---

## 1) まずは「どこが遅い？」を可視化しよう 👀🔎

速くする前に、**遅い犯人を特定**します🕵️‍♀️✨
おすすめの見える化はこのへん👇

## ① “遅いテスト”を目立たせる 🐢💥

Vitest は「遅いテスト」を検出する閾値を持てます（`slowTestThreshold`）🧪✨

`vitest.config.ts` に足してみよう👇

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    slowTestThreshold: 200, // 200ms超えたら「遅いよ！」って目立つ（好みで調整）
  },
});
```

## ② メモリで遅くなってない？（地味に多い）🧠🔥

重いテストは、メモリ（ヒープ）増えがちです。
Vitest には **各テストのヒープサイズ表示**があります👇 ([vitest.dev][1])

```bash
vitest run --logHeapUsage
```

---

## 2) 速くする最大のコツ：テストを「分離」する ✂️🚀

ここが一番効くことが多いです🙂✨

* ✅ **ユニットテスト**：普段はこれだけ回す（爆速）
* 🧱 **統合テスト（DB/HTTP/Redisなど）**：必要なときだけ回す（重いから）

## おすすめ構成 📁✨

* `tests/unit/**` …ユニット
* `tests/integration/**` …統合（DBあり等）

そして npm scripts をこう分ける👇（名前が大事！覚えなくて良くなる）🧠✨

```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:unit": "vitest run tests/unit",
    "test:unit:watch": "vitest tests/unit",
    "test:integration": "vitest run tests/integration"
  }
}
```

Vitest は **watch がデフォルト**で、`vitest run` は **watchなしの単発実行**です。 ([vitest.dev][1])
つまり普段は `npm test`（watchで快適）、CIは `npm run test:run`（単発）みたいにできるよ😄

---

## 3) 並列で速くする：3つのレバーを押す 🧵⚙️⚡

## レバーA：テストファイルは基本「並列」になってる ✅

Vitest は **テストファイル単位で並列実行が基本**です。 ([vitest.dev][2])
止めたいときは `fileParallelism: false`（＝ほぼ直列）もできます。 ([vitest.dev][3])

## レバーB：ワーカー数（maxWorkers）を調整する 🧑‍🏭👷‍♀️

CPUを活かすならここ！
CLI でも設定でもOKで、`--maxWorkers` が使えます。 ([vitest.dev][1])

例：CPUの半分だけ使う👇

```bash
vitest run --maxWorkers=50%
```

「PCが爆熱🔥」「他作業が重い😵」ってときは下げると快適になるよ🙂

## レバーC：pool を変える（forks ↔ threads）🧵🔁

Vitest はデフォで `forks`（別プロセス）だけど、`threads`（worker_threads）にすると速くなるケースがあります⚡
公式も “さらに速くするなら threads を検討” って言ってます（ただし相性注意）。 ([vitest.dev][4])

```bash
vitest run --pool=threads
```

---

## 4) “同じファイル内”も並列にしたい？（ただし効く条件あり）🏃‍♂️🏃‍♀️💨

ポイント：Vitest は **ファイル内のテストは基本「順番」**です。
でも `concurrent` で「同時実行グループ」にできます🙂 ([vitest.dev][2])

```ts
import { test, expect } from "vitest";

test.concurrent("A", async () => {
  // await する重い処理があると効きやすい
  expect(1).toBe(1);
});

test.concurrent("B", async () => {
  expect(2).toBe(2);
});
```

さらに “同時に走らせる数” は `maxConcurrency` で調整できます。 ([vitest.dev][5])

⚠️注意：

* **同期処理ばっかり**だと、同時実行してもあまり速くならないことがあります（CPUが1本で詰まる）🙂
* DB みたいな **共有資源**があると壊れやすいので、統合テストでは慎重に🙏

---

## 5) 再利用で速くする：準備を “毎回やらない” ♻️🍱

重い原因、だいたいここ👇

* DBの初期化
* seed投入
* サーバ起動
* 大量import（起動が遅い）

## ① setupFiles と globalSetup の使い分け 🧩

* `setupFiles`：**各テストファイルの前に毎回**走る（同じプロセス） ([vitest.dev][6])
* `globalSetup`：**全体で1回だけ**（ワーカー作成前）走る（重い準備向き） ([vitest.dev][6])

例えば「統合テストの前にDBコンテナが起動してることを保証」みたいなのは、`globalSetup` 側に寄せるとムダが減りやすいよ🙂✨

## ② 差分だけテストする（体感めちゃ効く）✂️⚡

* `--changed`：変更されたファイルに関連するテストだけ回す ([vitest.dev][1])
* `vitest related`：指定ソースに関連するテストだけ回す（lint-stagedとも相性◎） ([vitest.dev][1])

例👇

```bash
vitest --changed
vitest related --run src/index.ts
```

## ③ キャッシュで “次の実行” を速くする 🧊💨

`experimental.fsModuleCache` は **再実行時にモジュールをファイルシステムにキャッシュ**できます。 ([vitest.dev][1])

```bash
vitest --experimental.fsModuleCache
```

キャッシュを消したいときは👇（次は遅くなるよ、って注意も公式に書いてある） ([vitest.dev][1])

```bash
vitest --clearCache
```

---

## 6) “禁断の奥義”：isolate を切って速くする（ただし副作用に注意）⚠️🧨

Vitest は **各テストファイルを隔離（isolate）**して、ファイル間の汚染を防ぎます。 ([vitest.dev][4])
でもこの隔離が、プロジェクトによっては **遅さの原因**になります🥺

公式は「副作用に頼らないなら、isolateを切ると速くなる」って言ってます。 ([vitest.dev][7])

```bash
vitest run --no-isolate
```

⚠️注意ポイント（ここ超大事）

* グローバル変数とか、環境汚染するテストがあると壊れます💥
* まずは **unit だけ**で試すのがおすすめ🙂

---

## 7) CIでさらに速く：シャーディング（分割実行）⚙️🧩🚀

テストが増えたら、CIで **分割して同時実行**が効きます。

Vitest の `--shard` は、テスト全体を `<index>/<count>` に分割して実行できます。 ([vitest.dev][1])

```bash
vitest run --shard=1/3
vitest run --shard=2/3
vitest run --shard=3/3
```

watch とは一緒に使えない点も公式に明記されてるよ🙂 ([vitest.dev][1])

---

## 8) ミニ課題 🎯💪（30〜60分）

## 課題A：遅いテストを炙り出す 🐢🔥

1. `slowTestThreshold` を 200ms に設定
2. `npm run test:unit` を実行
3. “遅いテストTop3” をメモ📝

## 課題B：分離で爆速ループを作る ✂️⚡

1. `tests/unit` と `tests/integration` を作る
2. scripts を分ける（`test:unit` / `test:integration`）
3. 普段は `test:unit:watch` だけ回す🌀

## 課題C：並列の効き具合を体感する 🧵💨

1. `vitest run --maxWorkers=50%`
2. `vitest run --maxWorkers=100%`
3. 体感＆時間を比べる⌛（熱くなりすぎたら下げてOK🔥）

---

## 9) よくある詰まり 🧯😵‍💫

* 😭 **並列にしたらたまに落ちる**
  → 共有資源（DB/同じポート/同じファイル）を触ってる合図。統合テストは `maxWorkers=1` で走らせるのも全然アリ🙂

* 🧨 **--no-isolate で壊れた**
  → テストが状態を片付けてない可能性大。`beforeEach/afterEach` で初期化・後片付けを徹底しよう🧹

* 🐌 **最初の起動が遅い**
  → `--changed` / `related` / `fsModuleCache` が効くこと多いよ⚡ ([vitest.dev][1])

---

## 10) AIで時短 🤖✨（使いどころが超ある）

ここだけはガンガンAI使ってOKです😄
（たとえば GitHub の Copilot や OpenAI 系のコーディング支援）

## そのまま投げてOKなプロンプト例 🪄

* 「この `vitest.config.ts` を、unit は速く、integration は安全に（直列寄り）実行できるように scripts と設定案を出して」
* 「遅いテストTop3を、テストの意図を壊さずに速くする改善案を3パターン出して（副作用注意）」
* 「`--no-isolate` を試したい。壊れやすいパターン（グローバル汚染）を検出する観点チェックリスト作って」

---

## まとめ 🎁✨

テスト高速化は、だいたいこの順で勝てます👇

1. 👀 可視化（遅い場所を特定）
2. ✂️ 分離（unit と integration）
3. 🧵 並列（maxWorkers / pool / concurrent）
4. ♻️ 再利用（globalSetup / changed / related / cache）
5. ⚠️ 最後に禁断（no-isolate）

---

次の章（第21章）では、**Lint と Format を混ぜて地獄を見ない方法**に進むよ🧹✨

[1]: https://vitest.dev/guide/cli "Command Line Interface | Guide | Vitest"
[2]: https://vitest.dev/guide/parallelism?utm_source=chatgpt.com "Parallelism | Guide"
[3]: https://vitest.dev/config/fileparallelism?utm_source=chatgpt.com "fileParallelism | Config"
[4]: https://vitest.dev/guide/features?utm_source=chatgpt.com "Features | Guide"
[5]: https://vitest.dev/config/fileparallelism "fileParallelism | Config | Vitest"
[6]: https://vitest.dev/config/setupfiles?utm_source=chatgpt.com "setupFiles | Config"
[7]: https://vitest.dev/guide/improving-performance?utm_source=chatgpt.com "Improving Performance"
