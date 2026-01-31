# 第19章：ユースケース実装②（更新系）🔧✨

## この章でできるようになること 🎯💡

更新（= 既に存在する集約の状態を変える）を、**コマンド → 新イベント**としてきれいに実装できるようになります😊✨
この章では「更新の代表格」を2〜3個つくって、**更新イベントの粒度**も体で覚えます🧠⚖️

---

# 1. 更新系ってなにが難しいの？😵‍💫➡️😊

更新系が難しく感じる理由はだいたいこの3つ👇

1. **同じ更新でもパターンが多い**（追加・削除・数量変更・属性変更…）🧩
2. **イベント名がブレやすい**（でかすぎ・細かすぎ問題）⚖️
3. **不変条件（ルール）をどこで守るか迷う**🛡️

でも安心してね🌸
# 第16章の型（Load → Decide → Append）をそのまま使えば、更新もキレイにハマります✅

---

## 2. 今回の題材（例）：ショッピングカート🛒✨

第18章で「作成系（CartCreated）」をやった前提で、更新系を足します😊
ここでは更新コマンドを2つ（＋おまけ1つ）つくるよ👇

* ✅ **AddItem**：商品を追加する ➕📦
* ✅ **ChangeQuantity**：数量を変更する 🔢🔁
* ⭐（おまけ）**RemoveItem**：商品を削除する 🗑️

---

## 3. 更新イベントの設計（まずここが命！）🧠🔥

### 3.1 イベント命名（過去形）⏳✅

イベントは「やったこと（事実）」なので、**過去形**が基本✨

* `ItemAddedToCart`（カートに商品が追加された）
* `ItemQuantityChanged`（数量が変更された）
* `ItemRemovedFromCart`（商品が削除された）

### 3.2 粒度（でかすぎ vs ちょうどいい）⚖️👀

ありがちなNG👇

* ❌ `CartUpdated`（でかすぎて、何が起きたか分からない😇）
* ❌ `CartItemQuantityIncrementedBy1`（細かすぎてイベント爆発😵）

おすすめは「画面の操作」じゃなくて「ドメインの意味」で切ること😊✨
例：数量変更は「+1」「-1」ではなく「**数量がXになった**」の方が後々ラクなことが多いよ🔧

---

## 4. 不変条件（更新系の守りどころ）🛡️🧷

この章のカート例で、最低限のルールを決めよう👇（シンプルでOK！）

* 数量は **1以上**（0やマイナスは禁止）🙅‍♀️
* 追加するSKUは空文字禁止🙅‍♀️
* 変更対象の商品が存在しないなら変更できない🙅‍♀️
* （おまけ）削除対象が存在しないなら削除できない🙅‍♀️

このルールは **Decideの中で弾く** のが基本だよ✅

---

## 5. 実装：Domain（イベント・コマンド・集約）🧱✨

ここからは「そのまま貼って動く」寄りのサンプルでいきます😊
（イベントストアは第13〜17章の最小実装を使う想定📦）

### 5.1 イベント定義 📜✨

```csharp
public interface IDomainEvent;

public sealed record CartCreated(Guid CartId) : IDomainEvent;

public sealed record ItemAddedToCart(Guid CartId, string Sku, int Quantity) : IDomainEvent;

public sealed record ItemQuantityChanged(Guid CartId, string Sku, int NewQuantity) : IDomainEvent;

public sealed record ItemRemovedFromCart(Guid CartId, string Sku) : IDomainEvent;
```

ポイント💡

* 更新系は「差分」を入れるか「結果（NewQuantity）」を入れるか迷うけど、初心者コースでは **結果（NewQuantity）**がおすすめ😊

  * リプレイしてもブレない✅
  * 途中の計算が減る✅

---

### 5.2 コマンド定義 📮✨

```csharp
public interface ICommand;

public sealed record CreateCart(Guid CartId) : ICommand;

public sealed record AddItem(Guid CartId, string Sku, int Quantity) : ICommand;

public sealed record ChangeQuantity(Guid CartId, string Sku, int NewQuantity) : ICommand;

public sealed record RemoveItem(Guid CartId, string Sku) : ICommand;
```

---

### 5.3 集約（Cart Aggregate）🧺✨

```csharp
public sealed class Cart
{
    private readonly Dictionary<string, int> _items = new();

    public Guid Id { get; private set; }
    public bool IsCreated { get; private set; }

    // Rehydrate 用（外から new させない）
    private Cart() { }

    public static Cart Rehydrate(IEnumerable<IDomainEvent> history)
    {
        var cart = new Cart();
        foreach (var e in history)
        {
            cart.Apply(e);
        }
        return cart;
    }

    // Decide：コマンド -> 新イベント（ここで不変条件を守る）
    public IReadOnlyList<IDomainEvent> Decide(ICommand command) =>
        command switch
        {
            CreateCart c        => DecideCreate(c),
            AddItem c           => DecideAddItem(c),
            ChangeQuantity c    => DecideChangeQuantity(c),
            RemoveItem c        => DecideRemoveItem(c),
            _ => throw new NotSupportedException($"Unknown command: {command.GetType().Name}")
        };

    private IReadOnlyList<IDomainEvent> DecideCreate(CreateCart c)
    {
        if (IsCreated) throw new InvalidOperationException("Cart is already created.");
        if (c.CartId == Guid.Empty) throw new InvalidOperationException("CartId is required.");

        return new IDomainEvent[]
        {
            new CartCreated(c.CartId)
        };
    }

    private IReadOnlyList<IDomainEvent> DecideAddItem(AddItem c)
    {
        EnsureCreated();
        EnsureSku(c.Sku);
        if (c.Quantity <= 0) throw new InvalidOperationException("Quantity must be >= 1.");

        // ここは方針が2つあるよ👇
        // A) 同じSKUなら「追加」じゃなく「数量変更」に統一する
        // B) 追加は追加、変更は変更（イベントを分ける）
        // 今回は分かりやすさ優先で B にする😊

        return new IDomainEvent[]
        {
            new ItemAddedToCart(Id, c.Sku, c.Quantity)
        };
    }

    private IReadOnlyList<IDomainEvent> DecideChangeQuantity(ChangeQuantity c)
    {
        EnsureCreated();
        EnsureSku(c.Sku);
        if (c.NewQuantity <= 0) throw new InvalidOperationException("NewQuantity must be >= 1.");

        if (!_items.ContainsKey(c.Sku))
            throw new InvalidOperationException("Item does not exist in cart.");

        return new IDomainEvent[]
        {
            new ItemQuantityChanged(Id, c.Sku, c.NewQuantity)
        };
    }

    private IReadOnlyList<IDomainEvent> DecideRemoveItem(RemoveItem c)
    {
        EnsureCreated();
        EnsureSku(c.Sku);

        if (!_items.ContainsKey(c.Sku))
            throw new InvalidOperationException("Item does not exist in cart.");

        return new IDomainEvent[]
        {
            new ItemRemovedFromCart(Id, c.Sku)
        };
    }

    // Apply：イベント -> 状態更新（ここはルール判定しない）
    private void Apply(IDomainEvent e)
    {
        switch (e)
        {
            case CartCreated x:
                Id = x.CartId;
                IsCreated = true;
                break;

            case ItemAddedToCart x:
                if (_items.TryGetValue(x.Sku, out var current))
                    _items[x.Sku] = current + x.Quantity;
                else
                    _items[x.Sku] = x.Quantity;
                break;

            case ItemQuantityChanged x:
                _items[x.Sku] = x.NewQuantity;
                break;

            case ItemRemovedFromCart x:
                _items.Remove(x.Sku);
                break;

            default:
                throw new NotSupportedException($"Unknown event: {e.GetType().Name}");
        }
    }

    private void EnsureCreated()
    {
        if (!IsCreated) throw new InvalidOperationException("Cart is not created.");
    }

    private static void EnsureSku(string sku)
    {
        if (string.IsNullOrWhiteSpace(sku))
            throw new InvalidOperationException("Sku is required.");
    }

    // デバッグ用（状態を見たいとき便利😊）
    public IReadOnlyDictionary<string, int> GetItems() => _items;
}
```

ここ大事😊✨

* **Decide**：不変条件（ルール）を守る場所🛡️
* **Apply**：イベントを状態に反映するだけ（判定はしない）🔁

---

## 6. 実装：Application（ハンドラ）📮➡️📦

第16章の型をそのまま使うよ✅
イベントストア側は「ReadStream」「Append(streamId, expectedVersion, events)」がある想定📦

```csharp
public sealed class CartCommandHandler
{
    private readonly IEventStore _store;

    public CartCommandHandler(IEventStore store)
    {
        _store = store;
    }

    public void Handle(ICommand command)
    {
        var cartId = command switch
        {
            CreateCart c => c.CartId,
            AddItem c => c.CartId,
            ChangeQuantity c => c.CartId,
            RemoveItem c => c.CartId,
            _ => throw new NotSupportedException()
        };

        var streamId = $"cart-{cartId:N}";

        var history = _store.ReadStream(streamId); // IEnumerable<IDomainEvent>
        var cart = Cart.Rehydrate(history);

        var newEvents = cart.Decide(command);

        var expectedVersion = history.Count(); // ※第14章のversion管理の形に合わせて調整してOK
        _store.Append(streamId, expectedVersion, newEvents);
    }
}
```

※ `history.Count()` は IEnumerable を2回なめがちなので、実務なら List にしてから使うのが安全だよ😊（この章では分かりやすさ優先✨）

---

## 7. ミニ演習（更新コマンド2つを通す）🧪✨

### 演習A：AddItemを通す➕📦

1. `CreateCart` する
2. `AddItem(SKU="APPLE", Quantity=2)` を投げる
3. イベントストリームを読んで、最後に `ItemAddedToCart` が追加されているか確認✅

### 演習B：ChangeQuantityを通す🔢🔁

1. すでに `APPLE` が入っている状態から
2. `ChangeQuantity(SKU="APPLE", NewQuantity=5)` を投げる
3. `ItemQuantityChanged` が積まれるか確認✅

### 演習C：失敗パターンを作る🙅‍♀️💥

* `NewQuantity=0` を投げて、ちゃんと弾かれるか確認
* 存在しないSKUを変更して弾かれるか確認

---

## 8. “更新イベントの粒度診断” ミニチェック⚖️🔍

更新イベントを作ったら、これを自分に質問してみてね😊

* 「**何が起きたか**、イベント名だけで分かる？」👀
* 「後から見た人が、**なぜこのイベントが必要か**説明できる？」🗣️
* 「将来 “監査ログ” に並んだ時に、**人間が読める？**」📜
* 「`CartUpdated` みたいに“便利そうで意味が薄い”イベントになってない？」😇

---

## 9. AI活用（Copilot / Codex）🤖✨

### 9.1 まずはイベント案を出してもらう🧠💬

プロンプト例👇（そのまま貼ってOK）

```text
ショッピングカートのイベントソーシングを学習中です。
更新系のユースケースとして「商品追加」「数量変更」「商品削除」を実装したいです。

条件:
- イベント名は過去形で、何が起きたか分かること
- payloadは最小限（入れすぎない）
- 不変条件（数量は1以上、SKU空は禁止、存在しない商品は変更/削除できない）を守る

提案して:
1) コマンド名
2) イベント名
3) それぞれのpayload設計
4) 粒度がでかすぎ/細かすぎのNG例も
```

### 9.2 出てきた案の“手直しポイント”✍️✨

AIがよくやりがち👇

* payloadに **画面表示用の情報** を入れようとする（やりすぎ🍱💦）
* `CartUpdated` みたいな **万能イベント** を作りたがる（危険⚠️）

だから、最後はあなたがこの方針で整えると勝ち😊

* 「ドメイン的に意味がある？」
* 「後から読める？」
* 「Applyが単純？」

---

## 10. まとめ（この章のゴール確認）✅🎉

この章で押さえたこと👇

* 更新系も **Load → Decide → Append** の型で迷子にならない📮✅
* **Decideで不変条件**、**Applyで状態更新** を徹底🛡️🔁
* 更新イベントは「意味が分かる名前」と「ちょうどいい粒度」⚖️✨

次章（第20章）では、この更新も含めて **Given-When-Then** でテストを書いて「怖くない」状態にしていくよ🧪🌸

---

### 参考（2026年時点の開発スタックの根拠）📚✨

* .NET 10 は LTS で、サポート期間や入手について公式に案内されています。([Microsoft for Developers][1])
* .NET 10 の新機能概要（ASP.NET Core 10 など）も公式ドキュメントにまとまっています。([Microsoft Learn][2])
* C# 14 は .NET 10 SDK / Visual Studio 2026 で試せる旨が公式に明記されています。([Microsoft Learn][3])
* Visual Studio 2026 と .NET 10 で F5 起動が最大30%高速化、などの改善がリリースノートにあります。([Microsoft Learn][4])
* xUnit v3 側も .NET 10 ターゲットなどの情報をリリースノートとして公開しています（テスト章で活用しやすいです）。([xunit.net][5])

[1]: https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/?utm_source=chatgpt.com "Announcing .NET 10"
[2]: https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/overview?utm_source=chatgpt.com "What's new in .NET 10"
[3]: https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14?utm_source=chatgpt.com "What's new in C# 14"
[4]: https://learn.microsoft.com/ja-jp/visualstudio/releases/2026/release-notes?utm_source=chatgpt.com "Visual Studio 2026 リリース ノート"
[5]: https://xunit.net/releases/v3/3.1.0?utm_source=chatgpt.com "Core Framework v3 3.1.0 [2025 September 27]"
