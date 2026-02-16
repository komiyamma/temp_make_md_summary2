# 第07章：Node.jsとnpm：まず“動く土台”を確認🔩🧰

この章は **「React+TypeScriptを動かすための“土台”＝Node/npmがちゃんと動く」** をサクッと作る回だよ😊
ここがグラつくと、後の章（Vite/React/Firebase SDK/AI系）で **エラー祭り** になるので、先にガッチリ固めよう💪✨

---

## 今日のゴール🎯

* `node -v` / `npm -v` が通る✅
* `package.json` の **scripts / dependencies** を“ざっくり読める”✅
* `npm install` で依存を入れて、Nodeで1ファイル動かせる✅
* `package-lock.json` の意味が分かる✅（消さない🫶）

---

## 1) Node.js と npmって何者？🧠

* **Node.js**：ブラウザじゃなくてもJavaScriptを動かせる実行環境💻
  → React開発では「開発サーバー」「ビルド」「CLIツール」を動かすエンジン役になるよ⚙️
* **npm**：Nodeの世界の“アプリストア”みたいなもの📦
  → ライブラリを入れる・更新する・実行する（`npm run`）を担当！

> これから Firebase のSDK入れるのも、AI系（Genkitとか）を触るのも、まずnpmでパッケージを入れるところから始まるよ🤖📦 ([Chrome for Developers][1])

---

## 2) 2026年の「安全なNodeバージョン」🧯

React+Vite周りは、**Nodeが古いと容赦なく動かない** です😇

* Vite 7 では **Node 20.19+ または 22.12+ が必要**（ここ超重要）⚡ ([vitejs][2])
* NodeのLTS状況としては、2026年2月時点で **v24がActive LTS**、v22/v20は **Maintenance LTS** 側の扱いだよ📌 ([nodejs.org][3])

おすすめはこのどっちか👇

* **Node 24 LTS**（新しめで安心）✨
* **Node 22 LTS**（互換性で困りにくい）🧱

※ どっちでも **「Node >= 22.12」** を満たしてれば、Vite 7条件をクリアできるよ✅ ([vitejs][2])

---

## 3) Windowsで Node / npm を確認する🪟✅

## 3-1. バージョン確認（まずこれ！）

ターミナル（PowerShellでOK）で👇

```bash
node -v
npm -v
```

* どっちも数字が出ればOK🎉
* `node` が見つからない系なら、だいたい **インストール or PATH** 問題だよ🧩

## 3-2. すぐ直したいときの合言葉🧯

* **Nodeの再インストール（LTS）** → いちばん早い
* インストール後は **ターミナル再起動**（これ忘れがち）🔁

---

## 4) npm の基本操作（これだけで当面OK）📦✨

## 4-1. 依存を入れる

* ふつうに入れる：
  `npm install パッケージ名`（短く `npm i`）

* 開発用として入れる：
  `npm i -D パッケージ名`（Vite/TypeScript系はだいたいこっち）

## 4-2. スクリプトを動かす（超大事）

* `package.json` の `scripts` にある命令を実行するよ🏃‍♂️💨
  例：`npm run dev` は「開発サーバ起動」を意味することが多い⚛️

## 4-3. lockファイルは“守る”

`package-lock.json` は **npmが自動生成**して、同じ依存ツリーを再現するためのもの🔒
基本 **Gitにコミットする前提** だよ（チームでも未来の自分でも助かる）🫶 ([npm ドキュメント][4])

---

## 5) `package.json` の読み方（最低ライン）👀

見る場所はここだけでOK👇

* `name` / `version`：プロジェクト情報🪪
* `scripts`：`npm run xxx` で実行されるコマンド一覧🎮
* `dependencies`：本番でも使うライブラリ📦
* `devDependencies`：開発中だけ使う道具（TypeScript/Viteなど）🧰

---

## 6) 5分で体験：Nodeで動かして、npmで1個入れる🧪✨

## 6-1. 新しい作業フォルダを作る📁

```bash
mkdir node-npm-check
cd node-npm-check
npm init -y
```

これで `package.json` が生える🌱

## 6-2. まず “Nodeだけ” で動かす🚀

`index.mjs` を作って👇（エディタでOK）

```js
console.log("Node OK! 🎉");
console.log("Node version:", process.version);
```

実行👇

```bash
node index.mjs
```

## 6-3. npmでライブラリを入れる（例：nanoid）📦

```bash
npm i nanoid
```

`index.mjs` をこう変更👇

```js
import { nanoid } from "nanoid";

console.log("Node + npm OK! 🎉");
console.log("id:", nanoid());
```

実行👇

```bash
node index.mjs
```

ここまでできたら、土台はほぼ勝ち確🏆✨
この時点で `node_modules` と `package-lock.json` が増えてるはずだよ（消さないでね）🔒 ([npm ドキュメント][4])

---

## 7) Antigravity / Firebase Studio 側で詰まったとき🛸🧰

クラウドIDE側は **Nixで環境を固定**できるタイプ。
つまり「Nodeのバージョンをプロジェクトに同梱して、全員同じ環境にする」発想が強いよ📌 ([Firebase][5])

* 置き場所の基本：`.idx/dev.nix`
* ここを変えて **ワークスペースをリビルド**すると、Node等のツールが揃う感じ！

（※この章では“概念だけ”でOK。実際の調整は必要になったタイミングで一緒にやろう🤝）

---

## 8) AIに助けてもらう（Gemini CLI / Agent）🤖💬

Node/npmのエラーは、AIに投げると **復旧が速い** よ🚑✨

## 8-1. そのまま投げてOKなテンプレ🧾

* 「コマンド」「エラー全文」「今の `node -v` と `npm -v`」の3点セットが最強🔥

例（そのままコピペでOK）👇

```text
npm run dev が失敗します。
node -v: vXX.XX.X
npm -v: X.X.X

コマンド:
npm run dev

エラー:
(ここに全文)

原因候補を3つに絞って、確認コマンドもセットで教えて。
```

## 8-2. Gemini CLI を npm で更新する系の話📌

Gemini CLIは npm で入れて更新する案内が一般的だよ（`npm install -g ...`）🔧 ([Gemini CLI][6])
※ グローバル導入は便利だけど、PATH絡みの詰まりが出たらAIに「npmのglobal binパス見つけて直したい」って聞けばOK👍

---

## ミニ課題🎒✨（10分）

1. `node-npm-check` を別フォルダにもう1個作る📁
2. `npm i nanoid` の代わりに、好きなパッケージを1つ入れる（例：`dayjs`）📦
3. `node index.mjs` で「入れたパッケージを使って出力」する🖨️

   * 例：今日の日付を表示📅

---

## チェック✅（3つ言えたら合格🎉）

* `npm run dev` は何をするための仕組み？🧠
* `dependencies` と `devDependencies` の違いは？📦
* `package-lock.json` を消さない理由は？🔒 ([npm ドキュメント][4])

---

次の第8章では、この土台の上に **ViteでReact+TypeScript最小アプリ** を作って「ブラウザに表示できた！」まで行くよ⚛️🌱
もし今ここでエラー出たら、**エラー全文＋`node -v`＋`npm -v`** を貼ってくれたら、最短ルートで直すよ🧯💪

[1]: https://developer.chrome.com/docs/ai/firebase-ai-logic?utm_source=chatgpt.com "Hybrid AI prompting with Firebase AI Logic | AI on Chrome"
[2]: https://vite.dev/blog/announcing-vite7?utm_source=chatgpt.com "Vite 7.0 is out!"
[3]: https://nodejs.org/ja/about/previous-releases?utm_source=chatgpt.com "Node.js リリース"
[4]: https://docs.npmjs.com/cli/v8/configuring-npm/package-lock-json/?utm_source=chatgpt.com "package-lock.json"
[5]: https://firebase.google.com/docs/studio/customize-workspace?utm_source=chatgpt.com "Customize your Firebase Studio workspace - Google"
[6]: https://geminicli.com/docs/troubleshooting/?utm_source=chatgpt.com "Troubleshooting guide"
