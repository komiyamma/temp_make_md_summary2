# 27章：性能の超入門（計測のしかた）⏱️🔧

## この章でできるようになること 🎯✨

* 「遅い気がする…😵‍💫」を **数字で説明**できるようになる
* **どこが重いか**（復元？保存？JSON？Projection？）を当てずっぽうじゃなく探せる🔎
* 計測 → 仮説 → 1点改善 → 再計測、の流れを回せる🔁✅

---

## まず大事な結論：性能は“雰囲気”で語らない 🧊✨

イベントソーシングは、**復元（Rehydrate）** や **Projection更新** みたいに「同じ処理を何度もする」場面が多いよね📚🔁
だからこそ、性能の話は **“どれくらい遅い？” “どこが？”** を数字で押さえるのが正義💪😊

---

## 性能の会話でよく出る3つの指標 📏📌

1. **レイテンシ（Latency）**：1回の処理に何msかかった？（例：コマンド1件の処理時間）⏱️
2. **スループット（Throughput）**：1秒に何件さばけた？（例：リプレイで1秒に何イベント適用できた？）🚚💨
3. **メモリ/割り当て（Alloc）とGC**：メモリを使いすぎてGCで止まってない？🧹🧠

---

## “計測”の黄金ループ 🔁✨

この順番にすると迷子になりにくいよ😊🧭

1. **シナリオを決める**（例：イベント1万件の復元、Projection再構築）🎬
2. **指標を決める**（ms、件/秒、割り当てbyte、GC回数）📌
3. **ベースライン計測**（今の数字を取る）📸
4. **仮説を立てる**（重いのはJSON？LINQ？DB？）🕵️‍♀️
5. **変更は1点だけ**（一気に直さない！）✂️
6. **再計測**（改善した？悪化した？）🔁
7. **メモする**（「いつ・何を・どれくらい」）📝

---

## イベントソーシングで“測りどころ”マップ 🗺️🔎

特に狙われやすいのはここ👇

* **Rehydrate（復元）**：イベント列を `Apply` しまくる🔁
* **Append（保存）**：永続化先（SQLite/DB）＋楽観ロックのチェック🔒
* **シリアライズ/デシリアライズ**：JSONの変換コスト🧾
* **Projection更新**：同期更新だと書き込みのたびに重くなりがち📬
* **リプレイ（再構築）**：大量イベントを流すので“全部乗せ”で重い🍱

---

# Step 1：Stopwatchで“ざっくり”計測してみる ⏱️🙂

最初はこれでOK！「どのくらいかかってる？」を掴むのが目的だよ📌

## ざっくり計測のコツ 🧠✨

* **同じ処理を何回か繰り返して平均**を取る（1回だけはブレやすい）🎯
* 計測中は **Console出力をしない**（I/Oが強すぎる）🙅‍♀️
* まずは **“復元”だけ** みたいに範囲を狭める🔍

## 例：Rehydrateを計測するミニコード 🧪

```csharp
using System.Diagnostics;

public sealed record ItemAdded(Guid ItemId, int Quantity);
public sealed record ItemRemoved(Guid ItemId);

public sealed class CartState
{
    public Dictionary<Guid, int> Items { get; } = new();

    public void Apply(object ev)
    {
        switch (ev)
        {
            case ItemAdded e:
                Items[e.ItemId] = Items.TryGetValue(e.ItemId, out var q) ? q + e.Quantity : e.Quantity;
                break;
            case ItemRemoved e:
                Items.Remove(e.ItemId);
                break;
        }
    }
}

public static class PerfDemo
{
    public static TimeSpan MeasureRehydrate(List<object> events, int repeat)
    {
        // ウォームアップ（JITなどで最初は遅くなりがち）
        _ = Rehydrate(events);

        var sw = Stopwatch.StartNew();
        for (int i = 0; i < repeat; i++)
        {
            _ = Rehydrate(events);
        }
        sw.Stop();

        return TimeSpan.FromTicks(sw.ElapsedTicks / repeat);
    }

    private static CartState Rehydrate(List<object> events)
    {
        var state = new CartState();
        foreach (var ev in events)
        {
            state.Apply(ev);
        }
        return state;
    }
}
```

### ここで見るポイント 👀✨

* `events.Count` を増やしたとき、時間がどう増える？（100→1000→10000）📈
* `Apply` の中で **辞書アクセス**や **switch** がボトルネックになってない？🔎

---

# Step 2：Alloc（割り当て）も一緒に見よう 🧠🧹

時間が同じでも、**メモリを大量に確保してGCが走る**と、実際の体感が悪くなることがあるよ😵‍💫

## 例：割り当てbyteも測る（簡易）🧾

```csharp
using System.Diagnostics;

public static class AllocDemo
{
    public static (TimeSpan elapsed, long allocatedBytes) MeasureRehydrateWithAlloc(List<object> events)
    {
        // できるだけ計測前にGCの影響を減らす（超ざっくり）
        GC.Collect();
        GC.WaitForPendingFinalizers();
        GC.Collect();

        long before = GC.GetAllocatedBytesForCurrentThread();
        var sw = Stopwatch.StartNew();

        var state = new CartState();
        foreach (var ev in events)
            state.Apply(ev);

        sw.Stop();
        long after = GC.GetAllocatedBytesForCurrentThread();

        return (sw.Elapsed, after - before);
    }
}
```

---

# Step 3：マイクロ計測はBenchmarkDotNetで“ちゃんと”やる 🧪🏁

Stopwatchは便利だけど、**ブレやすい**のも事実。
「Applyの実装A vs B」みたいに **小さい差を比較**したいときは、BenchmarkDotNetが超強いよ💪✨
BenchmarkDotNetは **メソッドをベンチマーク化**して、再現性のある計測をしやすくしてくれる📏✨ ([benchmarkdotnet.org][1])

## 最小の流れ（イメージ）🚀

* パッケージ追加して
* `[Benchmark]` を付けて
* 実行するだけ

Getting Startedの手順がそのまま使えるよ📘 ([benchmarkdotnet.org][2])

> 注意：BenchmarkDotNetは基本、**Console Appで回す**前提だよ（Webアプリに直接は向かない）🧠 ([GitHub][3])

## 例：Applyの速度を比較する 🥊

```csharp
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;

[MemoryDiagnoser]
public class ApplyBench
{
    private List<object> _events = default!;

    [GlobalSetup]
    public void Setup()
    {
        _events = new();
        var id = Guid.NewGuid();
        for (int i = 0; i < 10_000; i++)
            _events.Add(new ItemAdded(id, 1));
    }

    [Benchmark]
    public int Rehydrate_Apply()
    {
        var state = new CartState();
        foreach (var ev in _events)
            state.Apply(ev);
        return state.Items.Count;
    }
}

public static class Program
{
    public static void Main() => BenchmarkRunner.Run<ApplyBench>();
}
```

---

# Step 4：動いてるプロセスを“観測”する（dotnet-counters）📡👀

「今この瞬間、CPUやGCがどうなってる？」を軽く見るなら **dotnet-counters** が便利✨
dotnet-counters は “最初のレベルの調査”向けの監視ツールで、CPU使用率や例外率などをサクッと眺められるよ📈 ([Microsoft Learn][4])

## よく使うコマンド例（イメージ）🧰

```bash
dotnet-counters monitor -p <PID> System.Runtime
```

見どころはここ👇

* `cpu-usage` が高いまま？🔥
* `gc-heap-size` が増え続けてない？📈
* `gen-2-gc-count` が頻繁？（重いGCが多いかも）🧹💥

---

# Step 5：どこが重いか“犯人探し”（dotnet-trace / EventPipe）🕵️‍♀️🔥

「時間はかかってるのは分かった。でも **どのメソッドが重いの？**」となったら **トレース**！
dotnet-trace は、ネイティブプロファイラなしで **実行中プロセスのトレースを収集**できて、内部的には .NET の **EventPipe** を使ってるよ📎 ([Microsoft Learn][5]) ([Microsoft Learn][6])

## 収集コマンド例（イメージ）🗂️

```bash
dotnet-trace collect -p <PID> --duration 00:00:10 -o trace.nettrace
```

* 収集した `.nettrace` は **Visual Studio** や **PerfView** で開いて分析できるよ🧠🔎 ([Microsoft Learn][7])
* `-f speedscope` みたいに出力形式を変えて、フレームグラフ的に見ることもできるよ🔥 ([Microsoft Learn][7])

---

# Visual StudioのPerformance Profiler超ざっくりガイド 🪟🔬

Visual StudioのPerformance Profilerは **Alt+F2** から開けるよ🧰 ([Microsoft Learn][8])

## CPU Usage（サンプリング）🧪

* “だいたいどこが重いか” を低コストで当てるのが得意🎯
* サンプリングはプロファイルの負荷が低めで、影響が少なめだよ📉 ([Microsoft Learn][9])

## Instrumentation（計測を差し込む）📌

* **呼び出し回数**や **壁時計時間（wall clock）** をより正確に見られる✨
* ただしCPU Usageより **オーバーヘッドは大きめ**（重くなりやすい）⚠️ ([Microsoft Learn][10])

---

# ミニ演習：復元が遅い原因を“数字”で突き止める 🔎📸

## 演習A：イベント数を増やして復元時間を計測 📈⏱️

1. イベント数を `100 / 1,000 / 10,000 / 50,000` にして `MeasureRehydrate` を回す
2. それぞれ **平均ms** をメモする📝
3. グラフっぽく傾向を読む（直線的？急に悪化？）📊

✅ 観察ポイント

* イベント数に比例して増えるなら「単純にApplyが重い」可能性
* ある点から急に悪化するなら「GCやメモリ」が絡んでるかも🧹

## 演習B：スナップショットあり/なしで比較 📸⚡

* “スナップショット＋残りイベントだけ適用” にした場合、時間がどれくらい減る？
* **計測→比較→メモ** をセットで📌

## 演習C：ボトルネック仮説→1点改善→再計測 🛠️🔁

例：

* LINQをやめて `foreach` にする
* `Apply` の分岐を整理する
* JSONの変換回数を減らす（投影で必要な形にまとめる など）🧾

---

## AI活用（この章向け）：推理→実験案を出させる 🤖🕵️‍♀️

“お願いの型”を固定すると強いよ📌✨

### 1) 数字から仮説を作るプロンプト 🧠

* 入力：イベント数ごとのms、割り当てbyte、GCの回数
* 依頼：

  * 「怪しい箇所の候補を3つ」
  * 「切り分け実験を2つ」
  * 「改善は1点ずつ」ルールで提案

### 2) dotnet-countersの結果を読ませる 📡

* 入力：`System.Runtime` の主要カウンター
* 依頼：

  * 「GCが原因っぽいか？」
  * 「次に見るべきトレース項目は？」

### 3) トレースの上位スタックから改善案 🔥

* 入力：重いスタック上位（関数名・割合）
* 依頼：

  * 「改善案（安全・中くらい・攻め）を3段階で」

---

## よくある失敗あるある 😵‍💫💦

* 1回だけ測って結論を出す（ブレる）🎲
* 計測中にログ/Console出力を入れすぎる（I/Oで崩壊）🧨
* 変更点を一気に入れて、何が効いたか分からなくなる🍝
* “速くなった気がする” で終わる（必ず再計測📸）

---

## まとめ 🧡✅

* 性能改善は **計測 → 仮説 → 1点改善 → 再計測** の繰り返し🔁
* イベントソーシングは **復元・投影・シリアライズ・永続化** が測りどころ🗺️
* Stopwatchで入口、必要なら **BenchmarkDotNet / dotnet-counters / dotnet-trace / Visual Studio Profiler** で深掘りしていこう⛏️✨

（参考：C# 14 は .NET 10 でサポートされ、Visual Studio 2026 には .NET 10 SDK が含まれるよ📘）([Microsoft Learn][11])

[1]: https://benchmarkdotnet.org/?utm_source=chatgpt.com "BenchmarkDotNet: Home"
[2]: https://benchmarkdotnet.org/articles/guides/getting-started.html?utm_source=chatgpt.com "Getting started"
[3]: https://github.com/dotnet/BenchmarkDotNet/blob/master/docs/articles/guides/how-to-run.md?utm_source=chatgpt.com "BenchmarkDotNet/docs/articles/guides/how-to-run.md at ..."
[4]: https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-counters?utm_source=chatgpt.com "dotnet-counters diagnostic tool - .NET CLI"
[5]: https://learn.microsoft.com/en-us/dotnet/core/diagnostics/dotnet-trace?utm_source=chatgpt.com "dotnet-trace diagnostic tool - .NET CLI"
[6]: https://learn.microsoft.com/en-us/dotnet/core/diagnostics/eventpipe?utm_source=chatgpt.com "EventPipe Overview - .NET"
[7]: https://learn.microsoft.com/ja-jp/dotnet/core/diagnostics/dotnet-trace?utm_source=chatgpt.com "dotnet-trace 診断ツール - .NET CLI"
[8]: https://learn.microsoft.com/en-us/visualstudio/profiling/instrumentation?view=visualstudio&utm_source=chatgpt.com "Instrument your .NET application - Visual Studio (Windows)"
[9]: https://learn.microsoft.com/en-us/visualstudio/profiling/understanding-performance-collection-methods-perf-profiler?view=visualstudio&utm_source=chatgpt.com "Understand profiler performance collection methods"
[10]: https://learn.microsoft.com/en-us/visualstudio/profiling/profiling-feature-tour?view=visualstudio&utm_source=chatgpt.com "Overview of the profiling tools - Visual Studio (Windows)"
[11]: https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14?utm_source=chatgpt.com "What's new in C# 14"
