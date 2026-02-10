# 第21章：LintとFormatの役割を分ける🔍✨

この章のゴールはひとつだけ！
**「Lint（チェック係）」と「Format（整形係）」をちゃんと別の仕事にして、設定地獄を回避する**ことです😇🧯

---

## 1) まず結論：Lint と Format は“別の生き物”🧬

## ✅ Format（フォーマット）＝見た目を統一する係💇‍♀️🧼

* インデント、改行、クォート、カンマ…みたいな**見た目**を自動でそろえる
* できるだけ**「考えなくていい」**のが正義👑
* 代表：**Prettier**（2026年初頭だと 3.8 が出てる）([prettier.io][1])

👉 イメージ：**自動整髪機**✂️
何も言わなくても整えてくれるのが強み💕

---

## ✅ Lint（リンター）＝バグ・品質を守る係🕵️‍♂️🛡️

* 未使用変数、危ない書き方、バグりやすい癖、型に関するミス…を見つける
* 「これはダメ！」を言う係（ただし言いすぎると嫌われる）🤣
* 代表：**ESLint**（現代は Flat Config が基本）([eslint.org][2])

👉 イメージ：**コードの健康診断**🩺
“見た目”じゃなくて“危険”を止めてくれる！

---

## 2) 混ぜると何が起きる？「無限修正ループ」♾️😇

* ESLint が「改行こうして！」と言う
* Prettier が「いや、こう！」と言う
* 保存するたびに差分が揺れる🌀
* CIでも落ちる、直しても戻る、心が折れる😇💥

だから **役割分担**👇

✅ **Format は Format ツールに全投げ**（Prettier など）
✅ **ESLint は “バグ防止・品質” を中心にする**
✅ “見た目ルール” は ESLint から基本的に追放する🏃‍♂️💨

---

## 3) 例で体感しよう：「Formatが直すもの」「Lintが指摘するもの」🧪✨

## ✨ Format が直す例（見た目だけ）🧼

```ts
// ぐちゃっとしてるけど、動くコード
const user ={id:1,name:"Taro",roles:["admin","editor",],}
```

Prettier みたいなフォーマッタは、**意味を変えずに**こう整えます💅
（細かい形は設定次第だけど、“勝手に統一される”のが大事！）

```ts
const user = { id: 1, name: "Taro", roles: ["admin", "editor"] };
```

---

## 🛡️ Lint が指摘する例（危険・品質）🚨

```ts
async function main() {
  const data = fetch("https://example.com"); // await忘れ
  console.log(data);
}
```

* 「await してないよ！」みたいな **事故の芽** を止める🌱✂️
* これはフォーマッタの仕事じゃない！🙅‍♀️

---

## 4) “分ける”ための最小ルール3つ📏✨

## ルール①：Format は Prettier（または Biome）に任せる💇‍♀️

* **見た目の議論を消す**のが目的😌

## ルール②：ESLint から “見た目ルール” を減らす🧹

* インデント・改行・カンマ…みたいな「整形系」は基本OFF
* ここでよく使われるのが **eslint-config-prettier**（衝突しそうなESLintルールを止めるやつ）([GitHub][3])

## ルール③：実行コマンドを分ける（後でワンコマンドに統合）🧰

* `format`（整形する）
* `lint`（危険を探す）
* `check`（CI用：整形済みか確認＋lint）

---

## 5) “分けた”ときのおすすめコマンド設計（超ミニ版）🧩

第27章でガッツリやるけど、今は雰囲気だけ先に✨

```json
{
  "scripts": {
    "lint": "eslint .",
    "format": "prettier . --write",
    "format:check": "prettier . --check",
    "check": "npm run format:check && npm run lint"
  }
}
```

ポイント👇

* `format` は **直す**（--write）
* `format:check` は **直さないで検査だけ**（CI向け）✅
* `lint` は **品質チェック**🛡️

---

## 6) ここでのミニ課題🎮💪

## ミニ課題A：見た目の議論を消す✨

1. わざとインデントや改行を崩したコードを作る🙃
2. `format` を実行
3. **差分が整形だけ**になっているのを確認👀✨

## ミニ課題B：「Lintは見た目じゃなくて危険を見る」を体感🛡️

1. 未使用変数、await忘れ、anyの雑な扱い…を1個仕込む😈
2. `lint` を実行
3. 「あ、こういう事故を止めるのがLintなんだ！」を掴む🧠✨

---

## 7) よくある詰まりポイント集🧯😵‍💫

## ❌ 詰まり①：保存のたびに勝手に整形されてビビる😨

➡️ 正常です！むしろ最高です！🎉
“保存したら整う” は開発体験の完成形のひとつ💾✨（第25章で整えます）

## ❌ 詰まり②：ESLint と Prettier がケンカしてる😡⚔️

➡️ だいたい「ESLint側に整形ルールが残ってる」のが原因
**eslint-config-prettier で衝突を止める**方向へ寄せるのが基本です([GitHub][3])

## ❌ 詰まり③：ESLint設定ファイルが `.eslintrc` じゃないと動かない？

➡️ 最近のESLintは **Flat Config（eslint.config.*）中心**です([eslint.org][2])
しかも **ESLint v10 が 2026年2月にリリース**されて、周辺もどんどん新流儀に寄ってます([eslint.org][4])

---

## 8) AI拡張で時短するコツ🤖⚡（ただし“鵜呑み禁止”）

## ✅ AIに投げると速いもの

* 「このプロジェクトだと、Lint（品質）で最低限入れるルールって何？」
* 「Format（整形）と衝突しそうなESLintルールを外す方針にして」
* 「check コマンド（CI向け）を作って」

## ✅ AIの出力はここだけ確認すれば安全度UP🔒

* **LintとFormatが混ざってないか？**（整形ルールをESLintに入れすぎてないか）
* 依存パッケージの追加が多すぎないか（増やすほど管理コストUP）📦

---

## 9) ちょい注意：依存パッケージは“たまに事故る”🚧🧨（特にWindows）

実は 2025年に **eslint-config-prettier 等が侵害された件**があり、**Windowsでのインストール時に悪用されうる**タイプの話が出ました（CVE-2025-54313）([GitHub][5])

ここからの教訓はシンプル👇

* lockfile は必ず使う🔒
* 変なバージョンに当たったら即止める🛑
* “便利ツール盛り盛り”にしすぎない（依存が増えるほどリスク増）📦💦

---

## 10) ちなみに：Biome という「Lint+Format一体型」もある⚡🧰

この教材だと第26章で詳しく触れるけど、今のうちに位置づけだけ👇

* **Biome**は「Lint＋Formatを1つでやる」高速ツール⚡
* Prettier互換もかなり意識されていて、公式は **Prettier互換 97%** をうたってます([Biome][6])
* 2026年のロードマップも公開されてて、対応範囲を広げる流れが見えます([Biome][7])

「設定を減らしたい」「とにかく速くしたい」なら選択肢になる感じです😎✨

---

## この章のまとめ🎁✨

* **Format＝見た目統一（自動整髪）**💇‍♀️
* **Lint＝バグ防止（健康診断）**🩺
* 混ぜると地獄なので、**役割分担して衝突を消す**😇🧯
* 次章（第22章）で **ESLint Flat Config** を“迷子にならない形”で入れていきます🧾🚀

[1]: https://prettier.io/blog/2026/01/14/3.8.0?utm_source=chatgpt.com "Prettier 3.8: Support for Angular v21.1"
[2]: https://eslint.org/docs/latest/use/configure/migration-guide?utm_source=chatgpt.com "Configuration Migration Guide"
[3]: https://github.com/prettier/eslint-config-prettier?utm_source=chatgpt.com "prettier/eslint-config-prettier: Turns off all rules that ..."
[4]: https://eslint.org/blog/2026/02/eslint-v10.0.0-released/?utm_source=chatgpt.com "ESLint v10.0.0 released"
[5]: https://github.com/advisories/GHSA-f29h-pxvx-f335?utm_source=chatgpt.com "eslint-config-prettier, eslint-plugin-prettier, synckit, @pkgr ..."
[6]: https://biomejs.dev/?utm_source=chatgpt.com "Biome, toolchain of the web"
[7]: https://biomejs.dev/blog/roadmap-2026/?utm_source=chatgpt.com "Roadmap 2026 - Biome"
