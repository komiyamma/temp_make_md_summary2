# 第32章：compose.ymlを読む練習（最低限の項目）👀

この章は「**書ける**」より先に、**“読める”を作る回**だよ〜😄✨
Compose はチーム開発でも個人開発でも「読める＝直せる」なので、ここで一気に慣れちゃおう💪🐳

---

## ✅ この章のゴール（できるようになること）🎯

* `compose.yaml` / `compose.yml` の **全体の形**を見てビビらない😆
* `services / ports / volumes` を見て、**何が起きる設定か説明できる**🗣️✨
* 「この compose、外からアクセスできる？」「データ消える？」が判断できる🔍🧠

※ Compose ファイルは `compose.yaml` が推奨で、互換のために `docker-compose.yml` 等も読めるよ〜📄（どれが優先されるかも明記あり）([Docker Documentation][1])

---

## 1) まずは“読む順番”を固定しよう 🧭👣

compose を読むときは、毎回この順でOK！✨

1. **ファイル名とプロジェクト名**（あれば `name:`）🏷️
2. **services**：サービス一覧（アプリの登場人物）🎭
3. **各サービスの ports**：外から入れる入口ある？🚪🔌
4. **各サービスの volumes**：データはどこに保存？消える？💾🧱
5. （余裕が出たら）`environment` や `depends_on` を軽く見る🎚️⏳

---

## 2) YAML 最小講座（ここで詰まる人が多い）🧩😵

YAML は「**インデントが命**」！🫠

* **半角スペース**で揃える（タブは基本使わない）
* `key: value` は **辞書（マップ）**
* `- item` は **配列（リスト）**
* 文字列は `"..."` で囲むと事故が減る（特に ports）🧯

特に ports は **引用符つき文字列**が推奨（YAML の解釈事故を避けるため）って公式にも注意があるよ📌([Docker Documentation][2])

---

## 3) Compose の“最小骨格”を目で覚える 👀🦴

Compose は「サービス（containers）」を YAML で束ねる仕組み。
考え方としては **services を必ず宣言**して、その下にサービス名が並ぶ感じ！([Docker Documentation][2])

```yaml
name: todo-api        # 省略OK（あってもOK）
services:
  api:
    # ここに設定が並ぶ
```

---

## 4) services を読む：まずは「登場人物」確認 🎭✨

`services` は「アプリを構成する部品たち」だよ📦
公式も「services をトップレベルに宣言し、サービス名 → サービス定義の map だよ」って明言してる👍([Docker Documentation][2])

**読みポイント**（最低限）👇

* `api:` ← これが **サービス名**（あとで名前解決にも使う）🏷️
* `image:` ← どのイメージで動く？🍱
* `ports:` ← 外からアクセスできる？🚪
* `volumes:` ← データの置き場所は？💾

---

## 5) ports を読む：外から入れる“入口”🚪🔌

## ✅ ports の意味

`ports` は **ホスト（あなたのPC）↔ コンテナ**のポート対応表だよ📮
公式も「ホストとコンテナのポートマッピング」と説明してる👍([Docker Documentation][2])

## ✅ 一番よく見る（短い書き方 / short syntax）

```yaml
ports:
  - "3000:3000"
```

* 左（ホスト）: `3000` → ブラウザで `localhost:3000` にアクセスする側🖥️🌐
* 右（コンテナ）: `3000` → コンテナの中で待ち受けてる側🐳
* `tcp/udp` を付けることもできて、デフォは `tcp`（公式に明記）([Docker Documentation][2])

## ✅ ありがち注意⚠️

* `network_mode: host` と `ports` は併用しない（実行時エラーになりうる）([Docker Documentation][2])
* `HOST:CONTAINER` は **文字列で書くのが安全**（YAML事故回避）([Docker Documentation][2])

---

## 6) volumes を読む：データは“どこに残る？”💾🧱

`volumes` は「コンテナから見えるファイル置き場をどこにするか」📁
公式では service 側 `volumes` は、`volume / bind / tmpfs / npipe` など複数タイプを扱えるよ、と説明されてるよ🧰([Docker Documentation][2])

## ✅ 2種類だけ覚えればOK（まずは！）🧠✨

## (A) bind mount（ホストのフォルダをそのまま見せる）🪟📂

```yaml
volumes:
  - ./:/app
```

* 典型：ソースコードを即反映したい開発向け⚡

## (B) named volume（Docker管理のデータ置き場）📦💾

```yaml
volumes:
  - api_node_modules:/app/node_modules

volumes:
  api_node_modules:
```

* Docker 側が管理する “名前付き保存領域”
* 複数サービスで再利用したいなら **トップレベル `volumes:` に定義**が基本だよ🧱✨([Docker Documentation][2])
* 「ホストパス直書き」より、壊れにくくて楽な場面が多い👍

---

## 7) 読み練習：この compose.yaml を読んでみよう 🧠✍️

次のファイルを見て、質問に答えてみてね😄（まずは読むだけでOK！）

```yaml
name: todo-api

services:
  api:
    image: node:24-slim
    working_dir: /app
    command: sh -c "npm ci && npm run dev"
    ports:
      - "3000:3000"
    volumes:
      - ./:/app
      - api_node_modules:/app/node_modules
    environment:
      NODE_ENV: development

volumes:
  api_node_modules:
```

## ✅ 質問（答えは下にあるよ）👇

1. ブラウザでアクセスする URL は？🌐
2. 外に公開されてるポート番号は？🔌
3. コンテナ内でアプリは何番ポートで待つ想定？🐳
4. `./:/app` はどんな意味？📂
5. `api_node_modules` はどこに保存されるタイプ？💾

## ✅ 答え合わせ🎉

1. `http://localhost:3000`
2. `3000`
3. `3000`
4. ホストのプロジェクトフォルダをコンテナの `/app` に見せる（bind mount）
5. named volume（Docker 管理の永続領域）([Docker Documentation][2])

---

## 8) “答え合わせ機械”として最強：docker compose config 🧾✨

読む練習で超便利なのがこれ👇
`docker compose config` は **変数解決・短縮記法の展開**をして「正規化した最終形」を表示してくれるよ！([Docker Documentation][3])

```bash
docker compose config
```

* 「結局どう解釈されるの？」が一発で見える👀✨
* `ports` や `volumes` の短縮がどう展開されるか確認しやすい👍([Docker Documentation][3])

---

## 9) よくある「読めない！」原因トップ7 🪤😵‍💫（先に潰す）

1. **インデントずれ**（YAMLは容赦ない）🫠
2. `ports` の `"3000:3000"` を数値っぽく書いて事故（文字列推奨）([Docker Documentation][2])
3. `HOST:CONTAINER` の左右を逆に覚える😇
4. bind mount と named volume の見分けがつかない（`./` が出たらbind率高め）📂
5. `volumes:` が **サービス内**と**トップレベル**に両方あって混乱（役割が違う）🧱([Docker Documentation][2])
6. `compose.yaml` と `docker-compose.yml` が両方あって「どっち読んでる？」状態（優先がある）([Docker Documentation][1])
7. `version:` を書いて警告でビビる（今は obsolete 扱い）⚠️([Docker Documentation][4])

---

## 10) AI活用：コメント付きにして“読める化”する🤖📝

## ✅ そのまま使えるプロンプト（コピペ用）📎

```text
次の compose.yaml を「初心者でも読める」ように、
各行に短いコメント（# ...）を付けてください。
特に services / ports / volumes の意味を丁寧に。
（コメント以外の内容は変えないで）

---ここから---
（compose.yaml を貼る）
---ここまで---
```

## ✅ “読み順テンプレ”を作らせる🧠

```text
この compose.yaml を読むときの「読む順番チェックリスト」を作って。
最初に services、次に ports、次に volumes を重点的に。
```

## ✅ ミス探しをやらせる🕵️‍♂️

```text
この compose.yaml にありがちなバグ/事故ポイントがないかレビューして。
特に ports の書き方、volumes の種類、パス周りを重点チェック。
```

---

## 11) ミニテスト（サクッと10問）📝✨

1. `services:` の下に並ぶキー（例：`api:`）は何？
2. `ports: - "8080:80"` の左と右はどっちがホスト？
3. `ports` を文字列で書くのが推奨されがちな理由は？
4. `volumes: - ./:/app` は何マウント？
5. named volume を複数サービスで使いたいとき、どこに宣言する？
6. `docker compose config` は何をしてくれる？
7. `compose.yaml` と `docker-compose.yml` が両方あるとき、どっちが優先？
8. `version:` は今どういう扱い？
9. `ports` の default protocol は？
10. `volumes` が「サービス内」と「トップレベル」にあるとき、それぞれ何の役？

※答えはこの章の本文に全部あるよ😄🔎（見つけられたら勝ち🏆）

---

## 次章へのつなぎ 🚀

次の第33章で、いよいよ **サービスを2つ（API＋DB）**に増やすよ〜！😆🎉
この章で「読める目」ができてると、増えても怖くない👍✨

[1]: https://docs.docker.com/compose/intro/compose-application-model/ "How Compose works | Docker Docs"
[2]: https://docs.docker.com/reference/compose-file/services/ "Services | Docker Docs"
[3]: https://docs.docker.com/reference/cli/docker/compose/config/?utm_source=chatgpt.com "docker compose config"
[4]: https://docs.docker.com/reference/compose-file/version-and-name/?utm_source=chatgpt.com "Version and name top-level elements"
