# 第32章：Projection再構築（リプレイ）🔁🧹

## この章でできるようになること🎯✨

* Projection（読みモデル）を **いったん消して**、イベントを最初から流して **作り直せる** ようになる😊🔁
* 「壊れた」「ズレた」「追加したい」を **リプレイで回復**できる感覚がつく💪✨
* 本番っぽくするための **チェックポイント（どこまで処理したか）** も入門できる🏁👀

---

# 1. Projectionって「作り直せる」前提のデータだよ🧠✨

イベントソーシングでは、イベントは「起きた事実」を積む方式で、そこから状態や読みモデルを再生成できます。つまり Projection は **派生物** なので、最悪 **消して再構築**できるのが強みです😊🧹🔁 ([Microsoft Learn][1])

---

# 2. Projectionを再構築したくなる典型パターンあるある😵‍💫➡️😊

## よくある理由🧩

* **バグでProjectionがズレた**（1イベントの反映漏れ、とか）🐛💥
* **新しい一覧画面が欲しい** → 新Projectionを追加したい🆕📋
* **Projectionのスキーマを変えたい**（表示項目を増やす等）🧾➕
* **イベント数が増えて処理方式を変えたい**（バッチ化、最適化）⚡

## ここで大事な感覚💡

* イベント：なるべく **消さない・改ざんしない**（履歴）📜
* Projection：壊れたら **捨てて作り直す**（派生）🗑️➡️🏗️

---

# 3. リプレイ再構築の3つのレベル🎚️（学習→実務）

## レベルA：学習用（いちばん簡単）🍀

1. Projectionを全部消す
2. 先頭からイベントを全部流す
3. できたProjectionを保存する
   → 小さいアプリならこれでOK😊✅

## レベルB：実務っぽい（切り替え方式）🔁🚦

* 新しいProjection置き場（例：テーブル `Projection_v2`）に再構築して
* 最後に **切り替える**（スイッチ）
  → 再構築中にユーザーが見てる画面を壊しにくい👀✨

## レベルC：本番ガチ寄り（追いかけ＝Catch-up）🏃‍♀️💨

* 「ここまで処理した」地点（チェックポイント）を覚えて
* 再構築後に **差分だけ追いかけ**て最新にそろえる
  → ずっと動かしながらでも整合させやすい🔁✅

---

# 4. 今日のゴール：レベルA＋チェックポイント入門🏁😊

ここでは「イベントを最初から全部読む」ために、イベントに **通し番号（Position）** を付けます📼🔢
（ストリームの version は「その集約内の順番」、Position は「全体の順番」ってイメージだよ😊）

あと、2026の最新前提としては **.NET 10（LTS）** が基本線で、2026-01-13時点の更新も出ています🧰✨ ([Microsoft][2])
C# も .NET 10 / Visual Studio 2026 で **C# 14** が試せます🧁✨ ([Microsoft Learn][3])

---

# 5. 実装：イベントを「全体順」で読めるようにする📦➡️📚

## 5.1 EventEnvelope（イベントの封筒）✉️

* Projection更新では「イベント本体」だけじゃなくて
  **Position / StreamId / Version / 発生時刻** なども欲しくなりがち🏷️✨

```csharp
public sealed record EventEnvelope(
    long Position,
    string StreamId,
    int Version,
    DateTimeOffset OccurredAt,
    object Event
);
```

---

## 5.2 IEventStore（ReadAllを追加）📚🔁

既存の `ReadStream(streamId)` とは別に、Projection再構築用に「全イベント」を読みたいです。

```csharp
public interface IEventStore
{
    Task AppendAsync(string streamId, int expectedVersion, IReadOnlyList<object> events);

    Task<IReadOnlyList<EventEnvelope>> ReadStreamAsync(string streamId);

    // ✅ Projection再構築の主役：全体の順番で読む
    Task<IReadOnlyList<EventEnvelope>> ReadAllAsync(long fromExclusivePosition, int maxCount);
}
```

---

## 5.3 インメモリEventStore（最小実装）🧺✨

Position は Append のたびに増える通し番号にします📈

```csharp
using System.Collections.Concurrent;
using System.Threading;

public sealed class InMemoryEventStore : IEventStore
{
    private readonly ConcurrentDictionary<string, List<EventEnvelope>> _streams = new();
    private readonly List<EventEnvelope> _all = new();
    private long _position = 0;

    public Task AppendAsync(string streamId, int expectedVersion, IReadOnlyList<object> events)
    {
        var stream = _streams.GetOrAdd(streamId, _ => new List<EventEnvelope>());

        // expectedVersionチェック（超ざっくり）
        var currentVersion = stream.Count == 0 ? -1 : stream[^1].Version;
        if (currentVersion != expectedVersion)
            throw new InvalidOperationException($"Concurrency conflict. expected={expectedVersion}, actual={currentVersion}");

        foreach (var e in events)
        {
            var nextVersion = currentVersion + 1;
            currentVersion = nextVersion;

            var pos = Interlocked.Increment(ref _position);
            var env = new EventEnvelope(
                Position: pos,
                StreamId: streamId,
                Version: nextVersion,
                OccurredAt: DateTimeOffset.UtcNow,
                Event: e
            );

            stream.Add(env);
            _all.Add(env);
        }

        return Task.CompletedTask;
    }

    public Task<IReadOnlyList<EventEnvelope>> ReadStreamAsync(string streamId)
    {
        if (!_streams.TryGetValue(streamId, out var stream))
            return Task.FromResult<IReadOnlyList<EventEnvelope>>(Array.Empty<EventEnvelope>());

        return Task.FromResult<IReadOnlyList<EventEnvelope>>(stream.ToList());
    }

    public Task<IReadOnlyList<EventEnvelope>> ReadAllAsync(long fromExclusivePosition, int maxCount)
    {
        var batch = _all
            .Where(x => x.Position > fromExclusivePosition)
            .OrderBy(x => x.Position)
            .Take(maxCount)
            .ToList();

        return Task.FromResult<IReadOnlyList<EventEnvelope>>(batch);
    }
}
```

---

# 6. Projection側：Applyで読みモデルを更新する🔎🧱

ここでは例として「カートの一覧表示用Projection」を作る想定にします🛒📋
（イベント名は雰囲気でOK。前章までの題材に合わせて読み替えてね😊）

## 6.1 Projectionが守るべきルール3つ🧷✨

1. **同じイベントをもう一回受けても壊れにくい**（できれば）🔁✅
2. **外部副作用を起こさない**（メール送信とかしない）📭🚫
3. **DateTime.Nowで結果が変わる**みたいな非決定性を避ける⏰🚫

## 6.2 IProjection（最小）🧩

```csharp
public interface IProjection
{
    string Name { get; }
    Task ResetAsync();                    // 全消し（再構築用）
    Task ApplyAsync(EventEnvelope env);   // 1イベント反映
}
```

## 6.3 Projection（インメモリ）例📋

```csharp
using System.Collections.Concurrent;

public sealed record CartSummary(string CartId, int ItemCount);

public sealed class CartSummaryProjection : IProjection
{
    public string Name => "CartSummary";

    private readonly ConcurrentDictionary<string, int> _itemCounts = new();

    public Task ResetAsync()
    {
        _itemCounts.Clear();
        return Task.CompletedTask;
    }

    public Task ApplyAsync(EventEnvelope env)
    {
        var cartId = env.StreamId;

        switch (env.Event)
        {
            case CartCreated:
                _itemCounts[cartId] = 0;
                break;

            case ItemAdded:
                _itemCounts.AddOrUpdate(cartId, 1, (_, old) => old + 1);
                break;

            case ItemRemoved:
                _itemCounts.AddOrUpdate(cartId, 0, (_, old) => Math.Max(0, old - 1));
                break;
        }

        return Task.CompletedTask;
    }

    // 画面用に取り出すメソッド（お好みで）
    public IReadOnlyList<CartSummary> GetAll()
        => _itemCounts.Select(kv => new CartSummary(kv.Key, kv.Value)).ToList();
}

// 例のイベント型（最小）
public sealed record CartCreated;
public sealed record ItemAdded(string Sku);
public sealed record ItemRemoved(string Sku);
```

---

# 7. 再構築サービス（リプレイ本体）🔁🧹✨

## 7.1 チェックポイント（どこまで処理したか）🏁

最小は「最後に処理したPosition」を保存すればOKです。

```csharp
public interface ICheckpointStore
{
    Task<long> LoadAsync(string projectionName);
    Task SaveAsync(string projectionName, long position);
}

public sealed class InMemoryCheckpointStore : ICheckpointStore
{
    private readonly Dictionary<string, long> _map = new();

    public Task<long> LoadAsync(string projectionName)
        => Task.FromResult(_map.TryGetValue(projectionName, out var pos) ? pos : 0);

    public Task SaveAsync(string projectionName, long position)
    {
        _map[projectionName] = position;
        return Task.CompletedTask;
    }
}
```

> ここでの 0 は「未処理」扱いにしてます😊（Positionは 1 から始まる想定）

---

## 7.2 Rebuild（全消し→全流し）🚿➡️🏗️

```csharp
public sealed class ProjectionRebuilder
{
    private readonly IEventStore _eventStore;
    private readonly ICheckpointStore _checkpointStore;

    public ProjectionRebuilder(IEventStore eventStore, ICheckpointStore checkpointStore)
    {
        _eventStore = eventStore;
        _checkpointStore = checkpointStore;
    }

    public async Task RebuildAsync(IProjection projection, int batchSize = 200)
    {
        // 1) 全消し
        await projection.ResetAsync();

        // 2) チェックポイントもリセット
        await _checkpointStore.SaveAsync(projection.Name, 0);

        long pos = 0;

        while (true)
        {
            var batch = await _eventStore.ReadAllAsync(pos, batchSize);
            if (batch.Count == 0) break;

            foreach (var env in batch)
            {
                await projection.ApplyAsync(env);
                pos = env.Position;

                // 小さくても「進捗保存」しておくと安心😊
                await _checkpointStore.SaveAsync(projection.Name, pos);
            }
        }
    }
}
```

---

# 8. ミニ演習：Projectionを消して、リプレイで復活させよう🧪🎮

## 演習1：わざと壊して直す😈➡️😇

1. イベントをいくつか積む（カートを作って商品を足す）🛒➕
2. Projectionを `ResetAsync()` で消す🧹
3. 一覧が空になるのを確認👀
4. `RebuildAsync()` を呼ぶ🔁
5. 一覧が戻るのを確認🎉

## 演習2：反映漏れを作って検知する👀🐛

* `ItemRemoved` の処理をコメントアウトしてリビルド
* 「なんか数が合わない…」を体験してから戻す
  → Projectionは **ズレても直せる** を体で覚える💪✨

---

# 9. テスト：再構築は“同じ入力なら同じ結果”が命🧪💎

## Given-When-Then（再構築版）🌸

* Given：イベント列（CartCreated, ItemAdded, ItemAdded, ItemRemoved）
* When：Rebuild
* Then：ItemCount が期待どおり（例：1）

```csharp
using Xunit;

public class ProjectionRebuildTests
{
    [Fact]
    public async Task Rebuild_replays_events_and_restores_projection()
    {
        var store = new InMemoryEventStore();
        var cp = new InMemoryCheckpointStore();
        var projection = new CartSummaryProjection();
        var rebuilder = new ProjectionRebuilder(store, cp);

        var cartId = "cart-1";

        await store.AppendAsync(cartId, -1, new object[] { new CartCreated() });
        await store.AppendAsync(cartId, 0,  new object[] { new ItemAdded("A") });
        await store.AppendAsync(cartId, 1,  new object[] { new ItemAdded("B") });
        await store.AppendAsync(cartId, 2,  new object[] { new ItemRemoved("A") });

        // わざと消す
        await projection.ResetAsync();

        // 再構築
        await rebuilder.RebuildAsync(projection);

        var list = projection.GetAll();
        Assert.Single(list);
        Assert.Equal(1, list[0].ItemCount);
    }
}
```

---

# 10. よくある落とし穴（ここだけ見れば事故減る）🧯✨

## 落とし穴1：Projectionで副作用しちゃう📣💥

* 再構築で過去イベントを何千件も流す
* そのたびに「通知メール送信」みたいなのをすると地獄📩😱
  ✅ Projectionは **表示用に徹する** のが安全😊

## 落とし穴2：順番が狂う🔀😵

* イベントは基本「順番が命」
  ✅ `Position` や `Version` を使って **必ず順に適用**🔢✅

## 落とし穴3：非決定性（毎回結果が変わる）🎲

* `DateTime.Now` で「今日の表示」を作る、みたいなのは再構築でズレがち
  ✅ “イベントに入ってる事実”から計算する🧠✅

---

# 11. AI活用：再構築の抜け漏れを減らすプロンプト集🤖🪄

## 11.1 「Apply漏れ」レビュー依頼👀

```text
次のProjectionのApply実装をレビューして。
観点は(1)イベント反映漏れ(2)非決定性(3)副作用(4)同一イベントの二重適用耐性。
不足イベントがあれば、追加すべきswitch分岐を提案して。
```

## 11.2 「再構築チェックリスト」生成📋✨

```text
Projection再構築（イベント全リプレイ）の運用チェックリストを作って。
手順、ログ、所要時間計測、失敗時のロールバック、確認観点まで入れて。
初心者がそのまま読める短い箇条書きで。
```

## 11.3 「Given-When-Thenのテスト案」量産🧪

```text
このイベント列の例を10パターン作って、Given-When-Thenのテストケースにして。
成功だけでなく失敗系（不変条件違反の前提）も混ぜて。
```

---

# 12. まとめ🌟

* Projectionは **派生データ**だから、壊れたら **消してリプレイで復活**できる🔁🧹
* 再構築には「全イベントを順に読む」仕組み（Position）が便利📼🔢
* チェックポイントを持つと、運用が一気にラクになる🏁😊
* イベントソーシングでは「履歴（イベント）→再生成（状態/読みモデル）」が大きな価値のひとつだよ✨ ([Microsoft Learn][1])

[1]: https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing?utm_source=chatgpt.com "Event Sourcing pattern - Azure Architecture Center"
[2]: https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core?utm_source=chatgpt.com "NET and .NET Core official support policy"
[3]: https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14?utm_source=chatgpt.com "What's new in C# 14"
