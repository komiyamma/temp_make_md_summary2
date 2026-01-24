# 第5章　辛さの正体を言語化する（設計の目👓）🧠✨
—「なんかツラい😵‍💫」を「どこが・なぜツラいか」に変える章だよ〜！

---

## この章のゴール🎯✨

この章が終わると、あなたはこう言えるようになります👇

* 「今の実装がツラいのは、**変更理由がごちゃ混ぜ**だからです🌀」
* 「変更したいのはここだけなのに、**影響範囲（爆発半径💣）がデカい**です」
* 「**I/O（DB・HTTP・日時・乱数）**が混ざってて、テストが地獄です🧪😭」

つまり…
**“ただ苦しい” → “苦しい理由を説明できる”** に進化する章です🦋✨

---

## まず「辛さ」って何？😵‍💫➡️🧠

第3〜4章の“分けない版”で起きてた辛さは、だいたいこの3つに集約されます👇

### ① 変更理由が混ざってる（SoCの崩壊）🧺🧦

1つのクラス/関数に、違う種類の仕事が詰め込まれてる状態💦
たとえば同じ `OrderService` の中に…

* 業務ルール（注文できる？支払える？）📜
* DBアクセス（保存・検索）🗄️
* 画面向け整形（DTOに変換）🎁
* エラー文言づくり（ユーザー向け）🗣️

が全部あると、**どれか1個変えるだけでも全部触る羽目**になるよね😇

---

### ② 影響範囲が読めない（爆発半径💣）🌋

「これ変えたいだけなのに…どこまで壊れるの？」が読めない状態😱

* 変更したらテストがいっぱい落ちる🧨
* どの画面が影響受けるか分からない👀
* 修正が“怖いもの”になる🙈

---

### ③ I/Oが混ざってテストがしにくい（純粋性が消える）🧪🚫

I/Oっていうのは、ざっくりこういう“外部とやりとり”のこと👇

* DBアクセス🗄️
* HTTP呼び出し🌐
* 現在時刻 `Date.now()` ⏰
* 乱数 `Math.random()` 🎲
* ファイル、環境変数、ログ出力📁🧾

これが業務ルールと混ざると、**同じ入力でも結果が変わる**し、テストが安定しないよ〜😭

---

## “分けない版”の典型：辛さが出るコード例😇🧨

「こういうの、あるある〜！」ってなるやつをミニ化してみるね👇
（読み物として見てOK、完璧に理解しなくて大丈夫🙆‍♀️）

```ts
// ❌ つらい例：いろんな責務が1つに混ざってる
export class OrderService {
  constructor(private db: any, private payment: any) {}

  async placeOrder(input: { userId: string; items: { menuId: string; qty: number }[] }) {
    // 入力チェック（本来は境界の仕事っぽい）
    if (!input.userId) throw new Error("ユーザーIDが必要です");
    if (input.items.some(x => x.qty <= 0)) throw new Error("数量は1以上です");

    // 業務ルール（ドメインっぽい）
    const total = input.items.reduce((sum, x) => sum + x.qty * 500, 0);
    const now = Date.now(); // I/O（時刻）

    // 永続化（インフラ）
    const orderId = crypto.randomUUID(); // I/O（乱数）
    await this.db.orders.insert({ orderId, userId: input.userId, items: input.items, total, status: "ORDERED", createdAt: now });

    // 画面向け整形（DTOっぽい）
    return { orderId, total, status: "ORDERED", createdAt: new Date(now).toISOString() };
  }

  async payOrder(orderId: string) {
    const order = await this.db.orders.findById(orderId); // I/O（DB）
    if (!order) throw new Error("注文が見つかりません");

    // 状態遷移ルール（ドメイン）
    if (order.status !== "ORDERED") throw new Error("支払いできない状態です");

    // 外部決済（I/O）
    await this.payment.charge({ orderId, amount: order.total });

    // 更新（I/O）
    await this.db.orders.update(orderId, { status: "PAID", paidAt: Date.now() });

    return { ok: true };
  }

  async getOrderList(userId: string) {
    // Queryなのに、DBの形そのまま＆整形もここでやる
    const rows = await this.db.orders.findByUserId(userId);
    return rows.map((r: any) => ({
      id: r.orderId,
      total: r.total,
      status: r.status,
      createdAt: new Date(r.createdAt).toLocaleString(), // 表示都合が混ざる
    }));
  }
}
```

### このコードの「ツラさの正体」🔍😵‍💫

同じファイルに、変更理由が4種類くらい混ざってる👇

* **業務ルールを変えたい**（例：支払い可能条件を追加）📜
* **DBを変えたい**（例：SQLite→Postgres）🗄️
* **画面の表示項目を変えたい**（例：createdAtの表示形式）🖥️
* **外部APIを変えたい**（例：決済サービス変更）💳

これ、全部別の理由なのに…
**全部 `OrderService` を編集する羽目になる** → 変更が衝突しやすい💥

---

## 設計の目👓：今日覚える3つの言葉✨

ここ、超だいじ！この3つだけで会話が一気に“設計っぽく”なるよ😆✨

### 1) 変更理由（Reason to Change）🧾

「このコードを変える理由は何？」って問い。
理由が1つならスッキリ、理由が多いほど「ごちゃ混ぜ」🌀

### 2) 影響範囲（Blast Radius）💣

「変更したら、どこまで波及する？」
影響範囲が読めないほど開発が怖くなる🙈

### 3) I/O混入（Side Effects）🧪

「外部に触る処理（DB/時刻/HTTP）が混ざってる」状態。
**テスト不能**になりがち😭

---

## ミニ演習🎯：「この変更、どこまで波及する？」3問📝✨

いまの“分けない版”を想像してね（OrderServiceに全部ある状態）😇

### 問1：一覧画面に「支払い日時」を表示したい📋⏰

* 変更の種類：表示（Query側）っぽい
* なのに起きがち：PayOrderの保存形式、DTO変換、一覧ロジック…全部触る😇

✅ 答えのコツ：
「表示要件の変更なのに、**支払い処理（Command）まで触る**ならヤバい」⚠️

---

### 問2：決済サービスをA社→B社に変えたい💳🔁

* 変更の種類：外部I/O差し替え
* なのに起きがち：支払い処理のロジック、例外、DB更新、テスト…一気に崩れる🧨

✅ 答えのコツ：
「決済を差し替えるだけで、**注文ルールまで壊れる**なら依存が逆」🙅‍♀️

---

### 問3：「日別売上集計」を追加したい📊✨

* 変更の種類：参照（Query）
* なのに起きがち：注文作成/支払いの内部にも集計都合が入り込む（地獄の始まり）😱

✅ 答えのコツ：
「集計のために、**更新処理に集計カラムが増殖**し始めたら危険」☠️

---

## VS Codeで“影響範囲”を見える化する👀_tf

（ここはすぐ使えるテク！✨）

* **検索（Ctrl+Shift+F）**：`OrderService` / `status` / `paidAt` とかで「関係者」を洗い出す🔎
* **Rename Symbol（F2）**：名前変更が怖い＝結合が強いサイン💡
* **Find All References（Shift+F12）**：参照が多すぎるなら責務が集まりすぎ📌

さらにTypeScriptは「型」で追えるのが強い💪✨
ただし！型が強くても、**責務の混在**は解決しないので注意だよ〜😆

---

## AI活用🤖✨：「辛さの言語化」をAIに手伝わせる

ここ、めっちゃ相性いいです🙆‍♀️💕

### ① 責務を列挙してもらう🧠

AIへのお願い例👇

* 「このクラスの責務を箇条書きにして、カテゴリ分けして」
* 「“変更理由”ごとにグループ化して」

👉 目的：**自分のモヤモヤを言語化**する✨

### ② 影響範囲（爆発半径）を推測してもらう💣

* 「この変更（例：売上集計）を入れると、どの関数が影響受けそう？」

👉 目的：**怖さの正体を見える化**する👀

### ③ 次章の準備：分け方の案を出してもらう🧩

* 「このコードをCQSっぽく“更新と参照”に分けるなら、最小でどう分ける？」

👉 目的：次章（CQS）にスムーズに入る🚪✨

※最近のVS Codeは、AI機能の統合が進んでいて、体験としては“エディタにAIが溶け込む”方向だよ〜。GitHub Copilot拡張は統合の流れで非推奨予定、みたいな話も出てるよ。 ([Visual Studio Code][1])

---

## 2026ミニコラム📌：TS/Nodeの“今”だけ軽く押さえる✨

深追いしないでOK、でも「へぇ〜」ってなるやつだけ😊

* TypeScriptは **5.9** のリリースノートが公開されていて、ドキュメント側も2026年1月に更新が入ってるよ。 ([TypeScript][2])
* VS CodeのTypeScript情報も継続更新されてて、「最新のTypeScriptを試すなら Nightly 拡張で」みたいな導線があるよ。 ([Visual Studio Code][3])
* Node.jsは **v24（Krypton）がActive LTS** として扱われていて、セキュリティリリースも定期的に出てるよ。 ([Node.js][4])

この辺は「環境を新しめで保つと、型・補完・ビルド・依存関係がラクになる」くらいの温度感でOK🙆‍♀️✨

---

## まとめ🎀✨（この章で持ち帰るもの）

あなたが今後、設計の話をするときの“武器”はこれ👇

* ツラい理由はだいたい
  **①変更理由の混在🌀 ②影響範囲が読めない💣 ③I/O混入でテスト不能🧪**
* まずは「辛さ」を**言語化**できれば、改善の方向が見える👓✨
* 次章でやる **CQS（更新と参照を混ぜない）** は、この辛さに効く“最初の処方箋”だよ💊😊

---

次は第6章「CQSの基本（更新と参照は混ぜない）🔀✅」に進むと、今日言語化した“辛さ”がスッと軽くなる流れに入れるよ〜！😆✨

[1]: https://code.visualstudio.com/blogs/2025/11/04/openSourceAIEditorSecondMilestone?utm_source=chatgpt.com "Open Source AI Editor: Second Milestone"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://code.visualstudio.com/docs/languages/typescript?utm_source=chatgpt.com "TypeScript in Visual Studio Code"
[4]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
