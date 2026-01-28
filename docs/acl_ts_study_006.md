# 第6章：まず失敗例を見る（外部DTOが侵食する地獄）🕳️😵

## この章のゴール🎯✨

* 「外部DTOをそのまま内側で使う」と何がツラいのかを、**コードで体感**できるようになる🧠💥
* ツラさを「言語化」して、次章以降のACL実装がスッと入る状態になる🧱🚪✨
* “どこからが侵食？”を見抜けるようになる👀🧪

---

## まずは超ミニの題材🎓🍱

学内アプリ（例：学食ポイント）で「学生のポイント残高」を見て、学食を買えるか判定する…みたいなイメージね🍙✨

* 外部サービス：学生情報API（クセ強め）👻
* 内側：学食ポイントという“自分たちのルール”で考えたい📘✨
* なのに…外部DTOをそのまま内側で使うと…地獄が始まる😇🔥

---

## 2026年1月時点の“今どき”メモ🧰🆕

* Node.js は v24（Krypton）が Active LTS、v25 が Current になってるよ📌🟢 ([Node.js][1])
* Node.js の fetch は v21 で安定（stable）扱いになってるよ🌐✅ ([Node.js][2])
* TypeScript の最新安定タグは 5.9.3 が “Latest” として出てるよ🟦✨ ([GitHub][3])

（※この章の主役は“設計の痛み”だから、環境はサクッとでOK👌）

---

# 1) 外部DTOをそのまま使う「わざと悪い例」😈🧪

## 外部APIのレスポンス（例）📦

外部が返すJSONは、こんな “外の都合” が詰まってる想定👇

* 変な命名（stu_id / nm_kj / pt…）🌀
* 区分が謎コード（"1" とか "2" とか）🔤❓
* 数値っぽいのに文字列（ptが"1200"）😵‍💫
* null が普通に来る（名前がnullとか）🫠

---

# 2) まずはDTO型を作る（外の形そのまま）🧾

```ts
// src/external/studentDirectoryDto.ts
export type StudentDirectoryDto = {
  stu_id: string;          // 学籍IDっぽい
  stu_kbn: "1" | "2";      // 謎の区分コード（例：1=学部, 2=院）
  nm_kj: string | null;    // 漢字氏名（null来ることも…）
  pt: string;              // ポイント（なぜか文字列）
  upd: string;             // 更新日時（ISO文字列）
};
```

---

# 3) “外部クライアント”も作る（でもこの時点で怪しい）🌐😇

```ts
// src/external/studentDirectoryClient.ts
import { StudentDirectoryDto } from "./studentDirectoryDto";

export async function fetchStudent(stuId: string): Promise<StudentDirectoryDto> {
  const res = await fetch(`https://example.edu/api/students/${stuId}`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);

  // 🚨 ここが最初の落とし穴：実体が正しいか検証せず「型だと信じる」
  return (await res.json()) as StudentDirectoryDto;
}
```

ここ、TypeScriptだと「as で型付け」できちゃうから、**安心した気になりやすい**のが罠😵‍💫🪤
（でも実際のJSONが違っても、コンパイルは通る…）

---

# 4) 内側（ユースケース）がDTOを直で食べる🍽️💀

```ts
// src/usecases/canBuyLunch.ts
import { StudentDirectoryDto } from "../external/studentDirectoryDto";

export function canBuyLunch(dto: StudentDirectoryDto, lunchPrice: number): boolean {
  // “pt”って何…？ってなる🌀
  const points = Number(dto.pt);

  // “stu_kbn”って何…？ってなる🌀
  if (dto.stu_kbn === "2") return false; // 例：院生は学食補助対象外…とか（外部コードに依存）

  // nullチェックが内側に侵食🫠
  if (dto.nm_kj === null) return false;

  // 数値変換に失敗すると NaN 地獄😇
  return points >= lunchPrice;
}
```

## この時点で起きてる“侵食”🧟‍♀️🧠

* 内側が外側の言葉（stu_kbn / nm_kj / pt）で埋まる🌀
* “コード値の意味”が内側に混ざる🔤➡️📘（翻訳なし）
* null対応・文字列数値変換など、外部の後始末が内側に来る🧹💦

---

# 5) 「変更に弱い」を一発で体感する💥📉

## パターンA：外部が pt を points に変更した（ありがち）🔁

外部が仕様変更で JSON をこう変えたとする👇

* 旧：pt
* 新：points

でも、さっきの fetchStudent は「検証なしで as」してるから…

* TypeScriptは怒らない😇
* 実行すると dto.pt は undefined
* Number(undefined) は NaN
* 判定が全部おかしくなる🫠💥

**つまり：型があっても“境界で検証しない”と守れない**ってこと🧱🚪⚠️

---

## パターンB：謎コードが増える（"3"が来た）🔤👻

stu_kbn が "1" | "2" だと思ってたのに、ある日 "3" が来る😇

* 型的には「想定外」だけど
* 実体として来たら普通に動いてしまう（そして意図しない分岐へ）🌀

こういう “外部の仕様変更” は、**こちらの努力と無関係に突然来る**のが怖いんだよね😱🌩️

---

# 6) 「テストがつらい」を体感する🧪💦

内側の関数 canBuyLunch をテストしたいだけなのに、DTOを丸ごと作らされる😭

```ts
// test/canBuyLunch.test.ts
import { describe, it, expect } from "vitest";
import { canBuyLunch } from "../src/usecases/canBuyLunch";

describe("canBuyLunch", () => {
  it("ポイントが足りていれば true", () => {
    const dto = {
      stu_id: "A0123",
      stu_kbn: "1",
      nm_kj: "田中 花子",
      pt: "500",
      upd: "2026-01-29T12:00:00+09:00",
    };

    expect(canBuyLunch(dto, 480)).toBe(true);
  });

  it("nm_kj が null だと false（内側が外の事情に引っ張られてる）", () => {
    const dto = {
      stu_id: "A0123",
      stu_kbn: "1",
      nm_kj: null,
      pt: "500",
      upd: "2026-01-29T12:00:00+09:00",
    };

    expect(canBuyLunch(dto, 480)).toBe(false);
  });
});
```

## 何がつらいの？😵‍💫

* テストしたいのは「学食を買えるか」なのに、外部項目（stu_id, upd…）まで毎回書く羽目📝💦
* DTOが肥大化すると、テストが「作業」になる🪨
* しかも外部仕様が変わると、**内側のテストがまとめて壊れる**💥🧨

---

# 7) “侵食してるかどうか”の見分け方チェック✅👀

内側のコードで、こういうのが見えたら黄色信号🚥💛

* 変な略語・スネークケースが出てくる（pt / nm_kj / stu_kbn）🐍🌀
* "1" や "2" みたいな謎コードで分岐してる🔤❓
* Number(dto.pt) みたいな “外部の後始末” が内側にある🧹
* null対応が内側のあちこちに散ってる🫠
* テストデータが「外部レスポンスの工作」になってる📦🧪

---

# 8) ここでACLの必要性が“腹落ち”するポイント🧱🛡️✨

外部と内側は、そもそも「別の言語（別の世界）」なんだよね🌍🗣️
混ぜると、語彙が混ざってコードがぐちゃぐちゃになる…って話が有名🍝💥 ([martinfowler.com][4])

だから境界に **翻訳レイヤー（ACL）** を置いて、

* 外部の都合 ↔ 内側の都合 を変換する🧾➡️📘
* モデル同士を翻訳して腐敗を防ぐ🧼🧱

っていうのがACLの基本アイデアだよ✨ ([microservices.io][5])

---

# 9) AI活用（この章の“悪い例”作りにも使える）🤖🧠✨

## Copilot/Codex向けの例プロンプト💬

* 「学生情報APIのDTO型を、スネークケースのフィールドで作って」🧾
* 「DTOをそのまま受け取って学食購入可否を判定する関数を雑に作って」😈
* 「DTOの pt が undefined になるケースを作って、バグる様子を再現するテストを書いて」🧪💥

⚠️ ただし、AIが作る “雑な変換” はこの章ではわざとOKだけど、次章以降は「内側の言葉」を人間が監督して守るよ🛡️✨

---

# 10) まとめ：この章でわかった“地獄ポイント”🔥🕳️

* DTOを内側で直に使うと、内側が外部の語彙で汚染される🌀
* 変更に弱くなる（外部変更 → 内側崩壊）💥
* 「as」で型を信じるだけだと、実体の変更を止められない😇
* テストが外部レスポンス工作になって、しんどくなる🧪💦

次章からは、ここで出た痛みをぜんぶ回収していくよ🧼🧱✨

[1]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
[2]: https://nodejs.org/en/blog/announcements/v21-release-announce "Node.js — Node.js 21 is now available!"
[3]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[4]: https://martinfowler.com/articles/refactoring-external-service.html "Refactoring code that accesses external services"
[5]: https://microservices.io/patterns/refactoring/anti-corruption-layer.html "Pattern: Anti-corruption layer"
