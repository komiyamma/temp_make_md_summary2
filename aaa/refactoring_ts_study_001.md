## 第1章 リファクタリングとは？（10分で要点）⏱️🛠️

### ねらい🎯

* 「リファクタリング＝何をすること？」を一言で説明できるようになる✨
* 「改修（機能追加）」「バグ修正」と混ざってないか、自分で判定できるようになる✅
* “動作を変えない”ってどこまで？をイメージできるようになる👀

---

### リファクタリングの定義🧠✨

リファクタリングは、**外から見える動作は変えずに**、コードの中身（構造）を整えて、読みやすく・直しやすくすることだよ🧹✨

有名な定義だと、こんな感じ👇（短い引用）

> “a change made to the internal structure of software … without changing its observable behavior.” ([martinfowler.com][1])

つまりポイントはこの2つ🎀

* **中身（内部構造）を良くする**🧩
* **見える動作（observable behavior）を変えない**✅

---

### なんで必要なの？💎（やると得すること）

リファクタリングの良さは、だいたいこのへんに集約されるよ🌸

* **読みやすくなる**📖✨（理解が速い＝作業が速い）
* **変更が安くなる**💰⬇️（直す場所が分かりやすい）
* **バグが入りにくくなる**🛡️（複雑さが減る）
* **機能追加がラクになる**🚀（未来の自分が助かる）

「動作を変えずに内部を整える」っていう前提と、メリットの整理はこの辺が分かりやすいよ🧠✨ ([martinfowler.com][2])

---

### 「リファクタ」vs「改修」vs「バグ修正」🔀🚧

ここ、最初に分けられるとめっちゃ強い💪✨

| 種類       | 目的       | ふるまい（動作）  | 例               |
| -------- | -------- | --------- | --------------- |
| リファクタ🛠️ | 中身を整える   | **変えない**✅ | 変数名改善、関数分割、重複削除 |
| 改修➕      | 新しい価値を足す | **変える**🔁 | 新機能追加、仕様変更      |
| バグ修正🐛   | 間違いを直す   | **変える**🔁 | 期待と違う結果を正しくする   |

⚠️ 注意：実務では「整えるついでに機能も足す」が起きがち。
でも混ざると差分が読めなくなって、レビューも事故りやすいよ🫠💦（第2章で詳しくやるよ！）

---

### “動作を変えない”って、どこまで？🔍

「動作（observable behavior）」って、ざっくり言うと**外から観測できるもの全部**だよ👀

✅ 変えないもの（基本）

* 返り値・出力結果🧾
* 例外の種類やメッセージ（仕様なら）⚠️
* ログやイベント（仕様として見られてるなら）🪵
* APIの入出力（リクエスト/レスポンス）🌐
* DB更新結果（外部に見える）🗃️

🤔 グレーになりやすいもの（要注意）

* パフォーマンス⏱️（「速さ」が仕様扱いのこともある）
* エラーメッセージ文言📝（UIに出てるなら仕様かも）
* ログ形式🧾（運用で解析してるなら仕様かも）

迷ったらこれ👇
**「誰かがそれを見て判断してる？」→YESなら、動作扱いの可能性高い**👀✅

---

### ちょい補足：最近のTypeScript周りの動き🧷🗞️

TypeScriptチームは、今後の大きな方針として **TypeScript 6.0 を“橋渡し”として、TypeScript 7.0（ネイティブ実装）へ進む**計画を説明してるよ🚀（6.0はJavaScript実装ベースの最後のメジャーになる方針、など） ([Microsoft for Developers][3])

※ここは「リファクタそのもの」じゃなくて、**道具（TypeScript）が進化してる**って話だよ🧰✨

---

### コード例（ビフォー/アフター）🧩➡️✨

テーマ：**同じ動作のまま、読みやすくする**💡

#### Before（読むのがつらい🥲）

```typescript
type User = {
  name?: string | null;
  age?: number | null;
  isStudent?: boolean | null;
};

export function buildGreeting(user: User): string {
  if (user && user.name && user.name.trim().length > 0) {
    const n = user.name.trim();
    return "Hi, " + n + "! " + (user.age ? ("You are " + user.age + " years old. ") : "") +
      (user.isStudent ? "Student discount applied." : "");
  } else {
    return "Hi! Guest.";
  }
}
```

#### After（動作は同じ✅ でも読みやすい😍）

```typescript
type User = {
  name?: string | null;
  age?: number | null;
  isStudent?: boolean | null;
};

export function buildGreeting(user: User): string {
  const name = normalizeName(user.name);
  if (!name) return "Hi! Guest.";

  const agePart = buildAgePart(user.age);
  const discountPart = user.isStudent ? "Student discount applied." : "";

  return `Hi, ${name}! ${agePart}${discountPart}`;
}

function normalizeName(name: string | null | undefined): string | null {
  const trimmed = name?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : null;
}

function buildAgePart(age: number | null | undefined): string {
  return age ? `You are ${age} years old. ` : "";
}
```

✅ 何が良くなった？（でも動作は変えてない！）

* 条件がスッキリ（早めにreturn）🚦✨
* 変数名が意味を持つ（`n`→`name`）🏷️
* 文字列の組み立てが見える化👀
* 役割ごとに小さく分けた（normalize / agePart）✂️📦

---

### 手順（小さく刻む）👣🛟

第1章では“感覚”だけ押さえるよ💡
安全にやる基本はこれ👇（第3章でガッツリやる✅）

1. **「何が動作？」を決める**👀（出力・例外・DB更新など）
2. **小さく1個だけ直す**✂️（名前変更だけ、関数抽出だけ、など）
3. **すぐ確認する**✅（同じ入力で同じ結果かチェック）

「小さく変えるほど、事故りにくい」って発想が超大事だよ🧸✨ ([martinfowler.com][2])

---

### ミニ課題：リファクタ？改修？クイズ🧠🎯

次の変更はどれ？（**リファクタ🛠️ / 改修➕ / バグ修正🐛**）

1. 変数名 `a` を `totalPrice` に変えた🏷️
2. ログの形式を JSON から文字列に変えた🪵
3. 「未ログインなら Guest 表示」にした（今まで空文字だった）👤
4. `if` のネストを減らすために早期returnにした🚦
5. 同じ処理が3箇所にあったので関数にまとめた🔁
6. 処理が遅いのでアルゴリズムを変えて2倍速くした⚡

#### 解答＆ちょい解説💡

1. **リファクタ🛠️**（動作そのまま、理解しやすく）
2. **ケース次第⚠️**（ログが仕様・運用で使われてたら“動作”扱いのことある）
3. **改修➕ or バグ修正🐛**（仕様として変わるので“動作が変わる”）
4. **リファクタ🛠️**（同じ条件なら同じ結果になるならOK）
5. **リファクタ🛠️**（共通化で中身を整理）
6. **改修➕（または仕様次第）**（速度が外部要件なら“動作”に入ることも）

---

### AI活用ポイント🤖📝（お願い方＋チェック観点✅）

AIはリファクタ相性めっちゃ良いよ✨
ただし**「提案＝正しい」じゃない**から、必ず自分で確認しようね🧷✅
（Copilotでも“リファクタ提案”の考え方が整理されてるよ） ([GitHub Docs][4])

#### 使えるお願いテンプレ🪄

* 「この関数、**動作を変えずに**読みやすくして。変更点の理由も3行で」🤖
* 「これはリファクタ？改修？バグ修正？**根拠**も教えて」🧠
* 「“外から見える動作”が変わってないか、**確認リスト**作って」✅
* 「差分をレビューして。**危ない変更**（仕様が変わりそう）を指摘して」👀⚠️

#### AIの回答を採用する前の最終チェック✅🛟

* 入力と出力、同じ？🧾
* 例外の出方、変わってない？⚠️
* 名前や分割で、読みやすくなった？📖✨
* 「今後直しやすい形」になった？🧩🌱

[1]: https://martinfowler.com/bliki/DefinitionOfRefactoring.html?utm_source=chatgpt.com "Definition Of Refactoring"
[2]: https://martinfowler.com/tags/refactoring.html?utm_source=chatgpt.com "tagged by: refactoring"
[3]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
[4]: https://docs.github.com/en/copilot/tutorials/refactor-code?utm_source=chatgpt.com "Refactoring code with GitHub Copilot"
