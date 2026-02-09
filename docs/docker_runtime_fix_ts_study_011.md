# 第11章：`npm ci` を味方につける🧼📦

この章は「依存を“毎回同じ”にして、事故を未然に止める」ための超重要ピースです💪✨
一言でいうと、`npm ci` は **“ロックファイルどおりに、まっさらから復元するボタン”** です🔁🧊 ([docs.npmjs.com][1])

---

## 今日のゴール🎯

* `npm install` と `npm ci` の違いが説明できる😌
* 「ロックファイルがズレたら `npm ci` が怒る」理由が腹落ちする🔥 ([docs.npmjs.com][1])
* 依存事故が起きたときに **最短で直せる**🛠️✨

---

## 1) まずイメージ🧠💡「ロックファイル＝レシピの確定版」

* `package.json`：**だいたいこの材料でOK**（範囲指定が入ることが多い）
* `package-lock.json`：**今回これで作りました！の確定版レシピ**（具体的な材料の型番まで）📌

だから、**“毎回同じ味”** にしたいならロックファイルが主役になります🍳✨
そして `npm ci` は、その確定版レシピを **絶対に守る** 動きです🧷 ([docs.npmjs.com][1])

---

## 2) `npm install` と `npm ci` の違い（ここだけ覚えればOK）🧩✨

`npm ci` の特徴はこれ👇（重要順）

* ✅ **`package-lock.json`（または `npm-shrinkwrap.json`）が必須**
* ✅ **`package.json` とロックがズレてたら、更新せずにエラーで止まる**（←正義）
* ✅ **依存を追加する用途では使えない**（プロジェクト丸ごとインストール専用）
* ✅ **`node_modules` があったら消してから入れ直す**（クリーンを保証）
* ✅ **ロックや `package.json` を絶対に書き換えない**（凍結インストール）

全部、公式がハッキリそう言ってます📜✨ ([docs.npmjs.com][1])

---

## 3) まずは体験しよう😆🧪（5分で腹落ち）

プロジェクト直下でやるだけでOKです👇

```bash
## ① まずは通常インストール（ロックを作る）
npm install

## ② ロックがあるか確認
dir package-lock.json

## ③ いったんnode_modulesを消して…
rmdir /s /q node_modules

## ④ ロックどおりに“復元”
npm ci
```

💡ここで感じてほしいこと

* `npm ci` は **「え、勝手に直さないの？」ってくらい頑固**
* でもその頑固さが、**未来の事故を潰す** んです🔥🛡️ ([docs.npmjs.com][1])

---

## 4) いちばん大事な運用ルール📏✨（これだけで勝てる）

## ルールA：ロックファイルは必ずコミット🧷📌

* `package-lock.json` が無いと、`npm ci` はそもそも動けません🙅‍♂️ ([docs.npmjs.com][1])
* つまり **ロックが無い＝再現性が無い** になりやすいです😵‍💫

## ルールB：依存を変えるときは `npm install`（→ロック更新）🧰

* 依存追加/更新は `npm install <pkg>` などで行う
* その結果変わった `package-lock.json` も一緒にコミット✅

## ルールC：再現したい場面は `npm ci`（Dockerビルド・CI）🤖🐳

* 「毎回同じにしたい」ときは `npm ci` が向いてます
* ロックがズレたら **その場で止めてくれる** のが強い💥 ([docs.npmjs.com][1])

---

## 5) つまずき王👑「lockとpackage.jsonがズレてる」→直し方

典型エラー（イメージ）💣
「`npm ci` can only install packages when your package.json and package-lock.json ... are in sync」みたいなやつです😇

## 直し方（最短）🛠️

```bash
## ① まずロックを正しい状態に更新
npm install

## ② 差分が出たら commit（ここ超大事）
## git diff で package-lock.json を確認してコミット

## ③ もう一回 clean install で検証
npm ci
```

ポイントはこれ👇

* `npm ci` は **ロックを直してくれません**（直す役は `npm install`） ([docs.npmjs.com][1])
* `npm ci` が怒るのは **「ズレたまま進むと事故るよ！」** の合図です🚨✨ ([docs.npmjs.com][1])

---

## 6) Dockerfileでの“勝ちパターン”🐳🏆（復習＋理由）

Dockerビルドでよく使う並びがこれ👇（キャッシュも効く）

```dockerfile
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
```

* `package.json / package-lock.json` が変わらない限り、`npm ci` の層が再利用されて速い⚡
* ロックどおりに入るから、**ビルドの再現性が上がる**🧊✨ ([docs.npmjs.com][1])

---

## 7) “フラグ地獄”を避ける小ワザ🧯（超重要）

もし過去にこんな感じでインストールしてたら👇

* `--legacy-peer-deps`
* `--install-links`
  みたいな **依存ツリーの形を変えるフラグ** を使ってた可能性があります。

この場合、公式がこう言ってます👇
「ロックをそのフラグ付きで作ったなら、`npm ci` も同じフラグ（または設定）で実行しないとエラーになりがち」🧨
そして解決策として **プロジェクトの `.npmrc` に設定してコミットすると楽**、とも書いてあります🧾✨ ([docs.npmjs.com][1])

---

## 8) 章末チェック✅📝（5問で定着）

1. `npm ci` に `package-lock.json` が必須なのはなぜ？📌
2. `npm ci` がズレを「自動修正」しないのはなぜ？🧊
3. 依存を1つ追加したい。使うのは `npm install` / `npm ci` どっち？🤔
4. `npm ci` が `node_modules` を消す理由は？🧹
5. フラグ付きで作ったロックを `npm ci` で使うときに注意することは？🧯 ([docs.npmjs.com][1])

---

## 9) ミニ課題🎒✨（手を動かすと一気に理解できる）

## 課題A：わざとズラして、`npm ci` に止めてもらう🚨

1. `npm install` 済みの状態を作る
2. `package.json` の依存バージョンを手でちょっと変える（※あえて）
3. `npm ci` を実行して、エラーで止まるのを確認
4. `npm install` でロックを更新して直す
5. もう一度 `npm ci` で通るのを確認✅

この“止めてもらう体験”が、あとであなたを救います😆🛟 ([docs.npmjs.com][1])

---

## 10) 今どきメモ🗓️✨（2026-02-09時点）

* Node 24 系は npm 11 を同梱、npm 11系が現役です📦 ([nodejs.org][2])
* npm CLI は 11.9.0 が “Latest” として案内されています🆕 ([GitHub][3])

---

## まとめ🎁✨

* `npm ci` は **ロックファイルの“完全再現”** 装置🧼
* ズレたら止まる＝**あなたの味方**🚨
* 依存をいじるときは `npm install`、再現したいときは `npm ci` の使い分けで勝てます🏆 ([docs.npmjs.com][1])

次の章（Dockerビルド高速化）に行く前に、もし `npm ci` で詰まったログが出たら、そのログ貼ってくれたら「最短で直す手順」だけに絞って案内します😆🧯

[1]: https://docs.npmjs.com/cli/v11/commands/npm-ci/ "npm-ci | npm Docs"
[2]: https://nodejs.org/en/blog/release/v24.0.0?utm_source=chatgpt.com "Node.js 24.0.0 (Current)"
[3]: https://github.com/npm/cli/releases?utm_source=chatgpt.com "Releases · npm/cli"
