# 第2章：なぜ冪等性が必要？現実はリトライだらけ😇🌧️

## 🎯この章のゴール

* 「冪等性がないと何が壊れるのか」を、**タイムアウトと再送**の流れで説明できるようになる🙂📌
* 「成功したのに返事が届かない」が、なぜ超やっかいかが腑に落ちる🙃💥

---

## 1) 現実：ネットワークは“だいたい不安定”📶💫

アプリって、常にこういうことが起きます👇

* 電波が弱い / Wi-Fiが切り替わる📱📡
* サーバーが混んでて返事が遅い🐢
* 途中のネットワーク（プロキシ等）で切れる🧵✂️
* プラットフォーム側の都合で接続が切られる⏱️💥（あとで詳しく）

そして人間はこうする👇
**「あれ？反応ない…もう一回押そ」** 🔁😅

ここで冪等性がないと、**同じ処理が2回走る**事故が起きます😱

---

## 2) “最悪”はこれ：成功したのに返事が届かない🙃📨

一番こわいのは、これ👇

* サーバー側では **処理が成功している** ✅
* でもクライアント（ブラウザ/アプリ）は **レスポンスを受け取れなかった** ❌

この状態だと、クライアントから見るとこうです👇
**「成功した？失敗した？わかんない…」** 🤷‍♀️💭

例えば Cloud Run のドキュメントでも、タイムアウトすると接続は閉じられて 504 になる一方で、**コンテナ（サーバー側）が処理を継続してしまう可能性**がある、と明記されています。つまり「返事は切れたけど、裏では進んでた」が普通に起こりえます。([Google Cloud Documentation][1])

だからこそ、HTTPの仕様でも「通信障害でレスポンスが読めなかったとき、**同じリクエストを再送すること**」を強く意識していて、**冪等なメソッドは自動再送しやすい**、でも **非冪等は慎重に**という話が出てきます。([RFCエディタ][2])

---

## 3) 「タイムアウト→再送→二重実行」事故の典型パターン📨📨💥

### パターンA：ユーザー再送（連打）👆👆

1回目：ボタン押す
2回目：反応が遅くて、もう一回押す
→ **同じ注文が2つ作られる**、**二重決済**、**ポイント二重付与**…😱💳

### パターンB：アプリ側のリトライ（自前実装）🔁🧠

ブラウザの `fetch()` は、**ネットワークエラー等でしか reject しない**（例：HTTP 504 でも reject しない）ので、アプリ側で `response.ok` を見て「再試行しよ！」って書きがちです。([MDN Web Docs][3])
この「再試行コード」が、冪等性を前提にしてないと事故ります😵‍💫

### パターンC：プラットフォーム/ライブラリ側のリトライ（勝手に起きる）🤖🔁

* Google Cloud Storage のように、クライアントライブラリが**自動リトライ**することがあります（エラーや接続不安定への対策）([Google Cloud][4])
* Firebase のバックグラウンド処理は、設定次第で失敗時に**リトライが続く**（最悪、長期間）ので、重複実行に耐える設計が必須です。([Firebase][5])

つまり結論👇
**リトライは「書いた覚えがなくても」起きる** 😇🌧️

---

## 4) 事故のイメージ図：二重注文が生まれるまで🖼️💥

たとえば「注文作成（POST /orders）」が冪等じゃない世界で…👇

```text
t=0s   クライアント：POST /orders 送信 📨
t=1s   サーバー：DBに注文レコード作成 ✅（注文#123）
t=2s   ネットワーク：返事が遅くてクライアント側タイムアウト ⏱️💥
t=3s   クライアント：失敗だと思って再送 POST /orders 📨
t=4s   サーバー：またDBに注文レコード作成 ✅（注文#124）
t=5s   ユーザー：注文が2個ある…😱
```

ポイントはここ👇

* **サーバーは悪くない**（普通に処理しただけ）
* **クライアントも悪くない**（失敗に見えたから再送しただけ）
* 悪いのは「再送が起きる世界で、非冪等な操作をそのままにした」こと⚠️

---

## 5) 「じゃあ、どうするの？」の方向性（超ざっくり）🧭✨

この章では“理由”が主役なので、解決は軽く触れるだけにします🙂

* **冪等にしやすい操作（PUT/DELETE）を選ぶ**
  HTTP では PUT/DELETE（と safe なメソッド）は冪等として定義されています。([RFCエディタ][2])
* **POST のような“増える操作”には「冪等キー」などの仕組みを足す**🔑
  IETF の Internet-Draft でも `Idempotency-Key` ヘッダーで、POST/PATCH を**フォールトトレラント（再送に強く）**する狙いが説明されています。([datatracker.ietf.org][6])
  Stripe でも、接続エラー時に安全に再送するために冪等キーを使うよう案内されています。([Stripe ドキュメント][7])
  AWS も「分散システムでは exactly once が難しいので、トークンで重複を吸収しよう」という考えをベストプラクティスとして書いています。([AWS ドキュメント][8])

---

## 📝演習：タイムアウト時の“最悪シナリオ”を図にしよう🖊️🖼️

次の3つを、矢印でつないだ図にしてみてね（絵が雑でもOK！）😊

1. クライアント（ブラウザ/アプリ）📱💻
2. サーバー（API）🖥️
3. DB（保存）🗄️

そして、図の中にこのイベントを書き込む👇

* 「送信」📨
* 「DB保存」✅
* 「タイムアウト」⏱️
* 「再送」🔁
* 「二重作成」💥

できたら最後に一言👇
**「どの瞬間から “成功か失敗か不明” になる？」** 🤔

---

## 🤖AI活用：事故パターンを“図解テキスト”にしてもらう🧩✨

AI にこう頼むと、理解が速いよ〜🙂

* 「**注文作成APIがタイムアウトして再送されたとき**に起こる事故を、t=0〜のタイムラインで図解して」⏱️
* 「**成功したのに返事が届かない**ケースを、クライアント視点/サーバー視点で分けて説明して」👀
* 「同じ処理が2回走ると困る例を、**決済以外で5つ**挙げて」🧾🎫📦📩

出てきた答えに対しては最後にこれだけチェック✅

* 「**何が二重になる？**」
* 「**どの条件で再送される？**」

---

## ✅この章のまとめ（ここだけ覚えればOK）🌸

* リトライは「必ず起きるもの」😇🔁
* 一番危ないのは **“成功したのに返事が届かない”** 🙃📨
* だから、変更系の操作（注文/決済/在庫など）は **再送に耐える設計**が必要⚠️
* 次の章以降で、用語整理 → HTTP設計 → 冪等キー、の順に固めていくよ🔑✨

[1]: https://docs.cloud.google.com/run/docs/configuring/request-timeout "Configure request timeout for services  |  Cloud Run  |  Google Cloud Documentation"
[2]: https://www.rfc-editor.org/rfc/rfc9110.html "RFC 9110: HTTP Semantics"
[3]: https://developer.mozilla.org/en-US/docs/Web/API/Window/fetch "Window: fetch() method - Web APIs | MDN"
[4]: https://cloud.google.com/blog/topics/developers-practitioners/improving-availability-your-cloud-storage-automatic-retries-client-libraries/?utm_source=chatgpt.com "Automatic retries in client libraries"
[5]: https://firebase.google.com/docs/functions/retries "Retry asynchronous functions  |  Cloud Functions for Firebase"
[6]: https://datatracker.ietf.org/doc/html/draft-ietf-httpapi-idempotency-key-header-03 "
            
                draft-ietf-httpapi-idempotency-key-header-03
            
        "
[7]: https://docs.stripe.com/api/idempotent_requests "docs.stripe.com"
[8]: https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_prevent_interaction_failure_idempotent.html "REL04-BP04 Make mutating operations idempotent - Reliability Pillar"

