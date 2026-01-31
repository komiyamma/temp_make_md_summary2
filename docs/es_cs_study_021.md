# 第21章：エラーモデリング超入門（Result型っぽい考え）🚦😊

## この章でできるようになること🎯✨

* 「例外（Exception）」に頼りすぎず、**“起きて当然の失敗”** をキレイに扱えるようになる😊
* **ドメインエラー**（ルール違反・入力ミスなど）と **インフラエラー**（DB落ち・ネットワーク断など）を分けられる🧠🔍
* `Result<T>` みたいな形で、**成功/失敗を型で表現**できる💎✅
* テスト（Given-When-Then）で **失敗ケースも読みやすく** 書ける🧪🌸
* （Web APIにしたい時に）**Problem Details** で返す形の入口も知れる📮✨（ASP.NET Coreのエラー処理として用意されてるよ）([Microsoft Learn][1])

---

# 1. まず「例外を暴れさせない」ってどういうこと？😵‍💫➡️😊

C#でよくあるのがこれ👇

* ルール違反（例：カートが空なのに注文）
* 入力ミス（例：数量がマイナス）
* 対象が見つからない（例：存在しない商品ID）

こういう **“よくある失敗”** にも例外を投げまくると…

* ログが赤く染まる🔥🧯（でも実は想定内の失敗）
* 呼び出し元が `try/catch` 地獄になる🌀
* 「失敗が仕様」なのに、「失敗＝異常」みたいな雰囲気になって、設計がグチャる😿

なのでこの章では、

* **起きて当然の失敗（ドメインエラー）** は `Result` で返す🚦
* **本当に異常（インフラエラー）** は例外でOK（ただし境界でまとめて処理）🧯

っていう整理をやっていくよ😊✨

---

# 2. ドメインエラー vs インフラエラー🔍🗂️

## ✅ ドメインエラー（Resultで返したい）🧩

「仕様として起こりうる失敗」だよ。

* 入力値が不正（Validation）✏️
* ビジネスルール違反（Rule Broken）🛡️
* 対象が存在しない（Not Found）🔎
* 競合（Conflict）⚔️（これは次章以降で深掘り！）

👉 **“ユーザーに説明して、行動してもらえる”** 失敗が多い😊

## ✅ インフラエラー（例外でOKなことが多い）🧯

「今は処理できない」系だよ。

* DB接続エラー💥
* ファイル読み書き失敗📁
* ネットワーク断📡
* タイムアウト⏱️

👉 **“再試行”や“運用対応”が必要** になりやすい😌

---

# 3. Result型の最小セットを作ろう💎✨

ここでは「めっちゃ小さい Result」を作るよ😊
ポイントはこれ👇

* **成功**：値を持つ
* **失敗**：ドメインエラーを持つ
* **例外は投げない**（ドメインエラーの場合）

## 3.1 DomainError（ドメインエラー）を型にする🏷️🧠

```csharp
public sealed record DomainError(
    string Code,
    string Message,
    string? Target = null
)
{
    public static DomainError Validation(string message, string? target = null)
        => new("validation_error", message, target);

    public static DomainError RuleBroken(string message, string? target = null)
        => new("rule_broken", message, target);

    public static DomainError NotFound(string message, string? target = null)
        => new("not_found", message, target);

    public static DomainError Conflict(string message, string? target = null)
        => new("conflict", message, target);
}
```

* `Code` は **機械向け**（後でHTTPのステータスやUI表示分岐に便利）🤖
* `Message` は **人間向け**（ただし内部情報を漏らさない）🗣️
* `Target` は **どの項目？** を指せる（`quantity` とか）🎯

---

## 3.2 Result<T> を作る🚦✅❌

```csharp
public readonly struct Result<T>
{
    public bool IsSuccess { get; }
    public T? Value { get; }
    public DomainError? Error { get; }

    private Result(bool isSuccess, T? value, DomainError? error)
    {
        IsSuccess = isSuccess;
        Value = value;
        Error = error;
    }

    public static Result<T> Success(T value) => new(true, value, null);

    public static Result<T> Fail(DomainError error) => new(false, default, error);
}
```

この形にすると、呼び出し側はこう書ける👇

```csharp
var result = DoSomething();

if (!result.IsSuccess)
{
    Console.WriteLine(result.Error!.Message);
    return;
}

Console.WriteLine(result.Value);
```

**try/catch が消えてスッキリ**しやすいよ😊✨

---

# 4. 「Command処理の型」に Result を入れてみよう📮➡️🚦

ここからは、イベントソーシングの “いつもの流れ” に入れるよ💡

* Load（イベント読み）🔁
* Decide（不変条件チェック＆イベント生成）🛡️
* Append（イベント保存）📦

## 4.1 例：数量変更コマンド（超ミニ）🧺🔢

「数量を変更する」って、実は失敗がいっぱいあるよね😳

* 数量がマイナス❌
* 対象アイテムが存在しない❌
* （次章以降）同時更新で競合❌

ここでは **ドメインエラーをResultで返す** に寄せるよ😊

---

## 4.2 Decide（ドメインルールの中心）を Result にする🧠🛡️

例として、集約の状態をこのくらいミニで置くね👇

```csharp
public sealed class CartState
{
    private readonly Dictionary<string, int> _items = new();

    public IReadOnlyDictionary<string, int> Items => _items;

    public void Apply(object @event)
    {
        switch (@event)
        {
            case ItemAdded e:
                _items[e.Sku] = _items.TryGetValue(e.Sku, out var q) ? q + e.Quantity : e.Quantity;
                break;

            case ItemQuantityChanged e:
                _items[e.Sku] = e.NewQuantity;
                break;
        }
    }
}

public sealed record ItemAdded(string Sku, int Quantity);
public sealed record ItemQuantityChanged(string Sku, int NewQuantity);
```

そして「数量変更」を Decide する👇

```csharp
public static class CartDecider
{
    public static Result<ItemQuantityChanged> DecideChangeQuantity(
        CartState state,
        string sku,
        int newQuantity
    )
    {
        if (string.IsNullOrWhiteSpace(sku))
            return Result<ItemQuantityChanged>.Fail(
                DomainError.Validation("SKUが空だよ🥺", "sku")
            );

        if (newQuantity < 0)
            return Result<ItemQuantityChanged>.Fail(
                DomainError.Validation("数量は0以上だよ🥺", "quantity")
            );

        if (!state.Items.ContainsKey(sku))
            return Result<ItemQuantityChanged>.Fail(
                DomainError.NotFound("その商品はカートに入ってないよ😿", "sku")
            );

        // ルールOK ✅ → 新イベントを返す
        return Result<ItemQuantityChanged>.Success(
            new ItemQuantityChanged(sku, newQuantity)
        );
    }
}
```

ここが超大事💡
**ルール違反は例外じゃなく Result.Fail** で返してるよ🚦❌

---

# 5. エラーを “上位” に持ち上げる時のルール🪜✨

Resultは便利だけど、「上に上げる」時のコツがあるよ😊

## ✅ コツ1：ドメイン層は “エラーの種類” を固定する🧱

* `validation_error` / `rule_broken` / `not_found` / `conflict` …みたいに、**数を増やしすぎない**
* `Message` はUIで見せる場合もあるから、**丁寧で短く**💬✨

## ✅ コツ2：インフラ例外は境界でまとめて握る🧯

アプリ層（ユースケース）で `try/catch` して、

* ドメインエラー → Result
* インフラ例外 → ログ＋「一時的に失敗」みたいな扱い

に寄せると、ドメインが汚れにくいよ😊

---

# 6. （Web APIの入口）Problem Details にのせる📮✨

Web APIでよくある「エラーの返し方」を標準化したのが **Problem Details** だよ😊
最近は **RFC 9457** が最新の仕様として整理されていて、RFC 7807 を置き換える形になってるよ📘✨([RFC Editor][2])

ASP.NET Core でも Problem Details を扱う仕組みが用意されていて、`AddProblemDetails` や `IProblemDetailsService` が説明されてるよ🛠️([Microsoft Learn][1])

## 6.1 Result → HTTPステータス の超定番マッピング🗺️

* `validation_error` → **400 Bad Request**
* `not_found` → **404 Not Found**
* `conflict` → **409 Conflict**
* `rule_broken` → **422 Unprocessable Entity**（よく使われるやつ）

「コード（Code）」があると、こういう分岐が簡単になる😊✨

---

# 7. テストの型：失敗ケースが主役🧪🌸

Result設計のうれしさは **失敗テストが読みやすい** こと✨
Given-When-Thenでいくよ！

## 7.1 例：数量がマイナスなら validation_error ❌

```csharp
using Xunit;

public class CartDeciderTests
{
    [Fact]
    public void ChangeQuantity_negative_quantity_returns_validation_error()
    {
        // Given
        var state = new CartState();
        state.Apply(new ItemAdded("SKU-1", 1));

        // When
        var result = CartDecider.DecideChangeQuantity(state, "SKU-1", -1);

        // Then
        Assert.False(result.IsSuccess);
        Assert.Equal("validation_error", result.Error!.Code);
        Assert.Equal("quantity", result.Error!.Target);
    }
}
```

* 「例外が投げられたか」じゃなくて
* **「どんな失敗が返るか」** をテストしてる😊✅

---

# 8. ミニ演習🧩✍️（手を動かすと一気に分かるよ！）

## 演習1：分類ゲーム🗂️🎮

次の失敗を「ドメイン / インフラ」に分けてみてね😊

* 数量がマイナス
* 注文確定後にキャンセルしようとした
* SQLiteがロックされて書き込めない
* 読み込み中にタイムアウト
* カートに無い商品を変更しようとした

👉 その理由も1行で書こう📝✨

---

## 演習2：DomainError を3種類増やしてみよう➕🏷️

例：

* `unauthorized`（権限なし）🔐
* `already_exists`（二重登録）♻️
* `rate_limited`（回数制限）⏳

ただし増やしすぎ注意だよ😺

---

## 演習3：Decide関数をもう1個作る🛠️

「アイテム削除」みたいなのが作りやすい😊

* SKUが空 → validation_error
* 存在しない → not_found
* OK → `ItemRemoved` イベント

---

## 演習4：失敗テストを2本追加🧪✨

* SKU空で失敗する
* 存在しないSKUで not_found

---

# 9. AI活用（この章の“使いどころ”）🤖✨

## 9.1 エラーの抜け漏れチェック👀

「このDecideで起こりうる失敗、漏れてない？」って聞くと強いよ💪

```text
次のC#コードのDecide関数について、
起こりうるドメインエラー（入力ミス・ルール違反・not found・conflict等）の抜け漏れを列挙して。
各エラーに Code / Message / Target の案も出して。
```

## 9.2 メッセージを“やさしく短く”整える💬🌸

```text
DomainErrorのMessage案を、女子大生にも読みやすい短文に整えて。
責める言い方は避けて、行動が分かる言い方にして。
```

## 9.3 テストをGiven-When-Thenで量産🧪

```text
次のDecide関数に対して、Given-When-ThenのxUnitテストを
成功1本、失敗2本（validation / not_found）作って。
Assertは Code と Target を必ず確認して。
```

---

# 10. まとめ（この章のコア）🌟

* **ドメインエラーは “仕様として起きる失敗”** → Resultで返す🚦
* **インフラエラーは “いま処理できない”** → 例外でOK（境界で処理）🧯
* `DomainError(Code, Message, Target)` を持つと、UI/API/テストまで全部ラクになる😊
* Web APIにするなら **Problem Details**（最新の流れはRFC 9457）も視野に入るよ📮✨([RFC Editor][2])

---

## おまけ：この章の位置づけ📍

この章で「失敗を型で扱う」土台ができたから、次の **競合（同時更新）** がスムーズになるよ⚔️😊

[1]: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling-api?view=aspnetcore-10.0&utm_source=chatgpt.com "Handle errors in ASP.NET Core APIs"
[2]: https://www.rfc-editor.org/rfc/rfc9457.html?utm_source=chatgpt.com "RFC 9457: Problem Details for HTTP APIs"
