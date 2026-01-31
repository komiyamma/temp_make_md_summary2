# 第31章：Projection実装②（非同期更新の入口）📬⏳

## この章でできるようになること 🎯✨

* Projection（読みモデル）を **バックグラウンドで非同期更新**できるようになる🛠️
* 「最終的整合性（eventual consistency）」の **“ズレる感覚”** を安全に体験できる😺
* 遅延・失敗・重複に備える **最低限の作法**がわかる🔁🧯

---

# 1. 同期更新と非同期更新、何が違うの？⚡🆚⏳

## 同期更新（第29章でやったやつ）⚡

* Commandを処理 → Event保存 → **Projectionもその場で更新**
* いいところ：画面がすぐ最新になりやすい😍
* つらいところ：

  * Projection更新が重いと **書き込みが遅くなる**🐢
  * Projection側で例外が出ると **書き込みまで巻き添え**になりがち😵‍💫

## 非同期更新（この章）📬⏳

* Commandを処理 → Event保存 → **「更新してね」メッセージをキューへ**📨
* 別スレッド／別プロセスで Projection を更新する🔧
* いいところ：

  * 書き込みが軽くなる🚀
  * 読みモデルが増えても「投影係」を増やせば分担できる🧑‍🤝‍🧑
* 注意点：

  * 画面は **ちょっと古い** ことがある（最終的整合性）🕰️
  * 失敗・重複・順序に備える必要が出てくる🔁⚠️

バックグラウンド処理の基本は、ASP.NET Coreでは `IHostedService` / `BackgroundService` が定番だよ〜というのが公式の考え方だよ📌 ([Microsoft Learn][1])

---

# 2. 「最終的整合性」って、どんな体験？🧠🍀

イメージはこれ👇

* ✅ 書き込みは成功した（イベントは保存された）
* ⏳ でも読みモデルが追いつくまで **数百ms〜数秒** かかることがある
* 🔁 追いついたら、画面も最新になる

つまり、ユーザー体験としては

* 「反映中…」を出す
* ちょっと待ってから再表示する
* 反映完了をポーリングで確認する
  みたいな工夫が必要になるよ😊📱✨

---

# 3. この章のミニ構成：疑似キュー＋投影ワーカー📦👷‍♀️

今回は “入口” なので、まずは **アプリ内キュー（疑似キュー）** で体験するよ😺

* 実戦では、メッセージング基盤（例：Queueストレージ等）に置き換える感じ！
  こういう用途（非同期処理のバックログ）にQueueを使うのは典型だよ〜って公式にも書いてある📌 ([Microsoft Learn][2])

---

# 4. 実装してみよう：Channelキュー＋BackgroundService 🧰✨

## 4.1 まずは「仕事の依頼票」を作る📮

Projection更新の依頼を「WorkItem」としてキューに積むよ📥

```csharp
public sealed record EventEnvelope(
    string StreamId,
    long Version,
    string EventType,
    string JsonData,
    DateTimeOffset OccurredAt,
    Guid EventId
);

public sealed record ProjectionWorkItem(
    Guid OperationId,
    EventEnvelope Envelope
);
```

---

## 4.2 キュー本体（インプロセス疑似キュー）📦

`Channel<T>` を使うと、アプリ内で安全にキューが作れるよ✨
（「逐次処理のキュー」例は公式のHosted Serviceサンプルでも紹介されてるよ） ([Microsoft Learn][1])

```csharp
using System.Threading.Channels;

public interface IProjectionQueue
{
    ValueTask EnqueueAsync(ProjectionWorkItem item, CancellationToken ct);
    IAsyncEnumerable<ProjectionWorkItem> DequeueAllAsync(CancellationToken ct);
}

public sealed class InMemoryProjectionQueue : IProjectionQueue
{
    private readonly Channel<ProjectionWorkItem> _channel =
        Channel.CreateUnbounded<ProjectionWorkItem>();

    public ValueTask EnqueueAsync(ProjectionWorkItem item, CancellationToken ct)
        => _channel.Writer.WriteAsync(item, ct);

    public async IAsyncEnumerable<ProjectionWorkItem> DequeueAllAsync(
        [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken ct)
    {
        while (await _channel.Reader.WaitToReadAsync(ct))
        {
            while (_channel.Reader.TryRead(out var item))
                yield return item;
        }
    }
}
```

---

## 4.3 Read Model（Projectionの保存先）📚

今回は超シンプルにメモリへ保存するよ✨
# あとでSQLiteや別DBに差し替えるのは第33章以降のノリでOK😺

重要ポイント：**重複対策（idempotent）** を最低限入れるよ🔁
→ 「同じイベントを2回食べても壊れない」ようにする🧷✨

```csharp
using System.Collections.Concurrent;

public sealed record TodoListItem(string TodoId, string Title, bool Completed);

public sealed class TodoListReadModelStore
{
    private readonly ConcurrentDictionary<string, TodoListItem> _items = new();
    private readonly ConcurrentDictionary<string, long> _lastAppliedVersionByStream = new();

    public IReadOnlyCollection<TodoListItem> GetAll()
        => _items.Values.OrderBy(x => x.TodoId).ToArray();

    public bool TryShouldApply(string streamId, long version)
    {
        var last = _lastAppliedVersionByStream.GetOrAdd(streamId, -1);
        return version > last; // 既に適用済みなら弾く🔁
    }

    public void MarkApplied(string streamId, long version)
        => _lastAppliedVersionByStream.AddOrUpdate(streamId, version, (_, __) => version);

    public void Upsert(TodoListItem item)
        => _items[item.TodoId] = item;
}
```

---

## 4.4 Projector（イベント→読みモデル更新）🔎✨

```csharp
using System.Text.Json;

public interface ITodoProjector
{
    void Apply(EventEnvelope e);
}

public sealed class TodoProjector : ITodoProjector
{
    private readonly TodoListReadModelStore _store;

    public TodoProjector(TodoListReadModelStore store) => _store = store;

    public void Apply(EventEnvelope e)
    {
        // 重複防止（最低限）🔁
        if (!_store.TryShouldApply(e.StreamId, e.Version)) return;

        switch (e.EventType)
        {
            case "TodoCreated":
            {
                var data = JsonSerializer.Deserialize<TodoCreated>(e.JsonData)!;
                _store.Upsert(new TodoListItem(data.TodoId, data.Title, false));
                break;
            }
            case "TodoCompleted":
            {
                var data = JsonSerializer.Deserialize<TodoCompleted>(e.JsonData)!;
                // 既存を拾って更新（なければ作らない運用にする）🧠
                // 超簡易のため、タイトルは保持しておく想定
                // 本番ならProjection用の状態を持って Apply するのが普通だよ
                var current = _store.GetAll().FirstOrDefault(x => x.TodoId == data.TodoId);
                if (current is not null)
                    _store.Upsert(current with { Completed = true });
                break;
            }
        }

        _store.MarkApplied(e.StreamId, e.Version);
    }

    private sealed record TodoCreated(string TodoId, string Title);
    private sealed record TodoCompleted(string TodoId);
}
```

---

## 4.5 投影ワーカー（BackgroundService）👷‍♀️⏳

キューを監視して、入ってきた仕事を1つずつ処理するよ📬
`BackgroundService` はWorker/バックグラウンド処理の基本として公式でも案内されてるよ🧩 ([Microsoft Learn][1])

```csharp
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

public sealed class ProjectionWorker : BackgroundService
{
    private readonly IProjectionQueue _queue;
    private readonly ITodoProjector _projector;
    private readonly ProjectionStatusStore _status;
    private readonly ILogger<ProjectionWorker> _logger;

    public ProjectionWorker(
        IProjectionQueue queue,
        ITodoProjector projector,
        ProjectionStatusStore status,
        ILogger<ProjectionWorker> logger)
    {
        _queue = queue;
        _projector = projector;
        _status = status;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await foreach (var item in _queue.DequeueAllAsync(stoppingToken))
        {
            try
            {
                // わざと遅延を入れて「最終的整合性」を体験⌛
                await Task.Delay(800, stoppingToken);

                _projector.Apply(item.Envelope);
                _status.MarkDone(item.OperationId);

                _logger.LogInformation("Projection applied. op={OperationId} evt={EventId}",
                    item.OperationId, item.Envelope.EventId);
            }
            catch (Exception ex)
            {
                _status.MarkFailed(item.OperationId, ex.Message);
                _logger.LogError(ex, "Projection failed. op={OperationId}", item.OperationId);
            }
        }
    }
}

public sealed class ProjectionStatusStore
{
    private readonly ConcurrentDictionary<Guid, (string Status, string? Error)> _map = new();

    public void MarkPending(Guid opId) => _map[opId] = ("pending", null);
    public void MarkDone(Guid opId) => _map[opId] = ("done", null);
    public void MarkFailed(Guid opId, string error) => _map[opId] = ("failed", error);

    public (string Status, string? Error)? Get(Guid opId)
        => _map.TryGetValue(opId, out var v) ? v : null;
}
```

---

## 4.6 最小APIでつなぐ（書き込み→キュー投入→読み取り）🧩🌸

Minimal APIの基本はこの流れでOKだよ〜というのが公式チュートリアルにもあるやつ📘 ([Microsoft Learn][3])
（.NET 10 ではMinimal APIの検証まわりも強化されてるよ📌） ([Microsoft Learn][4])

```csharp
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<IProjectionQueue, InMemoryProjectionQueue>();
builder.Services.AddSingleton<TodoListReadModelStore>();
builder.Services.AddSingleton<ITodoProjector, TodoProjector>();
builder.Services.AddSingleton<ProjectionStatusStore>();
builder.Services.AddHostedService<ProjectionWorker>();

var app = builder.Build();

// ---- 書き込み（イベント保存は超簡略：実戦ではEventStoreへ） ----
app.MapPost("/todos", async (CreateTodoRequest req,
    IProjectionQueue queue,
    ProjectionStatusStore status,
    CancellationToken ct) =>
{
    var todoId = Guid.NewGuid().ToString("N");
    var opId = Guid.NewGuid();

    status.MarkPending(opId);

    // ここでは「イベントを保存した体」にして、即キューへ📨
    var evt = new EventEnvelope(
        StreamId: $"todo-{todoId}",
        Version: 0,
        EventType: "TodoCreated",
        JsonData: JsonSerializer.Serialize(new { TodoId = todoId, Title = req.Title }),
        OccurredAt: DateTimeOffset.UtcNow,
        EventId: Guid.NewGuid()
    );

    await queue.EnqueueAsync(new ProjectionWorkItem(opId, evt), ct);

    // 反映は非同期なので、まず受付だけ返す📬
    return Results.Accepted($"/projection-status/{opId}", new
    {
        TodoId = todoId,
        OperationId = opId,
        Message = "作成を受付したよ！反映はちょっと待ってね⏳✨"
    });
});

app.MapGet("/projection-status/{opId:guid}", (Guid opId, ProjectionStatusStore status) =>
{
    var s = status.Get(opId);
    return s is null
        ? Results.NotFound(new { Message = "そのOperationIdは見つからないよ🥺" })
        : Results.Ok(new { OperationId = opId, Status = s.Value.Status, Error = s.Value.Error });
});

// ---- 読み取り（Projection） ----
app.MapGet("/todos", (TodoListReadModelStore store) => Results.Ok(store.GetAll()));

app.Run();

public sealed record CreateTodoRequest(string Title);
```

---

## 5. 「遅延の見せ方」ミニ作法 💅⏳

非同期Projectionでは、ユーザーにこう見せると優しいよ😊✨

### パターンA：受付（202）＋ステータス確認🧾

* POSTで `202 Accepted` を返す📬
* 画面は「反映中…」を出す⌛
* `/projection-status/{operationId}` をポーリングして `done` になったら一覧更新🔁✨

この章のサンプルはこれ！

### パターンB：ちょい待ってから再読込🔄

* POSTの後、0.5〜1秒だけ待ってGETし直す
* 小規模ならこれでも体験はできる😺

---

## 6. 非同期にすると増える「事故」ベスト3 ⚠️😵‍💫

### ① 重複（同じイベントを2回処理）🔁

* 通信や再試行で普通に起こる
* 対策：

  * **最後に適用したversionを覚える**（この章でやったやつ）🧷
  * あるいは EventId で「食べたか管理」🍽️

### ② 順序（イベントの順番が前後）🔀

* 1ワーカー＋1キューなら起こりにくい
* ワーカーを増やしたり分散すると起こりやすい
* 対策（入口）：

  * **StreamIdごとに順序を守る**（パーティション）
  * おかしくなったら **Projection再構築（第32章）** 🔁🧹

### ③ 失敗（投影処理が落ちる）💥

* 対策（入口）：

  * try/catchで握りつぶさず **ログ＋失敗ステータス**🧯
  * リトライ回数を決める（無限はダメ🙅‍♀️）
  * それでもダメなら「隔離（Dead Letter）」へ📦
    （実戦でQueueを使うのは、こういう運用がしやすいからだよ📌） ([Microsoft Learn][2])

---

## 7. ミニ演習（手を動かすやつ）✍️🧪

### 演習1：遅延を「目で見る」👀⌛

1. `ProjectionWorker` の `Task.Delay(800)` を `3000` にしてみる
2. POST `/todos` → すぐGET `/todos`
3. **最初は増えてない** → しばらくしてから増えるのを確認😺✨

### 演習2：失敗を起こしてみる💥

1. `TodoProjector.Apply` の中で、`Title` が空なら例外を投げる
2. 空タイトルでPOSTして、`/projection-status/{opId}` が `failed` になるのを確認🧯

### 演習3：重複耐性チェック🔁

1. 同じ `EventEnvelope` を **2回キューに積む**（わざと）
2. 一覧が壊れないこと（2件に増えないこと）を確認✅✨
   （今回のサンプルだと version で弾けるはず！）

---

## 8. AI活用（コピペで使えるプロンプト）🤖💬✨

### ① 「重複耐性」のレビュー依頼🔁

* 目的：投影が二重適用で壊れないかチェック

```text
次のC#コードのProjection更新は「同じイベントを2回処理」しても壊れませんか？
壊れるなら、最小の修正案を3つ（version方式 / EventId方式 / DB一意制約方式）で提案して。
コード：
（ここに TodoListReadModelStore と TodoProjector を貼る）
```

### ② 「将来Queueへ移行」するための差分整理📦➡️☁️

```text
このインプロセスChannelキューを、将来「外部キュー」に置き換える前提で、
置き換えポイント（インターフェース、シリアライズ、リトライ、死んだメッセージ隔離）を箇条書きで整理して。
```

---

## 9. まとめ🧁✨

* 非同期Projectionは「書き込みを速く・安全に」しやすい反面、**ズレる**のが前提になるよ⏳
* だからこそ

  * 受付レスポンス（202）📬
  * 反映状況（status）🧾
  * 重複耐性（idempotent）🔁
  * 失敗時の扱い🧯
    を最初からセットで持つのがコツだよ😊✨

次の第32章では、ズレたり壊れたりしても **Projectionをイベントから作り直す（リプレイ）** をやるよ🔁🧹

[1]: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services?view=aspnetcore-10.0&utm_source=chatgpt.com "Background tasks with hosted services in ASP.NET Core"
[2]: https://learn.microsoft.com/ja-jp/dotnet/api/overview/azure/storage.queues-readme?view=azure-dotnet&utm_source=chatgpt.com "Azure Storage Queues client library for .NET"
[3]: https://learn.microsoft.com/en-us/aspnet/core/tutorials/min-web-api?view=aspnetcore-10.0&utm_source=chatgpt.com "Tutorial: Create a Minimal API with ASP.NET Core"
[4]: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis?view=aspnetcore-10.0&utm_source=chatgpt.com "Minimal APIs quick reference"
