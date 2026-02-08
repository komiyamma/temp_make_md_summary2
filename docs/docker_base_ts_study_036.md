# 第36章：ログをまとめて見る（複数サービス運用のコツ）🪵📚

この章は「API＋DB」を **同時に運用してる時に、ログで全体の状態を一瞬でつかむ力** を付ける回だよ〜！😆
単体の `docker logs` じゃなくて、**Compose視点**で見るのがポイント👍

---

## 1) この章のゴール🎯

* **APIとDBのログを“並べて”見て**、何が起きてるか説明できる🙂
* `docker compose logs` を使って
  **追尾（follow）・行数制限（tail）・時間で絞る（since/until）** ができる💪
* 「原因っぽいサービス」をログから当てられる🔍✨

---

## 2) まず結論：複数サービス運用は“ログの見方”で勝負が決まる🥊😎

## ありがちな沼😵

* APIがエラー吐いてるけど、**本当はDBが先に死んでた**
* DBは元気だけど、**APIの接続文字列が間違ってる**
* どっちもログが出てて、**時系列がぐちゃぐちゃ**

→ だから **「まとめて」「絞って」「時刻で揃える」** が正義💡

---

## 3) `docker compose up` と `docker compose logs` の使い分け🚦

## A. `docker compose up`（画面にログが流れるモード）📺

* 開発中にそのまま眺めるならこれ
* ただし、ターミナルを占有する😅

## B. `docker compose up -d` → `docker compose logs`（後から見るモード）🕵️‍♂️

* バックグラウンド起動して、**必要な時にログだけ見る**
* 複数サービス運用だとこっちが便利になりがち👍

---

## 4) 基本：全部のログを“まとめて”見る🧺🪵

まずは全体像チェック✨

```bash
docker compose logs
```

ログは **サービスごとに混ざって出る**（＝「全体の実況中継」）ので、状況把握に強い👍
`docker compose logs` の主なオプションは公式のCLIリファレンスにまとまってるよ。([Docker Documentation][1])

---

## 5) “今起きてる問題”を見る最強セット⚡（follow + tail）

ログ追尾（リアルタイム監視）するとき、いきなり全部流すと地獄😇
なので最初に **直近だけ表示してから追尾** が鉄板！

```bash
docker compose logs --tail 50 --follow
```

* `--tail 50`：最初に直近50行だけ出す
* `--follow`：その後は流れ続ける

この組み合わせはComposeログの定番ムーブ👍（`--follow`/`--tail` は公式オプション）([Docker Documentation][1])

---

## 6) サービスを指定して“犯人”を絞る🔍🕵️‍♀️

全体が騒がしいなら、まず容疑者を絞る！

```bash
docker compose logs --tail 100 api
```

```bash
docker compose logs --tail 100 db
```

さらに、両方同時にもできる👇

```bash
docker compose logs --tail 100 api db
```

---

## 7) “時系列”を揃える：`--timestamps` が神⏰✨

複数サービスは、**時刻がないと話にならない**ことが多い😂
Dockerが付けたタイムスタンプを出す！

```bash
docker compose logs --timestamps --tail 200
```

`--timestamps` は公式オプションだよ。([Docker Documentation][1])

---

## 8) “時間で絞る”：`--since` / `--until` で一撃🎯⏱️

「さっき起きたやつだけ見たい！」に効くやつ🔥

## 直近10分だけ

```bash
docker compose logs --since 10m
```

## 直近1時間で、APIだけ追う

```bash
docker compose logs --since 1h --tail 200 api
```

## ある時間帯だけ（調査ログに超便利）

```bash
docker compose logs --since "2026-02-08T12:00:00" --until "2026-02-08T12:10:00" --timestamps
```

`--since` / `--until` も公式にあるフィルタだよ。([Docker Documentation][1])

---

## 9) “コピペしやすいログ”にする（prefix/色を消す）🧼📄

AIに貼ったり、Issueに貼る時は **余計な装飾が邪魔**になりがち！

```bash
docker compose logs --no-color --no-log-prefix --timestamps --since 10m
```

* `--no-log-prefix`：先頭のサービス名プレフィックスを消す
* `--no-color`：色を消す
* どっちも公式オプションだよ。([Docker Documentation][1])

---

## 10) 2ターミナル運用：現場でめちゃ強い💪🖥️🖥️

VS Codeのターミナルを2つ開いて👇

## タブA（API）

```bash
docker compose logs -f --tail 50 --timestamps api
```

## タブB（DB）

```bash
docker compose logs -f --tail 50 --timestamps db
```

これで **「APIがエラー吐いた瞬間に、DB側で何が起きたか」** が同時に見える😆✨
複数サービス運用の“基本フォーム”🏋️‍♂️

---

## 11) 便利小ネタ：スケールした時のログ（replicaが複数）🧬

もし `api` を複数起動（例：replica 2）した場合、どのコンテナのログか見たい時があるよね🙂
`docker compose logs` には **`--index`** オプションがある（サービスに複数コンテナがいる時に使う）よ。([Docker Documentation][1])

例（2台目だけ見たい、みたいなイメージ）：

```bash
docker compose logs --index 2 api
```

---

## 12) ありがちトラブルを“ログで診断”してみよう（超ミニ演習）🧪😈

## 演習：DBを止めてAPIがどう壊れるか観察する👀

1. DBだけ止める

```bash
docker compose stop db
```

2. APIログを追尾して眺める（別タブ推奨）

```bash
docker compose logs -f --tail 50 --timestamps api
```

3. 何かAPIにアクセス（ブラウザ/HTTPクライアント）してエラーを出す
   → API側に `ECONNREFUSED` とか “DBいないよ！” 的なログが出やすい💥

4. DBログも見る

```bash
docker compose logs --tail 100 --timestamps db
```

5. DBを戻す

```bash
docker compose start db
```

ここでの狙いは「直し方」じゃなくて、**“両方のログを見比べて状況を説明する”** ことだよ🙂✨
次章（起動順/待ち）に繋がる伏線〜！🎬

---

## 13) AI活用：ログ要約＆次の一手を作らせる🤖✂️✨

ログはそのまま貼ると長いので、**短く切り取ってAIに投げる**のがコツ👍

## コピペ用テンプレ（安全寄り🛡️）

* `--since 10m` と `--tail 200` で量を制御
* 秘密っぽい値（パスワード/トークン）は伏せる（`****`）
* できれば `--no-color --timestamps` を付ける

```text
次のログを読んで、(1) 何が起きたか を1〜2行、(2) 原因候補トップ3、(3) 確認コマンドを順番に 出して。
制約：推測は推測と明記して。ログの行番号も引用して。

--- logs ---
（ここに貼る）
```

---

## 14) 注意：logging driver を変えると `compose logs` で見えないことがある⚠️🪵

基本は気にしなくてOKだけど、Composeの `logging:` で `syslog` などに変えると、**`docker compose logs` が表示できないケース**があるよ（参照できるドライバに制約が出る）。([docs.docker.jp][2])
「ログが出ない！」って時は、ここも疑ってOK🙂

---

## まとめ🎉

* 複数サービスは **“まとめて見て→絞って→時刻で揃える”** が最強🪵⏰🔍
* 開発で一番使うのはだいたいこれ👇

  * `docker compose logs --tail 50 -f`
  * `docker compose logs --since 10m --timestamps`
  * サービス指定 `... api db`

次は **第37章：依存関係（起動順）をざっくり扱う⏳**！
「DB待ち問題」でログがさらに面白くなるぞ〜😆🔥

[1]: https://docs.docker.com/reference/cli/docker/compose/logs/?utm_source=chatgpt.com "docker compose logs"
[2]: https://docs.docker.jp/compose/compose-file/compose-file-v2.html?utm_source=chatgpt.com "Compose ファイル version 2 リファレンス"
