# 第27章：古いクライアントを殺さないリリース🧟‍♀️➡️🙂

## この章のゴール🎯✨

* 古いクライアント（例：更新されてないスマホアプリ、古いフロント、旧SDK）が **混ざったまま** でも、サーバー側のリリースで事故らないようにする🙂🧯
* 「サーバ先行」「クライアント先行」どっちでも安全な **段階リリースの型** を身につける🪜⏳
* 互換性を守るための実装テク（TypeScriptの型＋実行時の守り）を、手で書ける✍️🟦

---

## 1) なんで“古いクライアント”が残るの？📱🐢

現実では、クライアントは同じスピードで更新されません😵‍💫
たとえば…

* アプリの自動更新がOFFの人🙅‍♀️
* 会社PCで更新に制限がある人🏢🔒
* 旧バージョンのままでも「今は困ってない」人😌
* リリース後もしばらくキャッシュや古いJSが残るケース🍪🧊

だからサーバーは基本、**新旧クライアントが同時に来る前提**で作ります🧠🔁
ここを忘れると「昨日までは動いたのに😡」が簡単に起きます💥

---

## 2) まず押さえる大前提📌✨「リリース中は“新旧が混ざる”」

リリースって、ふつうこうなります👇

* サーバーA（新）🆕 と サーバーB（旧）🧓 が同時に動く時間がある
* さらにその間、クライアントも **新🆕** と **旧🧓** が混ざる

つまり組み合わせは最大で4通り😵‍💫🧩

* 新クライアント → 新サーバー ✅
* 新クライアント → 旧サーバー ✅（これが通ると強い💪）
* 旧クライアント → 新サーバー ✅（ここで死にがち💀）
* 旧クライアント → 旧サーバー ✅

この章では、特に「旧 → 新」で死なない方法を鍛えます🧟‍♀️➡️🙂

---

## 3) 事故りがちな2パターン😱💥（よくある…！）

### パターンA：サーバ先行で“削除”しちゃう🪓💀

* 旧クライアントが送ってくるフィールドを、サーバが「もう要らないよね？」で削除
* 旧クライアントが期待してたレスポンスを、サーバが変更

結果：旧クライアントが **400/500** を踏む、または画面が壊れる📉😭

### パターンB：クライアント先行で“新しい値”を送り始める🚀💥

* 新クライアントが、新しい enum 値（例：`status: "archived"`）を送る
* 旧サーバーがその値を知らなくて落ちる

結果：新クライアントが **旧サーバーに当たった瞬間**に爆死💣😇

---

## 4) 最強の型🧠✨「Expand → Migrate → Contract（並行変更）」

破壊的変更（本来なら互換性が壊れる変更）を、安全にやる定番がこれ👇
**Parallel Change / Expand and Contract** と呼ばれる手法です🪜
「Expand（拡張）→ Migrate（移行）→ Contract（収縮）」の3フェーズで進めます。([martinfowler.com][1])

### フェーズ1：Expand（拡張）🌱✨

古い契約を壊さずに、新しい形を**追加**する

* フィールドを追加する（任意にする）
* 新しいエンドポイントを追加する
* 新旧どっちも受けられるようにする（後方互換）

### フェーズ2：Migrate（移行）🚌🔁

利用者（クライアント）を、段階的に新しい方へ寄せる

* 新クライアントを配布
* サーバ側でログ計測して「旧がどれだけ残ってるか」見る📊
* 必要なら両対応（dual-read / dual-write）する

### フェーズ3：Contract（収縮）✂️✅

「もう誰も使ってない」を確認してから、古いものを削除する

* 旧フィールド削除
* 旧API廃止
* 旧挙動を停止

ポイントはこれ👇
**“削除は最後”** 🧟‍♀️➡️🙂
（旧クライアントを殺すのは、最後の最後まで我慢！）

---

## 5) “壊さない”実装テク集🧰✨（すぐ効くやつ）

### ✅ テク1：追加は「任意（optional）」にする➕🧸

レスポンスに新フィールドを足すときは、旧クライアントが無視できる形にする👍

* **レスポンス**：フィールド追加は比較的安全（旧が無視できるなら）
* **リクエスト**：新フィールド追加も、サーバが無視できれば安全

### ✅ テク2：意味変更は“最も危険”⚠️🧠

同じフィールド名で意味を変える（例：`price` が税込→税抜）
これは見た目は互換っぽいけど、実質破壊です😇💥
やるなら **新フィールドを足す**（例：`priceWithTax`）が安全✨

### ✅ テク3：enum は「知らない値が来る前提」で作る🎲🛡️

旧クライアントが知らない値を受け取っても死なないようにするのが大事🙂

* UIは「不明なら一般表示」に逃がす
* ロジックは「未知は保守的」に扱う（安全側）

### ✅ テク4：削除したいものは“非推奨→観測→削除”📣👀🗑️

* 非推奨（deprecate）メッセージを出す
* 旧利用をログで観測する
* 0%になったら削除

---

## 6) 「デプロイ」と「リリース」を分ける🎛️✨（Feature Flag）

段階リリースの強い味方が **Feature Toggle / Feature Flag** です🚩
コードは本番に置いても、機能は“OFFのまま”にできるやつ🙂
これで **古いクライアントが混ざってても** 安全に切り替えできます。([martinfowler.com][2])

よくある使い方👇

* まず本番にデプロイ（でもOFF）📦
* 小さい割合だけON（1% → 5% → 25% → 100%）📈
* 何かあったらOFFに戻す（即時退避）🧯

---

## 7) 段階リリースの代表パターン3つ🪜🌈

### ① カナリア（Canary）🐤📈

少しだけ新バージョンに流して様子を見る方式
「一部にだけ出して安全確認できる」って公式ドキュメントでも説明されています。([Google Cloud Documentation][3])

### ② ブルーグリーン（Blue/Green）🟦🟩

本番環境を2つ用意して切り替える方式
切り戻しが速いのが魅力✨([Octopus Deploy][4])

### ③ 機能フラグ（Feature Flag）🚩🎛️

環境を増やさずに「機能の見せ方」を切り替える
コードを先に出して、あとでONできるのが強い💪([martinfowler.com][2])

---

## 8) TypeScriptで“旧を殺さない”具体例🧁🟦

ここでは「レスポンスに新フィールド `nickname` を追加する」例でいきます🙂✨
旧クライアントは `nickname` を知らない前提！

### 8-1) 型はこう作る（任意で足す）🧩➕

```ts
// v1: 旧クライアントが想定している形
export type UserV1 = {
  id: string;
  name: string;
};

// v2: 新しく追加したい（でも旧を殺したくない）
export type UserV2 = UserV1 & {
  nickname?: string; // ★ optional で追加！
};
```

**ポイント**：`nickname` を必須にしない🙂🧸
（旧クライアントは無視できるし、新クライアントはあれば使える✨）

---

### 8-2) “読む側”は寛容に（Tolerant Reader）📖🧠

受け取ったデータは「欠けてる可能性」を許す🌸
そして内部表現は「揃った形」に寄せる（デフォルト補完）✨

```ts
export type UserInternal = {
  id: string;
  name: string;
  nickname: string; // 内部では必ず文字列にしたい
};

export function normalizeUser(input: UserV2): UserInternal {
  return {
    id: input.id,
    name: input.name,
    nickname: input.nickname ?? "", // ★ デフォルト補完
  };
}
```

---

### 8-3) enum の“未知”に耐える💪🎲

例：`status` に新しい値が追加されるかも！

```ts
type Status = "active" | "suspended"; // 旧の想定

// 受け取りは string として扱い、未知は fallback へ
export function renderStatus(status: string): string {
  switch (status) {
    case "active":
      return "利用中🙂";
    case "suspended":
      return "停止中🧊";
    default:
      return "不明（でもOK）🤷‍♀️"; // ★ 死なない
  }
}
```

---

### 8-4) 実行時チェックも“境界”でやる🚧✅

TypeScriptの型だけだと、本番で壊れたデータが来たとき防げません😵‍💫
なので **境界（APIの入口）** で守るのが定番です🛡️✨

（ここは使うライブラリは何でもOK！方針が大事🙂）

```ts
// 例：ざっくりバリデーション（擬似コード）
export function assertUserLike(x: unknown): asserts x is { id: string; name: string; nickname?: string } {
  if (typeof x !== "object" || x === null) throw new Error("user must be object");
  const obj = x as any;
  if (typeof obj.id !== "string") throw new Error("id must be string");
  if (typeof obj.name !== "string") throw new Error("name must be string");
  if (obj.nickname !== undefined && typeof obj.nickname !== "string") throw new Error("nickname must be string");
}
```

---

## 9) ミニ演習：Day1〜Day7の“殺さない”リリース計画🗓️🧟‍♀️➡️🙂

### お題🎁

あなたのアプリは「サーバが `status` を返す」
新機能で `status: "archived"` を追加したい📦✨
でも古いクライアントは `"archived"` を知らない！😱

### Day1：Expand（サーバ側を先に強くする）🧱✨

* サーバは `status` に未知があっても安全な形で返す（必要なら別フィールド追加）
* 旧クライアントが壊れないレスポンスを保証する🙂

### Day2：Feature Flag で“まだ見せない”🚩🙈

* 本番にコードは入れる（ただしOFF）
* `"archived"` はまだ返さない（または返しても UI に出さない）

### Day3：新クライアントを配布📲📤

* 新クライアントは `"archived"` を表示できるようにする
* 旧サーバに当たっても落ちないようにしておく（新→旧も安全に）🙂

### Day4：小さくON（1%）🐤📈

* カナリア的に少数だけ `"archived"` を返す/表示する([Google Cloud Documentation][3])
* エラー率、問い合わせ、ログを観測👀📊

### Day5：段階的に広げる（5%→25%→100%）📈🚀

* 問題が出たら即OFF🧯
* “戻せる”ことが正義🙂✨

### Day6：旧利用の観測👀🧓

* 旧クライアント比率を計測
* `"archived"` を理解できないクライアントがどのくらい残ってるか見る

### Day7：Contract（削除はまだしない！条件付き）✂️✅

* 「旧がほぼ消えた」＋「非推奨期間を満たした」
  この条件が揃ったら、初めて古い分岐や旧仕様の撤去を計画する🗑️✨
  （Parallel Change の “Contract” は最後の最後！）([martinfowler.com][1])

---

## 10) リリース当日の“殺さない”チェックリスト✅🧟‍♀️➡️🙂

* [ ] **旧→新** が壊れない？（古いクライアントが新サーバに当たってもOK）
* [ ] **新→旧** が壊れない？（新クライアントが旧サーバに当たってもOK）
* [ ] 「削除」はやってない？（やるなら最後）✂️🚫
* [ ] enum の未知値で落ちない？🎲🛡️
* [ ] フラグで即OFFできる？🚩🧯
* [ ] 監視（エラー率・主要API・ログ）が見えてる？👀📈
* [ ] 戻し方（ロールバック or フラグOFF）が手順化されてる？🔙🧠

---

## 11) AI活用（この章で使うと強いプロンプト集）🤖💞

* 「この変更で **旧クライアントが壊れる可能性** を列挙して。優先度も付けて」🔍🧠
* 「Expand → Migrate → Contract で、今の変更を **3フェーズに分解** して」🪜✨([martinfowler.com][1])
* 「このレスポンス仕様、**未知の enum 値** が来ても落ちない実装にして」🎲🛡️
* 「Feature Flag を入れるなら、**切り替えポイント** をどこに置くのが安全？」🚩🤔([martinfowler.com][2])
* 「Day1〜Day7 の段階リリース計画をレビューして、危ない順に指摘して」🗓️✅

---

## 12) ちょい最新メモ🧠🆕（2026-02-04時点）

* TypeScript は npm 上で **5.9.3 が最新**として掲載されています。([npm][5])
* Node.js は **v24 が Active LTS**、v25 が Current として扱われています（本番はLTSが基本おすすめ）。([nodejs.org][6])

（※この章の考え方自体は、バージョンが進んでもずっと使える“型”だよ🙂✨）

[1]: https://martinfowler.com/bliki/ParallelChange.html?utm_source=chatgpt.com "Parallel Change"
[2]: https://martinfowler.com/articles/feature-toggles.html?utm_source=chatgpt.com "Feature Toggles (aka Feature Flags)"
[3]: https://docs.cloud.google.com/deploy/docs/deployment-strategies/canary?utm_source=chatgpt.com "Use a canary deployment strategy"
[4]: https://octopus.com/devops/software-deployments/blue-green-vs-canary-deployments/?utm_source=chatgpt.com "Blue/green Versus Canary Deployments: 6 Differences ..."
[5]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[6]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
