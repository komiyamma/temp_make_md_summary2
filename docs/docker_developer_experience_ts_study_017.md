# 第17章：テストデータ設計：fixture/seedの基本🌱🧪

この章のゴールはシンプルだよ👇✨
**「毎回同じ結果が出る（＝テストが安定する）」データの作り方**を身につけること！🙂

---

## 1) まず言葉を整理しよ〜📚✨（ここが分かると一気にラク！）

* **fixture（フィクスチャ）**：テストで使う「固定のデータ」🧱
  例）`userAlice` は必ず同じメールアドレスを持つ、みたいなやつ。

* **seed（シード）**：DBなどに「最初に流し込むデータ」🌱
  例）テスト用DBにユーザー3人＋投稿10件を投入する、みたいなやつ。

* **factory（ファクトリ）**：必要に応じてデータを「生成する関数」🏭
  例）`createUser({ role: 'admin' })` で管理者ユーザーを作る、など。

この3つは役割が違うから、ちゃんと分けると設計がキレイになるよ😊✨

---

## 2) テストデータの“正義”はこれ🥇（迷ったらコレに戻る）

**ルールは3つだけ**👇😺

1. **テストは独立**：他のテストのデータに依存しない🧍‍♂️🧍‍♀️
2. **再現性**：毎回同じ結果が出る（乱数・時間・順序が揺れない）🔁
3. **読みやすさ**：テストを読んだ瞬間、状況が分かる👀✨

この3つを守ると「落ちる時だけ落ちる😇（フレーク）」が激減する！

---

## 3) まずは“fixture”から始めるのが勝ち🏁🧱

ユニットテスト（小さいテスト）では、まず固定データが最強だよ💪🙂

**おすすめ：`tests/fixtures/` に置く**📁

```ts
// tests/fixtures/users.ts
export const userAlice = {
  id: "u_alice",
  name: "Alice",
  email: "[email protected]",
  role: "user" as const,
};

export const userBob = {
  id: "u_bob",
  name: "Bob",
  email: "[email protected]",
  role: "admin" as const,
};
```

✅ これの良いところ

* 1回読んだら分かる👀✨
* データがブレない🔒
* デバッグがラク😺

---

## 4) 次に“factory”で「必要最小限だけ上書き」する🏭🧩

fixtureを増やしすぎると「同じようなデータだらけ」になりがち😅
そこで **factory** を使うとちょうどいい！

```ts
// tests/factories/userFactory.ts
import { faker } from "@faker-js/faker";

export type User = {
  id: string;
  name: string;
  email: string;
  role: "user" | "admin";
};

export function createUser(partial: Partial<User> = {}): User {
  return {
    id: partial.id ?? `u_${faker.string.nanoid()}`,
    name: partial.name ?? faker.person.fullName(),
    email: partial.email ?? faker.internet.email(),
    role: partial.role ?? "user",
  };
}
```

ここで超重要ポイント⚠️🧨
**fakerは“seed（固定）”しないと毎回値が変わってテストが揺れる**可能性があるよ！

`@faker-js/faker` は **seedで再現性を作れる**よ🌱🔁 ([npm][1])
ただし、**同じseedでもライブラリ更新で出力が変わることがある**ので、テストで使うならバージョン固定（ロック）も意識すると安全！🧷 ([GitHub][2])

**テスト側でseed固定する例**👇

```ts
// tests/userService.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import { faker } from "@faker-js/faker";
import { createUser } from "./factories/userFactory";

describe("user service", () => {
  beforeEach(() => {
    faker.seed(123); // ✅ 毎回同じ乱数列にする
  });

  it("adminは管理画面に入れる", () => {
    const admin = createUser({ role: "admin" });
    expect(admin.role).toBe("admin");
  });
});
```

---

## 5) Vitestの“fixture機能”で、テストがスッキリする🧼✨

ここからが気持ちいいやつ😆
**Vitestにはfixtureっぽい仕組み（Test Context / test.extend）がある**よ！
Playwrightのfixturesに影響を受けた設計で、テストに「道具」を注入できる感じ🧰✨ ([Vitest][3])

例：毎回 “seed済みfaker” と “よく使うユーザー” を渡す👇

```ts
// tests/testBase.ts
import { test as base } from "vitest";
import { faker } from "@faker-js/faker";
import { createUser, User } from "./factories/userFactory";

type Fixtures = {
  user: User;
};

export const test = base.extend<Fixtures>({
  user: async ({}, use) => {
    faker.seed(123);
    const user = createUser({ role: "user", email: "[email protected]" });
    await use(user);
  },
});
```

使う側👇

```ts
// tests/sample.test.ts
import { expect } from "vitest";
import { test } from "./testBase";

test("userのemailが入ってる", ({ user }) => {
  expect(user.email).toContain("@");
});
```

---

## 6) “seed（DBに流すやつ）”の基本方針🌱🧱

DBありテスト（統合テスト）は次章でガッツリやるけど、ここで“設計ルール”だけ作っておくね🙂

* **seedは「テスト専用DB」にだけ使う**（本番DBには混ぜない）🚫
* **seedは「最小セット」**：入れすぎると遅くなる🐢
* **IDは固定しがち**：`u_alice` みたいにするとテストが読みやすい👀✨
* **毎回リセットが基本**：テストは“同じ初期状態”から始める🔁

もしORMで Prisma を使うなら、公式に **seedingのワークフロー**が用意されてるよ🌱 ([Prisma][4])
あと、最近のドキュメントでは **seedingは明示的に実行する（例：`prisma db seed`）**流れが説明されてる（勝手に走らない前提になりやすい）ので、運用設計しやすいよ🧠✨ ([Prisma][5])

---

## 7) よくある事故トップ7💥（ここを潰すと強い）

1. **乱数が固定されてなくて落ちる**🎲→ `faker.seed()` を使う
2. **日時が現在時刻で揺れる**🕰️→ 日付は固定値 or 時間をモック
3. **テストの実行順で結果が変わる**🔀→ テストごとに初期化（`beforeEach`）
4. **配列の並び順が不安定**📚→ sortして比較 / 期待値を並べ替える
5. **fixtureが巨大化して読めない**📦→ factory + partial上書きに寄せる
6. **DB seedが重すぎて遅い**🐢→ seedは最小セット、詳細はfactoryへ
7. **“このテストが何を見たいか”がデータから伝わらない**😇→ 名前を強くする（`userAlice` など）

ちなみに `beforeEach` / ライフサイクルは「どこが何回走るか」が整理されてるので、一度公式ガイドを見ると安心感あるよ🙂 ([Vitest][6])

---

## 8) ミニ課題（15〜25分）⏱️🧪✨

**課題A（fixture）**🧱

* `tests/fixtures/users.ts` を作って `userAlice` と `userBob` を定義
* テストで `userBob.role === "admin"` を確認✅

**課題B（factory + seed固定）**🏭🌱

* `createUser({ role: "admin" })` を使うテストを1本作る
* `beforeEach` で `faker.seed(123)` を入れて、何回実行しても同じになるのを確認🔁

**課題C（Vitest test.extend）**🧰

* `testBase.ts` を作って `user` fixtureを注入
* 2本のテストで `{ user }` を受け取って使う

---

## 9) AI拡張で時短するコツ🤖✨（でも“確認”は絶対ね！）

GitHub Copilot / OpenAI Codex みたいなAI拡張がある前提で、こう使うと速いよ💨

**そのままコピペでOKなお願い例**👇

* 「Vitestで `test.extend` を使って `user` fixture を注入する最小例を書いて。TypeScriptで。」
* 「fakerをseed固定して、毎回同じUserを作るfactoryを書いて。上書きできるようにpartial対応も。」
* 「fixtureが増えすぎた時の整理方針を、`fixtures/` と `factories/` の分け方で提案して。」

✅ AIの出力を採用する前に見るポイント👀

* 乱数・時間が固定されてる？🎲🕰️
* テスト同士が独立してる？🧍‍♂️
* “読みやすい名前”になってる？📛✨

---

## まとめ🌟

* **ユニットはfixture中心**🧱
* **増えてきたらfactoryで差分生成**🏭
* **再現性はseed固定で守る**🌱🔁
* **Vitestのtest.extendでテストがスッキリ**🧼✨ ([Vitest][3])

次章（DBあり統合テスト）に行くと、ここで作った **seed設計がそのまま効いてくる**よ😺🧪

[1]: https://www.npmjs.com/package/%40faker-js/faker?utm_source=chatgpt.com "faker-js/faker"
[2]: https://github.com/faker-js/faker/blob/next/docs/guide/usage.md?plain=1&utm_source=chatgpt.com "faker/docs/guide/usage.md at next"
[3]: https://vitest.dev/guide/test-context?utm_source=chatgpt.com "Test Context | Guide"
[4]: https://www.prisma.io/docs/orm/prisma-migrate/workflows/seeding?utm_source=chatgpt.com "Seeding | Prisma Documentation"
[5]: https://www.prisma.io/docs/orm/reference/prisma-config-reference?utm_source=chatgpt.com "Reference documentation for the prisma config file"
[6]: https://vitest.dev/guide/lifecycle?utm_source=chatgpt.com "Test Run Lifecycle | Guide"
