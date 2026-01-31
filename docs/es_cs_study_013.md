# 第13章：最小EventStore（インメモリ）を作る①：読み書きだけ📦✅

## この章のゴール🎯✨

* **イベントを保存（Append）**できるようになる📮💾
* **イベントを読み出し（ReadStream）**できるようになる🔎📜
* **「イベントの並びがそのまま履歴」**って感覚を、手を動かしてつかむ👐🧠✨

---

## 1) EventStoreってなに？📦🤔

イベントソーシングでは、状態（State）を直接保存する代わりに、**出来事（Event）を時系列に積む**よね⏳🧱
その「積む箱」が **EventStore** です📦✨

この章では、EventStoreの最小機能だけ作ります👇

* **Append**：あるストリーム（streamId）にイベントを追加する➕
* **ReadStream**：あるストリームのイベント列を最初から読む📜

> この2つができると、「イベントを積んで、後で読める」が完成🎉
> そして次の章以降で、順番（version）・競合・永続化へ進めるようになるよ🚀

---

## 2) 今回の割り切り（最小だからね✂️😊）

この章は“理解最優先”なので、いったん割り切るよ〜🧸✨

* 永続化しない（アプリ終了で消える）🫥
* 競合対策しない（同時更新の守りは次の章以降）⚔️
* シリアライズしない（JSON保存はもっと後）🧾
* できるだけシンプルに、**Listで持つ**📋

---

## 3) ミニ設計：まず型を決めよう🧩✨

### 3-1. イベントは「変更不可」に寄せたい🧊🛡️

イベントって「過去の事実」だから、あとから書き換わると困るの😵‍💫
C# の `record` を使うと、**不変っぽく書けてラク**だよ✍️✨
（C# 14 は .NET 10 でサポートされてるよ📌）([Microsoft Learn][1])

### 3-2. 今回作る “箱” のインターフェース📦

EventStoreが提供するのは「読む」と「書く」だけ。

```csharp
using System.Collections.Concurrent;

public interface IDomainEvent { }

public sealed record StoredEvent(
    Guid EventId,
    DateTimeOffset OccurredAt,
    string EventType,
    IDomainEvent Data
);

public interface IEventStore
{
    ValueTask AppendAsync(
        string streamId,
        IReadOnlyList<IDomainEvent> events,
        CancellationToken ct = default
    );

    ValueTask<IReadOnlyList<StoredEvent>> ReadStreamAsync(
        string streamId,
        CancellationToken ct = default
    );
}
```

ポイント🌟

* `StoredEvent` は「封筒」みたいなもの✉️

  * `Data`：中身（ドメインイベント）
  * `OccurredAt`：いつ起きた？⏰
  * `EventType`：後でデバッグしやすいように型名も入れる🔍
* `streamId` は **集約（Aggregate）1つ分の履歴**を指すIDになる予定🧺（次章でもっと丁寧にやるよ！）

---

## 4) 実装：InMemoryEventStore を作る🧱💪

### 4-1. どう持つ？（答え：辞書＋List）📚

* `streamId` ごとにイベント列を持ちたい

* だから、こうする👇

* `ConcurrentDictionary<string, List<StoredEvent>>`

  * キー：streamId
  * 値：イベントのリスト（追加順が履歴になる）

ただし⚠️
`List<T>` はスレッドセーフじゃないので、**streamごとに lock** を持つよ🔒

### 4-2. 実装コード（最小版）✅

```csharp
using System.Collections.Concurrent;

public sealed class InMemoryEventStore : IEventStore
{
    private readonly ConcurrentDictionary<string, List<StoredEvent>> _streams = new();
    private readonly ConcurrentDictionary<string, object> _streamLocks = new();

    public ValueTask AppendAsync(
        string streamId,
        IReadOnlyList<IDomainEvent> events,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(streamId))
            throw new ArgumentException("streamId is required.", nameof(streamId));

        if (events is null)
            throw new ArgumentNullException(nameof(events));

        if (events.Count == 0)
            return ValueTask.CompletedTask;

        var gate = _streamLocks.GetOrAdd(streamId, _ => new object());

        lock (gate)
        {
            var list = _streams.GetOrAdd(streamId, _ => new List<StoredEvent>(capacity: 32));

            foreach (var ev in events)
            {
                if (ev is null) throw new ArgumentException("events contains null.", nameof(events));

                list.Add(new StoredEvent(
                    EventId: Guid.NewGuid(),
                    OccurredAt: DateTimeOffset.UtcNow,
                    EventType: ev.GetType().FullName ?? ev.GetType().Name,
                    Data: ev
                ));
            }
        }

        return ValueTask.CompletedTask;
    }

    public ValueTask<IReadOnlyList<StoredEvent>> ReadStreamAsync(
        string streamId,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(streamId))
            throw new ArgumentException("streamId is required.", nameof(streamId));

        if (!_streams.TryGetValue(streamId, out var list))
            return ValueTask.FromResult<IReadOnlyList<StoredEvent>>(Array.Empty<StoredEvent>());

        var gate = _streamLocks.GetOrAdd(streamId, _ => new object());

        lock (gate)
        {
            // 外側で勝手にListをいじられないようにコピーして返す🧤
            return ValueTask.FromResult<IReadOnlyList<StoredEvent>>(list.ToArray());
        }
    }
}
```

ここ、超大事ポイント3つ🌟🌟🌟

1. **「コピーして返す」**：内部Listをそのまま返すと、外から壊される😱
2. **UtcNow**：タイムゾーンの事故を避ける⏰🌍
3. **streamごとに lock**：最低限の安全🔒（本格対策は後の章！）

---

## 5) 動作確認：テストで “積めた＆読めた” を確認🧪🎀

### 5-1. xUnit（2026/02/01 時点の例）📌

* `xunit.v3` の NuGet 例：`3.2.2`([NuGet][2])
* Visual Studio のテスト探索用：`xunit.runner.visualstudio 3.1.5`([NuGet][3])

> .NET 10 は 2025-11-11 にリリースされた LTS で、3年サポート（～2028-11-10）だよ📅🛡️([Microsoft for Developers][4])
> C# 14 は .NET 10 対応の最新版って位置づけだよ✨([Microsoft Learn][1])

### 5-2. テスト用のイベントを2つだけ作る🍡

```csharp
public sealed record CartCreated(Guid CartId) : IDomainEvent;
public sealed record ItemAdded(string Sku, int Quantity) : IDomainEvent;
```

### 5-3. テスト本体（順番も確認するよ）✅✅

```csharp
using Xunit;

public sealed class InMemoryEventStoreTests
{
    [Fact]
    public async Task Append_then_ReadStream_returns_events_in_same_order()
    {
        // Arrange 🎀
        IEventStore store = new InMemoryEventStore();
        var streamId = "cart-001";

        var cartId = Guid.NewGuid();
        var e1 = new CartCreated(cartId);
        var e2 = new ItemAdded("SKU-APPLE", 2);

        // Act 🏃‍♀️
        await store.AppendAsync(streamId, new IDomainEvent[] { e1, e2 });
        var read = await store.ReadStreamAsync(streamId);

        // Assert ✅
        Assert.Equal(2, read.Count);

        Assert.Equal(typeof(CartCreated).FullName, read[0].EventType);
        Assert.Same(e1, read[0].Data);

        Assert.Equal(typeof(ItemAdded).FullName, read[1].EventType);
        Assert.Same(e2, read[1].Data);
    }

    [Fact]
    public async Task Different_streams_are_isolated()
    {
        // Arrange 🎀
        IEventStore store = new InMemoryEventStore();

        // Act 🏃‍♀️
        await store.AppendAsync("cart-A", new IDomainEvent[] { new ItemAdded("SKU-A", 1) });
        await store.AppendAsync("cart-B", new IDomainEvent[] { new ItemAdded("SKU-B", 9) });

        var a = await store.ReadStreamAsync("cart-A");
        var b = await store.ReadStreamAsync("cart-B");

        // Assert ✅
        Assert.Single(a);
        Assert.Single(b);

        var aItem = Assert.IsType<ItemAdded>(a[0].Data);
        var bItem = Assert.IsType<ItemAdded>(b[0].Data);

        Assert.Equal("SKU-A", aItem.Sku);
        Assert.Equal("SKU-B", bItem.Sku);
    }
}
```

テストで見てること👀✨

* **Appendした順に読める**（イベント列＝履歴だから超重要）
* **streamが違うと混ざらない**（これが「集約ごとに履歴」への入口🚪）

---

## 6) よくあるミス集（先に潰そ😺🔧）

* **Listをそのまま返す** → 外側が `Add` できちゃって履歴が壊れる😱
* **イベントをミュータブルにする** → 後でプロパティ書き換えられて歴史改ざん🕰️💥
* **streamIdが空** → みんな同じ箱に積まれてカオス🤯
* **lock無しでListを触る** → たまに落ちる・たまに順番が変に見える…みたいな地獄👻

---

## 7) AI活用（この章向けプロンプト例）🤖💬✨

### 7-1. 叩き台を作らせる（最小実装）

```text
C#でインメモリEventStoreを作りたいです。
要件:
- Append(streamId, events)
- ReadStream(streamId)
- streamIdごとにイベント列を保持
- 外部から内部リストを破壊されないようにコピーして返す
- シンプルに（永続化・競合対策なし）
コードだけ出してください。
```

### 7-2. レビューさせる（バグを先に潰す）

```text
このInMemoryEventStore実装をレビューして、
「スレッド安全性」「外部からの改変」「null/空入力」「設計の分かりやすさ」
の観点で指摘と改善案をください。
```

### 7-3. テスト生成（順番・分離を重視）

```text
InMemoryEventStoreに対して、
(1) Append順が保たれるテスト
(2) streamIdが違うと混ざらないテスト
xUnitで書いてください。
```

---

## 8) ミニ課題（できたら強い💪🌸）

* 課題A：`ReadStreamAsync` が存在しない streamId なら **空配列**を返すテストを書こう🧪✨
* 課題B：`AppendAsync` に `events.Count == 0` を渡したとき **何も増えない**テストを書こう🧪🍀
* 課題C：`StoredEvent` に `CorrelationId`（Guid）を追加して、同じ操作のイベントを追えるようにしてみよう🧵🔎

---

## チェックポイント✅🎀

* [ ] EventStoreは **Append / ReadStream** が最小セット📦
* [ ] streamId ごとにイベント列を分けられた🧺🧺
* [ ] 外部から壊されないように **コピーして返せた**🧤
* [ ] テストで「順番」と「分離」を確認できた🧪✨

[1]: https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14?utm_source=chatgpt.com "What's new in C# 14"
[2]: https://www.nuget.org/packages/xunit.v3 "
        NuGet Gallery
        \| xunit.v3 3.2.2
    "
[3]: https://www.nuget.org/packages/xunit.runner.visualstudio "
        NuGet Gallery
        \| xunit.runner.visualstudio 3.1.5
    "
[4]: https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/?utm_source=chatgpt.com "Announcing .NET 10"
