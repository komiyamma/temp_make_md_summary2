# 第15章：`node:alpine` をいきなり使わない理由🧊⚠️

この章のゴールはシンプルです👇
**「小さい＝正義じゃない」**を理解して、**最初の一歩で詰まらない選択**ができるようになること🧠✨

---

## 1) まず結論：最初は Debian系（`-slim`）がラク🥹👍

`node:alpine` は確かに小さいです。でも **初心者がハマりやすい地雷**が増えます💣
だから最初は、**Debian系の `-slim`（例：bookworm-slim）**を“標準装備”にしちゃうのが安全です🛡️✨

理由はこのあと全部説明します！

---

## 2) Alpineが小さい理由＝「入ってない物が多い」📦🧼

Docker の公式説明でも、`node:<version>-alpine` は

* **musl libc** を使う（一般的な **glibc** ではない）
* **git や bash などの周辺ツールが入ってない**ことが多い

…という “注意点つきの軽量版” として紹介されています。([Docker Hub][1])

さらに、Docker側の説明でも「迷ったらまず glibc（Debian系）にしとくと互換性の事故が減るよ」と、かなりハッキリ言っています。([Docker Documentation][2])

---

## 3) 初心者が `node:alpine` で踏みがちな地雷3連発💥💥💥

### 地雷①：`musl` と `glibc` の違いで「動くはずが動かない」🤯

世の中のバイナリ（とくに“ネイティブ拡張”）は **glibc 前提**が多いです。
Alpineは **musl** なので、依存が深いと

* インストールは通るのに実行時に落ちる😇
* 特定の機能だけ変な挙動になる😵‍💫
  みたいな事故が起きやすくなります。([Docker Hub][1])

---

### 地雷②：`npm ci` で突然ビルドが始まり、Pythonやgccが要求される🐍🔧

Nodeのパッケージには、JSだけじゃなく **C/C++で作られた“ネイティブアドオン”**を含むものがあります。
その場合、環境次第で **プリビルドが使えずコンパイル**に回ってしまいます💥

で、ここで登場するのが **node-gyp**（＝Pythonやビルドツールが必要になりがち）😇
Alpineは軽量ゆえに、そういう“ビルドに必要な道具”が最初から入ってないことが多いです。([Docker Hub][1])

結果、典型的には👇みたいな沼に入ります🫠

* `gyp ERR! find Python` 系のエラー
* `make: not found` / `g++: not found`
* 依存が増えたタイミングで急に死ぬ（昨日まで動いたのに！）

（実際、Alpineで解決するには `make gcc g++ python3` などを入れる…という“お決まりの追加”がよく登場します）([Qiita][3])

---

### 地雷③：`bash` や `git` がなくて、地味に詰む😵

開発系ツールやスクリプトは `bash` 前提なことがわりとあります。
でも Alpine系は **「小さくするために入れてない」**が普通です。([Docker Hub][1])

* `bash: not found`
* `git: not found`
* `curl: not found`（環境によって）

こういう“本筋じゃない詰まり”が増えるのがイヤなんですよね〜😇🌀

---

## 4) 「でも小さい方が良くない？」への現実的な答え📏😌

ここ大事👇
**Alpineを選ぶと、結局いろいろ入れてサイズ差が縮む**ことがよくあります。

たとえば調査例では、`node:<version>-slim` と `node:<version>-alpine` の差が「想像より小さめ」なケースも示されています（もちろん状況次第）。([iximiuz Labs][4])

なので最初のフェーズは：

* **事故らない（互換性）**
* **直しやすい（情報が多い）**
* **チームでも通じやすい（一般的）**

この3つが強い Debian系で走るのが勝ちです🏃‍♂️💨

---

## 5) じゃあ、いつ `node:alpine` を検討していい？✅🧊

このチェックが **全部YES** なら検討OKです👇✨

* ✅ 依存にネイティブアドオンがほぼ無い（or musl対応を理解してる）
* ✅ 追加するOSパッケージが明確（何を入れるか分かってる）
* ✅ CIでちゃんとテストしてる（起動確認だけじゃなく）
* ✅ 互換性トラブルが起きたときに切り分けできる
* ✅ “サイズ最優先”の理由がある（配布・起動・コストなど）

逆に、1つでも不安なら **まずは `-slim`** が安全です🛟✨

---

## 6) それでもAlpineを使うなら：最低限の「沼回避テンプレ」🧰⚠️

「とりあえず動かしたい」用の考え方はこれ👇

1. **ビルドが必要になりそう** → buildツールを入れる
2. **glibc前提のものが混ざる** → 互換レイヤは“最終手段”として検討（万能ではない）

Alpine側のWikiでも、glibcプログラムを動かす方法として `gcompat` などに触れていますが、**完全互換じゃない**前提で扱うのが安全です。([Alpine Linux][5])

例（“ビルドに必要になったら足す”雰囲気）👇

```dockerfile
FROM node:24-alpine

WORKDIR /app
COPY package.json package-lock.json ./

## ネイティブアドオンのビルドが必要になった時に入りがちなセット
RUN apk add --no-cache python3 make g++ \
  && npm ci --omit=dev

COPY . .
CMD ["node", "dist/index.js"]
```

ただし…これやると **「軽量のうま味」が薄れやすい**のがポイントです😇💦
（だからこそ、最初からDebian-slimで良いことが多い）

---

## 7) すぐ使える “判断フロー” 🧭✨

迷ったらこれでOK👇

* **開発・学習・個人開発の初期**：`node:<LTS>-bookworm-slim` ✅
* **サイズ最優先で、依存が軽くて、検証が回せる**：`node:<LTS>-alpine` を検討🧊
* **本番はさらに絞りたい**：まずは multi-stage や依存整理を先に（Alpineはその後でもOK）🔥

---

## 8) AIに投げる“沼脱出プロンプト”🤖🛟

GitHub Copilot や Codex に、これをそのまま貼ると切り分けが速いです👇

* 「`node:24-alpine` で `npm ci` が失敗した。ログはこれ。原因を “musl/glibc差” と “node-gyp(ビルドツール不足)” と “不足コマンド(bash/git等)” の3観点で分類して、最小の修正案を3つ出して」
* 「この依存ツリーにネイティブアドオンがあるか確認して。あるならパッケージ名と、Alpineでの対策候補（プリビルド/ビルド/置き換え）を教えて」

---

### ✅この章のまとめ🎁

* `node:alpine` は **小さいけどクセが強い** 🧊
* **musl/glibc差**と**ビルドツール不足**と**周辺ツール不足**で詰まりやすい💥
* 最初は **Debian系 `-slim`** がいちばんラクで再現性も高い👍✨

次章（第16章）で「開発ではソースをマウントして最速ループ🌀」に入ると、ここまでの判断が一気に“体感”になりますよ😆🔥

[1]: https://hub.docker.com/_/node "node - Official Image | Docker Hub"
[2]: https://docs.docker.com/dhi/core-concepts/glibc-musl/ "glibc and musl | Docker Docs"
[3]: https://qiita.com/maaaashi/items/36afba6787aea95f2f15?utm_source=chatgpt.com "Docker alpineベースの環境でnode-gypのエラーが出た"
[4]: https://labs.iximiuz.com/tutorials/how-to-choose-nodejs-container-image "A Deeper Look into Node.js Docker Images: Help, My Node Image Has Python!"
[5]: https://wiki.alpinelinux.org/wiki/Software_management?utm_source=chatgpt.com "Software management"
