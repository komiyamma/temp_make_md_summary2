# 第03章：TypeScript側も“固定”がいる理由🧩🧷

## 🎯 この章のゴール

* 「TSって型チェックだけでしょ？」→ **いや、ビルド結果（JSの出力）や解釈も変わる**って分かる😳
* チームでも未来の自分でも、**同じJSが出て同じエラーが出る**状態を作れる🔒✨

---

## 1) TypeScriptは“型”だけじゃない🧠⚙️

TypeScriptって、ざっくり言うとこう👇

* **TypeScript（.ts）を読んで**
* **JavaScript（.js）を吐き出す**（= コンパイル/トランスパイル）
* さらに **モジュール解決（importがどのファイルを見るか）** や **tsconfigの解釈** もする

つまり、TSは **「ルール付き変換機」** なんだよね🤖🔧
この“変換機のバージョン”が変わると、同じソースでも結果がズレることがある💥

ちなみに本日時点だと、TypeScript は **5.9 系が「latest」扱い**として案内されていて、npm の latest も 5.9.3 になってるよ📌 ([typescriptlang.org][1])

---

## 2) TSのバージョン差で「何がズレるの？」😵‍💫➡️😆

ズレ方は大きく3系統あるよ👇

## A. ✅ 出力されるJavaScriptが変わる（＝実行結果に影響しうる）💣

例：モジュール周りの扱い（ESM/CJS）や、ターゲット（どのJS文法に落とすか）が変わると、吐かれるJSが変わる⚡

TypeScript 5.9 では **Node.jsの挙動に合わせた安定オプション `--module node20`** が入ってて、`nodenext` みたいに将来の挙動が“浮く”設定より安定しやすい設計になってるんだ🧷
しかも `--module node20` は **暗黙で `--target es2023`** を含む（設定しなければ）ので、出力JSの姿も変わりやすいポイント💡 ([typescriptlang.org][2])

> ここ、かなり大事：
> **「module設定 = ただの型の話」じゃなくて、出力JSの話**でもある📦🔥

---

## B. ✅ “同じコード”が通ったり落ちたりする（＝ビルドが止まる）🚧

TypeScriptは毎リリースで、

* エラー検出が強くなったり
* 解釈が厳密になったり
* 推奨オプションが増えたり
  するから、TSのバージョンが違うと **片方だけビルド失敗**とか普通に起きる😇

特に 5.9 の `tsc --init` は生成される tsconfig が“今風”になってて、たとえば `verbatimModuleSyntax` や `isolatedModules` などが推奨として入る形になってるよ🧠
これ、プロジェクトによっては「急に怒られ始めた😡」が起きる代表例！ ([Microsoft for Developers][3])

---

## C. ✅ import の“見に行く先”が変わる（＝実行時に別ファイルを見る）👀

これは地味に怖いタイプ💀
TSの **moduleResolution（import解決ルール）** の改善や Node 寄せの変更で、

* “どのファイルが import されるか”
* “拡張子やexportsフィールドの扱い”

みたいな部分がズレると、**実行時に読み込むモノが変わる**ことがある⚠️
だから「TS固定」は、**型のため**だけじゃなくて、**実行結果を守る**意味もあるんだ🛡️✨

---

## 3) 結論：TSも「プロジェクト内に固定」しよう🔒📌

TypeScript公式でも、長期運用のコードベースは **グローバルではなくプロジェクト単位の導入**を推してるよ（＝再現性のため）🧠✨ ([typescriptlang.org][1])

## ✅ 最小の固定セット（これだけで勝ちやすい🥳）

## ① devDependencies に入れる（= プロジェクトに閉じ込め）📦

```bash
npm i -D typescript
```

「でもこれだと最新が入っちゃうのでは？」って思うよね😄
実際は **lockfile（package-lock.json 等）で“同じ版”に揃えられる**、という前提が公式にも書かれてる👍 ([typescriptlang.org][1])
（将来的に更新したいときだけ、意図して更新する運用にできる）

よりガチで固定したいなら、こう👇（教材としてはこっちが分かりやすい！）

```bash
npm i -D typescript@5.9.3
```

（本日時点の latest が 5.9.3） ([npm][4])

---

## ② scripts に “必ずローカルtscを使う道” を作る🛣️

```json
{
  "scripts": {
    "build": "tsc -p tsconfig.json",
    "typecheck": "tsc -p tsconfig.json --noEmit"
  }
}
```

これで、誰がどこで実行しても `node_modules` の **固定された tsc** が動く🔒✨

---

## ③ 版ズレ検知のために「表示」できるようにする🔍

```bash
npx tsc -v
```

TypeScript公式の導入ページでも `npx tsc` が案内されてるよ📌 ([typescriptlang.org][1])

---

## 4) “固定できてるか”チェックリスト✅🔁

* ✅ `npx tsc -v` が毎回同じ
* ✅ `package-lock.json`（または pnpm-lock / yarn.lock）をコミットしてある
* ✅ “グローバルtsc” をなんとなく使ってない（混ざるとカオス😇）
* ✅ エディタ側も **Workspace版のTS** を使う（ここズレると「エディタではOKなのにCIで死ぬ」あるある💀）

---

## 5) ありがちな事故例（イメージできたら勝ち🏆）💥

## 😇 事故1：AさんのPCだけビルド通る

* Aさん：TypeScript新しめ
* Bさん：TypeScript古め
  → 片方だけ怒られる/通る、が発生😵‍💫

## 😇 事故2：同じソースなのに出力JSが微妙に違う

* module/target の扱いが変わって、吐かれるJSが違う
  → 本番だけ挙動が変・テストが落ちる🤯

ここを潰すのが「TS固定」だよ🧷✨

---

## 6) ミニ演習（5分）🧪⌛

## 演習A：ローカルのTSでバージョン確認👀

1. `npm i -D typescript@5.9.3`
2. `npx tsc -v` を実行
3. 友達（または別PC）でも同じ結果になるのが理想✨

## 演習B：AIに“固定観点レビュー”させる🤖📝

Copilot / Codex にこれ投げてOK👇
「package.json / lockfile / tsconfig を見て、TypeScriptのバージョン固定が弱い点を指摘して。CIで再現性が壊れるパターンも添えて」

---

## まとめ🎁✨

* TypeScriptは **型だけじゃなく、ビルド結果や解釈も変える**🧠⚙️
* だから **TSもプロジェクト内に閉じ込めて固定**が必須🔒
* 本日時点では TypeScript 5.9 が “latest” として案内されていて、npm の latest も 5.9.3 📌 ([typescriptlang.org][1])
* 5.9 では `--module node20` のような “Node挙動の安定化”も入ってきて、**モジュール周りの設定がより重要**になってるよ🧷 ([typescriptlang.org][2])

---

次の章（第4章）で「固定には3段階ある（Node本体・パケマネ・依存）」に入ると、ここでやった **TS固定**が「なるほど！その一部か！」って繋がって気持ちよくなるはず😆🚀

[1]: https://www.typescriptlang.org/download/ "TypeScript: How to set up TypeScript"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html "TypeScript: Documentation - TypeScript 5.9"
[3]: https://devblogs.microsoft.com/typescript/announcing-typescript-5-9/ "Announcing TypeScript 5.9 - TypeScript"
[4]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
