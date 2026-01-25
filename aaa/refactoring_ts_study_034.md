# 第34章 any卒業③（ユーザー定義型ガード）🧷🧠

## ねらい🎯

* 「anyで通す😇」を卒業して、「unknownから安全に絞り込む✅」ができるようになる
* APIやJSONなど“外から来るデータ”を、型ガードでチェックしてから使えるようになる📦🔍
* 型ガード関数にテスト🧪を付けて、「壊してない」安心感を作る

※本日時点の現行最新は TypeScript 5.9.3 だよ〜🆕✨ ([GitHub][1])

---

## まず結論🌸：「型ガード」はこういうもの！

TypeScriptは、実行時（JavaScriptとして動く時）に“型”が消えちゃうんだよね🫧
だから **「これは本当にUserっぽい形？」を実行時にチェックする関数** を自分で作るのが「ユーザー定義型ガード」だよ🧷✨ ([TypeScript][2])

---

## よくある危険パターン（ビフォー）⚠️💥

外から来たデータに対して、いきなり「as」で決めつけちゃうやつ…👇

```ts
// ❌ ありがち：決めつけキャスト（実行時チェックが無い）
type UserDto = {
  id: string;
  name: string;
  age?: number;
};

const raw = JSON.parse('{"id": 123, "name": "Mika"}'); // idが数値でも通っちゃう…

const user = raw as UserDto; // ← ここで「UserDtoだよね？」って決めつけ😇

console.log(user.id.toUpperCase()); // 実行時に落ちる可能性あり💥
```

---

## 安全パターン（アフター）✅🛟

ポイントはこれだけ👇

1. 外部データはまず「unknown」で受ける
2. 型ガードでチェックしてから使う

```ts
type UserDto = {
  id: string;
  name: string;
  age?: number;
};

// まずは「オブジェクトっぽい？」の土台チェック🧱
function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

// ✅ ユーザー定義型ガード（trueのときだけ UserDto として扱える）
function isUserDto(value: unknown): value is UserDto {
  if (!isRecord(value)) return false;

  // 必須項目チェック
  if (typeof value["id"] !== "string") return false;
  if (typeof value["name"] !== "string") return false;

  // 任意項目チェック（あれば型が正しいこと）
  const age = value["age"];
  if (age !== undefined && typeof age !== "number") return false;

  return true;
}

const raw: unknown = JSON.parse('{"id": "u-001", "name": "Mika", "age": 20}');

if (!isUserDto(raw)) {
  throw new Error("UserDtoの形じゃないよ〜🥲");
}

// ここから先は raw が UserDto 扱いになる✨
console.log(raw.id.toUpperCase());
console.log(raw.age?.toFixed(0));
```

型ガード関数は「戻り値の型」に「parameterName is Type」みたいな“型述語”を書くのがコツだよ🧷✨ ([TypeScript][3])

---

## 手順（小さく刻む）👣✨

### 1) any を unknown に変える🧷

* 外部データ（JSON.parse / fetch / localStorage / 3rd party SDK）はまず unknown で受ける🫧

### 2) “土台ガード”を作る🧱

* 「オブジェクト？」「nullじゃない？」「配列じゃない？」を最初にやると事故が減るよ🚧

### 3) “ドメイン用ガード”を作る🧩

* 必須プロパティ：型までチェック✅
* 任意プロパティ：存在するなら型チェック✅

### 4) 使う場所は “境界（I/Oの近く）” に寄せる🚪

* 入力直後にチェックして、通ったら中では安心して扱う🛟

---

## もっと便利ワザ①：filter で配列をキレイにする🧹🌀

型ガードは「配列のfilter」と相性よすぎる〜！💖

```ts
const list: unknown[] = [
  { id: "u-1", name: "Mika" },
  { id: 999, name: "NG" },
  null,
  { id: "u-2", name: "Rina", age: 19 },
];

const users = list.filter(isUserDto);
// users は UserDto[] になる✨（変なやつは落ちる🧹）

console.log(users.map(u => u.name));
```

---

## もっと便利ワザ②：「asserts」で“通らなければ例外”にする🔥🧯

「ifで分岐するより、通らなかったら即エラーにしたい」ならアサーション関数が便利だよ😊
（例外を投げる代わりに、通った後は型が確定するやつ！） ([TypeScript][4])

```ts
function assertUserDto(value: unknown): asserts value is UserDto {
  if (!isUserDto(value)) {
    throw new Error("UserDtoじゃないよ〜🥲");
  }
}

const raw: unknown = JSON.parse('{"id":"u-3","name":"Nana"}');
assertUserDto(raw);

// ここから raw は UserDto として確定✨
console.log(raw.id);
```

---

## “DTOを安全に検証”ミニ実戦📦✅（ありがちシーン）

「APIから来たJSONをDTOとして扱いたい」ってときの王道ムーブだよ〜🧑‍💻✨

```ts
async function fetchUserJson(): Promise<unknown> {
  // 例：fetchして json() した結果（実際はAPIが返す）
  return JSON.parse('{"id":"u-10","name":"Mika","age":20}');
}

async function main() {
  const raw = await fetchUserJson(); // unknown

  if (!isUserDto(raw)) {
    // ログに入れておくと調査しやすい🪵🔍
    console.error("invalid dto", raw);
    return;
  }

  // ここからは安全✨
  console.log(raw.name);
}

main();
```

---

## テスト（型ガードは絶対テストして守る🧪🛡️）

型ガードは「通す・落とす」が命！
だからユニットテストで “OK/NG” の例を固定しちゃうのが超おすすめ💕

（例：Vitestっぽい書き方）

```ts
import { describe, it, expect } from "vitest";

describe("isUserDto", () => {
  it("OK: 正しい形なら true", () => {
    const v: unknown = { id: "u-1", name: "Mika", age: 20 };
    expect(isUserDto(v)).toBe(true);
  });

  it("NG: idがstringじゃない", () => {
    const v: unknown = { id: 123, name: "Mika" };
    expect(isUserDto(v)).toBe(false);
  });

  it("NG: null", () => {
    const v: unknown = null;
    expect(isUserDto(v)).toBe(false);
  });

  it("NG: 余計な型のage", () => {
    const v: unknown = { id: "u-1", name: "Mika", age: "20" };
    expect(isUserDto(v)).toBe(false);
  });
});
```

---

## よくある落とし穴まとめ⚠️🕳️

* 「typeof value === "object"」だけだと null が混ざる（nullもobject判定）🙅‍♀️
* 配列もobject扱いだから、必要なら Array.isArray で弾く🙅‍♀️
* 「as」で逃げると、チェックしてないのに“型だけ正しい顔”をする😇
* 任意プロパティは「あるなら型チェック」までやると事故が減る✅

---

## ミニ課題✍️🌷

### お題：ProductDto を安全にしたい🛒✨

次の型に対して「isProductDto(value: unknown): value is ProductDto」を作ってみてね！

* id は string
* title は string
* price は number
* tags は string[]（任意：無いならOK）

```ts
type ProductDto = {
  id: string;
  title: string;
  price: number;
  tags?: string[];
};
```

できたらテストも4本くらい作ろう🧪💪（OK1本、NG3本くらいがおすすめ）

---

## AI活用ポイント🤖✅（お願い方＋チェック観点）

### お願い方（コピペ用）📝🤖

* 「unknown入力 value を ProductDto に絞り込む型ガード関数 isProductDto を書いて。null/配列/任意プロパティ(tags)も考慮して」
* 「isProductDto のユニットテストを Vitest で。OK1本、NG3本。落とす理由が分かるケースにして」

### チェック観点（AIの提案を採用する前に👀✅）

* null を弾けてる？🫧
* 配列を弾けてる？🧺
* 必須プロパティの型チェックがある？🧷
* tags の「配列の中身が全部string」まで見てる？🔍
* 「as」で雑にキャストしてごまかしてない？⚠️

---

## まとめ🧁✨

* 外部データは unknown で受ける🧷
* 型ガードで「本当にその形？」をチェックしてから使う✅
* filter や asserts を使うと、実務が一気にラクになるよ〜🛟💕 ([TypeScript][3])

[1]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[2]: https://www.typescriptlang.org/docs/handbook/2/narrowing.html?utm_source=chatgpt.com "Documentation - Narrowing"
[3]: https://www.typescriptlang.org/docs/handbook/advanced-types.html?utm_source=chatgpt.com "Documentation - Advanced Types"
[4]: https://www.typescriptlang.org/ja/play/3-7/types-and-code-flow/assertion-functions.ts.html?utm_source=chatgpt.com "プレイグラウンド 例 - Assertion Functions"
