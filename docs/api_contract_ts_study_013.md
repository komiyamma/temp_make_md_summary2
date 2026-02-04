# 第13章：npmパッケージ契約①：公開API面の設計📦🚪

## この章のゴール🎯✨

* 「このライブラリの“約束（契約）”はここ！」って**入口を小さく**決められるようになる💡
* 利用者が**勝手に内部へ潜り込めない**ようにして、将来の変更がラクになる🧹✨
* “公開していいものだけ”を**機械的に固定**できるようになる🔒✅

---

## 13-1. 公開API面ってなに？🤝✨

npmパッケージの公開API面（Public Surface）は、ざっくり言うと👇

* 利用者が import できる “入口” の集合🚪
* 利用者が読める型（d.ts）として見える “約束” の集合🧾
* 利用者が「これがある前提」で組んでしまう “依存ポイント” の集合🧷

ここが増えるほど、将来の変更が「破壊的変更」になりやすいのがコワいところ😱💥
（公開＝約束、ってこと！）

---

## 13-2. 公開面が大きいと何が起きる？😵‍💫💣

公開面が大きいと、こんな地獄が起きがち👇

* 内部のファイル名を変えただけで利用者が壊れる（＝破壊）📁💥
* “つい export しちゃった便利関数” を消せなくなる（＝永久保存）🪦
* 入口が多すぎて、利用者がどれ使うべきか迷う（＝サポート地獄）🌀
* リファクタしたいのに「互換性が怖い」から動けなくなる（＝停滞）🧊

だから、最初から **公開面は小さく、入口は少なく** が正解になりやすいよ🫶✨

---

## 13-3. まず決めるのは「入口は何個？」🎭➡️🚪

おすすめの考え方はこれ👇

## ✅ 入口は基本 1つ（ルート）＋必要なら少数のサブ入口

* ルート入口：パッケージ名だけで import
* サブ入口：用途がハッキリしてるものだけ（例：/client、/server、/react みたいに）

この「入口の数」＝公開面のサイズの第一歩だよ👣✨

---

## 13-4. “公開を増やしてしまう”典型事故⚠️😇

## 事故①：全部入り index（巨大バレル）にしちゃう🧺💥

便利そうに見えて、公開面が勝手に太る…！
さらにビルドや型解決の負担が増えて、速度面で困ることもあるよ🏎️💦
（大規模で “barrel を減らして速度改善” みたいな事例も出てる）([アトラシアン][1])

## 事故②：利用者が内部へ直 import し始める🕳️🐜

例えば利用者が「pkg/dist/internal/utils」みたいに直で import すると…
あなたが内部構造を変えた瞬間に、利用者が死ぬ🧟‍♀️💥

これを防ぐために、次の章でやる “exports で出口を管理” が超重要になるよ🔒✨([Node.js][2])

---

## 13-5. 公開面を小さくする基本設計🧱✨

## ① 「公開用フォルダ」を作って、そこだけが“表”🌞

* src/public … 公開していいものだけ
* src/internal … いつでも壊していい内部

この分離だけで、設計の頭がスッキリするよ🧠✨

## ② 公開は “明示リスト方式” にする📝✅

「export * で全部出す」じゃなくて👇

* 公開する関数・型・定数を **1個ずつ指名**して export
* “公開するもの” は毎回レビュー対象にする👀

---

## 13-6. exports で「利用者が触れる入口」を固定する🔒🚪

Node の package.json の exports は、**“このパッケージの出口（公開される道）”**を宣言する仕組みだよ📦✨
ポイントは👇

* exports に書いたものだけが import 可能になる
* exports にないパスは、利用者からは基本アクセス不可（エラーになる）
* 条件付き（import/require など）で、環境ごとに出口を切り替えられる

Node の公式ドキュメントでも exports（条件付き exports 含む）が説明されてるよ📚([Node.js][2])
Webpack も「exports は package の公開範囲を宣言する」と整理してるよ🧰([webpack][3])

---

## 13-7. TypeScriptで壊れにくい公開面を作るコツ🟦🧾

## ✅ 「型の入口」も “公開面” だよ！

利用者に見える d.ts（型定義）は、まさに契約そのもの🧾🤝
だから、型も「表（public）」と「裏（internal）」を分ける発想が効くよ✨

## ✅ exports の “types” 条件を理解しよう🧠

TypeScript は exports の解決で “types” と “default” を優先して扱うルールがあるよ（条件付き exports）([TypeScript][4])
そして “types は exports の中で先に置くのが大事” という注意も昔から明記されてるよ📌([TypeScript][5])

さらに、TypeScript 側で exports/imports を正しく読むには moduleResolution のモードが関係するよ（node16/nodenext/bundler など）([TypeScript][6])

---

## 13-8. 「型だけ内部扱い」にしたい時の小技🕵️‍♀️🧾

「内部で使う型を、利用者に見せたくない…！」って時あるよね🥺

そのときに候補になるのが stripInternal（@internal を付けた宣言を d.ts に出さない）ってオプション。
ただし **“内部向け” で、結果の妥当性チェックはしてくれない** って注意があるよ⚠️([TypeScript][7])

つまり、使うなら👇

* 「@internal を付けたものを公開APIから参照しない」
* “型の依存関係” が崩れないかをちゃんと確認する
  が大事だよ✅

（「もっと堅くやりたい」なら api-extractor を見てね、って TypeScript 側でも案内があるよ）([TypeScript][7])

---

## 13-9. ハンズオン：公開面を “3つだけ” に絞るミニライブラリ✂️📦

## ① 目標：利用者に見せるのはこれだけ🌸

* formatDate（文字列にする）
* parseDate（文字列から読む）
* DateFormatOptions（オプション型）

それ以外は全部 internal に隔離する🙈✨

---

## ② ディレクトリ構成（例）📁

```text
my-date-lib/
  src/
    public/
      index.ts
    internal/
      parse.ts
      format.ts
      types.ts
  dist/
    ...（ビルド出力）
  package.json
  tsconfig.json
```

---

## ③ public/index.ts は “表の窓口”だけにする🚪✨

```ts
// src/public/index.ts
export { formatDate } from "../internal/format";
export { parseDate } from "../internal/parse";
export type { DateFormatOptions } from "../internal/types";
```

ポイント👇

* public 側は “再公開（re-export）” するだけ
* internal 側のファイル構成は将来変えてOK（利用者から見えなければ）🧠✨

---

## ④ package.json の exports で “出口” を固定する🔒

「利用者が import できる道」をここで宣言するよ📦

```json
{
  "name": "my-date-lib",
  "type": "module",
  "exports": {
    ".": {
      "types": "./dist/public/index.d.ts",
      "default": "./dist/public/index.js"
    }
  }
}
```

* 「ルート（.）だけ」公開＝入口が1つで超スッキリ✨
* exports に書いてない subpath は利用者が触れにくくなる（内部を守れる）🛡️([Node.js][2])
* “types” と “default” の扱いは TypeScript の exports 解決ルールに沿うよ🧾([TypeScript][4])

---

## ⑤ “内部パス封鎖” をより強くしたい時🧱🚫

subpath pattern を使う場合は、Node の docs で「private を null で除外できる」って説明があるよ🧷([Node.js][8])

（例：全部公開したいけど一部だけ封鎖したい、みたいな時に使うイメージ🧠）

---

## 13-10. 互換性（壊れる/壊れない）の判断早見⚖️🔁

## ✅ だいたい安全（MINOR/PATCH寄り）🌿

* 新しい関数を追加（入口や既存を壊さない）➕
* 既存関数の引数に “任意（オプショナル）” を足す（慎重に）🧩
* 内部実装だけ変える（公開面に影響しない）🧹

## ❌ だいたい破壊（MAJOR寄り）💥

* 既存 export の削除🗑️
* export 名の変更・移動（import パスが変わる）📦💣
* 関数シグネチャ変更（引数の削除、型の変更）🧨
* 返す値の意味が変わる（型が同じでも利用者が壊れる）🎭💥

---

## 13-11. 公開API面チェックリスト✅🧡

リリース前にこれだけ見ておくと事故が減るよ✨

* 公開入口は 1つ（＋必要最小のサブ入口）になってる？🚪
* public フォルダからしか公開してない？🌞
* export は “指名制” になってる？（全部出しになってない？）📝
* package.json の exports は “利用者に触らせたい道だけ” になってる？🔒([Node.js][2])
* 型（d.ts）に “うっかり内部型” が漏れてない？🧾
* 破壊的変更が混ざってない？（削除・改名・移動）💥

---

## 13-12. ミニ演習✍️🌸

## 演習A：自分のライブラリ（または小さな関数集）でやってみよう🧸

1. 公開したい機能を “3つだけ” 選ぶ🎯
2. src/public/index.ts を作って “窓口” にまとめる🚪
3. それ以外は src/internal に移動する📦
4. exports を “ルートだけ” にしてみる🔒
5. もし内部へ import してる利用者コードがあったら、全部ルート import に直す🛠️

---

## 13-13. AI活用プロンプト集🤖💞

そのままコピペで使えるよ✨

## 公開面の最小化🪄

* 「このライブラリの利用者のユースケースを3つ想像して、公開APIを最小セットで提案して」
* 「このコードから “公開してはいけない内部機能” を候補リストにして」

## exports 設計🔒

* 「このフォルダ構成で、入口を1つにする exports 設計案を作って」
* 「利用者が内部へ deep import しないようにする設計にして。移行コストも考えて」

## 破壊的変更レビュー👀

* 「この差分は破壊的変更？理由と、破壊を避ける代替案を出して」
* 「SemVer 的に MAJOR/MINOR/PATCH どれ？根拠も一緒に」

---

## まとめ🎀✨

公開API面は「利用者との約束」そのもの🤝
最初から **入口を小さく**して、**exports で出口を固定**して、**内部を自由に育てられる**形にしておくと、将来の進化がめちゃラクになるよ📦🌱([Node.js][2])

[1]: https://www.atlassian.com/blog/atlassian-engineering/faster-builds-when-removing-barrel-files?utm_source=chatgpt.com "How We Achieved 75% Faster Builds by Removing Barrel ..."
[2]: https://nodejs.org/api/packages.html?utm_source=chatgpt.com "Modules: Packages | Node.js v25.5.0 Documentation"
[3]: https://webpack.js.org/guides/package-exports/?utm_source=chatgpt.com "Package exports"
[4]: https://www.typescriptlang.org/docs/handbook/modules/reference.html?utm_source=chatgpt.com "Documentation - Modules - Reference"
[5]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-4-7.html?utm_source=chatgpt.com "Documentation - TypeScript 4.7"
[6]: https://www.typescriptlang.org/tsconfig/moduleResolution.html?utm_source=chatgpt.com "TSConfig Option: moduleResolution"
[7]: https://www.typescriptlang.org/tsconfig/stripInternal.html?utm_source=chatgpt.com "stripInternal - TSConfig Option"
[8]: https://nodejs.org/download/release/v16.10.0/docs/api/packages.html?utm_source=chatgpt.com "Modules: Packages | Node.js v16.10.0 Documentation"
