# 第15章：node_modules問題（どこに置く？）📦😮

〜「Cannot find module」地獄から卒業しよう！🎓✨

---

## 0. 今日のゴール🏁😆

この章が終わったら、これができるようになります👇

* ✅ **node_modules が“消える/壊れる/遅い”理由**を説明できる
* ✅ **Docker開発での正解パターン（3つ）**を選べる
* ✅ **Composeで node_modules をコンテナ側に隔離**できる
* ✅ Windows＋Docker Desktop＋WSL2で**重くならない置き方**がわかる

---

## 1. そもそも「node_modules問題」って何？🤔💥

Docker開発でありがちな流れ👇

1. Dockerfile で `npm install`（または `npm ci`）して **コンテナ内に node_modules ができる**
2. でも Compose で `.:/app` みたいに **プロジェクト全体をマウント**する
3. すると… **/app の中身がホスト側で上書き**される
4. 結果：コンテナ内で作った `node_modules` が見えなくなる（＝消えたように見える）😇

この「マウント上書き」タイプのトラブルが **node_modules問題**の正体です。
「マウントが勝つ」ので、Dockerfileで頑張って入れた依存が無かったことにされます🫠（※これはよくある罠として解説されています）([Latenode Official Community][1])

---

## 2. 症状あるある（1つでも当てはまったら本章の出番）🧯😵

* ❌ `Error: Cannot find module 'xxx'`
* ❌ `node_modules` が空っぽ / 生成されない
* ❌ 依存を入れ直しても、再起動するとまた壊れる
* ❌ Windows環境だと **ホットリロードが激遅**（ファン爆回り）🌀
* ❌ ネイティブ依存（例：bcrypt系など）でビルドがコケる

---

## 3. なぜ Windows だと特に詰まりやすいの？🪟🪤

ポイントはここ👇

* Windows/macOS の Docker は **VM（仮想マシン）上で Linux コンテナ**を動かす
* そのため bind mount（ホストのフォルダ共有）は **VM境界をまたぐ**
* `node_modules` は小さいファイルが大量で、ここが **激重ポイント**になりやすい

つまり、**node_modules を bind mount に巻き込むと遅くなりがち**です。
VS Code の Dev Containers 公式ドキュメントも「Windows/macOSでは bind mount は遅くなりやすい → named volume が有利」とはっきり書いてます。([Visual Studio Code][2])

---

## 4. 2026年2月時点の“現実的な方針”🧭✨

まず前提の確認（迷わないための地図）👇

* 開発の安定性を重視するなら **NodeはLTSが基本**
  2026/02時点だと、Node v24 が Active LTS、v25 は Current（最新系）です。([Node.js][3])

この章では、**開発体験が安定しやすい “node_modules をコンテナ側に隔離”** を中心にいきます😊

---

## 5. 正解パターンは3つ（おすすめ順）🥇🥈🥉

### 🥇 パターンA：node_modules を「コンテナ側（volume）」に隔離する（王道）👑

**結論：これがいちばん事故りにくい！**
やることはシンプル👇

* ソースコードは `.:/app` で共有（ホットリロードOK）
* でも `node_modules` だけは **別マウントで上書きして隔離**する

Docker公式ブログでも「node_modules をホストに見せないために“空の（別の）マウント”で覆う」というテクが紹介されています。([Docker][4])
そして日本語でも、Composeで `- /app/node_modules`（Anonymous Volume）にして隔離するのが定番としてまとまっています。([Zenn][5])

---

### 🥈 パターンB：リポジトリごと “コンテナボリューム” に置く（速さ最強）🚀

VS Code Dev Containers を使う場合に強いです。

* “ホストのファイル共有”を減らせる
* **Windows/macOSでとにかく速い**（ボリューム＝Linux側に寄せる）

VS Code公式が「Clone Repository in Container Volume」を用意してて、これがまさにこの思想です。([Visual Studio Code][2])

---

### 🥉 パターンC：ホスト側に node_modules を置く（楽だけど罠多め）⚠️

* 依存が純JSだけなら動くこともある
* でも LinuxコンテナとWindowsホストで差が出たり、ネイティブ依存で詰まったりしやすい

「後でハマりがち」なので、この教材では**基本おすすめしません**🙂

---

## 6. ハンズオン：わざと壊して → 直す（最短で理解）🧪😆

### 6.1 まず“壊れる構成”（再現）💥

`compose.yml` がこうなってるとします（例）👇

```yaml
services:
  api:
    build: .
    volumes:
      - .:/app
    ports:
      - "3000:3000"
```

Dockerfile で `npm ci` してても、起動時に `.:/app` が **/app を丸ごと上書き**するので、`/app/node_modules` がホスト側に無ければ…

* コンテナ視点だと **node_modules が無い**
* 結果：`Cannot find module` 😇

この「マウントが中身を上書きするせいで依存が消える」問題は頻出です。([Latenode Official Community][1])

---

### 6.2 解決：node_modules を “別マウントで上書き” する（Anonymous Volume版）🛟

Composeをこう変えます👇（超定番）

```yaml
services:
  api:
    build: .
    volumes:
      - .:/app
      - /app/node_modules
    ports:
      - "3000:3000"
```

ポイント👇

* 先に `.:/app` で全体を共有
* 次に `/app/node_modules` を **別マウントで上書き**
  → これで `node_modules` は **ホストの影響を受けない独立領域**になる🎉

この形は「node_modules をコンテナ内で独立させる解決策」としてよく紹介されています。([Zenn][5])

---

### 6.3 さらに良い：Named Volume版（後片付けしやすい）🧹✨

Anonymousだと「どれがどれだっけ？」になりがちなので、教材的には Named が分かりやすいです😄

```yaml
services:
  api:
    build: .
    volumes:
      - .:/app
      - todo-api-node_modules:/app/node_modules
    ports:
      - "3000:3000"

volumes:
  todo-api-node_modules:
```

✅ これで

* node_modules は **Dockerが管理する領域（高速寄り）**
* 必要なら `docker volume rm ...` で掃除も簡単

「Windows/macOSでは named volume がパフォーマンス面で有利」も公式に言及があります。([Visual Studio Code][2])

---

## 7. “依存をどこで入れる？”の運用ルール（迷子防止）🧠🧷

### 7.1 基本ルール（おすすめ）✅

* **依存のインストールはコンテナ内**でやる
* それを **volume に保持**する
* ホスト側はソースだけ持つ

これが一番「環境差」で壊れにくいです🙂

---

### 7.2 Dockerfile側のコツ（キャッシュが効く順番）🧱⚡

ビルドを速くする鉄板👇

1. `package.json` と lockfile だけ先にコピー
2. `npm ci`（lockfileに忠実＆再現性）
3. そのあとソースをコピー

`npm ci` は lockfile を元にクリーンに入れて、CIやDockerビルドでの再現性に向く、という説明がよくまとまっています。([Stack Overflow][6])

---

## 8. Windows＋WSL2で「重い…」を回避する裏ワザ🪟➡️🐧⚡

node_modules以前に、そもそも **ファイル置き場**で速度が変わることがあります。

* リポジトリを **WSL2側のファイルシステム上**に置く
* そして **WSL2側から `code .` でVS Codeを開く**

これでパフォーマンス改善する、という報告・解説が複数あります。([Zenn][7])

---

## 9. AI活用（この章でガチ効くやつ）🤖✨

### 9.1 “あなたの構成に合う方針”をAIに決めさせる🧠

そのまま貼ってOK👇

```text
Docker ComposeでNode/TypeScriptを開発しています。
Windows + Docker Desktop + WSL2です。
ソースはbind mountしたい（ホットリロードしたい）けど、node_modulesで詰まりたくないです。

次の3案のうち、私に最適な案と理由、compose.ymlの完成例をください：
A) node_modulesをanonymous/named volumeで隔離
B) リポジトリごとcontainer volumeに置く（Dev Containers方式）
C) ホスト側にnode_modulesを置く
```

---

### 9.2 エラー貼り付け用テンプレ🧯

```text
このエラーの原因候補トップ3と、確認コマンド、最短の直し方を教えて：
（ここに logs / stack trace / compose.yml / Dockerfile を貼る）
```

---

## 10. よくある質問（FAQ）🙋‍♀️🙋‍♂️

### Q1. なんで node_modules をホストと共有しちゃダメなの？🫣

A. 小ファイル大量＋OS差分で壊れやすいからです。特にWindows/macOSはVM境界で遅くなりがちで、公式も named volume を推しています。([Visual Studio Code][2])

### Q2. `- /app/node_modules` って何？こわい😨

A. それは「そのパスをコンテナ側のボリュームとして扱う」指定です。結果として **ホストのnode_modulesに引っ張られなくなる**のが目的です。([Zenn][5])

### Q3. 直したのにまだ遅い…😵

A. リポジトリの置き場が Windows 側（NTFS）で、WSL2側から開けてないケースが多いです。WSL2側に置いて `code .` が効きます。([Zenn][7])

---

## 11. 章末ミッション（できたら勝ち🏆）🎮✨

### ミッションA（基本）🥉

* Composeで `node_modules` を **Anonymous Volume** にして起動
* `Cannot find module` が消えるのを確認

### ミッションB（実務）🥈

* Named Volume に変更して、`docker volume ls` で確認
* `docker compose down` しても依存が残るのを確認

### ミッションC（速度）🥇

* リポジトリを WSL2側に置いて、WSL2側から VS Code を開く
* 体感でいいので「速くなった？」を確認

---

## 12. まとめ（この章の一言）📌😄

* **node_modules は “ソースと一緒にマウントしない” が正解**
* Composeで

  * `.:/app`（ソース）
  * `/app/node_modules`（別ボリューム）
    に分けるだけで、トラブルが激減します🎉([Zenn][5])
* Windows/macOSは特に、**named volume がパフォーマンス面で有利**です🚀([Visual Studio Code][2])

---

次の第16章は「ボリューム作成・一覧・削除（基本運用）」なので、ここで作った `todo-api-node_modules` を“安全に片付ける筋トレ”もしていきます🧹😆

[1]: https://community.latenode.com/t/node-modules-missing-from-mounted-volume-after-successful-npm-install-in-docker-container/27833?utm_source=chatgpt.com "Node modules missing from mounted volume after ..."
[2]: https://code.visualstudio.com/remote/advancedcontainers/improve-performance?utm_source=chatgpt.com "Improve disk performance"
[3]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[4]: https://www.docker.com/blog/keep-nodejs-rockin-in-docker/?utm_source=chatgpt.com "Top 4 Tactics To Keep Node.js Rockin' in Docker"
[5]: https://zenn.dev/duckdevv/articles/1f680e4debbf2d?utm_source=chatgpt.com "Docker 開発での node_modules マウント、Anonymous ..."
[6]: https://stackoverflow.com/questions/52499617/what-is-the-difference-between-npm-install-and-npm-ci?utm_source=chatgpt.com "What is the difference between \"npm install\" and \"npm ci\"?"
[7]: https://zenn.dev/onozaty/articles/devcontainer-performance?utm_source=chatgpt.com "Dev Containers のパフォーマンス改善"
