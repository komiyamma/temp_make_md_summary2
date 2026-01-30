# 第25章：CRDT入門①「勝手に収束する」ってどういうこと？🧲✨

## この章の結論（1行）✍️✨

CRDTは「更新がバラバラに起きても、あとでマージしたら同じ状態に落ち着く（＝収束する）」ように作られたデータ構造だよ🧲🌈（順番がズレても、重複して届いてもOKにするのがコツ！） ([ウィキペディア][1])

---

## 今日のゴール🎯💖

この章が終わると、こんな気持ちになれる✨

* 「収束する」って何が嬉しいのかが直感でわかる🧠💡
* “収束しないデータ”がどう壊れるかを、自分で再現できる🧪💥
* CRDTの基本条件（順序ズレ🔀＆重複📨に強い）を言葉で説明できる📣✨

---

# 1) まず「収束」って何？🧵🕰️

## 収束＝「最後にみんな同じになる」🌍✅

分散（=複数のノード/端末/サーバー）だと、同じデータが各所にコピー（レプリカ）されるよね📦📦📦
このとき…

* それぞれが勝手に更新しちゃう✍️✍️
* ネットワークが遅い/切れる⏳🔌
* 更新の届く順番が前後する🔀
* 同じ更新が2回届く（重複配達）📨📨

…みたいなことが普通に起きる😵‍💫

**CRDTは、こういう状況でも「最終的に同じ状態に落ち着く」ことを保証するための考え方/データ型**だよ🧲✨ ([ウィキペディア][1])

---

# 2) 「勝手に収束」が起きるための“最低条件”🧩✅

CRDTにはいろいろ種類があるんだけど、初心者がまず掴むべきはここ👇

## ✅ マージ（merge）が「順番」と「重複」に強いこと💪📨

特に **状態（state）を送り合ってマージするタイプ**（state-based / CvRDT）では、マージ関数がだいたい次を満たすのが基本✨

* **交換法則（commutative）**：順番を入れ替えても同じ
  `merge(A,B) == merge(B,A)` 🔁
* **結合法則（associative）**：まとめ方が違っても同じ
  `merge(merge(A,B),C) == merge(A,merge(B,C))` 🧩
* **冪等性（idempotent）**：同じものが2回届いても増えない
  `merge(A,A) == A` 🧷✅

これがあると、**順序ズレ🔀＆重複📨📨でも壊れにくい**んだよね✨ ([ウィキペディア][1])

> ここ、数学はやらないよ🙅‍♀️📚
> 体感だけでOK！「重複に強い＝冪等」だけはガチで大事🧷✨

---

# 3) 収束しない例：ナイーブな「足し算マージ」➕😇→💥

## ありがちな地雷💣

「各ノードが持ってるカウンタ値を、同期したら足せばよくない？」って思いがちなんだけど…

* ノードAが `1`
* ノードBが `1`
* 同期で `1 + 1 = 2`（一見OK）
* でも同じ状態が**もう一回届く（重複）**と… `2 + 1 = 3` 😱
* さらに届くと… `3 + 1 = 4` 😱😱

**増え続けて爆発**する🔥
これは `merge(A,A)=A` を満たしてない（冪等じゃない）から起きるの💥 ([ウィキペディア][1])

---

# 4) 収束する例：Grow-only Set（追加だけの集合）📚✨

## “追加だけ”は強い💪🌱

たとえば「タグ」みたいに **増やすだけ**の集合なら、

* ノードA：`{"apple"}` 🍎
* ノードB：`{"banana"}` 🍌
* マージ：**和集合（union）** ⇒ `{"apple","banana"}` 🍎🍌

で、順番がどうでも、重複して届いても、最後は同じになりやすい🧲✨
これが “収束しやすいデータ” の代表例だよ📚✅

---

# 5) ハンズオン：3ノードで「収束する/しない」を見比べる🧪🔀📨

ここでは **同じ「同期」を何回も・順番バラバラ・重複あり**で回して、挙動を観察するよ👀✨

## 5.1 準備（TypeScriptをサクッと実行⚡）

今回は `tsx` を使うよ（Node.js公式の学習ページでも TypeScript実行手段として紹介されてるやつ）🚀 ([nodejs.org][2])

```bash
npm i -D tsx typescript
```

---

## 5.2 実験コード（コピペOK）📄✨

`apps/worker/src/ch25-crdt-lab.ts` みたいな場所に保存してね🗂️💕

```ts
// ch25-crdt-lab.ts
// ねらい：
// ✅ 収束しない例：ナイーブな「足し算マージ」(冪等じゃない)
// ✅ 収束する例：Grow-only Set（union は冪等）
// を「順番バラバラ・重複あり」の同期で体感する🧪🔀📨

type NodeId = "A" | "B" | "C";

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function cloneSet<T>(s: Set<T>): Set<T> {
  return new Set([...s]);
}

/** ❌ 収束しない：状態を「足す」マージ（冪等じゃない） */
class NaiveSumCounter {
  value = 0;

  inc(n = 1) {
    this.value += n;
  }

  // これが地雷💣：同じ状態が重複して届くと、どんどん増える
  merge(remote: NaiveSumCounter) {
    this.value += remote.value;
  }

  snapshot(): NaiveSumCounter {
    const c = new NaiveSumCounter();
    c.value = this.value;
    return c;
  }

  toString() {
    return String(this.value);
  }
}

/** ✅ 収束しやすい：Grow-only Set（追加だけ） */
class GSet {
  items = new Set<string>();

  add(x: string) {
    this.items.add(x);
  }

  // union は「順番OK」「重複OK」になりやすい✨
  merge(remote: GSet) {
    for (const x of remote.items) this.items.add(x);
  }

  snapshot(): GSet {
    const s = new GSet();
    s.items = cloneSet(this.items);
    return s;
  }

  toString() {
    return `{${[...this.items].sort().join(",")}}`;
  }
}

/** 疑似ネットワーク：順番シャッフル＆重複配達あり📨🔀 */
function syncRounds<T extends { merge(r: T): void; snapshot(): T; toString(): string }>(
  name: string,
  nodes: Record<NodeId, T>,
  rounds: number
) {
  const ids: NodeId[] = ["A", "B", "C"];

  // “メッセージ”は「スナップショットを送る」扱い（state-basedっぽく）
  type Msg = { from: NodeId; to: NodeId; payload: T };

  let inbox: Msg[] = [];

  for (let r = 1; r <= rounds; r++) {
    // 1) 送信を作る（全員が全員へ送りがち、という雑な状況）
    for (const from of ids) {
      for (const to of ids) {
        if (from === to) continue;
        // 送るかどうかはランダム（ネットワークの気まぐれ）
        if (Math.random() < 0.7) {
          inbox.push({ from, to, payload: nodes[from].snapshot() });
        }
      }
    }

    // 2) 重複配達を発生させる（同じメッセージが2回届く📨📨）
    if (inbox.length > 0 && Math.random() < 0.5) {
      inbox.push(pick(inbox));
    }

    // 3) 届く順番をぐちゃぐちゃにする🔀
    inbox = shuffle(inbox);

    // 4) 受信してマージ
    for (const msg of inbox) {
      nodes[msg.to].merge(msg.payload);
    }

    // 5) ラウンドごとに軽く表示
    const stateLine = ids.map((id) => `${id}:${nodes[id].toString()}`).join("  ");
    console.log(`[${name}] round ${String(r).padStart(2, "0")}  ${stateLine}`);

    // 次ラウンドへ
    inbox = [];
  }

  // 最終比較
  const final = ids.map((id) => nodes[id].toString());
  const allSame = final.every((x) => x === final[0]);
  console.log(`\n[${name}] final: ${ids.map((id, i) => `${id}:${final[i]}`).join("  ")}`);
  console.log(`[${name}] converge? => ${allSame ? "YES ✅" : "NO ❌"}\n`);
}

function main() {
  console.log("=== Chapter 25: CRDT convergence lab 🧲✨ ===\n");

  // ❌ ナイーブカウンタ（壊れる）
  const c: Record<NodeId, NaiveSumCounter> = {
    A: new NaiveSumCounter(),
    B: new NaiveSumCounter(),
    C: new NaiveSumCounter(),
  };
  // みんなローカルで勝手に更新✍️
  c.A.inc(1);
  c.B.inc(1);
  c.C.inc(1);

  syncRounds("NaiveSumCounter 💥", c, 10);

  // ✅ G-Set（収束しやすい）
  const s: Record<NodeId, GSet> = {
    A: new GSet(),
    B: new GSet(),
    C: new GSet(),
  };
  s.A.add("apple🍎");
  s.B.add("banana🍌");
  s.C.add("cherry🍒");

  syncRounds("GSet 🧲", s, 10);

  console.log("次の章（第26章）では、カウンタを“ちゃんと収束する形”に直していくよ🔧🔢✨");
}

main();
```

---

## 5.3 実行してみよう🏃‍♀️💨

```bash
npx tsx apps/worker/src/ch25-crdt-lab.ts
```

### 見どころ👀✨

* `NaiveSumCounter 💥` は、ラウンドが進むほど値が増え続けたり、ノードごとにズレたりしやすい😱📈
  → **重複配達📨📨に弱い（冪等じゃない）**から💥
* `GSet 🧲` は、最終的にみんな同じ集合になりやすい🍎🍌🍒✅
  → **union が「順序OK🔀」「重複OK📨」**だから🧲✨

この“体感”が入ると、CRDTの説明が一気にラクになるよ🫶✨ ([ウィキペディア][1])

---

# 6) 現場の「CRDTどこで出る？」👩‍💻📱✨

いちばん有名なのは **共同編集**（Google Docs みたいなやつ）や、**オフラインでも書けて後で同期**する“local-first”系📝📶✨
CRDTは、こういう「切れても作業を続けたい」系の体験を支える土台になりがちだよ🌈

* **Yjs**：共同編集向けのCRDT実装で、Map/Arrayみたいな共有型を扱える🧩✨ ([GitHub][3])
* **Automerge 2.0**：本番利用を意識したCRDTとして性能・信頼性を上げた、と公式が言ってる💪🚀 ([automerge.org][4])
* “local-first software” という考え方自体も、オフライン・協調・データ所有の原則として整理されてるよ📦🔐 ([inkandswitch.com][5])

---

# 7) AI（Copilot / Codex）に聞くと理解が爆速になる質問集🤖💬✨

そのままコピペでOKだよ🫶

* 「CRDTの“収束”を、大学生にわかるたとえ話で3つ作って。1つは“重複配達”を含めて！」🧲📨
* 「この `NaiveSumCounter` の merge がダメな理由を、**冪等性**の観点で説明して！」🧷✅
* 「`GSet` の merge（union）が commutative / associative / idempotent を満たす理由を、短い文章で！」🧩✨
* 「次章の予習として、カウンタを“収束する形”にする設計案を2つだけ（数式なし）で！」🔢🌱

---

# まとめ🎀✨

* 分散では「順番ズレ🔀」「重複配達📨📨」が当たり前
* CRDTは、そんな世界でも **最終的に同じ状態に落ち着く（収束する）**ように作る考え方🧲✨ ([ウィキペディア][1])
* state-based系では特に、マージが
  **交換法則・結合法則・冪等性** を満たすのが超大事🧷✅ ([ウィキペディア][1])
* “壊れる例”を見たあとに “収束する例”を見ると、CRDTが一気に腑に落ちる🫶🌈

---

[1]: https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type?utm_source=chatgpt.com "Conflict-free replicated data type"
[2]: https://nodejs.org/en/learn/typescript/run?utm_source=chatgpt.com "Running TypeScript with a runner"
[3]: https://github.com/yjs/yjs?utm_source=chatgpt.com "yjs/yjs: Shared data types for building collaborative software"
[4]: https://automerge.org/blog/automerge-2/?utm_source=chatgpt.com "Introducing Automerge 2.0"
[5]: https://www.inkandswitch.com/essay/local-first/?utm_source=chatgpt.com "Local-first software: You own your data, in spite of the cloud"
