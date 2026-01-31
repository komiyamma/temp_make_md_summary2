# 8章：イベント命名（過去形）と“粒度”の感覚⏳✅

## この章でできるようになること🎯✨

* イベント名を「起きた事実（過去形）」として自然に付けられるようになる📚✅
* 「でかすぎ」「細かすぎ」な粒度を見分けて、ちょうどよく揃えられるようになる⚖️✨
* Command（お願い）と Event（起きた事実）を名前の時点で混ぜないようにできる🧠💡

---

# 1) まず大前提：イベントは「過去に起きたこと」🕰️📜

イベントは「こうしてほしい」じゃなくて「こうなった」だよ😊
つまり **イベント名は“過去形の動詞”** が基本になる✨
「イベントは過去に起きたもので、過去形の動詞で表すべき」と明確に説明されてるよ。

## Command と Event の違い（名前で事故らないコツ）🚧

* Command：お願い・命令（未来）📮 → `AddItemToCart`（カートに入れて！）
* Event：起きた事実（過去）📜 → `CartItemAdded`（カートに入った）✅

> **名前が Command っぽい Event** は、後で必ず混乱するよ〜😵‍💫

---

# 2) イベント命名 3つの黄金ルール👑✨

## ルール①：過去形（起きた事実）で言い切る🗣️✅

* ✅ `CartCreated` / `CartItemAdded` / `CheckoutCompleted`
* ❌ `CreateCart` / `AddItem` / `CompleteCheckout`

「イベントは過去に完了したこと」だから、言い切りが強いほどいい💪✨

---

## ルール②：ドメインの言葉（会話に出る言葉）で付ける🧸💬

イベント名は「開発者が分かる」より、**業務の人でも読める**ほうが強い🧡
（あとで監査ログを見たときに助かる…！📝）

* ✅ `OrderPlaced`（注文が確定した）
* ❌ `OrderSavedToDb`（DBに保存された）←技術の事情が混ざってる😿

---

## ルール③：名詞だけに逃げない（“何が起きたか”を動詞で）🏃‍♀️💨

名詞1語だけだと「状態？原因？結果？」が曖昧になりがち😵
「地震（Earthquake）」みたいに名詞で言えちゃう言葉でも、**動詞の過去形に寄せよう**って話があるよ。

* ❌ `Price` / `Cancellation` / `Error`
* ✅ `PriceChanged` / `OrderCanceled` / `PaymentFailed`

---

# 3) “粒度”がむずい理由：ちょうどいいが一番強い⚖️😺

## でかすぎイベント（雑すぎ）🙅‍♀️💥

例：`CartUpdated`
これ、何が起きたの？😵

* 商品が追加？削除？数量変更？クーポン適用？
  → 読み手が推理しないといけないイベントは弱い🌀

## 細かすぎイベント（バラバラ）🙅‍♀️🧩

例：
`CartItemQuantityChanged` をさらに分けて
`CartItemQuantityIncremented` / `CartItemQuantityDecremented` / `CartItemQuantitySetToValue` …
みたいに増やしすぎると、学習中は特にしんどい😇
（投影・テスト・仕様変更のコストが増える💸）

---

# 4) 粒度の決め方：5つの質問でチェック✅🧠

イベント名を決める前に、これを自分に質問してみてね😊✨

1. **この出来事は、あとで監査ログに残ってて嬉しい？**📝
2. **この出来事が起きたら、画面表示や通知が変わる？**📣
3. **この出来事は“1つの意思決定”として自然？**🎯
4. **巻き戻し（タイムトラベル）したとき意味がある単位？**🕰️
5. **「なぜそうなった？」がイベント名だけで想像できる？**🔍

YES が多いほど「ちょうどいい粒度」になりやすいよ✅✨

---

# 5) 具体例：ショッピングカートで命名してみよう🛒💕

ここでは例として「カート」を使うよ😊
（題材が別でも、やり方は同じ！）

## よくある Command（お願い）📮

* `CreateCart`
* `AddItemToCart`
* `RemoveItemFromCart`
* `ChangeItemQuantity`
* `ApplyCoupon`
* `Checkout`

## 対応する Event（起きた事実）📜

* `CartCreated`
* `CartItemAdded`
* `CartItemRemoved`
* `CartItemQuantityChanged`
* `CouponApplied`
* `CheckoutCompleted`

ここで大事なのは👇

* 「お願い」じゃなく「起きた事実」
* “何が起きたか”が一発で分かる粒度

---

# 6) 迷いやすいポイント：1つの Command から複数 Event が出てもOK？🤔✨

結論：**OK（むしろ自然なことが多い）**😊

例：`Checkout`（精算して！）の結果として

* `CheckoutCompleted`
* `PaymentAuthorized`
* `InventoryReserved`

みたいに分かれることがあるよ✅
ただし、学習の最初は **「1 Command → 1 Event」** で始めるのがラク😺✨
（複数イベントは、慣れてから増やすと安心）

---

# 7) C# でのイベント表現（最小でOK）🧱✨

イベントは「起きた事実のデータ」なので、**record** が相性いいよ😊
（今の .NET / C# では acknowledging されていて、最新環境で触れやすいよ。([Microsoft Learn][1])）

```csharp
public interface IDomainEvent
{
    Guid AggregateId { get; }
    DateTimeOffset OccurredAt { get; }
}

// カート作成
public sealed record CartCreated(
    Guid AggregateId,
    DateTimeOffset OccurredAt,
    Guid CustomerId
) : IDomainEvent;

// 商品追加
public sealed record CartItemAdded(
    Guid AggregateId,
    DateTimeOffset OccurredAt,
    Guid ProductId,
    int Quantity
) : IDomainEvent;

// 数量変更（増減も “変更” としてまとめる例）
public sealed record CartItemQuantityChanged(
    Guid AggregateId,
    DateTimeOffset OccurredAt,
    Guid ProductId,
    int NewQuantity
) : IDomainEvent;
```

## 命名が良いと、コードも読みやすくなる📖💖

`CartItemAdded` を見た瞬間に
「カートに商品が追加されたんだな」って分かるよね😊✨
これがイベント命名の勝ちポイント🏆

---

# 8) よくある “ダメ例” → “改善” 変換集🔁🙆‍♀️

## ❌ ダメ：技術の事情が混ざる

* `CartSaved` / `CartUpdatedInDb`
  ✅ 改善：
* `CartCreated` / `CartItemAdded` / `CartItemRemoved`

## ❌ ダメ：状態っぽい（何が起きた？が弱い）

* `CartIsValid`
  ✅ 改善：
* `CartValidated`（検証に通った）
* もしくは **Event にしない**（単なる計算結果ならイベントじゃなくてOK）

## ❌ ダメ：広すぎ

* `CartChanged`
  ✅ 改善：
* `CartItemAdded` / `CartItemQuantityChanged` / `CouponApplied`

---

# 9) ミニ演習①：命名候補を10個出して、3つに絞ろう🎯✨

## 手順📝

1. カートの出来事を「日本語で」10個書く（例：商品を入れた、クーポンを適用した…）
2. それを **過去形の英語（PascalCase）** にする
3. 3つに絞る（理由も書く）✍️

## 絞るときのコツ🧠

* “画面に出したい出来事”を優先すると失敗しにくい📺✨
* “監査ログに残したい出来事”も強い📝🔥

---

# 10) ミニ演習②：AIに「ダメ例」を作らせて直そう🤖🙅‍♀️➡️🙆‍♀️

AIにお願いすると、違いが一気に分かるよ😊✨
（GitHub の Copilot でも、OpenAI の Codex 系でもやり方は同じだよ🤖💡）

## 使えるプロンプト例📌

```text
あなたはDDDとイベントソーシングの先生です。
題材は「ショッピングカート」。
イベント名の “ダメ例” を10個作ってください（理由も添えて）。
その後、それぞれを “良いイベント名（過去形の動詞）” に直してください。
命名は PascalCase の英語で。
```

ポイント：

* **ダメ例に理由を付けさせる**と学びが爆増する📈✨

---

# 11) ミニ演習③：粒度を3段階で作って比べよう📏✨

同じ出来事を「大・中・小」で作ると、粒度が掴めるよ😊

例：商品をカートに入れた🛒

* 大：`CartUpdated`（雑）😿
* 中：`CartItemAdded`（ちょうどよいことが多い）✅
* 小：`CartItemAddedWithPriceAtThatTimeAndCampaignInfo...`（盛りすぎ）😵‍💫

## 判断のコツ🔍

* 中（ちょうどよい）を基本にして、
  **「後で絶対に必要な事実」だけ**を payload に残すのが強い💪✨

---

# 12) まとめ：この章の合格ライン💮🎉

* イベント名は **「起きた事実」＝過去形**で付ける⏳✅
* “名詞だけ”や“技術の事情”に逃げず、ドメインの言葉で言い切る🧸💬
* 粒度は「監査に嬉しい？」「表示に効く？」「1つの意思決定？」でチェックする⚖️✨

（補足：最新の .NET は LTS として提供されていて、現行の開発体験も更新され続けてるよ。([Microsoft for Developers][2])）

[1]: https://learn.microsoft.com/ja-jp/dotnet/csharp/whats-new/csharp-14?utm_source=chatgpt.com "C# 14 の新機能"
[2]: https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/?utm_source=chatgpt.com "Announcing .NET 10"
