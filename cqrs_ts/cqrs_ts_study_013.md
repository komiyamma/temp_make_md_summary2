# 第13章　CommandHandlerの責務（薄く・強く）🧠🧩✨

この章はね、「CommandHandlerってどこまでやっていいの？🤔」問題をスッキリさせる回だよ〜！
**結論：Handlerは“流れ（手順）”担当、ドメインは“ルール（制約）”担当**にすると、CQRSが一気に気持ちよくなる☺️✨

---

## 13.1 まずはイメージ！Handlerは「台本」、ドメインは「法律」🎬⚖️

### ✅ CommandHandlerがやること（流れ）

* 入力を受け取る（Command）📩
* 必要なら軽い入力チェック（型/必須/形式）✅
* 集約（Order）を読み込む📦
* **ドメインのメソッドを呼ぶ（ここが最重要！）**🔔
* 保存する🗄️
* イベントがあれば発行する📣
* 結果を返す🎁

### ✅ ドメインがやること（ルール）

* 「未注文は支払えない🙅‍♀️」
* 「数量は1以上🍙」
* 「合計金額はマイナス禁止💸」
* 状態遷移（ORDERED → PAID など）🔁

> Handlerにルールを書き始めると、すぐ太って地獄になるよ…😵‍💫
> だから **“ルールはドメインへ”** が合言葉！🧠✨

---

## 13.2 2026最新メモ（さらっと）📝✨

* TypeScriptの最新系列は **5.9**（`import defer` や `--module node20`、`tsc --init`の改善、ホバー改善など）だよ〜！開発体験がちょい快適に😆✨ ([Microsoft for Developers][1])
* VS Code周りのAI機能は再編が進んでて、**GitHub Copilot拡張は2026年初頭までにMarketplaceから外れる予定**って明言されてるよ（体験自体は大きく変えない方針）🧩🤖 ([Visual Studio Code][2])
* OpenAI CodexのVS Code拡張もあって、**コードを読んで・編集して・実行まで**を支援する “エージェント寄り” の感じ🛠️✨（Windowsは“experimental”扱いなので、安定しない時はWSLワークスペースが無難） ([OpenAI Developers][3])

※この章の中身（責務分離の考え方）は、ツールが変わってもずっと使える“設計の筋トレ”だよ💪😊

---

## 13.3 ありがちNG：Handlerが太るとこうなる😇💥

### ❌ 太いHandlerの典型パターン

* Handlerの中に **業務ルール** が直書き
* DB更新・外部API・Readモデル更新まで全部やる
* if/else だらけでテストしにくい
* 変更が来るたびHandlerが巨大化🐘

例（わざと悪い例だよ！）👇

```ts
// ❌ 悪い例：PayOrderHandlerが全部やってる（太い！）
export class PayOrderHandler {
  constructor(private db: any) {}

  async handle(cmd: { orderId: string; payMethod: "card" | "cash" }) {
    const order = await this.db.orders.find(cmd.orderId);

    // ルールがHandlerに直書き 😵‍💫
    if (!order) return { ok: false, error: "NOT_FOUND" };
    if (order.status !== "ORDERED") return { ok: false, error: "INVALID_STATE" };
    if (order.total < 0) return { ok: false, error: "BROKEN_TOTAL" };

    // ついでに支払い方法の制約もここ…😇
    if (order.total >= 5000 && cmd.payMethod !== "card") {
      return { ok: false, error: "CARD_REQUIRED" };
    }

    // DB更新もここ
    order.status = "PAID";
    order.paidAt = new Date().toISOString();
    await this.db.orders.update(order);

    // Readモデル更新もここ（WriteとReadが混ざる😭）
    await this.db.orderListView.update(order.id, { status: "PAID" });

    return { ok: true };
  }
}
```

これ、最初は動くんだけどね…
ルールが増えるほど **Handlerが“業務の真実”になっちゃう**のがヤバいの🥲💦

---

## 13.4 正解の形：Handlerは薄く、ドメインは強く💎🛡️

ここからが本番！✨
目標は「Handlerを読んだら、処理の流れがスッと頭に入る」状態😊

---

### ① ドメインにルールを寄せる（Orderが賢くなる）📦🧠

```ts
export type OrderStatus = "ORDERED" | "PAID";

export type DomainEvent =
  | { type: "OrderPaid"; orderId: string; paidAt: string };

export class Order {
  private events: DomainEvent[] = [];

  constructor(
    public readonly id: string,
    private status: OrderStatus,
    private total: number,
    private paidAt?: string,
  ) {}

  pay(payMethod: "card" | "cash", nowIso: string) {
    // ✅ ルールはドメインに置く！
    if (this.status !== "ORDERED") {
      throw new Error("INVALID_STATE");
    }
    if (this.total < 0) {
      throw new Error("BROKEN_TOTAL");
    }
    if (this.total >= 5000 && payMethod !== "card") {
      throw new Error("CARD_REQUIRED");
    }

    this.status = "PAID";
    this.paidAt = nowIso;

    this.events.push({ type: "OrderPaid", orderId: this.id, paidAt: nowIso });
  }

  pullEvents(): DomainEvent[] {
    const out = this.events;
    this.events = [];
    return out;
  }
}
```

ポイント🌟

* 「支払えるか？」の判断は **Orderが知ってる**
* Handlerは **Orderに聞くだけ**
* イベントもドメインが出す（「起きた事実」）📣

---

### ② Handlerは“手順だけ”を書く（台本）🎬✨

```ts
export type PayOrderCommand = {
  orderId: string;
  payMethod: "card" | "cash";
};

export interface OrderRepository {
  findById(orderId: string): Promise<Order | null>;
  save(order: Order): Promise<void>;
}

export interface EventBus {
  publish(events: DomainEvent[]): Promise<void>;
}

export interface Clock {
  nowIso(): string;
}

export class PayOrderHandler {
  constructor(
    private orders: OrderRepository,
    private bus: EventBus,
    private clock: Clock,
  ) {}

  async handle(cmd: PayOrderCommand) {
    // 1) 入力の最低限チェック（形式・必須）✅
    if (!cmd.orderId) return { ok: false, error: "ORDER_ID_REQUIRED" as const };

    // 2) 集約を読む📦
    const order = await this.orders.findById(cmd.orderId);
    if (!order) return { ok: false, error: "NOT_FOUND" as const };

    // 3) ルールはドメインに任せる🛡️
    try {
      order.pay(cmd.payMethod, this.clock.nowIso());
    } catch (e: any) {
      return { ok: false, error: e.message as string };
    }

    // 4) 保存🗄️
    await this.orders.save(order);

    // 5) イベント発行📣
    await this.bus.publish(order.pullEvents());

    return { ok: true as const };
  }
}
```

ほら！Handlerが「流れ」しか書いてないよね☺️✨
こうなると、変更に強いし、テストもしやすい💪🧪

---

## 13.5 どこに書く？早見表🗺️✨

| やりたいこと                   | 置き場所                         | 理由             |
| ------------------------ | ---------------------------- | -------------- |
| 「未注文は支払えない」              | ドメイン（Order.pay）              | 業務ルール＝真実だから🛡️ |
| Commandの必須チェック（orderId空） | Handler（入口）                  | 入口で弾くと早い＆親切😊  |
| DBのSQL/ORM操作             | Repository実装（infrastructure） | 技術都合は外へ🧰      |
| Readモデル更新                | Projection/EventHandler側     | CQRSの分離を守る🧼   |
| “今の時刻”を取る                | Clock（注入）                    | テストしやすくする⌚🧪   |

---

## 13.6 ミニハンズオン：太いPayOrderHandlerを“薄く”する✂️✨

やることはこの順でOK！🧠

1. Handler内の if/else（業務ルール）を見つける🔎
2. それを **Orderのメソッド** に移す📦
3. Handlerは「読む→呼ぶ→保存→発行」だけ残す🎬
4. “今の時刻”みたいな外部依存は `Clock` に逃がす⌚
5. Readモデル更新が混ざってたら、イベント側へ分離📣

> リファクタのコツ：
> **「この判断、業務の言葉で説明できる？」** → できるならドメインへ！🧠✨

---

## 13.7 テストどうする？（ここ超大事）🧪💕

### ✅ ドメインのテスト（最優先！）

* `Order.pay()` が

  * 正しい状態ならPAIDになる✅
  * 間違った状態ならエラーになる🙅‍♀️
  * イベントが出る📣
    をガチガチに固める💪

### ✅ Handlerのテスト（薄いから簡単）

* `findById` が null → NOT_FOUND
* `save` が呼ばれる
* `bus.publish` が呼ばれる
  みたいに “流れ” だけ見る👀✨

---

## 13.8 AI活用（“やりすぎ警報🚨” を鳴らす）🤖🔔

### 🧪 プロンプト例（そのまま投げてOK）

* 「このHandler、責務が混ざってない？混ざってたら、どこに移すべきか理由付きで指摘して🙏」
* 「このHandlerを“読む→呼ぶ→保存→発行”の形に整理して。移動先は Domain / Repository / EventHandler のどれが良い？」
* 「Order.pay に入れるべき不変条件を候補で10個出して、過剰なら削って✨」
* 「このリファクタ後、ユニットテストの観点を AAA で箇条書きにして🧪」

ツールの名前が変わっても、**“レビュー相手として使う”**のがめちゃ強いよ〜😆🤝✨
（最近はVS Code側のAI機能が統合・再編されつつあるのも追い風だね🤖🧩） ([Visual Studio Code][2])

---

## 13.9 まとめ（この章のゴール）🏁✨

* Handlerは **薄く**：やるのは“流れ”だけ🎬
* ドメインは **強く**：業務ルール・状態遷移・不変条件を守る🛡️
* その結果…

  * 変更に強い💪
  * テストがラク🧪
  * CQRSが気持ちいい😊✨

---

次の第14章では、Write側の永続化を守るための **Repository入門🗄️🔁** に入るよ〜！
「DB都合でドメインが汚れるのイヤ😖」をスッキリ解決していこ😆✨

[1]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/ "Announcing TypeScript 5.9 - TypeScript"
[2]: https://code.visualstudio.com/blogs/2025/11/04/openSourceAIEditorSecondMilestone "Open Source AI Editor: Second Milestone"
[3]: https://developers.openai.com/codex/ide/ "Codex IDE extension"
