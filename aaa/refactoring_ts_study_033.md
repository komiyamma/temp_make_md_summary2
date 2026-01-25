# 第33章 any卒業②（narrowingの基本）🔍🧩

### ねらい🎯

* 「広い型（unknown / union）」を、条件分岐で“安全に絞り込む”感覚をつかむ✨
* typeof / in / instanceof を使い分けて、落ちないコードにする🛟
* 「絞り込みできる形」に整える＝リファクタの入り口に立つ🚪🌱

---

### 今日のゴール🏁

* 受け取った値が何者か分からなくても、判定しながら安全に使える✅
* 「この if の中では string！」みたいに、TypeScript に納得してもらえる🧷✨
* any を減らしても開発スピードを落とさない（むしろ事故が減る）🚀

---

### まず結論：narrowing（型の絞り込み）って何？🧠✨

TypeScript は、if / switch などの「実行時の判定」をヒントにして、変数の型を段階的に絞ってくれるよ〜！
この仕組みが “Narrowing（型の絞り込み）” だよ📌 ([TypeScript][1])

---

## 1) ビフォー：any はラクだけど、落とし穴だらけ😵‍💫🕳️

外から来る値（API / JSON / localStorage / フォーム）は、だいたい「型があいまい」だよね。

#### ビフォー（any で突っ込む）💥

```ts
function greet(raw: any) {
  // 何でも通るけど…
  return "Hello " + raw.name.toUpperCase();
}

// 実行時に落ちる例😇
console.log(greet({ name: 123 })); // toUpperCase が無い！
```

**ポイント**

* any は「型チェックの安全ネット」を外しちゃう🎈
* だから「絞り込み」も活かしにくい（何でもOKになっちゃう）😵

---

## 2) アフター：unknown ＋ narrowing で“落ちない道”を作る🛟🧷

#### アフター（unknown を判定しながら使う）✨

```ts
function greet(raw: unknown) {
  // まず “raw がオブジェクトっぽいか” を確認
  if (typeof raw === "object" && raw !== null) {
    // 次に “name を持ってるか”
    if ("name" in raw) {
      const nameValue = (raw as { name: unknown }).name;

      // 最後に “name が文字列か”
      if (typeof nameValue === "string") {
        return "Hello " + nameValue.toUpperCase();
      }
    }
  }

  return "Hello Guest";
}
```

**ここが大事💡**
unknown は「そのままでは触れない」けど、判定すれば安全に触れるようになる🧤✨
だから、設計が超入門でも “壊さない改善” がしやすいよ👣

---

## 3) 基本の narrowing 4点セット🧰✨

### A. typeof：プリミティブ判定の王様👑

文字列・数値・真偽などはまずこれ！

```ts
function normalize(input: unknown) {
  if (typeof input === "string") {
    return input.trim();
  }

  if (typeof input === "number") {
    return input.toFixed(2);
  }

  return "N/A";
}
```

✅ ありがち用途

* フォーム入力（だいたい string）
* JSON パース後の値チェック
* 設定値（string | number みたいな混在）

---

### B. “null だけ特別”に注意⚠️🫧

JavaScript では null も “object 扱い” なので、ここは定番の罠！😇

```ts
function isObjectLike(x: unknown) {
  return typeof x === "object" && x !== null;
}
```

---

### C. in：プロパティを持ってるかで絞る🧩

「オブジェクトっぽい」＋「その鍵がある」を見たいときに便利🎯

```ts
function getMessage(x: unknown) {
  if (typeof x === "object" && x !== null && "message" in x) {
    const msg = (x as { message: unknown }).message;
    if (typeof msg === "string") {
      return msg;
    }
  }
  return "(no message)";
}
```

---

### D. instanceof：クラス由来の値を絞る🏷️✨

Date や Error みたいな「インスタンス」を判定できるよ！

```ts
function formatError(e: unknown) {
  if (e instanceof Error) {
    return e.name + ": " + e.message;
  }
  return "Unknown error";
}
```

---

## 4) union 型でも narrowing は超強い💪✨（if / switch の基本）

### 例：文字列 or 数値を受け取って処理を変える🚦

```ts
function display(value: string | number) {
  if (typeof value === "string") {
    return value.toUpperCase();
  } else {
    return value.toFixed(0);
  }
}
```

### 例：リテラル（決まった文字）で分岐する🏷️

```ts
type Mode = "easy" | "hard";

function getHp(mode: Mode) {
  if (mode === "easy") return 200;
  return 100;
}
```

---

## 5) 最近のTypeScriptだと「キーアクセス」も絞り込みが効きやすい🧠✨

TypeScript 5.5 では、条件が揃うと「obj[key]」みたいなアクセスでも、制御フロー解析で絞り込みしやすくなったよ🧷
（レコード型＋キーが実質固定、みたいなケース） ([TypeScript][2])

```ts
function upperIfString(obj: Record<string, unknown>, key: "title" | "label") {
  const v = obj[key];

  if (typeof v === "string") {
    return v.toUpperCase(); // 絞り込みが効く✨
  }

  return "";
}
```

※ 2026年1月時点の最新リリースノートは TypeScript 5.9 系だよ📚 ([TypeScript][3])

---

## 6) リファクタ手順（小さく刻む）👣🛟

「any を消す」って聞くと怖いけど、順番を守れば大丈夫🙆‍♀️✨

1. 触る関数の入口だけ any → unknown にする🧷
2. その直後に “判定ブロック（if）” を置く🔍
3. 判定の中でだけ安全に使う✅
4. 分岐が増えたら、判定を小さな関数に分ける（次章で本格的にやるよ）✂️📦
5. 変更は小さくコミット（差分が説明できるサイズ）💾

---

## 7) ミニ課題✍️🌸

### 課題A：unknown を安全に表示しよう📦➡️🧷

下の関数を「落ちない」ように直してね！

```ts
function showProfile(x: unknown) {
  // 目標：
  // - x が { name: string } なら "NAME: ◯◯"
  // - それ以外は "NAME: (unknown)"
  return "NAME: " + (x as any).name.toUpperCase();
}
```

✅ ヒント

* object 判定 → in 判定 → string 判定 の順が安定だよ👣✨

---

### 課題B：配列かどうかを判定して合計しよう🧮✨

```ts
function sumNumbers(x: unknown) {
  // 目標：
  // - x が number[] っぽければ合計
  // - それ以外は 0
  return 0;
}
```

✅ ヒント

* Array.isArray を使う
* 中身が number かどうかも typeof で確認する

---

## 8) AI活用ポイント🤖✅（お願い方＋チェック観点）

### お願い方（そのまま使える）📝✨

* 「unknown を typeof / in / instanceof で安全に絞り込む if の順番を提案して」
* 「この関数で起こり得る入力パターン（壊れるケース）を列挙して」
* 「分岐が増えすぎないリファクタ案を3つ。安全順で並べて」

### AIの提案を採用する前のチェック✅🧷

* 判定順が “object → null除外 → in → typeof” になってる？🔍
* 変換（as）を乱用してない？（必要最小限？）⚠️
* 例外ケース（null / 数値 / 空文字 / 想定外オブジェクト）に耐える？🛟

---

[1]: https://www.typescriptlang.org/docs/handbook/2/narrowing.html?utm_source=chatgpt.com "Documentation - Narrowing"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-5.html?utm_source=chatgpt.com "Documentation - TypeScript 5.5"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
