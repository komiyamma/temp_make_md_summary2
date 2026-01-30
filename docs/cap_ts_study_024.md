# 第24章：順序問題② 因果（ざっくり）とバージョン付け🧵🕰️

## この章で身につけること🎯✨

* 「どっちが先？」を**最低限のルール**で判断できるようになる🧠✅
* **version番号**で「古い更新」を弾けるようになる🧱🛡️
* 途中が抜けた（順番が飛んだ）ときに「再取得（リシンク）」へ逃がせるようになる🚪📥

---

## 1) まず1分で体感：順番がズレると何が壊れる？😵‍💫📨🔀

たとえば「注文ステータス」がこう変わるとするね👇

* v1: `PENDING`（受付）
* v2: `PAID`（支払い完了）
* v3: `CANCELLED`（キャンセル）

本当は「最後はCANCELLED」になってほしいのに…
**メッセージが逆順で届く**とこうなる😱

1. v3（CANCELLED）が先に届く → 状態はCANCELLED ✅
2. 後から v2（PAID）が届く → 状態がPAIDに戻っちゃう ❌💥

これ、分散だと普通に起きるよ（遅延・再送・シャッフルの合わせ技）🌀

---

## 2) 因果（ざっくり）ってなに？🧵👀

「因果」って難しく聞こえるけど、超ざっくり言うと👇

> **“BはAの後に起きた”** を言える関係が「因果」だよ🧵✨

分散の世界では、事件（イベント）の順番は**全部が一直線**じゃない。
「先・後」が言えるものもあれば、言えないものもある（部分順序）📎
この考え方は Lamport の “happened-before” として有名だよ📚🕰️ ([lamport.azurewebsites.net][1])

ここでは数学はやらない！代わりに実務の必殺技👇

---

## 3) 物理時計（時刻）より、versionで順番を作る⏰❌➡️🔢✅

時刻（timestamp）で「新しい方を採用！」ってやりたくなるけど…
分散だと**時計ズレ**があるから危ない⚠️（A機は未来、B機は過去…みたいになる）

だからこの章では、いちばん扱いやすい👇

### ✅ version番号（単調増加）で順番を作る

* 更新のたびに `version += 1` する🔢✨
* 受け取った更新に version を付ける📨
* **今の状態のversionと比較**して「古いなら捨てる」🗑️

---

## 4) バージョン付けの基本ルール3つ🧠📏

ここだけ覚えると強いよ💪✨

1. **古い更新は無視**（stale）🧊
2. **ちょうど次（+1）なら適用**✅
3. **飛んでたら再取得**（gap）📥🧯

つまり👇

* `ev.version <= current.version` → **古い**ので捨てる🗑️
* `ev.version === current.version + 1` → **順番通り**なので適用✅
* `ev.version > current.version + 1` → **途中が抜けた**ので再取得📥

---

## 5) ハンズオン：versionが古い更新を弾く🧪🧰✨

### 5-1. 型を用意する🧾✨

```ts
// apps/shared/order.ts
export type OrderStatus = "PENDING" | "PAID" | "CANCELLED";

export type Order = {
  id: string;
  status: OrderStatus;
  version: number;      // 🔢 これが主役！
};

export type OrderStatusChanged = {
  type: "OrderStatusChanged";
  orderId: string;
  to: OrderStatus;
  version: number;      // 🔢 「この更新が何番目か」
  causedBy: string;     // 🧵 相関IDっぽいもの（ログ追跡用）
};
```

### 5-2. 適用関数（超重要）を書く🧠🛡️

```ts
// apps/worker/applyEvent.ts
import type { Order, OrderStatusChanged } from "../shared/order";

export type ApplyResult =
  | { kind: "applied"; order: Order }
  | { kind: "stale"; reason: string }
  | { kind: "gap"; reason: string };

export function applyOrderEvent(order: Order, ev: OrderStatusChanged): ApplyResult {
  // ① 古い更新は捨てる🧊
  if (ev.version <= order.version) {
    return {
      kind: "stale",
      reason: `stale event. current=v${order.version}, incoming=v${ev.version}`,
    };
  }

  // ② ちょうど次ならOK✅
  if (ev.version === order.version + 1) {
    return {
      kind: "applied",
      order: { ...order, status: ev.to, version: ev.version },
    };
  }

  // ③ 飛んでたら再取得📥
  return {
    kind: "gap",
    reason: `gap detected. current=v${order.version}, incoming=v${ev.version}`,
  };
}
```

### 5-3. 逆順でイベントを流して壊してみる😈➡️🧯

```ts
// apps/worker/simulate.ts
import { applyOrderEvent } from "./applyEvent";
import type { Order, OrderStatusChanged } from "../shared/order";

const order: Order = { id: "o-1", status: "PENDING", version: 1 };

const ev2: OrderStatusChanged = {
  type: "OrderStatusChanged",
  orderId: "o-1",
  to: "PAID",
  version: 2,
  causedBy: "req-aaa",
};

const ev3: OrderStatusChanged = {
  type: "OrderStatusChanged",
  orderId: "o-1",
  to: "CANCELLED",
  version: 3,
  causedBy: "req-bbb",
};

// 😈 逆順で来た体で適用してみる
let current = order;

for (const ev of [ev3, ev2]) {
  const r = applyOrderEvent(current, ev);
  console.log("incoming", ev.to, "v" + ev.version, "=>", r.kind, r.reason ?? "");
  if (r.kind === "applied") current = r.order;

  // gapなら「再取得」へ（ここではログだけ）
  if (r.kind === "gap") {
    console.log("🔁 need resync! fetching latest order...");
  }
}

console.log("final:", current);
```

**期待する観察ポイント👀✨**

* v3が来た時点で `gap` になって「再取得しよ〜」になる📥
* v2が後から来ても `applied` されて、順番が整う✅
* もし “再取得” を本当に実装したら、v3も最終的に取り込める🎯

---

## 6) 「再取得（リシンク）」ってどうやるの？📥🔁

`gap` を見つけたら、いったんこうするのが現実的👇

* **GETで最新の状態を取り直す**（例：`GET /orders/o-1`）📡
* 取り直した `version` を基準にして、またイベントを適用する🔄

ポイントはこれ👇
**「抜けたイベントを気合で当てる」より「最新状態を取り直す」方が安全**🧯✨

---

## 7) もう1つの定番：HTTPでもversionチェックできる（If-Match / ETag）🏷️🛡️

APIで「編集の競合」を防ぐなら、HTTPの**条件付きリクエスト**が便利だよ📨✨
`If-Match` は ETag が一致するときだけ更新し、ズレたら `412 Precondition Failed` を返すのが基本🧠✅ ([MDN Web Docs][2])

### 例：注文を更新するときにIf-Matchを使う🧾✨

* サーバーが `ETag: "order-o-1-v3"` を返す🏷️
* クライアントは更新時に `If-Match: "order-o-1-v3"` を付ける📨
* サーバー側で一致しなければ `412` で拒否🛑

これ、考え方としては「version一致したら更新OK」ってことだよ🔢✅

---

## 8) TypeScriptまわりの“最新”ミニメモ🧠✨

* TypeScript 5.9 は公式にリリース告知が出ていて、公式ドキュメントにも 5.9 のリリースノートがあるよ📚✨ ([Microsoft for Developers][3])
* Node.js は v24 が Active LTS、v25 が Current としてリストに載ってる（2026-01時点）🟢🟡 ([Node.js][4])

（教材コードは “特殊な新機能” に寄せず、どの環境でも通用する「versionで守る設計」に寄せるのが安全だよ🛡️✨）

---

## 9) よくある落とし穴（ここで事故が減る）⚠️🧯

* **versionの更新は原子的に**（DB更新は「version一致で更新」みたいにする）🔒
* **versionは“対象ごと”に持つ**（注文ごと、在庫アイテムごと）🧩
* **timestampの大小でLWWに逃げない**（時計ズレで負ける）⏰💥
* `gap` を無視しない（抜けたまま進むと、あとで必ず変な状態になる）🌀😵‍💫

---

## 10) ミニ演習✍️🧪✨

### 演習1：説明してみよう🗣️💡

* 「v3が先に来て、v2が後に来る」と何が危ない？
* versionチェックがあるとどう防げる？

### 演習2：保留キューを作る📦🧵

`gap` のとき、イベントを捨てずに一旦 `pending[orderId]` に入れて、
再取得後に「入ってる分を順番に適用」してみよう🔄✨

### 演習3：If-Matchっぽい更新をAPIに入れる🏷️

* `GET /orders/:id` で ETag を返す
* `PUT /orders/:id` は `If-Match` が一致したら更新、違えば `412`

---

## 11) AI活用コーナー🤖💬✨

そのまま貼って使えるプロンプト例👇

* 「OrderStatusChangedイベントが逆順・重複で届くケースのテストを10個作って。期待結果も書いて」🧪🤖
* 「applyOrderEventの分岐（stale/gap/applied）で、ログに出すべき項目を提案して」🪵🤖
* 「If-Match/ETagで412を返す最小のExpress実装をTypeScriptで」🏷️🤖

---

## まとめ（結論1行）✍️✨

**順番がズレる世界では、“時刻”より“version”で新しさを判断して、古い更新は弾き、飛びが出たら再取得で守る**🛡️🔢📥

[1]: https://lamport.azurewebsites.net/pubs/time-clocks.pdf?utm_source=chatgpt.com "Time, Clocks, and the Ordering of Events in a Distributed System"
[2]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/If-Match?utm_source=chatgpt.com "If-Match header - HTTP - MDN Web Docs"
[3]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
[4]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
