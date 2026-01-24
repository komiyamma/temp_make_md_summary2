# 第1章　CQRSってなに？最短でわかる入口🚪✨

この章は「CQRSの“雰囲気”をつかむ」がゴールだよ😊
むずかしい単語が出てきても、今日は**ぜんぶ完璧に覚えなくてOK**！「なるほど、こういう分け方なんだ〜」って思えれば勝ち🏆✨

---

## 1) CQRSを一言でいうと？📌

**CQRS = “更新するもの(Command)” と “見るだけのもの(Query)” を分けようね**っていう考え方だよ🧠✨
正式には *Command Query Responsibility Segregation*（コマンド／クエリ責任分離）って呼ばれるよ。([martinfowler.com][1])

* **Command（更新）**：状態を変える（＝副作用あり）🔧
  例）注文する、支払う、キャンセルする、住所を変更する…など
* **Query（参照）**：見るだけ（＝副作用なし）👀
  例）注文一覧を見る、売上集計を見る、在庫を確認する…など

> ポイント：**「変える」か「見る」か**だけでまず判定できる👍✨

---

## 2) なんで分けるの？（雑に混ぜると起きがちなこと）😵‍💫

最初は「全部まとめて1つのサービスに書く」でも動くんだけど…
システムが育つと、だんだんこんなことが起きやすいの👇

* 一覧表示を直しただけなのに、更新ロジックまで壊れた💥
* 「集計を速くしたい」けど、更新と絡みすぎて触れない🙈
* テストがしんどい（参照のはずがDB更新してたり）🧪💦

CQRSは、**“見る”と“変える”の役割を分けて**、変更しやすくしたり、表示を速くしたりしやすくする考え方だよ🚀✨([Microsoft Learn][2])

ただし！CQRSは**強いけど、複雑さも増える**から、何でもかんでも採用すれば良いわけじゃないよ（ここ大事）⚠️
「多くのシステムでは複雑さがリスクになる」って注意も有名👍([martinfowler.com][1])

---

## 3) Command / Query を一瞬で見分けるコツ👓✨

迷ったら、この3つの質問でOK😊

### ✅ 質問A：データが変わる？

* 変わる → **Command** 🔧
* 変わらない → **Query** 👀

### ✅ 質問B：副作用がある？（保存・送信・課金・通知など）

* ある → **Command** 🔥
* ない → **Query** 🧼

### ✅ 質問C：名前が「〜する」？

* 「注文する」「支払う」みたいな動詞 → **Command**っぽい
* 「取得する」「一覧を見る」 → **Query**っぽい

---

## 4) よくある誤解：CQRS = イベント駆動？イベントソーシング？🤔

ここ、初心者が混乱しやすいところ！💡

* **CQRSは“必ずイベントが必要”ではない**よ🙆‍♀️
* ただ、現場では「CQRS + イベント（非同期投影）」みたいに**セットで語られがち**だから、そう見えるだけ👍

「CQRS自体はイベント必須じゃない」って説明もあるよ📚([martinfowler.com][3])

---

## 5) 身近な例でつかむ：学食モバイル注文🍙📱

たとえば学食アプリだと👇

### 🔧 Command（更新）

* 注文する
* 支払う
* 注文をキャンセルする
* メニューを追加する（管理画面）

### 👀 Query（参照）

* 今日のメニューを見る
* 注文一覧を見る
* 売上集計を見る
* 人気メニューTOP3を見る

「注文する」は世界が変わるけど、「注文一覧を見る」は世界は変わらない、って感じ😊✨

---

## 6) ミニ演習：Command？Query？どっちゲーム🗂️🎮

次の10個を **Command / Query** に分けてみてね✨（直感でOK！）

1. 注文する
2. 注文一覧を表示する
3. 住所を変更する
4. 今日の売上合計を見る
5. ログインする
6. メニューの価格を変更する
7. 注文のステータス（準備中/受け取り済み）を見る
8. お気に入りメニューに追加する
9. 人気メニューTOP3を見る
10. レシートを再発行する（PDFを作る）

### ✅ こたえ（理由つき）🎯

1. Command（注文が作られる）
2. Query（見るだけ）
3. Command（情報が変わる）
4. Query（集計を見るだけ）
5. **だいたいCommand**（ログイン状態・セッションが変わることが多い）
6. Command（価格が変わる）
7. Query（見るだけ）
8. Command（お気に入りが増える）
9. Query（見るだけ）
10. ⚠️迷いどころ：

* 「PDFを**生成して保存**する」ならCommand
* 「すでにあるPDFを**取得して表示**」ならQuery
  → **“世界が変わるか”で判定**すると強い💪✨

---

## 7) 超ミニのTypeScript例（雰囲気だけつかむ）✍️✨

「更新」と「参照」を**関数レベル**で分けるだけでも、もうCQRSの入り口だよ🚪✨

```ts
// ✅ Command（更新）: 注文する（状態が変わる）
type PlaceOrderCommand = {
  userId: string;
  menuId: string;
  qty: number;
};

// ✅ Query（参照）: 注文一覧を取る（状態は変えない）
type GetOrderListQuery = {
  userId: string;
};

type OrderListItem = {
  orderId: string;
  menuName: string;
  qty: number;
  status: "ORDERED" | "PAID";
};

// --- Command側 ---
async function placeOrder(cmd: PlaceOrderCommand): Promise<{ orderId: string }> {
  // ここでは「保存する」「状態を作る」みたいなことが起きる想定（副作用あり）
  // 例: DBにinsert、在庫を減らす、など
  return { orderId: "ORD-123" };
}

// --- Query側 ---
async function getOrderList(q: GetOrderListQuery): Promise<OrderListItem[]> {
  // ここは「読むだけ」（副作用なし）
  return [
    { orderId: "ORD-123", menuName: "唐揚げ定食", qty: 1, status: "ORDERED" },
  ];
}
```

### ここでの大事ポイント🌟

* **Commandは「やる」**（世界を変える）
* **Queryは「見る」**（世界を変えない）
* 関数を分けただけでも、頭の中が整理されてくるよ😊✨

---

## 8) AI活用コーナー🤖💬（例を10個出して分類させる😆）

そのままコピペで使えるよ👇✨

### ✅ プロンプト例1：分類してもらう🗂️

「学食モバイル注文アプリ」で起きる操作を10個考えて、
各操作を Command / Query に分類して、理由を1行で書いて。

### ✅ プロンプト例2：わざと間違わせてツッコむ😈👉😆

次の操作を Command / Query に分類して。
ただし自信がなくても必ず答えて。
（答えた後で、間違いそうなものだけ“なぜ迷うか”も書いて）

👉 AIが迷った場所こそ、あなたの理解ポイントが育つ場所🌱✨

### ✅ プロンプト例3：命名の練習🧾

CommandとQueryの名前を、英語の関数名で10個提案して。
例：PlaceOrder, GetOrderList みたいな感じ。

---

## 9) まとめ🎀

* CQRSは **「更新(Command)」と「参照(Query)」を分ける**考え方😊✨([martinfowler.com][1])
* まずは「世界が変わる？」で判定すると迷いにくい👓
* CQRSは強いけど、複雑さも増えるから“使いどころ”が大事⚠️([martinfowler.com][1])
* CQRSはイベント必須じゃない（混同しなくてOK）🙆‍♀️([martinfowler.com][3])

---

## おまけ：いまのTypeScript/Nodeの“最新感”メモ🧁✨

* TypeScriptは **5.9** が現行系列として案内されてるよ🧠([Microsoft for Developers][4])
* Node.js は **v24 が Active LTS**、v25 が Current（最新系列）として更新されてるよ🔧([Node.js][5])

（※この章では“知ってると安心”程度でOK！次章以降で手を動かしていくよ😊）

---

次の第2章は、題材の「学食モバイル注文」を固定して、迷子にならない地図を作るよ🧭✨
続けて第2章もこのテンションで作る？🍙📱💕

[1]: https://martinfowler.com/bliki/CQRS.html?utm_source=chatgpt.com "CQRS"
[2]: https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs?utm_source=chatgpt.com "CQRS Pattern - Azure Architecture Center"
[3]: https://martinfowler.com/articles/201701-event-driven.html?utm_source=chatgpt.com "What do you mean by “Event-Driven”?"
[4]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
[5]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
