# 第33章：イベント永続化（まずはSQLiteでOK）🗄️✨

## この章でできるようになること🎯💡

* ✅ インメモリEventStoreを卒業して、**SQLiteにイベントを保存**できる
* ✅ **Append（追記）** と **ReadStream（読み出し）** をSQLiteで動かせる
* ✅ **expectedVersion（楽観ロック）** を、DB制約＋コードでちゃんと守れる🔒

---

# 1) まずは最小の「Eventsテーブル」を作ろう🧱🧺

イベントストアの最低ラインはこれ👇
「ストリームごとに」「順番（version）で」「出来事を積む」📚✨

## テーブル設計（最小構成）📐

* `stream_id`：どの集約（Aggregate）の履歴？（＝ストリームID）
* `version`：そのストリーム内の連番（1,2,3…）🔢
* `event_id`：イベント自体のID（重複防止にも使える）🪪
* `type`：イベント種類（例：`ItemAdded`）🏷️
* `data_json`：payload（事実の中身）📦
* `meta_json`：メタ情報（発生時刻・コリレーションID等）🏷️
* `created_utc`：保存した時刻（UTC ISO文字列でOK）⏱️

> SQLiteは **(stream_id, version)** を主キーにすると、「同じversionが2回入る」を物理的に防げて強いよ💪

---

# 2) SQLiteの“運用寄り”おまじない（超重要）🧙‍♀️✨

SQLiteはファイルDBだから、並行アクセスで「database is locked」が起きやすい😵‍💫
そこで、まずはこの3点を入れておくと学習がスムーズ🍀

## ✅ WALモード（読み取りと書き込みの同居がしやすい）📖✍️

`PRAGMA journal_mode=WAL;` で有効化できるよ。([SQLite][1])

## ✅ busy_timeout（ロック中はちょっと待つ）⏳

SQLite公式APIとして「ロック中は指定ms待つ」仕組みがあるよ。([SQLite][2])

## ✅ ロックの基本を知っておく（短い取引が正義）🧠

「どんなときにロックが起きるか」は公式の解説が一番安心。([SQLite][3])

---

# 3) NuGet追加📦✨

今回の実装は **Microsoft.Data.Sqlite** を使うよ。
.NET 10 / net10.0 まで対応してるのも確認できる👍 ([NuGet][4])

```bash
dotnet add package Microsoft.Data.Sqlite
```

（Microsoft Learnにも基本的な使い方が載ってるよ）([Microsoft Learn][5])

---

# 4) DDL：Eventsテーブルを作るSQL🧾🛠️

まずはこれを「起動時に1回」流して、DBを初期化する👍

```sql
CREATE TABLE IF NOT EXISTS events (
  stream_id   TEXT    NOT NULL,
  version     INTEGER NOT NULL,
  event_id    TEXT    NOT NULL,
  type        TEXT    NOT NULL,
  data_json   TEXT    NOT NULL,
  meta_json   TEXT    NOT NULL,
  created_utc TEXT    NOT NULL,

  PRIMARY KEY (stream_id, version),
  UNIQUE (event_id)
);

CREATE INDEX IF NOT EXISTS ix_events_stream
  ON events(stream_id);

CREATE INDEX IF NOT EXISTS ix_events_created
  ON events(created_utc);
```

ポイント😊✨

* **PRIMARY KEY(stream_id, version)**：順番が壊れない💎
* **UNIQUE(event_id)**：二重保存（うっかり）対策にもなる🧷（冪等性の入口にもなるよ）

---

# 5) 実装：SQLite版 EventStore（最小）🧪🚀

ここから「動く最小実装」💨
（プロジェクト内に `Infrastructure/EventStore` みたいなフォルダを作って置くと気持ちいい😺）

## 5-1) 例外（競合用）⚔️

```csharp
public sealed class ConcurrencyException : Exception
{
    public ConcurrencyException(string message) : base(message) { }
}
```

---

## 5-2) 保存するイベントの形（DB行）🧱

```csharp
public sealed record StoredEvent(
    string StreamId,
    long Version,
    string EventId,
    string Type,
    string DataJson,
    string MetaJson,
    string CreatedUtc
);
```

---

## 5-3) EventStoreインターフェース（最低限）📮

```csharp
public interface IEventStore
{
    Task AppendAsync(
        string streamId,
        long expectedVersion,
        IReadOnlyList<StoredEvent> newEvents,
        CancellationToken ct = default);

    Task<IReadOnlyList<StoredEvent>> ReadStreamAsync(
        string streamId,
        long fromVersionInclusive = 1,
        CancellationToken ct = default);
}
```

---

## 5-4) SQLite実装（初期化＋PRAGMA＋Append＋Read）🗄️✨

```csharp
using Microsoft.Data.Sqlite;

public sealed class SqliteEventStore : IEventStore
{
    private readonly string _connectionString;

    public SqliteEventStore(string dbPath)
    {
        var builder = new SqliteConnectionStringBuilder
        {
            DataSource = dbPath,
            Mode = SqliteOpenMode.ReadWriteCreate,
            Cache = SqliteCacheMode.Shared
        };
        _connectionString = builder.ToString();
    }

    public async Task InitializeAsync(CancellationToken ct = default)
    {
        await using var con = new SqliteConnection(_connectionString);
        await con.OpenAsync(ct);

        await ApplyPragmasAsync(con, ct);

        var ddl = """
        CREATE TABLE IF NOT EXISTS events (
          stream_id   TEXT    NOT NULL,
          version     INTEGER NOT NULL,
          event_id    TEXT    NOT NULL,
          type        TEXT    NOT NULL,
          data_json   TEXT    NOT NULL,
          meta_json   TEXT    NOT NULL,
          created_utc TEXT    NOT NULL,

          PRIMARY KEY (stream_id, version),
          UNIQUE (event_id)
        );

        CREATE INDEX IF NOT EXISTS ix_events_stream
          ON events(stream_id);

        CREATE INDEX IF NOT EXISTS ix_events_created
          ON events(created_utc);
        """;

        await using var cmd = con.CreateCommand();
        cmd.CommandText = ddl;
        await cmd.ExecuteNonQueryAsync(ct);
    }

    public async Task AppendAsync(
        string streamId,
        long expectedVersion,
        IReadOnlyList<StoredEvent> newEvents,
        CancellationToken ct = default)
    {
        if (newEvents.Count == 0) return;

        await using var con = new SqliteConnection(_connectionString);
        await con.OpenAsync(ct);
        await ApplyPragmasAsync(con, ct);

        await using var tx = await con.BeginTransactionAsync(ct);

        // 今の最新versionを読む（同一TX内で）
        var currentVersion = await GetCurrentVersionAsync(con, tx, streamId, ct);

        if (currentVersion != expectedVersion)
            throw new ConcurrencyException(
                $"Concurrency conflict: expected={expectedVersion}, actual={currentVersion}");

        // expectedVersionの次から順番に挿入
        long v = expectedVersion;

        foreach (var e in newEvents)
        {
            v++;

            await using var insert = con.CreateCommand();
            insert.Transaction = tx;
            insert.CommandText = """
            INSERT INTO events(stream_id, version, event_id, type, data_json, meta_json, created_utc)
            VALUES ($stream_id, $version, $event_id, $type, $data_json, $meta_json, $created_utc);
            """;

            insert.Parameters.AddWithValue("$stream_id", streamId);
            insert.Parameters.AddWithValue("$version", v);
            insert.Parameters.AddWithValue("$event_id", e.EventId);
            insert.Parameters.AddWithValue("$type", e.Type);
            insert.Parameters.AddWithValue("$data_json", e.DataJson);
            insert.Parameters.AddWithValue("$meta_json", e.MetaJson);
            insert.Parameters.AddWithValue("$created_utc", e.CreatedUtc);

            try
            {
                await insert.ExecuteNonQueryAsync(ct);
            }
            catch (SqliteException ex) when (ex.SqliteErrorCode == 19) // SQLITE_CONSTRAINT
            {
                // PK(stream_id, version) or UNIQUE(event_id) が破られた
                throw new ConcurrencyException($"Constraint failed while appending events: {ex.Message}");
            }
        }

        await tx.CommitAsync(ct);
    }

    public async Task<IReadOnlyList<StoredEvent>> ReadStreamAsync(
        string streamId,
        long fromVersionInclusive = 1,
        CancellationToken ct = default)
    {
        await using var con = new SqliteConnection(_connectionString);
        await con.OpenAsync(ct);
        await ApplyPragmasAsync(con, ct);

        await using var cmd = con.CreateCommand();
        cmd.CommandText = """
        SELECT stream_id, version, event_id, type, data_json, meta_json, created_utc
        FROM events
        WHERE stream_id = $stream_id
          AND version >= $from_version
        ORDER BY version;
        """;
        cmd.Parameters.AddWithValue("$stream_id", streamId);
        cmd.Parameters.AddWithValue("$from_version", fromVersionInclusive);

        var list = new List<StoredEvent>();

        await using var reader = await cmd.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            list.Add(new StoredEvent(
                StreamId: reader.GetString(0),
                Version: reader.GetInt64(1),
                EventId: reader.GetString(2),
                Type: reader.GetString(3),
                DataJson: reader.GetString(4),
                MetaJson: reader.GetString(5),
                CreatedUtc: reader.GetString(6)
            ));
        }

        return list;
    }

    private static async Task<long> GetCurrentVersionAsync(
        SqliteConnection con,
        SqliteTransaction tx,
        string streamId,
        CancellationToken ct)
    {
        await using var cmd = con.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = """
        SELECT COALESCE(MAX(version), 0)
        FROM events
        WHERE stream_id = $stream_id;
        """;
        cmd.Parameters.AddWithValue("$stream_id", streamId);

        var scalar = await cmd.ExecuteScalarAsync(ct);
        return Convert.ToInt64(scalar);
    }

    private static async Task ApplyPragmasAsync(SqliteConnection con, CancellationToken ct)
    {
        // WAL: 読み取りと書き込みの同居に強くなる
        // busy_timeout: "database is locked" を減らす
        // synchronous: 学習段階はNORMALが扱いやすい（耐久性重視ならFULLも検討）
        var pragmas = """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        PRAGMA busy_timeout = 5000;
        """;

        await using var cmd = con.CreateCommand();
        cmd.CommandText = pragmas;
        await cmd.ExecuteNonQueryAsync(ct);
    }
}
```

WALは `PRAGMA journal_mode=WAL;` で切り替えできるよ。([SQLite][1])
「busy_timeoutで待つ」仕組みも公式仕様として用意されてるよ。([SQLite][2])

---

# 6) 動作確認：1回保存→アプリ再起動→読める？🔁✅

テスト用に、超ミニで動かしてみよう😊

```csharp
using System.Text.Json;

var store = new SqliteEventStore("events.db");
await store.InitializeAsync();

var streamId = "cart-001";

string NewId() => Guid.NewGuid().ToString("N");
string UtcNow() => DateTimeOffset.UtcNow.ToString("O");

var newEvents = new[]
{
    new StoredEvent(streamId, 0, NewId(), "CartCreated",
        DataJson: JsonSerializer.Serialize(new { CartId = streamId }),
        MetaJson: JsonSerializer.Serialize(new { CorrelationId = NewId() }),
        CreatedUtc: UtcNow()),

    new StoredEvent(streamId, 0, NewId(), "ItemAdded",
        DataJson: JsonSerializer.Serialize(new { Sku = "APPLE", Qty = 2 }),
        MetaJson: JsonSerializer.Serialize(new { CorrelationId = NewId() }),
        CreatedUtc: UtcNow())
};

await store.AppendAsync(streamId, expectedVersion: 0, newEvents);

var loaded = await store.ReadStreamAsync(streamId);
foreach (var e in loaded)
{
    Console.WriteLine($"{e.StreamId} v{e.Version} {e.Type} {e.DataJson}");
}
```

* 1回実行してDBファイルができる✅
* もう1回実行して「expectedVersion=0」のままだと…**競合例外になる**はず⚔️（＝守れてる！）

---

# 7) ミニ演習（絶対やると理解が深まる）🧪🌸

## 演習A：インメモリEventStoreを置き換えよう🔄

* 既存の `IEventStore` を、今回の `SqliteEventStore` に差し替え
* アプリ再起動しても復元できるのを確認🔁✨

## 演習B：競合テストを書こう⚔️🧪

* Given：イベントが2つある（つまりversion=2）
* When：`expectedVersion=1` でAppend
* Then：`ConcurrencyException` になる🙅‍♀️

---

# 8) ありがちハマりポイント集😵‍💫➡️😺

## 「database is locked」💥

* ✅ `busy_timeout` を入れる（この章のPRAGMAの通り）([SQLite][2])
* ✅ トランザクションを短く！（中で重い処理しない）
* ✅ WALを使う（読み取りが増えても平和になりやすい）([SQLite][1])

## JSONがグチャグチャになってつらい🌀

# * ここは次章（第34章）で「保存形式の安定化」をちゃんとやるよ🧊✨
  （type名・data形・互換性がテーマ！）

---

## 9) AI活用（Copilot/Codex向け）🤖✨

### そのまま貼れるプロンプト例📝

```text
目的：SQLiteにイベントを永続化するEventStoreを実装したい
制約：
- テーブルは (stream_id, version) を主キー
- expectedVersionで競合検出する
- PRAGMA: journal_mode=WAL, synchronous=NORMAL, busy_timeout=5000
欲しいもの：
- C#でのAppend/ReadStream実装（Microsoft.Data.Sqlite）
- 例外設計（ConcurrencyException）
注意：
- SQLは必ずパラメータ化
- トランザクション内で currentVersion を読んでからInsertする
```

AIが出したSQLや例外処理は、**「制約（PRIMARY KEY / UNIQUE）で守れてる？」** を必ずチェックしてね👀✅

---

## まとめ🎁✨

* SQLiteの **Eventsテーブル** を用意して、EventStoreを永続化できた🗄️
* **(stream_id, version)** を主キーにすることで、順番が壊れにくい🔐
* WAL＋busy_timeoutで、学習中の「ロック地獄」を減らせる⏳✨ ([SQLite][1])

[1]: https://sqlite.org/wal.html?utm_source=chatgpt.com "Write-Ahead Logging"
[2]: https://www.sqlite.org/c3ref/busy_timeout.html?utm_source=chatgpt.com "Set A Busy Timeout"
[3]: https://sqlite.org/lockingv3.html?utm_source=chatgpt.com "File Locking And Concurrency In SQLite Version 3"
[4]: https://www.nuget.org/packages/microsoft.data.sqlite/ "
        NuGet Gallery
        \| Microsoft.Data.Sqlite 10.0.2
    "
[5]: https://learn.microsoft.com/ja-jp/dotnet/standard/data/sqlite/ "概要 - Microsoft.Data.Sqlite | Microsoft Learn"
