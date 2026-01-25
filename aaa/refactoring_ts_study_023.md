# 第23章 Guard Clauses（ネストを減らす）🚦✨

### ねらい🎯

* ネスト（入れ子）を減らして、**読める流れ（ハッピーパス）**にする🌷
* 「まずダメ条件を先に返す（早期リターン）」が自然にできるようになる🧠✨
* TypeScriptの**型の絞り込み（narrowing）**と相性が良い形に整える🧷✅

---

### 今日のキーワード🧩

* Guard Clause（ガード節）🛡️
  → 「ここから先は進めない条件」を先に処理して、すぐ終わらせる
* Early Return（早期リターン）↩️
  → ネストを増やさずに、分岐を上に集める
* Happy Path（ハッピーパス）🌈
  → “本筋の処理”がスッと読める状態

---

### なんでGuard Clausesが効くの？👀✨

ネストが深いと…

* 右に右にずれて、目が迷子になる😵‍💫
* 「結局この関数、何したいの？」が見えにくい🌫️
* 追加仕様で if が増えるほど、壊れやすい💥

Guard Clausesにすると…

* **ダメ条件だけ上で片付く**ので、下がスッキリ🌸
* **主役の処理（ハッピーパス）**が一直線に読める🚶‍♀️✨
* TypeScriptが「ここから下は null じゃない」みたいに理解しやすい🧷✅

---

## コード例（ビフォー/アフター）🧩➡️✨

### 例題：購入処理の入り口（入力が微妙に怪しいやつ）🛒🧾

#### ビフォー：ネストが増えて読みにくい😵‍💫

```ts
type User = { id: string; isBanned: boolean };
type Item = { price: number; qty: number };
type Coupon = { code: string; discountRate: number }; // 0〜1

type CheckoutOk = { ok: true; total: number };
type CheckoutNg = { ok: false; reason: "NO_USER" | "BANNED" | "EMPTY_CART" | "BAD_COUPON" };
type CheckoutResult = CheckoutOk | CheckoutNg;

export function checkout(user: User | null, items: Item[], coupon: Coupon | null): CheckoutResult {
  if (user !== null) {
    if (!user.isBanned) {
      if (items.length > 0) {
        let total = 0;
        for (const item of items) {
          total += item.price * item.qty;
        }

        if (coupon !== null) {
          if (coupon.discountRate > 0 && coupon.discountRate < 1) {
            total = Math.floor(total * (1 - coupon.discountRate));
            return { ok: true, total };
          } else {
            return { ok: false, reason: "BAD_COUPON" };
          }
        } else {
          return { ok: true, total };
        }
      } else {
        return { ok: false, reason: "EMPTY_CART" };
      }
    } else {
      return { ok: false, reason: "BANNED" };
    }
  } else {
    return { ok: false, reason: "NO_USER" };
  }
}
```

💦 ぱっと見で「成功する流れ」がどこにあるか見えづらい…
しかも「else の波🌊」で読むのが疲れる…😮‍💨

---

#### アフター：ガード節で“ダメ条件”を先に終わらせる🚦✨

```ts
type User = { id: string; isBanned: boolean };
type Item = { price: number; qty: number };
type Coupon = { code: string; discountRate: number };

type CheckoutOk = { ok: true; total: number };
type CheckoutNg = { ok: false; reason: "NO_USER" | "BANNED" | "EMPTY_CART" | "BAD_COUPON" };
type CheckoutResult = CheckoutOk | CheckoutNg;

function calcSubtotal(items: Item[]): number {
  let total = 0;
  for (const item of items) total += item.price * item.qty;
  return total;
}

function isValidDiscountRate(rate: number): boolean {
  return rate > 0 && rate < 1;
}

export function checkout(user: User | null, items: Item[], coupon: Coupon | null): CheckoutResult {
  // ✅ ガード節：先に「続行できない条件」を片付ける
  if (user === null) return { ok: false, reason: "NO_USER" };
  if (user.isBanned) return { ok: false, reason: "BANNED" };
  if (items.length === 0) return { ok: false, reason: "EMPTY_CART" };

  // 🌈 ここから下は“成功する道”がスッと読める
  let total = calcSubtotal(items);

  if (coupon !== null) {
    if (!isValidDiscountRate(coupon.discountRate)) return { ok: false, reason: "BAD_COUPON" };
    total = Math.floor(total * (1 - coupon.discountRate));
  }

  return { ok: true, total };
}
```

ポイント💡

* 上の3行で「続けられない条件」を全部処理🧹✨
* その下は、**ハッピーパスが一直線**🌈
* coupon の分岐も「不正なら即return」でスッキリ🚦

---

## 手順（小さく刻む）👣🛟

### 0) まず守りを置く（最低1本テスト）🧪🥚

```ts
import { describe, it, expect } from "vitest";
import { checkout } from "./checkout";

describe("checkout", () => {
  it("userがnullならNO_USER", () => {
    expect(checkout(null, [{ price: 100, qty: 1 }], null)).toEqual({ ok: false, reason: "NO_USER" });
  });

  it("カート空ならEMPTY_CART", () => {
    expect(checkout({ id: "u1", isBanned: false }, [], null)).toEqual({ ok: false, reason: "EMPTY_CART" });
  });

  it("クーポンが不正ならBAD_COUPON", () => {
    expect(
      checkout({ id: "u1", isBanned: false }, [{ price: 100, qty: 1 }], { code: "X", discountRate: 2 })
    ).toEqual({ ok: false, reason: "BAD_COUPON" });
  });

  it("正常なら合計を返す", () => {
    expect(
      checkout({ id: "u1", isBanned: false }, [{ price: 100, qty: 2 }], { code: "OFF", discountRate: 0.1 })
    ).toEqual({ ok: true, total: 180 });
  });
});
```

※ Vitestは移行時にカバレッジ周りなど変更点が入ることがあるので、アップデート時はMigration Guideも一度だけ目を通すと安心だよ🧯📘 ([Vitest][1])

---

### 1) “続行できない条件”を箇条書きにする📝

例：

* user がいない → もう無理（NO_USER）🙅‍♀️
* user がBAN → もう無理（BANNED）🚫
* items が空 → もう無理（EMPTY_CART）🛒❌
* coupon が不正 → もう無理（BAD_COUPON）🎟️💥

この「無理リスト」を上に集めるのがGuard Clauses🛡️✨

---

### 2) 1個ずつ上に移して、毎回テスト🧪✅

コツ：

* いきなり全部やらない🙅‍♀️
* 1条件ずつ「上へ」→テスト→次へ👣

---

### 3) “成功の流れ”が見えたら、最後に整える🎀

* 小さな関数に分ける（calcSubtotal みたいに）✂️📦
* 条件の意味に名前をつける（isValidDiscountRate みたいに）🏷️✨

---

## もう1本：ループのガード節（continue）🌀🚦

「配列を処理する系」は return じゃなくて continue が気持ちいいことが多いよ🍃

#### ビフォー：ネストが増えがち😵‍💫

```ts
type User = { id: string; email?: string };

export function collectEmails(users: User[]): string[] {
  const emails: string[] = [];

  for (const u of users) {
    if (u.email !== undefined) {
      if (u.email.includes("@")) {
        emails.push(u.email);
      }
    }
  }

  return emails;
}
```

#### アフター：ガードしてスッキリ✨

```ts
type User = { id: string; email?: string };

export function collectEmails(users: User[]): string[] {
  const emails: string[] = [];

  for (const u of users) {
    if (u.email === undefined) continue;
    if (!u.email.includes("@")) continue;

    emails.push(u.email);
  }

  return emails;
}
```

---

## Guard Clausesのコツ集🧠✨

### ✅ ガード節に向いてる条件

* 入力が足りない（null/undefined/空）🫧
* 権限がない、状態がダメ（BAN、期限切れ、在庫なし）🚫
* 例外的なケース（超レア）🦄

### ✅ 書き方の気持ちいい順番

* いちばん安い判定（軽い）から上へ💨
* “よく起きるエラー”を上へ（読みやすい）👀
* 1行で終わるガードが最高✨

### ⚠️ 注意（ありがち落とし穴）

* 後片付けが必要な処理（ファイル、ロック等）がある場合は finally を使う🧯
* return が多すぎて混乱するなら「ガード＝上の数行だけ」に限定する🏷️

---

## Lintで「else地獄」を予防する👮‍♀️✅

* ESLintは v9 で新しい設定方式（flat config）がデフォルトになっていて、これが今の標準だよ📌 ([ESLint][2])
* さらに v10 はリリースが近く、RC（リリース候補）も出てるので、設定ファイルの形は flat config に寄せておくと安心感があるよ✨ ([ESLint][3])

例：if の書き方を整えるルールを入れる（no-else-return など）🧹

```js
import js from "@eslint/js";

export default [
  js.configs.recommended,
  {
    rules: {
      "no-else-return": "error"
    }
  }
];
```

---

## ミニ課題✍️🌸

### 課題1：ネスト3段を1段にしてみよう🚦✨

次の関数をGuard Clausesにして、**同じ結果**になるようにしてね🧩
（ヒント：ダメ条件を上に集めるだけ！）

```ts
type LoginOk = { ok: true; userId: string };
type LoginNg = { ok: false; reason: "EMPTY" | "NOT_FOUND" | "LOCKED" };
type LoginResult = LoginOk | LoginNg;

type User = { id: string; locked: boolean };

export function login(username: string, user: User | null): LoginResult {
  if (username.length > 0) {
    if (user !== null) {
      if (!user.locked) {
        return { ok: true, userId: user.id };
      } else {
        return { ok: false, reason: "LOCKED" };
      }
    } else {
      return { ok: false, reason: "NOT_FOUND" };
    }
  } else {
    return { ok: false, reason: "EMPTY" };
  }
}
```

✅ ゴール

* else をほぼ消す🌪️➡️🍃
* ハッピーパスが一直線になる🌈
* 返す reason は一切変えない🎯

---

### 課題2：ループをcontinueで平坦に🌀🍃

「条件がダメなら次！」を2つ作って、ネストを消してみよう🚦✨

---

## AI活用ポイント🤖💡（お願い方＋チェック観点✅）

### お願い方（コピペOK）📝

```text
次のTypeScript関数を Guard Clauses（早期return/continue）に書き換えてください。
条件：
- 動作（返す値、エラー理由、例外）は一切変えない
- ネストを減らし、ハッピーパスが下に一直線で読める形にする
- 変更ステップを「小さく刻んだ順番」で提案する（1ステップごとに何を確認するかも）
コード：
（ここに対象コード）
```

### チェック観点✅（AIの提案を採用する前に）

* 返す reason や文字列が変わってない？🔎
* 境界条件（空、null、0件）がちゃんと同じ？🧪
* ガード節を入れたことで「後処理漏れ」起きてない？🧯
* “成功ルート”が最後にスッと読める？🌈

---

## まとめ📌✨

* Guard Clausesは「ダメ条件を上で終わらせる」だけで、ネストが減って読みやすくなる🚦✨
* “成功の流れ（ハッピーパス）”をまっすぐ見せると、変更にも強くなる🌷
* TypeScriptはガード後に型が絞れて、安全に書きやすくなる🧷✅
* 仕上げに小さな関数化＆意味に名前をつけると、さらに読みやすい🏷️💖

（参考：TypeScriptは現在 npm の最新安定版が 5.9.3 と案内されているよ📦✨ ([npmjs.com][4])）

[1]: https://vitest.dev/guide/migration.html?utm_source=chatgpt.com "Migration Guide"
[2]: https://eslint.org/blog/2025/03/flat-config-extends-define-config-global-ignores/?utm_source=chatgpt.com "Evolving flat config with extends"
[3]: https://eslint.org/?utm_source=chatgpt.com "Find and fix problems in your JavaScript code - ESLint ..."
[4]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
