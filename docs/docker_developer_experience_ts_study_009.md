# 第09章：TypeScriptの実行を気持ちよくする🏃‍♂️💨（待ち時間を減らす！）

この章のテーマはシンプル👇
**「TSを“実行するまでの儀式”を減らして、保存→即反映を気持ちよくする」**です😆✨

---

## 1) まず結論：TSの実行ルートは3つある🛣️

| ルート                    | 体験     | 強み               | 注意点            |
| ---------------------- | ------ | ---------------- | -------------- |
| A. **tsxで直接実行**        | 速い！楽！  | watchが強い / 設定少なめ | **型チェックは別で必要** |
| B. **tscでビルド→nodeで実行** | 堅い！安定！ | 本番に近い / TS機能フル   | “ビルド待ち”が出やすい   |
| C. **Nodeの“そのままTS実行”** | 依存少なめ  | Node単体でOK        | **使えるTS構文が制限** |

tsxは「CJS/ESMどっちも扱いやすい」「Watchモードが用意されてる」など、開発体験をかなりラクにしてくれる路線だよ😊
([tsx][1])

---

## 2) 今章の主役：tsxで“最短ホットリロード”を作る🔥

## 2-1. ねらい🎯

* **保存したら勝手に再起動**（watch）👀
* **“TSを実行するための手順”を最短に**✂️
* でも **型の安全は捨てない**（型チェックは別で回す）🛡️

tsxは高速トランスパイル寄りで、**型チェックをしない**思想。なので **tscの型チェック（noEmit）を並走**させるのが“気持ちよさ”と“安心”の両立だよ👍
([tsx][2])

---

## 3) 実装：tsx watch + typecheck watch を“同時起動”する🧩✨

## 3-1. 追加インストール📦

開発用に入れる（例）：

```bash
npm i -D tsx typescript @types/node concurrently
```

* **tsx**：TS実行＆watch担当🏃‍♂️💨
* **typescript**：型チェック担当🧠
* **concurrently**：2つのコマンド同時起動担当🧵

---

## 3-2. package.json に “気持ちいい scripts” を作る🧰

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "typecheck": "tsc -p tsconfig.json --noEmit --watch",
    "dev:full": "concurrently -k \"npm:dev\" \"npm:typecheck\"",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js"
  }
}
```

ポイント💡

* `dev`：**実行＆再起動**だけ担当（速い）⚡
* `typecheck`：**型だけ監視**（noEmitで出力しない）🧠
* `dev:full`：**2つを同時に回す**（“速い”＋“安心”）💪

---

## 3-3. Compose側は“入口を1個にする”🚪✨

コンテナ起動コマンドは、最終的にこれだけに寄せると迷わない：

```yaml
services:
  app:
    command: npm run dev:full
```

これで、あなたの開発者体験は👇
**「docker compose up」→ 保存するたびに自動反映 + 型エラーも即表示** 🎉

---

## 4) “型チェックは別で回す”が正解な理由🛡️🙂

tsxは便利だけど、**型で止めてくれるわけじゃない**。だからこそ、

* 実行は **tsx（速さ重視）** 🏎️
* 安全は **tsc（型だけ監視）** 🛡️

の分業がいちばん気持ちいいんだよね😄
この思想はNode側のガイドでも「tsxは型チェックしないので、出荷前にtscでチェック推奨」みたいなニュアンスで語られてるよ📚
([Node.js][3])

---

## 5) 参考：Nodeの watch を組み合わせるとさらに楽になることも👀

Nodeには `--watch` があって、変更で自動再起動できる（watchは安定扱い）😎
([Node.js][4])

ただし注意⚠️
**Nodeのwatchは「JSを再起動」する機能**で、TSをどう扱うかは別問題になりがち。そこでtsxが効く、って流れだね。

---

## 6) もう1ルート：Nodeの“そのままTS実行”って何？🧪

最近のNodeは、条件が合えば **TSをそのまま実行できる**方向に進んでるよ（いわゆる“type stripping”）🧼
([Node.js][5])

ただしこれは **「消せる型注釈だけのTS」**が前提で、TSの機能でも **実行時に意味を持つもの**（例：いろいろ）を使うとコケやすい🙃
なので教材としては、まずは **tsx + typecheck** の方が事故りにくい👍
（この“消せるTSだけ”という考え方はTypeScript側でも説明されてる）
([typescriptlang.org][6])

---

## 7) ミニ課題（10〜20分）🎓✨

## 課題A：ホット反映を体感する⚡

1. `src/index.ts` にログを1行追加（例：起動時に “boot!” を出す）📝
2. 保存して、**コンテナが自動再起動**するのを確認👀
3. ブラウザ or curl で動作確認✅

## 課題B：型エラーが“即わかる”状態を作る🧠

1. わざと型ミスする（例：`const n: number = "a"`）😈
2. 保存して、**typecheck側が即エラー**を出すのを確認🚨
3. 直して、エラーが消えるのを確認✨

---

## 8) よくある詰まりポイント集（ここが沼！）🕳️😂

## ❶ 「動くけど型が壊れてる」問題

* **tsxは型で止めない** → `typecheck` を常時回すのが解決策👍
  ([tsx][2])

## ❷ watchが反応しない／遅い（特にWindows+コンテナ）

* ファイル変更通知が届きにくい環境がある
* そういう時は次章以降の **Compose Watch** が効く場面が出る（章11の流れ）🙂
  （tsx自体のwatchは“Nodeのwatchより堅牢寄り”という説明もある）
  ([tsx][7])

## ❸ Nodeのwatchを使ったら終了シグナルが合わない

* 例えば graceful shutdown をしたいなら、`--watch-kill-signal` で調整できる（追加されたオプション）🧯
  ([Node.js][4])

---

## 9) AIで時短するプロンプト例🤖✨（コピペでOK）

## 9-1. scripts を整える

「いまのpackage.jsonのscriptsを、tsx watch + tsc --noEmit --watch を concurrently で dev:full 起動できる形にして。既存のbuild/startは壊さないで」

## 9-2. tsconfig を“最小で気持ちよく”

「Node実行のTSプロジェクト向けに、学習用のtsconfig.jsonを最小構成で作って。strictはtrue、outDirはdist、rootDirはsrc、sourceMapはtrue」

## 9-3. 事故りがちな点のチェック

「この構成で、ESM/CJS周りで初心者が詰まりやすい点を3つ挙げて、それぞれの回避策を具体的に教えて」

---

次の章（第10章）では、ここで作った基盤に対して「じゃあ nodemon はいつ必要？」を**判断基準つき**で整理していくよ🤔🧰
この第9章の状態ができてると、比較がめちゃくちゃラクになる👍✨

[1]: https://tsx.is/?utm_source=chatgpt.com "TypeScript Execute (tsx) | tsx"
[2]: https://tsx.is/faq?utm_source=chatgpt.com "Frequently Asked Questions | tsx"
[3]: https://nodejs.org/en/learn/typescript/run?utm_source=chatgpt.com "Running TypeScript with a runner"
[4]: https://nodejs.org/api/cli.html?utm_source=chatgpt.com "Command-line API | Node.js v25.6.0 Documentation"
[5]: https://nodejs.org/en/learn/typescript/run-natively?utm_source=chatgpt.com "Running TypeScript Natively"
[6]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-8.html?utm_source=chatgpt.com "Documentation - TypeScript 5.8"
[7]: https://tsx.is/watch-mode?utm_source=chatgpt.com "Watch mode"
