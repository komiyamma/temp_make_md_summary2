# 第38章：開発コマンドを一発化（npm scriptsと併用）🎮

開発って、気づくとこうなりがち👇😵
「起動…ログ見る…止める…DB初期化…また起動…」の**儀式ループ**🔁

この章では、その儀式を **`npm run xxx` の“開発メニュー”にして一発化**します😆🎉
（結果：自分も未来の自分も助かる🫶✨）

---

## 🎯 この章のゴール（できたら勝ち🏆）

* `npm run up` で **API+DBを起動**できる 🚀
* `npm run logs` で **ログ追尾**できる 🪵👀
* `npm run down` で **片付け**できる 🧹
* `npm run reset` で **DBをまっさらに**できる（※破壊コマンド）💥🗑️
* 余裕があれば：`npm run dev:watch` で **編集→自動反映**まで行く 🪄✨（Compose Watch）

---

## 🧠 まず“儀式”を文字にする（設計の超ミニ版）📝✨

あなたが普段やってる流れを、そのまま書き出します👇🙂

* 起動：`docker compose up ...`
* 状態：`docker compose ps`
* ログ：`docker compose logs -f ...`
* 停止＆削除：`docker compose down ...`
* DB初期化：`docker compose down -v`（ボリューム消える⚠️）

`docker compose up` は**コンテナを作って起動し、ログもまとめて表示**します。さらに、フォアグラウンドで動かすと**コマンド終了時にコンテナも止まる**挙動です（`--detach` なら裏で動き続ける）🧠✨ ([Docker Documentation][1])
`docker compose down` は **upで作ったコンテナ/ネットワーク等を掃除**します（ボリュームやイメージはオプション次第）🧹 ([Docker Documentation][2])

---

## 🧰 ハンズオン1：`package.json` に“開発メニュー”を作る📜🎮

ここが本題🔥
**ターミナルで長いコマンドを打たない**世界へ行きます😆🚀

まず、プロジェクト直下の `package.json` の `scripts` をこうします👇
（Composeファイル名は `compose.yaml` 想定。もし `docker-compose.yml` ならそこだけ読み替えOK👌）

```json
{
  "scripts": {
    "up": "docker compose -f compose.yaml up -d --build",
    "ps": "docker compose -f compose.yaml ps",
    "logs": "docker compose -f compose.yaml logs -f --tail=200",
    "down": "docker compose -f compose.yaml down",
    "restart": "npm run down && npm run up",

    "reset": "docker compose -f compose.yaml down -v",
    "reset:hard": "docker compose -f compose.yaml down -v --remove-orphans",

    "sh:api": "docker compose -f compose.yaml exec api sh",
    "sh:db": "docker compose -f compose.yaml exec db sh"
  }
}
```

## ✅ 使い方（この章の“魔法の言葉”）🪄

* 起動：`npm run up` 🚀
* 状態：`npm run ps` 📋
* ログ：`npm run logs` 🪵👀
* 停止：`npm run down` 🧹
* DB初期化：`npm run reset` 💥（**ボリューム消える**ので注意！）([Docker Documentation][2])

> 💡 `reset:hard` の `--remove-orphans` は、Composeファイルから消えたサービスの“孤児コンテナ”も掃除してくれる系です🧹✨（環境が散らかりがちな人ほど効く）

---

## ⚠️ 破壊コマンドを“安全にする”小ワザ🛡️😇

`reset` は強い。強すぎる。💥
だから名前で分かるようにします👇

* ✅ よく使う：`reset`（DBだけ初期化したい時）
* ✅ さらに危険：`reset:hard`（孤児も含めて全部掃除）

さらに安全にしたい人は、**READMEに赤字（気持ち）で書く**のが一番効きます🤣🟥

---

## 🧰 ハンズオン2：もっとラクする（Compose Watchで“編集→自動反映”）🪄✨

ここ、2026時点でかなり便利です😆
Compose Watchは、**ファイル変更を見て、コンテナへ同期したり、必要なら再起動/再ビルド**してくれます📦🔁

* 使い方はシンプル：`docker compose up --watch`（または `docker compose watch`）👀 ([Docker Documentation][3])
* Composeの設定は `develop: watch:` にルールを書くタイプです🧩 ([Docker Documentation][3])
* `node_modules/` は同期しないのが基本（重い＆ネイティブ依存が混ざることがある）📦⚠️ ([Docker Documentation][3])

例：`api` サービスに watch を足すイメージ👇（雰囲気だけ掴めればOK！）

```yaml
services:
  api:
    build: .
    command: npm run dev
    develop:
      watch:
        - action: sync
          path: .
          target: /app
          ignore:
            - node_modules/
        - action: rebuild
          path: package.json
```

そして `package.json` にも入口を追加👇

```json
{
  "scripts": {
    "dev:watch": "docker compose -f compose.yaml up --watch"
  }
}
```

これで、**`npm run dev:watch` → 編集保存 → 勝手に反映**の世界へ🚀🪄✨ ([Docker Documentation][3])

---

## 🧰 ハンズオン3：`&&` が不安なら（Windows差で壊れがち回避）🧯🪟

ターミナルの種類によっては `&&` の挙動が微妙なことがあります😵‍💫
「順番に実行」を確実にしたいなら、**`npm-run-all2`** がラクです（`run-s` で直列、`run-p` で並列）🧩✨ ([GitHub][4])

例（入れるなら）👇

```bash
npm i -D npm-run-all2
```

```json
{
  "scripts": {
    "down": "docker compose -f compose.yaml down",
    "up": "docker compose -f compose.yaml up -d --build",
    "restart": "run-s down up"
  }
}
```

> 🛡️ 依存を増やすときは、供給網攻撃（サプライチェーン）の話も現実にあるので、**有名/信頼できるものを選んでロックファイル運用**しようね🙏🔒 ([about.gitlab.com][5])

---

## 🤖 AI活用：この章はAIがめちゃくちゃ相性いい😆🤖✨

## 1) “あなたの儀式”から scripts を自動生成してもらう

コピペ用プロンプト👇

```text
compose.yaml の services は api と db です。
開発で使うコマンド（up/ps/logs/down/reset/sh）を npm scripts にしたいです。
Windowsでも壊れにくい命名で、危険なコマンドは分かる名前にして提案して。
```

## 2) READMEの「起動手順」を整形してもらう📘✨

```text
以下の npm scripts を前提に、初見の人が迷わない README の「Quick Start」を作って。
注意点（resetはデータ消える）も入れて、短く、箇条書きで。
```

---

## 🧯 よくある詰まり＆即チェック✅😵

* 🐳 **`docker compose` が動かない**
  → Docker Desktop 側に Compose は含まれてるので、まずバージョン確認：`docker compose version`（インストールの基本）([Docker Documentation][6])
* 🚪 **ポートが埋まってる**
  → `npm run ps` で状態、`npm run logs` で原因を見る📋🪵
* 🧩 **`sh:api` が入れない（サービス名違い）**
  → compose.yaml の `services:` 名と scripts の `exec api` を一致させる🙂
* 💥 **`reset` したらデータ消えた**
  → それが `down -v`（ボリューム削除）です😇💥 ([Docker Documentation][2])
* 🪄 **watchが期待通りに動かない**
  → `develop: watch:` ルール確認、`node_modules/` は同期しない（基本）📦⚠️ ([Docker Documentation][3])

---

## ✅ 章末ミニテスト（3問）🧠🎯

1. `npm run up` が裏で起動するようにしてるのはどのオプション？😆
2. `reset` が危険なのはなぜ？（何が消える？）💥
3. watchで `node_modules/` を避ける理由を1つ言ってみて📦⚠️

---

## 🏁 まとめ（この章で手に入るもの）🎁✨

* 開発の“儀式”が **`npm run` で統一**される🎮
* 未来の自分/仲間が **READMEだけで起動できる**📘
* 余裕があれば watch で **編集→自動反映**まで行ける🪄🚀 ([Docker Documentation][3])
* しかも Compose の基本挙動（up/down/logs）が腹落ちする🧠✨ ([Docker Documentation][1])

次の章（第39章）では、この“開発メニュー”を**迷わない運用ルール**に落とし込んでいきます📏😄

[1]: https://docs.docker.com/reference/cli/docker/compose/up/ "docker compose up | Docker Docs"
[2]: https://docs.docker.com/reference/cli/docker/compose/down/ "docker compose down | Docker Docs"
[3]: https://docs.docker.com/compose/how-tos/file-watch/ "Use Compose Watch | Docker Docs"
[4]: https://github.com/bcomnes/npm-run-all2/releases?utm_source=chatgpt.com "Releases · bcomnes/npm-run-all2"
[5]: https://about.gitlab.com/blog/gitlab-discovers-widespread-npm-supply-chain-attack/?utm_source=chatgpt.com "GitLab discovers widespread npm supply chain attack"
[6]: https://docs.docker.com/compose/install/?utm_source=chatgpt.com "Overview of installing Docker Compose"
