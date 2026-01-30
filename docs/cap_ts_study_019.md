# 第19章：マージしやすいデータ設計①（カウンタ/加算）➕🔢

## この章でできるようになること 🎯✨

* 「上書き」だと競合で壊れる理由を、**体感レベル**で説明できる 😵‍💫
* 「いいね数」「閲覧数」みたいな**カウンタ系**を、競合しにくい形（加算）で設計できる ➕
* 最終的整合性の世界でありがちな「重複」「遅延」に強いカウンタを作れる 🧷🔁

---

## 19.1 まずは結論 🧠⚡

カウンタ系（いいね数・PV・在庫の増減ログなど）は、**「いまの合計値」を上書きしない**のが基本です 🙅‍♀️
代わりに、**「+1 した」「+3 した」みたいな“増分（デルタ）”で表現**すると、後から集計・マージしやすくなります ➕📦

---

## 19.2 なぜ「上書き」が危ないの？😱🧨（lost update 体験）

例：いいね数を「合計値」で上書きする設計

* いま DB のいいね数は 10 👍
* Aさんがいいね → 11 にして保存したい
* ほぼ同時に Bさんもいいね → 11 にして保存したい

タイムラインで見ると… 🕰️

* Aさん：10 を読んだ → 11 を書いた
* Bさん：10 を読んだ → 11 を書いた
* 結果：**本当は +2 なのに +1 しか増えてない**（1回分のいいねが消えた！）💥

この「消えた！」が **lost update（更新の取りこぼし）** だよ〜😵‍💫

---

## 19.3 「加算」にすると何が嬉しい？🎁✨（競合に強い）

同じ状況でも、操作を「+1」みたいに表現すると…

* Aさん：+1 を発生させた
* Bさん：+1 を発生させた
* あとでまとめて足す → **10 + 1 + 1 = 12** 🎉

ポイントはこれ👇

* 「+1」と「+1」は、**順番が入れ替わっても結果が同じ**（足し算は順序に強い）🔀✅
* つまり、最終的整合性でありがちな「遅れて届く」「順番がズレる」に耐えやすい 💪⏳

さらに、CRDT（衝突なしで収束するデータ型）の世界でも、カウンタは代表例として整理されていて、**“各レプリカの増分を持って、マージ時にうまく合成する”**という考え方が出てくるよ 🧲✨ ([dsf.berkeley.edu][1])

---

## 19.4 カウンタ設計：3つのレベル感 🧩📚

### レベルA：同じDBに書くなら「原子的インクリメント」🗃️⚡

1つのDBにみんなが書くなら、DBが用意してる「増分更新」を使うのが王道だよ 👍
例：DynamoDB なら Update で ADD/SET を使って **アトミックに増分**できる（同時更新でも潰れにくい）🛡️ ([AWS ドキュメント][2])

ただし…

* 「分散して別々に書いて、あとでマージ」みたいな世界になると、それだけでは足りないことがある 🙃

---

### レベルB：非同期（API受付→Worker反映）なら「デルタ（+1）イベント」📨🔁

* APIは「+1してね」イベントを積む
* Workerが後で集計して反映する
* ここで大事なのは **重複に耐える（冪等）** こと 🧷

---

### レベルC：複数レプリカで書けるなら「G-Counterっぽい形」🧲🔢（おまけ）

「各レプリカが自分の増分だけ持つ」形にすると、マージが安定しやすいよ 🌱
状態ベースの G-Counter では、だいたいこんな感じ👇

* 状態：レプリカID → カウント（Map）
* 値：全部足し算
* マージ：各レプリカIDごとに **大きい方を採用（pointwise max）** してから足す
  この “max でマージ” が「増えた事実を失わない」コツ ✨ ([soft.vub.ac.be][3])

---

## 19.5 ハンズオン：いいね数を「上書き」から「加算」へリファクタ 🛠️💖

ここからは「いいね」を題材に、**競合しにくい形**に直すよ〜！✨
（この章は “最小で動く” 版にして、次章以降で強化していく感じでOK👌）

---

### ① データ構造：Post と LikeDeltaEvent を作る 📦🧾

```ts
// apps/shared/src/types.ts

export type PostId = string;

export type Post = {
  id: PostId;
  title: string;

  // ✅ 合計値は「結果」であって、更新の単位ではない
  likes: number;

  // 🧷 冪等性のため：処理済みイベントIDを覚える（最小構成）
  processedEventIds: Set<string>;
};

export type LikeDeltaEvent = {
  eventId: string;     // 一意（UUIDなど）
  postId: PostId;
  delta: number;       // ここでは +1 だけにしてもOK
  happenedAt: number;  // Date.now()
};
```

---

### ② まず悪い例：上書きAPI（消えるやつ）😱

「やっちゃいがち」な形（参考）👇
※この形を**後で直す**よ！

```ts
// apps/api/src/bad_overwrite_example.ts

import { Post } from "../../shared/src/types";

const posts = new Map<string, Post>();

export function overwriteLikes(postId: string, newLikes: number) {
  const p = posts.get(postId);
  if (!p) throw new Error("post not found");

  // ❌ 合計値を上書き
  p.likes = newLikes;
}
```

この設計だと、同時更新で lost update しやすいのがポイント 🙃

---

### ③ 良い例：APIは「+1イベント」を積む 📨➕

```ts
// apps/api/src/event_queue.ts

import { LikeDeltaEvent } from "../../shared/src/types";

export const likeEventQueue: LikeDeltaEvent[] = [];

// 教材なので「最小のID生成」(本番はUUID推奨)
export function newEventId() {
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
```

```ts
// apps/api/src/like_endpoint.ts

import { likeEventQueue, newEventId } from "./event_queue";
import { LikeDeltaEvent } from "../../shared/src/types";

export function requestLikeIncrement(postId: string) {
  const ev: LikeDeltaEvent = {
    eventId: newEventId(),
    postId,
    delta: 1,
    happenedAt: Date.now(),
  };

  // ✅ ここでやるのは「更新」じゃなく「更新依頼（デルタ）」
  likeEventQueue.push(ev);

  return { accepted: true, eventId: ev.eventId };
}
```

ポイント👇

* APIの役目は「受け取ったよ！」まで（A寄り）🧾✅
* 反映は後で Worker がやる（最終的整合性）⏳

---

### ④ Worker：イベントを集計して反映（重複も防ぐ）🧷🔁

```ts
// apps/worker/src/worker.ts

import { likeEventQueue } from "../../api/src/event_queue";
import { Post, LikeDeltaEvent } from "../../shared/src/types";

const posts = new Map<string, Post>();

// デモ用：初期データ
posts.set("p1", {
  id: "p1",
  title: "カフェの新作☕",
  likes: 0,
  processedEventIds: new Set(),
});

function applyLikeEvent(p: Post, ev: LikeDeltaEvent) {
  // 🧷 冪等：同じイベントがもう処理済みなら無視
  if (p.processedEventIds.has(ev.eventId)) return;

  p.likes += ev.delta; // ✅ 加算！
  p.processedEventIds.add(ev.eventId);
}

export function tickOnce() {
  // 🧪 故障っぽさ：たまに重複配達が起きた体で同じイベントを2回処理してみる
  const ev = likeEventQueue.shift();
  if (!ev) return;

  const p = posts.get(ev.postId);
  if (!p) return;

  applyLikeEvent(p, ev);

  // 10%で重複
  if (Math.random() < 0.1) {
    applyLikeEvent(p, ev);
  }
}

export function getPost(postId: string) {
  const p = posts.get(postId);
  if (!p) throw new Error("post not found");
  return { id: p.id, title: p.title, likes: p.likes };
}
```

ここで勝ち筋はこれ👇

* 反映が遅れても OK（最終的整合性）⏳
* 重複して届いても OK（冪等）🧷
* 順番が多少ズレても「足し算」は基本強い 🔀✅

---

### ⑤ 動作チェック：同時に20回いいねしてみる 💥👍

“同時”を雑に再現するミニスクリプト（例）👇

```ts
// apps/devtools/src/spam_like.ts

import { requestLikeIncrement } from "../../api/src/like_endpoint";
import { tickOnce, getPost } from "../../worker/src/worker";

for (let i = 0; i < 20; i++) {
  requestLikeIncrement("p1");
}

// Workerを回す（実際は常時動いてる想定）
for (let i = 0; i < 25; i++) {
  tickOnce();
}

console.log(getPost("p1"));
```

期待する気持ち 🙏✨

* いいねが 20 付近になる（重複の10%が入ると 20 以上になり得る）
* 「あ、重複したら増えちゃうんだ！」って気づけたら大成功 🎉
  → 次章以降で「重複しても増えない」方向に強化していくよ 🧷🔥

---

## 19.6 よくある落とし穴まとめ ⚠️😵‍💫

### 落とし穴1：デルタは強いけど「重複」には弱い 📨🌀

* リトライで同じイベントが再配達されると、**足し算は二重に増えちゃう**
* だから **イベントIDで重複排除**がほぼ必須 🧷

### 落とし穴2：「取り消し」(−1) を入れると難易度アップ 😮

* +1 だけなら楽（Grow-only）
* -1 も入るなら、設計を「増分と減分を分けて持つ」方向にすると整理しやすい（PN-Counter の発想）🧲➕➖ ([soft.vub.ac.be][3])

---

## 19.7 AI（Copilot等）に頼むと強いプロンプト例 🤖💬

* 「いいねの重複配達を再現するテストケースを10個作って。イベントID重複、順序逆転、遅延を混ぜて」🧪
* 「processedEventIds を永続化するなら、どの層に置く？（Domain/Infra）案を3つ」🧠
* 「“上書き”が危険な理由を、女子大生向けのたとえ話で3つ」🍩✨

---

## 19.8 まとめ 📝🎀

* カウンタ系は **合計値の上書き**より **デルタ（加算）** が強い ➕🔢
* 最終的整合性で避けられない「遅延」「順序ズレ」「重複」に対して、設計で勝ちやすくなる 💪⏳
* 次に強化するなら、**重複しても増えない**ように「冪等キーの永続化」へ進むのが自然 🧷🔥

（参考：TypeScript は現在 5.9 系が最新リリースとして扱われていて、将来はネイティブ実装プレビューの流れも出てきてるよ〜⚡） ([github.com][4])

[1]: https://dsf.berkeley.edu/cs286/papers/crdt-tr2011.pdf?utm_source=chatgpt.com "A comprehensive study of Convergent and Commutative ..."
[2]: https://docs.aws.amazon.com/ja_jp/amazondynamodb/latest/developerguide/example_dynamodb_Scenario_AtomicCounterOperations_section.html?utm_source=chatgpt.com "AWS SDK を使用して DynamoDB でアトミックカウンター ..."
[3]: https://soft.vub.ac.be/dare23/assets/talks/baquero_CRDTsDARE2023.pdf?utm_source=chatgpt.com "CRDTs: State-based approaches to high availability"
[4]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
