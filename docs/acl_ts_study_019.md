# 第19章：テスト② 異常系・境界値・外部変更検知（壊れない設計へ）🧨🧱

## この章のゴール 🎯✨

* 外部APIの「変なデータ」でも内側（ドメイン）を壊さないテストが書ける🛡️
* **欠損 / null / 型違い / 未知コード / 桁あふれ**みたいな事故をテストで先に潰せる💥
* 外部仕様が変わったときに、**本番より先にテストが気づく**仕組みを作れる🚨✅

---

# 19-1. 「異常系テスト」ってなに？こわくないよ😇🧪

異常系テストは、ざっくり言うとこれ👇

> 「外部が変なものを送ってきたとき、こっちは**どう振る舞う**のが正しいの？」を決めて、テストで固定する

つまり **“仕様の固定”** だよ✨
「変なデータが来たら落とす？デフォルト値？隔離？」を決めておくと、実装がブレなくなる👍

---

# 19-2. 異常データあるある図鑑 📚👻（まずは敵を知る）

外部APIから来がちな“罠”はだいたいこのへん👇

## 欠損・null系 🕳️

* 必須フィールドが無い（`stu_id` が無い）
* `null` が来る（`name: null`）
* 空文字（`""`）・空配列（`[]`）

## 型が変🐟

* 数値のはずが文字列（`"100"`）
* 真偽値が `"0" / "1"`
* 日付が `"2026/01/01"` みたいな独自形式

## 値が変😇（境界値・範囲外）

* `-1`、`0`、`MAX+1`
* 桁あふれ（想定より長いID）
* 未来日時が来る / 過去すぎる

## 未知コード 👾

* `"1"|"2"` のはずが `"9"` が来る
* enumに無い値が増える

## 外部仕様変更（本章の主役）🧨

* フィールド名が変わる（`stu_kbn` → `student_kind`）
* ネスト構造が変わる
* 型が変わる（`point: number` → `point: string`）

---

# 19-3. 今日の方針：ACLは「境界で落とす」🧼🚧

この教材では、基本方針をこう置くよ👇

* **外部データは信用しない**（パース＆検証でチェック）🔍
* ダメなら **ACLで止める**（ドメインに入れない）🛑
* 例外（throw）でもResult型でもOK。ここでは分かりやすく **throw** を例にするよ💡

---

# 19-4. 実装例：学生APIのDTO → ドメイン変換 🧾➡️📘

ここからは「例」を固定して進めるね🍱🎓
外部DTO（例）はこんな感じ👇

```ts
// 外部DTO（例）: 命名も型も外部都合
export type StudentDto = {
  stu_id: string;            // "A001"
  stu_kbn: string;           // "1" or "2" ...のはず
  stu_name: string | null;   // nullが来ることがある😇
  point: unknown;            // 型がブレる可能性
  updated_at: string;        // ISO文字列（+09:00 付きが来ることも）
};
```

---

# 19-5. 異常系テストの土台：DTOの「形」をZodで検証する🧱🔍

外部のJSONは実行時には **型が無い** ので、テストで強くするならスキーマ検証がめちゃ効くよ🔥
Zodは「TypeScript-firstのバリデーションライブラリ」って公式でも言ってるやつだよ✅ ([Zod][1])

## ✅ スキーマ（例）

ZodのISO datetimeは **offset許可**がオプションで書ける（`z.iso.datetime({ offset: true })`）よ✨ ([Zod][2])

```ts
import { z } from "zod";

// 「破壊的変更」を検知したいなら .strict() も有効だけど、
// まずは "必要なものがある" を守る方針で .passthrough() にしておくのが扱いやすい👌
export const studentDtoSchema = z.object({
  stu_id: z.string().min(1),
  stu_kbn: z.string().min(1),
  stu_name: z.string().min(1).nullable(),
  point: z.unknown(),
  updated_at: z.iso.datetime({ offset: true }),
}).passthrough();

export type StudentDtoParsed = z.infer<typeof studentDtoSchema>;
```

---

# 19-6. 変換関数（ACL）の“異常系”をテストする 🧪🔥

ここが本章のメイン！
**「変な入力」→「ちゃんと止まる」**をテストで固定しよう💪

## ✅ 変換（例）

```ts
export enum StudentType {
  UNDERGRAD = "UNDERGRAD",
  GRAD = "GRAD",
}

export function mapStudentType(code: string): StudentType {
  if (code === "1") return StudentType.UNDERGRAD;
  if (code === "2") return StudentType.GRAD;
  throw new Error(`Unknown student type code: ${code}`);
}

export function parsePoints(input: unknown): number {
  // "100" みたいな文字列でも受けたいなら coerce 的に寄せる
  const n = typeof input === "string" ? Number(input) : (input as number);

  if (!Number.isFinite(n)) throw new Error("point is not a number");
  if (!Number.isInteger(n)) throw new Error("point must be int");
  if (n < 0 || n > 999_999) throw new Error("point out of range");
  return n;
}

export function mapStudent(dto: unknown) {
  const parsed = studentDtoSchema.parse(dto);

  // nullはここでは「落とす」方針
  if (parsed.stu_name == null) throw new Error("stu_name is null");

  return {
    id: parsed.stu_id,
    type: mapStudentType(parsed.stu_kbn),
    name: parsed.stu_name,
    points: parsePoints(parsed.point),
    updatedAt: new Date(parsed.updated_at),
  };
}
```

---

# 19-7. 異常系テスト：テーブル駆動で“サクサク大量”にする🍣🧪

Vitestは v4 系が出ていて、Migration Guideも v4.0向けに整備されてるよ📌 ([Vitest][3])
（テストランナーとしての定番ルートのひとつだね✨）

## ✅ 例：未知コード / null / 型違い / 範囲外

```ts
import { describe, expect, it } from "vitest";
import { mapStudent } from "../../src/acl/student/mapStudent";

describe("mapStudent - 異常系🧨", () => {
  it.each([
    ["未知コード", { stu_id: "A001", stu_kbn: "9", stu_name: "A", point: 10, updated_at: "2026-01-01T00:00:00+09:00" }],
    ["nameがnull", { stu_id: "A001", stu_kbn: "1", stu_name: null, point: 10, updated_at: "2026-01-01T00:00:00+09:00" }],
    ["pointがNaN", { stu_id: "A001", stu_kbn: "1", stu_name: "A", point: "zzz", updated_at: "2026-01-01T00:00:00+09:00" }],
    ["pointが負数", { stu_id: "A001", stu_kbn: "1", stu_name: "A", point: -1, updated_at: "2026-01-01T00:00:00+09:00" }],
    ["updated_atが変", { stu_id: "A001", stu_kbn: "1", stu_name: "A", point: 10, updated_at: "2026/01/01" }],
    ["必須欠損(stu_id無し)", { stu_kbn: "1", stu_name: "A", point: 10, updated_at: "2026-01-01T00:00:00+09:00" }],
  ] as const)(
    "%s のときは落とす🛑",
    (_, dto) => {
      expect(() => mapStudent(dto)).toThrow();
    }
  );
});
```

## 🌟ポイント

* `it.each`で「ケース表」を作ると、異常系が増えても管理しやすい📦✨
* “落ち方”を厳密にしたいなら `toThrow("...")` でメッセージまで固定してもOK🧷

---

# 19-8. 境界値テスト：ここが一番バグるゾーン🎯😇

境界値は **“0/1/MAX/MAX+1”** が鉄板だよ🍞✨

## ✅ 例：ポイントの境界値

```ts
import { describe, expect, it } from "vitest";
import { parsePoints } from "../../src/acl/student/mapStudent";

describe("parsePoints - 境界値🎯", () => {
  it.each([
    ["0 はOK", 0, true],
    ["1 はOK", 1, true],
    ["MAX はOK", 999_999, true],
    ["MAX+1 はNG", 1_000_000, false],
    ["-1 はNG", -1, false],
    ["小数はNG", 1.5, false],
    ["文字列でも数ならOK", "10", true],
  ] as const)("%s", (_, input, ok) => {
    if (ok) {
      expect(() => parsePoints(input)).not.toThrow();
    } else {
      expect(() => parsePoints(input)).toThrow();
    }
  });
});
```

---

# 19-9. 外部変更検知：フィクスチャ（外部レスポンスの標本）を残す📦🚨

ここが「壊れない設計へ」の核心💎

## ① フィクスチャを保存する🗃️

* `tests/fixtures/student/getStudent.success.json` みたいに置く
* **実データに近いほど強い**（ただし個人情報は必ず消す🙅‍♀️）

## ② フィクスチャ全件をパースして、変換できるかテストする✅

これだけで、外部が変わったときに **テストが最初に悲鳴を上げる** よ🚨

```ts
import { describe, expect, it } from "vitest";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { mapStudent } from "../../src/acl/student/mapStudent";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

describe("外部変更検知 - フィクスチャを全部通す🚨", () => {
  it("getStudent.success.json が今のACLで変換できる", async () => {
    const p = path.join(__dirname, "../fixtures/student/getStudent.success.json");
    const json = JSON.parse(await readFile(p, "utf-8"));

    expect(() => mapStudent(json)).not.toThrow();
  });
});
```

## ③ “変換結果”もスナップショットで軽く固定📸（任意）

* 外部の値が「同じフィールド名のまま中身だけ変わる」みたいな変更にも気づきやすい👍
* ただしスナップショットは増えすぎると辛いので、**代表ケースだけ**でOK🙆‍♀️

---

# 19-10. さらに強い「契約テスト」って選択肢もある📜🤝

外部が“別チームのAPI”とか“他社API”で、変更が多いなら
**契約テスト（Consumer Driven Contract Testing）** が超強いよ💪

Pactは「APIのConsumerが期待をテストとして書き、契約ファイルを作って共有する」仕組みの代表例だよ📌 ([docs.pact.io][4])

この章では深追いしないけど、覚えておくと将来かなり役立つ✨

---

# 19-11. “最新環境”のワンポイント（テストが安定しやすい選び方）🧰🪟

* Node.jsは **安定運用ならLTS系を選ぶ**のが定番（Currentより破壊的変更が少なめ）📌 ([endoflife.date][5])
* TypeScriptは 5.9 系の安定版が出ていて、5.9.3 のタグも公開されてるよ📌 ([GitHub][6])
* Vitestは v4 系が継続してリリースされていて、v4 への移行ガイドもあるよ📌 ([Vitest][7])

---

# 19-12. AIで異常系テストを“いい感じに量産”する🤖🧪

AIはこの章だとめちゃ相性いい✨（ただし最後は人間が監督ね🛡️）

## 使えるお願いの型（コピペOK）📎

* 「このDTOの想定異常ケースを **20個** 列挙して。欠損/null/型違い/境界値/未知コードを必ず入れて」
* 「Vitestの `it.each` で回せる形に整形して」
* 「“落とす”方針なので `expect(() => ...).toThrow()` にして」

## 注意⚠️

* AIが作るケースには **ドメイン的に意味不明**なものも混ざるので、採用は選別してOK🙆‍♀️

---

# 19-13. 仕上げチェックリスト ✅✨

* [ ] 欠損フィールドで落ちる🕳️
* [ ] `null`/空文字で落ちる（または代替値方針が固定）😇
* [ ] 未知コードで落ちる（or UNKNOWNへ寄せる方針が固定）👾
* [ ] 数値・日付の型違いで落ちる🐟
* [ ] 境界値（0/1/MAX/MAX+1）がテストされてる🎯
* [ ] フィクスチャが保存されていて、変換できるかをCIで見張ってる🚨📦

---

# 19-14. 練習問題（やると強くなる💪🎓）

1. `stu_name: "   "`（空白だけ）を **落とす or trimして許可**、どっちにする？方針を決めてテスト追加✍️
2. `point: "0010"` を許可する？（許可するなら `Number("0010")` は10になる）🧮
3. フィクスチャを1つ改ざんして（例：`stu_kbn` を `"9"` に）、テストがちゃんと赤くなるか確認🚨

---

[1]: https://zod.dev/?utm_source=chatgpt.com "Zod: Intro"
[2]: https://zod.dev/api?utm_source=chatgpt.com "Defining schemas"
[3]: https://vitest.dev/blog/vitest-4?utm_source=chatgpt.com "Vitest 4.0 is out!"
[4]: https://docs.pact.io/implementation_guides/javascript/docs/consumer?utm_source=chatgpt.com "Consumer Tests"
[5]: https://endoflife.date/nodejs?utm_source=chatgpt.com "Node.js"
[6]: https://github.com/microsoft/TypeScript/releases/tag/v5.9.3 "Release TypeScript 5.9.3 · microsoft/TypeScript · GitHub"
[7]: https://vitest.dev/guide/migration.html "Migration Guide | Guide | Vitest"
