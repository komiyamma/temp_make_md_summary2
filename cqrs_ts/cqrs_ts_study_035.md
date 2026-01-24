# 第35章　フロント視点（Command後にどう画面更新する？）🖥️🔄✨

この章はね、**「更新（Command）したのに、画面が古いまま…😢」**を卒業する回だよ〜！🎓💕

CQRSだと、だいたいこんな流れになるよね👇

* ① フロントが **POST（Command）** を送る 📮
* ② サーバーが「OK！受け取ったよ！」って返す ✅
* ③ でも **Readモデル（GETの結果）** が更新されるのは、ちょい後かも…⏳（非同期投影だと特に！）

だからフロントは、**Command成功後の画面更新**を “意識して設計” する必要があるの〜🥺✨
（ここをちゃんとやると、UXが一気にプロっぽくなる💎）

---

## 35.1 まず結論：画面更新の3択🎯✨

第35章のテーマはこれ👇

1. **再取得（Re-fetch）** 🔄
2. **楽観更新（Optimistic Update）** 🚀
3. **通知（Notification / Subscription）** 🔔

それぞれの「向いてる場面」が違うから、**迷ったら判断軸**を持とうね😊🧭

---

## 35.2 “3択”のキャラ紹介😆✨

### ① 再取得（Re-fetch）🔄✨

**やり方：** Command成功したら、GET（Query）をもう一回取りにいく！

* いいところ😊

  * 実装がいちばん簡単✨
  * サーバーの正が取れる（ミスしにくい）✅
* つらいところ🥺

  * Readモデルの反映が遅いと、取り直しても古い可能性がある⏳
  * 通信が増える📡

フロントのデータ取得に **TanStack Query** を使うなら「invalidate」が王道だよ〜！🪄
（Queryを“古い”扱いにして再取得させるやつ）([TanStack][1])

---

### ② 楽観更新（Optimistic Update）🚀💖

**やり方：** サーバーの返事を待たずに、画面を先に更新しちゃう！

* いいところ😍

  * 体感がめちゃ速い⚡（ユーザー幸せ）
  * ボタン押した瞬間に反応できる✨
* つらいところ😵‍💫

  * 失敗したら巻き戻し（rollback）が必要🙃
  * 非同期投影だと「画面は更新されたけど、GETはまだ古い」ズレが起きることも👀

TanStack Query v5 には **楽観更新のガイド**がちゃんとあるよ〜！心強い💪✨ ([TanStack][2])

---

### ③ 通知（Notification / Subscription）🔔📨

**やり方：** サーバーから「Readモデル更新できたよ！」って教えてもらう

* いいところ🥹✨

  * 非同期投影でも「反映完了」が分かる！最高！
  * 「いつ再取得すべきか」が明確🎯
* つらいところ😅

  * ちょい実装が増える（WebSocket / SSE / Push / ポーリングなど）
  * 運用の設計も必要（切断・再接続とか）🔌

---

## 35.3 判断のコツ：どれを選ぶ？🧭✨

### 迷ったらこの3質問だけでOK🙆‍♀️💡

1. **“今すぐ反映”が必要？**

   * 必要 → 楽観更新🚀 or 通知🔔
   * まあ後でOK → 再取得🔄

2. **失敗が多そう？（在庫切れ・決済失敗など）**

   * 多い → 再取得🔄（安全） or 楽観更新でもrollback丁寧に

3. **Readモデルが遅れる設計？（非同期投影）**

   * 遅れる → 通知🔔が強い
   * 同期投影寄り → 再取得🔄でも快適

---

## 35.4 ハンズオン：学食アプリで3択ぜんぶ体験🍙📱✨

ここからは **「注文する（PlaceOrder）」** を例にするね！
（Queryは “注文一覧” を GET で取って表示してる想定📋）

以降の例は **React + TypeScript + TanStack Query v5** で書くよ〜🧡
※Reactは19系が安定版になってるよ ([react.dev][3])
（Next.jsを使うなら、15でReact 19系の流れもあるよ ([nextjs.org][4])）

---

### 準備：API呼び出し（超シンプル版）📮

```ts
export type OrderListItem = {
  id: string
  status: "ORDERED" | "PAID"
  total: number
  createdAt: string
}

export type PlaceOrderInput = {
  menuId: string
  qty: number
}

export async function fetchOrderList(): Promise<OrderListItem[]> {
  const res = await fetch("/api/orders", { method: "GET" })
  if (!res.ok) throw new Error("failed to fetch order list")
  return res.json()
}

export async function placeOrder(input: PlaceOrderInput): Promise<{ orderId: string }> {
  const res = await fetch("/api/orders", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  })
  if (!res.ok) throw new Error("failed to place order")
  return res.json()
}
```

---

## 35.5 パターン①：再取得（invalidate）で更新する🔄✨

「Command成功したら、一覧を取り直す！」の最短ルートだよ😊

```ts
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { fetchOrderList, placeOrder, PlaceOrderInput } from "./api"

export function useOrderList() {
  return useQuery({
    queryKey: ["orderList"],
    queryFn: fetchOrderList,
  })
}

export function usePlaceOrder_refetch() {
  const qc = useQueryClient()

  return useMutation({
    mutationFn: (input: PlaceOrderInput) => placeOrder(input),
    onSuccess: async () => {
      // 「この一覧は古くなったよ」→ 再取得へ
      await qc.invalidateQueries({ queryKey: ["orderList"] })
    },
  })
}
```

TanStack Queryの invalidate はこの用途ど真ん中だよ〜🪄 ([TanStack][1])

### UXの小ワザ🍀

* 送信中はボタンをdisabledにする🙅‍♀️
* 「注文を送信中…」トースト出す🍞✨
* 再取得中はスケルトン表示🦴

---

## 35.6 パターン②：楽観更新（Optimistic）🚀✨

「押した瞬間に一覧に出したい！」ってときのやつ💖
TanStack Queryの公式ガイドだと “onMutateでキャッシュを先に更新→失敗なら戻す” が王道だよ ([TanStack][2])

```ts
import { useMutation, useQueryClient } from "@tanstack/react-query"
import { placeOrder, PlaceOrderInput, OrderListItem } from "./api"

export function usePlaceOrder_optimistic() {
  const qc = useQueryClient()

  return useMutation({
    mutationFn: (input: PlaceOrderInput) => placeOrder(input),

    onMutate: async (input) => {
      // 1) 競合を避けるため、関連Queryの通信を止める
      await qc.cancelQueries({ queryKey: ["orderList"] })

      // 2) いまの一覧を退避（失敗したら戻す用）
      const prev = qc.getQueryData<OrderListItem[]>(["orderList"]) ?? []

      // 3) 先に画面へ反映（仮の注文を追加）
      const optimistic: OrderListItem = {
        id: "temp-" + crypto.randomUUID(),
        status: "ORDERED",
        total: 999, // ここは本当は入力から計算 or UI用の仮表示でもOK
        createdAt: new Date().toISOString(),
      }
      qc.setQueryData<OrderListItem[]>(["orderList"], [optimistic, ...prev])

      // 4) rollback用に返す
      return { prev }
    },

    onError: (_err, _input, ctx) => {
      // 失敗したら戻す😢
      qc.setQueryData(["orderList"], ctx?.prev ?? [])
    },

    onSettled: async () => {
      // 最後はサーバーの正で整える✨（超大事）
      await qc.invalidateQueries({ queryKey: ["orderList"] })
    },
  })
}
```

### CQRSあるある注意⚠️👀

非同期投影だと、`onSettled` で再取得しても **Read側がまだ古い**ことがあるの🥺
そのときは次のどれかを足すと安定するよ👇

* ✅ ちょい待ってリトライ（短いポーリング）🔄
* ✅ 「反映待ち」バッジを出す⌛
* ✅ ③の通知を使って「反映完了」を待つ🔔

---

## 35.7 パターン③：通知（SSEで“反映完了”を受け取る）🔔✨

ここではフロントだけ書くね！（サーバーはSSEでイベントを流してくる想定📡）

### 例：SSEを購読して、来たら一覧を再取得する📨

```ts
import { useEffect } from "react"
import { useQueryClient } from "@tanstack/react-query"

export function useReadModelNotifications() {
  const qc = useQueryClient()

  useEffect(() => {
    const es = new EventSource("/api/events") // SSEエンドポイント

    es.addEventListener("orderProjected", async () => {
      // Readモデル更新できたよ！→ じゃあ取り直そ🔄
      await qc.invalidateQueries({ queryKey: ["orderList"] })
      await qc.invalidateQueries({ queryKey: ["salesSummary"] })
    })

    es.onerror = () => {
      // 実務だと再接続やバックオフを入れると安心😌
    }

    return () => es.close()
  }, [qc])
}
```

### これが強い場面💪✨

* 「支払い完了したのに一覧のステータスが変わらない😢」みたいな不満を潰せる
* 「集計（売上サマリ）」みたいに、投影が遅れがちな画面にも効く📊

---

## 35.8 学食アプリだと、どれが合う？🍙🎯

おすすめの“混ぜ技”いくよ〜😆✨

### 注文ボタン（PlaceOrder）🧾

* **基本：楽観更新🚀 + 最後に再取得🔄**
* さらに非同期投影なら「反映待ち⌛」も出すと優しい💕

### 支払い（PayOrder）💳

* 「押した瞬間にPaidが見たい！」が強いので
  **楽観更新🚀（失敗rollback丁寧に）** が気持ちいい✨

### 売上サマリ（集計）📊

* ユーザーが連打する画面じゃないことが多いので
  **通知🔔 or 再取得🔄** が安定！

---

## 35.9 ミニ演習（3分でできる）📝✨

次の画面、それぞれ **どの方式にする？（理由も1行）** で選んでみて〜🎯💕

1. 注文一覧（最新が見たい）📋
2. 支払いボタン（失敗あり得る）💳
3. 売上サマリ（重い集計）📊
4. 管理者の注文監視画面（リアルタイムっぽく見せたい）👀

---

## 35.10 AI活用プロンプト例🤖💬（コピペOK）

### ① 判断相談🧭

「この画面は再取得/楽観更新/通知のどれが良い？UX・実装コスト・失敗時対応まで含めて提案して」

### ② rollback設計🛡️

「楽観更新のrollbackで、どのデータをcontextに保存すべき？“最小”で壊れにくい案を出して」

### ③ “反映待ち”UX作り⌛

「CQRSの非同期投影で、Readが遅れる前提。ユーザーが不安にならない文言とUI案（トースト/バッジ/再試行）を提案して」

---

## まとめ🎉✨

* **再取得🔄**：いちばん簡単・安全（でも投影遅延に弱い）
* **楽観更新🚀**：体感最強（rollback必須、最後は再取得で整える）([TanStack][2])
* **通知🔔**：非同期投影の「反映完了」を扱える（実装は少し増える）

---

次の章（第36章）は、ここで出てきた「通知」「再取得」「投影ズレ」を **困らないように観測＆復旧**していく回だよ〜🧭🧰✨

[1]: https://tanstack.com/query/v5/docs/react/guides/query-invalidation?utm_source=chatgpt.com "Query Invalidation | TanStack Query React Docs"
[2]: https://tanstack.com/query/v5/docs/react/guides/optimistic-updates?utm_source=chatgpt.com "Optimistic Updates | TanStack Query React Docs"
[3]: https://react.dev/blog/2024/12/05/react-19?utm_source=chatgpt.com "React v19"
[4]: https://nextjs.org/blog/next-15?utm_source=chatgpt.com "Next.js 15"
