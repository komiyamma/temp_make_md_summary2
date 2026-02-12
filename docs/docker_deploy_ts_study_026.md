# 第26章：スケールと同時実行：料金と性能の勘所 📈💰

## この章のゴール 🎯

* 「速いけど高い」「安いけど遅い」を **設定でコントロール**できるようになる😎
* ざっくりこの4つを説明できるようになる👇

  1. **同時実行（concurrency）**
  2. **最大インスタンス（max instances）**
  3. **最小インスタンス（min instances）**
  4. **タイムアウト（timeout）**

---

## 1) まず“超ざっくり地図”🗺️✨

Cloud Runのスケールは、ざっくりこういう話です👇

* **concurrency** を上げる
  → 1台（1インスタンス）でさばける人数が増える
  → インスタンス数が増えにくい（＝安くなりやすい）
  → でも1台に詰め込みすぎると遅くなる😵‍💫

* **max instances** を下げる
  → “無限スケール”を止める（コスト暴走ブレーキ🛑）
  → ただし混雑時は **待ち行列**が増えて遅くなる

* **min instances** を上げる
  → 冷えた起動（コールドスタート）を減らせる🔥
  → ただし **アイドル中でも課金が発生**しうる💸（※後述）

* **timeout** を短くする
  → 事故を早く切る（無限待ち防止🧯）
  → でも短すぎると普通の処理も504になって悲しい😭

---

## 2) 同時実行（concurrency）って何？👥➡️🧠

## 2-1. 公式の基本（ここが超重要）📌

* Cloud Runは **1インスタンスが同時に処理していいリクエスト数**を設定できます
* **最大は 1000** まで上げられます ([Google Cloud Documentation][1])
* **デフォルト**はちょっとクセがある👇

  * コンソールで作ると **80** ([Google Cloud Documentation][1])
  * `gcloud` / Terraform で **新規サービス作成**すると
    **「80 × vCPU数」** が初期値 ([Google Cloud Documentation][1])
  * しかもこの初期値は **“新規作成時だけ”** で、次のデプロイでは勝手に変わりません ([Google Cloud Documentation][1])

> つまり「いつの間にか concurrency が変わってた」は起きにくいけど、
> 「昔作ったサービスの concurrency が古いまま」は普通に起きます😇

## 2-2. Node/TSだとどう考える？🟦🧵

* Nodeは基本 **シングルスレッド**だけど、I/O（DBや外部API待ち）なら非同期でさばける
* 逆に **CPUをガッツリ使う処理**（画像処理、重い暗号化、大量JSON整形など）だと
  concurrency を上げすぎると **1台の中で渋滞**します🚗🚕🚙

公式も「まずデフォルトで始めて、メトリクス見て調整してね」路線です ([Google Cloud Documentation][1])

---

## 3) お金（課金）でハマらないための最短知識 💸🧠

## 3-1. 課金モデルは2種類（ここで事故が減る）🧾

Cloud Run（サービス）には👇があります：

* **Request-based billing（デフォルト）**
  インスタンスは **リクエスト処理中＋起動/終了中** だけ課金 ([Google Cloud Documentation][2])
  さらに「リクエスト数」も課金対象（無料枠あり） ([Google Cloud][3])

* **Instance-based billing**
  インスタンスが生きてる間ずっと課金（アイドルでも） ([Google Cloud Documentation][2])
  ※昔の呼び名「CPU always allocated」 ([Google Cloud Documentation][2])

> ふつうのWeb APIは **Request-based** が相性よいことが多いです🙆‍♂️
> 背景処理を回したい等は Instance-based が便利な場面があります ([Google Cloud Documentation][2])

## 3-2. min instances は“便利だけど課金する”🔥💸

* min instances を設定すると **処理してない（アイドル）インスタンスを維持**します ([Google Cloud Documentation][4])
* その分、**課金が発生する**と明記されています ([Google Cloud Documentation][4])
* 価格表には **「Idle time (Min instance)」** のレートが別で載っていて、
  「min instance じゃないアイドルは課金されない」とも書いてあります ([Google Cloud][3])

---

## 4) max instances：コストの“上限ロック”🛑💰

* max instances を設定すると「増えすぎ」を止められます（コストやDB接続数の制御に効く） ([Google Cloud Documentation][5])
* ただし **一瞬だけ上限を超える場合がある**（スパイク等）と書かれています ([Google Cloud Documentation][5])
* デフォルトで **revision は最大100インスタンス**になっている、と明記があります ([Google Cloud Documentation][5])
* さらに“理論上の最大”はリージョンの割当やCPU/メモリ設定にも左右されます ([Google Cloud Documentation][6])

---

## 5) timeout：長すぎても短すぎても地獄 ⏱️😇

* デフォルト **5分（300秒）**、最大 **60分（3600秒）** ([Google Cloud Documentation][7])
* タイムアウトすると **接続は切れて504**、でも **インスタンス自体は落ちない** ([Google Cloud Documentation][7])
  → つまり、サーバ側が処理を続けてしまうと **別リクエストに悪影響**になることもある😵‍💫 ([Google Cloud Documentation][7])

---

## 6) ハンズオン：同時実行とスケールを“目で見る”👀🔥

ここからは「設定を変える → 負荷をかける → メトリクスを見る」の流れでいきます🚀
（※URLは第25章で作ったCloud RunのURLを使う想定）

---

## 6-1. テスト用エンドポイントを足す（10分）🧪

Express想定で「遅い処理」を作ります（I/O待ちの擬似）👇

```ts
// src/routes/debug.ts (例)
import { Router } from "express";

export const debugRouter = Router();

debugRouter.get("/sleep", async (req, res) => {
  const ms = Math.min(Number(req.query.ms ?? 500), 60_000);
  await new Promise<void>((r) => setTimeout(r, ms));
  res.json({ ok: true, sleptMs: ms, at: new Date().toISOString() });
});
```

※CPUを食う版も作りたいなら👇（やりすぎ注意💥）

```ts
debugRouter.get("/burn", (req, res) => {
  const ms = Math.min(Number(req.query.ms ?? 200), 10_000);
  const end = Date.now() + ms;
  while (Date.now() < end) {
    // busy loop
  }
  res.json({ ok: true, burnedMs: ms });
});
```

---

## 6-2. まず“メトリクスを見る場所”を開く（2分）📊👀

Cloud Runのサービス画面で、最低これを見ます👇

* **Instance count（インスタンス数）**
* **Request latency（レイテンシ）**（p50 / p95あたり）
* **CPU / Memory**（見える範囲で）

---

## 6-3. 負荷をかける（Windowsで一番ラクなやり方）🪟⚡

## 方式A：Dockerで `hey` を使う（インストール不要）🐳

例：30秒間、同時50で叩く

```bash
docker run --rm ghcr.io/rakyll/hey -z 30s -c 50 "https://YOUR_URL/sleep?ms=200"
```

* `-c` を増やす＝同時アクセスを増やす
* `ms=200` を増やす＝1回の処理時間を長くする

## 方式B：Dockerで k6（もう少し本格）📈

（好みでOK）

---

## 6-4. 実験1：concurrency を変える（これが本題）👥🔧

## パターン①：デフォルト（基準）

まずは何も変えずに叩いて、

* インスタンスが何台まで増えたか
* p95がどれくらいか
  をメモ📝

## パターン②：concurrency=1（スケールしやすくなる）

```bash
gcloud run services update SERVICE_NAME --concurrency=1
```

もう一度 `hey`。
だいたい👇が起きます：

* 1台が1人しか相手しないので **インスタンスが増えやすい**
* ただしインスタンス起動が増えるので **起動待ち**が出やすいことも😵‍💫

公式も「concurrencyを下げると同じリクエスト量でもインスタンスが増える」と説明しています ([Google Cloud Documentation][1])

## パターン③：concurrencyを上げる（安くなる可能性）

例：200（状況により80〜200くらいで試すのが現実的🙆‍♂️）

```bash
gcloud run services update SERVICE_NAME --concurrency=200
```

結果の見方👇

* インスタンス数が減る＝コスト効率は上がりやすい📉
* でも p95 が悪化するなら「詰め込みすぎ」サイン🚨

---

## 6-5. 実験2：max instances で“コスト暴走ブレーキ”🛑

例：最大3台に制限

```bash
gcloud run services update SERVICE_NAME --max-instances=3
```

叩くと👇が起きがち：

* さばき切れず **待つ** → レイテンシ増
* 最悪、クライアント側タイムアウトや失敗が増える😇

max instances はコスト制御やバックエンド（DB等）保護に有効、と公式にあります ([Google Cloud Documentation][5])

---

## 6-6. 実験3：min instances で“冷え”を減らす🔥

```bash
gcloud run services update SERVICE_NAME --min-instances=1
```

* これで「常に最低1台」が温存されます ([Google Cloud Documentation][4])
* ただし **課金が発生する**と明記されています ([Google Cloud Documentation][4])

> コールドスタート対策は気持ちいいけど、
> 使わない時間が長いサービスだと普通にお金が増えます💸😇

---

## 6-7. 実験4：timeout を体感する⏱️

例：10秒にして、20秒sleepを叩く

```bash
gcloud run services update SERVICE_NAME --timeout=10s
```

```bash
curl "https://YOUR_URL/sleep?ms=20000"
```

* 504が返りやすくなります（公式：タイムアウトで接続が閉じて504） ([Google Cloud Documentation][7])
* しかも “インスタンスは落ちない” ので、サーバ側処理が続くと混雑の原因にも ([Google Cloud Documentation][7])

---

## 7) ありがちな事故トップ5 😵‍💫🧯

1. **concurrency上げたら遅くなった**
   → 詰め込みすぎ。CPU/メモリに余裕がないか、処理がCPU寄り。

2. **concurrency=1で安定したけど、スパイクに弱い**
   → 起動台数が増えるので、瞬間的に追いつかないことがある（起動待ち）😇

3. **max instances 低すぎて“混雑時に死ぬ”**
   → ブレーキ強すぎ。現実のピークに合わせて決める。

4. **min instances 入れたら請求が増えた**
   → 仕様です🔥（アイドル維持に課金が発生） ([Google Cloud Documentation][4])

5. **timeout短すぎて504祭り**
   → だいたい「普段のp95×2」くらいから調整スタートが安全🛡️
   （最大60分・デフォルト5分は公式） ([Google Cloud Documentation][7])

---

## 8) “最初のおすすめ設定”テンプレ（個人開発のAPI向け）🧩✨

最初はこれで始めて、計測して微調整が一番ラクです😄

* concurrency：**デフォルト**（まずは触らない） ([Google Cloud Documentation][1])
* max instances：**10〜30**（小さめに上限を持たせる） ([Google Cloud Documentation][5])
* min instances：**0**（まずは無料寄り＆様子見） ([Google Cloud Documentation][4])
* timeout：**30〜120秒**（APIなら長すぎないのが吉） ([Google Cloud Documentation][7])
* 課金モデル：基本 **Request-based**（デフォ） ([Google Cloud Documentation][2])

> そして **メトリクスを見て**、「遅い原因」が concurrency なのか CPU/メモリなのかを当てにいきます🎯

---

## 9) AIに投げると強いプロンプト例 🤖💬

* 「このAPIはI/O待ちが多い？CPUが多い？ログとコードから推測して、Cloud Runのconcurrency初期案を出して」
* 「p95が悪化した。concurrency / max instances / timeout のどれから疑うべきか、原因の見分け方を順番に教えて」
* 「Cloud Runのメトリクス（instance count, latency, CPU）を見て、次に触る設定を1つだけ選んで理由も書いて」

---

## 10) ミニ理解チェック（3問）✅🧠

1. concurrency を上げると、インスタンス数は増えやすい？減りやすい？🤔
2. min instances を 1 にすると、何が嬉しくて何が痛い？🔥💸
3. timeout で 504 になったとき、コンテナは落ちる？処理は止まる？😇

---

次の第27章は **「ヘルスチェック（落ちたら戻る）」**で、運用っぽさが一気に増えて楽しくなります🩺🔁
もしよければ、今のアプリ（第25章でデプロイしたやつ）が **API寄り**か **Web（SSR/SPA配信）寄り**かだけ教えてくれたら、この章の“おすすめ初期値”をもう一段だけ寄せた版も作れます😊

[1]: https://docs.cloud.google.com/run/docs/about-concurrency "Maximum concurrent requests for services  |  Cloud Run  |  Google Cloud Documentation"
[2]: https://docs.cloud.google.com/run/docs/configuring/billing-settings "Billing settings for services  |  Cloud Run  |  Google Cloud Documentation"
[3]: https://cloud.google.com/run/pricing "Cloud Run pricing | Google Cloud"
[4]: https://docs.cloud.google.com/run/docs/configuring/min-instances "Set minimum instances for services  |  Cloud Run  |  Google Cloud Documentation"
[5]: https://docs.cloud.google.com/run/docs/configuring/max-instances "Set maximum instances for services  |  Cloud Run  |  Google Cloud Documentation"
[6]: https://docs.cloud.google.com/run/docs/configuring/max-instances-limits "About maximum instances  |  Cloud Run  |  Google Cloud Documentation"
[7]: https://docs.cloud.google.com/run/docs/configuring/request-timeout "Configure request timeout for services  |  Cloud Run  |  Google Cloud Documentation"
