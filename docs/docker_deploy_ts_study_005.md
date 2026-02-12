# 第05章：devとprodの違い：同じじゃないよ問題 🙅‍♂️

開発中って、便利グッズ（自動リロード・型チェック・デバッガ・テスト）が山盛りですよね😆🧰
でも本番は「便利さ」より **軽さ・確実さ・安全さ** が大事になります💪🔥
ここを分けないと、**「ローカルでは動くのに本番で死ぬ😇」** が起きます。

（ちなみに本日時点だと Node は **v24 が Active LTS / v25 が Current** という状態です📌）([Node.js][1])

---

## この章のゴール 🎯✨

この章が終わると👇ができるようになります！

* ✅ **本番起動コマンドを1行で固定**できる（例：`npm run start`）🚀
* ✅ **devDependencies / dependencies を仕分け**できる 🧹
* ✅ TypeScript を **本番では「ビルド済みJS」で動かす**イメージがつく 🏗️
* ✅ Dockerfile が呼ぶべき「本番の形」が分かる 🐳

---

## 1) dev と prod は「優先順位」が違う 😺↔️🦁

ざっくり言うと👇

* **dev（開発）**：速く試す・すぐ直す・観察する 👀⚡

  * 例：ホットリロード、型チェック、テスト、詳細ログ
* **prod（本番）**：軽く動く・落ちにくい・再現できる 🛡️📦

  * 例：余計な依存を入れない、ビルド成果物だけで起動、設定は外出し

そして Node 自体は「開発/本番で設定が必須」ってわけじゃないけど、**多くのライブラリが `NODE_ENV` を見て挙動を変える**ので、本番は `NODE_ENV=production` が基本になります🧠🔑([Node.js][2])

---

## 2) “同じじゃない”ポイントは3つだけ覚えればOK 🧠✨

## A. 依存（Dependencies）📦

* **dependencies**：本番で実行に必要（例：express、DBクライアント）
* **devDependencies**：開発で必要（例：typescript、eslint、テスト系、ビルド系）

> 本番コンテナに devDependencies を入れると、サイズ増える＋攻撃面増える＋起動遅くなる…になりがち😵‍💫🧨
> （Node/Docker系のセキュリティ観点でも「本番依存だけ」が推奨）([OWASP Cheat Sheet Series][3])

---

## B. 成果物（Build artifacts）🏗️

TypeScript のまま本番で動かすんじゃなくて、

* dev：`src/*.ts` を監視して実行（速い・便利）👟
* prod：`dist/*.js` に **ビルドしてから** `node dist/...` で起動（軽い・確実）🧱

---

## C. 起動コマンド（Start command）🚀

**本番起動は“1行で固定”が超大事**です。

* ✅ 良い：`npm run start` → 中で `node dist/server.js`
* ❌ だめ：`ts-node src/server.ts` / `tsx watch ...` / `nodemon ...`（便利グッズを本番へ持ち込んでる😇）

---

## 3) ハンズオン：本番起動コマンドを「1行」で固定する 🧪🚀

ここから実際に整えます！😆✨
（今あるプロジェクトに合わせて名前は調整OKです）

## Step 1：`package.json` の scripts を “dev / build / start” に分ける 🧩

```json
{
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "build": "tsc -p tsconfig.build.json",
    "start": "node dist/server.js"
  }
}
```

ポイント👇😺

* `dev`：開発用（watchあり）👀
* `build`：TypeScript → JavaScript に変換 🏗️
* `start`：**本番用の起動**（watch禁止🚫）

> `NODE_ENV=production` を使うライブラリが多いので、本番はこれもセットで使う想定にすると◎です🛡️([Node.js][2])

---

## Step 2：`tsconfig.build.json` を作って “本番に要るTSだけ” をビルド対象にする ✂️📦

```json
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "dist",
    "sourceMap": true
  },
  "include": ["src/**/*.ts"],
  "exclude": ["**/*.test.ts", "**/*.spec.ts", "src/**/__tests__/**"]
}
```

これで「テストや開発用コードまで本番に混ざる」事故が減ります🧯✨

---

## Step 3：本番起動をローカルで再現する（超大事）🧪🔥

まずビルドして、

```powershell
npm run build
```

次に「本番モードっぽく」起動！

```powershell
$env:NODE_ENV="production"
npm run start
```

> `npm install` は `NODE_ENV=production` だと devDependencies を入れない挙動があるので、環境変数は“影響が出るもの”として意識しておくと安全です🧠([docs.npmjs.com][4])

---

## 4) 依存の仕分け：迷ったらこのルールでOK 🧹✨

## ✅ dependencies に入れがちなもの

* Webフレームワーク（Express/Fastify など）🌐
* DBクライアント、ORM（Prisma/Drizzle など）🗄️
* バリデーション（zod など）✅
* 画像・暗号・HTTPクライアントなど「実行時に使う」もの 🧰

## ✅ devDependencies に入れがちなもの

* TypeScript / tsx / ts-node 🧠
* ESLint / Prettier ✨
* テスト（Vitest/Jest）🧪
* 型定義 `@types/*` 🏷️

npm の公式も「dependencies / devDependencies に分けて書く」前提で説明しています📚([docs.npmjs.com][5])

---

## 5) “本番はクリーン”のコツ：`npm ci` を知っておく 🧊⚙️

CI/CD や本番ビルドでは、基本 **`npm ci`** が向いてます✅
理由：ロックファイルに厳密で「毎回同じ依存」を作りやすいからです🔒([docs.npmjs.com][6])

---

## 6) Docker 的には、ここが整ってると勝ち確 🐳🏆

Dockerfile は次の章以降でガッツリやるけど、第5章の時点で覚えておくことはシンプル👇

* Dockerfile は結局、だいたいこの流れをやりたい

  1. 依存入れる 📦
  2. ビルドする 🏗️
  3. 本番起動する 🚀
* だから **`npm run build` と `npm run start` が整ってる**と、Docker 化がスッ…と進む😆✨

おまけ：本番では **devDependencies を落としたい**ので、npm には `--omit=dev` や `npm prune` みたいな道具があります🧹（`npm prune` は `--omit=dev` や `NODE_ENV=production` で devDependencies を削る挙動が説明されています）([docs.npmjs.com][7])

---

## 7) つまずきTop5 😵‍💫➡️✅

## ① start が `ts-node` / `tsx` になってる 😇

✅ 対処：`start` は **node + dist** に固定！
（`dev` にだけ watch を置く）👀

## ② `start` したら `dist` が無い 🤷‍♂️

✅ 対処：本番フローは **build → start** の順に。
CI/CD でもこの順にする。

## ③ 本番で必要なライブラリが devDependencies に入ってた 🧨

✅ 対処：実行時に `require/import` されるものは dependencies へ移動📦

## ④ `NODE_ENV=production` にしたら挙動が変わって焦る 😱

✅ 対処：ローカルでも一度 **production 相当で起動**して確認する（さっきの PowerShell 手順）🧪
Node界隈は `NODE_ENV` を見るライブラリが多いです([Node.js][2])

## ⑤ クラウドで「PORT が違う」で死ぬ 🔌💥

✅ 対処：`process.env.PORT` で受け取れるようにする（次章で詳しく！）
Cloud Run みたいに **`PORT` を注入する**環境が実在します([Google Cloud Documentation][8])

---

## 8) AIに投げる“コピペ用”プロンプト集 🤖✨

* 🤖「この `package.json` を見て、`dev/build/start` を分けた最小 scripts を提案して。理由も短く。」
* 🤖「この TypeScript プロジェクトを本番で `node dist/...` 起動できるように、`tsconfig.build.json` を作って。」
* 🤖「依存一覧（dependencies/devDependencies）を見て、実行時に必要なのに devDependencies にいるものを指摘して。」
* 🤖「`NODE_ENV=production` を前提に、起動時のログを最小で見やすくして。」

---

## ミニ課題 🎒📝

1. `npm run build` → `npm run start` が **必ず通る**状態にする ✅
2. `NODE_ENV=production` で起動しても、最低限の画面/APIが動くのを確認する ✅
3. dependencies/devDependencies を見直して、怪しいのを3つメモする📝👀

---

## 次章につながる予告 👀🐳

次の章では「**ローカルOKなのに本番NG**」の代表格、
`0.0.0.0` と `PORT` の話を “即効で潰す” ように進めます🔥（Cloud Run など実在のルールも絡みます）([Google Cloud Documentation][8])

---

必要なら、あなたの実プロジェクトの `package.json`（scriptsと依存だけでOK）を貼ってくれたら、**第5章の内容をそのプロジェクトに完全フィット**させた版（改善案＋差分つき）にして出します😆🛠️✨

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://nodejs.org/en/learn/getting-started/nodejs-the-difference-between-development-and-production?utm_source=chatgpt.com "Node.js, the difference between development and production"
[3]: https://cheatsheetseries.owasp.org/cheatsheets/NodeJS_Docker_Cheat_Sheet.html?utm_source=chatgpt.com "NodeJS Docker - OWASP Cheat Sheet Series"
[4]: https://docs.npmjs.com/cli/v8/commands/npm-install/?utm_source=chatgpt.com "npm-install"
[5]: https://docs.npmjs.com/specifying-dependencies-and-devdependencies-in-a-package-json-file/?utm_source=chatgpt.com "Adding dependencies to a package.json file"
[6]: https://docs.npmjs.com/cli/v9/commands/npm-ci/?utm_source=chatgpt.com "npm-ci"
[7]: https://docs.npmjs.com/cli/v9/commands/npm-prune/?utm_source=chatgpt.com "npm-prune: Remove extraneous packages"
[8]: https://docs.cloud.google.com/run/docs/container-contract?utm_source=chatgpt.com "Container runtime contract | Cloud Run"
