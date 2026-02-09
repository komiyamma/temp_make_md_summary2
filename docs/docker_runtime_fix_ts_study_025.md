# 第25章：ソースマップでデバッグが幸せになる🕵️‍♂️✨

この章のテーマはシンプル！
**「TSで書いた行番号のまま、エラー原因を追えるようにする」**です😆🔍
（2026-02-09時点：Nodeは v25がCurrent / v24がActive LTS / v22がMaintenance LTS、TypeScriptのnpm “Latest”は 5.9.3 です）([Node.js][1])

---

#### 今日のゴール🎯✨

* ✅ **スタックトレース（エラーの行番号）が TS の `src/*.ts` を指す**
* ✅ VS Code で **TSの行にブレークポイント**が刺さる（刺さりやすくなる）🧷
* ✅ Docker/Compose でも同じノリでできる🐳

---

## 1) そもそも「ソースマップ」って何？🗺️💡

TypeScriptって、実行する前にだいたいこうなるよね👇

* `src/index.ts`（人間が読む用🧠）
* ↓ `tsc` で変換
* `dist/index.js`（Nodeが実行する用⚙️）

このとき、エラーが起きると **普通は `dist/index.js:1234`** みたいな行番号になるんだけど…
**ソースマップがあると、`src/index.ts:12` に“戻して”表示できる**んだよ〜〜🥳

ポイントは2つだけ👇

1. **TypeScriptがソースマップを出す**（`tsconfig.json` の設定）([Visual Studio Code][2])
2. **Nodeがソースマップを使う**（`node --enable-source-maps`）([Node.js][3])

---

## 2) 30秒で体感ハンズオン🚀（わざとエラー出す）

### 2-1. 最小プロジェクトを作る📦✨

（フォルダは好きな名前でOK）

```bash
mkdir sourcemap-demo
cd sourcemap-demo
npm init -y
npm i -D typescript
```

`src/index.ts` を作って、わざと落とす👇

```ts
function boom() {
  throw new Error("うわっ！わざと落とした💥");
}

boom();
```

### 2-2. `tsconfig.json` を“ソースマップON”で用意🧩

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "CommonJS",
    "rootDir": "src",
    "outDir": "dist",

    "sourceMap": true,
    "strict": true
  }
}
```

* `sourceMap: true` で **`dist/index.js.map` が生成**されるよ🗺️([TypeScript][4])

ビルド！

```bash
npx tsc
```

---

## 3) 「ソースマップ無し」と「有り」で差を見る👀✨

### 3-1. ソースマップ無し（普通に実行）😇

```bash
node dist/index.js
```

だいたいこんな感じで **`dist/index.js`** を指しがち👇

* `... at boom (dist/index.js:??:??)`

### 3-2. ソースマップ有り（幸せスイッチON）🥰

```bash
node --enable-source-maps dist/index.js
```

これで **`src/index.ts` の行番号**に寄せて表示されるようになる！
Nodeはこのフラグで、ソースマップを読んでスタックトレースを“元のソース位置”に合わせにいくよ🧠✨([Node.js][3])

---

## 4) いつも使える形にする（npm scripts）🧰✨

`package.json` の `scripts` をこうしておくとラク👍

```json
{
  "scripts": {
    "build": "tsc",
    "start": "node --enable-source-maps dist/index.js"
  }
}
```

以後はこれでOK！

```bash
npm run build
npm run start
```

---

## 5) ちょい応用：ソースマップの種類（外出し / インライン）🧠🗺️

### A. ふつう（おすすめ）✅：`sourceMap: true`

* `dist/index.js.map` が別ファイルで出る
* サイズが膨れにくい💪

### B. インライン：`inlineSourceMap: true`（好み）🧃

`.js` の中にソースマップを埋め込む方式。
「`.map` ファイルのコピー忘れ」が起きにくいのが利点👍
（ただし `.js` がデカくなる）([TypeScript][5])

---

## 6) Docker/Composeで使うときのコツ🐳✨

### 6-1. Dockerfile の起動コマンドで付ける（わかりやすい）✅

```dockerfile
CMD ["node", "--enable-source-maps", "dist/index.js"]
```

### 6-2. Compose の `command:` でも同じ🍱

```yaml
services:
  app:
    command: node --enable-source-maps dist/index.js
```

「どこで起動しても `--enable-source-maps` 付き」が大事だよ〜😆

---

## 7) VS Codeで“TSの行にブレークポイント”を刺す🧷🕹️

VS Codeのデバッグは **ソースマップ対応**してるよ！([Visual Studio Code][2])
まずはシンプルに「ビルドしてから dist をデバッグ」がおすすめ👍

`.vscode/launch.json` 例👇

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug dist (source maps)",
      "type": "pwa-node",
      "request": "launch",
      "program": "${workspaceFolder}/dist/index.js",
      "runtimeArgs": ["--enable-source-maps"],
      "outFiles": ["${workspaceFolder}/dist/**/*.js"]
    }
  ]
}
```

流れはこれ👇

1. `npm run build`（ターミナルでOK）🔨
2. VS CodeでF5 ▶️（上の構成を選ぶ）
3. TS側に置いたブレークポイントが効きやすくなる🧷✨

---

## 8) つまずきポイント集（ここが9割）💣🧯

### ❌ 1) `.map` が無い / 配置がズレてる

* `dist/index.js.map` が存在する？
* `dist/index.js` の末尾に `sourceMappingURL` が付いてる？（`tsc` がやってくれるはず）

### ❌ 2) `outDir` / `rootDir` がぐちゃぐちゃ

* `rootDir: "src"`
* `outDir: "dist"`
  この“王道配置”に戻すと直ること多い👍

### ❌ 3) 「本番用イメージ」に `.map` を入れ忘れた

* 本番用に `dist` だけコピーしてると、`.map` だけ漏れることある😇
* その場合は `COPY dist ./dist` が `.map` も含む形になってるかチェック！

### ❌ 4) なんか重い気がする

`--enable-source-maps` はソースマップを読んで変換する分、コストが出ることがあるよ（環境や規模次第）([GitHub][6])
まずは **開発時にON** が鉄板✨

---

## 9) ミニ課題🎓🔥（手を動かすと定着する）

### 課題A：エラーの行番号を“TS側”に戻せ✅

* `node dist/index.js` と
* `node --enable-source-maps dist/index.js`
  で、スタックトレースがどう変わるか確認👀✨

### 課題B：`inlineSourceMap` に変えてみる🧃

* `.map` が消えて `.js` が大きくなるのを観察してみよう😆([TypeScript][5])

### 課題C：VS Codeでブレークポイント🧷

* `src/index.ts` の `throw` 行にブレークポイント置いて、F5で止める！

---

## まとめ🏁🎉

* **TS側**：`sourceMap: true`（または `inlineSourceMap`）で地図を作る🗺️([TypeScript][4])
* **Node側**：`node --enable-source-maps` で地図を使う🧭([Node.js][3])
* これで **“distの謎行番号”から解放**される！😆✨

次の章（第26章）に行く前に、もし「Dockerコンテナ内でVS Codeデバッガをアタッチ（9229）したい」方向に寄せた“実戦版”も欲しければ、その形でサンプルも作るよ〜🐳🕹️

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://code.visualstudio.com/docs/typescript/typescript-debugging?utm_source=chatgpt.com "Debugging TypeScript"
[3]: https://nodejs.org/api/cli.html?utm_source=chatgpt.com "Command-line API | Node.js v25.6.0 Documentation"
[4]: https://www.typescriptlang.org/docs/handbook/compiler-options.html?utm_source=chatgpt.com "Documentation - tsc CLI Options"
[5]: https://www.typescriptlang.org/tsconfig/inlineSourceMap.html?utm_source=chatgpt.com "TSConfig Option: inlineSourceMap"
[6]: https://github.com/nodejs/node/issues/41541?utm_source=chatgpt.com "--enable-source-maps is unnecessarily slow with large ..."
