# 第22章：競合解決の選び方（LWW/ルール/マージ）🎛️🧠

## この章の結論1行 ✍️✨

**「LWWで済むデータ」か「ドメインルールで守るべきデータ」か「最初からマージできる形にする」かを、データごとに決めるのが勝ち筋だよ〜！** 🏆😊

---

# 1) この章でできるようになること 🎯💪

読み終わると、こんな判断ができるようになるよ👇✨

* 「これ、LWWでいい？危ない？」を説明できる 🧠⚠️
* お金💸・在庫📦・状態遷移🔁みたいな**“壊れると困る”データ**に、**ドメインルール**でガードを入れられる 🧱🔒
* 「集合」「履歴」「加算」みたいに、**マージしやすい表現**を選べる 🧩➕
* 競合が起きたときに、**ログに“事故の証拠”を残す**設計ができる 🕵️‍♀️🧾

---

# 2) 競合っていつ起きるの？（前章の復習）💥⚔️

競合はだいたいこの3つで発生するよ👇

* **同時更新**（AさんとBさんが同じ注文を別々に更新）👭🛒
* **遅延・分断**（ネットワークが遅くて、更新が前後して届く）⏳🔌
* **リトライ・二重送信**（同じ更新が複数回届く）🔁📨

ここで怖いのは「エラーにならずに、静かに壊れる」こと…😇💣
Jepsen系の検証でも、LWWの自動解決が**新しい値を捨てたり、ロストアップデートを防げなかったり**する話が出てくるよ。([jepsen.io][1])

---

# 3) 競合解決の3大パターン 🌟（LWW / ルール / マージ）

## A. LWW（Last-Write-Wins）🕒👑

**いちばん新しい更新（タイムスタンプが最大）を採用する**方式だよ。

**いいところ** ✅

* 実装が超ラク（比較して勝ちを決めるだけ）😌
* 速度も出る（自動で片付く）⚡

**こわいところ** 😱

* **時計ズレ（clock skew）**で、実際は古い更新が“新しい扱い”になって勝つことがあるよ🕰️💥
  （NTPがあってもズレは起きうる、って話がよく出る）([DZone][2])
* 因果的に同時（どっちが先かわからない）更新だと、**成功した更新が静かに捨てられる**ことがある😇🗑️([InfoQ][3])

**LWWが向いてるケース** 👍

* 「最後の状態だけあればOK」で、途中の更新を失っても致命傷になりにくい
  例：プロフィールの“自己紹介文”、UIの設定（テーマ/並び順）🎨⚙️
* さらに安全にするなら

  * **“サーバー側で単調増加のversion”**を使う（壁時計に頼らない）📈
  * **履歴（イベント）を別に残す**（捨てたくない事実は消さない）📚

---

## B. ドメインルール（業務ルールで決める）📜🧱

**「その業務だと何が正しいか」**で勝者を決める方式だよ。

**いいところ** ✅

* **不変条件（インバリアント）**を守れる（壊れにくい）🛡️
* 「キャンセル済みなのに発送済み」みたいな事故を防ぎやすい🚫📦

**注意ポイント** ⚠️

* ルールが曖昧だと実装も曖昧になりがち😵‍💫
* ルールを増やしすぎると読みづらい（状態機械にするとスッキリ）🔁🗺️

**ルールが向いてるケース** 👍

* お金💸 / 在庫📦 / 契約⚖️ / 返金💳 みたいな**壊れたら痛い領域**
* 「正しい状態遷移」が決まってる領域（注文・配送・決済など）🛒🚚💳

---

## C. マージ（複数の更新を“合成”する）🧩🧲

**更新を捨てずに“両方取り込む”**方式だよ。
CRDTみたいに「勝手に収束する」発想もここに入るよ〜（後の章で深掘り！）🌱✨([ウィキペディア][4])

**いいところ** ✅

* “取りこぼし”が減る（捨てない）🙆‍♀️
* 競合に強い（順序がズレても最終的に同じになりやすい）🧲

**向いてるデータ表現** 🎯

* **集合（set）**：タグは「追加」なら union でOK 🏷️➕
* **加算（counter）**：いいね数は「上書き」より「加算」👍➕
* **履歴（event log）**：操作は追記、表示は集計 📚🧮

---

# 4) どれを選ぶ？判断チェックリスト ✅📋

迷ったらこれで決めよ〜！🫶✨

## まず最初に聞く4問 ❓

1. **更新を“捨ててもいい”タイプ？**（設定とか）⚙️
2. **壊れたらお金/法務/信用が死ぬ？**（決済・在庫とか）💸⚖️
3. **「両方取り込める表現」にできる？**（集合・履歴・加算）🧩
4. **競合が起きた事実を後から追う必要ある？**（監査・調査）🕵️‍♀️🧾

## 選び方のざっくり早見 🧭

* **LWW**：捨ててもOK / 最終状態だけ欲しい / 超シンプルでいい 🕒
* **ルール**：不変条件を守りたい / 状態遷移がある / 壊れると痛い 🧱
* **マージ**：捨てたくない / 合成できる形にできる / 収束させたい 🧲

（ちなみにDynamo系は、競合版を残して**アプリ側でマージ**させる設計が典型だよ🛒📦）([All Things Distributed][5])

---

# 5) ハンズオン：LWW版とルール版を比較して事故を見る 😱🧪

題材：**注文ステータス**（PAID / CANCELLED / SHIPPED）🛒💳🚚
「キャンセルしたのに発送になった」事故を、LWWでわざと起こすよ🔥

## 5-1. まずは型を作る 🧱✨

`apps/worker/src/conflict/orderTypes.ts`

```ts
export type OrderStatus = "PAID" | "CANCELLED" | "SHIPPED";

export type OrderUpdate = {
  orderId: string;
  status: OrderStatus;

  /**
   * 更新を書いた側が付けた “壁時計” の時刻（ms）
   * ※ここがズレるとLWWが事故る…！
   */
  updatedAtMs: number;

  /** 追跡用（どこから来た更新？） */
  source: "api" | "shipping-worker" | "payment-worker";

  /** ログ用（ユニークでなくてOK、見分けがつけばOK） */
  updateId: string;
};

export type Resolution = {
  chosen: OrderUpdate;
  dropped: OrderUpdate[];
  notes: string[];
};
```

---

## 5-2. LWW（壁時計）で解決する関数 🕒👑

`apps/worker/src/conflict/resolveLww.ts`

```ts
import { OrderUpdate, Resolution } from "./orderTypes.js";

export function resolveByLww(a: OrderUpdate, b: OrderUpdate): Resolution {
  // updatedAtMs が大きいほうを勝ちにする（同点ならupdateIdで安定化）
  const winner =
    a.updatedAtMs > b.updatedAtMs ? a :
    a.updatedAtMs < b.updatedAtMs ? b :
    (a.updateId > b.updateId ? a : b);

  const loser = winner === a ? b : a;

  return {
    chosen: winner,
    dropped: [loser],
    notes: [
      `LWW: updatedAtMs が新しい方を採用 (${winner.updateId})`,
      "⚠️ 注意: 時計ズレがあると、実際は古い更新が勝つ可能性あり",
    ],
  };
}
```

LWWが時計ズレに弱いのは定番の落とし穴だよ🕰️💥([DZone][2])

---

## 5-3. ドメインルール（状態遷移）で解決する関数 📜🧱

ここではルールを超シンプルにするね👇

* **CANCELLED の後に SHIPPED はありえない**（発送は止めるべき）🚫📦
* 競合してたら **CANCELLED を優先**しつつ、**要調査ログ**を残す 🕵️‍♀️

`apps/worker/src/conflict/resolveRule.ts`

```ts
import { OrderUpdate, Resolution, OrderStatus } from "./orderTypes.js";

function isValidTransition(from: OrderStatus, to: OrderStatus): boolean {
  // すでにキャンセル済みなら、発送には絶対に行かない
  if (from === "CANCELLED" && to === "SHIPPED") return false;

  // 今回は最小ルール：PAIDからはCANCELLED/SHIPPEDどっちも起こりうる
  // （ただし同時に来たら“競合”として扱う）
  return true;
}

/**
 * 競合解決：業務ルール優先
 * - CANCELLEDとSHIPPEDが競合したらCANCELLEDを採用（安全側）
 * - ただし notes に「要調査」を残す
 */
export function resolveByDomainRule(
  current: OrderStatus,
  a: OrderUpdate,
  b: OrderUpdate
): Resolution {
  const notes: string[] = [];

  // まず遷移として不正なものを落とす
  const aOk = isValidTransition(current, a.status);
  const bOk = isValidTransition(current, b.status);

  if (aOk && !bOk) {
    notes.push(`ルール: ${b.status} は不正遷移なので破棄 (${b.updateId})`);
    return { chosen: a, dropped: [b], notes };
  }
  if (!aOk && bOk) {
    notes.push(`ルール: ${a.status} は不正遷移なので破棄 (${a.updateId})`);
    return { chosen: b, dropped: [a], notes };
  }

  // 両方OKでも、CANCELLED vs SHIPPED のような「業務的に衝突」なら安全側に倒す
  const statuses = new Set([a.status, b.status]);
  if (statuses.has("CANCELLED") && statuses.has("SHIPPED")) {
    const winner = a.status === "CANCELLED" ? a : b;
    const loser = winner === a ? b : a;
    notes.push("🚨 競合: CANCELLED と SHIPPED が同時に来たよ");
    notes.push(`安全側: CANCELLED を採用 (${winner.updateId})`);
    notes.push("🕵️‍♀️ 要調査: 発送停止・返金・在庫戻しなどの確認が必要かも");
    return { chosen: winner, dropped: [loser], notes };
  }

  // それ以外は最終手段でLWW（ここでも“壁時計依存”に注意）
  notes.push("補助: ルールで決まらないので最終手段としてLWWへ");
  return {
    chosen: a.updatedAtMs >= b.updatedAtMs ? a : b,
    dropped: [a.updatedAtMs >= b.updatedAtMs ? b : a],
    notes,
  };
}
```

---

## 5-4. テストで「LWW事故」を目で見る 👀💣

`apps/worker/src/conflict/resolve.test.ts`

```ts
import test from "node:test";
import assert from "node:assert/strict";
import { resolveByLww } from "./resolveLww.js";
import { resolveByDomainRule } from "./resolveRule.js";
import { OrderUpdate } from "./orderTypes.js";

test("😱 LWWは時計ズレで 'キャンセルしたのに発送' が起こりうる", () => {
  const orderId = "o-100";

  // 本当は：キャンセル（後）が正しい
  const cancel: OrderUpdate = {
    orderId,
    status: "CANCELLED",
    // API側は時計が遅れている（小さい値）
    updatedAtMs: 1_000,
    source: "api",
    updateId: "u-cancel",
  };

  const shipped: OrderUpdate = {
    orderId,
    status: "SHIPPED",
    // shipping-worker側の時計が進んでる（大きい値）
    updatedAtMs: 9_999,
    source: "shipping-worker",
    updateId: "u-ship",
  };

  const r = resolveByLww(cancel, shipped);

  // LWWだと shipped が勝ってしまう…😇
  assert.equal(r.chosen.status, "SHIPPED");
});

test("✅ ルールなら 'キャンセル済みなのに発送' を安全側で止められる", () => {
  const orderId = "o-100";

  const cancel: OrderUpdate = {
    orderId,
    status: "CANCELLED",
    updatedAtMs: 1_000,
    source: "api",
    updateId: "u-cancel",
  };

  const shipped: OrderUpdate = {
    orderId,
    status: "SHIPPED",
    updatedAtMs: 9_999,
    source: "shipping-worker",
    updateId: "u-ship",
  };

  const r = resolveByDomainRule("PAID", cancel, shipped);

  assert.equal(r.chosen.status, "CANCELLED");
  assert.ok(r.notes.some((x) => x.includes("要調査")));
});
```

👉 実行してみてね（nodeのテスト機能を使うよ）🧪✨
`node --test apps/worker/src/conflict/resolve.test.ts`

---

# 6) もう1つ：マージできるデータの例（集合）🏷️🧩

「タグ」みたいに **集合（set）** にできるものは、競合しても**和集合（union）**で収束しやすいよ🙆‍♀️✨
（CRDTの考え方にもつながるよ）([ウィキペディア][4])

`apps/worker/src/conflict/mergeSet.ts`

```ts
export function mergeSet<T>(a: ReadonlyArray<T>, b: ReadonlyArray<T>): T[] {
  return Array.from(new Set([...a, ...b]));
}
```

---

# 7) よくある落とし穴ワースト5 😵‍💫⚠️

1. **“壁時計”を信じすぎる**（LWWが事故る）🕰️💥([DZone][2])
2. **勝った方だけ保存して、負けた方を捨ててしまう**（後から調査不能）🗑️🕵️‍♀️
3. **状態を上書き1本で表現**して、履歴を残さない（原因追跡できない）📉
4. **競合ログがない**（現場で「たまに変」系バグになる）👻
5. **“勝ち”を決めた理由がコードに埋もれる**（ルールが読めない）🧠💤

ちなみにCouchDB系だと「勝者（winning revision）」は決まるけど、競合が残っているとビューから情報が落ちたりする例が説明されてるよ（＝勝者だけ見て安心すると危ない）📄⚠️([docs.couchdb.org][6])

---

# 8) AI（Copilot/Codex）で爆速に理解するコツ 🤖💨

そのまま貼って使えるプロンプト例だよ📝✨

* **状態遷移表を作る**
  「注文ステータス PAID/CANCELLED/SHIPPED の状態遷移表を作って。禁止遷移と理由も。」🔁📋

* **競合ケースを増やす**
  「このresolveByDomainRuleに対して、事故りそうなテストケースを10個作って（ケース名も）。」🧪💥

* **ログ設計レビュー**
  「競合が起きたときのログに最低限入れるべき項目（相関ID/更新元/採用理由など）をチェックリスト化して。」🕵️‍♀️🧾

---

# 9) まとめ 🧸✨（セルフチェック付き）

## まとめ1行

**競合解決は「楽さ（LWW）」より「正しさ（ルール）」や「捨てない（マージ）」が大事な場面が多いよ！** 🎛️💖

## セルフチェック✅

* LWWが事故る代表原因を1つ言える？（ヒント：時計）🕰️
* 注文・決済みたいな領域で「守るべき不変条件」は何？🧱
* “集合/履歴/加算”にできるデータを1つ思いつける？🧩➕

---

[1]: https://jepsen.io/analyses/aerospike-3-99-0-3?utm_source=chatgpt.com "Aerospike 3.99.0.3"
[2]: https://dzone.com/articles/conflict-resolution-using-last-write-wins-vs-crdts?utm_source=chatgpt.com "Conflict Resolution: Using Last-Write-Wins vs. CRDTs"
[3]: https://www.infoq.com/articles/jepsen/?utm_source=chatgpt.com "Jepsen: Testing the Partition Tolerance of PostgreSQL, ..."
[4]: https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type?utm_source=chatgpt.com "Conflict-free replicated data type"
[5]: https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf?utm_source=chatgpt.com "Dynamo: Amazon's Highly Available Key-value Store"
[6]: https://docs.couchdb.org/en/stable/replication/conflicts.html?utm_source=chatgpt.com "2.3. Replication and conflict model - CouchDB docs"
