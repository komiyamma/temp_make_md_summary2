# 第6章：まずCRUDを作って“限界”を見る😺🧱

## この章のゴール🎯✨

CRUD（作成・取得・更新・削除）をいったん“普通に”作ってみて、すぐ湧いてくる追加要求（履歴・監査・巻き戻し）で **どこが苦しくなるか** を体験するよ〜🧠💥
そして「イベントを積む」発想が **なぜ必要になるのか** を、身体で理解するのが狙いだよ🔁✨

---

# 1. まずは最小CRUDを作ろう🛠️🚀

題材は超シンプルな **ToDo** にするね📝（カートでも家計簿でも同じ構造で苦しくなるから安心してOK😌）

## 1-1. データ（状態）モデルを決める📦

「今の状態」をDBに保存する、いわゆる“状態保存”モデルでいくよ✅

* `Id`（ToDoのID）
* `Title`（やること）
* `IsDone`（終わった？）
* `UpdatedAt`（更新時刻）※あとで監査っぽくしたくなるから最初から置いちゃう⏰

---

# 2. 最小構成のWeb API（CRUD）例🍱🌐

ここでは **Minimal API + SQLite + EF Core** でサクッと作るよ🧁
（EF Core 10 は .NET 10 前提、LTS枠だよ〜📌）([Microsoft Learn][1])

## 2-1. 使うパッケージ📦

```powershell
dotnet add package Microsoft.EntityFrameworkCore.Sqlite
dotnet add package Microsoft.EntityFrameworkCore.Design
```

## 2-2. `TodoItem` と `AppDbContext` を用意🧩

```csharp
using Microsoft.EntityFrameworkCore;

public sealed class TodoItem
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Title { get; set; }
    public bool IsDone { get; set; }
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}

public sealed class AppDbContext : DbContext
{
    public DbSet<TodoItem> Todos => Set<TodoItem>();

    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }
}
```

## 2-3. `Program.cs`（CRUDエンドポイント）🧪

```csharp
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(opt =>
    opt.UseSqlite("Data Source=app.db"));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

// Create
app.MapPost("/todos", async (AppDbContext db, CreateTodoRequest req) =>
{
    var todo = new TodoItem
    {
        Title = req.Title.Trim(),
        IsDone = false,
        UpdatedAt = DateTimeOffset.UtcNow
    };

    db.Todos.Add(todo);
    await db.SaveChangesAsync();

    return Results.Created($"/todos/{todo.Id}", todo);
});

// Read (list)
app.MapGet("/todos", async (AppDbContext db) =>
{
    var todos = await db.Todos
        .OrderByDescending(x => x.UpdatedAt)
        .ToListAsync();

    return Results.Ok(todos);
});

// Read (detail)
app.MapGet("/todos/{id:guid}", async (AppDbContext db, Guid id) =>
{
    var todo = await db.Todos.FindAsync(id);
    return todo is null ? Results.NotFound() : Results.Ok(todo);
});

// Update
app.MapPut("/todos/{id:guid}", async (AppDbContext db, Guid id, UpdateTodoRequest req) =>
{
    var todo = await db.Todos.FindAsync(id);
    if (todo is null) return Results.NotFound();

    todo.Title = req.Title.Trim();
    todo.IsDone = req.IsDone;
    todo.UpdatedAt = DateTimeOffset.UtcNow;

    await db.SaveChangesAsync();
    return Results.Ok(todo);
});

// Delete
app.MapDelete("/todos/{id:guid}", async (AppDbContext db, Guid id) =>
{
    var todo = await db.Todos.FindAsync(id);
    if (todo is null) return Results.NotFound();

    db.Todos.Remove(todo);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.Run();

public sealed record CreateTodoRequest(string Title);
public sealed record UpdateTodoRequest(string Title, bool IsDone);
```

## 2-4. DB作成（マイグレーション）🗄️

```powershell
dotnet ef migrations add Init
dotnet ef database update
dotnet run
```

Swaggerが出たら、CRUDは完成〜🎉🙌

---

# 3. ここからが本番：追加要求が来る😇📮

CRUDが動いた瞬間に、だいたいこう言われるよ👇（ほんとに“あるある”😵‍💫）

## 追加要求A：変更履歴を見たい📜👀

* 「いつ、誰が、何を変えたの？」
* 「前のタイトルって何だったっけ？」

## 追加要求B：監査（改ざん検知・証跡）が欲しい🕵️‍♀️🔍

* 「消したToDoも残して」
* 「削除は論理削除にして」
* 「監査対応なので証跡が必要です…！」

## 追加要求C：過去時点の状態が見たい🕰️✨

* 「**2026/02/01 10:00 時点** の一覧を出して」
* 「その時点で未完了だったものだけ欲しい」

## 追加要求D：巻き戻したい（Undo / Time Travel）🔙🧙‍♀️

* 「昨日の状態に戻して」
* 「この変更だけ取り消して」

このへんが来た瞬間、CRUD（状態保存）は顔色が変わるよ😨💦

---

# 4. CRUDで“履歴”を足すとどうなる？😵‍💫🧱

## 4-1. 素直にやる案：監査ログテーブルを足す📚

例：`TodoAuditLogs` を追加して、更新前後を保存する…みたいなやつ。

* ✅ できる
* ❌ でも、**一気に設計が重くなる**（しかも作っても要求が増えるとまた壊れる）

### “ありがちな”監査ログ設計が抱える辛さ🧨

* どの粒度で保存する？（変更差分？丸ごとスナップ？）📌
* 取得のクエリが複雑になる（時点Tの状態＝「T以前の最新版」を探す）🌀
* 削除・復元・マージのルールが増える（仕様が雪だるま）⛄
* バグると「真実」が分からなくなる（監査のための仕組みが監査できない😂）

---

# 5. “時点Tの状態”をCRUDで出すのがなぜ大変？🧠💥

## 状態保存モデルの本質😺

CRUDの更新って、だいたいこう👇

* 「レコードを上書きする」✍️
* つまり「古い情報が消える（or 別の場所に逃がす必要がある）」🗑️

だから **履歴が本体ではない** のね。履歴は“後付けのオマケ”になりがち🍬

## 例：時点TのToDo一覧を出す（監査ログ方式）

「ToDo本体」＋「監査ログ」を組み合わせて、時点Tの状態を復元するには…

* ToDoが “いつ作られたか” が要る
* 更新履歴が “時系列で正しい” 必要がある
* 削除履歴も必要
* さらに「部分更新」「複数フィールド更新」「同時更新」も来る⚔️

つまり、**要求が増えるほどSQLと仕様が絡み合う**🧶😵‍💫

---

# 6. この章のキモ：CRUDの“限界”チェックリスト✅🧾

CRUD（状態保存）が苦しくなるサインはこれ👇

* 変更履歴が欲しい📜
* 監査対応（改ざん不可）が欲しい🕵️
* 過去時点の状態が欲しい🕰️
* Undo / 巻き戻しが欲しい🔙
* “なぜこうなった？”の説明責任が必要（トラブル調査）🚑
* 仕様変更が頻繁で、項目が増えたり意味が変わる🧬

このサインが複数出たら、**「履歴を主役にする」発想**が欲しくなるよね…って流れ💡✨

---

# 7. ミニ演習：CRUDを“わざと”苦しめよう😈🧪

## お題🎒

次の要求を1つだけ追加して、CRUDがどう苦しくなるか味わってみよう🍿

### 演習A（おすすめ）：過去時点の一覧🕰️

* 「指定時刻 `asOf`（例：2026-02-01T10:00:00Z）時点で未完了だったToDo一覧を返して」

👉 必要になりがちな追加情報：

* 作成時刻 `CreatedAt`
* 更新履歴（ログ or スナップ）
* 削除履歴（論理削除 or ログ）

### 演習B：Undo（1手戻す）🔙

* 「直前の更新だけ取り消す」
  👉 “直前”の定義で揉めるし、複数端末更新でさらに揉める😂

### 演習C：監査ログを表示📜

* 「このToDoの変更履歴を時系列で一覧表示」
  👉 変更前後、誰、理由、関連ID…どんどん増える😇

---

# 8. AI活用：CRUDはAIで爆速、でも“限界ポイント”は人間が見る🤖💨👀

## 8-1. Copilot / GitHub Copilot に投げるプロンプト例🪄

* 「Minimal APIでToDoのCRUDを書いて。SQLite + EF Core。エンドポイントはPOST/GET/PUT/DELETE。」
* 「バリデーション（空タイトル禁止）も入れて」
* 「テストの雛形も作って」

## 8-2. OpenAI Codex系に“将来要求”を出させる🔮

* 「ToDoアプリに将来追加されそうな要求を10個出して。監査・履歴・検索・巻き戻し・同時更新も混ぜて。」
* 「その要求が“状態保存CRUD”をどこから壊すかも説明して」

こうすると、次の章以降で「だからイベントが必要なんだ〜！」がスッと入るよ😊✨

---

# 9. まとめ：この章で持ち帰る“気づき”🎁✨

* CRUD（状態保存）は **“今”を扱うのは得意**😺✅
* でも、履歴・監査・時点復元・巻き戻しが来ると **後付けがどんどん重くなる**😵‍💫🧱
* 「変更の履歴」が重要なドメインでは、**履歴を主役にする設計**が自然になっていく📜➡️👑
* だから次は、イベントソーシングの基本語彙（Command / Event / State / Projection）に進むと、話が一気に繋がるよ📮📜🧠🔎✨

[1]: https://learn.microsoft.com/en-us/ef/core/what-is-new/ef-core-10.0/whatsnew?utm_source=chatgpt.com "What's New in EF Core 10"
