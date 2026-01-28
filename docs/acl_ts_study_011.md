# 11章：ACLの核① マッピングの基本（DTO→ドメイン）🔁📦

## この章でできるようになること 🎯✨

* 外部APIの **DTO（外の都合）** を、アプリ内部の **ドメイン型（自分の都合）** に変換できるようになる🙌
* 「変換関数（mapper）」を **どこに置く？どう命名する？** が迷わなくなる🧭
* DTOが内側に漏れない、キレイな境界が作れるようになる🧼🧱

---

# 11-1. まず超重要：DTOとドメイン型は“別物”だよ 🧾🆚📘

## DTO（Data Transfer Object）＝外の都合 🧳

* 外部APIのレスポンスそのまま
* 命名が変・コード値が謎・null多め・単位が不思議…みたいな “クセ” が混ざる😇
* 変更されやすい（相手が仕様変えたら即しんどい）💥

## ドメイン型＝内側の都合（あなたのルール）🏠✨

* アプリの中で読みやすく、意味が明確
* 不変条件（ルール）を守れる形にしたい🔒
* “あなたのアプリの言葉” だけで完結させたい📚

✅ 結論：**DTOは内側に入れない**。入れる前に“翻訳”する。それがACLの核🔥

---

# 11-2. マッピング（変換）の基本形はこれだけ ✨

マッピングは基本、こういう流れだよ👇

1. DTOを受け取る 📥
2. 必要なら整形（trim/数値化/日付化…）🧽
3. ドメイン型を作って返す 📤

ポイントはこれ👇

* **I/Oしない**（HTTP叩かない、DB触らない）🙅‍♀️
* **純粋関数**にする（同じ入力→同じ出力）🧪✨
* 例外や失敗をどう返すかは“設計”だけど、最初はシンプルでOK👌

---

# 11-3. 変換関数はどこに置く？命名どうする？🗂️✍️

## おすすめの置き場所（例）📁

* `src/acl/...` の下にまとめる

  * `src/acl/dto/` … 外部DTOの型
  * `src/acl/mappers/` … DTO→ドメイン変換
  * `src/acl/adapters/` … Port実装（外部呼び出し＋変換）

“ACL配下に変換が集まる”と、境界が見えやすいよ👀✨

## 命名ルール（迷ったらこれ）📝

* DTO型：`StudentDto` / `PaymentResponseDto` みたいに **Dtoを末尾**
* 変換関数：

  * `toStudent()`（短くて使いやすい）
  * `mapStudentDtoToStudent()`（明示的で安全）
* ファイル名：`student.mapper.ts` みたいに役割がわかる名前📌

---

# 11-4. ハンズオン：DTO → ドメインに変換してみよう 🧑‍💻✨

ここから手を動かすよ〜！🧤🔥
題材は「学生情報API（外部）」→「アプリ内のStudent（内側）」に変換する例📦➡️📘

（2026年1月時点でTypeScriptは5.9系が最新安定版として配布されています。）([npmjs.com][1])
（Node.jsは v24 が Active LTS で提供されています。）([Node.js][2])

---

## 11-4-1. 外部DTO（例）を定義しよう 🧾

```ts
// src/acl/dto/student-directory.dto.ts

// 外部APIが返してくる “外の都合” の形
export type StudentDirectoryStudentDto = {
  stu_id: string;              // "A00123" みたいな文字列ID
  name_kana?: string | null;   // nullが来ることも…
  name: string;
  grade_cd: "1" | "2" | "3" | "4" | "9"; // "9" が何か不明…😇
  point: string;               // "1200" みたいに数値が文字列…
  updated_at: string;          // ISOっぽい文字列
};
```

DTOは「うん、こう来るんだね…」でOK。**直さない**。直すのは変換側💪✨

---

## 11-4-2. ドメイン型（内側の言葉）を作ろう 📘✨

ここでは超シンプルにいくよ😊
（ValueObjectをガチるのは別章でOK👌）

```ts
// src/domain/student.ts

export type StudentId = string & { readonly __brand: "StudentId" };

export function StudentId(value: string): StudentId {
  // ここで最低限のチェックをしたくなるけど…
  // 今章では「作れる形に整える」までにして、厳密な検証は後の章でやろう✨
  return value as StudentId;
}

export type StudentType = "UNDERGRAD" | "GRAD" | "UNKNOWN";

export type Student = {
  id: StudentId;
  name: string;
  nameKana: string | null;
  studentType: StudentType;
  points: number;
  updatedAt: Date;
};
```

---

## 11-4-3. いよいよ変換（mapper）を書くよ 🔁🔥

```ts
// src/acl/mappers/student.mapper.ts
import { Student, StudentId, StudentType } from "../../domain/student";
import { StudentDirectoryStudentDto } from "../dto/student-directory.dto";

function toStudentType(gradeCd: StudentDirectoryStudentDto["grade_cd"]): StudentType {
  // 例：学部生=1-4、大学院=9 と仮定（外部の仕様に依存する場所はここに閉じ込める🧱）
  if (gradeCd === "9") return "GRAD";
  if (gradeCd === "1" || gradeCd === "2" || gradeCd === "3" || gradeCd === "4") return "UNDERGRAD";
  return "UNKNOWN";
}

function toPoints(point: string): number {
  // "1200" → 1200
  const n = Number(point);
  // NaN対策（ここで落とす/0にする/UNKNOWNにする…は設計）
  return Number.isFinite(n) ? n : 0;
}

export function toStudent(dto: StudentDirectoryStudentDto): Student {
  return {
    id: StudentId(dto.stu_id),
    name: dto.name,
    nameKana: dto.name_kana ?? null,
    studentType: toStudentType(dto.grade_cd),
    points: toPoints(dto.point),
    updatedAt: new Date(dto.updated_at),
  };
}
```

### ここが最高に大事ポイント 💎

* 外部の謎（`grade_cd`、`point` が文字列…）は **このファイルに隔離**🧱
* ドメイン側は **読みやすい＆意味がある型** だけになる📘✨
* 外部が変わっても、修正ポイントは **mapper周辺に集中**🔧

---

# 11-5. “変換の責任”を太らせすぎないコツ 🍔➡️🥗

mapperは便利だから、油断するとこうなる👇😇

* 変換しながらHTTP叩く
* 変換しながらDB問い合わせ
* 変換しながら巨大なif地獄

✅ まず守るルールはこれだけでOK💡

* mapperは **データの形を変えるだけ**
* 迷ったら「小さい関数に分ける」✂️✨（`toStudentType`みたいに）

---

# 11-6. ランタイム検証（ちょい最新トレンド）🧪✨（※軽く触れるだけ）

TypeScriptは「型」は強いけど、外部から来たデータが本当に型どおりかは保証できないよね😵‍💫
そこで最近は **Zodみたいなスキーマ検証**をACLで使う人が多いよ🧼✨

* Zod v4 は安定版として公開されていて、npm上でも継続的に更新されています。([Zod][3])

ただし！今章は **“マッピングの基本”** が主役なので、
本格的な「パース」「バリデーション」は **14章・15章でガッツリ**やろうね🧽✅

---

# 11-7. AI拡張（Copilot / Codex）を使うと爆速になる場面 🤖💨

GitHub Copilot は VS Code の中で、コード提案・説明・実装の補助をしてくれるよ。([Visual Studio Code][4])

## 使いどころ①：DTO→ドメイン変換の“下書き”を出してもらう ✍️

Copilot/Codexに投げる指示例👇（そのまま貼ってOK）

* 「このDTOをStudentに変換する `toStudent(dto)` を作って。`grade_cd` は enum にして、未知値は `UNKNOWN` にして」
* 「`point: string` を number にして、NaNなら0にして」
* 「mapperを小さい関数に分けて読みやすくして」

## 使いどころ②：境界ケースを洗い出す 🧠💡

* 「null/undefined/空文字/NaN/未知コードのケースを列挙して」
  → 次章以降のテストや検証にそのまま使えるよ🧪✨

⚠️ ただし：外部仕様の“意味”（例：`grade_cd="9"`が何か）は、**人間が決める**のが安全だよ🛡️🙂

---

# 11-8. ミニ演習（手を動かすと定着するよ）🎮✨

## 演習A：未知コードをログ用に残せる形にしてみよう 📝

* `toStudentType()` で `UNKNOWN` になったとき、あとで観測できるように
  `unknownGradeCd?: string` を `Student` じゃなくて「ACL側の結果」に持たせる案を考えてみてね💡
  （※ログや観測は20章でやるけど、設計の発想として◎）

## 演習B：`updated_at` が変な文字列のときどうする？⏰😇

* `new Date(dto.updated_at)` が `Invalid Date` になったら？

  * 落とす？
  * 代替値？
  * “扱えないデータ”として隔離？🚦
    どれがあなたのアプリに合うか、方針を1つ決めてみよう✨

---

# 11-9. この章のチェックリスト ✅🧼

* [ ] DTO型（`*Dto`）が `src/domain/` に入り込んでない？🚫
* [ ] mapperがHTTP/DBに触ってない？🙅‍♀️
* [ ] “外の謎”は mapper/ACL配下に閉じ込められてる？🧱
* [ ] ドメイン型は読みやすい言葉になってる？📘✨
* [ ] 変換がデカくなりそうなら、小さい関数に分けた？✂️

---

次の章（12章）では、命名変換・構造変換をもっと気持ちよくして「内側の言葉の品質」を爆上げしていくよ〜！🧾➡️📘✨

[1]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://zod.dev/v4?utm_source=chatgpt.com "Release notes"
[4]: https://code.visualstudio.com/docs/copilot/overview?utm_source=chatgpt.com "GitHub Copilot in VS Code"
