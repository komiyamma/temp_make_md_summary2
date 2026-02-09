# 第19章：Nodeの `--watch` を知る👀🔁

この章は「**コードを直したら、自動でプロセスが再起動する**」を **Node標準機能だけで**やれるようになる回です😆✨
（昔は `nodemon` が定番だったけど、Node側がどんどん強くなってます💪）

---

#### この章のゴール🎯✨

* `node --watch` が **何をして / 何をしないか**が言える👄
* `--watch` を **Composeの開発コマンド**に組み込める🐳🧩
* Windows + Docker で **watchが効かない時の原因**が分かる🕵️‍♂️

---

## 1) `node --watch` ってなに？🤔

`node --watch` は、**監視対象のファイルが変わったら Nodeプロセスを再起動**してくれる機能です🔁
開発中の「保存 → 自分で止めて起動し直す」を消せます🧹✨

* watch中は、変更が入るたびに **プロセスを再起動**します
* デフォルトでは **エントリポイント（最初に実行したファイル）＋ import/require で読んだモジュール**を監視します👀
* `--watch-preserve-output` で、再起動時にコンソールを消さない設定もできます🧾✨ ([Node.js][1])

さらに、Node v22 / v20.13 以降では **watch mode が stable（安定扱い）**になっています🟢 ([Node.js][2])

---

## 2) よくある勘違い⚠️（ここ大事）

* ❌ **ホットリロード(HMR)** ではない
  → つまり「状態を保ったまま差分だけ反映」ではなく、**プロセス丸ごと再起動**です🔁😇
* ✅ サーバー系（API・Bot・CLI・小さめの常駐処理）なら **再起動で十分**なことが多い👍

---

## 3) まずは体感！最小の `--watch` 実験👣✨

### 実験A：1ファイルを監視して再起動する🔁

1. `src/index.js` を作る✍️

```js
console.log("boot:", new Date().toISOString());

setInterval(() => {
  console.log("tick:", new Date().toISOString());
}, 2000);
```

2. watch起動する🏁

```bash
node --watch src/index.js
```

3. どこでもいいので `src/index.js` を保存（空行追加とか）📝
   → **プロセスが再起動**して、また `boot:` が出ます😆 ([Node.js][1])

---

### 実験B：ログが消えるのが嫌なら `--watch-preserve-output` 🧾✨

```bash
node --watch --watch-preserve-output src/index.js
```

再起動してもコンソールが消えにくくなるので、ログを追いやすいです👀✨ ([Node.js][1])

---

## 4) Composeに組み込む（開発コマンドの型）🐳🧩

「保存したら勝手に再起動」を Compose でやる例です👇

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - node_modules:/app/node_modules
    command: node --watch src/index.js

volumes:
  node_modules:
```

ポイント💡

* `--watch` は **必ず“実行ファイルのパス”が必要**です（無いと終了コード9で落ちます）💥 ([Node.js][1])
* `node --watch` は、`--eval` や REPL と一緒に使えない…などの制約があります（困ったら「それ無理なんだな」でOK）🧯 ([Node.js][1])

---

## 5) ⚠️Windows + Docker の “watch効かない問題” を攻略する🪟🐳

ここ、初心者がめちゃ踏みます💣💥
原因はだいたいこれ👇

### あるある原因😵

* Windows側のフォルダを Linuxコンテナへ bind mount したとき、
  **ファイル変更イベント（inotify）がコンテナに届かない / 遅い**ことがある📉

公式のベストプラクティスとして、
**bind mount するなら「Linuxファイルシステム上（WSL2側）にソースを置く」**のが推奨されています✅
そして、Linuxコンテナが変更イベントを受けやすいのも「Linuxファイルシステムにあるファイル」だと明記されています📌 ([Docker Documentation][3])

### まず最優先の解決策🥇✨

* プロジェクトを **WSL2のLinux側（例：`\\wsl$` の中）**に置いて運用する🐧
  → watchの反応が激変することが多いです⚡ ([Docker Documentation][3])

---

## 6) `--watch-path` ってどうなの？🧭

`--watch-path` で「監視するパスを追加できる」…のですが、注意点が強めです⚠️

* `--watch-path` を使うと、**import/require の自動監視はオフ**になります（挙動が変わる）
* さらに、ドキュメント上 **macOS と Windows のみ対応**で、対応してない環境ではエラーになります💥
  → つまり **Linuxコンテナ内では使えない**ケースが普通にありえます😇 ([Node.js][1])

なのでこの教材では、まずは **`node --watch <entry>` の基本形**を主役にします🎯

---

## 7) トラブル時のチェックリスト✅🧯

watchが動かない / 遅い / 二重に反応する…時は👇

* ✅ ソースが **Windows側フォルダ**にある？ → **WSL2側へ移動**（最優先）🐧 ([Docker Documentation][3])
* ✅ 監視対象に `.git/`, `node_modules/`, `dist/` を含めてない？ → 重くなる原因😵
* ✅ `volumes:` で `node_modules` をホストと混ぜてない？ → 変な差分が出やすい💣
* ✅ それでもダメなら、watch方式を **別手段（後の章の tsx / 他ツール）**に切り替えるのも戦略🧠✨

---

## 8) （次章につながる）TSと合わせる時の発想🧩✨

TypeScriptはそのままだと Node が実行できないことが多いので、王道はこう👇

* `tsc -w` で `dist/` を作る👷
* `node --watch dist/server.js` で再起動する👀🔁

この「2プロセス構成」が次の章の土台になります🛣️✨
（ちなみに `tsc --watch` 自体も、Node の監視機能に依存していて、方式のメリデメがあります） ([typescriptlang.org][4])

---

## 9) AI（Copilot / Codex）に投げる一言例🤖💬

* 「Composeの `command` を `node --watch` にして、保存で再起動する開発環境を作って」🐳
* 「Windows+Dockerでwatchが効かない時の原因と対策（WSL2運用）を手順化して」🪟🐧
* 「`tsc -w` と `node --watch dist/...` を同時起動する `package.json scripts` を作って」🧩

---

## まとめ🎁✨

* `node --watch` は **変更でプロセス再起動**の標準機能👀🔁 ([Node.js][1])
* v22 / v20.13 以降で **stable（安心して使いやすい）**🟢 ([Node.js][2])
* Windows + Docker は **置き場所（WSL2側）で勝負が決まる**ことが多い🐧⚡ ([Docker Documentation][3])

次の章（第20章）では、この watch を **TypeScript開発の王道2ルート**に接続して、「迷子にならない選択」ができるようにしていきます🛣️😆

[1]: https://nodejs.org/api/cli.html "Command-line API | Node.js v25.6.0 Documentation"
[2]: https://nodejs.org/en/blog/announcements/v22-release-announce?utm_source=chatgpt.com "Node.js 22 is now available!"
[3]: https://docs.docker.com/desktop/features/wsl/best-practices/ "Best practices | Docker Docs"
[4]: https://www.typescriptlang.org/docs/handbook/configuring-watch.html?utm_source=chatgpt.com "Documentation - Configuring Watch"
