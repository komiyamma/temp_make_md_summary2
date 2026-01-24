# 第26章　投影（Projection）② 非同期投影の全体像⏳📨

### この章でできるようになること ✅✨

読み終わったら、こんな状態になってればOK！

* **非同期投影の流れ**を、口で説明できる＆紙に描ける🖊️✨
* 「同期投影」と比べて、**どこが嬉しい/どこが辛い**が分かる🙂⚖️
* 「ズレ（最終的整合性）」が起きる理由がちゃんと腹落ちする🕒🙂
* 最小の“なんちゃって非同期投影”をTypeScriptで動かせる🤖💻

---

## 1) そもそも「投影（Projection）」って何だっけ？🪞✨

投影は一言でいうと…

**「Write側で起きたこと」を材料にして、Read側の“見やすい形”を育てる作業** 🌱📚

* Write側：正しさ優先（注文・支払い・状態遷移など）🧾💳
* Read側：画面に出しやすさ優先（一覧・集計・検索が速い形）🔎📊

---

## 2) 非同期投影は、どこが“非同期”なの？⏳📨

同期投影（前章）はこう👇
**Commandが終わるまでに、Readモデルも更新する** ⚡

非同期投影はこう👇
**Commandは先に成功で返して、Readモデル更新は後で別ルートでやる** ⏳📨

つまり…

* ✅ Commandのレスポンスが速くなりやすい🚀
* ✅ 投影処理が失敗しても、Writeの成功自体は守れる🛡️
* ⚠️ その代わり「画面が一瞬古い」ズレが発生する🕒🙂

---

## 3) 全体像（まずはこの絵が描ければ勝ち✌️✨）

イメージはこれ！👇

* Command（更新）

  1. Write DB更新
  2. 「起きたこと」をイベントとして残す（Outboxなど）📮
  3. すぐ成功レスポンス返す✅

* Projection（別働隊）
  4) イベントを拾う（キュー/Outbox）👀
  5) Readモデルを更新する🌱
  6) QueryはReadモデルを見る🔎

図で書くとこう👇

```txt
[Client]
  |
  | 1) PlaceOrder (Command)
  v
[API/CommandHandler] ---- 2) Write DB更新 ----> [Write DB]
  |                               |
  | 3) イベント保存(Outbox)📮       |
  +------------------------------> [Outbox(Event Log)]
  |
  | 4) すぐ成功返す✅
  v
[Client]  (でもReadはまだ古いかも…🕒)

別働隊：
[Projector/Worker] <--- 5) Outboxから取得 --- [Outbox]
  |
  | 6) Readモデル更新🌱
  v
[Read DB/View]
  |
  | 7) GetOrderList (Query)
  v
[Client]
```

この「**Write成功**」と「**Read反映**」の間に、時間差が入るのがポイントだよ⏳🙂

---

## 4) “学食モバイル注文”で起きること（超具体例🍙📱）

### シーン：注文ボタンを押した瞬間👇

* あなた：注文する🧾✨（Command）
* サーバ：注文をWrite DBに保存する✅
* サーバ：イベントをOutboxに積む📮
* サーバ：**「注文できたよ！」って即返す** 🎉

でも…

* 一覧画面（Query）はReadモデルを見てるから、**反映が0.5秒遅れる**とかが普通に起きる🕒🙂

このズレは **バグじゃなくて仕様** だよ〜（ここ超大事！）🧠✨

---

## 5) 非同期投影でよく出てくる登場人物たち👥✨

### (A) イベント（Event）📣

「起きた事実」を表すデータ。例：

* OrderPlaced（注文された）
* OrderPaid（支払われた）

（次章でここをガッツリやるよ！📦✨）

### (B) Outbox（イベント置き場）📮

Write DBの中に「後で投影するためのイベント」を貯める箱。
Write DBの更新とセットで残すのが大事（理由は後の章で強く効く🛡️）

### (C) Projector / Worker（投影係）🧑‍🔧🌱

Outboxやキューを見張って、Readモデルを育てる別プロセス（別スレでも別サーバでもOK）👀✨

---

## 6) 非同期投影の「嬉しいところ」と「怖いところ」🙂⚖️

### 嬉しいところ🎉

* **Commandのレスポンスが軽くなる**（投影が重くても関係ない）🚀
* Readモデル更新が重い（集計・検索用整形）ほど効く📊✨
* 投影が失敗しても、Write成功が守れる（業務の核心を守りやすい）🛡️

### 怖いところ😵‍💫

* **最終的整合性**：画面が一瞬古い🕒
* **運用が必要**：リトライ、監視、失敗イベントの扱い…🧯
* **二重処理**が普通に起きる（次章以降の「冪等性」に繋がる）🔁

---

## 7) まず動かす！超ミニ「非同期投影」ハンズオン🤏💻✨

ここは「概念を体に入れる」ための最小構成だよ😊
外部キューやDBなしで、**アプリ内の簡易キュー**で再現するよ📨

### 7-1. “起きたこと”イベント型を用意📣

```ts
type OrderPlaced = {
  type: "OrderPlaced";
  eventId: string;         // UUIDなど（のちに冪等性で超重要🔑）
  occurredAt: number;      // Date.now()
  orderId: string;
  userId: string;
  totalYen: number;
};
```

### 7-2. Outbox（イベント箱）を配列で作る📮

```ts
class InMemoryOutbox {
  private events: OrderPlaced[] = [];

  push(e: OrderPlaced) {
    this.events.push(e);
  }

  pullBatch(max = 10): OrderPlaced[] {
    return this.events.splice(0, max); // 先頭から取って消す
  }
}
```

### 7-3. Readモデル（画面用データ）を育てる🌱

```ts
type OrderRow = { orderId: string; userId: string; totalYen: number; placedAt: number };

class ReadModel {
  private list: OrderRow[] = [];

  upsertFromEvent(e: OrderPlaced) {
    this.list.unshift({ orderId: e.orderId, userId: e.userId, totalYen: e.totalYen, placedAt: e.occurredAt });
  }

  getList(): OrderRow[] {
    return [...this.list];
  }
}
```

### 7-4. Projector（別働隊）を“定期実行”で再現⏳

```ts
class Projector {
  constructor(private outbox: InMemoryOutbox, private read: ReadModel) {}

  start() {
    setInterval(() => {
      const batch = this.outbox.pullBatch(10);
      for (const e of batch) {
        this.read.upsertFromEvent(e);
      }
    }, 200); // 0.2秒ごとに投影
  }
}
```

### 7-5. Commandが「イベントを積んで、すぐ返す」を体験🎉

```ts
function placeOrder(outbox: InMemoryOutbox, orderId: string, userId: string, totalYen: number) {
  // 本来はWrite DBに保存する（ここでは省略）
  outbox.push({
    type: "OrderPlaced",
    eventId: crypto.randomUUID(),
    occurredAt: Date.now(),
    orderId,
    userId,
    totalYen,
  });

  return { ok: true as const, orderId }; // 先に成功を返す✅
}
```

✅これで「注文成功」→（ちょい遅れ）→「一覧に出る」が再現できるよ🕒🙂✨

---

## 8) もう一段 “現実っぽい” 形（OutboxがDBにある世界）📮🗄️

本番では、アプリが落ちてもイベントが消えないようにしたいよね🥺
そこで **OutboxをDBに入れる** 方向に進むよ。

### ざっくりDB設計イメージ🧾

* orders（Writeの正）
* outbox_events（投影待ちイベント）📮
* read_orders（Readモデル）🌱

ポイントはこれ👇
**ordersの更新とoutbox_eventsの追加を“同じトランザクション”でやる** 🔒✨
（ここがズレると「注文は入ったのにイベントが出ない」事故が起きる😱）

SQLiteならWALで読み取り並行性が上がりやすい、みたいな話もあるよ🧠✨（Readが多い構成と相性がいいことがある）([Shivek Khurana][1])

---

## 9) 「配達の性質」：非同期は“だいたい複数回届く”前提📦🔁

非同期投影では、現実あるあるが起きるよ👇

* ワーカーが途中で落ちた😵
* ネットワークが不安定📶
* リトライで同じイベントが2回処理された🔁

なので考え方としては、

> **イベントは“少なくとも1回”届く（at-least-once）**
> だから **投影は二重に来ても壊れない（冪等）** にする

この「冪等性」は第30章でガッツリやるけど、
第26章の時点では「**二重が普通に起きる**」だけ覚えてればOKだよ🙂✨

---

## 10) よくある失敗あるある😇（先に踏み抜きポイント共有！）

* **Commandの中で投影までやっちゃう**（結局同期じゃん問題）😅
* **Readに反映されないのをバグ扱いする**（最終的整合性の理解不足）🕒💦
* **イベントに必要な情報が足りない**（投影できない事件）📣❌
* **失敗イベントの行き先がない**（どこにも回収されず詰む）🗑️😱

---

## 11) AI活用🤖✨（Copilot / Codexに頼むとめっちゃ捗る！）

そのまま貼って使える系プロンプトを置いとくね🧸✨

### 図を描いてもらう🖊️

* 「非同期投影の流れを、登場人物（Client/API/WriteDB/Outbox/Worker/ReadDB）でシーケンス図にして。学食注文アプリの例で！」

### イベント設計のレビュー📣

* 「OrderPlacedイベントに含めるべきフィールドを提案して。Readモデル（一覧と集計）を作る前提で“足りないと困る情報”を指摘して！」

### “ズレ”のUX案を出してもらう🕒✨

* 「Read反映が遅れる前提で、フロント側の表示（更新中表示、再取得、楽観更新）を学食注文アプリの画面として提案して！」

---

## 12) 2026年1月時点の“開発前提”ミニメモ🧠✨

* Nodeは **偶数メジャーのLTSを選ぶ**のが基本で、2026年1月時点だと **v24がActive LTS** として扱われているよ🟢([Node.js][2])
* TypeScriptはネイティブ移植（コンパイラ/言語サービス高速化）が進んでいて、今後大規模コードベースのビルド体験がさらに良くなる流れが出てるよ⚡（“プレビュー/計画”として把握でOK）([Microsoft Developer][3])

---

## まとめ🎀✨（この章のゴール）

* 非同期投影は、**Write成功とRead反映を分離**するやり方⏳📨
* “イベント（起きた事実）”を運んで、Readモデルを育てる🌱
* その代わり、**ズレ（最終的整合性）**と**運用（リトライ/監視/冪等）**がセット🙂🧯
* 次章で「ドメインイベント」を作れるようになると、ここが一気に気持ちよくなるよ📣✨

---

次の第27章は、「イベントって何を書けばいいの？」「名前どうするの？」「粒度は？」ってところを、学食アプリの具体例で一緒に固めるよ〜📣🍙✨

[1]: https://shivekkhurana.com/blog/sqlite-in-production/?utm_source=chatgpt.com "Sophisticated Simplicity of Modern SQLite - Shivek Khurana"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026?utm_source=chatgpt.com "TypeScript 7 native preview in Visual Studio 2026"
