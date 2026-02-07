# 第78章 依存の向き：内側が強い🏰➡️🧱✨

この章はね、**「DDDのコードが“壊れにくい体”になる最重要ポイント」**だよ〜！🥰
結論から言うと…

* **内側（domain）は最強💎**＝変更に強い“コア”
* **外側（app/infra）は交換パーツ🔧**＝都合で変わりがち
* だから **依存（import）の向きは「外→内」だけ**にするのが正解🙆‍♀️✨

---

## 1) まず“依存の向き”ってなに？🧭

ここで言う「依存」ってほぼこの2つのことだよ👇

1. **importの依存**（どの層がどの層のコードをimportしてる？）📦
2. **実装の依存**（具体クラスにベタ依存してない？）🧲

DDDで超だいじなのはこのルール👇

* ✅ **domain は app/infra を知らない**
* ✅ **app は domain を使う（呼ぶ）**
* ✅ **infra は domain/app を支える（実装する）**

---

## 2) なんで「内側が強い」ほうがいいの？💗

内側（domain）には **業務ルール（不変条件）**が詰まってるよね🔒
ここが外側の都合でグラグラすると…

* DB変更でドメインが壊れる😱
* API変更でルールが崩れる😱
* テストが重くなって守れなくなる😱

逆に、依存の向きを守ると…✨

* DBを差し替えてもドメイン無傷🛡️
* UIを変えてもドメイン無傷🛡️
* ドメインが軽い＝テスト爆速💨🧪

---

## 3) 依存の向きの“正しい図”🗺️✨

イメージはこれ👇（矢印＝依存）

```
presentation(UI)  →  application  →  domain
                         ↑
                      infrastructure
```

* **矢印が内側に向かうほどOK**🙆‍♀️
* **domain → infra** みたいに逆向きはNG🙅‍♀️⚡

---

## 4) 手を動かして体感しよ！🎮✨（最小サンプル）

ここでは **「OrderRepository を domain に置いて、infra が実装する」**で体験するよ〜！🧁

### 4-1) フォルダ構成（例）📁✨

* `src/domain/...` ＝ルールの城🏰
* `src/application/...` ＝ユースケースの台本🎬
* `src/infrastructure/...` ＝DBや外部連携の部品🔌

---

### 4-2) domain に “interface” を置く💎（ここが核心！）

```ts
// src/domain/order/OrderRepository.ts
import type { Order } from "./Order";
import type { OrderId } from "./OrderId";

export interface OrderRepository {
  save(order: Order): Promise<void>;
  findById(id: OrderId): Promise<Order | null>;
}
```

ポイント🎯

* **domain は “どう保存するか” を知らない**🙆‍♀️
* でも **“保存できるはず” という約束（interface）**は持っていい✨

---

### 4-3) application は interface に依存する🎬

```ts
// src/application/placeOrder/PlaceOrderService.ts
import type { OrderRepository } from "../../domain/order/OrderRepository";
import { Order } from "../../domain/order/Order";

export class PlaceOrderService {
  constructor(private readonly orderRepo: OrderRepository) {}

  async execute(): Promise<void> {
    const order = Order.createNew(); // 例：Factoryやstatic createを想定
    await this.orderRepo.save(order);
  }
}
```

ここ、めっちゃ大事💖

* application は **「保存してね」**と言うだけ
* **DBが何かは知らない**（＝壊れにくい！）🛡️

---

### 4-4) infra が “具体実装” を担当する🔧

```ts
// src/infrastructure/order/InMemoryOrderRepository.ts
import type { OrderRepository } from "../../domain/order/OrderRepository";
import type { OrderId } from "../../domain/order/OrderId";
import type { Order } from "../../domain/order/Order";

export class InMemoryOrderRepository implements OrderRepository {
  private readonly store = new Map<string, Order>();

  async save(order: Order): Promise<void> {
    this.store.set(order.id.value, order);
  }

  async findById(id: OrderId): Promise<Order | null> {
    return this.store.get(id.value) ?? null;
  }
}
```

* infra は **domain の約束（interface）を実現する係**🧑‍🔧✨
* **domain が infra をimportしない**のが勝ちルール🏆

---

### 4-5) どこで組み立てる？（Composition Root）🧩

最後に、**外側で組み立てる**よ👇
（＝依存の向きを守りつつ、アプリを起動できる）

```ts
// src/main.ts
import { PlaceOrderService } from "./application/placeOrder/PlaceOrderService";
import { InMemoryOrderRepository } from "./infrastructure/order/InMemoryOrderRepository";

const orderRepo = new InMemoryOrderRepository();
const service = new PlaceOrderService(orderRepo);

await service.execute();
```

**main.ts は “一番外側”**だから、何をimportしてもだいたいOK🙆‍♀️
（ここが“配線”の場所🔌✨）

---

## 5) よくある事故例（これやると崩れる😵‍💫⚠️）

### ❌ domain が infra を直接importしちゃう

例えば domain の中で…

* Prisma
* DBクライアント
* fetch / axios
* ファイル操作

みたいなのを触り始めると、**城（domain）が外の都合で崩れる**の…🏰💥

---

## 6) 「口約束」じゃなく「仕組み」で守る🚧🛡️（超おすすめ）

ここからが“実務っぽさ”だよ〜！✨
依存の向きは、人間の目だけだと絶対漏れる👀💦
なので **ESLintで機械チェック**しちゃおう🧪

### 6-1) まずは超シンプルに：`no-restricted-imports` 🧱

ESLintの `no-restricted-imports` は「このimport禁止ね！」を設定できるルールだよ✨ ([ESLint][1])
しかも最近は **型だけimportは許可**みたいな運用もやりやすくなってる（`allowTypeImports`）🧠✨ ([ESLint][2])

例（イメージ）：domain から infra を禁止する👇

```js
// eslint.config.js（例：雰囲気をつかむ用）
export default [
  {
    rules: {
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              group: ["../infrastructure/**", "../../infrastructure/**"],
              message: "domain から infrastructure を import しないでね🏰🚫",
            },
          ],
        },
      ],
    },
  },
];
```

※パスはプロジェクト構成で変わるから、ここは自分の構造に合わせてOKだよ🙆‍♀️

---

### 6-2) 本命：`eslint-plugin-boundaries` で“層ルール”を表現🧙‍♀️✨

`eslint-plugin-boundaries` は **アーキ境界をESLintで守るためのプラグイン**だよ📦✨ ([GitHub][3])

強いところ👇

* “domain/app/infra”みたいな **層のルールを宣言**できる
* 違反したら即エラーで止めてくれる🚨

---

### 6-3) ついでに：ESLint自体も最新がどんどん進化してる🧼✨

ESLintは最近もメジャー更新が出てて、周辺も変化が速いよ〜！ ([ESLint][4])
だから「境界ルールを機械化する」って、今どきの現場だとほぼ必須になりがち🛡️

---

## 7) AI（Copilot/Codex）で“依存レビュー”を爆速にする🤖💨

おすすめの使い方テンプレ置いとくね🧁✨

### ✅ 依存の向きレビュー（貼るだけ）

* 「このPRで **domain→infra のimportが混ざってないか**見て。もし混ざってたら、**interfaceをdomainに置く形**で直して。」

### ✅ 依存図を作ってもらう

* 「このフォルダ構成から、**依存の矢印図（domain/app/infra）**をASCIIで描いて。逆向き矢印があったら指摘して。」

### ✅ “違反しやすいポイント”の洗い出し

* 「domain層が外部に依存しやすい“匂い”を10個挙げて。例：DBクライアント、HTTP、Date.now直呼び…」

---

## 8) 章末チェックリスト✅🌸

最後にこれだけ守れてたら、この章はクリアだよ〜！🎉

* ✅ domain が app/infra を import してない
* ✅ 永続化や外部連携は infra に閉じ込めた
* ✅ application は **interface** 越しに保存/取得してる
* ✅ “配線（newする場所）”は外側（main）にある
* ✅ ESLintで依存違反を機械的に検知できる🚨

---

## 9) ミニ問題（理解チェック）🧠💕

1. 「OrderRepository の interface」を置くべき層はどこ？なんで？🏰
2. application が infra の具体クラスを直接 `new` してもいい場所はどこ？🔌
3. domain が外側に依存してしまったとき、起きがちな悲劇を3つ言ってみて😵‍💫

---

## 10) ミニ演習🎮✨（15〜30分）

### 🎯 演習A：わざと壊して、ESLintで止める

1. domain から infra を import する“悪いコード”を1箇所作る😈
2. ESLintルールを入れて、**ちゃんと怒られる**のを確認する🚨✨
3. interface を domain に移して、依存を戻す🏰➡️🧱

### 🎯 演習B：差し替え体験（次章への伏線🔁）

* `InMemoryOrderRepository` を `FileOrderRepository`（仮）に変える想定で、application を一切触らず差し替えできるか試す💖

---

## ちょい最新トピック（軽く）🧡

TypeScriptは現在も 5.x 系が使われていて、5.9 系のリリースノートも公開されてるよ📘✨ ([TypeScript][5])
（この章のテーマ的には “importの副作用を減らす/制御する” みたいな考え方とも相性がいいよ〜🧠💡）

---

次の第79章は、この章で作った「依存の向き」を **“禁止importルール”としてガチガチに仕組み化**していくよ🚧🔥
ここまでの構造、ちゃんと“城”になってきたね〜！🏰✨

[1]: https://eslint.org/docs/latest/rules/no-restricted-imports?utm_source=chatgpt.com "no-restricted-imports - ESLint - Pluggable JavaScript Linter"
[2]: https://eslint.org/blog/2025/10/eslint-v9.37.0-released/?utm_source=chatgpt.com "ESLint v9.37.0 released"
[3]: https://github.com/javierbrea/eslint-plugin-boundaries?utm_source=chatgpt.com "javierbrea/eslint-plugin-boundaries"
[4]: https://eslint.org/blog/2026/02/eslint-v10.0.0-released/?utm_source=chatgpt.com "ESLint v10.0.0 released"
[5]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
