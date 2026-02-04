# 第5章：公開API面（Public Surface）を決める🎭🚪

## 今日のゴール🎯✨

* 「ここから先は“利用者との約束”だよ🤝」っていう **公開範囲（Public Surface）** を、自分で決められるようになる🙌
* TypeScriptの世界で「公開＝どこまで安定させるか」を、**フォルダ・export・package.json** でコントロールできるようになる🧩✨
* “うっかり公開” を防いで、将来の変更がラクになる🛠️🌈

---

## 1) 公開API面ってなに？🤔🚪

公開API面（Public Surface）は、かんたんに言うと👇

* **利用者が触っていい入口**（importして使う場所）
* **あなたが将来も守る約束の範囲**（壊さないように頑張る範囲）

たとえば、ライブラリなら利用者はこう書くよね👇

* `import { foo } from "your-lib";` ← ここが “入口” 🚪
  この入口から見える関数・型・挙動が、公開API面になるよ✨

---

## 2) まず最初に決めること：利用者はだれ？👥🧠

公開API面は「誰に約束するか」で大きさが変わるよ🌸

* **自分だけ（アプリ内部）**：公開面は “チーム内ルール” くらいの強さでもOK👌
* **他の人/他プロジェクト**：公開面は小さく！安定優先！🧱
* **npmで公開**：公開面は “契約” そのもの！破ると炎上しやすい🔥😱

---

## 3) 公開面を小さくするメリット💎✨

公開面を小さくすると、いいことだらけ☺️🌷

1. **変更が怖くなくなる**（内部を自由に直せる）🛠️
2. **学習コストが下がる**（使い方が迷子にならない）🧭
3. **破壊的変更が減る**（互換性を守りやすい）🔁✅

---

## 4) ルール：公開するもの / 隠すもの🧺🔒

迷ったら、まずこの基準でOK🙆‍♀️✨

### 公開していいもの✅

* 利用者が **本当に使う** 関数・クラス・型だけ🎁
* 名前や引数が **長く安定** しそうなもの🧱
* “意味” をちゃんと説明できるもの📝💡

### 隠したいもの🔒

* 仕様が揺れてる途中のやつ（試作・実験）🧪
* 内部都合のヘルパー（`parseXxx` の細かいやつ等）🧰
* あとで変えたくなる構造（ファイル配置・内部データ構造）🧬

---

## 5) 入口を作る：`public-api.ts`（または `index.ts`）🎯🚪

公開API面を決める一番わかりやすい方法は👇
**「入口ファイルを1個作って、そこからだけ export する」** だよ✨

### 例：フォルダ構成📁🌈

```text
src/
  internal/
    calcCore.ts
    parse.ts
  public-api.ts
```

* `src/internal/*` は **内部**（好きに変更OK）🔧
* `src/public-api.ts` は **公開入口**（ここは慎重に）🚪✨

---

## 6) “export の仕方” で公開範囲が決まる🎭🧩

### ✅ おすすめ：明示的に export（事故りにくい）🧁

```ts
// src/public-api.ts
export { add, subtract } from "./internal/calcCore";
export type { CalcOptions } from "./internal/calcCore";
```

### ⚠️ 便利だけど注意：`export *`（うっかり公開しがち）🙈💦

```ts
// src/public-api.ts
export * from "./internal/calcCore"; // 余計なものまで漏れやすい
```

---

## 7) バレル（barrel）ファイルの注意点📦⚡

`public-api.ts` や `index.ts` みたいな “まとめexport” は便利だけど、**増えすぎると** ビルドやエディタが重くなることがあるよ😵‍💫💦
実際に大規模コードで「バレルを減らしたらビルドが大幅に速くなった」事例もあるの。だから👇が現実的🌸

* **公開入口はOK（1個〜少数）** ✅
* **内部までバレルだらけは避ける** ⚠️

([アトラシアン][1])

---

## 8) “強制的に” 入口だけにする：`package.json` の `"exports"` 🧱🚪

npm公開や社内パッケージなら、さらに強く守れるよ✨
`package.json` の `"exports"` を使うと👇

* 利用者が **勝手に深いパス（内部ファイル）を import** するのを止められる🙅‍♀️
* Node.js では `"exports"` があると、基本的に **指定した入口以外はアクセスできない** 挙動になるよ🚪🔒

([Node.js][2])

### 例：入口を “`.`（ルート）だけ” に固定🧷

```json
{
  "name": "math-lite",
  "type": "module",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "types": "./dist/index.d.ts"
    }
  }
}
```

* `"exports"` は **環境ごと（import/require等）に分岐** もできるよ🔁
* Node.js の仕様として、`"exports"` に書くパスは `./` から始める必要があるよ✅

([Node.js][2])

### TypeScript側も `"exports"` を見て解決するよ👀🟦

TypeScriptは `moduleResolution` が `node16` / `nodenext` / `bundler` のとき、基本的に `package.json` の `"exports"` を参照するのが標準寄りになってるよ📦✨

([TypeScript][3])

---

## 9) さらに一段：`@internal` + `stripInternal`（上級だけど便利）🧙‍♀️✨

「export はしてるけど `.d.ts` には出したくない」みたいな時に使えるテクもあるよ🧩
`/** @internal */` を付けて、`tsconfig` の `stripInternal` を使うと、宣言ファイルから隠せることがあるよ🔒
ただし **“内部オプション扱い”** として注意も書かれてるので、使うならチームで合意してね☺️

([TypeScript][4])

---

## 10) 手を動かすミニ演習🧪💖

### 演習A：公開する関数を “3つだけ” 選ぶ🎯

1. 自分の小さいモジュール（例：日付処理、文字列整形）を1つ選ぶ📦
2. 「他の人が使うならこれだけ！」っていう関数を **3つ** 決める✂️✨
3. `public-api.ts` を作って、その3つだけ export する🚪

チェック✅：

* 内部フォルダの関数を直接 import してる箇所がない？🙈
* 入口（public-api.ts）だけ見れば使い方がわかる？🧭

### 演習B：うっかり公開を見つける🔍😳

* `export *` を一度使ってみて、公開されるものが増えすぎないか確認👀
* 増えたら、明示 export に戻す✍️✨

### 演習C：深いimportを禁止してみる（パッケージなら）🚫🧱

* `package.json` に `"exports"` を足す
* 利用側で `your-lib/internal/xxx` みたいな import をしてみて、止まるか確認🧨

---

## 11) AI活用（コピペでOK）🤖💞

* 「このフォルダ構成から、公開API面を最小にする `public-api.ts` を提案して。理由もつけて」🧠
* 「この変更は公開API面に影響ある？ SemVer的にどれ？（理由つき）」🔢
* 「`export *` をやめて、公開面がわかりやすい明示exportに書き換えて」✍️✨
* 「“利用者が困る変更” を3パターン想像して、対策も出して」😱➡️😊

---

## 12) よくある事故あるある🧯💦

### 事故①：内部型を公開しちゃって戻せない😇

* 公開した型は、変更が超むずかしい…
* 対策：公開型は **薄く・安定** を意識（DTOっぽくする）🧾✨

### 事故②：深いパスimportが広まって内部が触れない😵‍💫

* 対策：`package.json` の `"exports"` で入口固定🚪🔒（パッケージなら特に強い）([Node.js][2])

### 事故③：バレル増やしすぎて重い🐢

* 対策：公開入口だけにして、内部は必要最小限に📦⚡([アトラシアン][1])

---

## まとめ🎀✅

* 公開API面は「利用者との約束」🤝
* **入口ファイル（public-api.ts / index.ts）で公開範囲を決める** 🚪
* パッケージなら **`package.json` の `"exports"`** で入口を “強制” できる🧱🔒([Node.js][2])
* 公開面は小さく、内部は自由に🛠️🌈

[1]: https://www.atlassian.com/blog/atlassian-engineering/faster-builds-when-removing-barrel-files?utm_source=chatgpt.com "How We Achieved 75% Faster Builds by Removing Barrel ..."
[2]: https://nodejs.org/api/packages.html?utm_source=chatgpt.com "Modules: Packages | Node.js v25.5.0 Documentation"
[3]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-0.html?utm_source=chatgpt.com "Documentation - TypeScript 5.0"
[4]: https://www.typescriptlang.org/tsconfig/stripInternal.html?utm_source=chatgpt.com "stripInternal - TSConfig Option"
