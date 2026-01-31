# 10章：Aggregate（集約）と境界の決め方🐣🧩

## この章でできるようになること🎯✨

* 「どこまでを1つのまとまりとして扱うか（=境界）」を、**迷子にならず**決められるようになる🧭💡
* その結果、イベントが「散らばらず」「肥大せず」、あとあと楽になる😊✨
* 「1つの集約＝だいたい1つのイベントストリーム」という感覚がつかめる📼🔁 ([Microsoft Learn][1])

---

## まず結論：Aggregateってなに？🐣

Aggregate（集約）は、ざっくり言うと…

**「一緒に整合性を守る必要があるものを、ひとまとめにした“島”」**🏝️
そして、その島の入口が **Aggregate Root（集約ルート）** だよ🚪✨

* Aggregateは **整合性（Consistency）を守る境界** になる🧷🛡️ ([Microsoft Learn][1])
* 外から触るのは **Rootだけ**（子ども達はRoot経由で操作）👩‍👧‍👦🔒 ([Microsoft Learn][1])
* まとめて「1つの単位」として扱うと嬉しい（保存・更新・ルール適用がスッキリ）📦✨ ([martinfowler.com][2])

> 覚え方：
> **Root = “この島の市役所”**🏛️
> 何か変更したいなら、市役所に申請しようね、みたいな感じ😊📝

---

## なぜ境界が大事？（ブレると地獄👹）

境界が雑だと、こんな事故が起きやすい💥😵‍💫

* 「1回のコマンドで、いろんな場所のデータを同時に整合させたい」欲が出る
  → 集約が巨大化（イベント多すぎ・復元つらい）🧟‍♀️📚
* 「どのルールをどこで守るの？」が曖昧
  → 不変条件（Invariants）が散らかる🧷🌀
* Event Sourcingだと、集約の単位がそのまま「ストリームの単位」になりがち
  → 境界が悪いとストリームも運用も辛くなる📼😵 ([Microsoft Learn][1])

---

# 境界を決める“超実用”3ステップ🧠✨

## ステップ1：絶対に守りたいルール（不変条件）を集める🧷🛡️

まずは「これ破ったらダメ！」を集めるよ✍️

例（ショッピングカート🛒の場合）：

* 1つのカートで、同じ商品は行が重複しない（数量で管理）📦
* 数量は1以上📈
* カートが確定（注文化）したら、もう変更できない🔒

この「守りたいルール」が、境界の中心になる🧲✨
Aggregate Rootは、**整合性の番人**として振る舞うのが基本だよ👮‍♀️✅ ([Microsoft Learn][3])

---

## ステップ2：「同時に整合してないと困る範囲」を決める⚖️

ここがいちばん大事！💓
判断基準はシンプル👇

✅ **“今この瞬間”に整合してないと困る？**

* 困る → 同じAggregateに入れる候補
* 困らない（あとで追いつけばOK） → 別Aggregateに分ける候補

MicrosoftのDDD解説でも、Aggregateは「整合性境界」として説明されてるよ📘✨ ([Microsoft Learn][1])

---

## ステップ3：Root（入口）を1つ決める🚪✨

Aggregateの中に複数オブジェクトがいてもOK🙆‍♀️
でも **入口（Root）は1つ**にするのが基本！

* RootのIDで見つける（ロードする）🔎
* 子どもはRootから辿る（外から直接参照しない）🧶
  この形が「境界が崩れない」コツだよ😊 ([Microsoft Learn][1])

---

# 例：ショッピングカート🛒で境界を2案作って比べよう⚖️

## 案A：Cart集約（おすすめ寄り✨）

**Cart（Root）** の中に CartItems（子）を持つ。

* Cartが守るルール

  * アイテムの重複禁止
  * 数量の増減
  * 確定後は変更禁止
* 他のもの（例：在庫・商品情報）は **別集約**にして、CartからはID参照だけにする

  * ProductId だけ持つ、とかね🏷️

こうすると「カート内の整合性」がきれいに閉じる🧼✨
Aggregateはビジネス要件から導く（技術都合じゃなく）っていう考え方にも合うよ🧠 ([Microsoft Learn][4])

---

## 案B：Cart + Inventory まで同じ集約（ありがち罠😵‍💫）

「カートに入れるとき在庫も減らしたい！」って思って…

* Cartの操作でInventoryも同時更新したくなる
* すると「在庫の整合性」まで同じ境界に混ざって、集約が巨大化しやすい🧟‍♀️💥
* Event Sourcingだと、ストリームも長くなりがちで運用・性能がつらくなる方向へ…📼😵 ([Kurrent - event-native data platform][5])

---

## 2案を“1分で”比較する表📋✨

| 観点                 | 案A：Cartだけ集約🛒     | 案B：Cart+Inventory集約🧟‍♀️                                    |
| ------------------ | ----------------- | ----------------------------------------------------------- |
| ルールの置き場所🧷         | Cartに集中して分かりやすい😊 | ルールが絡まって混乱しやすい😵                                            |
| 変更の影響範囲🔧          | 小さく済みやすい✨         | 大きくなりやすい💥                                                  |
| 競合（同時更新）⚔️         | カート単位で起きる         | 在庫更新まで巻き込まれやすい                                              |
| Event Sourcing運用📼 | ストリームが素直になりやすい    | ストリーム肥大のリスク増えがち ([Kurrent - event-native data platform][5]) |

---

# 「1集約＝1ストリーム」ってどういう気持ち？📼🧠

Event Sourcingでは、集約の変更はイベントとして積まれるよね🔁
このとき実務では、**“集約ごとにストリームを分ける”**設計がよく使われるよ📼✨

* ストリームを短く保つ（運用・性能の観点）という話もよく出る📏 ([Kurrent - event-native data platform][5])
* だからこそ、集約境界が雑だと「イベントが多すぎ問題」が起きやすい😵‍💫

イメージ図👇（雰囲気でOK😊）

```text
Cart-123 (1ストリーム)
  v1  CartCreated
  v2  ItemAdded(product=A, qty=1)
  v3  ItemQtyChanged(product=A, qty=2)
  v4  CouponApplied(code=WINTER)
```

---

# C#で“境界が崩れない”最小の形（例）🧩✨

ポイントはこれ👇

* 外から触れるのは `Cart`（Root）だけ
* `CartItem` は内部の子（外から直接いじらない）🔒

```csharp
public readonly record struct CartId(Guid Value);
public readonly record struct ProductId(Guid Value);

public sealed class Cart
{
    private readonly Dictionary<ProductId, int> _items = new();
    public CartId Id { get; }
    public bool IsCheckedOut { get; private set; }

    private Cart(CartId id) => Id = id;

    // Rootだけが外部API（入口）になるイメージ🚪
    public static (Cart cart, object @event) Create(CartId id)
        => (new Cart(id), new CartCreated(id));

    public object AddItem(ProductId productId, int qty)
    {
        if (IsCheckedOut) throw new InvalidOperationException("確定後は変更できません");
        if (qty <= 0) throw new ArgumentOutOfRangeException(nameof(qty));

        // ここで「同じ商品は重複しない」ルールを守る🧷
        var newQty = _items.TryGetValue(productId, out var current) ? current + qty : qty;
        return new ItemAdded(Id, productId, qty, newQty);
    }

    // Eventを適用して状態を作る（Rehydrateの準備）🔁
    public void Apply(object @event)
    {
        switch (@event)
        {
            case CartCreated e:
                // 生成時は必要なら初期化
                break;

            case ItemAdded e:
                _items[e.ProductId] = e.NewTotalQty;
                break;

            case CheckedOut:
                IsCheckedOut = true;
                break;
        }
    }
}

public sealed record CartCreated(CartId CartId);
public sealed record ItemAdded(CartId CartId, ProductId ProductId, int AddedQty, int NewTotalQty);
public sealed record CheckedOut(CartId CartId);
```

この形にしておくと、
「他の集約（在庫とか）を一緒に更新したい…」って誘惑が来ても、境界を守りやすい😊🛡️
（別集約の更新は、**別のコマンド/別の処理**で扱う方向に自然と寄るよ）

---

# よくある境界ミス集（先に踏み抜きを回避🕳️🚫）

## ミス1：表示に必要だから、他の集約の情報を全部持ちたくなる😵

例：Cartのイベントに「商品名・価格・画像URL」まで全部入れる…
→ 将来変更に弱くなりやすい（更新地獄）🧟‍♀️

目安：

* **整合性に必要な“事実”**は入れる
* **表示都合**は Projection 側（後半の章）で作る方向がラク🔎✨

## ミス2：「とりあえず全部1つの集約」にする😇

→ コマンドが増えるほど、Rootが巨大化🧟‍♀️
→ ストリームも長くなりがち📼😵 ([Kurrent - event-native data platform][5])

## ミス3：Root以外を外から直接触る（境界が崩壊）💥

Aggregate Rootは更新の入口にする、って原則が超大事🚪✨ ([Microsoft Learn][3])

---

# ミニ演習（境界案を2つ作って比較）⚖️📝✨

題材：ショッピングカート🛒（または自分の題材でもOK🙆‍♀️）

## やること①：不変条件を3つ書く🧷

例：

* 重複禁止
* 数量は1以上
* 確定後は変更不可

## やること②：境界案を2つ作る🧩

* 案A：Cartだけ集約
* 案B：Cart + Coupon まで集約（あるいは在庫まで、など）

## やること③：比較メモを書く📋

* “今この瞬間”に整合してないと困るのはどれ？⚡
* どの案がルールをRootに集められる？🧷
* 将来の変更に強そうなのは？🔧

---

# AI活用（Copilot / OpenAI系ツール / GitHub）🤖✨

## 1️⃣ 境界案を2つ出してもらうプロンプト🪄

```text
題材は「ショッピングカート」です。
イベントソーシング前提で、Aggregate（集約）の境界案を2つ提示してください。

条件：
- それぞれ「集約に入れるもの / 入れないもの」を列挙
- 各案のメリット・デメリット
- 「守るべき不変条件（Invariants）」を各案でどう守るか
- 1集約=1イベントストリームの設計にした場合のイメージも添える
短くてOK、箇条書き中心で。
```

## 2️⃣ “今この瞬間の整合性”チェック🧠✅

```text
次のルール一覧を「同一Aggregateで即時整合が必要か？」で分類して。
分類は「同一集約に入れる候補 / 別集約に分ける候補」の2つ。
さらに、その理由を1行ずつ。

（ここにルールを箇条書きで貼る）
```

## 3️⃣ RootのAPI案（メソッド）を作らせる🧰

```text
Aggregate Root を1つ決めた前提で、
外部から呼べる公開メソッド（コマンド処理の入口）を列挙して。
各メソッドが発行しそうなイベント名（過去形）もセットで。
```

---

# まとめ🌸✨

* Aggregateは「整合性を守る境界」で、Rootが入口🚪🛡️ ([Microsoft Learn][1])
* 境界は「今この瞬間に整合してないと困るか？」で決める⚡
* Event Sourcingでは、境界がそのままストリーム設計に効きやすい📼🔁 ([Kurrent - event-native data platform][5])
* 迷ったら「小さめに作る → ルールが増えて本当に必要なら広げる」寄りが事故りにくい😊✨ ([Microsoft Learn][4])

---

# ちいさな理解チェック✅📝

1. Aggregate Rootだけを入口にする理由を、ひとことで言うと？🚪
2. 「同一集約に入れる/分ける」を決めるときの質問は？⚖️
3. カートと在庫を同一集約にしたくなる理由は何で、何が危険？🧨

---

[1]: https://learn.microsoft.com/en-us/azure/architecture/microservices/model/tactical-ddd?utm_source=chatgpt.com "Using tactical DDD to design microservices"
[2]: https://martinfowler.com/bliki/DDD_Aggregate.html?utm_source=chatgpt.com "D D D_ Aggregate"
[3]: https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-domain-model?utm_source=chatgpt.com "Designing a microservice domain model - .NET"
[4]: https://learn.microsoft.com/en-us/azure/architecture/microservices/model/microservice-boundaries?utm_source=chatgpt.com "Identify microservice boundaries - Azure Architecture Center"
[5]: https://www.kurrent.io/blog/how-to-model-event-sourced-systems-efficiently/?utm_source=chatgpt.com "How To Model Event-Sourced Systems Efficiently - Kurrent.io"
