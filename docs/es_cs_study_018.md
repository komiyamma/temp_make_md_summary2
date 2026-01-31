# 第18章：ユースケース実装①（作成系）🆕✨

## この章でやること（ゴール）🎯😊

「作成系ユースケース」を、イベントソーシングの王道パターンでちゃんと動かします✨
今回は **Create コマンド → Created イベント → 復元できる** までを一気に通します🔁✅

> ちなみにいまは、Microsoft の Visual Studio 2026 で .NET 10 / C# 14 が素直に使えるので、最新の言語機能を気持ちよく使えます🪟✨ ([Microsoft Learn][1])

---

# 18.1 今日の題材：ショッピングカートを「作成」する🧺🆕

ここから先、例として **ShoppingCart（カート）** を使います😊
「カートを作る」は作成系の代表なので、イベントソーシングの最初の成功体験にちょうどいいです🎉

## 使うもの（今回の最小セット）🧩

* コマンド：CreateCart（作って！）📮
* イベント：CartCreated（作られた！）📜
* 集約：ShoppingCart（状態を持つやつ）🧠
* EventStore：Append / ReadStream（前章までの最小実装）📦

---

# 18.2 作成系の「設計の型」🧠✨

作成系でも、基本パターンは同じです👇😊

1. **Load**：過去イベントを読む（新規なら空）📚
2. **Rehydrate**：イベントを Apply して現在状態にする🔁
3. **Decide**：コマンドを見て、新イベントを決める（不変条件チェックもここ）🛡️
4. **Append**：新イベントを保存する📦✅

この「Load → Decide → Append」が固定できると、迷子になりません🧭💕

---

# 18.3 イベント設計：CartCreated は何を持つ？🍱🏷️

## ✅ CartCreated に入れる（payload）

* CartId：どのカート？
* CustomerId：誰のカート？
* CreatedAt：いつ作られた？（例：UTC）⏰

💡イベントは「事実」なので、**命令っぽい情報**（例：CreateReason みたいな“気持ち”）は入れすぎ注意です🙅‍♀️✨

> なお、今の .NET 10 の System.Text.Json は予約っぽい名前（$type / $id / $ref など）と衝突するプロパティ名を早めにエラーにする挙動があるので、イベント payload の命名でそこは避けるのが安全です⚠️ ([Microsoft Learn][2])

---

# 18.4 実装：まずは「イベント」と「集約」から🧱✨

## 18.4.1 イベント定義（record でOK）📜

```csharp
namespace MyEs.Domain;

public interface IDomainEvent;

public sealed record CartCreated(
    Guid CartId,
    Guid CustomerId,
    DateTimeOffset CreatedAtUtc
) : IDomainEvent;
```

---

## 18.4.2 集約（ShoppingCart）🧺🧠

ポイントはこれだけ👇😊

* Apply(CartCreated) で状態が変わる
* Create コマンドが来たら、Created イベントを返す
* 「すでに作成済み」を不変条件として弾く🛡️🚧

```csharp
namespace MyEs.Domain;

public sealed class ShoppingCart
{
    public Guid CartId { get; private set; }
    public Guid CustomerId { get; private set; }
    public bool IsCreated { get; private set; }

    private ShoppingCart() { }

    // Rehydrate 用：イベント列から復元する
    public static ShoppingCart Rehydrate(IEnumerable<IDomainEvent> history)
    {
        var cart = new ShoppingCart();
        foreach (var e in history)
        {
            cart.Apply(e);
        }
        return cart;
    }

    // Decide：コマンドを見て、新イベントを決める（ここがドメインの心臓💓）
    public IReadOnlyList<IDomainEvent> DecideCreate(Guid cartId, Guid customerId, DateTimeOffset nowUtc)
    {
        if (IsCreated)
        {
            // 例外にせず「ドメインエラーで返す」方式は次章以降で強化するよ😊
            // 今回は最小のため、空リストで「何も起きない」を表現（後で Result 型に置き換え推奨）
            return Array.Empty<IDomainEvent>();
        }

        return new IDomainEvent[]
        {
            new CartCreated(cartId, customerId, nowUtc)
        };
    }

    // Apply：イベントを状態に反映
    private void Apply(IDomainEvent e)
    {
        switch (e)
        {
            case CartCreated created:
                CartId = created.CartId;
                CustomerId = created.CustomerId;
                IsCreated = true;
                break;
        }
    }
}
```

✅ これで「イベントが状態を作る」骨格は完成です🎉

---

# 18.5 実装：ユースケース（CreateCart）を通す📮➡️📜➡️📦

ここは「アプリ層（UseCase）」の仕事です😊
集約はルールを守るだけ、永続化は EventStore がやるだけ、に分けるとスッキリします✨

## 18.5.1 コマンド定義📮

```csharp
namespace MyEs.Application;

public sealed record CreateCart(
    Guid CartId,
    Guid CustomerId
);
```

---

## 18.5.2 EventStore（前章までの最小）との接続イメージ📦

前章の実装に合わせて、必要な形だけ置きます（中身はあなたの実装に合わせてOK）😊

```csharp
namespace MyEs.Infrastructure;

public sealed record StoredEvent(long Version, MyEs.Domain.IDomainEvent Event);

public interface IEventStore
{
    IReadOnlyList<StoredEvent> ReadStream(string streamId);
    void AppendToStream(string streamId, long expectedVersion, IReadOnlyList<MyEs.Domain.IDomainEvent> newEvents);
}
```

---

## 18.5.3 UseCase（Load → Decide → Append を固定）✅

```csharp
using MyEs.Domain;
using MyEs.Infrastructure;

namespace MyEs.Application;

public sealed class CartUseCase
{
    private readonly IEventStore _store;

    public CartUseCase(IEventStore store)
    {
        _store = store;
    }

    public void Handle(CreateCart command, DateTimeOffset nowUtc)
    {
        var streamId = StreamIdOf(command.CartId);

        // 1) Load
        var stored = _store.ReadStream(streamId);

        // 2) Rehydrate
        var history = stored.Select(x => x.Event);
        var cart = ShoppingCart.Rehydrate(history);

        // 3) Decide
        var newEvents = cart.DecideCreate(command.CartId, command.CustomerId, nowUtc);
        if (newEvents.Count == 0)
        {
            // 本当は「すでに作成済み」などのエラーにしたい（次の章で強化💪）
            return;
        }

        // 4) Append（新規作成なので expectedVersion は 0 を想定）
        var expectedVersion = stored.Count; // 空なら 0
        _store.AppendToStream(streamId, expectedVersion, newEvents);
    }

    private static string StreamIdOf(Guid cartId) => $"cart-{cartId:N}";
}
```

🎉 これで、CreateCart を投げたら CartCreated が保存されます！

---

# 18.6 動作確認：作成 → 読み → 復元 🔁✅

「ほんとに復元できる？」をここで必ず確認します😊✨
（テストは次の章でちゃんとやるけど、今は目で見て安心するのが大事💖）

## 確認用コード（例：簡易コンソール）👀

```csharp
using MyEs.Application;
using MyEs.Infrastructure;

var store = new InMemoryEventStore(); // あなたの実装
var useCase = new CartUseCase(store);

var cartId = Guid.NewGuid();
var customerId = Guid.NewGuid();

useCase.Handle(new CreateCart(cartId, customerId), DateTimeOffset.UtcNow);

// いったんイベントを読む
var streamId = $"cart-{cartId:N}";
var stored = store.ReadStream(streamId);
Console.WriteLine($"events: {stored.Count}");
Console.WriteLine(stored[0].Event.GetType().Name);

// 復元してみる
var history = stored.Select(x => x.Event);
var cart = MyEs.Domain.ShoppingCart.Rehydrate(history);
Console.WriteLine($"IsCreated: {cart.IsCreated}");
Console.WriteLine($"CartId: {cart.CartId}");
```

期待する出力イメージ👇✨

* events: 1
* CartCreated
* IsCreated: True

---

# 18.7 よくあるミス集（ここで潰す）💥😵‍💫➡️😊

## ミス1：作成なのに「更新っぽいイベント名」にしちゃう

* 例：CartCreateRequested（命令っぽい）🙅‍♀️
* 正：CartCreated（起きた事実）✅

## ミス2：イベントに余計な情報を詰めすぎる🍱💦

* 画面表示用の合成値、将来変わる分類名、などを payload に入れると破壊力が高い😇
* 迷ったら「事実だけ」に寄せるのが安全✨

## ミス3：Apply の書き忘れ（復元でバグる）🫠

* Decide でイベントを作ったら、Apply に必ず対応を作る✅
* Apply 漏れは「イベントはあるのに状態が変わらない」地獄🥶

---

# 18.8 ミニ演習（今日のゴール）📝🎀

## 演習A：作成系をもう1個増やす🆕

* 例：CartOwnerChanged を作ってみる（※本当は作成直後に固定でもOK）
* または、別ドメイン（ToDoListCreated など）でもOK😊

## 演習B：不変条件を1つ追加する🛡️

* 例：CustomerId が空なら作成できない
* 例：CartId が空なら作成できない

---

# 18.9 AI拡張（GitHub Copilot / OpenAI Codex）で速く作るコツ🤖✨

## 使いやすいお願いテンプレ（コピペ用）📌

* 「C# で ShoppingCart 集約を作りたい。CartCreated イベント、Rehydrate、DecideCreate、Apply を含めて。イベントは record、集約は状態と不変条件（作成済み禁止）を持つ。無駄な責務を入れないで。短く、読みやすく。」

## AIにやらせてから、人間が必ず見る場所👀✅

* イベント名が過去形になってる？
* payload が “事実” だけ？
* Apply が漏れてない？
* UseCase が Load → Decide → Append の順番を守ってる？

---

# 18.10 まとめ（この章で手に入れた型）🎁😊✨

* Created 系イベントを作って、**作成ユースケースが通った**🎉
* イベントが積まれ、そこから **復元できる** ことを確認できた🔁✅
* 「Load → Decide → Append」の型が、作成でもブレないと分かった📮📜📦

---

## 参考（最新ドキュメント）📚✨

* C# 14 の新機能まとめ（公式） ([Microsoft Learn][3])
* .NET 10 の新機能（公式） ([Microsoft Learn][4])
* Visual Studio 2026 の .NET 10 / C# 14 サポート（公式） ([Microsoft Learn][1])
* System.Text.Json の .NET 10 互換性変更（予約名チェック） ([Microsoft Learn][2])

[1]: https://learn.microsoft.com/ja-jp/visualstudio/releases/2026/release-notes?utm_source=chatgpt.com "Visual Studio 2026 リリース ノート"
[2]: https://learn.microsoft.com/en-us/dotnet/core/compatibility/serialization/10/property-name-validation?utm_source=chatgpt.com "System.Text.Json checks for property name conflicts - .NET"
[3]: https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14?utm_source=chatgpt.com "What's new in C# 14"
[4]: https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/overview?utm_source=chatgpt.com "What's new in .NET 10"
