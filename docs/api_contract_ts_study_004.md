# 第4章：TypeScriptの型は契約の入り口🟦🧩

## この章でできるようになること🎯✨

* 「型＝契約」ってどういう意味？をスッキリ説明できる🤝
* 型で守れること／守れないこと（実行時）を区別できる⚖️
* “外から来るデータ”を安全に扱う入口（unknown＋絞り込み）が書ける🚪🔒
* 「オプショナル（?）の落とし穴」を回避できる（exactOptionalPropertyTypes）🕳️💡 ([TypeScript][1])
* `satisfies` で「型チェックだけして推論は保持」を使える🧠✨ ([TypeScript][2])

---

## 0. まず超ざっくり：型は“約束の文章”📜🟦

TypeScriptの型は、**「この関数はこう呼んでね」「このデータはこういう形だよ」**っていう“約束”をコードに書くものだよ😊
そしてこの約束は、主に **コンパイル時（型チェック時）に守られる** んだけど、**実行時（ランタイム）には型は存在しない**のが大事ポイント⚠️

> だからこそ「型は契約の入り口」＝契約のスタート地点だけど、契約の全てではないよ🧩✨

---

## 1. 1分で体験：型が契約になる瞬間⚡🟦

```ts
// 呼び出す人（利用者）との約束＝引数と戻り値の型✨
export function calcTotal(price: number, quantity: number): number {
  return price * quantity;
}

// ✅ OK
calcTotal(120, 3);

// ❌ NG（契約違反）
// calcTotal("120", 3);
```

ここで `calcTotal` の型は、利用者にとっての **契約書** だよ📄✨
「numberを2つ入れたらnumberが返る」って約束ね🤝

---

## 2. でも万能じゃない：型で守れない世界（実行時）🌪️😵‍💫

### 2-1. JSONは“型を無視して入ってくる”📦⚠️

外部（API/ファイル/DB/localStorageなど）から来るデータは、型がついてないことが多いよね。

```ts
// 例：どこかから来たJSON文字列
const json = `{"name":"Mina","age":"20"}`;

// parseした瞬間、実行時はただの “値”
const data = JSON.parse(json);

// ここで「ageはnumberのはず」と思い込むと…😇
console.log(data.age + 1); // "201" みたいな事故が起きる💥
```

**型チェックはコンパイル時の世界**だから、`JSON.parse` の結果が正しい形かどうかは保証してくれないんだ〜😵‍💫

---

## 3. 契約の入口としての“境界”を作ろう🚪🔒（any禁止、unknown推し✨）

### 3-1. `any` は契約を破壊する😱🧨

`any` を使うと、型チェックが止まって “契約が紙切れ” になるよ💔

```ts
function unsafe(x: any) {
  // なんでも通る😇
  return x.toUpperCase();
}
```

### 3-2. `unknown` は「まず疑う」から安全🕵️‍♀️✨

外部入力は `unknown` で受けて、**中で確認してから使う**のがコツ！

```ts
type User = {
  name: string;
  age: number;
};

function isUser(value: unknown): value is User {
  if (typeof value !== "object" || value === null) return false;

  const v = value as Record<string, unknown>;
  return (
    typeof v.name === "string" &&
    typeof v.age === "number"
  );
}

function parseUser(json: string): User {
  const value: unknown = JSON.parse(json);

  if (!isUser(value)) {
    throw new Error("Userの形じゃないよ🥺");
  }

  return value;
}
```

これが **「契約の入口」** って感じ！🚪✨

* 境界でチェック✅
* 中に入れたら信頼して楽に書く🧡

---

## 4. TypeScriptは“形で見る”＝構造的型付け🧩🔍

TypeScriptは「名前」じゃなくて「形（プロパティ構造）」で型を見ます。

```ts
type Point2D = { x: number; y: number };

const p = { x: 1, y: 2, z: 999 };

// ✅ 形が合うからOKになりやすい（余計なzがあっても代入できる場面がある）
const a: Point2D = p;
```

便利だけど、契約設計では「混ざってほしくないものが混ざる」事故も起きる😵‍💫
次の「ブランド型」で対策するよ💪✨

---

## 5. “同じnumberだけど別物”を混ぜない🧷✨（ブランド型）

ユーザーIDと商品ID、両方 `number` だと混ざりやすいよね😇

```ts
type Brand<K, T> = K & { __brand: T };

type UserId = Brand<number, "UserId">;
type ProductId = Brand<number, "ProductId">;

function toUserId(n: number): UserId {
  return n as UserId;
}

function toProductId(n: number): ProductId {
  return n as ProductId;
}

function loadUser(id: UserId) {
  // ...
}

const uid = toUserId(1);
const pid = toProductId(1);

loadUser(uid); // ✅
// loadUser(pid); // ❌ 混ぜる事故を防げる💖
```

「契約として区別したい型」は、こうやって守ると強いよ🛡️✨

---

## 6. オプショナル（?）は契約の地雷💣😵（absence と undefined は別！）

### 6-1. ありがちな誤解：「? は undefined もOKでしょ？」🤔

実は、設定で挙動が変わるよ⚙️

* `exactOptionalPropertyTypes: true` にすると、**「省略できる」と「undefinedを入れる」は別物**として扱う（より契約っぽくなる）✨ ([TypeScript][1])

```ts
// tsconfig: "exactOptionalPropertyTypes": true
type Profile = {
  nickname?: string; // ない（省略）ならOK
};

const a: Profile = {}; // ✅ 省略OK
// const b: Profile = { nickname: undefined }; // ❌ “undefinedを入れた”は別扱い
```

### 6-2. 契約設計的に嬉しいこと💡

* 「値がない」＝プロパティが存在しない（欠けてる）
* 「値がある」＝ちゃんと値がある
  この区別ができると、JSON契約がブレにくいよ🧾✨

---

## 7. `noUncheckedIndexedAccess` で「取り出しは危険」を型に出す🧪⚠️

配列や辞書の `[]` って、存在しないかもだよね？

`noUncheckedIndexedAccess: true` を有効にすると、**存在しない可能性（undefined）を型に出してくれる**よ✅ ([TypeScript][3])

```ts
// tsconfig: "noUncheckedIndexedAccess": true
const map: Record<string, number> = { apple: 100 };

const price = map["banana"];
// price は number | undefined になりやすい🍌⚠️
```

契約設計では「存在しないときの扱い」も契約の一部だから、これめっちゃ相性いい👍✨

---

## 8. `satisfies`：チェックだけして推論は残す🎀✨

「型に合ってるかチェックしたい。でも推論の便利さは失いたくない！」って時に神👼

```ts
type Route = {
  path: `/${string}`;
  method: "GET" | "POST";
};

const routes = [
  { path: "/users", method: "GET" },
  { path: "/orders", method: "POST" },
] satisfies Route[];
```

* `as Route[]` みたいに雑にねじ込まない
* “合ってるか”だけ検査してくれる
* しかも、配列要素の具体的な推論は残りやすい✨ ([TypeScript][2])

---

## 9. 章のテーマに直結：型で契約を育てるときの「安全な変更」🧬🌱

ここは次章以降で深掘りするけど、まず感覚だけ🎈

* ✅ **追加（任意プロパティを足す）**：比較的安全（後方互換になりやすい）
* ⚠️ **必須を増やす**：古い利用者が壊れる可能性
* ❌ **削除／型変更**：破壊的変更になりやすい

この判断をするとき、TypeScriptの型は「契約の変化」を早めに気づかせてくれるよ👀✨

---

## 10. ミニ演習✍️🧩（手を動かすと定着するよ〜！）

### 演習①：型だけで防げない例を1つ書こう📝😵‍💫

次のテーマから1つ選んで「型があっても壊れる例」を書いてみてね👇

* `JSON.parse` の型事故
* localStorageの文字列事故
* APIが仕様変更して形が変わった事故

💡ヒント：**unknownで受けて、絞り込み（型ガード）**まで書けたら満点💯✨

### 演習②：`exactOptionalPropertyTypes` 体感💣➡️💡

```json
// tsconfig.json（抜粋）
{
  "compilerOptions": {
    "strict": true,
    "exactOptionalPropertyTypes": true
  }
}
```

この設定で、`{ nickname: undefined }` がエラーになるのを確認してみよう👀✨ ([TypeScript][1])

---

## 11. AI活用コーナー🧠🤖✨（レビュー係にしてラクしよ）

### 11-1. 契約を言語化してもらう📝

* 「この関数の利用者との約束（入力/出力/例外/副作用）を箇条書きにして」🧾✨
* 「この型の弱点（実行時に守れない点）を3つ挙げて」⚠️

### 11-2. unknown→安全な型ガードを生成してもらう🔒

* 「このJSONの想定スキーマを元に、TypeScriptの型ガード関数を書いて」🧩
* 「境界でunknownを検証して、内部は信頼する設計にリファクタして」🚪✨

### 11-3. “破壊的変更っぽい？”を判定させる🔍

* 「この型変更は後方互換？ 破壊的？ 理由も」🧠

（AI拡張の例：GitHubのCopilotや、OpenAI系のコーディング支援ツールなど🧸✨）

---

## 12. まとめ🎀✅

* 型は **契約の入り口**：呼び方・返し方・データ形状を“約束”できる🤝
* でも **実行時は守れない**：外から来る値は unknown で受けて検証する🚪🔒
* `exactOptionalPropertyTypes` は「省略」と「undefined」を分けて契約を強くできる🧾✨ ([TypeScript][1])
* `satisfies` は「合ってるかだけ検査」できて便利🎀 ([TypeScript][2])

---

### 参考：最新のTypeScript周辺メモ🗞️✨

* 現時点の安定版としては npm / GitHub 上で TypeScript 5.9.3 が確認できるよ📌 ([npmjs.com][4])
* TypeScript 5.9 では `import defer` など新機能も入ってるよ📦✨ ([TypeScript][5])
* さらに将来に向けて、ネイティブ版のプレビューや移行ロードマップも公式から出てるよ（高速化の流れ）🚀✨ ([Microsoft for Developers][6])

[1]: https://www.typescriptlang.org/tsconfig/exactOptionalPropertyTypes.html?utm_source=chatgpt.com "TSConfig Option: exactOptionalPropertyTypes"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-9.html?utm_source=chatgpt.com "Documentation - TypeScript 4.9"
[3]: https://www.typescriptlang.org/tsconfig/noUncheckedIndexedAccess.html?utm_source=chatgpt.com "TSConfig Option: noUncheckedIndexedAccess"
[4]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
[5]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html "TypeScript: Documentation - TypeScript 5.9"
[6]: https://devblogs.microsoft.com/typescript/announcing-typescript-native-previews/?utm_source=chatgpt.com "Announcing TypeScript Native Previews"
