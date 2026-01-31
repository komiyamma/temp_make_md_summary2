# 第16章：Command処理の“型”①（Load → Decide → Append）📮✅

## この章でできるようになること🎯✨

* Command（やりたいこと）を受け取って、**イベントソーシングの王道フロー**で処理できるようになる😊
* 処理の流れを **1つの「型」**に固定して、迷子にならないようにする🧭💕
* 「どこに何を書くか」を分けて、コードが読みやすくなる📚✨

---

## まずは“型”を覚えちゃおう🧠💡

イベントソーシングの Command 処理は、だいたいこれでOKです👇✨

1. **Load**：過去イベントを EventStore から読む📚🔁
2. **Decide**：集約（Aggregate）がルールチェックして、新イベントを決める🛡️✨
3. **Append**：新イベントを EventStore に保存する🧾✅

これを **Load → Decide → Append** って呼ぶよ📮✅

---

## どうしてこの型が大事なの？🤔💗

もし Command の中で “状態を直接書き換え” しちゃうと…

* 「何が起きたか」の履歴が薄くなる😵‍💫
* テストがやりにくい🧪💥
* 後から仕様変更でぐちゃぐちゃになりやすい🌀

だから、**状態の更新はイベントを通して行う**のが基本だよ✨

---

# 今回のお題（例）🛒🍎

「ショッピングカート」っぽいミニ例でいくよ😊

* Command：`AddItemToCart`（商品をカートに追加）🧺
* Event：`ItemAddedToCart`（商品が追加された）📦✨
* Aggregate：`ShoppingCart`（ルールを守る担当）🛡️

---

# 1) Load：過去イベントを読む📚🔁

EventStore には「その集約で過去に起きた出来事」が並んでるよね。
だからまず **ストリームID**（例：`cart-123`）でイベント列を読む！

ポイント💡

* Load の責任は「過去を取ってくる」だけ
* ここでは “判断” しない（まだ Decide じゃない）🙅‍♀️

---

# 2) Decide：ルールチェックして、新イベントを作る🛡️✨

Decide は **Aggregate の仕事**だよ😊

* 不変条件（守るべきルール）をチェック🧷
* OKなら新イベントを作る🎁
* NGなら「止める」（次章で詳しくやるよ🚧）

---

# 3) Append：新イベントを保存する🧾✅

最後に新イベントを EventStore に append（追記）するよ✨
このとき「順番（version）」も超大事！
（競合は22〜24章でがっつりやるけど、ここから形だけ入れてOK👍）

---

# 実装：最小の構成で “型” を書く🧱✨

## ① ドメイン：Command / Event を用意📮📜

```csharp
public sealed record AddItemToCart(
    Guid CartId,
    string Sku,
    int Quantity,
    Guid CommandId
);

public sealed record ItemAddedToCart(
    string Sku,
    int Quantity
);
```

* `CommandId` は「同じCommandを2回送っちゃった」対策の足がかり（35章で活きるよ🔁🧷）

---

## ② EventEnvelope（メタデータ入り）🏷️🍱

イベントには「起きた事実」＋「付帯情報」があると運用しやすいよ✨

```csharp
public sealed record EventEnvelope(
    Guid EventId,
    DateTimeOffset OccurredAt,
    object Event,
    Guid? CausationId // どのCommandが原因？
);
```

---

## ③ EventStore の最小インターフェース📦✅

```csharp
public interface IEventStore
{
    Task<StreamReadResult> ReadStreamAsync(string streamId, CancellationToken ct);

    Task AppendAsync(
        string streamId,
        int expectedVersion,
        IReadOnlyList<EventEnvelope> events,
        CancellationToken ct);
}

public sealed record StreamReadResult(
    int Version,
    IReadOnlyList<EventEnvelope> Events
);
```

* `expectedVersion` は “今見たバージョンの続きに書くよ” って意味（競合対策の準備運動🏋️‍♀️）

---

## ④ Aggregate：Rehydrate（復元）と Decide（判断）🧠🔁🛡️

ここがこの章の主役だよ✨
「イベントを適用して状態を作る」＋「Commandからイベントを決める」

```csharp
public sealed class ShoppingCart
{
    private readonly Dictionary<string, int> _items = new();
    private bool _isCheckedOut;

    public static ShoppingCart Rehydrate(IEnumerable<EventEnvelope> history)
    {
        var cart = new ShoppingCart();
        foreach (var e in history)
        {
            cart.Apply(e.Event);
        }
        return cart;
    }

    // Decide：Commandを受けて「起こすイベント」を返す（状態はここで直接いじらない）
    public IReadOnlyList<object> Decide(AddItemToCart cmd)
    {
        if (cmd.Quantity <= 0) throw new ArgumentOutOfRangeException(nameof(cmd.Quantity));

        if (_isCheckedOut)
            throw new InvalidOperationException("チェックアウト後は追加できません");

        // ここで「何が起きたか」をイベントとして作る✨
        return new object[]
        {
            new ItemAddedToCart(cmd.Sku, cmd.Quantity)
        };
    }

    // Apply：イベントで状態を更新（復元でも、新イベント反映でも使う）
    public void Apply(object @event)
    {
        switch (@event)
        {
            case ItemAddedToCart e:
                _items.TryGetValue(e.Sku, out var current);
                _items[e.Sku] = current + e.Quantity;
                break;

            default:
                throw new NotSupportedException($"Unknown event: {@event.GetType().Name}");
        }
    }
}
```

ここで大事なのは👇💕

* **Decide は “イベントを返す”**（何が起きたか）
* **Apply は “状態を変える”**（どう変わったか）

---

## ⑤ CommandHandler：Load → Decide → Append を全部つなぐ📮✅

```csharp
public sealed class ShoppingCartCommandHandler
{
    private readonly IEventStore _store;

    public ShoppingCartCommandHandler(IEventStore store)
        => _store = store;

    public async Task HandleAsync(AddItemToCart cmd, CancellationToken ct)
    {
        var streamId = $"cart-{cmd.CartId:D}";

        // 1) Load
        var read = await _store.ReadStreamAsync(streamId, ct);

        // 2) Rehydrate（イベント列から現在状態へ）
        var cart = ShoppingCart.Rehydrate(read.Events);

        // 3) Decide（新イベントを作る）
        var newEvents = cart.Decide(cmd);

        // （おまけ）新イベントをApplyしておくと、後続処理が書きやすい時もあるよ✨
        foreach (var ev in newEvents) cart.Apply(ev);

        // 4) Append（EventEnvelopeに包んで保存）
        var envelopes = newEvents
            .Select(ev => new EventEnvelope(
                EventId: Guid.NewGuid(),
                OccurredAt: DateTimeOffset.UtcNow,
                Event: ev,
                CausationId: cmd.CommandId
            ))
            .ToList();

        await _store.AppendAsync(streamId, read.Version, envelopes, ct);
    }
}
```

✅ これが **Load → Decide → Append** の “型” だよ〜！📮✨

---

# テスト：Given-When-Then で超わかりやすく🧪🌸

ここでは「成功パターン」だけやってみよう😊
（失敗パターンは次章で “弾く” をきれいにするよ🛡️🚧）

## テスト用：インメモリEventStore（最小）📦🧪

```csharp
public sealed class InMemoryEventStore : IEventStore
{
    private readonly Dictionary<string, List<EventEnvelope>> _streams = new();

    public Task<StreamReadResult> ReadStreamAsync(string streamId, CancellationToken ct)
    {
        _streams.TryGetValue(streamId, out var list);
        list ??= new List<EventEnvelope>();

        // version は「最後の index」っぽく扱う（超最小）
        var version = list.Count;
        return Task.FromResult(new StreamReadResult(version, list.ToList()));
    }

    public Task AppendAsync(
        string streamId,
        int expectedVersion,
        IReadOnlyList<EventEnvelope> events,
        CancellationToken ct)
    {
        _streams.TryGetValue(streamId, out var list);
        list ??= new List<EventEnvelope>();
        _streams[streamId] = list;

        if (list.Count != expectedVersion)
            throw new InvalidOperationException("Version mismatch");

        list.AddRange(events);
        return Task.CompletedTask;
    }
}
```

## xUnit テスト例🧪✨

```csharp
using Xunit;

public sealed class Chapter16Tests
{
    [Fact]
    public async Task AddItem_LoadDecideAppend_adds_ItemAdded_event()
    {
        // Given
        var store = new InMemoryEventStore();
        var handler = new ShoppingCartCommandHandler(store);

        var cartId = Guid.NewGuid();
        var cmd = new AddItemToCart(
            CartId: cartId,
            Sku: "APPLE",
            Quantity: 2,
            CommandId: Guid.NewGuid()
        );

        // When
        await handler.HandleAsync(cmd, CancellationToken.None);

        // Then
        var streamId = $"cart-{cartId:D}";
        var read = await store.ReadStreamAsync(streamId, CancellationToken.None);

        Assert.Single(read.Events);
        Assert.IsType<ItemAddedToCart>(read.Events[0].Event);

        var ev = (ItemAddedToCart)read.Events[0].Event;
        Assert.Equal("APPLE", ev.Sku);
        Assert.Equal(2, ev.Quantity);
        Assert.Equal(cmd.CommandId, read.Events[0].CausationId);
    }
}
```

---

# つまずきポイント集（あるある）😵‍💫💥

## ❶ Decide で状態を直接いじっちゃう🙅‍♀️

* Decide は「イベントを決める」
* 状態更新は Apply に寄せる（復元でも使えるからね🔁）

## ❷ Load したのに Rehydrate してない😇

* ただイベントを読んだだけだと、今の状態が作れてないよ〜！
* **Rehydrate（Apply連打）**は必須✨

## ❸ Append するイベントに “メタ情報” がない🏷️

* EventId / OccurredAt / CausationId があると、後で助かる確率が爆上がり📈✨

---

# ミニ演習（10〜25分）✍️🌸

## 演習A：Commandを1つ増やす➕🧺

* `RemoveItemFromCart` を追加
* `ItemRemovedFromCart` を追加
* Decide と Apply を実装して、テスト1本追加🧪✨

## 演習B：イベントの“形”を見直す🔎

* `Sku` だけで足りる？
* 将来「商品名変更」「価格変動」が来たらどうする？（payload入れすぎ注意🍱⚠️）

---

# AI活用（Copilot / Codex）プロンプト例🤖✨

## 1) Handlerの雛形を作らせる🧰

```text
C#でイベントソーシングのCommandHandlerを書きたいです。
型は Load(過去イベント読む) → Rehydrate → Decide(新イベント生成) → Append(保存) です。
IEventStore は ReadStreamAsync(streamId) と AppendAsync(streamId, expectedVersion, events) を持ちます。
ShoppingCart の Decide は AddItemToCart を受けて ItemAddedToCart を返します。
最小で読みやすいコードを提案してください。
```

## 2) テスト（Given-When-Then）を作らせる🧪

```text
xUnitでGiven-When-Then形式のテストを書いてください。
Given: 空のストリーム
When: AddItemToCart
Then: ItemAddedToCart が1件追加され、CausationIdがCommandIdと一致する
```

---

# 最新メモ（この章に関係するツールの動き）🧩🪟

* Visual Studio 2026 は v18 系としてリリース履歴が公開されていて、2026-01-20 に 18.2.1 が出ています。([Microsoft Learn][1])
* Visual Studio 2026 のリリースノートも公開されています。([Microsoft Learn][2])
* .NET 10 の “What’s new” が公開されていて、ASP.NET Core 10 などの更新がまとまっています。([Microsoft Learn][3])
* VS Code 側も Insiders の 2026年1月アップデート（1.109）が更新されています。([Visual Studio Code][4])

---

## まとめ：この章の合言葉📮✅

* **Load**：過去を読む📚
* **Decide**：ルールで決める🛡️
* **Append**：履歴として残す🧾

この“型”が、次の章（不変条件で弾く🛡️🚧）にもそのまま繋がるよ✨

[1]: https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-history?utm_source=chatgpt.com "Visual Studio Release History"
[2]: https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes?utm_source=chatgpt.com "Visual Studio 2026 Release Notes"
[3]: https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/overview?utm_source=chatgpt.com "What's new in .NET 10"
[4]: https://code.visualstudio.com/updates/v1_109?utm_source=chatgpt.com "January 2026 Insiders (version 1.109)"
