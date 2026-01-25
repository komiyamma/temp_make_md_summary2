# 第4章 学習用プロジェクトを動かす（最短で成功体験）🚀🧑‍💻✨

### ねらい🎯

* 「まず動かす！」を最速で達成する🏁✨
* npm scripts（`npm run ...`）に慣れる🧩
* 変更 → 実行 → 戻す の“安全な手触り”を体に入れる🔁🛟
* VS Codeでのデバッグ入口を開ける🔍🧷

---

### 今回つくる学習用プロジェクト🧪📦

**ブラウザで動く TypeScript ミニアプリ（Vite）**でいくよ〜🌸
Vite はテンプレが用意されてて、`vanilla-ts`（生TypeScript）がサクッと作れるよ📌 ([vitejs][1])

---

## 1) Node.js の準備（まずここ）🟢🔧

ターミナル（VS Code内でOK）で👇を打ってみてね💻✨

```bash
node -v
npm -v
```

* Node.js は **LTS（長期サポート）** を使うのが安心だよ🛟
* 今のLTS系だと、**v24 が Active LTS** として案内されてるよ📌 ([nodejs.org][2])
* しかも最近、**v24.13.0** みたいなセキュリティ更新も出てるから、たまに更新してね🧯✨ ([nodejs.org][3])

---

## 2) プロジェクト作成（1分で完成）⏱️📁✨

作業用フォルダで、次を実行するよ👇

### 2-1. 迷わない一発コマンド版💥

```bash
npm create vite@latest refactor-playground -- --template vanilla-ts
cd refactor-playground
npm install
```

> `vanilla-ts` は Vite の公式テンプレのひとつだよ🧁 ([vitejs][1])

### 2-2. 対話で選ぶ版（こっちでもOK）💬

```bash
npm create vite@latest
```

質問が出たら、だいたいこんな感じで選ぶよ👇

* Project name：`refactor-playground`
* Framework：Vanilla
* Variant：TypeScript

---

## 3) まず動かす！（成功体験✨）▶️🌈

```bash
npm run dev
```

ブラウザで `http://localhost:5173/` を開いて、画面が出たら勝ち🏆✨
（Viteの開発サーバはこのへんの流れが基本だよ〜） ([vitejs][4])

---

## 4) npm scripts を読めるようになる（超だいじ）📜👀

`package.json` を開いて、`scripts` を見てみよう🧩✨
だいたいこういうのが入ってるよ👇（生成物により多少違ってOK）

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview"
  }
}
```

* `dev`：開発用（最重要）🔥
* `build`：本番用に固める（型チェックも絡むこと多い）📦
* `preview`：ビルド結果をローカルで確認👀

---

## 5) 「1行変更 → 実行 → 戻す」練習🔁✨（ミニ課題の本体）

`src/main.ts` を開いて、`console.log` か表示テキストを **1行だけ** 変えてみてね✍️

例：`main.ts` のどこかに👇を足す（または文字を変える）

```ts
console.log("refactor playground: hello! 🌷");
```

そして👇を確認✅

1. ブラウザが自動で更新（または手動リロード）される👀✨
2. DevTools（F12）→ Console にログが出る🪵
3. その1行を元に戻す🔙（戻せたらさらに安心感UP🛟）

> Vite は TypeScript を開発中は高速に扱えるようにしてて、HMR（即反映）も強いのが売りだよ⚡ ([vitejs][4])

---

## 6) デバッグ入門（ブレークポイント置いてみよ）🔍🧷✨

「デバッグできる」と、怖いコードでも触れるようになるよ〜😌🛟

### 6-1. ブレークポイントを置く🎯

`src/main.ts` の適当な行にブレークポイント（赤い●）を置く！

### 6-2. VS Code のデバッグ設定を作る🧰

`.vscode/launch.json` を作って、これを書いてね👇

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Vite: Chromeで起動してデバッグ",
      "type": "pwa-chrome",
      "request": "launch",
      "url": "http://localhost:5173",
      "webRoot": "${workspaceFolder}"
    }
  ]
}
```

### 6-3. 実行▶️

1. 先に `npm run dev` を動かしておく
2. VS Code の「実行とデバッグ」→ `Vite: Chromeで起動してデバッグ` を選んで▶️
3. ブレークポイントで止まったら大成功🎉✨

---

## 7) “型チェック専用”コマンドを追加（安心ボタン）🧷✅

Vite は開発中の変換が速い反面、「型エラーを別プロセスで見たい」場面もあるよ📌
公式も `tsc --noEmit --watch` を別で回す案を紹介してるよ🧷 ([vitejs][4])

`package.json` の `scripts` にこれを足してみよう👇

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "typecheck": "tsc --noEmit",
    "typecheck:watch": "tsc --noEmit --watch"
  }
}
```

使い方👇

```bash
npm run typecheck
```

「型で守られてる感じ」が出てきて、リファクタが怖くなくなるよ〜🛡️✨

---

## ミニ課題✍️🌸（チェックリスト式）

* [ ] `npm run dev` で起動できた🚀
* [ ] `src/main.ts` を1行変えて、反映を見た👀✨
* [ ] 1行を元に戻した🔙🛟
* [ ] `launch.json` でデバッグ起動して止められた🔍🧷
* [ ] `npm run typecheck` を追加して動かした🧷✅

---

## AI活用ポイント🤖✨（お願い方＋チェック観点✅）

### 1) README を整えてもらう📄✨

お願い例👇

```text
このプロジェクトのREADMEを作って。
内容は「セットアップ」「よく使うコマンド(dev/build/preview/typecheck)」「デバッグ方法(launch.json)」「よくあるエラーと対処」を短く。
```

チェック観点✅

* “実際のコマンド名”が `package.json` と一致してる？
* 手順が **コピペで動く** 形になってる？

### 2) scripts の意味を“自分の言葉”にしてもらう🧠✨

お願い例👇

```text
package.jsonのscripts(dev/build/preview/typecheck)を、初心者向けに1行ずつ説明して。
それぞれ「いつ使うか」も書いて。
```

チェック観点✅

* 「いつ使うか」が具体的？（例：リファクタ前にtypecheck、など）
* 余計なツール追加を勝手にしてない？（まずは最小が正解🙆‍♀️）

### 3) “1行変更”の候補を10個出してもらう🎲

お願い例👇

```text
src/main.tsで「1行だけ変えて動作確認しやすい変更」を10個ください。
表示が分かりやすくて、すぐ元に戻せるものがいいです。
```

チェック観点✅

* 変更が小さい？（差分が1行〜数行に収まる）
* ちゃんとすぐ戻せる？🔁

---

[1]: https://ja.vite.dev/guide/?utm_source=chatgpt.com "はじめに"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://nodejs.org/en/blog/vulnerability/december-2025-security-releases?utm_source=chatgpt.com "Tuesday, January 13, 2026 Security Releases"
[4]: https://vite.dev/guide/features?utm_source=chatgpt.com "Features"
