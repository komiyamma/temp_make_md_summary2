# 第13章：ACLの核③ コード値・列挙・区分の変換（謎コード撲滅）🔤🧹

## 0. 今日やること（ゴール）🎯✨

外部APIが返してくる **謎コード**（例：`"1"`, `"2"`, `"A"`, `"X9"` みたいなやつ）を、内側（ドメイン）では **意味のある型** に変換できるようにします😊
そして **未知コード** が来たときに「どう扱うか」を、設計として決められるようになります🧠🛡️

---

# 1. そもそも「コード値」ってなに？なんで危険？😵‍💫💥

外部APIあるある👇

* `stu_kbn: "1"` ← これ、見ても意味わからん😂
* 仕様書に「1=学部生、2=院生、9=その他」みたいに書いてある
* しかも増える/変わる（ある日突然 `"7"` が追加される）😇

もし内側でそのまま使うと…

* 条件分岐が `"1"` / `"2"` だらけ 🌀
* 読む人が毎回「えっと…1って何だっけ？」になる📖💦
* 外部仕様変更で内側が壊れる（腐敗💀）

だからACLでやることは超シンプル👇
**外のコード値 → 内側の“意味ある型”に翻訳する** 🗣️➡️📘

---

# 2. 2026のTypeScript的に「enum」はどう扱う？🤔🧩

TypeScriptの`enum`は、TypeScriptの中でも珍しく **実行時（JavaScript）に残る機能** です📦（＝型だけじゃない）([TypeScript][1])
その結果、バンドルが増えたり、ツリーシェイクされにくかったりする話が出がちです🌲✂️（実例解説も多い）([LINE ENGINEERING][2])

さらに最近は、`--erasableSyntaxOnly` という「実行時に残る構文（例：enum）を禁止する」オプションも入っています🚫([TypeScript][3])
なのでこの教材では、**“constオブジェクト + union型”** を基本形にします✅✨

> もちろん`enum`が絶対ダメってわけじゃないよ🙂
> ただ、ACLの「境界を薄く・安全に」って目的には、**constオブジェクト型**が相性よし💕

---

# 3. 基本形：内側は “意味ある型” を持つ（ドメイン側）📘✨

例：学生区分を、内側ではこう持つ👇

```ts
// domain/student/StudentType.ts
export const StudentType = {
  Undergrad: "UNDERGRAD",
  Grad: "GRAD",
  Other: "OTHER",
} as const;

export type StudentType = (typeof StudentType)[keyof typeof StudentType];
```

ポイント💡

* 内側では `"1"` とか一切出てこない🙅‍♀️
* 使う側は `StudentType.Undergrad` みたいに読める🎓✨
* 型としては `"UNDERGRAD" | "GRAD" | "OTHER"` のunionになる👍

---

# 4. ACLでの変換：コード値→ドメイン型（翻訳テーブル）🗃️🔁

外部：`stu_kbn` が `"1" | "2" | "9"` で来る想定にします📡

## 4.1 外部コード型をまず固定（ACL側）🧱

```ts
// acl/studentDirectory/codes/ExternalStudentTypeCode.ts
export const externalStudentTypeCodes = ["1", "2", "9"] as const;
export type ExternalStudentTypeCode = (typeof externalStudentTypeCodes)[number];

export function isExternalStudentTypeCode(v: string): v is ExternalStudentTypeCode {
  return (externalStudentTypeCodes as readonly string[]).includes(v);
}
```

## 4.2 変換テーブル（対応表）を作る📋✨

```ts
// acl/studentDirectory/codes/studentTypeMap.ts
import { StudentType } from "../../domain/student/StudentType";
import type { ExternalStudentTypeCode } from "./ExternalStudentTypeCode";

export const STUDENT_TYPE_BY_CODE = {
  "1": StudentType.Undergrad,
  "2": StudentType.Grad,
  "9": StudentType.Other,
} as const satisfies Record<ExternalStudentTypeCode, (typeof StudentType)[keyof typeof StudentType]>;
```

ここで使ってる`satisfies`は、**「型チェックはするけど、推論（as constの細さ）は保つ」** 便利機能です🪄✨([TypeScript][4])
つまり👇

* `"1"`, `"2"`, `"9"` を **書き漏らすとエラー** になりやすい✅
* `as const` の良さ（リテラル推論）も失わない✅

---

# 5. 未知コードが来たらどうする？（設計の分かれ道）🚦🤔

外部は信用しないので、**未知コードは普通に来る** 前提で考えます😇

代表的な方針は3つ👇

## 方針A：即エラー（おすすめ寄り）💥

* データが壊れてる/仕様変更の可能性が高い
* 早めに気づける（監視・テストと相性◎）🚨

## 方針B：`Other/Unknown` に丸める🧺

* 表示だけしたい、止めたくない用途で便利
* ただし、**問題が静かに隠れる** リスクもある😶‍🌫️

## 方針C：隔離（扱えないデータとして保留）🧊

* 「後で調査」する仕組みがあるなら強い💪
* ACLでログやメトリクスが必要（20章の観測につながる）📈

この章では分かりやすく **方針A（エラー）** の例でいきます🔥

---

# 6. 変換関数：DTOのコード値 → ドメイン型 ✅🛡️

```ts
// acl/studentDirectory/mappers/toStudentType.ts
import { StudentType } from "../../domain/student/StudentType";
import { STUDENT_TYPE_BY_CODE } from "../codes/studentTypeMap";
import { isExternalStudentTypeCode } from "../codes/ExternalStudentTypeCode";

export class UnknownCodeError extends Error {
  constructor(public readonly field: string, public readonly code: string) {
    super(`Unknown code for ${field}: ${code}`);
    this.name = "UnknownCodeError";
  }
}

export function toStudentType(stu_kbn: string) {
  if (!isExternalStudentTypeCode(stu_kbn)) {
    throw new UnknownCodeError("stu_kbn", stu_kbn);
  }
  return STUDENT_TYPE_BY_CODE[stu_kbn];
}
```

これで内側はずっとこう書けます👇（超読みやすい🥹✨）

```ts
if (student.type === StudentType.Grad) {
  // 院生向け処理🎓
}
```

---

# 7. “表示名”はドメインに入れない（UI用マップで分離）🧼🧱

ドメインは **意味（概念）** だけ持てばOK🙆‍♀️
「日本語ラベル」はUIの都合なので別に持つのが安全です✨

```ts
// ui/labels/studentTypeLabel.ts
import { StudentType, type StudentType as StudentTypeUnion } from "../../domain/student/StudentType";

export const StudentTypeLabel: Record<StudentTypeUnion, string> = {
  [StudentType.Undergrad]: "学部生",
  [StudentType.Grad]: "院生",
  [StudentType.Other]: "その他",
};
```

こうしておくと👇

* 画面の文言が変わってもドメインは無傷🛡️
* 多言語対応もやりやすい🌍✨

---

# 8. 変換テーブルの管理術（増えても地獄にならない）🗃️🧯

コード値変換は増えやすいので、ルールを作るのが勝ちです🏆

おすすめルール👇

* 変換テーブルは **「1種類=1ファイル」** にする（`paymentMethodMap.ts` みたいに）📄
* 外部コード型（`ExternalXxxCode`）も近くに置く📦
* 仕様書の意味をコメントで最小限残す📝
* 「この変換はACLの責任」って分かる場所に置く（client直後）🚪🧱

---

# 9. `const enum`はどう？（ちょい注意）⚠️

`const enum`は出力を小さくしやすい一方で、ビルドが「単一ファイル変換」前提の環境だと問題が出ることがあり、`isolatedModules`が警告してくれる領域でもあります🧯([TypeScript][5])
なのでこの教材のACLでは、まずは **constオブジェクト** を基本形にしておくのが安心です😊

---

# 10. ミニ演習（手を動かすと一気に理解できる）🧪🔥

## 演習①：支払い方法コードを翻訳しよう💳

外部：`pay_kbn: "A" | "B" | "Z"`
内側：`PaymentMethod = "CARD" | "CASH" | "OTHER"`

やること👇

1. `PaymentMethod` を constオブジェクトで作る
2. `ExternalPaymentCode` と判定関数を作る
3. `PAYMENT_METHOD_BY_CODE` を作る
4. `toPaymentMethod(code: string)` を作る

## 演習②：未知コードの方針をBに変えてみよう🧺

`throw` の代わりに、未知なら `Other` を返すバージョンを作ってみる✨
（ログは20章で入れる予定でもOK👌）

## 演習③：ラベルをUI層に分離しよう🪄

`PaymentMethodLabel` を別ファイルに分けて作る🎨

---

# 11. テストの超ミニ例（変換はテスト効率が最強）🧪✨

※テスト環境の話は後の章で本格化するけど、雰囲気だけ先に🌸

```ts
// acl/studentDirectory/mappers/toStudentType.test.ts
import { describe, it, expect } from "vitest";
import { toStudentType, UnknownCodeError } from "./toStudentType";
import { StudentType } from "../../domain/student/StudentType";

describe("toStudentType", () => {
  it("コード '1' は Undergrad に変換される", () => {
    expect(toStudentType("1")).toBe(StudentType.Undergrad);
  });

  it("未知コードは UnknownCodeError", () => {
    expect(() => toStudentType("999")).toThrow(UnknownCodeError);
  });
});
```

変換は「入力→出力」が明確だから、ユニットテストが超ラクです💖🧪

---

# 12. AI（Copilot/Codex）に頼むと速いところ🤖⚡

やってほしいことがハッキリしてるので、AIが得意です✨
たとえばこんな依頼が強い👇

* 「外部コード `A/B/Z` を `PaymentMethod` に変換する `as const` マップと型ガードを書いて」🗺️
* 「未知コードの扱いを “throw” と “Otherに丸める” の2案で関数作って」🔁
* 「この変換マップのテストケース、代表3つと境界値を提案して」🧪

最後にチェックするのはここ✅

* **内側に外部コードが漏れてない？**（`"1"` がドメインで登場してない？）🧼
* **未知コード方針が決まってる？**🚦
* **変換テーブルが1箇所に集まってる？**🗃️

---

# まとめ（この章で持ち帰る型の形）🎁✨

* 外の `"1"|"2"` はACLで翻訳して、内側は `StudentType` だけで生きる🌱
* 変換は **テーブル + 型ガード + 方針（未知コード）** の3点セット🧰
* `as const` + `satisfies` で「書き漏らしにくい」変換表が作れる🪄([TypeScript][4])
* 最近のTypeScriptは `enum` を禁止できるオプションもあるので、constオブジェクト運用が相性よし🚫✨([TypeScript][3])

[1]: https://www.typescriptlang.org/docs/handbook/enums.html?utm_source=chatgpt.com "TypeScript: Handbook - Enums"
[2]: https://engineering.linecorp.com/ko/blog/typescript-enum-tree-shaking?utm_source=chatgpt.com "TypeScript enum을 사용하지 않는 게 좋은 이유를 Tree-shaking ..."
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-8.html?utm_source=chatgpt.com "Documentation - TypeScript 5.8"
[4]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html?utm_source=chatgpt.com "Documentation - TypeScript 4.9"
[5]: https://www.typescriptlang.org/ja/tsconfig/?utm_source=chatgpt.com "すべてのTSConfigのオプションのドキュメント"
