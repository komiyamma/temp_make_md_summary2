# 第12章：Dockerビルドを速くする“基本の型”⚡🧠

この章のテーマはシンプルです👇
**「ソースをちょっと直しただけなのに、毎回 `npm ci` で数分待つ…」を卒業する**こと！😆🚀

---

## 1) まず結論：速いDockerfileには“型”がある🧩✨

Dockerのビルドは、ざっくり言うと **Dockerfileの1行ずつが「積み木（レイヤー）」** です🧱
そして **前回と同じ積み木は再利用（キャッシュ）** されます♻️

でも逆に言うと…

* ある積み木が変わる
  → **その上に積んだ全部が作り直し** 😇💥

だから「変わりやすいもの（ソースコード）」と「変わりにくいもの（依存関係）」を分けて積むのが勝ち筋です🏆✨

---

## 2) キャッシュが死ぬ“ありがちなDockerfile”😱

悪い例（よく見るやつ）👇
ソースを先に `COPY . .` しちゃうと、**ソースを1行変えただけで依存インストールまで巻き込まれます**💣

```dockerfile
FROM node:24-bookworm-slim
WORKDIR /app

COPY . .              # ← ここで全部コピー（毎回変わりやすい）
RUN npm ci            # ← 毎回やり直しになりがち 😭

CMD ["npm", "run", "start"]
```

---

## 3) キャッシュが効く“基本の型”✅⚡

ポイントはこれだけ👇

1. **依存定義（package*.json）だけ先にCOPY**
2. **npm ci を先に実行**
3. 最後に **ソースコードをCOPY**

こうすると、ソースだけ変えた時は **依存インストールのレイヤーがキャッシュで再利用**されます♻️✨

```dockerfile
FROM node:24-bookworm-slim
WORKDIR /app

## ① 依存の定義ファイルだけ先にコピー
COPY package.json package-lock.json ./

## ② lockfile前提でクリーンインストール（再現性＆キャッシュに相性◎）
RUN npm ci

## ③ 最後にソースをコピー（ここはよく変わる）
COPY . .

CMD ["npm", "run", "start"]
```

この「型」が効く理由は、**依存が変わらない限り `npm ci` の行が“前回と同じ”扱いになって再実行されにくい**からです🧠✨

ちなみに `npm ci` は **lockfile必須**で、`package.json` とズレてたらエラーで止めてくれる（＝再現性に強い）仕様です🧼📦 ([docs.npmjs.com][1])

---

## 4) 体感しよう：キャッシュが効くか“目で見る”実験🔬👀

### 4-1) まず1回ビルド（初回は遅くてOK）🐢

PowerShellで👇

```powershell
docker build --progress=plain -t myapp:dev .
```

`--progress=plain` を付けると、ビルドログが追いやすくなります🧾✨（DockerのCLIオプションとして用意されています）([docs.docker.jp][2])

---

### 4-2) 次に「ソースだけ」ちょい変更✏️

例：`src/index.ts` のログ文だけ変える、とかでOK🙆‍♂️

---

### 4-3) もう1回ビルド（ここが本番）⚡

```powershell
docker build --progress=plain -t myapp:dev .
```

ここで理想は👇

* `COPY package*.json` はキャッシュ
* `RUN npm ci` もキャッシュ（または一瞬）
* `COPY . .` 以降だけが更新

ログ上で `CACHED` みたいな表示が出て、**体感で速くなります**😆🚀

---

## 5) さらに速くする“現代の裏技”：BuildKitのキャッシュマウント🧠⚡⚡

ここからは「効いたら気持ちいいやつ」😎✨
BuildKitには、ビルド中だけ使える **永続キャッシュ置き場**を作る機能があります（cache mount）♻️

Dockerの公式ドキュメントでも、`npm install` / `npm` のキャッシュを `RUN --mount=type=cache` で使う例が紹介されています📘 ([Docker Documentation][3])

しかもBuildKit自体、**Docker Desktopではデフォルト**、Docker Engineでも **23.0以降はデフォルト**です🧰✨ ([Docker Documentation][4])

### 5-1) こう書く（npmのダウンロードを再利用しやすくする）📦⚡

```dockerfile
FROM node:24-bookworm-slim
WORKDIR /app

COPY package.json package-lock.json ./

## BuildKitのキャッシュ領域をnpmキャッシュとして使う
RUN --mount=type=cache,target=/root/.npm npm ci

COPY . .

CMD ["npm", "run", "start"]
```

これの嬉しさは👇
「依存レイヤーが作り直しになったとしても、**ダウンロード済みのnpmキャッシュが残ってて速い**」になりやすい点です🏎️💨 ([Docker Documentation][3])

---

## 6) “速くならない”ときのチェックリスト🧯✅

### A. `package-lock.json` をコピーしてない / 更新されてない📌

* `package-lock.json` がないと `npm ci` は成立しません（または怒られます）😇
* lockと `package.json` がズレてると `npm ci` は止まります（それが正しい）🧼 ([docs.npmjs.com][1])

---

### B. 依存が毎回変わってる（例：`package.json` を頻繁に触ってる）🌀

* 依存を変えたら、当然 `npm ci` はやり直しになります
* 「ソースだけ変更」のときに速くなるのが主目的です🎯

---

### C. 何かおかしい時の“強制リセット”🧨

キャッシュが原因か切り分けたいときは👇

```powershell
docker build --no-cache --progress=plain -t myapp:dev .
```

---

## 7) ミニ理解テスト（3問）📝✨

1. `COPY . .` を `npm ci` より前に置くと何が起きやすい？😱
2. 依存が変わってないのに毎回 `npm ci` が走るとしたら、どのレイヤーが毎回変わってそう？🔍
3. BuildKitの `--mount=type=cache` は何を“永続化”してくれる？♻️

---

## 8) この章のゴール（できた判定）🏁🎉

次を満たせたら勝ちです🙌

* ソース1行だけ変更して `docker build` したときに **`npm ci` がほぼ走らない（キャッシュになる）** ✅
* `--progress=plain` のログで「どの行がキャッシュされたか」説明できる✅ ([docs.docker.jp][2])
* （おまけ）BuildKitのcache mountで **依存再構築でも速くなる**のを体感できた✅ ([Docker Documentation][3])

---

次の第13章は `.dockerignore` で「送るファイルを減らして地味に爆速」🚀🧹に入ります。
第12章の“キャッシュの型”ができてると、第13章がさらに気持ちよく効きますよ〜😆✨

[1]: https://docs.npmjs.com/cli/v8/commands/npm-ci?utm_source=chatgpt.com "npm-ci"
[2]: https://docs.docker.jp/engine/reference/commandline/build.html?utm_source=chatgpt.com "docker build — Docker-docs-ja 24.0 ドキュメント"
[3]: https://docs.docker.com/build/cache/optimize/?utm_source=chatgpt.com "Optimize cache usage in builds"
[4]: https://docs.docker.com/build/buildkit/?utm_source=chatgpt.com "BuildKit"
