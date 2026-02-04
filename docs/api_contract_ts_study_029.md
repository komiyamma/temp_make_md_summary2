# 第29章：互換性テスト②：最小テスト構成（型＋ユニット）✅🧪

## この章のゴール🎯✨

* 「壊しちゃダメな約束（契約）」を **最小の手間** で守れるようになる🛡️
* **型チェック（コンパイル）** と **ユニットテスト（実行）** の役割分担ができるようになる🧠
* 「どこまでやれば十分？」の判断軸を持てるようになる⚖️

---

## まず結論：最小の“守りのセット”はこれ💡✅

契約を守るのに、最初からテスト地獄にする必要はないよ〜☺️🌸
まずはこの **3点セット** からスタートでOK！

1. **型チェック**：`tsc --noEmit`（コンパイルで契約崩れを止める）🟦🧱
2. **型テスト（必要なときだけ）**：公開型・ジェネリクス・オーバーロードの「意図」を固定する🧩
3. **ユニットテスト**：挙動・エラー・境界（入力チェック）を固定する🧪⚙️

> TypeScriptは現時点だと5.9系が安定ラインで、次の大きな節目として6.0（7.0への橋渡し）も予告されています。([Microsoft for Developers][1])
> だからこそ「**型＋ユニット**」で“壊れない最低限の柵”を作っておくのが超大事だよ〜🧸🧡

---

## 29-1. 守るべき「契約」を3つだけ選ぼう🎯📝

前章（観点）で出てきた「壊れやすいところ」全部を最初から守ろうとすると、しんどい😵‍💫💦
ここでは、**重要な契約を3つだけ** 選ぶよ！

## 3つの選び方（テンプレ）🧾✨

次の中から **各1個ずつ** 選ぶのがオススメ👇

* **A. 公開API**：外から呼ばれる関数／クラス／型（Public Surface）🚪
* **B. 返り値の意味**：成功時の形、値の意味（例：ソート順、単位、丸め）📦
* **C. エラーの約束**：失敗時の形式（例：エラーコード、例外の種類）💥

✅ 例：

* A：`getUser(id)` の引数と返り値
* B：`calcPrice()` が「税込みで返す」
* C：入力不正のときは `ValidationError` を投げる

---

## 29-2. 型チェックは「最強の無料ガード」🟦🛡️

## 役割はこれ！✨

* **公開APIが変わってしまった**（引数が減った／型が変わった）
* **依存関係や型定義の変更で壊れた**
* **意図せぬany化・推論崩壊**

これらを **最速で止める** のが `tsc --noEmit` だよ✅

## 最小のスクリプト例📦

```json
{
  "scripts": {
    "typecheck": "tsc --noEmit"
  }
}
```

「テスト書く前に、まずこれが通る」を基本姿勢にするだけで、事故がかなり減るよ〜🧯✨

---

## 29-3. 型テストは「型の意図」を固定する🧩🔒

型チェックは強いんだけど、**“意図”までは固定しきれない** ことがあるよ😵‍💫
たとえば👇

* ジェネリクスの推論結果が変わった
* オーバーロードの選ばれ方が変わった
* 公開型（`.d.ts`）が微妙に崩れた

そんなときに効くのが **型テスト**！

## 選択肢①：Vitestの型テスト（手軽）🧪🟦

Vitestは `*.test-d.ts` を型テストとして扱う仕組みがあって、`expectTypeOf` / `assertType` で型の期待を固定できるよ。([vitest.dev][2])
（Vitest自体は2025年に4.0が出て、今も活発に更新されてるよ〜🚀）([vitest.dev][3])

## 選択肢②：tsd（公開型をガチ守り）📘🧪

ライブラリや型定義を配るなら、`tsd` みたいな「型定義テスト専用ツール」も便利！
`.test-d.ts` で `expectError` みたいな構文を使って“壊しちゃダメ”を固定できるよ。([GitHub][4])

---

## 29-4. ユニットテストは「意味・挙動・エラー」を固定する⚙️🧪

型では守れない契約があるんだよね👇🥺

* **値の意味**（税込み/税抜き、ms/秒、昇順/降順…）
* **境界の挙動**（空文字、0、null、巨大値）
* **エラー形式**（例外の型、エラーコード、メッセージ）

ここを守るのがユニットテストの仕事💪✨

---

## 29-5. 例題：小さな契約を「型＋ユニット」で守る🎁🧸

## 仕様（＝契約）📜✨

* `parseUser(input)` は `User` を返す
* `User.id` は `"usr_"` で始まる
* 入力が不正なら `ValidationError` を投げる

---

## 実装（例）🧩

```ts
// src/user.ts
export type UserId = `usr_${string}`;

export type User = {
  id: UserId;
  name: string;
};

export class ValidationError extends Error {
  readonly code = "VALIDATION_ERROR";
  constructor(message: string) {
    super(message);
    this.name = "ValidationError";
  }
}

export function parseUser(input: unknown): User {
  if (typeof input !== "object" || input === null) {
    throw new ValidationError("input must be an object");
  }

  const obj = input as { id?: unknown; name?: unknown };

  if (typeof obj.id !== "string" || !obj.id.startsWith("usr_")) {
    throw new ValidationError("id is invalid");
  }
  if (typeof obj.name !== "string" || obj.name.length === 0) {
    throw new ValidationError("name is invalid");
  }

  return { id: obj.id as UserId, name: obj.name };
}
```

---

## 型テスト（Vitest方式のイメージ）🟦🧪

> `*.test-d.ts` を使った型テストの考え方はVitestのガイドにまとまってるよ。([vitest.dev][2])

```ts
// test/user.test-d.ts
import { expectTypeOf } from "vitest";
import { parseUser, type User, type UserId } from "../src/user";

const u = parseUser({ id: "usr_123", name: "Alice" });

// 返り値が User であることを固定🧷
expectTypeOf(u).toMatchTypeOf<User>();

// id が UserId（テンプレ literal）であることを固定🧷
expectTypeOf(u.id).toMatchTypeOf<UserId>();
```

> `expect` 自体の基本（Jest互換のアサーション等）もVitest公式にまとまってるよ。([vitest.dev][5])

---

## ユニットテスト（挙動・エラー契約）⚙️🧪

```ts
// test/user.spec.ts
import { describe, it, expect } from "vitest";
import { parseUser, ValidationError } from "../src/user";

describe("parseUser", () => {
  it("valid input returns User", () => {
    const u = parseUser({ id: "usr_123", name: "Alice" });
    expect(u).toEqual({ id: "usr_123", name: "Alice" });
  });

  it("invalid id throws ValidationError", () => {
    expect(() => parseUser({ id: "xxx_123", name: "Alice" })).toThrow(ValidationError);
  });

  it("invalid input type throws ValidationError", () => {
    expect(() => parseUser(null)).toThrow(ValidationError);
    expect(() => parseUser("nope")).toThrow(ValidationError);
  });
});
```

ここで守ってるのは **「意味」** と **「失敗の形」** だよ〜💖
型だけだと絶対に守れないところ！えらい！👏✨

---

## 29-6. 最小構成の“回し方”✅🔁

## ローカルで回すコマンド（例）🌀

* `typecheck`：型の契約を守る🟦
* `test`：挙動の契約を守る🧪

大事なのは「**両方が通る＝契約OK**」って状態を作ることだよ💡

---

## 29-7. よくある落とし穴💣➡️🧯

## 落とし穴①：型チェックだけで安心しちゃう😴💤

* 「税込み/税抜き」の意味変更とか、型は通るのに壊れるやつ…あるある😭

✅ 対策：

* **意味がある値**（単位・丸め・順序）を1〜2個だけでもユニットで固定🧪✨

---

## 落とし穴②：ユニットテストが“内部実装テスト”になっちゃう🧱🔍

* private関数や内部構造に依存すると、リファクタでテストが壊れる😵‍💫

✅ 対策：

* テスト対象は **契約（公開API・戻り値・エラー）だけ** に寄せる🚪📦💥

---

## 落とし穴③：型テストをやりすぎる🌀

* 型テストは強いけど、書きすぎると更新がつらい😇

✅ 対策：

* 型テストは「**壊れたら致命傷**」だけ（ジェネリクス・公開型・オーバーロード）に限定🎯

---

## 29-8. ミニ演習🎓🌸（30〜45分）

あなたの小さな機能（またはミニAPI）を1つ選んで、これをやってみよう💪✨

## Step 1️⃣ 契約を3つ選ぶ🎯

* 公開API：________
* 返り値の意味：________
* エラーの約束：________

## Step 2️⃣ 型チェックを通す🟦✅

* `tsc --noEmit` が通る状態にする

## Step 3️⃣ ユニットテストを2本だけ書く🧪✍️

* 成功ケース：1本
* 失敗ケース（エラー契約）：1本

## Step 4️⃣（任意）型テストを1本だけ書く🧩🧷

* 「型の意図」が壊れたら困るところを1つ固定

---

## 29-9. AI活用プロンプト集🧠🤖✨（コピペOK）

## 契約の抽出📝

* 「この関数の“契約”を **公開API／返り値の意味／エラー** に分けて3つに整理して」

## 最小テストの提案🧪

* 「この契約を守るために、**型チェック／型テスト／ユニットテスト** それぞれ最小で何を書けばいい？」

## 失敗ケース作り💥

* 「この関数の入力で壊れやすい境界ケースを10個出して（null、空文字、巨大値など）」

## テストレビュー🔍

* 「このテストは“内部実装”に依存してない？ 契約テストとして改善案を出して」

---

## この章のまとめ📌✨

* **型チェック**＝公開APIの崩れを止める🟦🛡️
* **型テスト**＝型の“意図”を固定する（必要なときだけ）🧩🔒
* **ユニット**＝意味・挙動・エラーを固定する⚙️🧪
* まずは **契約3つ** を選んで、**最小本数** で守るのが勝ち🏆💖

[1]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/?utm_source=chatgpt.com "Announcing TypeScript 5.9"
[2]: https://vitest.dev/guide/testing-types?utm_source=chatgpt.com "Testing Types | Guide"
[3]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[4]: https://github.com/tsdjs/tsd?utm_source=chatgpt.com "tsdjs/tsd: Check TypeScript type definitions"
[5]: https://vitest.dev/api/expect?utm_source=chatgpt.com "Expect"
