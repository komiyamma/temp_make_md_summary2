# 第29章：Projection実装①（同期で更新）⚡🧱

## この章でできるようになること 🎯✨

* **イベントを書いた直後に、画面用データ（Projection）も同時に更新**できるようになるよ😊
* **「書いたのに読めない😵‍💫」を減らす**（Read-your-writes を作りやすい）📖✅
* Projection更新の **抜け漏れ・二重反映**を防ぐための「小さな型」を身につける🧰✨

---

# 1. Projection（読みモデル）を同期更新するってどういうこと？🔎⚡

イベントソーシングでは、基本はこうだよ👇

* **書き込み（Write）**：Command → Event（イベントを追記）📮➡️📜
* **読み取り（Read）**：Projection（表示用の形）を読む👀📋

ここで「同期更新」とは、**イベントを追記した“同じ処理の流れ”の中で Projection も更新しちゃう**方法のこと😊⚡
やり方次第では **イベント保存とProjection更新を“同じトランザクション”**に入れられるケースもあるよ（同じRDBで管理する等）。([Event-Driven][1])

---

# 2. 同期Projectionのメリット・注意点 🌟⚠️

## メリット 🌈

* **すぐ読める（Read-your-writes）**：保存直後に一覧や詳細が最新で出る✨
* **学習にめちゃ向いてる**：流れが一直線で理解しやすい😊
* 同一DBでうまくやると **「イベントだけ書けた」「Projectionだけ更新された」事故を減らせる**（トランザクション設計しやすい）([Event-Driven][1])

## 注意点 ⚠️

* **遅くなりやすい**：Projection更新も“その場で”やるのでレスポンス時間が伸びる⌛
* **例外が怖い**：Projection更新でコケたら、イベントだけ保存されちゃう…みたいな事故が起き得る😵
* **Projectionを増やしすぎると地獄**：コマンド1回で更新が大量になって重い💥

なのでこの章では、まずは **「最小で安全な同期更新」**の型を作るよ🧱✨

---

# 3. 今回作るProjection（例：カート一覧）🛒📋

## 例：CartSummary（一覧用）

一覧で見たいのって、だいたいこんな感じ👇

* カートID
* 状態（作成済み / 購入済み など）
* アイテム数、合計数量
* 最終更新日時

**表示に必要な形だけ**を持つのがコツだよ😊🍱（入れすぎ注意！）

---

# 4. 「同期更新」の最小アーキテクチャ 🧠🧩

ポイントはこれ👇

1. **EventStoreにイベントを追記**する📜
2. 追記したイベントを **Projectionに流す（Project）**🔁
3. 二重反映を避けるため、Projection側に **チェックポイント（最後に処理したversion）**を持たせる🔖

---

# 5. 実装：イベントとEnvelope（version付き）📦🔢

```csharp
using System.Collections.Concurrent;

public interface IDomainEvent
{
    DateTimeOffset OccurredAt { get; }
}

public sealed record EventEnvelope(
    string StreamId,
    long Version,
    IDomainEvent Event
);

// 例：カートのイベント（必要最低限）
public sealed record CartCreated(string CartId, DateTimeOffset OccurredAt) : IDomainEvent;
public sealed record ItemAdded(string CartId, string Sku, int Quantity, DateTimeOffset OccurredAt) : IDomainEvent;
public sealed record ItemRemoved(string CartId, string Sku, DateTimeOffset OccurredAt) : IDomainEvent;
public sealed record CartCheckedOut(string CartId, DateTimeOffset OccurredAt) : IDomainEvent;
```

# ✅ `Version` は「そのストリーム内での順番」だよ（第23章の expectedVersion とセットで効くやつ）🔒

---

## 6. 実装：最小EventStore（Append時にversion採番）📼✅

```csharp
public interface IEventStore
{
    IReadOnlyList<EventEnvelope> ReadStream(string streamId);
    IReadOnlyList<EventEnvelope> Append(string streamId, long expectedVersion, IReadOnlyList<IDomainEvent> newEvents);
}

public sealed class InMemoryEventStore : IEventStore
{
    private readonly object _gate = new();
    private readonly Dictionary<string, List<EventEnvelope>> _streams = new();

    public IReadOnlyList<EventEnvelope> ReadStream(string streamId)
    {
        lock (_gate)
        {
            return _streams.TryGetValue(streamId, out var list)
                ? list.ToList()
                : new List<EventEnvelope>();
        }
    }

    public IReadOnlyList<EventEnvelope> Append(string streamId, long expectedVersion, IReadOnlyList<IDomainEvent> newEvents)
    {
        lock (_gate)
        {
            if (!_streams.TryGetValue(streamId, out var list))
            {
                list = new List<EventEnvelope>();
                _streams[streamId] = list;
            }

            var currentVersion = list.Count == 0 ? 0 : list[^1].Version;
            if (currentVersion != expectedVersion)
                throw new InvalidOperationException($"Concurrency conflict. expected={expectedVersion}, actual={currentVersion}");

            var appended = new List<EventEnvelope>(newEvents.Count);
            foreach (var e in newEvents)
            {
                var next = currentVersion + 1;
                var env = new EventEnvelope(streamId, next, e);
                list.Add(env);
                appended.Add(env);
                currentVersion = next;
            }

            return appended;
        }
    }
}
```

ここまでで、**イベントはちゃんと順番付きで保存**できる✅

---

## 7. 実装：Projection（CartSummary）📋✨

### 7-1. 読みモデル（表示用の形）👀

```csharp
public sealed record CartSummaryView(
    string CartId,
    string Status,
    int DistinctItems,
    int TotalQuantity,
    DateTimeOffset UpdatedAt
);
```

### 7-2. Projectionストア（インメモリ）＋チェックポイント🔖

「二重反映しない」ために、**各Streamの最後に処理したVersion**を覚えるよ😊

```csharp
public interface ICartSummaryStore
{
    CartSummaryView? Get(string cartId);
    IReadOnlyList<CartSummaryView> List();

    // upsert と checkpoint
    void Upsert(CartSummaryView view);
    long GetLastProcessedVersion(string streamId);
    void SetLastProcessedVersion(string streamId, long version);
}

public sealed class InMemoryCartSummaryStore : ICartSummaryStore
{
    private readonly ConcurrentDictionary<string, CartSummaryView> _views = new();
    private readonly ConcurrentDictionary<string, long> _checkpoints = new();

    public CartSummaryView? Get(string cartId)
        => _views.TryGetValue(cartId, out var v) ? v : null;

    public IReadOnlyList<CartSummaryView> List()
        => _views.Values.OrderByDescending(v => v.UpdatedAt).ToList();

    public void Upsert(CartSummaryView view)
        => _views[view.CartId] = view;

    public long GetLastProcessedVersion(string streamId)
        => _checkpoints.TryGetValue(streamId, out var v) ? v : 0;

    public void SetLastProcessedVersion(string streamId, long version)
        => _checkpoints[streamId] = version;
}
```

---

## 8. 実装：Projector（イベントを受けて読みモデル更新）🔁🧱

```csharp
public interface IProjector
{
    void Project(IReadOnlyList<EventEnvelope> appendedEvents);
}

public sealed class CartSummaryProjector : IProjector
{
    private readonly ICartSummaryStore _store;

    public CartSummaryProjector(ICartSummaryStore store)
    {
        _store = store;
    }

    public void Project(IReadOnlyList<EventEnvelope> appendedEvents)
    {
        // version順に処理（念のため）
        foreach (var env in appendedEvents.OrderBy(e => e.Version))
        {
            var last = _store.GetLastProcessedVersion(env.StreamId);
            if (env.Version <= last)
            {
                // すでに処理済みならスキップ（冪等っぽくする）🔁🧷
                continue;
            }

            ApplyOne(env);

            // 最後にcheckpoint更新（ここ超大事）🔖✨
            _store.SetLastProcessedVersion(env.StreamId, env.Version);
        }
    }

    private void ApplyOne(EventEnvelope env)
    {
        switch (env.Event)
        {
            case CartCreated e:
                _store.Upsert(new CartSummaryView(
                    CartId: e.CartId,
                    Status: "Active",
                    DistinctItems: 0,
                    TotalQuantity: 0,
                    UpdatedAt: e.OccurredAt
                ));
                break;

            case ItemAdded e:
            {
                var cur = _store.Get(e.CartId)
                    ?? new CartSummaryView(e.CartId, "Active", 0, 0, e.OccurredAt);

                // 超ざっくり：DistinctItems を正確にしたいなら SKU集合を別途持つProjectionにする（後で発展OK）😊
                var next = cur with
                {
                    TotalQuantity = cur.TotalQuantity + e.Quantity,
                    DistinctItems = Math.Max(cur.DistinctItems, 1),
                    UpdatedAt = e.OccurredAt
                };
                _store.Upsert(next);
                break;
            }

            case ItemRemoved e:
            {
                var cur = _store.Get(e.CartId);
                if (cur is null) break;

                var next = cur with
                {
                    UpdatedAt = e.OccurredAt
                };
                _store.Upsert(next);
                break;
            }

            case CartCheckedOut e:
            {
                var cur = _store.Get(e.CartId);
                if (cur is null) break;

                _store.Upsert(cur with { Status = "CheckedOut", UpdatedAt = e.OccurredAt });
                break;
            }
        }
    }
}
```

✅ ここでのコツは **「Projectorは“速く・単純に”」**だよ⚡
重い集計を始めたら、同期更新はすぐ辛くなる😵‍💫（次の非同期編につながる）

---

## 9. 「同期更新」を呼び出す場所（いちばん大事）📍✅

同期Projectionは、だいたいこのどっちかに置くよ👇

### パターンA：Commandハンドラの最後で Project ✅（学習向け）

* Appendできたら、そのままProject
* 返す前にProjectionが更新されるので「書いたらすぐ読める」✨

### パターンB：EventStore側で “Append+Project” を一体化 ✅（事故りにくい）

「イベント保存だけ成功」事故を減らすには、**同じ“単位”として扱う**のが強い💪
（RDBなら同一トランザクション化が王道だよ）([Event-Driven][1])

今回は学習しやすいように **A寄り + 事故防止のミニ工夫**でいくよ😊

---

## 10. 実装：Command処理の最後で同期Project 📮➡️📜➡️🔎

```csharp
public sealed class CartApplicationService
{
    private readonly IEventStore _store;
    private readonly IProjector _projector;

    public CartApplicationService(IEventStore store, IProjector projector)
    {
        _store = store;
        _projector = projector;
    }

    public void CreateCart(string cartId)
    {
        var streamId = $"cart-{cartId}";
        var history = _store.ReadStream(streamId);
        var expected = history.Count == 0 ? 0 : history[^1].Version;

        var now = DateTimeOffset.UtcNow;
        var newEvents = new IDomainEvent[]
        {
            new CartCreated(cartId, now)
        };

        var appended = _store.Append(streamId, expected, newEvents);
        _projector.Project(appended); // ←同期でProjection更新⚡
    }

    public void AddItem(string cartId, string sku, int qty)
    {
        var streamId = $"cart-{cartId}";
        var history = _store.ReadStream(streamId);
        var expected = history.Count == 0 ? 0 : history[^1].Version;

        var now = DateTimeOffset.UtcNow;
        var newEvents = new IDomainEvent[]
        {
            new ItemAdded(cartId, sku, qty, now)
        };

        var appended = _store.Append(streamId, expected, newEvents);
        _projector.Project(appended); // ←同期でProjection更新⚡
    }
}
```

---

## 11. ミニ演習 🧪✨（ここは手を動かすと一気に理解できる！）

### 演習1：一覧を表示してみよう 📋👀

* `CreateCart` → `AddItem` を呼んだあとに
* `store.List()` で `CartSummaryView` が更新されてるか確認✅

### 演習2：二重反映を防げてる？🔁🧷

* 同じ `appendedEvents` をもう一回 `Project()` に渡してみて
* 数字が二重に増えないかチェック✅（checkpointが効いてるか）

---

## 12. テスト（Given-When-Thenの形）🧪🌸

```csharp
using Xunit;

public sealed class ProjectionSyncTests
{
    [Fact]
    public void Create_and_additem_updates_projection_synchronously()
    {
        // Given
        var eventStore = new InMemoryEventStore();
        var readStore = new InMemoryCartSummaryStore();
        var projector = new CartSummaryProjector(readStore);
        var app = new CartApplicationService(eventStore, projector);

        // When
        app.CreateCart("C1");
        app.AddItem("C1", "SKU-001", 2);

        // Then
        var view = readStore.Get("C1");
        Assert.NotNull(view);
        Assert.Equal("Active", view!.Status);
        Assert.Equal(2, view.TotalQuantity);
    }
}
```

✅ 「コマンドが成功した時点でProjectionも更新済み」になってるのをテストで保証できるよ😊

---

## 13. よくある落とし穴あるある 😵‍💫🕳️

### 1) Projection更新が重くてレスポンスが遅い⌛

同期は **“その場で全部やる”**ので、更新が重いと即つらい💦
➡️ 対策：Projectionを **小さく・速く**、必要なら非同期へ（次の章）📬⏳

### 2) Projectionがコケた時、イベントだけ保存される💥

現実のDBだとここが一番やばい⚠️
➡️ 対策：同じRDB内なら **トランザクションでまとめる**のが王道だよ([Event-Driven][1])
（別DB/別プロセスなら、最終的整合性・再構築（第32章）が効いてくる🔁🧹）

### 3) 二重反映で数字が増殖する👾

リトライや再実行で起きるやつ😵
➡️ 対策：今回やった **checkpoint（最後に処理したversion）**が超シンプルで強い🔖✨

---

## 14. 2026時点の開発メモ（最新前提）🪟🛠️✨

* この教材の前提である .NET 10 は **LTS（長期サポート）**として提供され、サポート期間も明示されてるよ（2025年11月リリース、3年間サポート）。([Microsoft for Developers][2])
* .NET 10 のダウンロードページでは、**10.0.2 の最新リリース日（2026年1月）**も案内されてるよ。([Microsoft][3])
* .NET 10 の新機能まとめ（ASP.NET Core含む）も公式で整理されてるので、機能差分を追うときはここを見るのが安心😊([Microsoft Learn][4])

会社での実務だと、セキュリティ更新の取り込みも大事なので、**LTS＋最新版パッチ**の感覚は早めに身につけておくと強いよ💪✨

---

## 15. AI活用（Projection実装で使うと強いプロンプト例）🤖💬✨

* 「このイベント一覧（CartCreated / ItemAdded / …）から、CartSummaryView を更新する Projector をC#で書いて。
  条件：冪等っぽくするため、Streamごとに lastProcessedVersion を持って、Versionが古いイベントは無視して」
* 「同期ProjectionのテストをGiven-When-Thenで2本。成功ケースと、二重適用を防ぐケース」
* 「このProjectionの更新が重くなりそうな理由を5個。同期のまま耐える工夫と、非同期に切り替える判断基準も」

---

### チェックリスト ✅📌

* [ ] Appendしたイベントを **そのままProjectorへ渡してる**
* [ ] Projectorは **version順**に処理してる
* [ ] **checkpoint（lastProcessedVersion）**で二重反映を防げてる
* [ ] テストで「コマンド成功＝Projection更新済み」を保証できてる

---

[1]: https://event-driven.io/en/projections_and_read_models_in_event_driven_architecture/?utm_source=chatgpt.com "Guide to Projections and Read Models in Event-Driven ..."
[2]: https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/?utm_source=chatgpt.com "Announcing .NET 10"
[3]: https://dotnet.microsoft.com/en-US/download/dotnet/10.0?utm_source=chatgpt.com "Download .NET 10.0 (Linux, macOS, and Windows) | .NET"
[4]: https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/overview?utm_source=chatgpt.com "What's new in .NET 10"
