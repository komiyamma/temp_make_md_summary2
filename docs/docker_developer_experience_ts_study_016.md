# 第16章：モックとスタブを怖がらない🧸🧪✨

この章のゴールはシンプル！👇
**「外部依存（時間・乱数・HTTP・DB）を、テストで“自分の都合のいい状態”にできる」**ようになることです😎💪
そして同時に、初心者がやりがちな **“やりすぎモック地獄”** を回避します😇🕳️

---

## 1) まず用語を“ざっくり”整理しよう🧠✨

厳密さより「使いどころ」が大事！💡

* **スタブ（stub）**：戻り値を固定する係

  * 例）`Math.random()` を 항상 `0.1` にする🎲➡️0.1
* **スパイ（spy）**：本物を覗き見して、呼ばれ方を記録する係👀

  * 例）`fetch()` が何回呼ばれたか見る📞
* **モック（mock）**：スタブ＋「こう呼ばれるべき」まで面倒を見る係🎭

  * 例）「`fetch('/users')` が1回呼ばれるべき」まで検証する
* **フェイク（fake）**：簡易な代用品（実装は動くけど本物じゃない）🧩

  * 例）DBの代わりにメモリ配列で動く“偽リポジトリ”📦

Vitestでは基本 `vi` ヘルパーで揃います。`vi.fn` / `vi.spyOn` / `vi.mock` などが中心です。([Vitest][1])

---

## 2) どこをモックすべき？判断のコツ🧭😺

テストが不安定になる原因は、だいたいこの4つ👇

1. **時間**（`Date.now`, `new Date`, `setTimeout`）⏰
2. **乱数**（`Math.random`）🎲
3. **通信**（`fetch`, HTTPクライアント）🌐
4. **DB/外部サービス**（本物は遅い・壊れやすい）🧱

✅ 結論：**“外の世界”は切り離す**
❌ 逆に：**自分の関数の中身までモックし始める**と、テストが「仕様」じゃなく「実装」に縛られて死にます🪦😇

---

## 3) ハンズオン：最小コードで「怖くない」を体感🧪🧸

## 3-1) スタブ：乱数を固定してテストを安定化🎲➡️📌

例：`Math.random()` によって結果が変わる関数をテストしたい

## 実装例（src/lucky.ts）

```ts
export function isLucky(): boolean {
  return Math.random() < 0.2
}
```

## テスト例（src/lucky.test.ts）

```ts
import { describe, it, expect, vi } from 'vitest'
import { isLucky } from './lucky'

describe('isLucky', () => {
  it('乱数を固定して true を検証する', () => {
    vi.spyOn(Math, 'random').mockReturnValue(0.1) // 0.1 < 0.2 なので true
    expect(isLucky()).toBe(true)
  })

  it('乱数を固定して false を検証する', () => {
    vi.spyOn(Math, 'random').mockReturnValue(0.9) // 0.9 < 0.2 ではない
    expect(isLucky()).toBe(false)
  })
})
```

ポイント😊✨

* `vi.spyOn(対象, 'メソッド')` は「本物を監視しつつ差し替え」できる万能選手💪
* これだけでテストが「運ゲー」から卒業します🎓🎲🚫

---

## 3-2) フェイクタイマー：時間に依存する処理を爆速テスト⏰⚡

例：`setTimeout` があるとテストが遅い＆不安定になりがち😵‍💫
Vitestは **fake timers** で時間を進められます。([Vitest][2])

## 実装例（src/after.ts）

```ts
export function executeAfter(ms: number, fn: () => void) {
  setTimeout(fn, ms)
}
```

## テスト例（src/after.test.ts）

```ts
import { describe, it, expect, vi } from 'vitest'
import { executeAfter } from './after'

describe('executeAfter', () => {
  it('時間を進めてコールされることを確認', () => {
    vi.useFakeTimers()

    const fn = vi.fn()
    executeAfter(1000, fn)

    expect(fn).not.toHaveBeenCalled()

    vi.advanceTimersByTime(1000) // 1秒進める
    expect(fn).toHaveBeenCalledTimes(1)

    vi.useRealTimers()
  })
})
```

🔥 よくある注意

* `vi.useFakeTimers()` したまま放置すると **他のテストが変になります**😇
  → `afterEach` で戻すクセをつけると安全🧯

---

## 3-3) 日時固定：`new Date()` が絡む処理を安定化📅🧊

「今日が何日か」で結果が変わる処理、テストで事故りがち！💥
Vitestは **日時も固定**できます（fake timers の仕組みで制御）。([Vitest][3])

## テスト例（ざっくり）

```ts
import { describe, it, expect, vi } from 'vitest'

function greeting() {
  const hour = new Date().getHours()
  return hour < 12 ? 'おはよう' : 'こんにちは'
}

describe('greeting', () => {
  it('朝なら「おはよう」', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-02-10T09:00:00.000Z'))

    expect(greeting()).toBe('おはよう')

    vi.useRealTimers()
  })
})
```

---

## 3-4) グローバルのスタブ：`fetch` を丸ごと差し替える🌐🧪

HTTPは本物を叩くと遅い・壊れやすい・通信失敗する…で地獄👹
Vitestは `vi.stubGlobal` で `fetch` 自体を差し替えできます。([Vitest][4])

## 例：`fetch` をスタブして JSON を返す

```ts
import { describe, it, expect, vi, afterEach } from 'vitest'

async function loadUserName() {
  const res = await fetch('https://example.com/users/1')
  const data = await res.json()
  return data.name
}

describe('loadUserName', () => {
  afterEach(() => {
    vi.unstubAllGlobals() // これ超大事！🔥
  })

  it('fetchを差し替えて安定テスト', async () => {
    vi.stubGlobal('fetch', vi.fn(() =>
      Promise.resolve({
        json: () => Promise.resolve({ name: 'Taro' }),
      } as any)
    ))

    await expect(loadUserName()).resolves.toBe('Taro')
    expect(fetch).toHaveBeenCalledTimes(1)
  })
})
```

ポイント😊

* `vi.stubGlobal` は **デフォで自動リセットされない**ので、`vi.unstubAllGlobals()` が安全策です🧯([Vitest][4])

---

## 4) モジュールモック：外部モジュール丸ごと差し替える📦🎭

「APIクライアント」「DBアクセス層」みたいな *別ファイル* を切り離す時に使います。
Vitestのモックは `vi.mock()` が基本。([Vitest][1])

## 例：`userApi.ts` を `service.ts` から呼んでる想定

```ts
// userApi.ts
export async function fetchUser() {
  return { id: 1, name: 'Real' }
}

// service.ts
import { fetchUser } from './userApi'
export async function getUserName() {
  const u = await fetchUser()
  return u.name
}
```

テストで `userApi` を差し替え👇

```ts
import { describe, it, expect, vi } from 'vitest'
import { getUserName } from './service'

vi.mock('./userApi', () => {
  return {
    fetchUser: vi.fn(async () => ({ id: 1, name: 'Mocked' })),
  }
})

describe('getUserName', () => {
  it('モジュールを差し替えて検証', async () => {
    await expect(getUserName()).resolves.toBe('Mocked')
  })
})
```

⚠️ 罠：`vi.mock()` はファイル上部に巻き上げ（hoist）される性質があるので、**配置で挙動が変わり得ます**。([Vitest][1])

---

## 5) 初心者がやりがちな「やりすぎモック」回避術🛑😅

## ✅ “ちょうどいい”目安

* **外部境界だけ**モック（時間・乱数・通信・DB）🧱
* 自分のロジックは **なるべく本物で**テスト🧠✨

## ❌ ありがちな地雷

* 実装の細部（内部関数呼び出し順）まで `toHaveBeenCalledWith` で縛る
  → リファクタでテストが死ぬ💀
* 1テストでモックが多すぎる
  → 何がしたいテストか分からない迷子テスト🐣🧭
* fake timers を戻し忘れて他テストが崩壊😇⏰

---

## 6) ミニ課題🎒✨（手を動かすと一気に定着するよ！）

1. 🎲 `Math.random()` を固定して「当たり/はずれ」の2ケースを書く
2. ⏰ `setTimeout` を fake timers で即時完了させるテストを書く
3. 🌐 `fetch` を `vi.stubGlobal` で差し替えて、JSONを返すテストを書く（最後に `vi.unstubAllGlobals()`）

---

## 7) AI拡張で時短するコツ🤖✨（でも事故らない！）

AIに投げるときは **“仕様”を渡す**のがコツです😊
おすすめプロンプト例👇

* 🧪「この関数のテストケースを、外部依存（Date/Random/fetch）を固定する前提で3つ提案して」
* 🎭「Vitestで `vi.spyOn` と `vi.stubGlobal` を使い分ける例を、このコードに合わせて書いて」
* 🧯「このテストが不安定になる可能性を指摘して。fake timers や unstub 忘れもチェックして」

仕上げにあなたがやることはこれだけ👇

* 期待値が“仕様”になってる？（実装に寄ってない？）🧠
* モックの後始末できてる？（`useRealTimers` / `unstubAllGlobals`）🧹
* テスト名が「何を守るか」を説明してる？📛

---

## まとめ🎉

モック/スタブは「ズル」じゃなくて、**テストを安定させるための道具**です🧰✨
でもやりすぎると逆に不安定になるので、まずはこの合言葉でいきましょ👇

**「外の世界だけ固定して、ロジックは本物で！」**🌍🔒🧠✅

[1]: https://vitest.dev/guide/mocking?utm_source=chatgpt.com "Mocking | Guide"
[2]: https://vitest.dev/guide/mocking/timers?utm_source=chatgpt.com "Timers"
[3]: https://vitest.dev/guide/mocking/dates?utm_source=chatgpt.com "Mocking Dates"
[4]: https://vitest.dev/guide/mocking/globals?utm_source=chatgpt.com "Mocking Globals"
