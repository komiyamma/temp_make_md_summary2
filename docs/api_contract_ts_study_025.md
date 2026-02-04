# 第25章：APIバージョニング②：移行の運用（旧版サポート）⏳🧡

## この章のゴール🎯✨

* **旧版（v1）を残しつつ新版（v2）へ移行**する運用ができるようになる🪜
* **「いつまでサポートするか」**を決めて、**告知→計測→移行→廃止**まで安全に回せるようになる🧯
* **利用率（メトリクス）**を見ながら、炎上しない「やさしい廃止」ができるようになる📊💕

---

## まず大事な感覚😵‍💫➡️🙂

APIバージョン移行で揉める原因、だいたいこの3つ👇

1. **期限が曖昧**（いつまで使えるの？）
2. **移行手段が弱い**（どう直せばいいの？）
3. **利用状況が見えてない**（誰がまだ使ってるの？）

なので運用は、ざっくり言うとこの順番が鉄板です👇
**期限を決める🗓️ → 伝える📣 → 計測する📊 → 移行を助ける🧡 → 段階的に止める🧱**

---

## キーワード辞典📚✨

* **Deprecation（非推奨）**：まだ動くけど「もう新規利用はおすすめしないよ〜」の宣言🚧
  HTTPでは `Deprecation` ヘッダーで「いつから非推奨か」を伝えられるよ📩([RFCエディタ][1])
* **Sunset（廃止予定日）**：「この日時以降は動かなくなるかも」宣言🌇
  HTTPでは `Sunset` ヘッダーで「いつ不通になる予定か」を伝えられるよ📩([RFCエディタ][2])
* **サポート期間（support window）**：旧版を“どのレベルで”いつまで面倒見るか⏳
  例：最低24か月通知など、プロダクトごとにポリシーを持つケースがあるよ📜([Microsoft Learn][3])
* **利用率（adoption / usage）**：v1がどれだけ呼ばれてるか（誰が残ってるか）📊
  「廃止するなら計測して追跡が必須」ってガイドラインでも明言されがち💡([SailPoint OSS][4])

---

## 25-1. 旧版サポートを「3段階」で設計しよう🏗️💞

旧版（v1）を残すときは、まず **“何をどこまで守るか”** を段階にするのが超大事🧠✨
おすすめはこの3段階👇

## レベルA：フルサポート💚

* バグ修正もする
* 仕様の質問も答える
* 互換性バグは優先的に直す

## レベルB：保守サポート🟡

* **重大バグ・セキュリティ・障害系のみ**対応
* 新機能は入れない
* ドキュメントは「移行してください」中心に

## レベルC：終了準備🧡➡️🟥

* 新規クライアントは使わせない（後述）
* 期限に向けて強めに通知
* 廃止日以降はエラー（`410 Gone` や `426 Upgrade Required` など）にする

> ここを決めずに「とりあえずv1残すね〜」が一番危ない😇💥

---

## 25-2. “期限”を決めるときの考え方🗓️🔁

期限は「気分」ではなく、**移行に必要な現実の時間**で決めるのが安定🧁✨
（外部の例として、最低24か月通知を掲げるAPIもあるし([Microsoft Learn][3])、少なくとも12か月通知を明示する利用規約もあるよ([Google Cloud][5])）

## 期限を決めるためのチェック項目✅

* クライアントが **モバイル**？（ストア審査＆配信で遅れやすい📱⏳）
* **B2B**で相手のリリースが遅い？（社内稟議・検証が長い🏢）
* SDK利用？（SDK更新→アプリ更新→配布 の二段階📦）
* 互換性テストはある？（CDC/自動テストがないと移行が伸びる😵‍💫）

---

## 25-3. “告知”は3レイヤーで出す📣🌈

告知は「見た人だけ得する」方式だと漏れるよ〜😭
なので **3レイヤー**で出すのが王道👇

1. **ドキュメント（仕様・移行ガイド）**🧾
2. **ランタイム通知（HTTPヘッダー等）**📩
3. **直接通知（メール/ダッシュボード/管理画面）**💌

特にランタイム通知は強い✨
`Deprecation` ヘッダーは「非推奨になった/なる」を伝えるための標準で、**非推奨＝動作変更ではない**（“情報”）という立て付けも明確だよ📌([RFCエディタ][1])
`Sunset` ヘッダーは「この日時以降は不通になりうる」を伝える標準だよ📌([RFCエディタ][2])

---

## 25-4. HTTPヘッダーで「移行の合図」を出す📩🚧🌇

## 使うヘッダー（最小セット）✨

* `Deprecation: @<unix秒>`（Structured Fields のDate型）
  例：`Deprecation: @1688169599`([RFCエディタ][1])
* `Sunset: <HTTP-date>`
  例：`Sunset: Sat, 31 Dec 2018 23:59:59 GMT`([RFCエディタ][2])
* `Link: <...>; rel="deprecation"`（「詳しい移行ページここだよ」📎）([RFCエディタ][1])

## Expressでの実装例（TypeScript）🧩✨

```ts
import type { Request, Response, NextFunction } from "express";

const DEPRECATION_UNIX = 1767225599; // 例: 2025-12-31T23:59:59Z
const SUNSET_HTTP_DATE = "Wed, 31 Dec 2025 23:59:59 GMT";

export function v1DeprecationHeaders(req: Request, res: Response, next: NextFunction) {
  // Deprecation: RFC 9745 (Structured Fields Date; "@unix")
  res.setHeader("Deprecation", `@${DEPRECATION_UNIX}`);

  // Sunset: RFC 8594 (HTTP-date)
  res.setHeader("Sunset", SUNSET_HTTP_DATE);

  // "deprecation" link relation: where to read migration guide
  res.setHeader("Link", `<https://example.com/docs/api/v1-migration>; rel="deprecation"`);

  next();
}
```

> ポイント💡：`Deprecation` は「動作変更」じゃなくて「通知」だよ、ってRFCでも明示されてる📌([RFCエディタ][1])
> `Sunset` は「この時刻を過ぎたら4xxになったり、リダイレクトになったり、接続できなくなるかも」って扱い📌([RFCエディタ][2])

---

## 25-5. “利用率（メトリクス）”で移行をコントロールする📊🧡

「誰が残ってるか分からない」のが炎上の元🔥
だから **旧版がSunset予定なら利用状況を監視しろ**ってガイドでも強めに言われるよ📌([SailPoint OSS][4])

## 最低限ほしいメトリクス🎯

* **v1リクエスト数**（日次/週次）
* **ユニーク利用者数**（APIキー、テナントIDなど）
* **v1利用トップN**（大口が残ってると危険⚠️）
* **v1のエラー率**（移行で壊れた兆候）
* **v2の移行率**（v1→v2の置き換えが進んでるか）

参考：たとえば Kubernetes は「deprecated APIへのリクエスト」をメトリクスで観測したり、Warningヘッダーを返したり、監査ログに印を付けたりする設計になってるよ📈([Kubernetes][6])

---

## 25-6. 旧版サポートの「運用レシピ」7ステップ🪜✨

## Step 1：移行先を“先に”用意する🛠️💗

* v2を先に出す（少なくともベータでもOK）
* 仕様とサンプルを揃える
* SDKがあるならSDKもv2対応を出す

## Step 2：期限とサポート段階を決める🗓️🧱

* 「非推奨日」「Sunset日」「完全停止日（実質Sunset）」を決める
* 旧版サポートをA/B/Cのどれにするか決める

## Step 3：告知を出す📣💌

* Docs/CHANGELOG/管理画面/メール
* ランタイム通知（`Deprecation` / `Sunset` / `Link`）も開始([RFCエディタ][1])

## Step 4：計測を開始する📊🔍

* v1の利用者を特定
* 「移行できてない人にだけ」丁寧に追いかける

## Step 5：新規利用を止める（だけど既存は守る）🚧🧡

* 新規APIキーはv1不可、など
* SDKはv2をデフォルトに
* ドキュメントもv2を主に（v1は“移行してね”に寄せる）

## Step 6：移行支援をガチる🧁🤝

* 移行ガイド（差分一覧、置換表、実例）
* FAQ（よく詰まる箇所）
* 互換レイヤ（v1→内部v2変換）を作るのも超有効✨

## Step 7：Sunset（廃止）を実行する🌇🟥

* 廃止日以降は `410 Gone` などを返す
* 直前は“最後の通知”を強めに
* 廃止後もしばらく「問い合わせ導線」だけは残す（優しさ🧡）

> 実際に「告知→停止日」が明確に並んでいる例として、OpenAI のAPIのdeprecationsページは **推奨置き換え**や**停止日**をセットで出す運用になってるよ🗓️([OpenAI Platform][7])

---

## 25-7. “廃止スケジュール”テンプレ🗓️🧾

## 例：12週間の移行プラン（イメージ）🌸

* **Week 0**：v2リリース、移行ガイド公開📘
* **Week 1**：v1に `Deprecation` / `Sunset` / `Link` を付与📩
* **Week 2**：利用率ダッシュボード公開、上位利用者へ個別連絡📊💌
* **Week 4**：v1はレベルB（保守のみ）へ🟡
* **Week 6**：新規利用禁止（新規キーはv1不可など）🚧
* **Week 10**：v1利用者へ最終通知（Top Nを重点フォロー）🔥
* **Week 12**：Sunset（v1停止）🌇🟥

---

## 25-8. よくある落とし穴（ここで事故る🥲）

* **“期限だけ決めた”けど移行先が弱い**（移行不能で炎上🔥）
* **告知がドキュメントだけ**（ランタイム通知がないと漏れる📉）
* **利用率が取れてない**（誰が残ってるか不明で止められない😵‍💫）
* **SDK更新の遅さをナメる**（アプリ配布まで長い📱⏳）
* **“非推奨”なのに挙動を変えちゃう**（信頼が壊れる💔）
  `Deprecation` はあくまで通知で、動作変更そのものではない立て付けだよ📌([RFCエディタ][1])

---

## 25-9. ミニ演習📝✨（20〜40分）

## 演習1：廃止スケジュールを作る🗓️🧡

次の条件で「Week 0〜Week 12」計画を作ってみよう👇

* v1利用者が100社
* 上位10社で80%のトラフィック
* モバイルアプリもある（リリース遅め）

**提出物**：

* 週ごとの施策（告知・計測・新規停止・最終停止）
* “Top10社向け”の個別フォロー案💌

## 演習2：メトリクス設計📊

「最低限のログ項目」を箇条書きしてみよう👇

* APIキー（or テナントID）
* バージョン（v1/v2）
* エンドポイント
* ステータスコード
* レイテンシ
* クライアント種別（SDK/直叩き など）

---

## 25-10. AI活用プロンプト集🤖✨（コピペOK）

* 「v1→v2の**差分一覧**を、利用者目線で表にして。破壊変更ポイントは強調して」📋🤖
* 「移行ガイドの章立てを作って。**最短で移行できる手順**を先に出して」🪜🤖
* 「このOpenAPI（または仕様）から、**移行手順のドラフト**を書いて」🧾🤖
* 「v1レスポンスに付ける `Deprecation` / `Sunset` / `Link` の実装を、ミドルウェアで書いて」🧩🤖
* 「“Top 10利用者”向けの丁寧な移行案内文を作って（短め/普通/長めの3種）」💌🤖

---

## 25-11. 仕上げチェックリスト✅🌸

* [ ] 旧版サポートの段階（A/B/C）が決まってる
* [ ] **非推奨日**と**Sunset日**が明文化されてる
* [ ] v1レスポンスに `Deprecation` / `Sunset` / `Link` が付く([RFCエディタ][1])
* [ ] v1利用率（誰が残ってるか）が見えるダッシュボードがある([SailPoint OSS][4])
* [ ] 移行ガイドに「差分」「置換」「実例」「FAQ」がある
* [ ] 新規利用を止める仕組みがある（既存は守る）
* [ ] Sunset後のエラー設計（410/426など）と問い合わせ導線がある

---

[1]: https://www.rfc-editor.org/rfc/rfc9745.html?utm_source=chatgpt.com "RFC 9745: The Deprecation HTTP Response Header Field"
[2]: https://www.rfc-editor.org/rfc/rfc8594.html "RFC 8594: The Sunset HTTP Header Field"
[3]: https://learn.microsoft.com/en-us/graph/versioning-and-support "Versioning, support, and breaking change policies for Microsoft Graph - Microsoft Graph | Microsoft Learn"
[4]: https://sailpoint-oss.github.io/sailpoint-api-guidelines/ "SailPoint RESTful API Guidelines"
[5]: https://cloud.google.com/archive/maps-platform/terms-20200506 "Google Maps Platform Terms Of Service | Google Cloud"
[6]: https://kubernetes.io/docs/reference/using-api/deprecation-policy/ "Kubernetes Deprecation Policy | Kubernetes"
[7]: https://platform.openai.com/docs/deprecations "Deprecations | OpenAI API"
