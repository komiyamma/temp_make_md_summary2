# 第11章：段階的に変える（移行設計）🪜⏳

## ねらい 🎯✨

一気に変更して「うわ、壊れた…😱」を避けつつ、**古い使い方（旧）→新しい使い方（新）**へ、利用者をやさしく移動させる設計ができるようになるよ🧡
ポイントは **旧新併存・段階リリース・最後に片づけ** までをセットで考えること！🧹✨

---

## 11-1. なんで“一気に変える”と事故るの？😵‍💫💥

「契約（Contract）」って、利用者との約束だよね🤝
ここを急に変えると、こんな事故が起きがち👇

* **ビルドが落ちる**（関数名変えた／引数減らした など）🧱💣
* **実行時に落ちる**（JSONの形が変わってパース失敗 など）💥🏃‍♀️
* **挙動が変わってバグる**（意味を変えたのに型は通る など）😇→😱

だから、移行設計は **「壊さずに変える技」** なんだ〜🪄✨

---

## 11-2. 段階移行の“道具セット”🧰🌈

段階移行でよく使う道具はこの3つ＋おまけ1つだよ👇

## ① 旧新併存（両方動く期間を作る）🧑‍🤝‍🧑🔁

* 新APIを追加して、旧APIも当面残す
* 利用者が自分のタイミングで移行できる💗

## ② 互換レイヤ（変換・ラッパー）🧩🔧

* 旧APIを残しつつ、中身は新APIへ誘導（内部で呼び替え）
* 利用者側の変更を小さくできる✨

## ③ フラグ（段階リリース／切り戻し）🚦🎚️

* 新旧の挙動を切り替えられる
* でもフラグは放置すると“負債”になるから、**片づけ計画が必須**🧹
  使い終わったフラグは削除しよう、ってベストプラクティスでも言われてるよ🧼✨ ([LaunchDarkly][1])

## おまけ：計測（何人が旧を使ってる？）📈👀

* 「旧がまだ何割いるか」が分かると、廃止の判断ができる！

---

## 11-3. 4ステップ移行テンプレ 🗺️✨（これ覚えるだけで強い！）

移行設計は、だいたいこの **4ステップ** で安定するよ👇

## Step 1：新を追加（旧は残す）➕🆕

* 新API／新フォーマットを追加
* 旧もそのまま動く状態にする

## Step 2：旧に“非推奨”を付ける 🚧📣

* コード上で「そろそろ新にしてね🙏」が見えるようにする
* TypeScript は **@deprecated** を型システムで扱えて、エディタで警告（取り消し線など）を出せるよ ([TypeScript][2])

## Step 3：新をデフォルトに寄せる 🎛️➡️🆕

* 可能なら「何もしない人は新を使う」方向へ
* 旧を使う人だけ明示的に旧を選ぶ（or フラグで段階切替）

## Step 4：旧を削除（ここが“MAJOR”になりやすい）🗑️🚀

* 期限・移行率・告知が整ったら削除
* TypeScript自体も、将来のメジャーで非推奨の削除を計画する流れがあるよ（例：次期メジャーで削除） ([Microsoft for Developers][3])

---

## 11-4. 例①：関数APIを段階移行してみよう（旧→新）🧁🧩

ここでは「日付フォーマット関数」を例にするね📅✨

## 目標 🎯

* 旧：formatDate(date)
* 新：formatDate(date, options)（オプション追加）
* 旧呼び出しは壊さず、新へ誘導する💞

### Step 1：新しい形を追加 ➕

```ts
export type DateFormatStyle = "short" | "long";

export type FormatOptions = {
  style?: DateFormatStyle;
  locale?: string;
};

export function formatDate(date: Date, options: FormatOptions = {}): string {
  const { style = "short", locale = "ja-JP" } = options;

  // 例：雑に実装（本物はIntl.DateTimeFormatなどに置き換えてOK）
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");

  if (style === "long") return `${y}年${m}月${d}日 (${locale})`;
  return `${y}-${m}-${d}`;
}
```

### Step 2：旧APIを残しつつ非推奨にする 🚧

旧シグネチャの“入口”を残して、中で新へ流すよ〜🔁✨
（@deprecated は VS Code などで目立つ形で出てくれる）([TypeScript][2])

```ts
/**
 * @deprecated 新しい formatDate(date, options) を使ってね✨
 * 例: formatDate(date, { style: "long" })
 */
export function formatDateV1(date: Date): string {
  return formatDate(date, { style: "short" });
}
```

### Step 3：新をデフォルトに寄せる 🎛️

* 新しい呼び方をドキュメントやサンプルで優先する📚✨
* 新機能は新APIにだけ追加（旧に追加しない）🚫🍰

### Step 4：削除 🗑️

* 次のメジャーで formatDateV1 を消す
* 消す前に「移行率が十分か」を計測して判断📈

---

## 11-5. 例②：JSONフィールド名変更の段階移行（データ契約）🧾🧬

## 状況 😵‍💫

* 旧：userName
* 新：displayName
  「名前が分かりやすいから変えたい！」ってやつ😊

## やっちゃダメ例 🙅‍♀️

* いきなり userName を消す → 古いクライアントが即死😱💥

## 安定ルート（段階移行）🪜✨

### Step 1：出力は両方返す（併存）📤

```ts
type UserResponse = {
  id: string;
  displayName: string;
  userName?: string; // 旧も残す（当面）
};

function toResponse(u: { id: string; displayName: string }): UserResponse {
  return {
    id: u.id,
    displayName: u.displayName,
    userName: u.displayName, // 旧クライアント救済
  };
}
```

### Step 2：入力は両方受ける（正規化）📥

```ts
type UserInput = {
  displayName?: string;
  userName?: string;
};

function normalizeUserInput(input: UserInput): { displayName: string } {
  const name = input.displayName ?? input.userName ?? "";
  if (!name) throw new Error("displayName が必要だよ💦");
  return { displayName: name };
}
```

### Step 3：新だけを推奨にする 📣✨

* ドキュメントは displayName をメインに
* userName は「古い互換用」扱いに

### Step 4：旧を削除 🗑️

* 期限を決めて、十分に移行されたら userName を廃止

---

## 11-6. フラグで安全に切り替える（でも片づけ必須！）🚦🧹

「新ロジックをちょっとずつONにしたい」って時はフラグが便利💡
ただし放置すると分岐が増えて地獄になるから、フラグの寿命を決めようね🪦😂
フラグは“ライフサイクル管理”や“削除”が大事ってガイドでも強調されてるよ ([LaunchDarkly][1])

```ts
type Flags = {
  useNewCalc: boolean;
};

export function calcPrice(base: number, flags: Flags): number {
  if (flags.useNewCalc) {
    // 新しい計算
    return Math.ceil(base * 1.1);
  }

  // 旧の計算（互換用）
  return Math.round(base);
}
```

## フラグ運用のコツ 🎀

* フラグ名は意味が分かるようにする📝
* 「いつ消すか」を最初に決める🗓️
* フラグを消す作業をタスク化（四半期ごとでもOK）🧹✨ ([Harness Developer Hub][4])

---

## 11-7. “移行が終わった！”の判断材料 📊👀

段階移行って、「気持ち」じゃなくて「数字」で終わらせると強い💪✨

* 旧APIの呼び出し回数（ログ・メトリクス）📈
* 旧の利用者（バージョン別ユーザー割合）👥
* 旧の利用箇所がリポジトリ内に残ってないか（参照検索）🔍
* 旧を使う利用者向けに移行ガイドが揃ってるか📚

---

## 11-8. ミニ演習 📝🌸（Step1〜Step4を書いてみよ！）

あなたの過去コードから、こういうのを1個選んでね👇

* 関数の引数を増やしたい
* 返り値の形を変えたい
* JSONのフィールド名を変えたい

そして、**4ステップ移行プラン**を書こう🪜✨

## テンプレ（コピペして埋める用）🧡

* Step1（追加）：新しい〇〇を追加する（旧は残す）➕
* Step2（非推奨）：旧〇〇に非推奨を付ける🚧（代替も書く）
* Step3（寄せる）：ドキュメント・サンプル・デフォルトを新へ🎛️
* Step4（削除）：期限/条件を決めて旧〇〇を削除🗑️（メジャー想定）

---

## 11-9. 段階移行チェックリスト ✅🧁

* [ ] 旧の利用者が今日も動く（互換がある）🧸
* [ ] 新への移行方法が1行で言える（例もある）🧾✨
* [ ] 旧には非推奨が付いてる（気づける）🚧
* [ ] 新旧の差がテストできる（最低1つでOK）🧪
* [ ] フラグを使ったなら、削除予定日がある🗓️🧹 ([LaunchDarkly][1])
* [ ] 旧を消す条件が“数字”で言える📈

---

## 11-10. AI活用プロンプト集 🤖💖（そのまま投げてOK）

※ GitHub の Copilot や OpenAI 系のAI補助を「レビュー係」にすると超ラクだよ〜🧁✨

## ① 段階移行プランを作らせる 🗺️

* 「このAPI変更を、Step1〜Step4の段階移行プランにして。利用者影響と計測案も入れて🙏」

## ② 非推奨コメントを“やさしく”整える 🚧

* 「この非推奨コメントを、短くて親切な文章にして。代替APIの例も1つ入れて🌸」

## ③ 互換レイヤ（ラッパー）を書かせる 🔧

* 「旧APIを残したまま、新APIへ内部で流すラッパー関数を書いて。型も付けて✨」

## ④ JSONの正規化関数を作る 🧾

* 「旧フィールド userName と新フィールド displayName を両対応する正規化関数を書いて。入力バリデーションも入れて⚠️」

## ⑤ フラグの片づけ計画を作る 🧹

* 「この機能フラグのライフサイクル（作成→展開→安定→削除）を、作業項目のチェックリストにして✅」 ([LaunchDarkly][1])

---

## おまけ：npmパッケージの“入口”を変える時の段階移行 📦🚪

もし「importのパス」みたいな入口を変えるなら、package.json の exports を使って旧入口を残す戦もあるよ✨
Node.js では main と exports が入口を定義できて、exports はより細かく公開面を制御できるんだ〜 ([Node.js][5])

（この話は後ろの章でガッツリやると最強🧠🔥）

---

[1]: https://launchdarkly.com/docs/guides/flags/technical-debt?utm_source=chatgpt.com "Reducing technical debt from feature flags"
[2]: https://www.typescriptlang.org/play/4-0/new-js-features/jsdoc-deprecated.ts.html?utm_source=chatgpt.com "Playground Example - JSDoc Deprecated"
[3]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
[4]: https://developer.harness.io/docs/feature-flags/get-started/feature-flag-best-practices?utm_source=chatgpt.com "Best practices for managing flags"
[5]: https://nodejs.org/api/packages.html?utm_source=chatgpt.com "Modules: Packages | Node.js v25.5.0 Documentation"
