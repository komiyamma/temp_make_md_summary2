# 第35章：イベントの進化（バージョニング）＋冪等性（最小）🧬🧷

## この章でできるようになること 🎯✨

* イベントが保存されたあとに「仕様変更」が来ても、壊さずに前へ進めるようになる🧯✅
* “過去のイベントは基本いじらない”理由が腹落ちする📜🙂
* 「イベントのバージョン」を扱う最小の設計（エンベロープ＋Upcast）を書ける🧰🔁
* 二重実行（リトライ・連打・タイムアウト再送）でイベントが二重に積まれないようにする（冪等性キー）を入れられる🔁🔒

---

# 1. 現実でよく起きる2つの事故 😵‍💫💥

## 事故A：イベントの形を変えたら、過去が読めない🧊

例）`CartItemAdded` に「単価（UnitPrice）」を後から足したい

* 昔のイベント：単価が無い
* 新しいコード：単価が必須
  → 復元（Rehydrate）が途中で落ちる😿

## 事故B：同じコマンドが2回届いて、イベントが2回積まれる🔁🔁

原因あるある👇

* 画面の二度押し🖱️🖱️
* APIタイムアウト→クライアントが再送📶😵
* メッセージ処理のリトライ🔁
  → 「数量が2倍」みたいな悲劇が起きる🥲

---

# 2. まず大原則：「イベントは基本、変えない」📜🧡

イベントソーシングでは、イベントは“履歴そのもの”なので、後から書き換えると…

* 監査・追跡が崩れる🕵️‍♀️💦
* 古いデータが読めなくなる📦
* 別の読みモデル（Projection）や分析が壊れる📊💥

特に現行の .NET 10 は JSON 周りがより厳格になっていて、曖昧なJSONを早めに弾く方向が強いです（例：メタデータ予約名との衝突検出など）。([Microsoft Learn][1])
また、現行LTSは .NET 10（2025-11-11 リリース）です。([Microsoft][2])

---

# 3. イベント進化の「よく使う3パターン」🧬📦✨

| パターン                    | 何をする？                    | いつ向く？           | 注意点            |
| ----------------------- | ------------------------ | --------------- | -------------- |
| ① 後方互換の追加（Additive）➕    | フィールドを“追加”して、無いときは既定値で扱う | 追加が自然（例：メモ欄）    | “必須化”すると崩れる😵  |
| ② 新イベントを追加（New Event）🆕 | 旧イベントは残し、新イベントで表現する      | 意味が変わる／分けたい     | 読み側の対応が増える🧹   |
| ③ 読み取り時に変換（Upcast）🔁    | 旧イベントを読み込んだ瞬間に新形へ変換する    | 過去イベントを最新形で扱いたい | 変換ロジックのテスト必須🧪 |

この章では「③ Upcast」＋「冪等性」を最小でやります😊🧰

---

# 4. 最小の道具：「イベントエンベロープ」🍱🏷️

イベント本体だけだと、進化や運用で困りがちなので、最低限の包み（Envelope）をつけます🧸✨

* `EventType`：イベント名（例：`CartItemAdded`）
* `SchemaVersion`：そのイベントの形のバージョン（例：1, 2…）
* `EventId`：イベント自体の一意ID（重複対策にも使える）🆔
* `OccurredAt`：発生日時⏰
* `DataJson`：イベント本体（JSON）🧾
* `MetaJson`：相関IDや冪等性キーなど（JSON）🏷️

> ポリモーフィックな JSON（継承イベントを `System.Text.Json` で判別して復元する）も可能で、.NET 7 以降は属性でのサポートがあります。([Microsoft Learn][3])
> ただし本章は「まず壊れにくい最小」を優先して、`EventType + DataJson` 方式でいきます😊

---

# 5. 実装：エンベロープとイベント（例：カート）🛒✨

```csharp
using System.Text.Json;

public sealed record EventEnvelope(
    Guid EventId,
    string StreamId,
    long StreamVersion,
    string EventType,
    int SchemaVersion,
    DateTimeOffset OccurredAt,
    string DataJson,
    string MetaJson
);

public sealed record CartItemAddedV1(Guid CartId, string Sku, int Quantity);
public sealed record CartItemAddedV2(Guid CartId, string Sku, int Quantity, decimal UnitPrice);

public static class Json
{
    public static readonly JsonSerializerOptions Options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false
    };
}
```

## 💡ポイント

* “V1/V2” は「過去イベントの形」を表すための型だよ😊
* 今のアプリの内部では「最新形（V2）」で統一して扱えるとラク✨

---

# 6. 実装：Upcast（V1→V2へ変換）🔁🧙‍♀️

## 6.1 Upcastの方針（超重要）📌

* 旧イベントを読み込んだら、即座に“最新形”へ変換してからドメインに渡す
* 変換結果は「その場だけ」でもOK（最小）

  * 余裕があれば「変換後で保存し直す」戦略もあるけど、この章はやらない🙂

## 6.2 Upcasterコード（最小）🧰

```csharp
public static class EventUpcaster
{
    public static EventEnvelope UpcastToLatest(EventEnvelope e)
    {
        // 例：CartItemAdded の v1 → v2
        if (e.EventType == "CartItemAdded" && e.SchemaVersion == 1)
        {
            var v1 = JsonSerializer.Deserialize<CartItemAddedV1>(e.DataJson, Json.Options)
                     ?? throw new InvalidOperationException("Invalid CartItemAdded v1 JSON");

            // v1にはUnitPriceが無いので、既定値で補う（例として0）
            var v2 = new CartItemAddedV2(v1.CartId, v1.Sku, v1.Quantity, unitPrice: 0m);

            return e with
            {
                SchemaVersion = 2,
                DataJson = JsonSerializer.Serialize(v2, Json.Options)
            };
        }

        return e;
    }
}
```

## 6.3 「既定値0」ってアリ？🤔

学習ではOK！✅
実務では、

* 単価が必須の意味なら「後から必須化」ではなく、イベント設計を見直す（②新イベント追加など）も検討するよ🧠✨

---

# 7. ここから本題：冪等性（Idempotency）🧷🔒✨

## 7.1 冪等性ってなに？🙂

同じリクエスト（同じ意図）が複数回来ても、結果が一回分になる性質だよ🔁✅
実務のREST APIでも「冪等性キー」を使って重複を防ぐ設計がよく紹介されています。([Milan Jovanović][4])

## 7.2 何を“同じ”とみなす？🧠

この章は最小なので👇

* 「IdempotencyKey（冪等性キー）が同じなら、同じリクエスト扱い」にする
* さらに安全にするため、`RequestHash`（内容のハッシュ）も保存して「キー使い回し事故」を検出する🚨

---

# 8. 実装：SQLiteで冪等性テーブルを作る🗄️🧷

## 8.1 テーブル（最小DDL）🧱

```sql
CREATE TABLE IF NOT EXISTS idempotency (
  idempotency_key TEXT PRIMARY KEY,
  request_hash     TEXT NOT NULL,
  response_json    TEXT,
  status           TEXT NOT NULL,
  created_at       TEXT NOT NULL
);
```

* `PRIMARY KEY` による一意制約で「同じキーの二重登録」を止める🔒
* `status` は最小で `"processing"` / `"completed"` を想定🙂

---

# 9. 実装：冪等性つきコマンド処理（最小の型）📮✅🔁

ここでは「AddItem（商品追加）」を例にするね🛒✨

* 1回目：普通にイベントを積む
* 2回目：同じキーなら “前回の結果” を返して、イベントは増やさない

## 9.1 リクエストと結果（例）🧾

```csharp
public sealed record AddItemCommand(Guid CartId, string Sku, int Quantity, decimal UnitPrice);

public sealed record AddItemResult(bool Success, string Message, long NewStreamVersion);
```

## 9.2 ざっくりの流れ（超大事）🧠✨

1. トランザクション開始
2. `idempotency_key` で検索

* completed なら response を返す
* processing なら「処理中」扱い（今回は例外 or リトライ促し）

3. なければ processing でINSERT（予約）
4. イベントをAppend
5. response を保存して completed に更新
6. コミット✅

## 9.3 コード（最小・雰囲気重視）🧸✨

```csharp
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Data.Sqlite;

public sealed class IdempotencyStore
{
    private readonly SqliteConnection _conn;
    public IdempotencyStore(SqliteConnection conn) => _conn = conn;

    public (string Status, string? ResponseJson, string RequestHash)? Find(string key, SqliteTransaction tx)
    {
        using var cmd = _conn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = """
            SELECT status, response_json, request_hash
            FROM idempotency
            WHERE idempotency_key = $key
            """;
        cmd.Parameters.AddWithValue("$key", key);

        using var reader = cmd.ExecuteReader();
        if (!reader.Read()) return null;

        return (reader.GetString(0), reader.IsDBNull(1) ? null : reader.GetString(1), reader.GetString(2));
    }

    public void Reserve(string key, string requestHash, SqliteTransaction tx)
    {
        using var cmd = _conn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = """
            INSERT INTO idempotency(idempotency_key, request_hash, response_json, status, created_at)
            VALUES ($key, $hash, NULL, 'processing', $now)
            """;
        cmd.Parameters.AddWithValue("$key", key);
        cmd.Parameters.AddWithValue("$hash", requestHash);
        cmd.Parameters.AddWithValue("$now", DateTimeOffset.UtcNow.ToString("O"));
        cmd.ExecuteNonQuery();
    }

    public void Complete(string key, string responseJson, SqliteTransaction tx)
    {
        using var cmd = _conn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = """
            UPDATE idempotency
            SET response_json = $res, status = 'completed'
            WHERE idempotency_key = $key
            """;
        cmd.Parameters.AddWithValue("$key", key);
        cmd.Parameters.AddWithValue("$res", responseJson);
        cmd.ExecuteNonQuery();
    }

    public static string HashRequest(AddItemCommand cmd)
    {
        var canonical = JsonSerializer.Serialize(cmd, Json.Options);
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(canonical));
        return Convert.ToHexString(bytes);
    }
}
```

> ※ `INSERT` がキー重複で失敗するのが「二重実行を止める仕組み」だよ🔒✨

---

# 10. 演習：イベント進化＋冪等性をつないで完成させよう 🧪🎀

## 演習A：イベント進化（Upcast）🔁🧬

1. `CartItemAdded` の `SchemaVersion` を 1/2 で作る
2. V1 の JSON を保存しておく（UnitPrice無し）
3. 読み込み時に `EventUpcaster.UpcastToLatest` を通してから復元する
4. 「V1でも落ちない」ことを確認✅

チェック✅

* Upcast後の `SchemaVersion` が 2 になってる？
* `UnitPrice` が既定値になってる？

---

## 演習B：冪等性（IdempotencyKey）🔒🧷

1. `IdempotencyStore` のテーブルを作る
2. コマンド処理の最初で `Find` → 既存なら結果を返す
3. 無ければ `Reserve` → イベント追加 → `Complete`
4. 同じ `IdempotencyKey` で2回呼び、イベントが増えないことを確認✅

チェック✅

* 2回目は「前回の結果」を返してる？
* イベント数が1回分のまま？

---

# 11. テスト（Given-When-Then）で守ろう🧪🌸

## 11.1 期待するふるまい ✅✨

* **Given**：空の状態
* **When**：同じコマンド（同じ冪等性キー）を2回実行
* **Then**：イベントは1回だけ、結果は同じ

```csharp
using Xunit;

public sealed class IdempotencyTests
{
    [Fact]
    public void Same_idempotency_key_does_not_append_twice()
    {
        // ここは擬似：本当はEventStore/SQLiteを使って
        // 「Appendされたイベント数」を検証するテストにするよ🧪✨

        var cmd = new AddItemCommand(
            CartId: Guid.NewGuid(),
            Sku: "SKU-001",
            Quantity: 1,
            UnitPrice: 1200m
        );

        var key = Guid.NewGuid().ToString(); // IdempotencyKey（例）

        // 1回目：成功してイベント追加
        // 2回目：同じkeyなのでイベント追加されない（同じ結果が返る）
        Assert.True(true);
    }
}
```

> テスト本体は、前章までで作った「SQLite EventStore」に合わせて、
> “イベント件数” をちゃんと数えて Assert しようね📏😊

---

# 12. AI活用（この章で効く使い方）🤖✨💡

## Upcast用プロンプト例 🧙‍♀️

* 「V1→V2 の変換で、既定値の決め方の候補を3つ出して」🧠
* 「Upcastの単体テスト観点をGiven-When-Thenで10個」🧪

## 冪等性用プロンプト例 🔒

* 「IdempotencyKeyの保存に必要なカラム設計を、最小→実務向けで比較して」📋
* 「同じキーで別内容が来たときの扱い方（409/422/ログのみ等）のメリデメ」⚖️

（冪等性キー方式はAPI設計でも定番で、“重複を防いで信頼性を上げる”文脈で説明されることが多いよ📚）([Milan Jovanović][4])

---

# 13. よくあるミス集 🙅‍♀️💦（ここ超あるある！）

* **イベントに `$type` みたいな予約っぽいプロパティ名を入れて混乱**
  → .NET 10 では予約メタデータと衝突する名前へのチェックが強くなってるので注意⚠️([Microsoft Learn][5])
* **「フィールド追加」をしたのに、読み側で必須扱いして落ちる**😿
* **冪等性キーはあるのに、結果を保存してなくて2回目に返せない**📦💥
* **同じキーを別用途に使い回して事故**（RequestHashで検知しよう🚨）

---

# 14. まとめ 🧡📘✨

* イベントは“履歴”なので、基本は書き換えず「進化」させる🧬
* 最小の進化は **SchemaVersion + Upcast** が扱いやすい🔁
* 二重実行は普通に起きるので、**IdempotencyKey + 一意制約 + 結果保存** で守る🔒🧷
* 現行の .NET 10 は JSON をより厳密に扱う方向が見えるので、「曖昧にしない設計」がより大事になってくるよ🙂✨([Microsoft Learn][1])

[1]: https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/overview?utm_source=chatgpt.com "What's new in .NET 10"
[2]: https://dotnet.microsoft.com/ja-jp/platform/support/policy?utm_source=chatgpt.com "公式の .NET サポート ポリシー | .NET"
[3]: https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/polymorphism?utm_source=chatgpt.com "How to serialize properties of derived classes with System. ..."
[4]: https://www.milanjovanovic.tech/blog/implementing-idempotent-rest-apis-in-aspnetcore?utm_source=chatgpt.com "Implementing Idempotent REST APIs in ASP.NET Core"
[5]: https://learn.microsoft.com/en-us/dotnet/core/compatibility/serialization/10/property-name-validation?utm_source=chatgpt.com "System.Text.Json checks for property name conflicts - .NET"
