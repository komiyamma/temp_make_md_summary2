# 第11章：状態遷移を“手書き”してみる ✍️🔁

## 11.1 この章でできるようになること 🎯✨

* 「イベント（出来事）」が起きたときに、**状態（いまの姿）がどう変わるか**を説明できるようになる😊
* **状態遷移表（ステート表）**を作って、抜け漏れに気づける👀💡
* 次の章以降で作る `Apply`（イベント適用）の“設計図”を先に用意できる🧩✅

---

## 11.2 まずは超ざっくり：状態ってなに？ 🧠🌸

イベントソーシングでは、データを「最新の状態だけ」ではなく、**出来事（イベント）の積み重ね**として持ちます📜✨
でも実際に画面に出したり、判断したりするときは、結局 **“いまの状態”** が必要です💡

* **イベント**：起きた事実（過去形）📜
* **状態**：イベントを積み上げて復元した「いま」📸

この章は、「イベント → 状態変化」を **紙に書けるくらい具体化**して、迷子を防ぐ回です🗺️😊

---

## 11.3 例題ドメイン：ミニ“ショッピングカート” 🛒✨

ここでは学習用に、すごく小さなカートを題材にします😊
（あなたの題材がカートじゃなくても、作り方は同じだよ👌✨）

### カートでやりたいこと（最小）🧺

* カートを作る🆕
* 商品を追加する➕
* 商品を減らす➖
* 購入を確定する✅

---

## 11.4 「状態」を先に決める 📌🧩

イベントソーシングの状態は、**DBのカラム一覧**みたいに考えるより、まずは「ざっくり段階」で考えるのが楽です😊

### 状態（State）の候補 🌱➡️🌳

* `NotCreated`（まだ無い）😶
* `Active`（編集中）🛒
* `CheckedOut`（購入確定済み）✅
* `Cancelled`（破棄/キャンセル）🗑️

> コツ：状態は「画面の画面遷移」じゃなくて、**ドメイン的に意味が変わる境目**だけにするよ⚠️😊

---

## 11.5 「イベント」を並べる（過去形）📜⏳

イベントは「やったこと（命令）」じゃなくて「起きた事実」です✨
（例：AddItem ではなく **ItemAdded**）

例として、こんなイベントにします👇😊

* `CartCreated`（カートが作られた）🆕
* `ItemAdded`（商品が追加された）➕
* `ItemRemoved`（商品が減らされた）➖
* `CheckedOut`（購入が確定した）✅
* `CartCancelled`（カートが破棄された）🗑️

---

## 11.6 状態遷移表（ステート表）を作ろう 🗒️✨

### ① まずは「イベントが起きたら状態はどこへ？」だけ書く ✍️

いきなり完璧にしなくてOK！まずは **矢印だけ**でも十分です😊

```text
NotCreated --(CartCreated)--> Active
Active     --(CheckedOut)--> CheckedOut
Active     --(CartCancelled)--> Cancelled
```

### ② 次に「どんなときに起きていい？」（不変条件）を書く 🛡️🧷

不変条件（Invariants）は「絶対守りたいルール」でしたね😊
状態遷移表に入れると、**ルールが散らからない**です✨

* 空のカートは購入できない🙅‍♀️
* 購入後に商品を追加できない🙅‍♀️
* マイナス個数にならない🙅‍♀️

### ③ 最終形：状態遷移表（おすすめフォーマット）📋✨

| 今の状態 🧠    | 起きるイベント 📜    | 起きていい条件（不変条件）🛡️ | 次の状態 🔁    | 状態の変化（メモ）📝   |
| ---------- | ------------- | ---------------- | ---------- | ------------- |
| NotCreated | CartCreated   | まだ作られていない        | Active     | カートIDを持つ      |
| Active     | ItemAdded     | 購入確定前            | Active     | Items に追加     |
| Active     | ItemRemoved   | 対象が存在し、0未満にならない  | Active     | Items を減らす/消す |
| Active     | CheckedOut    | Items が空じゃない     | CheckedOut | 購入日時などを保持     |
| Active     | CartCancelled | 購入確定前            | Cancelled  | 以後変更禁止        |
| CheckedOut | ItemAdded     | （禁止）             | （なし）       | 起こしてはいけない❌    |
| Cancelled  | ItemAdded     | （禁止）             | （なし）       | 起こしてはいけない❌    |

> 💡ポイント：**「禁止の行」も書く**と、あとで実装・テストがラクになるよ😊✨

---

## 11.7 “抜け漏れ”を見つけるコツ 👀🔍

状態遷移表ができたら、次のチェックをします✅

### チェック1：各状態に「あり得ないイベント」が混ざってない？ 🚫

* `CheckedOut` に `ItemAdded` が来たら…おかしいよね？😵
  → こういうのが **バグの入口** です💥

### チェック2：「失敗イベント」を作るべき？ ⚠️

イベントソーシングは「失敗もイベントにする？」問題が出ます。
この教材では最初はシンプルに、**失敗はイベントにせず、コマンドが弾かれる（エラー）**でOK🙆‍♀️✨
（失敗をイベント化するのは、必要になったときで大丈夫😊）

### チェック3：「状態が足りない」サイン 🧩

状態遷移がごちゃつくときは、状態が少なすぎることがあります💡
例：購入確定の途中段階（支払い中など）を扱うなら `PendingPayment` が欲しくなる…みたいな感じ😊

---

## 11.8 次章への橋渡し：この表が `Apply` の設計図になる 🧱➡️💻

次の章以降で「イベントから状態を復元（Rehydrate）」するとき、基本はこうです👇

* `Apply(ItemAdded)` は **Active のときだけ意味がある**
* `Apply(CheckedOut)` が呼ばれたら **CheckedOut に変わる**

つまり、状態遷移表はそのまま **`Apply` 実装の仕様書**になります📘✨

---

## 11.9 最小コード例：イベント → 状態を更新する（イメージ）👩‍💻✨

この章は“手書き”が主役だけど、イメージ用に最小だけ載せます😊

```csharp
public enum CartStatus
{
    NotCreated,
    Active,
    CheckedOut,
    Cancelled
}

public interface IEvent;

public record CartCreated(Guid CartId) : IEvent;
public record ItemAdded(string Sku, int Quantity) : IEvent;
public record ItemRemoved(string Sku, int Quantity) : IEvent;
public record CheckedOut(DateTimeOffset At) : IEvent;
public record CartCancelled(DateTimeOffset At) : IEvent;

public sealed class CartState
{
    public CartStatus Status { get; private set; } = CartStatus.NotCreated;

    // 超簡略：本当はSKUごとの数量をDictionaryなどで持つ
    public int TotalQuantity { get; private set; } = 0;

    public void Apply(IEvent e)
    {
        switch (e)
        {
            case CartCreated:
                Status = CartStatus.Active;
                break;

            case ItemAdded added:
                // 本当は「StatusがActiveか」「数量が正か」などを確認したくなる
                TotalQuantity += added.Quantity;
                break;

            case ItemRemoved removed:
                TotalQuantity -= removed.Quantity;
                break;

            case CheckedOut:
                Status = CartStatus.CheckedOut;
                break;

            case CartCancelled:
                Status = CartStatus.Cancelled;
                break;

            default:
                throw new NotSupportedException($"Unknown event: {e.GetType().Name}");
        }
    }
}
```

> ⚠️ここでは “分かりやすさ優先” で、ガチガチの例外処理などは省略しています😊
> 本番では「禁止イベントが来たとき」をどう扱うか（弾く/無視/壊す）をちゃんと決めるよ🧯✨

---

## 11.10 ミニ演習：自分の題材で「状態遷移表」を作る 🧪🗒️✨

### ステップA：状態を3〜5個に絞る 🧩

* 状態は増やしすぎない！最初は少なめが正解😊

### ステップB：イベントを5〜10個出す 📜

* ぜんぶ過去形にする（〜された）✨

### ステップC：表にする（これをそのまま埋めてね）📝

| 今の状態 | イベント | 条件（不変条件） | 次の状態 | メモ |
| ---- | ---- | -------- | ---- | -- |
|      |      |          |      |    |
|      |      |          |      |    |
|      |      |          |      |    |

### ステップD：禁止パターンも3つ書く 🚫

* 「この状態でこのイベントは絶対起きない」ってやつ😊
  これが後でテストの宝になります💎🧪

---

## 11.11 AI活用（コピペOK）🤖✨

AI拡張に投げるときは、**“あなたが作った表”を材料にしてレビューさせる**のがコツです😊

### プロンプト1：抜け漏れチェック👀

```text
以下の状態遷移表をレビューして、抜け漏れ（必要そうなのに無いイベント/状態）と、
矛盾（禁止すべき遷移）を指摘して。初心者向けに理由も書いて。

【状態遷移表】
（ここに貼る）
```

### プロンプト2：不変条件→テスト観点に変換🧪

```text
この状態遷移表の「条件（不変条件）」から、Given-When-Thenのテスト観点を10個作って。
成功ケースと失敗ケースが混ざるようにして。
```

### プロンプト3：`Apply` 実装の下書き生成🧱

```text
この状態遷移表をもとに、C#でイベント適用(Apply)の骨組みを作って。
switchパターンでイベントごとに分岐し、禁止ケースは分かるようにコメントを入れて。
```

---

## 11.12 この章のまとめ ✅🎉

* 状態遷移表は、イベントソーシングの「迷子防止マップ」🗺️✨
* **禁止の遷移も書く**と、実装とテストが超ラクになる😊🧪
* 次の章（イベントの中身・メタデータ）や、後半の `Apply` 実装に直結するよ🔁💻

---

## 参考：2026年2月1日時点の“いま”のC#/.NETまわり（公式）🧠📌

* .NET 10 は **2025年11月11日リリースのLTS**で、**2026年1月13日時点の最新パッチが 10.0.2** と案内されています。([Microsoft][1])
* C# 14 は .NET 10 上でサポートされ、Visual Studio 2026 / .NET 10 SDK で試せる新機能が整理されています。([Microsoft Learn][2])
* Visual Studio 2026 のリリースノート側でも、.NET 10 対応などの更新が明記されています。([Microsoft Learn][3])

[1]: https://dotnet.microsoft.com/ja-jp/platform/support/policy/dotnet-core ".NET および .NET Core の公式サポート ポリシー | .NET"
[2]: https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14 "What's new in C# 14 | Microsoft Learn"
[3]: https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes "Visual Studio 2026 Release Notes | Microsoft Learn"
