# 第6章：副作用の整理（見えない変更を見える化）👻⚠️✨

この章はね、「なんか呼んだだけなのにデータ変わってるんだけど！？😇」って事故を **仕組みで起きにくくする** 回だよ〜🧠💡
CQSのキモは「混ぜない」だけど、混ざりやすいのがこの **副作用（side effect）** なのです…！👀💥

> ちなみに最新のC#は **C# 14**、対応する最新の .NET は **.NET 10（LTS）** だよ〜✨（2025/11にリリース） ([Microsoft Learn][1])
> .NET のサポートは LTS=3年 / STS=2年の方針だよ📅 ([Microsoft][2])
> Visual Studio 2026 で .NET 10 が扱えるよ🛠️ ([Microsoft Learn][1])

---

## 6-1. この章のゴール🎯✨

読み終わったら、こんな状態になってればOK🙆‍♀️💕

* 「これは副作用だ！」って **嗅ぎ分け**できる👃👀
* Query に副作用が混ざる **ありがち事故**を説明できる😇
* 「例外的に必要な副作用」を **設計で“見える化”**できる📝✨
* テストで「副作用が入ってない」ことを **守れる**🧪🛡️

---

## 6-2. 副作用ってなに？（超やさしく）🧠🌱

ざっくり言うと👇

## ✅ 副作用 = 「戻り値以外に、世界が変わること」🌍🔧

たとえば…

* DB更新（INSERT/UPDATE/DELETE）🗄️✍️
* 外部API呼び出し（決済/通知/認証）🌐💳
* ファイル書き込み（ログ/画像/CSV）📁🖊️
* メール送信📨
* イベント発行📣
* キャッシュ書き換え🧊🔁
* 現在時刻の取得（テスト観点だと“外”）⏰
* 乱数（再現できない）🎲

このへんがメソッド内に入ってたら、「副作用あるかも！」って疑ってOK😎✨

---

## 6-3. CQS的に「ヤバい副作用」と「許容しやすい副作用」🚧💡

副作用は全部ダメ！…って話じゃないよ😊
**CQSで一番避けたい**のはこれ👇

## 🔥 Query が「業務データ」を変える副作用

* `GetUser()` が内部で `LastAccessedAt` 更新しちゃう😇
* `GetProduct()` が内部で閲覧数を増やしちゃう😇
* `Search()` が内部で何か登録しちゃう😇

これが起きると👇

* 呼んだ側は「読んだだけ」のつもりなのに、状態が変わる👻
* “読む処理”のテストがめんどくさくなる🧪💥
* バグ調査で「どこで変わった？」が地獄🪦

---

## 6-4. まずは事故コードを見てみよ😇💥（アンチパターン）

例として「ToDo詳細を取得するQueryっぽい処理」を見てね👀

```csharp
public sealed class TodoService
{
    private readonly ITodoRepository _repo;

    public TodoService(ITodoRepository repo)
        => _repo = repo;

    // 😇 Queryっぽいのに…中で更新してる！！
    public async Task<TodoDetailDto?> GetTodoDetailAsync(Guid id)
    {
        var todo = await _repo.FindByIdAsync(id);
        if (todo is null) return null;

        todo.ViewCount++;                 // 👻 副作用（業務データ更新）
        todo.LastViewedAtUtc = DateTime.UtcNow; // 👻 外部（現在時刻）依存
        await _repo.SaveAsync(todo);      // 👻 DB書き込み

        return new TodoDetailDto(todo.Id, todo.Title, todo.IsDone, todo.ViewCount);
    }
}
```

## 何がダメかを “言語化” すると…🧠📝

* メソッド名も返り値も「取得」なのに、実際は「更新」してる
* 呼び出し回数 = データ更新回数（思わぬ増加）📈💥
* 取得のつもりでキャッシュやリトライしたら、更新が増える😇
* テストで “読むだけ” ができない（書き込み前提になる）🧪💦

---

## 6-5. 解決の基本：副作用を「別のCommand」に分ける✂️✅

ここがCQSの王道〜✨
「閲覧数を増やす」っていう要求があるなら、**それはCommand** として表に出そ？😊

## ✅ 1) Query：読むだけにする🔍

```csharp
public sealed class TodoQueries
{
    private readonly ITodoRepository _repo;

    public TodoQueries(ITodoRepository repo)
        => _repo = repo;

    public async Task<TodoDetailDto?> GetTodoDetailAsync(Guid id)
    {
        var todo = await _repo.FindByIdAsync(id);
        if (todo is null) return null;

        // ✅ 読むだけ！
        return new TodoDetailDto(todo.Id, todo.Title, todo.IsDone, todo.ViewCount);
    }
}
```

## ✅ 2) Command：増やすのを担当する🔧

```csharp
public sealed class TodoCommands
{
    private readonly ITodoRepository _repo;
    private readonly IClock _clock;

    public TodoCommands(ITodoRepository repo, IClock clock)
        => (_repo, _clock) = (repo, clock);

    public async Task RecordViewedAsync(Guid id)
    {
        var todo = await _repo.FindByIdAsync(id);
        if (todo is null) return;

        todo.ViewCount++;
        todo.LastViewedAtUtc = _clock.UtcNow;
        await _repo.SaveAsync(todo);
    }
}
```

`DateTime.UtcNow` を直接使わず `IClock` にするのは、**テストが楽になる魔法**だよ⏰🪄✨

```csharp
public interface IClock
{
    DateTime UtcNow { get; }
}

public sealed class SystemClock : IClock
{
    public DateTime UtcNow => DateTime.UtcNow;
}
```

---

## 6-6. 「でも閲覧数って、画面表示とセットじゃない？」問題🤔💭

ここ、めっちゃ実務で揉めるポイント！😆💥
結論はこれ👇

## ✅ それが “業務的に必要” なら Command にする

* ランキング、人気順、レコメンドに使う、とかなら **業務データ**
  → Queryに混ぜず、Commandで明示✨

## ✅ “ただの観測” なら別ルートに逃がす

* 監視ログ、メトリクス、トレース、アクセスログ…📊🪪
  これらは **業務状態を変えない** なら、Queryに入っても比較的安全🙂
  でも！混ぜるなら **「観測だよ」って形で見える化**しよ📝✨
  （例：`IAccessLogger` を注入して、DB更新しないルールにする など）

---

## 6-7. Queryに副作用が混ざりがちな “典型例” 集😇📚

「うっかり混ぜ」あるある〜！

## ① キャッシュ更新🧊🔁

* Queryで結果をキャッシュに保存する（技術的副作用）
  👉 **落とし所**：Query本体は純粋にして、**Decorator**で包むのが綺麗✨

```csharp
public interface ITodoQueryService
{
    Task<IReadOnlyList<TodoListItemDto>> GetTodosAsync();
}

public sealed class TodoQueryService : ITodoQueryService
{
    private readonly ITodoRepository _repo;
    public TodoQueryService(ITodoRepository repo) => _repo = repo;

    public async Task<IReadOnlyList<TodoListItemDto>> GetTodosAsync()
    {
        var todos = await _repo.ListAsync();
        return todos.Select(t => new TodoListItemDto(t.Id, t.Title, t.IsDone)).ToList();
    }
}

// ✅ キャッシュという副作用は“外側”に追い出す！
public sealed class CachedTodoQueryService : ITodoQueryService
{
    private readonly ITodoQueryService _inner;
    private readonly ITodoCache _cache;

    public CachedTodoQueryService(ITodoQueryService inner, ITodoCache cache)
        => (_inner, _cache) = (inner, cache);

    public async Task<IReadOnlyList<TodoListItemDto>> GetTodosAsync()
    {
        var cached = await _cache.GetAsync();
        if (cached is not null) return cached;

        var fresh = await _inner.GetTodosAsync();
        await _cache.SetAsync(fresh);
        return fresh;
    }
}
```

**ポイント**：Queryの中心ロジックは汚さず、技術都合は外に置く🧼✨

---

## ② 「取得したら最終アクセス時刻を更新」👻⏰

これ、仕様として必要なら **Command** です🙂
必要じゃないなら、監視ログや分析基盤に流す方が安全だよ📊✨

---

## ③ 「GetOrCreate」系（取得なのに作る）🧟‍♀️💥

`GetUserByEmailOrCreate()` みたいなのは、ほぼ **Commandの香り**…！

* 見つからない場合に登録する → 状態変更
  👉 分けるなら
* Query：`FindUserByEmail`
* Command：`CreateUser`

---

## 6-8. テストで「Queryに副作用がない」を守る🧪🛡️

ここ超大事！**設計はテストで固定**すると強い💪✨

## ✅ Queryのテスト：保存が呼ばれてないことを確認

（例：Moq を使うイメージ）

```csharp
using Moq;
using Xunit;

public class TodoQueriesTests
{
    [Fact]
    public async Task GetTodoDetail_DoesNotSave()
    {
        var repo = new Mock<ITodoRepository>();
        repo.Setup(r => r.FindByIdAsync(It.IsAny<Guid>()))
            .ReturnsAsync(new Todo { Id = Guid.NewGuid(), Title = "A", IsDone = false, ViewCount = 1 });

        var queries = new TodoQueries(repo.Object);

        var dto = await queries.GetTodoDetailAsync(Guid.NewGuid());

        repo.Verify(r => r.SaveAsync(It.IsAny<Todo>()), Times.Never); // ✅ ここが守り！
    }
}
```

## ✅ Commandのテスト：保存が呼ばれることを確認

```csharp
public class TodoCommandsTests
{
    [Fact]
    public async Task RecordViewed_Saves()
    {
        var repo = new Mock<ITodoRepository>();
        repo.Setup(r => r.FindByIdAsync(It.IsAny<Guid>()))
            .ReturnsAsync(new Todo { Id = Guid.NewGuid(), Title = "A", IsDone = false, ViewCount = 1 });

        var clock = new Mock<IClock>();
        clock.SetupGet(c => c.UtcNow).Returns(new DateTime(2026, 1, 30, 0, 0, 0, DateTimeKind.Utc));

        var commands = new TodoCommands(repo.Object, clock.Object);

        await commands.RecordViewedAsync(Guid.NewGuid());

        repo.Verify(r => r.SaveAsync(It.IsAny<Todo>()), Times.Once);
    }
}
```

---

## 6-9. ミニ演習（手を動かすと定着するやつ）📝🔥

## 演習①：副作用を丸で囲え！⭕👀

次のうち、副作用っぽい行に「⭕」つけてみて〜😊

* DB書き込み
* 現在時刻取得
* 外部API
* キャッシュ更新
* 乱数
  （→ だいたい全部⭕になってOK😂）

## 演習②：Queryを分割して “見える化” ✂️✨

さっきのアンチパターン `GetTodoDetailAsync` を

* Query：読むだけ
* Command：閲覧を記録
  に分けてみよう💪🙂

## 演習③：キャッシュはDecoratorで外に出す🧊✨

`TodoQueryService` を `CachedTodoQueryService` で包む形にして、
Query本体を汚さない練習〜🧼🫧

---

## 6-10. AI（Copilot / Codex）に頼むときの“良いお願い”🤖🧷✨

AIは便利だけど、設計判断は人が握るのがコツだよ〜🙂✨

## ✅ 副作用の洗い出しプロンプト

```text
次のC#コードで、副作用（DB更新、外部I/O、時刻、乱数、キャッシュ更新など）になりうる箇所を列挙して、
Queryに混ぜると問題になる理由も短く説明して。
```

## ✅ CQS分割の提案プロンプト

```text
このメソッドをCQSに沿って分割したい。
Queryは状態変更なし、Commandに副作用を寄せる方針で、
クラス分割案とメソッド名案、最小の差分コードを提案して。
```

## ✅ テスト生成プロンプト（“Verify”まで指定すると強い）

```text
Query側にDB保存が入らないことを保証したい。
Moq + xUnitで SaveAsync が呼ばれないテストを作って。Verify(Times.Never) を必ず使って。
```

---

## 6-11. よくある詰まりポイント集🧱😵‍💫

* 「ログって副作用じゃないの？」
  → 副作用だけど、**業務状態を変えない観測**なら許容しやすいよ📊✨
* 「キャッシュ更新はダメ？」
  → ダメじゃない！でも **Query本体から追い出して“見える化”**しよ🧊✨
* 「取得と同時に更新したい仕様がある」
  → それは **Commandとして表に出す**のがCQS的にスッキリ👌✨

---

## 6-12. この章のまとめ✅🎀

* 副作用は「戻り値以外に世界が変わること」🌍🔧
* CQSで一番避けたいのは **Queryが業務データを更新すること**👻💥
* どうしても必要な副作用は、**Commandに出す** or **外側に逃がして見える化**📝✨
* テストで「Queryに副作用が入ってない」を固定すると最強🧪🛡️

---

## 次の第7章（ToDoで分ける📝🍰）に向けて、もしよければ👇も作るよ〜😊💕

* 「第6章の演習」用に、最初から用意された **練習プロジェクト一式**のコード（Console版 / Minimal API版どっちも）📦✨
* それを使った **授業スライドみたいな進行台本**（説明セリフ付き）🎤😆

[1]: https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14?utm_source=chatgpt.com "What's new in C# 14"
[2]: https://dotnet.microsoft.com/en-us/platform/support/policy?utm_source=chatgpt.com "The official .NET support policy"
