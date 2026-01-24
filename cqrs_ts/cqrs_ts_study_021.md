# 第21章　エラー設計①（エラーの種類を分ける）⚠️🧠✨

今回は「エラーを“仕様”として整理する」回だよ〜😊
CQRSの世界では、**エラーを分けるだけで設計が一気にラク**になるの…！✨

---

## 1) まず結論：エラーは3種類に分けよう🧺✨

### ✅ A. ドメインエラー（＝想定内・仕様どおり）📜💡

「その操作はルール的にダメだよ」ってやつ。

* 例：未注文なのに支払いしようとした🙅‍♀️
* 例：すでに支払い済みなのに、もう一回支払いした🙅‍♀️💳

👉 **ユーザーに“そのまま伝えてOK”**（丁寧な文言にはするけどね😊）

---

### ✅ B. インフラエラー（＝外部要因・環境都合）🌐🧯

DB・ネットワーク・外部API・ファイルなどの「外側」が原因。

* 例：DBに接続できない😵
* 例：決済サービスがタイムアウトした⌛
* 例：ネットが落ちた📴

👉 ユーザーには「今は処理できない🙏」を返しつつ、
**ログには詳細を残す**のが基本だよ📝✨

---

### ✅ C. 予期せぬバグ（＝設計ミス・実装ミス）🐛💥

「本来起きないはず」のやつ。

* 例：nullを想定してなくて落ちた😇
* 例：想定してない分岐に入った😵‍💫

👉 ユーザーには「不具合が起きた🙏」を返し、
**開発側にアラート**案件📣🔥（ログ超重要！）

---

## 2) なんで分けるの？（分けないと地獄😵‍💫）

エラーを一括りにすると…

* 「どれがユーザーに見せてOK？」が毎回ブレる😵
* 「リトライすべき？」が判断できない🔁❓
* ログがぐちゃぐちゃで調査できない🕵️‍♀️💦
* テストが書けない（何を期待すればいいの？）🧪❓

だからまず **種類分け＝設計の地図** を作るのが超大事🗺️✨

---

## 3) 具体例：PayOrder（支払う）で起こるエラーを並べよう💳⚠️

### ドメインエラー候補📜

* `OrderNotFound`（注文が存在しない）🔎
* `OrderAlreadyPaid`（もう支払い済み）✅
* `OrderNotOrderedYet`（未注文なのに支払い）🙅‍♀️
* `InvalidAmount`（金額が不正）💰❌

### インフラエラー候補🌐

* `DbConnectionFailed`（DB接続NG）🗄️❌
* `PaymentGatewayTimeout`（決済タイムアウト）⌛
* `PaymentGatewayRejected`（外部都合で拒否）🚫

### 予期せぬバグ候補🐛

* `switch` の網羅漏れで到達しちゃった💥
* `undefined` が混ざって落ちた😇

> コツ：**「ユーザーの操作で起きうる＝ドメイン」**
> **「外部の都合＝インフラ」**
> **「起きたらおかしい＝バグ」**
> この3つでだいたい迷子にならないよ😊✨

---

## 4) TypeScriptで“エラーを型”にしよう🧩✨（超重要！）

ここではライブラリ無しで、素朴にいくよ〜😊
（最近は Result 型パターンがよく使われるよ、って話は後で少しするね🤖）

```ts
// ✅ まずは「分類タグ」を必ず持たせる（これが超効く！）
type DomainError =
  | { type: "DomainError"; kind: "OrderNotFound"; orderId: string }
  | { type: "DomainError"; kind: "OrderAlreadyPaid"; orderId: string }
  | { type: "DomainError"; kind: "OrderNotOrderedYet"; orderId: string };

type InfraError =
  | { type: "InfraError"; kind: "DbConnectionFailed"; message: string; cause?: unknown }
  | { type: "InfraError"; kind: "PaymentGatewayTimeout"; message: string; cause?: unknown };

type UnexpectedBug =
  | { type: "UnexpectedBug"; kind: "Unexpected"; message: string; cause?: unknown };

type AppError = DomainError | InfraError | UnexpectedBug;
```

### 🎀 ここがポイント！

* `type` で「分類」を固定する（Domain/Infra/Bug）✅
* `kind` で「具体名」を表す（OrderAlreadyPaid など）✅
* インフラ・バグは `cause` を持たせると調査が超楽🕵️‍♀️✨

---

## 5) 「どこで」どのエラーを作る？（責務の置き場）📦🧠

### ドメインエラー📜

* **ドメインのルールを判断する場所**で作る
  （例：Orderの状態遷移の判定、支払い可否チェックなど）

### インフラエラー🌐

* **Repository や外部API呼び出し**で作る
  ただし、そのまま外に投げずに、あとでアプリ側で扱いやすい形にする✨

### 予期せぬバグ🐛

* これは「作る」というより
  **起きたら捕まえて “UnexpectedBug” に包む**感じが多いよ😊

---

## 6) ちょい実装例：PayOrderが返す“失敗の型”💳🧩

```ts
type Ok<T> = { ok: true; value: T };
type Err<E> = { ok: false; error: E };
type Result<T, E> = Ok<T> | Err<E>;

type PayOrderResult = Result<{ paidAt: string }, AppError>;
```

### この形のいいところ😊✨

* 「失敗しうる」ことが **型で見える**
* 呼ぶ側は **必ずエラー処理を書く流れ**になる
* テストで「この失敗が返るはず」を書ける🧪✅

最近はこういう **Result型パターン**が人気で、代表例として `neverthrow` があるよ（Ok/Err を提供してくれる）([GitHub][1])
さらに “エラーも型で追いかける” のを強力にやりたい人向けに Effect みたいな選択肢も増えてるよ([Effect][2])

---

## 7) ミニ演習📝✨（3分でOK！）

### ✅ お題：PayOrderのエラーを「3分類」で仕分けしてみてね💳⚠️

次を Domain / Infra / Bug に分けてみよ〜😊

1. 注文IDが存在しない
2. すでに支払い済み
3. DB接続エラー
4. 決済APIがタイムアウト
5. `switch(order.status)` の default に落ちた

**答え合わせ（こっそり）**👇

* 1,2 → Domain📜
* 3,4 → Infra🌐
* 5 → Bug🐛

---

## 8) AI活用プロンプト🤖✨（そのままコピペOK！）

「エラー分類の漏れ」を潰すのにAIめっちゃ強いよ😊

```text
学食モバイル注文の PayOrder（支払い）について質問です。
起こりうるエラーを「ドメインエラー / インフラエラー / 予期せぬバグ」に分類して、
漏れがないかチェックしつつ、追加で考えられるケースも提案してください。
各エラーに「ユーザー表示メッセージ案」も1つずつ付けてください。
```

---

## 9) 章末まとめ🎉

この章でできるようになったこと😊✨

* エラーを **Domain / Infra / Bug** に分けられる🧺
* PayOrderで起こる失敗を「仕様」として整理できる📜
* TypeScriptで **エラーを型として表現**できる🧩
* 次章（第22章）で「じゃあ境界でどう返す？ Result？例外？」に進む準備ができた🎯✨

---

必要なら、次の第22章に繋がる形で「境界での変換（HTTPステータス/レスポンス形）」のチラ見せも付けて、学びの流れを滑らかにして書けるよ〜😊🚪✨

[1]: https://github.com/supermacro/neverthrow?utm_source=chatgpt.com "supermacro/neverthrow: Type-Safe Errors for JS & TypeScript"
[2]: https://effect.website/?utm_source=chatgpt.com "Effect – The best way to build robust apps in TypeScript"
