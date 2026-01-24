# 第3章　まずは“分けない版”を作る①（最小の動く形）😅🔧

## 今日のゴール🎯✨

* 注文を **作る（create）** と **一覧を見る（list）** を、**1つの `OrderService` に雑に詰め込んで**動かす💨
* 「動くけど、これ…増えたらヤバそう😇」をうっすら感じる👀🌱

ちなみに2026/1/24時点だと、TypeScript の npm “latest” は **5.9.3**、Node.js は **v24 が Active LTS**、VS Code は **1.108 系**が安定版として案内されてるよ🧡
（このへんは手順中の `@latest` で自然に追従する想定！） ([NPM][1])

---

## できあがりイメージ🍙📱

* `POST /orders` → 注文を作る🧾✨
* `GET /orders` → 注文一覧を返す📋✨
* データは **メモリ上（配列）** に保存（いったん軽く！🪶）

---

# 1) プロジェクト作成📁✨（最小でOK）

ターミナルでこれ👇（フォルダ名は好きにどうぞ！）

```bash
mkdir cqrs-ch3
cd cqrs-ch3
npm init -y
```

必要なものを入れる👇（Expressで最小APIにするよ〜🌐）

```bash
npm i express
npm i -D typescript tsx @types/express
```

`tsx` は「TypeScriptをそのまま実行」しやすいやつ⚡（初心者にやさしい） ([GitHub][2])

---

# 2) tsconfig.json を作る🛠️✨

```bash
npx tsc --init
```

できた `tsconfig.json` を、いったんこの感じに寄せる（全部同じでOK！）👇

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",

    "rootDir": "src",
    "outDir": "dist",

    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
```

---

# 3) 実行スクリプトを用意🏃‍♀️💨

`package.json` の `"scripts"` をこうする👇

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts"
  }
}
```

---

# 4) ぜんぶ詰め込み `src/index.ts` を作る😅📦

フォルダ作って👇

```bash
mkdir src
```

`src/index.ts` を作って、これをコピペでOK👇（**わざと**全部ここに入れるよ！）

```ts
import express from "express";
import { randomUUID } from "crypto";

/**
 * 「分けない版」なので、型もサービスも保存もルーティングもぜんぶ同居😅
 * ※この雑さが、あとで効いてくる…！
 */

type OrderStatus = "ORDERED" | "PAID";

type OrderItem = {
  menuId: string;
  name: string;
  price: number; // 本当は通貨や丸めがあるけど、いまは雑でOK🪶
  qty: number;
};

type Order = {
  id: string;
  customerId: string;
  items: OrderItem[];
  total: number;
  status: OrderStatus;
  createdAt: string;
};

type CreateOrderRequest = {
  customerId: string;
  items: OrderItem[];
};

class OrderService {
  // DBの代わりに配列で保存（雑だけど最小で動く！）
  private orders: Order[] = [];

  createOrder(req: CreateOrderRequest): Order {
    // いったん雑バリデーション（この章は“最低限”でOK🙂）
    if (!req.customerId) {
      throw new Error("customerId is required");
    }
    if (!Array.isArray(req.items) || req.items.length === 0) {
      throw new Error("items must be a non-empty array");
    }
    for (const item of req.items) {
      if (!item.menuId) throw new Error("menuId is required");
      if (!item.name) throw new Error("name is required");
      if (typeof item.price !== "number" || item.price < 0) throw new Error("price must be >= 0");
      if (typeof item.qty !== "number" || item.qty <= 0) throw new Error("qty must be > 0");
    }

    const total = req.items.reduce((sum, i) => sum + i.price * i.qty, 0);

    const order: Order = {
      id: randomUUID(),
      customerId: req.customerId,
      items: req.items,
      total,
      status: "ORDERED",
      createdAt: new Date().toISOString()
    };

    this.orders.push(order);
    return order;
  }

  listOrders(): Order[] {
    // そのまま返す（整形とかページングとかは、まだやらない🙂）
    return this.orders;
  }
}

// --- ここから “API” も同じファイルに同居 😅 ---
const app = express();
app.use(express.json());

const orderService = new OrderService();

app.post("/orders", (req, res) => {
  try {
    const created = orderService.createOrder(req.body);
    res.status(201).json(created);
  } catch (e) {
    const message = e instanceof Error ? e.message : "unknown error";
    res.status(400).json({ error: message });
  }
});

app.get("/orders", (_req, res) => {
  const list = orderService.listOrders();
  res.json(list);
});

const port = 3000;
app.listen(port, () => {
  console.log(`✅ server running: http://localhost:${port}`);
});
```

---

# 5) 起動する▶️✨

```bash
npm run dev
```

コンソールにこれが出たらOK👇

* ✅ `server running: http://localhost:3000`

---

# 6) 動作確認する🧪✨（PowerShellでもOK）

## 注文を作る（POST）🧾🍙

### いちばん楽：PowerShell の `Invoke-RestMethod` 💙

```powershell
$body = @{
  customerId = "u-001"
  items = @(
    @{ menuId="m-001"; name="カツ丼"; price=650; qty=1 },
    @{ menuId="m-002"; name="味噌汁"; price=120; qty=1 }
  )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Post -Uri "http://localhost:3000/orders" -ContentType "application/json" -Body $body
```

成功すると `id` と `total` とかが返ってくるよ〜✨

## 一覧を見る（GET）📋✨

```powershell
Invoke-RestMethod -Method Get -Uri "http://localhost:3000/orders"
```

---

# 7) この章の「わざと雑」ポイント観察👀🌱

動いた！えらい！🎉 …でも、今の `OrderService` って、もうすでに👇が混ざってる😅

* 入力チェック（バリデーション）🧹
* 合計計算（業務っぽいロジック）🧠
* ID発行（技術都合）🪪
* 保存（DBっぽい責務）🗄️
* 一覧返す（表示寄りの要求が来がち）📋

この状態で、次章で「支払い」「状態遷移」「検索条件」みたいなものが増えると…
**“1クラスが巨大化して、変更が怖くなる”** って流れになりやすいんだよね😇📌

（この“嫌な予感”を、次章でわざと現実にするよ！😆🔥）

---

# 8) ミニ演習（5〜15分）🧩✨

## 演習A：注文に `note`（備考）を追加📝

* `CreateOrderRequest` に `note?: string` を追加
* `Order` にも `note?: string` を追加
* `createOrder` がそれを保存して返すようにする

👉 **ポイント**：地味だけど、こういう小変更が積み重なると `OrderService` がどんどん太る🍔😅

## 演習B：`GET /orders?status=ORDERED` を追加🔎

* `app.get("/orders"...` でクエリを見る
* `listOrders()` にフィルタ引数を足してもいいし、ルート側でやってもいい

👉 **ポイント**：「Query（参照）」の都合が入り始めると、更新ロジックと同居してカオス化しやすい🌪️

---

# 9) AI活用🤖✨（この章での使いどころ）

💡おすすめの頼み方（コピペOK）👇

* 「今の `CreateOrderRequest` に note を追加して、APIの入出力も壊さずに通して」
* 「`GET /orders` に status フィルタを追加して。型がanyにならないように」
* 「今の `OrderService` の責務が混ざってるところを箇条書きで指摘して」

✅ AIの出力をチェックするコツ

* `any` が増えてない？（増えてたら負け😇）
* エラーが握りつぶされてない？
* 仕様（statusフィルタなど）が勝手に変わってない？

---

## まとめ🎀✨

この章は「分けない版」を**あえて**作って、

* 最小で動く体験🎉
* そして“混ざり始める匂い”を嗅ぐ👃🌱
  ここまでが目的だよ〜😄🧡

次の第4章で、ここに機能を足して **“うわ、つらい😵‍💫”** を体験しに行こうね🔥

[1]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[2]: https://github.com/privatenumber/tsx?utm_source=chatgpt.com "privatenumber/tsx: ⚡️ TypeScript Execute | The easiest ..."
