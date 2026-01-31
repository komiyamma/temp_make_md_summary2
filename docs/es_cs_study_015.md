# 第15章：復元（Rehydrate）入門：Applyで状態を作る🔁🧠

## この章でできるようになること🎯✨

* イベントの列（履歴）から、**いまの状態**を復元できる🔁✅
* `Apply` の役割（イベント → 状態の反映）を説明できる🗣️💡
* 「`Apply` 漏れ」で起きるバグを体験し、**防ぐ型**を持てる🛡️🧪

---

# 1) Rehydrateってなに？（超やさしく）🌸

イベントソーシングでは、データを「状態」じゃなくて「出来事（イベント）」として積みます📚✨
だから、アプリが「いまどうなってる？」を知りたいときは…

* **過去のイベントを順番に読み**
* **1個ずつ状態に反映（Apply）**して
* **現在の状態を作る**

これが **Rehydrate（復元）** です🔁🧠

---

# 2) 今日の主役：Apply（反映）って何するの？🍱🏷️

`Apply` は「イベントに書かれてる事実を、状態に反映する」だけの係です🙌
ここで大事な感覚👇

* `Apply` は **判断しない**（基本）🧘‍♀️
* ルール違反を弾く（不変条件チェック）は、次の章以降の「Decide」側の役目🛡️
* でも `Apply` 漏れがあると **復元が間違う**（コワい😱）

---

# 3) ざっくり図でイメージ🎬✨

```text
(イベントストリーム)
  v0: CartCreated
  v1: ItemAdded(Apple, 2)
  v2: ItemAdded(Banana, 1)
  v3: ItemRemoved(Apple)

        ↓ Rehydrate（順に読む）
空のカート ──Apply──> 状態更新 ──Apply──> 状態更新 ──Apply──> 今の状態 ✅
```

---

# 4) 最小コード：カートを復元してみよう🛒🔁

ここでは「カート（ShoppingCart）」を例にします😊
イベントは最小3つに絞ります✂️✨

* `CartCreated`
* `ItemAdded`
* `ItemRemoved`

## 4-1) イベント型を用意する📦

```csharp
using System;
using System.Collections.Generic;

public interface IEvent
{
    DateTimeOffset OccurredAt { get; }
}

public sealed record CartCreated(Guid CartId, DateTimeOffset OccurredAt) : IEvent;

public sealed record ItemAdded(
    Guid CartId,
    string Sku,
    int Quantity,
    DateTimeOffset OccurredAt
) : IEvent;

public sealed record ItemRemoved(
    Guid CartId,
    string Sku,
    DateTimeOffset OccurredAt
) : IEvent;
```

## 4-2) 状態（State）と Apply を作る🧠✨

「復元」は、まず **空の状態** を作って、イベントを順に `Apply` します🔁

```csharp
using System;
using System.Collections.Generic;

public sealed class ShoppingCart
{
    public Guid Id { get; private set; }
    public bool IsCreated { get; private set; }

    // SKU -> 数量
    public Dictionary<string, int> Items { get; } = new();

    // Rehydrateの入口（ファクトリ）
    public static ShoppingCart Rehydrate(IEnumerable<IEvent> history)
    {
        var cart = new ShoppingCart();

        foreach (var e in history)
        {
            cart.Apply(e);
        }

        return cart;
    }

    private void Apply(IEvent e)
    {
        switch (e)
        {
            case CartCreated created:
                Id = created.CartId;
                IsCreated = true;
                break;

            case ItemAdded added:
                if (!Items.TryGetValue(added.Sku, out var current))
                {
                    current = 0;
                }
                Items[added.Sku] = current + added.Quantity;
                break;

            case ItemRemoved removed:
                Items.Remove(removed.Sku);
                break;

            // ★ここが超重要：知らないイベントが来たら「気づける」ようにする
            default:
                throw new NotSupportedException($"Unknown event: {e.GetType().Name}");
        }
    }
}
```

---

# 5) ミニ演習：イベント3つで復元してみよう🎬🛒

## 5-1) 手で「いまの状態」を当ててみる📝✨

イベントがこれ👇だったら、最終的な `Items` はどうなる？😊

1. `CartCreated`
2. `ItemAdded(Sku="Apple", Quantity=2)`
3. `ItemAdded(Sku="Banana", Quantity=1)`

答え：

* Apple = 2 🍎
* Banana = 1 🍌

## 5-2) 実際に動かしてみる🚀

```csharp
using System;
using System.Collections.Generic;

var cartId = Guid.NewGuid();
var now = DateTimeOffset.UtcNow;

var history = new List<IEvent>
{
    new CartCreated(cartId, now),
    new ItemAdded(cartId, "Apple", 2, now.AddMinutes(1)),
    new ItemAdded(cartId, "Banana", 1, now.AddMinutes(2)),
};

var cart = ShoppingCart.Rehydrate(history);

Console.WriteLine(cart.Id);
Console.WriteLine(cart.IsCreated);
Console.WriteLine($"Apple = {cart.Items["Apple"]}");
Console.WriteLine($"Banana = {cart.Items["Banana"]}");
```

---

# 6) こわい話：Apply漏れで何が起きる？😱🕳️

イベントソーシングでありがちな事故がこれ👇

* 新しいイベントを追加した✅
* でも `Apply` を更新し忘れた❌
* 復元した状態が **静かに壊れる**（または例外で落ちる）💥

さっきのコードは `default: throw` があるので、**落ちて気づける**タイプです✅
これはかなり安全です🛡️✨（“静かに壊れる”より100倍マシ）

---

# 7) Apply漏れを減らす「型」3つ🧰🛡️

## 型①：`Apply` を1か所に集める📍

「あちこちで状態更新」すると漏れやすいです😵‍💫
**状態更新は `Apply` に寄せる**のが基本形✅

## 型②：知らないイベントは落として気づく🚨

`default: throw` を入れて、未知イベントを早期発見🔎✨
（読みモデルのProjection側も同じ発想でOK）

## 型③：復元テストでガードする🧪✅

「復元したらこうなる」がテストにあれば、`Apply` 漏れがすぐバレます👏
テストフレームワークは xUnit などがよく使われます。([xUnit.net][1])

---

# 8) テストして安心しよう（復元テスト）🧪🌸

「イベント列 → 状態」が合ってるかをテストします😊

```csharp
using System;
using System.Collections.Generic;
using Xunit;

public class ShoppingCartRehydrateTests
{
    [Fact]
    public void Rehydrate_builds_state_from_events()
    {
        var cartId = Guid.NewGuid();
        var t0 = DateTimeOffset.UtcNow;

        var history = new List<IEvent>
        {
            new CartCreated(cartId, t0),
            new ItemAdded(cartId, "Apple", 2, t0.AddMinutes(1)),
            new ItemAdded(cartId, "Banana", 1, t0.AddMinutes(2)),
            new ItemRemoved(cartId, "Apple", t0.AddMinutes(3)),
        };

        var cart = ShoppingCart.Rehydrate(history);

        Assert.True(cart.IsCreated);
        Assert.Equal(cartId, cart.Id);

        Assert.False(cart.Items.ContainsKey("Apple"));
        Assert.Equal(1, cart.Items["Banana"]);
    }
}
```

---

# 9) AI活用：Apply漏れチェックを“儀式化”しよう🤖✅✨

Copilot / Codex みたいなAIには、**お願いの形（テンプレ）**を固定すると強いです📌

## 9-1) 追加イベントを作るときのお願い（例）🧾

```text
以下のC#コードに、新しいイベント `ItemQuantityChanged` を追加して。
やってほしいこと：
1) IEvent record を追加
2) ShoppingCart.Apply の switch に処理を追加
3) Rehydrateテストを1本追加（成功ケース）
制約：
- 例外メッセージは簡潔に
- Items辞書の更新ロジックは既存と整合
```

## 9-2) AIレビュー観点（Apply漏れ対策）🔍

AIにこれをチェックさせると便利👇

* 追加したイベントが `Apply` に反映されてる？✅
* `default: throw` が残ってる？✅
* 復元テストが増えてる？✅
* `Apply` が判断ロジックを持ちすぎてない？（やりすぎ注意）⚠️

---

# 10) まとめ🎁✨

* **Rehydrate = イベント列から状態を作る**🔁
* **Apply = イベントの事実を状態に反映する**🧠
* `Apply` 漏れは危険なので、

  * 未知イベントは落として気づく🚨
  * 復元テストで守る🧪
    がとても大事🛡️✨

---

# 参考（2026の最新ドキュメント）📚🔗

* .NET 10 の新機能まとめ（公式）([Microsoft Learn][2])
* C# 14 の新機能まとめ（公式）([Microsoft Learn][3])
* Visual Studio 2026 のリリースノート（公式）([Microsoft Learn][4])

[1]: https://xunit.net/?utm_source=chatgpt.com "xUnit.net: Home"
[2]: https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/overview?utm_source=chatgpt.com "What's new in .NET 10"
[3]: https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14?utm_source=chatgpt.com "What's new in C# 14"
[4]: https://learn.microsoft.com/ja-jp/visualstudio/releases/2026/release-notes?utm_source=chatgpt.com "Visual Studio 2026 リリース ノート"
