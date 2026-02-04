# 第7章：SemVer（X.Y.Z）をやさしく理解する🔢✨

## この章でできるようになること🎯✨

* **MAJOR / MINOR / PATCH** を見て「何が起きそうか」を説明できる🙂📣
* 変更内容から「どの番号を上げる？」を**自分で判定**できる🧠✅
* **TypeScriptライブラe**（型も契約！）で、破壊変更をうっかり混ぜないコツが分かる🟦⚠️
* npm の **^ / ~** の意味を理解して、事故りにくい依存指定ができる📦🧯

---

## 7.1 SemVerってなに？🤝🔢

SemVer（Semantic Versioning）は、バージョン番号 **X.Y.Z** に「変更の意味」を入れるルールだよ✨
利用者は番号を見るだけで、だいたいこう予測できるようになる💡

* **X（MAJOR）**：大きめに壊れるかも…！😱
* **Y（MINOR）**：機能増えそう！でも基本は壊さないはず😊
* **Z（PATCH）**：バグ直し中心で安心寄り🩹✨

SemVer の仕様は「**公開API（Public API）**がどう変わったか」で判断するのがポイントだよ🚪✨ ([Semantic Versioning][1])

---

## 7.2 まず覚える3ルール📏🌈

SemVerの超基本はこれだけでOK👇✨（**1.0.0以降**の話ね）

* **PATCH（x.y.Z）**：公開APIはそのまま、**後方互換なバグ修正**🩹
* **MINOR（x.Y.0）**：公開APIに**後方互換な機能追加**✨

  * さらに大事！**非推奨（Deprecated）を付けたら MINOR** にするのがルール🛟
* **MAJOR（X.0.0）**：公開APIに**後方互換のない変更（破壊変更）**😱💥

この「非推奨は MINOR」って意外と忘れがちだから要注意だよ〜！🚧✨ ([Semantic Versioning][1])

---

## 7.3 “公開API（Public Surface）”が分かると、判定が激ラク🎭🚪

SemVerは「利用者に約束してる部分＝公開API」が変わったかで決めるよ📌
たとえば TypeScript のライブラリなら、だいたいこのへんが公開APIになりがち👇

* export してる **関数 / クラス / 型 / 定数** 🟦📤
* 公開してる **JSONの形**（DTO）🧾
* 公開APIの **振る舞い（意味）** 🧠
* “動く”だけじゃなくて、**型としての約束**も含まれることが多い✨

「公開APIが変わったか？」の問いに答えられると、SemVerが一気に簡単になるよ🙂🎀 ([Semantic Versioning][1])

---

## 7.4 迷ったらこれ！判定フロー🧭✨

変更を見たら、順番にこれだけ聞けばOKだよ👇😺

1. **利用者のコードが壊れる？**（ビルド失敗、実行時エラー、意味が変わって動作が変になる…）
   → Yes なら **MAJOR** 😱💥

2. 壊れないけど、**新しい機能が増えた？**
   → Yes なら **MINOR** ✨🎁

3. 機能追加じゃなくて、**バグ修正だけ？**
   → Yes なら **PATCH** 🩹✅

「壊れる」の考え方は「利用者が修正を要求される可能性がある変更」って捉えると判断しやすいよ👀✨ ([Livefront][2])

---

## 7.5 TypeScriptでよくある変更パターン集🧩🟦

### A. これは PATCH 🩹✨（だいたい安全）

* 内部処理の修正で、公開APIの入出力は同じ
* バグってた挙動を “仕様通り” に戻す（※ただし利用者がバグに依存してたら難しい😵‍💫）

例（内部だけ修正）👇

```ts
// export されてる関数のシグネチャはそのまま
export function parseId(input: string): number {
  // バグ: "001" が 1 にならない…などを修正するイメージ
  return Number.parseInt(input, 10);
}
```

SemVer的には「後方互換なバグ修正」は PATCH 🩹 ([Semantic Versioning][1])

---

### B. これは MINOR 🎁✨（増やす・広げる）

* **新しい export を追加**（既存はそのまま）
* **任意パラメータ**を追加（デフォルト値あり）
* 既存機能に **@deprecated を付ける**（“次で消すよ”の予告）🚧

例（任意パラメータ追加）👇

```ts
export function greet(name: string, options?: { emoji?: boolean }) {
  const mark = options?.emoji ? "✨" : "";
  return `Hello, ${name}${mark}`;
}
```

「非推奨を付けたら MINOR」は仕様に明記されてるよ📌 ([Semantic Versioning][1])

---

### C. これは MAJOR 😱💥（壊れる）

* 引数を **必須で追加**（呼び出し側が全修正になる）
* 戻り値の型を変える（string→number など）
* export の削除 / 名前変更
* 既存の意味が変わる（同じ引数なのに結果が別物）

例（必須引数追加＝壊れる）👇

```ts
// 旧: greet(name: string)
// 新: greet(name: string, lang: "ja" | "en") ← 必須が増えた！
export function greet(name: string, lang: "ja" | "en") {
  return lang === "ja" ? `こんにちは ${name}` : `Hello, ${name}`;
}
```

公開APIに後方互換のない変更が入ったら MAJOR 必須だよ😱 ([Semantic Versioning][1])

---

## 7.6 0.y.z（0系）ってどう扱うの？🧪🌀

SemVerでは **0.y.z は「初期開発」**扱いで、公開APIは安定してない前提だよ⚠️
つまり「なんでも変わり得る」ゾーン😵‍💫 ([Semantic Versioning][1])

でも実務では、0系でも “それっぽく” 運用したいよね？🙂
npm の世界では **0.x の x を「壊れる番号」扱い**する文化がよくあるよ📦✨ ([npm ドキュメント][3])

おすすめ感覚（0系のとき）👇

* **0.2.3 → 0.2.4**：PATCHっぽい🩹
* **0.2.3 → 0.3.0**：MAJORっぽい（壊れる可能性強）😱

---

## 7.7 package.json の ^ と ~ を理解しよ📦🔧

ここ、超事故ポイント！😇💥
npm の範囲指定は、だいたいこう覚えるとOKだよ👇

* **~1.2.3**：1.2 の中で更新OK（パッチ中心）🩹

  * 例：>=1.2.3 かつ <1.3.0
* **^1.2.3**：1 の中で更新OK（マイナー＋パッチ）🎁🩹

  * 例：>=1.2.3 かつ <2.0.0

しかも **0系は挙動が違う**のが罠！🕳️

* **^0.2.3** は <0.3.0 まで（0.x は “x を壊れ番号扱い” みたいな感覚）
* **^0.0.3** は <0.0.4 まで（ほぼ固定）

このルールは npm の SemVer ドキュメントにまとまってるよ✅ ([npm ドキュメント][3])

例（依存指定）👇

```json
{
  "dependencies": {
    "some-lib": "^1.4.2",
    "tiny-lib": "~2.3.0"
  }
}
```

---

## 7.8 TypeScriptならでは：**型も契約**だよ🟦🤝

TypeScriptのライブラリって、**型定義がそのまま契約**になりやすいよね✨
だから「動く」だけじゃなくて「型が通る」も大事！

たとえば、次みたいな変更は **利用者の型チェックが落ちる**ことがある😵‍💫

* 型を “狭める/変える”（string → number とか）
* 既存プロパティを削除 / 名前変更
* ユニオン型の扱いを変えて、今まで通ってたコードが通らなくなる

実際、TypeScript向けツール群でも「型の非互換は breaking」として整理されてるよ📌 ([TypeScript ESLint][4])

---

## 7.9 （最新トピック）TypeScript本体は “厳密SemVer” じゃない点も知っとこ🧠⚠️

ライブラリは SemVer で運用するのが基本だけど、足元のツール（TypeScriptコンパイラ）は事情がちょい複雑🍀
公式の Breaking Changes ページが継続的に更新されていて、バージョンアップで型チェック挙動が変わり得るのが分かるよ🧯 ([GitHub][5])

さらに 2025年12月の公式ブログでは、**TypeScript 6.0 は 7.0 への “橋渡し”**で、6.1は出さない予定（必要ならパッチのみ）…みたいな方針も出てるよ📣 ([Microsoft for Developers][6])

👉 つまり、依存の更新では「SemVerだから絶対安心」と思い込まず、**CHANGELOG/リリースノートを見る習慣**が超大事だよ🙂📚

---

## 7.10 ミニ演習：SemVer判定クイズ🎮✨（10問）

次の変更、どれを上げる？（前提：1.0.0以上、公開APIがあるプロジェクト）🔢

1. 内部処理のバグ修正。公開APIは変わらない。
2. 新しい export 関数を追加（既存はそのまま）。
3. 既存関数に必須引数を1つ追加。
4. 戻り値の型を string → number に変更。
5. 既存型のプロパティを optional → required に変更。
6. 既存機能に @deprecated を付けた（まだ消してない）。
7. @deprecated にしてた関数を削除した。
8. JSONレスポンスに “新しい任意フィールド” を追加（古いクライアントは無視できる想定）。
9. エラーコードの値を変更（利用者がコードで分岐してる可能性あり）。
10. README を整えた（コードは同じ）。

### 解答✅✨

1. PATCH 🩹
2. MINOR 🎁
3. MAJOR 😱
4. MAJOR 😱
5. MAJOR 😱（型契約が壊れる）
6. MINOR 🚧（非推奨は MINOR） ([Semantic Versioning][1])
7. MAJOR 💥
8. だいたい MINOR 🎁（ただし “必須化” したら危険）
9. 多くは MAJOR 😱（挙動・意味が変わる系）
10. PATCH（か、リリースしないでもOK）📝

---

## 7.11 AI活用コーナー🤖✨（そのままコピペでOK）

* 「次の変更一覧を SemVer（MAJOR/MINOR/PATCH）で分類して。理由も短く」🧠
* 「この変更、利用者コードが壊れる可能性を3パターン挙げて」😱
* 「破壊変更を避けるための代替案（段階移行・非推奨）を提案して」🪜🚧
* 「CHANGELOG 用に Added/Changed/Deprecated/Removed/Fixed/Security で書き分けて」📰✨

---

## 7.12 リリースノート＆CHANGELOGの型📰📚

SemVerは「番号で伝える」だけど、実務では **文章で伝える**のがセットだよ✍️✨
有名な型として **Keep a Changelog** では、変更をこう分類するのがおすすめされてるよ👇

* Added / Changed / Deprecated / Removed / Fixed / Security ([Keep a Changelog][7])

あと GitHub のリリースノート自動生成も便利！
タグを切って「Generate release notes」できたり、SemVerに基づいて “latest release” が自動で決まる挙動もあるよ📌 ([GitHub Docs][8])

---

## まとめ✨🎀

* SemVerは「**公開APIがどう変わったか**」で決める🚪
* **壊したら MAJOR / 増やしたら MINOR / 直したら PATCH**🩹🎁😱
* **非推奨を付けたら MINOR**（地味に重要！）🚧
* npm の **^ / ~** と **0系のクセ**を理解すると事故が激減📦✨ ([npm ドキュメント][3])
* TypeScriptは **型＝契約**になりやすいから、型変更は breaking 判定になりがち🟦🤝 ([TypeScript ESLint][4])

[1]: https://semver.org/ "Semantic Versioning 2.0.0 | Semantic Versioning"
[2]: https://livefront.com/writing/lies-damn-lies-and-semantic-versioning/ "Lies, Damn Lies, and Semantic Versioning | Livefront Digital Product Consultancy"
[3]: https://docs.npmjs.com/cli/v6/using-npm/semver/ "semver | npm Docs"
[4]: https://typescript-eslint.io/users/versioning/ "Versioning | typescript-eslint"
[5]: https://github.com/microsoft/TypeScript/wiki/Breaking-Changes?utm_source=chatgpt.com "Breaking Changes · microsoft/TypeScript Wiki"
[6]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/ "Progress on TypeScript 7 - December 2025 - TypeScript"
[7]: https://keepachangelog.com/en/1.1.0/ "Keep a Changelog"
[8]: https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes "Automatically generated release notes - GitHub Docs"
