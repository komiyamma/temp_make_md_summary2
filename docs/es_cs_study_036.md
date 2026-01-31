# 第36章：卒業制作（ミニプロダクト完成）🎓🎉

## 1) 卒業制作のゴール（提出物）📦✨

この章では、ここまで作ってきた題材（例：カート／家計簿／ToDoなど）を **「小さいけど筋が通ってるミニプロダクト」** に仕上げます😊💪

### 必須要件（最低ライン）✅

* イベント保存（永続化）🗄️
* 復元（Rehydrate）🔁
* Projection 1つ（読みモデル）🔎
* Given-When-Then テスト数本 🧪
* **競合（expectedVersion）** もしくは **冪等性** のどちらか1つ
  → ここでは **競合（expectedVersion）** を必須にするよ🔒⚔️

### 仕上げで「動いてる感」を出す要素（おすすめ）✨

* Minimal API で操作できる（HTTP）🌐
* OpenAPI/Swagger で叩ける🧾
* README がある📘
* （できたら）Projection 再構築ボタン／エンドポイント🔁

> ちなみに .NET 10 は LTS で、2028年11月までサポートされるよ📅✨ ([Microsoft for Developers][1])
> C# 14 は .NET 10 でサポートされてるよ🧠✨ ([Microsoft Learn][2])
> ASP.NET Core 10 / Minimal API 周りも強化されてるよ🚀 ([Microsoft Learn][3])

---

## 2) 今回のミニプロダクト例：ショッピングカート🛒✨

題材は自由だけど、説明は「カート」で通すね😊（あなたの題材に置き換えてOK！）

### ユースケース（最小）🧩

* カートを作る🆕
* 商品を追加する➕
* 商品を減らす／削除する➖
* カートの内容を見る👀（Projection）
* 競合を検知して保存を止める🛑（expectedVersion）

---

## 3) “完成形”の構成（わかりやすい最小）🏗️✨

「分けすぎると迷子」になりやすいので、**これくらいがちょうどいい**🙆‍♀️

* `Cart.Domain`（イベント・集約・不変条件）🧠
* `Cart.Api`（HTTP + アプリ層 + SQLite）🌐🗄️
* `Cart.Tests`（Given-When-Then）🧪

ASP.NET Core 10 の変更点や改善は “何となく知っておく” 程度でOK🙆‍♀️（使い方は今まで通りでいける） ([Microsoft Learn][4])

---

## 4) SQLite テーブル（イベント + Projection）🗃️✨

### 4.1 Events テーブル（イベントストア本体）📼

要点はこれ👇

* `stream_id`：集約ID（カートID）
* `version`：連番（超重要）🔢
* `type`：イベント種類
* `data_json/meta_json`：中身
* `UNIQUE(stream_id, version)`：**順番が壊れない守り**🛡️

```sql
CREATE TABLE IF NOT EXISTS events (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  stream_id    TEXT    NOT NULL,
  version      INTEGER NOT NULL,
  type         TEXT    NOT NULL,
  data_json    TEXT    NOT NULL,
  meta_json    TEXT    NOT NULL,
  occurred_utc TEXT    NOT NULL,
  UNIQUE(stream_id, version)
);

CREATE INDEX IF NOT EXISTS ix_events_stream ON events(stream_id);
```

### 4.2 Projection（読む用）テーブル🔎

最小だと「カートの現在の内容」が見えればOK😊

```sql
CREATE TABLE IF NOT EXISTS cart_items_projection (
  cart_id    TEXT NOT NULL,
  product_id TEXT NOT NULL,
  quantity   INTEGER NOT NULL,
  PRIMARY KEY (cart_id, product_id)
);

CREATE TABLE IF NOT EXISTS cart_summary_projection (
  cart_id      TEXT PRIMARY KEY,
  total_items  INTEGER NOT NULL,
  updated_utc  TEXT NOT NULL
);
```

---

## 5) ドメイン（イベント・集約・不変条件）🧠🧷

### 5.1 イベント（過去形）📜

```csharp
public interface IEvent
{
    DateTimeOffset OccurredUtc { get; }
}

public sealed record CartCreated(
    string CartId,
    DateTimeOffset OccurredUtc
) : IEvent;

public sealed record ItemAdded(
    string CartId,
    string ProductId,
    int Quantity,
    DateTimeOffset OccurredUtc
) : IEvent;

public sealed record ItemRemoved(
    string CartId,
    string ProductId,
    DateTimeOffset OccurredUtc
) : IEvent;
```

### 5.2 集約（Apply と Decide を分ける）🔁📮

* `Apply`：イベントを状態に反映する（復元で使う）🔁
* `Decide`：コマンドを受けて「新イベント」を作る（不変条件チェック）🛡️

```csharp
public sealed class Cart
{
    private readonly Dictionary<string, int> _items = new();

    public string Id { get; private set; } = "";
    public bool IsCreated { get; private set; }

    // ====== 復元用 ======
    public void Apply(IEvent ev)
    {
        switch (ev)
        {
            case CartCreated e:
                Id = e.CartId;
                IsCreated = true;
                break;

            case ItemAdded e:
                if (_items.TryGetValue(e.ProductId, out var q))
                    _items[e.ProductId] = q + e.Quantity;
                else
                    _items[e.ProductId] = e.Quantity;
                break;

            case ItemRemoved e:
                _items.Remove(e.ProductId);
                break;

            default:
                throw new InvalidOperationException($"Unknown event: {ev.GetType().Name}");
        }
    }

    // ====== コマンド処理（Decide） ======
    public static IReadOnlyList<IEvent> DecideCreate(string cartId, DateTimeOffset nowUtc)
    {
        if (string.IsNullOrWhiteSpace(cartId))
            throw new ArgumentException("cartId is required");

        return new IEvent[] { new CartCreated(cartId, nowUtc) };
    }

    public IReadOnlyList<IEvent> DecideAddItem(string productId, int quantity, DateTimeOffset nowUtc)
    {
        if (!IsCreated) throw new InvalidOperationException("Cart not created");
        if (string.IsNullOrWhiteSpace(productId)) throw new ArgumentException("productId is required");
        if (quantity <= 0) throw new ArgumentOutOfRangeException(nameof(quantity), "quantity must be > 0");

        return new IEvent[] { new ItemAdded(Id, productId, quantity, nowUtc) };
    }

    public IReadOnlyList<IEvent> DecideRemoveItem(string productId, DateTimeOffset nowUtc)
    {
        if (!IsCreated) throw new InvalidOperationException("Cart not created");
        if (!_items.ContainsKey(productId)) throw new InvalidOperationException("Item not found");

        return new IEvent[] { new ItemRemoved(Id, productId, nowUtc) };
    }

    public IReadOnlyDictionary<string, int> SnapshotItems() => _items;
}
```

> エラーを `throw` にしてるけど、前の章で Result 型にしてるなら **同じところを Result に置き換えればOK**😊（筋が通ってれば勝ち！）✨

---

## 6) 復元（Rehydrate）と expectedVersion（競合対策）🔁🔒

### 6.1 まず「読み出して復元」📼➡️🧠

流れは固定👇

1. DBからイベント列を読む
2. `Cart` を new
3. 上から `Apply`
4. 現在状態ができる✨

```csharp
public static Cart Rehydrate(IEnumerable<IEvent> events)
{
    var cart = new Cart();
    foreach (var ev in events)
        cart.Apply(ev);
    return cart;
}
```

### 6.2 expectedVersion ってなに？🤔

「保存するとき、最後に見た version と同じなら保存していいよ」っていう約束😊
ズレてたら **誰かが先に更新してる** ので止める🛑

---

## 7) EventStore（SQLite）最小実装🗄️✨

### 7.1 Append（expectedVersion 付き）📌

ポイント👇

* `MAX(version)` を見て期待値と一致するかチェック👀
* 一致したら `version+1` で順番に INSERT
* トランザクションで守る🔐

```csharp
public sealed class ConcurrencyException : Exception
{
    public ConcurrencyException(string message) : base(message) { }
}

public sealed class SqliteEventStore
{
    private readonly string _connectionString;

    public SqliteEventStore(string connectionString) => _connectionString = connectionString;

    public async Task<(List<IEvent> Events, int LastVersion)> ReadStreamAsync(string streamId)
    {
        using var con = new Microsoft.Data.Sqlite.SqliteConnection(_connectionString);
        await con.OpenAsync();

        var cmd = con.CreateCommand();
        cmd.CommandText = """
            SELECT version, type, data_json, meta_json, occurred_utc
            FROM events
            WHERE stream_id = $streamId
            ORDER BY version ASC
        """;
        cmd.Parameters.AddWithValue("$streamId", streamId);

        var events = new List<IEvent>();
        var lastVersion = 0;

        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            lastVersion = reader.GetInt32(0);
            var type = reader.GetString(1);
            var dataJson = reader.GetString(2);
            var occurred = DateTimeOffset.Parse(reader.GetString(4));

            events.Add(EventJson.Deserialize(type, dataJson, occurred));
        }

        return (events, lastVersion);
    }

    public async Task AppendAsync(string streamId, int expectedVersion, IReadOnlyList<IEvent> newEvents)
    {
        using var con = new Microsoft.Data.Sqlite.SqliteConnection(_connectionString);
        await con.OpenAsync();

        using var tx = con.BeginTransaction();

        // 現在の最後のversionを取る
        var getCmd = con.CreateCommand();
        getCmd.Transaction = tx;
        getCmd.CommandText = "SELECT COALESCE(MAX(version), 0) FROM events WHERE stream_id = $streamId";
        getCmd.Parameters.AddWithValue("$streamId", streamId);

        var current = Convert.ToInt32(await getCmd.ExecuteScalarAsync());

        if (current != expectedVersion)
            throw new ConcurrencyException($"Concurrency! expected={expectedVersion} actual={current}");

        var next = current;
        foreach (var ev in newEvents)
        {
            next++;

            var (type, dataJson, metaJson, occurredUtc) = EventJson.Serialize(ev);

            var ins = con.CreateCommand();
            ins.Transaction = tx;
            ins.CommandText = """
                INSERT INTO events(stream_id, version, type, data_json, meta_json, occurred_utc)
                VALUES($streamId, $version, $type, $data, $meta, $occurred)
            """;
            ins.Parameters.AddWithValue("$streamId", streamId);
            ins.Parameters.AddWithValue("$version", next);
            ins.Parameters.AddWithValue("$type", type);
            ins.Parameters.AddWithValue("$data", dataJson);
            ins.Parameters.AddWithValue("$meta", metaJson);
            ins.Parameters.AddWithValue("$occurred", occurredUtc.ToString("O"));

            await ins.ExecuteNonQueryAsync();
        }

        await tx.CommitAsync();
    }
}
```

---

## 8) イベントの JSON（type と data の往復）🧾🔁

### 8.1 シリアライズ／デシリアライズ担当を1箇所に集める🧹

```csharp
using System.Text.Json;

public static class EventJson
{
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);

    public static (string Type, string DataJson, string MetaJson, DateTimeOffset OccurredUtc) Serialize(IEvent ev)
    {
        var type = ev.GetType().Name;

        var dataJson = JsonSerializer.Serialize(ev, ev.GetType(), Options);

        // 最小メタ（必要なら追加してOK）
        var meta = new
        {
            schema = 1,
            clrType = ev.GetType().FullName
        };
        var metaJson = JsonSerializer.Serialize(meta, Options);

        return (type, dataJson, metaJson, ev.OccurredUtc);
    }

    public static IEvent Deserialize(string type, string dataJson, DateTimeOffset occurredUtc)
    {
        return type switch
        {
            nameof(CartCreated) => JsonSerializer.Deserialize<CartCreated>(dataJson, Options)!,
            nameof(ItemAdded) => JsonSerializer.Deserialize<ItemAdded>(dataJson, Options)!,
            nameof(ItemRemoved) => JsonSerializer.Deserialize<ItemRemoved>(dataJson, Options)!,
            _ => throw new InvalidOperationException($"Unknown event type: {type}")
        };
    }
}
```

> “type の文字列” は将来の変更点になりやすいので、**安定した命名**にするのがおすすめ😊（第35章の「進化」につながる）🧬✨

---

## 9) Projection 更新（同期でOK）🔎⚡

この章は「実戦の入口」なので、まずは **イベント保存と同じタイミングで Projection を更新**してOK😊
（本格的な非同期は、次のステップでやればよし📬✨）

### 9.1 Projection 更新関数（イベントを読んで更新）🧠➡️🗃️

```csharp
public sealed class CartProjectionWriter
{
    private readonly string _cs;

    public CartProjectionWriter(string connectionString) => _cs = connectionString;

    public async Task ApplyAsync(IEvent ev)
    {
        using var con = new Microsoft.Data.Sqlite.SqliteConnection(_cs);
        await con.OpenAsync();

        using var tx = con.BeginTransaction();

        switch (ev)
        {
            case CartCreated e:
                await UpsertSummary(con, tx, e.CartId);
                break;

            case ItemAdded e:
                await UpsertItem(con, tx, e.CartId, e.ProductId, e.Quantity);
                await UpsertSummary(con, tx, e.CartId);
                break;

            case ItemRemoved e:
                await DeleteItem(con, tx, e.CartId, e.ProductId);
                await UpsertSummary(con, tx, e.CartId);
                break;
        }

        await tx.CommitAsync();
    }

    private static async Task UpsertItem(Microsoft.Data.Sqlite.SqliteConnection con, Microsoft.Data.Sqlite.SqliteTransaction tx,
        string cartId, string productId, int addQty)
    {
        var cmd = con.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = """
            INSERT INTO cart_items_projection(cart_id, product_id, quantity)
            VALUES($cartId, $productId, $qty)
            ON CONFLICT(cart_id, product_id)
            DO UPDATE SET quantity = quantity + $qty
        """;
        cmd.Parameters.AddWithValue("$cartId", cartId);
        cmd.Parameters.AddWithValue("$productId", productId);
        cmd.Parameters.AddWithValue("$qty", addQty);
        await cmd.ExecuteNonQueryAsync();
    }

    private static async Task DeleteItem(Microsoft.Data.Sqlite.SqliteConnection con, Microsoft.Data.Sqlite.SqliteTransaction tx,
        string cartId, string productId)
    {
        var cmd = con.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = "DELETE FROM cart_items_projection WHERE cart_id = $cartId AND product_id = $productId";
        cmd.Parameters.AddWithValue("$cartId", cartId);
        cmd.Parameters.AddWithValue("$productId", productId);
        await cmd.ExecuteNonQueryAsync();
    }

    private static async Task UpsertSummary(Microsoft.Data.Sqlite.SqliteConnection con, Microsoft.Data.Sqlite.SqliteTransaction tx,
        string cartId)
    {
        // total_items = SUM(quantity)
        var sumCmd = con.CreateCommand();
        sumCmd.Transaction = tx;
        sumCmd.CommandText = "SELECT COALESCE(SUM(quantity), 0) FROM cart_items_projection WHERE cart_id = $cartId";
        sumCmd.Parameters.AddWithValue("$cartId", cartId);
        var total = Convert.ToInt32(await sumCmd.ExecuteScalarAsync());

        var now = DateTimeOffset.UtcNow.ToString("O");

        var up = con.CreateCommand();
        up.Transaction = tx;
        up.CommandText = """
            INSERT INTO cart_summary_projection(cart_id, total_items, updated_utc)
            VALUES($cartId, $total, $now)
            ON CONFLICT(cart_id)
            DO UPDATE SET total_items = $total, updated_utc = $now
        """;
        up.Parameters.AddWithValue("$cartId", cartId);
        up.Parameters.AddWithValue("$total", total);
        up.Parameters.AddWithValue("$now", now);
        await up.ExecuteNonQueryAsync();
    }
}
```

---

## 10) API（Minimal API）で触れるようにする🌐🛒✨

ASP.NET Core 10 の「何が新しいか」はここでは深追いしなくてOK😊（でも “Minimal API が今も主役” って感じだよ） ([Microsoft Learn][3])

### 10.1 エンドポイント案（最小）📮

* `POST /carts`（作成）
* `POST /carts/{cartId}/items`（追加）
* `DELETE /carts/{cartId}/items/{productId}`（削除）
* `GET /carts/{cartId}`（Projection 参照）
* （おまけ）`POST /projections/rebuild`（再構築🔁）

### 10.2 “Load → Decide → Append → Project” の型（超重要）📌

```csharp
app.MapPost("/carts/{cartId}/items", async (string cartId, AddItemRequest req,
    SqliteEventStore store, CartProjectionWriter projector) =>
{
    // 1) Load
    var (events, lastVersion) = await store.ReadStreamAsync(cartId);

    // 2) Rehydrate
    var cart = Rehydrate(events);

    // 3) Decide
    var now = DateTimeOffset.UtcNow;
    var newEvents = cart.DecideAddItem(req.ProductId, req.Quantity, now);

    // 4) Append (expectedVersion)
    await store.AppendAsync(cartId, expectedVersion: lastVersion, newEvents);

    // 5) Projection 更新（同期）
    foreach (var ev in newEvents)
        await projector.ApplyAsync(ev);

    return Results.Ok(new { cartId });
});

public sealed record AddItemRequest(string ProductId, int Quantity);
```

### 10.3 競合時の返し方（それっぽく）⚔️🛑

```csharp
app.Use(async (ctx, next) =>
{
    try
    {
        await next();
    }
    catch (ConcurrencyException ex)
    {
        ctx.Response.StatusCode = 409; // Conflict
        await ctx.Response.WriteAsJsonAsync(new { error = "CONCURRENCY", message = ex.Message });
    }
});
```

---

## 11) Projection を読む（GET）👀🔎

```csharp
app.MapGet("/carts/{cartId}", async (string cartId, string cs) =>
{
    using var con = new Microsoft.Data.Sqlite.SqliteConnection(cs);
    await con.OpenAsync();

    var itemsCmd = con.CreateCommand();
    itemsCmd.CommandText = """
        SELECT product_id, quantity
        FROM cart_items_projection
        WHERE cart_id = $cartId
        ORDER BY product_id
    """;
    itemsCmd.Parameters.AddWithValue("$cartId", cartId);

    var items = new List<object>();
    using var r = await itemsCmd.ExecuteReaderAsync();
    while (await r.ReadAsync())
        items.Add(new { productId = r.GetString(0), quantity = r.GetInt32(1) });

    var sumCmd = con.CreateCommand();
    sumCmd.CommandText = "SELECT total_items, updated_utc FROM cart_summary_projection WHERE cart_id = $cartId";
    sumCmd.Parameters.AddWithValue("$cartId", cartId);

    using var r2 = await sumCmd.ExecuteReaderAsync();
    if (!await r2.ReadAsync())
        return Results.NotFound();

    return Results.Ok(new
    {
        cartId,
        totalItems = r2.GetInt32(0),
        updatedUtc = r2.GetString(1),
        items
    });
});
```

---

## 12) テスト（Given-When-Then）🧪🌸

xUnit の基本はこのチュートリアルの形がわかりやすいよ🧪✨ ([Microsoft Learn][5])
.NET のテスト全体の考え方もここが読みやすい😊 ([Microsoft Learn][6])

### 12.1 ドメインの単体テスト（イベントが出ることだけ見る）👀

```csharp
using Xunit;

public sealed class CartTests
{
    [Fact]
    public void Given_empty_When_create_Then_CartCreated()
    {
        // Given
        var now = DateTimeOffset.Parse("2026-02-01T00:00:00Z");

        // When
        var evs = Cart.DecideCreate("C1", now);

        // Then
        Assert.Single(evs);
        var e = Assert.IsType<CartCreated>(evs[0]);
        Assert.Equal("C1", e.CartId);
    }

    [Fact]
    public void Given_created_When_add_item_Then_ItemAdded()
    {
        // Given
        var cart = new Cart();
        cart.Apply(new CartCreated("C1", DateTimeOffset.UtcNow));

        // When
        var evs = cart.DecideAddItem("P1", 2, DateTimeOffset.UtcNow);

        // Then
        var e = Assert.IsType<ItemAdded>(Assert.Single(evs));
        Assert.Equal("C1", e.CartId);
        Assert.Equal("P1", e.ProductId);
        Assert.Equal(2, e.Quantity);
    }
}
```

### 12.2 競合テスト（expectedVersion の確認）⚔️

```csharp
[Fact]
public async Task When_expectedVersion_is_stale_Then_throw_ConcurrencyException()
{
    var store = new SqliteEventStore("Data Source=cart.db");

    // すでに version=1 まで入ってる想定で、
    // expectedVersion=0 を渡すと競合する
    await Assert.ThrowsAsync<ConcurrencyException>(async () =>
    {
        await store.AppendAsync("C1", expectedVersion: 0, new IEvent[]
        {
            new ItemAdded("C1", "P1", 1, DateTimeOffset.UtcNow)
        });
    });
}
```

---

## 13) Projection 再構築（リプレイ）🔁🧹（おすすめ）

「読みモデルは壊れても作り直せる」って感覚が超だいじ😊✨
最小はこれ👇

1. Projection テーブルを空にする
2. events を全部 stream 順に読んで Apply する

```csharp
app.MapPost("/projections/rebuild", async (SqliteEventStore store, CartProjectionWriter projector, string cs) =>
{
    // 1) Projection を消す（最小）
    using (var con = new Microsoft.Data.Sqlite.SqliteConnection(cs))
    {
        await con.OpenAsync();
        var cmd = con.CreateCommand();
        cmd.CommandText = """
            DELETE FROM cart_items_projection;
            DELETE FROM cart_summary_projection;
        """;
        await cmd.ExecuteNonQueryAsync();
    }

    // 2) 全イベントを流す（今回は簡略。実務ならstream単位でやるのがおすすめ）
    using var con2 = new Microsoft.Data.Sqlite.SqliteConnection(cs);
    await con2.OpenAsync();

    var read = con2.CreateCommand();
    read.CommandText = "SELECT type, data_json, occurred_utc FROM events ORDER BY stream_id, version";

    using var r = await read.ExecuteReaderAsync();
    while (await r.ReadAsync())
    {
        var type = r.GetString(0);
        var data = r.GetString(1);
        var occurred = DateTimeOffset.Parse(r.GetString(2));
        var ev = EventJson.Deserialize(type, data, occurred);
        await projector.ApplyAsync(ev);
    }

    return Results.Ok(new { rebuilt = true });
});
```

---

## 14) README（提出物の顔）📘✨

README に最低限ほしいもの👇😊

* 何ができるアプリ？🛒
* どう動かす？（起動・DB作成・API叩き方）🚀
* ざっくり構成（Domain / Api / Tests）🏗️
* イベント一覧（type / payload）📜
* Projection の説明🔎
* 競合の説明（409が返る）⚔️

AIに頼むなら、こういう依頼が強いよ🤖✨

* 「README を“利用者向け”と“開発者向け”の2段で書いて」📘
* 「イベント一覧を表で（type / いつ起きる / payload）にして」🧾
* 「競合（expectedVersion）の説明を、初心者に伝わる例えで」🍀

---

## 15) 仕上げチェックリスト（これで卒業！）✅🎓

### 動作チェック🧪

* [ ] `POST /carts` で作成できる🆕
* [ ] `POST /carts/{id}/items` で追加できる➕
* [ ] `GET /carts/{id}` で Projection が見える👀
* [ ] 競合すると 409 が返る⚔️
* [ ] Projection 再構築が動く🔁

### テスト🧪

* [ ] Given-When-Then が最低3本✅✅✅
* [ ] NG系（例：quantity <= 0）が1本以上🙅‍♀️
* [ ] 競合テストが1本⚔️

### 運用っぽさ🧰

* [ ] DBファイルが消えても作り直せる（マイグレーション/CREATE文）🗄️
* [ ] 依存パッケージ更新に備える（定期アップデート）🔧

> .NET は毎月パッチが出るので、定期的に更新していくのが大事だよ📅🔁 ([Microsoft][7])
> （例：.NET 10 も 2026-01-13 時点の更新が出てる） ([Microsoft Support][8])
> Visual Studio 2026 側も改善が継続してるよ🛠️✨ ([Microsoft Learn][9])

---

## 16) つまずきポイントあるある（先回り）🩹✨

* **Apply 漏れ**：イベントは保存されてるのに復元すると状態が変わらない😵‍💫
  → “イベント追加したら Apply もセット” を合言葉に✅🔁

* **type の不一致**：`nameof(...)` 変えちゃって読み戻し失敗😇
  → type は “外部契約” と思って固定しよ📌🧾

* **expectedVersion の計算ミス**：lastVersion がズレて 409 祭り🎆
  → `ReadStream` が返す `LastVersion` を信じるのが安全😊🔢

---

## 17) お祝い：ここまでできたら、もう「入口」は突破だよ🎉🎓✨

イベントが「保存できる」→「復元できる」→「読める（Projection）」→「壊れない（競合）」→「テストできる」🧠🛠️🧪
この5点セットが揃ってる時点で、めちゃくちゃ強い💪✨

[1]: https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/?utm_source=chatgpt.com "Announcing .NET 10"
[2]: https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14?utm_source=chatgpt.com "What's new in C# 14"
[3]: https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/overview?utm_source=chatgpt.com "What's new in .NET 10"
[4]: https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-10.0?view=aspnetcore-10.0&utm_source=chatgpt.com "What's new in ASP.NET Core in .NET 10"
[5]: https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-csharp-with-xunit?utm_source=chatgpt.com "Unit testing C# code in .NET using dotnet test and xUnit"
[6]: https://learn.microsoft.com/en-us/dotnet/core/testing/?utm_source=chatgpt.com "Testing in .NET"
[7]: https://dotnet.microsoft.com/en-us/platform/support/policy?utm_source=chatgpt.com "The official .NET support policy"
[8]: https://support.microsoft.com/en-us/topic/-net-10-0-update-january-13-2026-64f1e2a4-3eb6-499e-b067-e55852885ad5?utm_source=chatgpt.com ".NET 10.0 Update - January 13, 2026"
[9]: https://learn.microsoft.com/ja-jp/visualstudio/releases/2026/release-notes?utm_source=chatgpt.com "Visual Studio 2026 リリース ノート"
