# 第12章：Deprecation（非推奨）を上手に出す🚧📣

## この章のゴール🎯✨

* 「非推奨＝利用者に優しい“卒業予告”」だと理解する🤝🌸
* **告知→移行案内→期限→削除**の流れを、迷わず組み立てられるようになる🪜⏳
* TypeScriptで **@deprecated** を付けて、VS Code上で気づける形にできる🟦👀
* チームやCIで「非推奨の使い続け」を検知して止められる✅🧪

---

## 12.1 Deprecationってなに？🤔💭

Deprecation（非推奨）は、ざっくり言うと…

* **今すぐ壊す（破壊的変更）じゃない**🙅‍♀️💥
* でも **将来は消す予定**だから、
* **今のうちに“こっちに移ってね”を案内する**📣➡️✨

つまり「契約（Contract）」の観点だと、
**“利用者との約束を、壊さずに更新するための儀式”**なんだよね🧾🌸

---

## 12.2 非推奨の王道フロー：4ステップ🪜⏳

非推奨は「付けて終わり」じゃなくて、運用の流れが大事〜！😊🧡

1. **告知（知らせる）**📣
2. **移行案内（代替手段を用意する）**🗺️✨
3. **期限（いつまでに移ってね）**📅
4. **削除（きれいに卒業）**🧹🎓

> npmパッケージの場合、npmレジストリ側でも「このバージョン非推奨だよ」ってインストール時にメッセージを出せるよ📦⚠️ ([npm ドキュメント][1])

---

## 12.3 非推奨にする“よくある理由”あるある🧠✨

* もっと良いAPIを作った（設計を改善した）🛠️🌟
* セキュリティや事故の温床だった（危険だから卒業）🧯⚠️
* 名前が分かりにくい／意味がズレた（誤解される）😵‍💫🌀
* 仕様や外部都合で維持が難しい（依存先が変わった等）🔁📦

---

## 12.4 “良い非推奨メッセージ”のテンプレ🍰📝

非推奨コメントは、**読む人が行動できる**のが正解だよ🧡

✅ だいたいこの3点セットでOK👇

* **何が非推奨？**（この関数/プロパティだよ）
* **代わりは何？**（これ使ってね）
* **いつ消える？**（目安でいいから期限）

例（文章の型）👇

* 「`oldX` は非推奨です。代わりに `newX` を使ってください。`v3.0.0` で削除予定です。」📣✨

---

## 12.5 TypeScriptで非推奨を出す：@deprecated を付けよう🟦🚧

TypeScriptは **JSDocの `@deprecated`** を理解して、VS Codeなどで警告表示してくれるよ👀✨ ([TypeScript][2])

### 12.5.1 関数を非推奨にする🧩

```ts
/**
 * 旧API：次のメジャーで削除予定
 * @deprecated 代わりに `formatPrice()` を使ってね。v3.0.0 で削除予定。
 */
export function formatMoney(amount: number): string {
  return `${amount}円`;
}

export function formatPrice(amount: number): string {
  return `${amount.toLocaleString("ja-JP")}円`;
}
```

### 12.5.2 メソッドを非推奨にする🧸

```ts
export class UserService {
  /**
   * @deprecated 代わりに `getUserById()` を使ってね。v2.5.0 で削除予定。
   */
  getUser(id: string) {
    return this.getUserById(id);
  }

  getUserById(id: string) {
    return { id, name: "Sakura" };
  }
}
```

### 12.5.3 プロパティを非推奨にする（データ契約っぽいやつ）🧾

```ts
export interface AccountInfo {
  name: string;

  /** @deprecated 代わりに `gender` を使ってね。v3.0.0 で削除予定。 */
  sex?: "male" | "female";

  gender?: "male" | "female" | "other";
}
```

TypeScriptは `@deprecated` を理解するけど、**実行を止めたりはしない**（＝“気づけるようにする”が役目）だよ🙂✨ ([TypeScript][2])

> ちなみに、打ち消し線が付く/付かないなど表示はケースによって差が出ることがあるので、「表示されてるか」だけに頼らないのが安全だよ🧯 ([GitHub][3])

---

## 12.6 “実行時”にも気づかせたい時（ライブラリ向け）🔔🖥️

型やエディタ警告は便利だけど、利用者がJSで使ってたり、警告を見てなかったりもするよね😵‍💫
そういうときは「実行時に1回だけ警告」もアリ！

Node.jsにはデプリケーションの仕組み（警告の出し方、フラグで例外化など）があるよ🟩⚠️ ([Node.js][4])

例（やりすぎ注意！）👇

```ts
let warned = false;

/**
 * @deprecated 代わりに `newApi()` を使ってね。v3.0.0 で削除予定。
 */
export function oldApi() {
  if (!warned) {
    warned = true;
    // 本番で大量に出ると辛いので、出し方はチームで相談してね🙂
    console.warn("[DEPRECATED] oldApi() -> use newApi(). Will be removed in v3.0.0");
  }
}
```

---

## 12.7 npmパッケージの非推奨：レジストリでも警告を出せる📦📣

パッケージ配布してる場合、npmには **インストール時に非推奨メッセージを表示**させる仕組みがあるよ📦⚠️ ([npm ドキュメント][1])

### 12.7.1 コマンド例（特定バージョンや範囲に出せる）🧾

```bash
npm deprecate my-lib@"< 2.3.0" "重大バグあり。v2.3.0以上へ更新してね🙏"
```

これをやると、対象バージョンを入れようとした人のターミナルにメッセージが出るよ👀✨ ([npm ドキュメント][5])

---

## 12.8 “非推奨を使ってたら警告/エラー”を自動化する✅🧪

「見落とし」を防ぐには、**ルールで検知して止める**のが強い🔥

### 12.8.1 ESLint（TypeScript ESLint）の no-deprecated 🧯

`@deprecated` が付いたAPIの参照を検知するルールがあるよ✅
ただし **型情報が必要**だから設定は少しだけ本格的（でも効果大！）💪✨ ([TypeScript ESLint][6])

### 12.8.2 eslint-plugin-deprecation（別プラグイン）もある🧩

「非推奨利用をレポートする」専用プラグインもあるよ🧪✨ ([GitHub][7])

> どっちを使うかは、プロジェクトのESLint構成次第でOK〜😊
> 大事なのは「CIで拾える形」にすることだよ🚦💥

---

## 12.9 よくある失敗パターン集😱🧯

### 失敗1：代替がない（移行先ゼロ）🙅‍♀️

「非推奨です」って言われても、行き先がなかったら詰む…😭
➡️ **先に代替APIを作る**🛠️✨

### 失敗2：期限がなくて永久に放置🕰️🫠

ずっと残って、コードが古い/新しいで二重管理に…
➡️ **削除予定（目安）を書く**📅✨

### 失敗3：メッセージが雑で何すればいいか不明😵‍💫

「deprecated」だけだと、利用者が迷子になるよ🌀
➡️ **代替＋期限＋リンク（移行ガイド）**🗺️📎

### 失敗4：非推奨のまま“内部で使い続ける”🧟‍♀️

作った本人たちが使い続けると、永遠に消えないあるある…
➡️ **内部利用を先に置換**してから外部へ告知が安全🙂✅

---

## 12.10 ミニ演習📝🌸

### 演習A：非推奨コメントを作る（3点セット）🧁

次の条件で、`@deprecated` コメントを書いてみよう✨

* 旧：`getUser()`
* 新：`getUserById()`
* 削除予定：`v2.5.0`

✅ 期待する形

* 「代替」＋「期限」が入ってること📣📅

### 演習B：4ステップ計画を書く🗓️🪜

`v2.2.0` で非推奨を出すとして…

* いつ告知？
* いつ移行ガイド公開？
* いつ利用率を見る？（雑でOK）
* いつ削除？

---

## 12.11 AI活用プロンプト例🤖✨

そのままコピペで使えるやつ〜！💖

* 「この関数を非推奨にしたい。**代替API案**と、**移行手順（利用者向け）**を作って」🗺️
* 「既存コードから `oldApi()` を探して、`newApi()` に置換するPR案を出して（注意点も）」🔍🔁
* 「非推奨メッセージを、**短くて優しい文章**にして。期限と代替を必ず入れて」🌸🧾
* 「削除予定バージョンを決めたい。影響が大きい契約なので、**段階移行の案**を3パターン出して」🪜✨

---

## 12.12 まとめ🎀✅

* 非推奨は「壊さずに契約を更新する」ための礼儀🤝🌸
* **告知→移行→期限→削除**の流れが超大事🪜⏳
* TypeScriptの `@deprecated` はVS Codeでも気づける形にできるよ🟦👀 ([TypeScript][2])
* 見落とし防止には **ESLint/CIで検知**が強い✅🧪 ([TypeScript ESLint][6])
* npm配布なら `npm deprecate` でインストール時警告も出せる📦📣 ([npm ドキュメント][5])

（参考）本日時点で npm 上の TypeScript 最新安定版は **5.9.3** と表示されているよ🟦✨ ([npmjs.com][8])

[1]: https://docs.npmjs.com/deprecating-and-undeprecating-packages-or-package-versions/?utm_source=chatgpt.com "Deprecating and undeprecating packages or ..."
[2]: https://www.typescriptlang.org/ja/play/4-0/new-js-features/jsdoc-deprecated.ts.html?utm_source=chatgpt.com "プレイグラウンド 例 - JSDoc Deprecated"
[3]: https://github.com/microsoft/TypeScript/issues/39374?utm_source=chatgpt.com "@deprecated strikethrough doesn't appear in many cases ..."
[4]: https://nodejs.org/api/deprecations.html?utm_source=chatgpt.com "Deprecated APIs | Node.js v25.5.0 Documentation"
[5]: https://docs.npmjs.com/cli/v8/commands/npm-deprecate/?utm_source=chatgpt.com "npm-deprecate"
[6]: https://typescript-eslint.io/rules/no-deprecated/?utm_source=chatgpt.com "no-deprecated"
[7]: https://github.com/gund/eslint-plugin-deprecation?utm_source=chatgpt.com "gund/eslint-plugin-deprecation: ESLint rule that reports ..."
[8]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "typescript"
