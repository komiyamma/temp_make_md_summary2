# 第22章：競合って何？（同時更新を体験）⚔️😵

## この章でできるようになること🎯✨

* 「競合（同時更新）」が**どういう事故**なのか説明できる📣
* イベントソーシングでも、**競合で“不正なイベント”が保存されうる**ことを体験する😱
* 次章の「expectedVersion（楽観ロック）」が**なぜ必要なのか**腹落ちする🔒✅

---

# 1) 競合ってなに？いちばん短い説明📝⚡

**同じデータを、別々の人（別々の処理）が、ほぼ同時に更新しようとしてぶつかること**だよ⚔️

たとえば…💡

* Aさん：残高100円だと思って 80円引き出す🏧
* Bさん：同じく残高100円だと思って 80円引き出す🏧
* 結果：合計160円引き出して、残高がマイナスに…！？😵‍💫💥

こういう「同時に起きた更新の衝突」を **競合（Concurrency Conflict）** って呼ぶよ✨

---

# 2) 「イベントソーシングなら安全」…ではない理由😺🔍

イベントソーシングは「状態」じゃなく「出来事（イベント）」を積む設計だよね📚
（イベントを順番に保存して、必要なら再生して状態を復元する）([martinfowler.com][1])

でも…⚠️
**イベントを作る（Decide）ときは、いったん現在状態を復元して判断する**よね？🔁🧠
その判断が「古い状態（古い版）」を元に行われると、**今の現実とズレたイベント**ができちゃうの😱

つまりこう👇

* 「イベントは追記だから安全」✅
* だけど「追記する内容が、古い情報で作られてたら危険」⚠️

この章は、ここを体で覚える回だよ💪✨

---

# 3) 今日の実験シナリオ：銀行口座🏦💰

## ルール（不変条件）🧷🛡️

* 残高は **0未満になっちゃダメ**🙅‍♀️（Balance >= 0）

## イベント📮

* `MoneyDeposited(100)`（100円入金）
* `MoneyWithdrawn(80)`（80円出金）

---

# 4) 実験①：わざと“危ない”イベントストアで競合を起こす💥🧪

ここでは、**競合チェックを一切しない**「ナイーブなイベントストア」を使うよ😈
（次章でこれを直す！🔧✨）

---

## 4-1. ドメインイベント定義📦✨

```csharp
public interface IDomainEvent { }

public sealed record MoneyDeposited(decimal Amount) : IDomainEvent;
public sealed record MoneyWithdrawn(decimal Amount) : IDomainEvent;
```

---

## 4-2. 集約（口座）と復元（Rehydrate）🔁🧠

ポイントは2つだよ👇

* イベントを `Apply` して状態を作る🔁
* 何個イベントを適用したかを `Version` として持つ📌（この章では「最後に適用したイベント番号」）

```csharp
public sealed class BankAccount
{
    public decimal Balance { get; private set; }
    public int Version { get; private set; } = -1; // 最後に適用したイベント番号
    private readonly List<IDomainEvent> _uncommitted = new();

    public IReadOnlyList<IDomainEvent> UncommittedEvents => _uncommitted;

    public static BankAccount Rehydrate(IEnumerable<IDomainEvent> history)
    {
        var acc = new BankAccount();
        foreach (var e in history) acc.Apply(e, isNew: false);
        return acc;
    }

    public void Deposit(decimal amount)
    {
        if (amount <= 0) throw new ArgumentOutOfRangeException(nameof(amount));
        Raise(new MoneyDeposited(amount));
    }

    public void Withdraw(decimal amount)
    {
        if (amount <= 0) throw new ArgumentOutOfRangeException(nameof(amount));
        if (Balance - amount < 0) throw new InvalidOperationException("残高不足だよ😢");
        Raise(new MoneyWithdrawn(amount));
    }

    public void ClearUncommittedEvents() => _uncommitted.Clear();

    private void Raise(IDomainEvent e) => Apply(e, isNew: true);

    private void Apply(IDomainEvent e, bool isNew)
    {
        switch (e)
        {
            case MoneyDeposited d:
                Balance += d.Amount;
                break;
            case MoneyWithdrawn w:
                Balance -= w.Amount;
                break;
            default:
                throw new NotSupportedException(e.GetType().Name);
        }

        Version++; // イベントを1個適用したら版が進む
        if (isNew) _uncommitted.Add(e);
    }
}
```

---

## 4-3. “危ない”イベントストア（競合チェックなし）😈📚

```csharp
public sealed class NaiveEventStore
{
    private readonly Dictionary<string, List<IDomainEvent>> _streams = new();

    public IReadOnlyList<IDomainEvent> ReadStream(string streamId)
        => _streams.TryGetValue(streamId, out var list) ? list.ToList() : new List<IDomainEvent>();

    // ⚠️ expectedVersion（期待する版）を見ずに、無条件で追記する
    public void Append(string streamId, IEnumerable<IDomainEvent> events)
    {
        if (!_streams.TryGetValue(streamId, out var list))
        {
            list = new List<IDomainEvent>();
            _streams[streamId] = list;
        }

        foreach (var e in events) list.Add(e);
    }
}
```

---

## 4-4. “同時更新っぽく”するために、LoadとAppendを分ける✂️🧩

リアルの競合はこういう感じ👇

* Aのリクエスト：Load → Decide（イベント作る） → Append
* Bのリクエスト：Load → Decide（イベント作る） → Append
  この2つが「ほぼ同時」に走ると、AもBも**同じ版**を見てイベントを作っちゃう😵

だから、実験では「Prepare（イベント作る）→あとでAppend」をやるよ🧪✨

```csharp
public sealed record PreparedAppend(int ExpectedVersion, IReadOnlyList<IDomainEvent> NewEvents);

public static class AccountUseCase
{
    public static PreparedAppend PrepareWithdraw(NaiveEventStore store, string streamId, decimal amount)
    {
        var history = store.ReadStream(streamId);
        var acc = BankAccount.Rehydrate(history);

        var expectedVersion = acc.Version;   // ←「この版を元に判断したよ」という印
        acc.Withdraw(amount);               // Decide（ここでイベントが作られる）

        return new PreparedAppend(expectedVersion, acc.UncommittedEvents.ToList());
    }
}
```

---

## 4-5. 競合を発生させる本体💥⚔️

```csharp
var store = new NaiveEventStore();
var id = "account-001";

// まず入金100（ストリームの版は 0 になる）
store.Append(id, new IDomainEvent[] { new MoneyDeposited(100m) });

// AとBが「同じ版（0）」を見て、同じ判断をする（ほぼ同時を再現）
var a = AccountUseCase.PrepareWithdraw(store, id, 80m);
var b = AccountUseCase.PrepareWithdraw(store, id, 80m);

Console.WriteLine($"Aが見たVersion: {a.ExpectedVersion}");
Console.WriteLine($"Bが見たVersion: {b.ExpectedVersion}");

// ⚠️ 競合チェックがないので、どっちも保存できちゃう
store.Append(id, a.NewEvents);
store.Append(id, b.NewEvents);

// 最終状態を復元してみる
var final = BankAccount.Rehydrate(store.ReadStream(id));
Console.WriteLine($"最終残高: {final.Balance}");
```

✅ 期待される実行イメージ（ざっくり）👇

* Aが見たVersion: 0
* Bが見たVersion: 0
* 最終残高: **-60** 😱💥

---

# 5) 何がヤバいの？（本質）🧠⚡

## 保存されたイベントが「嘘」になってる😵‍💫

2つ目の `MoneyWithdrawn(80)` は、**本当は残高20の世界で起きてはいけない出来事**だよね🙅‍♀️

でも競合チェックがないと👇

* 「古い状態で作られたイベント」
* がそのまま保存されちゃう…！😱

---

# 6) 図で見ると一発📈✨

```text
rev0: Deposited(100)

A: rev0 を読む → Balance=100 → Withdrawn(80) を作る
B: rev0 を読む → Balance=100 → Withdrawn(80) を作る

A: 追記 → rev1
B: 追記 → rev2   ← 本当はここで止めたい！！🛑⚔️
```

---

# 7) “競合対策”ってどんな世界観？🌍🔒

主流は **楽観的同時実行制御（Optimistic Concurrency）** だよ✨
ざっくり言うと👇

* 「競合は起きる前提」🧨
* 「保存するときに、版が変わってないかチェック」🔎
* 「変わってたら失敗にして、リトライや再入力へ」🔁

データベースでもこの考え方が一般的で、たとえばEF Coreは**concurrency token**で衝突検出をするよ([Microsoft Learn][2])
HTTPの世界でも **ETag + If-Match** みたいな形で「版が一致したら更新」をやる（考え方が同じ）よ([Microsoft Learn][3])

イベントストア界隈では「expectedVersion / expectedRevision」という言い方で、**期待する版を渡して、合ってたら追記、違ったら失敗**が定番✨
（例：`expected_version` は楽観ロックとして働く、同時書き込みでは1つだけ成功する、など）([Rails Event Store][4])
またEventStoreDB（Kurrent）の.NETクライアントでは用語を `ExpectedVersion` より明確な `ExpectedRevision` に寄せた、という話もあるよ([Kurrent Docs][5])

---

# 8) ミニ演習🎒🧪（手を動かすやつ！）

## 演習A：金額を変えて観察👀💰

* 80円 → 60円にしてみて、最終残高はいくつ？😺
* 40円/40円、70円/70円など色々試して、「どこで破綻するか」見よう💥

## 演習B：別ドメインに置き換え🍔🛒

口座じゃなくて、カートでもOK✨

* ルール：在庫は0未満ダメ📦🙅‍♀️
* 2人が同時に購入して在庫がマイナス…を再現してみよう😵‍💫

## 演習C：ログを増やす📣🧾

* `ReadStream` したときのイベント数
* `ExpectedVersion`
* `Append` 後のイベント数
  を表示して「版ズレ」を目で追えるようにしよう👀✨

---

# 9) AI活用🤖✨（この章向けの使い方）

## その1：競合シナリオを増やす🎭⚔️

* 「この口座の例みたいに、競合で壊れるシナリオを3つ（在庫/予約/クーポン）で出して。イベント名も過去形で。」

## その2：失敗するテストを作って“事故を固定”する🧪🧷

* 「この NaiveEventStore で競合を再現するGiven-When-Thenテストを書いて。期待としては“本当は2回目の保存が失敗すべき”というテストにしたい。」

## その3：ログ設計🔎🧠

* 「競合調査しやすいログ項目（streamId / expectedVersion / currentVersion / commandId等）を提案して。」

---

# 10) まとめ📌✨

* 競合は「別々の処理が、同じデータを同時に更新しようとして衝突」⚔️
* イベントソーシングでも、**古い状態で作ったイベント**が保存されると破綻する😱
* だから「保存時に版をチェックする」＝ **expectedVersion / expectedRevision** が重要🔒✅ ([Rails Event Store][4])

次章では、この実験の“穴”を **expectedVersion（楽観ロック）** で塞いで、「2回目をちゃんと止める」実装に進むよ🔧✨

[1]: https://martinfowler.com/eaaDev/EventSourcing.html?utm_source=chatgpt.com "Event Sourcing"
[2]: https://learn.microsoft.com/en-us/ef/core/saving/concurrency?utm_source=chatgpt.com "Handling Concurrency Conflicts - EF Core"
[3]: https://learn.microsoft.com/en-us/azure/cosmos-db/database-transactions-optimistic-concurrency?utm_source=chatgpt.com "Database Transactions and Optimistic Concurrency Control"
[4]: https://railseventstore.org/docs/core-concepts/expected-version?utm_source=chatgpt.com "Expected Version explained"
[5]: https://docs.kurrent.io/clients/tcp/dotnet/21.2/migration-to-gRPC?utm_source=chatgpt.com "Migration to gRPC client - Kurrent Docs"
