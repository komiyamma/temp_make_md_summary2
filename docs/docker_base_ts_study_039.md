# 第39章：Compose運用ルール（チームでも自分でも迷わない）📏

この章は「**Composeで開発スタックを回すときの迷子ポイント**」をぜんぶ潰して、**“ルール1枚”を完成**させます✍️✨
（あとで未来の自分が助かるやつです🥹🎁）

---

## 0) まず結論：迷わない運用は「入口を固定」するだけで8割勝ち🏁😆

Compose運用で迷う理由って、ほぼこれ👇

* 起動の仕方が人によって違う😵‍💫（`up` のオプションバラバラ）
* データ消すコマンドが怖い😱（誰かが `-v` しがち）
* `.env` が散らかる🌀（値がどれが正なの？）
* 追加サービス（Redisとか）で混乱する😇

だから、運用ルールは **3つだけ固定**します👇✨

1. **入口コマンドを固定**（起動・停止・ログ・初期化）🎮
2. **破壊コマンドに“赤札”**（安全/危険を明文化）🟥⚠️
3. **設定の置き場所を固定**（env/ポート/データ）📦🧠

---

## 1) 今日のゴール🎯✨

最終的に、プロジェクトにこれを置きます👇

* `docs/compose-rules.md`（運用ルール1枚）📄✨
* `package.json` の scripts（入口コマンド固定）🧩🎮

これで「え、どう起動するんだっけ？」がゼロになります😆👍

---

## 2) “ルール化”する対象リスト（ここだけやればOK）✅🧠✨

運用で毎回使うのは、だいたいこのへん👇

## A. 起動・停止のルール▶️⏹️

* ふだんは `docker compose up -d`（ログ貼り付け地獄を避ける😵）
* 変更反映は「ビルドする/しない」を決める（`--build` を使うか固定）🧱
* 起動確認をラクにするなら `--wait`（サービスが running/healthy になるまで待てる）⏳✨ ([Docker Documentation][1])

## B. ログの見方🪵👀

* 全体ログ：`docker compose logs -f`
* 1サービスだけ：`docker compose logs -f api`（例）🎯

## C. データの扱い（重要）💾🛡️

* DBは**名前付きvolume**で守る（消えると泣く😭）
* “初期化コマンド”を用意して、迷わずリセットできるようにする🧨➡️🌱

## D. ポート設計🚪🔢

* 予約ポートを決める（例：API=3000, DB=5432 みたいに）📏
* 変更するときは「どこに書くか」を固定（compose or env）🧠

## E. 設定（env）の置き場所🎚️

* `.env` は**ローカル用**、`.env.example` をコミット、が鉄板🧊🧾

## F. 追加サービスの増やし方（Redisや管理GUIなど）🧩➕

* いつも有効にしないなら **profiles** を使うとキレイ✨ ([Docker Documentation][2])

---

## 3) Compose運用で “絶対に決めておく” ルール7つ📏🔥

## ① Composeファイル名は “迷わない名前” に寄せる📄🧭

今は `compose.yaml` が推奨で、互換で `docker-compose.yml` も動きます（両方あると `compose.yaml` が優先）📝 ([Docker Documentation][3])
→ **ルール：基本は `compose.yaml` に統一** がラクです👍

---

## ② プロジェクト名を固定して “コンテナ名事故” を防ぐ🏷️🧨

Composeはプロジェクト名でコンテナ名やネットワーク名が決まります。
決め方の優先順位（`-p` → `COMPOSE_PROJECT_NAME` → `name:` → ディレクトリ名…）が公式に明記されています🧠✨ ([Docker Documentation][4])

→ **ルール：`compose.yaml` に `name:` を書いて固定** が簡単です👍

---

## ③ “安全コマンド” と “危険コマンド” を分けて書く🟥⚠️

`docker compose down` は基本安全寄り。
でも `-v/--volumes` を付けると **名前付きvolumeも消える**（＝DBデータ消える可能性）😱 ([Docker Documentation][5])
さらに `--remove-orphans` は「Composeに書かれてない古いコンテナ」も掃除する🧹 ([Docker Documentation][5])

→ **ルール：危険コマンドは“赤札”で明示**🟥

---

## ④ 起動確認を “待てる” ようにする（地味に効く）⏳✨

`docker compose up` には `--wait` があり、サービスが running/healthy になるまで待ってくれます（detach相当になる）🧠 ([Docker Documentation][1])
→ **ルール：チーム用コマンドは `--wait` ありにする**と「起動したはずなのに繋がらない😵」が減ります👍

---

## ⑤ ファイル変更反映は “Watch” を標準にする（開発が速い）⚡👀

Composeにはファイル監視（Watch）があり、`docker compose up --watch` で起動しつつ監視できます。ログを分けたいなら `docker compose watch` もOK👌 ([Docker Documentation][6])
`action` によって `sync+restart` みたいな挙動も選べます🔁✨ ([Docker Documentation][6])

→ **ルール：開発時は watch を“標準の入口”に**すると、反映ミスが激減します😆

---

## ⑥ Composeの “最終形” を確認する癖をつける（デバッグ最強）🔍🧠

`docker compose config` は、mergeやenv展開後の “最終的に適用される形” を出せます🧾✨ ([Docker Documentation][7])
→ **ルール：困ったら `config` を見る**（超強い）💪

---

## ⑦ 共通設定は `x-` 拡張で “重複を消す”🧹✨

`x-` で始まるトップレベル要素は Compose が無視してくれる（例外的にサイレント無視される）ので、共通設定をまとめやすいです📌 ([Docker Documentation][8])
→ **ルール：共通のenvやログ設定は `x-` に寄せる**（後から効く）

---

## 4) ハンズオン：運用ルール1枚を作る📄✨（コピペOK）

## 手順①：`docs/compose-rules.md` を作る📁🖊️

下をそのまま貼って、プロジェクトに合わせて数カ所だけ書き換えてね😊

```md
## Compose運用ルール（開発用）📏✨

## 1. 入口コマンド（これ以外は禁止🙅）
- 起動（開発）: `npm run dev:up`
- 監視（開発）: `npm run dev:watch`
- ログ追尾: `npm run dev:logs`
- 停止（安全）: `npm run dev:down`
- データ初期化（危険🟥）: `npm run dev:reset`

## 2. よくある確認コマンド🔍
- 状態: `docker compose ps`
- 設定の最終形: `docker compose config`
- 1サービスだけログ: `docker compose logs -f api`

## 3. データの扱い💾
- DBは名前付きvolumeで保持する（消さない）
- 初期化したいときは `npm run dev:reset` を使う（手動で -v しない）

## 4. ポート表🚪
- API: 3000
- DB: 5432
（衝突したらここを更新して全員に共有）

## 5. envルール🎚️
- `.env` はローカル専用（コミットしない）
- `.env.example` をコミットして、鍵じゃない値だけ入れる

## 6. 追加サービスのルール🧩
- いつも使わないサービスは profiles で分ける（例: `--profile tools`）
```

---

## 手順②：`package.json` に “入口コマンド” を作る🎮✨

（コマンド固定が正義👑）

```json
{
  "scripts": {
    "dev:up": "docker compose up -d --build --wait",
    "dev:watch": "docker compose up --watch",
    "dev:logs": "docker compose logs -f --timestamps",
    "dev:down": "docker compose down",
    "dev:reset": "docker compose down -v --remove-orphans"
  }
}
```

* `--wait` は「起動したつもり」を減らすのに効きます⏳✨ ([Docker Documentation][1])
* `down -v` は**データ消える可能性**があるので、**reset専用**に隔離します🟥💥 ([Docker Documentation][5])
* `--remove-orphans` は「昔の残骸」を掃除してくれます🧹 ([Docker Documentation][5])

---

## 手順③：`compose.yaml` に “プロジェクト名固定” を入れる🏷️✨

```yaml
name: todo-api

services:
  api:
    # 省略
  db:
    # 省略
```

プロジェクト名の決まり方に `name:` が含まれるのは公式仕様です📌 ([Docker Documentation][4])

---

## 手順④：Watch運用を “標準装備” にする👀⚡

Watchは `docker compose up --watch` で起動でき、ログを分けたいなら `docker compose watch` もOKです👌 ([Docker Documentation][6])
さらに `sync+restart` みたいなアクションも用意されています🔁✨ ([Docker Documentation][6])

（例：Nodeの開発で「ファイル同期＋プロセス再起動」をしたい時など）

---

## 5) AIに頼むと爆速になるやつ🤖⚡（コピペOK）

## ✅ ルール文章を読みやすく整える

```text
docs/compose-rules.md を貼ります。
「初心者が迷わない」ことを最優先に、文章を短くして箇条書き中心に整えてください。
危険コマンドは🟥で目立たせてください。
```

## ✅ 運用コマンドが妥当かレビュー

```text
package.json の scripts を貼ります。
チーム運用で事故りやすい点（データ消失/ポート衝突/環境差）を指摘して、より安全な案に直してください。
```

## ✅ Composeの最終形チェック（デバッグ用）

```text
docker compose config の出力を貼ります。
意図と違うところ（env展開、ポート、volume、profiles）を指摘して、原因候補を優先順位付きで出してください。
```

---

## 6) 仕上げチェック✅🎉（ここまでできたら勝ち！）

* [ ] `npm run dev:up` で迷わず起動できる🙂
* [ ] `npm run dev:watch` で編集→反映が追える👀⚡
* [ ] `npm run dev:reset` が **“危険🟥” として隔離**されている😆
* [ ] `docs/compose-rules.md` が1枚で説明できる📄✨
* [ ] 困ったら `docker compose config` を見る癖がついた🔍🧠 ([Docker Documentation][7])

---

## 7) おまけ：規模が大きくなったら（将来の拡張）🌱➡️🌳

「composeが巨大化してきた😵」となったら、複数ファイルの **merge** ルールや **include** で分割できます📚✨ ([Docker Documentation][9])
ただ、まずは **“入口固定”** ができてれば十分強いです💪😆

---

次の第40章で、いよいよ **“開発スタック一発起動” 完成🏁🎉** に持っていくよ〜！🚀✨

[1]: https://docs.docker.com/reference/cli/docker/compose/up/?utm_source=chatgpt.com "docker compose up"
[2]: https://docs.docker.com/reference/compose-file/profiles/?utm_source=chatgpt.com "Profiles"
[3]: https://docs.docker.com/compose/intro/compose-application-model/?utm_source=chatgpt.com "How Compose works | Docker Docs"
[4]: https://docs.docker.com/compose/how-tos/project-name/?utm_source=chatgpt.com "Specify a project name"
[5]: https://docs.docker.com/reference/cli/docker/compose/down/?utm_source=chatgpt.com "docker compose down"
[6]: https://docs.docker.com/compose/how-tos/file-watch/?utm_source=chatgpt.com "Use Compose Watch"
[7]: https://docs.docker.com/reference/cli/docker/compose/config/?utm_source=chatgpt.com "docker compose config"
[8]: https://docs.docker.com/reference/compose-file/extension/?utm_source=chatgpt.com "Extensions"
[9]: https://docs.docker.com/reference/compose-file/merge/?utm_source=chatgpt.com "Merge Compose files"
