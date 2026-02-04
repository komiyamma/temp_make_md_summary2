# 第15章：依存の向きと契約（崩れない土台）🧱🧭

## この章でやること 🎯✨

* 「契約（= 利用者との約束）」が**壊れにくい構造**を作れるようになるよ🙂💪
* 依存関係を **“外→内”** に揃えて、変更に強い設計にするよ🔁🏗️
* TypeScriptの `import` 地獄（循環・境界あいまい）を減らすコツもやるよ🌀➡️🌈

---

## 15.1 まず超ざっくり：依存の向きってなに？🧭

**依存**っていうのは、かんたんに言うと👇
「AがBを使う（importする / 呼び出す）＝ AはBに依存してる」だよ📦➡️📦

で、契約を守りやすい形はこれ👇✨

* **内側（変えたくない“約束”や“方針”）**
  例：公開APIの型、ドメインルール、使い方の約束、エラー形式 など
* **外側（変わりやすい“都合”や“実装”）**
  例：DB、HTTP、UI、ライブラリ、フレームワーク、ログ、キャッシュ など

💡大事なのはこれだけ👇
**外側が内側に依存する（外→内）**
**内側は外側を知らない（内→外 は禁止）** 🙅‍♀️

---

## 15.2 なんで「外→内」がいいの？😌✨

## ☠️ ありがちな崩れ方

内側（契約）に外側の都合が入り込むと…

* DB都合の型がそのまま公開APIに出ちゃう😵‍💫
* UI都合で、ドメインルールがねじ曲がる😱
* ライブラリ変更で、コアが壊れて全部修正になる💥

## 🌟 「外→内」にするとこうなる

* 仕様（契約）が安定する📜✨
* DBやUIを変えても、**コアが巻き込まれにくい**🛡️
* テストしやすい（外側なしで内側だけテストOK）🧪💖

---

## 15.3 ルールは1つだけ：内側に “ルール（契約）” を置く📌

この章の合言葉は👇
**「契約は内側。実装は外側。」** 🧡

イメージ図（ざっくり）👇

* 外側（UI / DB / HTTP）
  ↓ 依存
* 内側（UseCase / Domain / Public Types）

---

## 15.4 TypeScriptでの「内側・外側」の切り分け例 🗂️✨

フォルダ構成の一例だよ👇（小さく始めてOK🙆‍♀️）

```text
src/
  domain/        # いちばん内側（ルール・型）
  app/           # ユースケース（何をするか）
  ports/         # 境界（interface：外に要求する口）
  adapters/      # 外側の実装（DB/HTTPなど）
  main/          # 組み立て（DI：配線）
```

* `domain/`：**意味・ルール・型**（なるべく純粋に）🧠✨
* `ports/`：**内側が外側にお願いする契約**（interface）📨
* `adapters/`：**お願いを叶える実装**（DBとか）🧰
* `main/`：最後に **配線する場所**（どれを使うか決める）🔌

---

## 15.5 具体例：Repository（口）を内側に置いて逆転する🔁💖

## ① 内側：契約（interface）を定義する📜

「保存してね」っていう“お願い”だけを書くよ👇

```ts
// src/ports/TodoRepository.ts
export type TodoId = string;

export type Todo = {
  id: TodoId;
  title: string;
  createdAt: Date;
};

export interface TodoRepository {
  save(todo: Todo): Promise<void>;
  findById(id: TodoId): Promise<Todo | null>;
}
```

ここでは **DBの種類の話ゼロ**！🙈✨
これが「内側が外側を知らない」だよ🧠🧡

---

## ② 内側：ユースケース（やること）を書く🧩

```ts
// src/app/createTodo.ts
import type { TodoRepository, Todo } from "../ports/TodoRepository.js";

export async function createTodo(
  repo: TodoRepository,
  title: string,
): Promise<Todo> {
  const todo: Todo = {
    id: crypto.randomUUID(),
    title,
    createdAt: new Date(),
  };

  await repo.save(todo);
  return todo;
}
```

ポイント👇✨

* `repo` を引数でもらう＝**依存を注入（DI）** 💉
* ユースケースは DB知らない＝強い💪🌈

---

## ③ 外側：DB実装（adapter）を書く🗄️

```ts
// src/adapters/SqlTodoRepository.ts
import type { TodoRepository, Todo, TodoId } from "../ports/TodoRepository.js";

export class SqlTodoRepository implements TodoRepository {
  async save(todo: Todo): Promise<void> {
    // ここでSQL実装（例）
  }

  async findById(id: TodoId): Promise<Todo | null> {
    // ここでSQL実装（例）
    return null;
  }
}
```

ここは外側なので、DB都合があってOK🙂🧰

---

## ④ いちばん外：配線（composition root）🔌

```ts
// src/main/main.ts
import { createTodo } from "../app/createTodo.js";
import { SqlTodoRepository } from "../adapters/SqlTodoRepository.js";

const repo = new SqlTodoRepository();

const todo = await createTodo(repo, "牛乳買う🥛");
console.log(todo);
```

ここで初めて「どの実装を使うか」を決めるよ🎀

---

## 15.6 ミニ演習：依存が逆向きになってる場所を探そう🔍🧯

## ✅ チェックしてほしい“やばい匂い”リスト

次があったら、依存の向きが崩れてる可能性高めだよ😵‍💫

* `domain/` や `app/` の中から `adapters/` を `import` してる🙅‍♀️
* `domain/` の型がDBのカラム名に引っ張られてる（`created_at` とか）😇
* `domain/` がHTTPステータス（200/404）を知ってる😱
* 内側で “便利ライブラリ” を直importして、そこが変わると全部崩れる💥

## ✍️ やること（10〜15分）

1. 自分のプロジェクトで `domain/` 相当の場所を決める🧠
2. その中の `import` を眺める👀
3. **「外側っぽいもの」を引っこ抜いて、ports（interface）に変換**してみる🔁✨

---

## 15.7 リファクタ手順：やさしい4ステップ🪜😊

## Step1：境界線を引く🖊️

「ここから内側」って線を引くだけで勝ち✨
（domain/app/ports を“内側”にするのがやりやすいよ🙆‍♀️）

## Step2：外側参照を見つける🔍

内側で外側を `import` してたら赤信号🚨

## Step3：interface にして逆転する🔁

内側：`interface`（お願い）
外側：`implements`（実装）
→ 依存が **外→内** になる🎉

## Step4：配線を1か所に集める🔌

「new する場所」を `main/` に寄せるとスッキリするよ🧼✨

---

## 15.8 2026っぽい注意点：import周りで契約が崩れやすい😵‍💫📦

最近のNodeは **ESM / CJS 混在**が前提になってて、`package.json` の `"exports"` とかで「どこを公開するか」を強くコントロールできるよ📦🚪（逆に言うと、設定ミスると利用者が即死しがち…！）([nodejs.org][1])

さらに、TypeScript側も `moduleResolution` に `node16` / `nodenext` みたいな **“Nodeの解決ルール再現モード”** があって、ESM/CJSや `"exports"` の影響を受けやすいの🥺([typescriptlang.org][2])
フロント寄りだと `bundler`（バンドラ挙動）で拡張子省略がしやすくなる、みたいな違いもあるよ🧩([Speaker Deck][3])

✅ つまりね：
**「公開する入口（exports）」「境界のimport」「依存の向き」** を揃えると、契約が崩れにくいよ🙂💖

---

## 15.9 ちいさなチェックリスト✅✨（これだけ守ると強い）

* 内側は外側を import しない🙅‍♀️
* 外側の都合は adapter に閉じ込める🧰
* 境界は interface（ports）で表現する📜
* “どれを使うか” は main で決める🔌
* 循環依存（A→B→A）を作らない🌀🚫

---

## 15.10 AI活用プロンプト集🤖💡（コピペOK）

* 「このプロジェクトの依存関係を“内側/外側”に分けて、危ない import を指摘して」🔍
* 「domain層がDBに依存してるので、ports（interface）に分離する手順を提案して」🪜
* 「このクラスをDIPっぽくリファクタして。interfaceと配線場所も含めて」🔁
* 「循環依存が起きそうな import を見つける観点を箇条書きにして」🌀
* 「公開API（exports）を最小化したい。入口設計の案を出して」📦🚪

---

## 15.11 おまけ：最新バージョン感（さらっと）🗓️✨

* TypeScriptはGitHubのリリース上、**5.9.2（Stable）** が確認できるよ（2025-10頃の情報として表示）([GitHub][4])
* Node.jsは **v24 が Active LTS / v25 が Current** になってるよ（ページ上の最終更新日も2026-02-02/03の情報が載ってる）([nodejs.org][5])
* それと、Microsoft が「TypeScriptのネイティブ実装（プレビュー）」を発表してて、将来的にコンパイル体験がかなり変わりそう…！って流れもあるよ⚡([Microsoft Developer][6])

---

## 🌸 この章のまとめ

**契約（守りたい約束）を内側に置いて、外側の都合を外に隔離する。**
そのために **依存を “外→内” に揃える**。これが「崩れない土台」だよ🧱🧡

[1]: https://nodejs.org/api/packages.html?utm_source=chatgpt.com "Modules: Packages | Node.js v25.5.0 Documentation"
[2]: https://www.typescriptlang.org/tsconfig/moduleResolution.html?utm_source=chatgpt.com "TSConfig Option: moduleResolution"
[3]: https://speakerdeck.com/uhyo/tsconfig-dot-jsonnoshe-ding-wojian-zhi-sou-hurontoendoxiang-ke-2024xia?utm_source=chatgpt.com "tsconfig.jsonの設定を見直そう！ フロントエンド向け 2024夏"
[4]: https://github.com/microsoft/typescript/releases?utm_source=chatgpt.com "Releases · microsoft/TypeScript"
[5]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[6]: https://developer.microsoft.com/blog/typescript-7-native-preview-in-visual-studio-2026?utm_source=chatgpt.com "TypeScript 7 native preview in Visual Studio 2026"
