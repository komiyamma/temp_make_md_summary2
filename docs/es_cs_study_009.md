# 9章：不変条件（Invariants）超入門🧷🛡️

## この章でできるようになること🎯✨

* 「絶対に壊しちゃダメなルール（不変条件）」を見つけられる👀🧠
* 不変条件を“あちこちに散らさず”に守れるようになる📌✅
* 不変条件をテスト観点（Given-When-Then）に変換できる🧪🔁

---

# 9-1. 不変条件（Invariant）ってなに？🧷🤔

不変条件は、超ざっくり言うと…

> **「この世界では、これだけは絶対に起きちゃダメ！」**
> **「いつでも必ず守られてないと困る！」**

っていう **“ビジネス上のガードレール”** のことだよ🚧✨

たとえば（ショッピングカート🛒の例）

* ✅ **チェックアウト済みのカートに商品追加はできない**
* ✅ **カートが空ならチェックアウトできない**
* ✅ **数量は 1 以上（0 やマイナスはダメ）**

こういうのが不変条件候補だよ🧷🛡️

---

# 9-2. なんでイベントソーシングだと超大事？📜🔥

イベントソーシングは「状態を保存」じゃなくて「出来事（イベント）を積む」設計だったよね🔁✨
そしてイベントは **基本的に追加専用（append-only）** で、履歴として残り続ける📚🧾
だから一度「おかしなイベント」を出しちゃうと、ずっと残っちゃう可能性が高い😱💦

イベントソーシング自体の考え方（イベントを追加専用ストアに記録する）は、Microsoftのパターン解説でもこう整理されているよ📘✨ ([Microsoft Learn][1])

👉 つまり…
**「イベントを出す前に、不変条件で止める」** が超重要になるの！🛑🧷

---

# 9-3. 不変条件と“ただの入力チェック”の違い🧠🧁

ここ、よく混ざるので分けようね😊✨

## ✅ 入力チェック（Validation）

* 例：メールアドレス形式が変、必須項目が空、文字数が長すぎる
* UIやAPI層でもやる（ユーザーに優しい）📮💕

## ✅ 不変条件（Invariant）

* 例：チェックアウト済みカートに商品追加は絶対ダメ
* これは **“ドメイン（中核ルール）側で絶対守る”** 🧷🛡️
* UIをすり抜けても、最終防衛線で止める🚧✨

---

# 9-4. 不変条件はどこに置くのが正解？📍🧩

結論：**ドメインの中心（のちの章で出てくる Aggregate の中）** に集めるのが基本だよ📌✨
（Aggregate は10章で詳しくやるけど、今は「1つのルールのまとまり」くらいでOK😊）

イベントソーシング界隈でも、**集約（Aggregate）が整合性の境界になって不変条件を守る** という整理がよく使われるよ🧠🛡️ ([Event Sourcing Guide][2])

---

# 9-5. 不変条件の“見つけ方”テンプレ🕵️‍♀️✨

次の質問に「はい」が多いほど、不変条件っぽいよ✅

## 不変条件チェックリスト✅🧷

* 「それが破られると、ビジネス的に事故る？」💥
* 「一瞬でもその状態が存在したら困る？」⛔
* 「後から直すじゃなく、その場で止めたい？」🛑
* 「1つのまとまりの中だけで判断できる？」（他の集約を見ないと判断できないなら境界の相談ポイント👀）

---

# 9-6. 例で理解しよう🛒✨（ショッピングカート）

## カートの不変条件（例）🧷

1. **チェックアウト済みなら変更禁止** 🔒
2. **数量は1以上** ➕
3. **空カートはチェックアウト不可** 🕳️❌

ここで大事なのは、イベントソーシングでは

* コマンドを受け取る（例：AddItem）📮
* いまのイベント列から状態を復元する（Rehydrate）🔁
* 不変条件をチェックする🧷
* OKなら、新しいイベントを生成して保存する📜✅

という流れになりがち、ってこと✨
（この「型」は16章でガッツリ固めるよ😊）

---

# 9-7. C#で“不変条件ガード”を書いてみよう✍️🧷

ここでは最小形で、雰囲気をつかもう😊✨
（まだEventStoreとかは作らないよ。**不変条件だけに集中**！🧠）

## ① 状態（State）っぽいもの

```csharp
public sealed class CartState
{
    public bool IsCheckedOut { get; private set; }
    public Dictionary<string, int> Items { get; } = new();

    public void Apply(object @event)
    {
        switch (@event)
        {
            case ItemAdded e:
                Items[e.Sku] = Items.TryGetValue(e.Sku, out var qty) ? qty + e.Quantity : e.Quantity;
                break;

            case CheckedOut:
                IsCheckedOut = true;
                break;
        }
    }
}

public sealed record ItemAdded(string Sku, int Quantity);
public sealed record CheckedOut;
```

ポイント😊

* `Apply` は「イベントが起きた結果、状態がどう変わるか」だけを書く✍️
* **イベントが正しい前提**でスッキリ書く（正しさは“決める側”で守る）🧷✨

## ② 不変条件ガード（超シンプル版）

```csharp
public static class Invariants
{
    public static void EnsureNotCheckedOut(CartState state)
    {
        if (state.IsCheckedOut)
            throw new InvalidOperationException("チェックアウト済みのカートは変更できません。");
    }

    public static void EnsureQuantityPositive(int quantity)
    {
        if (quantity <= 0)
            throw new InvalidOperationException("数量は1以上である必要があります。");
    }

    public static void EnsureNotEmptyOnCheckout(CartState state)
    {
        if (state.Items.Count == 0)
            throw new InvalidOperationException("空のカートはチェックアウトできません。");
    }
}
```

ここでは例外にしたけど、**あとでResult型っぽく安全にする**（21章あたり）予定があるから、今は「ガードがある形」を覚えればOKだよ😊🧠

## ③ コマンド処理っぽい入口で守る（雰囲気）

```csharp
public static class CartUseCases
{
    public static ItemAdded AddItem(CartState state, string sku, int quantity)
    {
        Invariants.EnsureNotCheckedOut(state);
        Invariants.EnsureQuantityPositive(quantity);

        // OKなら「出来事」を返す（保存はまだやらない）
        return new ItemAdded(sku, quantity);
    }

    public static CheckedOut Checkout(CartState state)
    {
        Invariants.EnsureNotCheckedOut(state);
        Invariants.EnsureNotEmptyOnCheckout(state);

        return new CheckedOut();
    }
}
```

この形ができると、イベントソーシングの一番の怖さ（＝変なイベントを出す）を最初に潰せる🧷🛡️✨

---

# 9-8. ミニ演習📝✨（不変条件を3つ書いてみよう）

題材はあなたの教材ドメイン（カートでもToDoでも家計簿でもOK）でやってね😊💕

## ステップ1：まず自然言語で3つ✍️

* 「〜のとき、〜してはいけない」
* 「〜は常に〜である」
* 「〜が成り立たないなら、操作を拒否する」

例（家計簿💰）

* ✅ 残高が足りないなら出金できない
* ✅ 未来の日付の出金は登録できない（ルールなら）
* ✅ 同じ取引IDは二重登録できない（冪等性にも関係🔁）

## ステップ2：それを“if文”に落とす🔽

* 条件（if）
* エラーメッセージ（ユーザーに優しく）💬✨

## ステップ3：置き場所を決める📌

* 「画面だけ」❌
* 「DB制約だけ」❌
* **“ドメイン側”に集める** ✅🧷

---

# 9-9. 不変条件 → テスト観点への変換🧪✨

不変条件は、そのまま **失敗テスト** になりやすいよ😊🧠

例：空カートはチェックアウトできない🕳️❌

* Given：アイテム0件の状態
* When：Checkoutコマンド
* Then：エラーになる（もしくはイベントが出ない）

この形は20章で本格的にやるけど、今のうちに “変換できる感覚” を持っておくと強い💪🧪

---

# 9-10. よくある落とし穴😵‍💫⚠️

## ❶ 不変条件が散らばる🌀

UI・API・サービス・DB…あちこちに同じルールがあると、変更で地獄😇
👉 **中心に集める**📌✨

## ❷ 「ルール」じゃなく「手順」を不変条件にしちゃう

* 例：「チェックアウトは夜だけ」みたいな運用ルール
  👉 それが“絶対に守るべき本質”かは一回疑ってOK😊

## ❸ 他の集約が必要なルールで詰む

「AとBの合計が〜」みたいなやつ
👉 境界（10章）や、後のSaga/最終的整合性の話に繋がる👀✨

---

# 9-11. AI活用🤖✨（不変条件を増やして、品質を上げる）

## ① 不変条件候補を“増やす”プロンプト💡

* 「題材はショッピングカート。ユーザーが事故りそうな不変条件を10個、初心者向けに」
* 「それぞれ、破られたときに何が困るかも1行で」

## ② 不変条件を“テスト観点”に変換するプロンプト🧪

* 「この不変条件をGiven-When-Thenに変換して。成功/失敗を1本ずつ」

## ③ メッセージ改善プロンプト💬

* 「このエラーメッセージ、ユーザーに優しく、でも短くして。3案」

---

# 9-12. まとめ🌸✨

* 不変条件は「絶対に壊しちゃダメなルール」🧷🛡️
* イベントソーシングはイベントが履歴として残るから、**変なイベントを出さない設計が超重要**📜🔥 ([Microsoft Learn][1])
* 不変条件は“中心に集めて”守るのが基本📌✨（集約が整合性境界になって不変条件を守る整理がよく使われるよ）🧠🛡️ ([Event Sourcing Guide][2])
* 不変条件はテスト観点に変換しやすいから、あとで爆伸びする🧪🚀

---

[1]: https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing?utm_source=chatgpt.com "Event Sourcing pattern - Azure Architecture Center"
[2]: https://www.eventsourcing.dev/best-practices/designing-aggregates?utm_source=chatgpt.com "Designing Aggregates - Best Practices - Event Sourcing Guide"
