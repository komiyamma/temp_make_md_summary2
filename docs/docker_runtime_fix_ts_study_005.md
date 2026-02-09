# 第05章：最初のゴール設定🎯✨（“動く”の定義）

この章はめちゃ大事です！😆
なぜなら、ここで「できた！」の基準を決めておくと、後の章で迷子にならないからです🧭✨
（Dockerって、やること増えると「何をもって成功？」がブレやすいんだよね…🫠）

---

## 1) まず“固定”の世界での「動く」を決めよう🔒🧠

ランタイム固定（Node/TSを閉じ込める）での「動く」は、**あなたのPCでたまたま動く**じゃなくて、こういう意味になります👇

* ✅ **誰のPCでも（未来の自分でも）同じ結果になる**
* ✅ **ビルド手順が再現できる**
* ✅ **Node/TSのバージョンが勝手に変わらない**

ちなみに本日時点では、Nodeは **v24がActive LTS**、v25がCurrent、v22がMaintenance LTS という扱いになっています。([Node.js][1])
TypeScriptは **5.9系が “latest” 扱い**（npmでも5.9.3がLatest表示）です。([npm][2])
（そしてTypeScript 6.0/7.0系は「進行中」扱いの話題も出てるので、学習の軸は当面 5.9 で安定させるのが気持ちラク😌）([Microsoft for Developers][3])

---

## 2) 第5章の“できた判定”✅✅✅（最小のDefinition of Done）

この章のゴールは「基準を作る」ことなので、**チェックリスト化**しちゃいましょう📋✨
あなたの“できた判定”はこれ👇

## ✅ DoD（Definition of Done：完成の定義）

* ✅ `docker build` が通る🐳
* ✅ `docker run` でアプリ（または検証用コンテナ）が起動する🚀
* ✅ Node/TSの版が **毎回同じ** になる🔁🔒

ここがブレなければ、後の章で「あれ、これ成功なの？」って悩む時間が激減します😊

---

## 3) “できた判定”を強くする追加ルール（おすすめ）💪✨

上の3つに、初心者ほど効く「事故防止ルール」を足します👇

* ✅ **バージョン表示を必ずどこかで出す**
  例：起動時ログに `node -v` / `npm -v` を出す、など👀
* ✅ 依存インストールは（後の章で）`npm ci` を基本にする
  `npm ci` は「クリーンに同じ依存を入れる」目的のコマンドとして公式に説明されています。([npmドキュメント][4])
* ✅ “固定の証拠”を残す（あとで自分が救われる）
  例：`docker image inspect` でベースイメージ確認、ビルドログ保存、など🧾✨

---

## 4) ミニ実習：まずは“動く”を最小で証明しよう🧪✨（1分でOK）

アプリ本体がまだ無くてもいいです。
**「毎回同じNodeが出る」**を、まず目で見て成功体験しよう😆

## 4-1. フォルダ作成📁

```bash
mkdir runtime-check
cd runtime-check
```

## 4-2. Dockerfileを作る🧱

`Dockerfile` を作成👇

```dockerfile
FROM node:24-bookworm-slim
WORKDIR /app

## “固定できてる証拠”を出す
RUN node -v && npm -v

## 実行時にも versions を表示（毎回同じなら勝ち！）
CMD ["node", "-p", "process.versions"]
```

> `node:24-bookworm-slim` みたいな「タグ」を決めるのも固定の一部だよ👍
> （タグ設計は後の章でガッツリやるので、今は“決める”だけでOK）

## 4-3. build（成功条件①）🏗️

```bash
docker build -t runtime-check .
```

## 4-4. run（成功条件②）🚀

```bash
docker run --rm runtime-check
```

出力に `node` のバージョンや `process.versions` が出たらOK🎉
そして、何回やっても同じ結果なら（成功条件③）もクリア！🔁✨

> `docker run` は公式ドキュメントでも基本の実行コマンドとして説明されています。([Docker Documentation][5])

---

## 5) ありがちな「成功っぽいのに失敗」パターン集🧯😵‍💫

## 😵 パターンA：buildは通るのにrunで落ちる

原因あるある👇

* CMD/ENTRYPOINTの指定ミス（ファイルパス違い）📄💥
* 依存が入ってない（COPY順やnpmコマンドの違い）📦💥
* ポート待ち受けしてないのに公開してる（Web系で多い）🌐💥

対策（今章の範囲）👇

* **「runできる最小」から始める**（今回の runtime-check がまさにそれ）😆
* まずは「起動して何か表示したら勝ち」に寄せる🏁

---

## 😵 パターンB：“毎回同じ”のつもりが、いつのまにか変わる

原因あるある👇

* `node:24` だけ指定していて、細かい差分が混ざる（更新タイミングで差が出ることがある）🔁
* lockfile運用が弱くて依存がズレる📦

対策👇

* タグを **明示して固定**（例：`node:24-bookworm-slim`）🏷️
* 依存は後の章で `npm ci` を基本にして“ズレたら止まる”を味方にする🧼🛑 ([npmドキュメント][4])

---

## 6) AI活用🤖✨：この章の成果物を“テンプレ文”にしておく

この章で作った **DoD（できた判定）**は、毎回使い回せます👍
Copilot / Codex にこう投げると早い👇

* 「Node/TSのランタイム固定の“Definition of Done”を3〜6項目で作って。`docker build` / `docker run` / 版固定の確認を含めて。初心者向けにチェックリスト形式で」✅📋
* 「Dockerfileの最小“バージョン表示用”テンプレを作って。`node -v` と `npm -v` と `process.versions` を出すだけのやつ」🐳🧱

“基準が文章化されてる”だけで、次の章からの学習がスイスイになります😆✨

---

## まとめ🏁✨（この章で手に入ったもの）

* 「動く」の基準が **言語化＆チェックリスト化**できた📋✅
* `docker build` / `docker run` / バージョン固定 の **3点セット**が成功条件になった🔒🔁
* 最小の検証（runtime-check）で「毎回同じ」を目で確認できた👀🎉

次の第6章で、いよいよ `docker run` だけで「閉じ込め体験」していきます🐳💨
この章で決めた基準を、そのまま“合格ライン”として使っていこうね😆👍

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://www.npmjs.com/package/typescript?utm_source=chatgpt.com "TypeScript"
[3]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
[4]: https://docs.npmjs.com/cli/v9/commands/npm-ci/?utm_source=chatgpt.com "npm-ci"
[5]: https://docs.docker.com/get-started/workshop/02_our_app/?utm_source=chatgpt.com "Part 1: Containerize an application"
