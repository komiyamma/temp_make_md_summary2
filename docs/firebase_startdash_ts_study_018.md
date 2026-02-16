# 第18章：料金・クォータ事故を避ける：最初に付ける“安全装置”💸🧯

この章は「**気づいたら課金が増えてた😱**」を防ぐための、**最初の安全装置3点セット**を入れます🔧✨
（あとでFirestore/Storage/Functions/AIを触るほど、この章の価値が効いてきます💪）

---

## この章のゴール🎯

* Spark / Blaze の違いを「課金事故目線」で説明できる🙂
* **予算アラート（Budget）**を作って、通知が飛ぶ状態にする🔔
* 「アラート＝停止装置じゃない」を腹落ちさせる⚠️([Firebase][1])

---

## 0) まず最初に押さえる“超重要3行”📌

1. **予算アラートは“上限ストップ”じゃない**（使いすぎたら教えてくれるだけ）⚠️([Firebase][1])
2. **通知には遅れがある**（サービスによっては数日ズレることもある）⏳([Firebase][1])
3. Firebaseの課金は裏で **Google Cloud の課金（Cloud Billing）**とつながっている🔗([Firebase][1])

---

## 1) Spark / Blaze を「事故らない視点」で理解する🧠💡

* **Spark**：支払い情報なしで開始できる無料プラン🌱
* **Blaze**：課金アカウント（Cloud Billing）を紐づけて、従量課金で広く使える🔥

  * ただし **無料枠（no-cost usage quota）**も同時に持ってて、超えた分だけ課金されるイメージ💰([Firebase][2])
* 大事ポイント：**無料枠は「プロジェクト単位」**。アプリ単位じゃないよ🧯([Firebase][3])

---

## 2) 2026/2 時点での「ここが罠！」早見⚠️🧨

## ✅ Blaze が必要になりやすい代表例

* **Cloud Functions**：Blaze で利用できる代表格⚙️([Firebase][2])
* **Cloud Storage for Firebase**：ここは特に注意‼️

  * `*.appspot.com` のデフォルトバケットを使っている場合、**2026年2月3日以降** Spark のままだとコンソールから見えなくなったり、APIが **402/403** を返す挙動が明記されています🚨([Firebase][4])

> つまり「無料でStorageだけ使う」は、以前より成立しにくいです。
> 使うなら **Blaze + 安全装置** がセット🔔🧯([Firebase][4])

---

## 3) 安全装置①：予算（Budget）とアラートを作る🔔💸

ここが本章のメインです💪✨
予算は **Google Cloud 側の Cloud Billing** で作ります。([Google Cloud Documentation][5])

## 3-1. どこから行く？（迷子防止）🧭

* Firebase コンソール → プロジェクト → **Usage & billing**（課金まわり）へ
* そこから **Google Cloud の Billing（課金）画面**へ飛ぶのが王道ルート🛣️([Firebase][1])

## 3-2. 作成手順（初心者向けの型）🧩

1. **Billing（課金）アカウント**を確認👀
2. **Budgets & alerts（予算とアラート）**を開く🔔
3. 予算の対象を「このプロジェクト」に絞る（事故りにくい）🎯
4. 期間はまず **Monthly（月）** が無難📅([Google Cloud Documentation][5])
5. 予算額は“学習用なら小さく”

   * 例：**¥500 / ¥1,000 / ¥3,000**（自分の心理的安全ラインでOK）💴
6. しきい値（通知トリガー）を入れる

   * **50% / 90% / 100%** の3段が鉄板🔔🔔🔔
7. 通知先に自分のメールを入れて完成📩

## 3-3. 重要な注意（ここで事故が減る）🧯

* 予算は **勝手に利用や請求を止めません**✋（通知だけ）([Google Cloud Documentation][5])
* 通知はリアルタイムではなく **遅れがありうる**ので、予算は「上限ジャスト」じゃなく余裕を持つのが安全⏳([Firebase][1])
* 予算やアラートを作るには **課金アカウントの Owner 権限**が必要なケースがあります👑([Firebase][1])

---

## 4) 安全装置②：本当に止めたいときの“止め方”🛑🔌

「通知が来た！でも寝てた！😴」みたいな不安があるなら、**“止める手段”**も知っておくと安心です。

## 方法A：手動で Billing を無効化（確実だが影響大）🧨

* 課金を無効化すると、そのプロジェクトの **Google Cloud サービスが停止**します（無料枠のサービスも含む）🛑([Google Cloud Documentation][6])

## 方法B：予算通知を使って“自動で止める”発想（上級寄り）🤖📣

* Google Cloud は **予算通知を使って、プログラム的にコスト制御**する道も用意しています（Pub/Sub など）🧠([Google Cloud Documentation][5])
* ただしこれも **通知の遅れで予算超過は起こり得る**ので、最大予算は余裕を見て設定が推奨です⚠️([Google Cloud Documentation][6])

> 今は「存在を知る」だけでOK👌
> 本格的に必要になったら、Functions/Cloud Run と一緒に組むのが現実的です⚙️

---

## 5) 安全装置③：日常の“メーター”を見る習慣📈👀

「設定したら終わり」じゃなくて、**見る場所を固定**すると事故が激減します✨

* Firebase 側：Usage & billing（プロジェクトの課金入口）🧭([Firebase][1])
* Google Cloud 側：Cloud Billing の予算・レポート（実際の請求の本丸）🏦([Google Cloud Documentation][5])

---

## 6) 典型的な“課金事故”パターン6選🧨😇

1. **Storageを使ったらBlaze必須だった**（2026/2/3以降の要件に注意）🪣([Firebase][4])
2. **Firestoreの読み書きが想定以上に増える**（無料枠は日次でリセット、プロジェクトごと、DBは1つだけ等）📚([Firebase][7])
3. **App Check を入れたら reCAPTCHA の回数が増える**（reCAPTCHA Enterprise は月1万までは無料だが超えると費用）🛡️([Firebase][8])
4. **AI呼び出しが“思ったよりトークン食う”**（AI Logic / Gemini API はBlazeだと従量課金が前提になりやすい）🤖💬([Firebase][9])
5. **Hosting/App Hosting で想定外の通信（特にダウンロード）**🌐💨（まずはUsageで傾向を見るのが安全）([Firebase][1])
6. **Extensions/Functions を試して、止め忘れる**🧩⚙️（Blaze前提になりやすい代表）

---

## 7) Gemini CLI / AIエージェントで“安全点検”するプロンプト例🤖🧪

コピペで使えるやつ置いとくね📌（秘密情報は貼らないでOK🙅‍♂️）

```text
あなたはFirebaseのコスト監査役です。
このプロジェクトで「課金が増える原因」を優先度順に列挙してください。

条件:
- 予算アラート（Budget）は上限停止ではなく通知である点を踏まえる
- 予算超過を避けるための具体的な設定案（予算額/しきい値/見るべき画面）を提案
- 特に Cloud Storage / Firestore / AI（Firebase AI Logic） での事故パターンを重点的に
出力:
1) リスクTOP5
2) 今すぐ入れる安全装置チェックリスト（10項目）
3) 学習用の推奨Budget例（小額で）
```

AI（Firebase AI Logic）を使う予定があるなら、これも便利👇
（「送る前にだいたいのトークン感を見積もる」発想）([Firebase][9])

```text
Firebase AI Logic を使う予定です。
「コストが跳ねる典型パターン」と「maxOutputTokens / thinking budget を小さく始める設定方針」を
初心者向けに説明して。countTokensで事前見積もりする狙いも入れて。
```

---

## 8) ミニ課題：月¥500で“必ず気づける”アラートを作る💴🔔

* 予算：¥500（または自分が絶対に許せる小額）
* 通知：50% / 90% / 100%
* できたら、通知先メールが自分になってるのを確認📩
* 最後に一言メモ：

  * 「予算は停止装置じゃない。通知が来たら自分で止める」✍️([Firebase][1])

---

## 9) チェック問題（3つ答えられたら勝ち）✅🎉

1. 予算アラートが **停止装置じゃない理由**を1行で言える？⚠️([Firebase][1])
2. 2026年2月3日以降、Storageまわりで何が起きうる？🪣([Firebase][4])
3. Firestoreの無料枠が「日次リセット」なのは、どのタイムゾーン基準？🌎([Firebase][7])

---

## この章のまとめ🧷✨

* **Spark/Blazeの違い**を“事故目線”で理解🙂([Firebase][2])
* **Budget & alerts を設定**して、通知で確実に気づけるようにした🔔([Google Cloud Documentation][5])
* 「止めたいならどうする？」の方向性も掴んだ🛑([Google Cloud Documentation][6])

次の章（第19章）は、Functions/AIに入る前に「言語とバージョン感」だけ先に押さえて、迷子を減らす回になるよ👀⚙️

[1]: https://firebase.google.com/docs/projects/billing/avoid-surprise-bills "Avoid surprise bills  |  Firebase Documentation"
[2]: https://firebase.google.com/docs/projects/billing/firebase-pricing-plans "Firebase pricing plans  |  Firebase Documentation"
[3]: https://firebase.google.com/pricing "Firebase Pricing"
[4]: https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024 "FAQs about changes to Cloud Storage for Firebase pricing and default buckets"
[5]: https://docs.cloud.google.com/billing/docs/how-to/budgets "Create, edit, or delete budgets and budget alerts  |  Cloud Billing  |  Google Cloud Documentation"
[6]: https://docs.cloud.google.com/billing/docs/how-to/disable-billing-with-notifications "Disable billing usage with notifications  |  Cloud Billing  |  Google Cloud Documentation"
[7]: https://firebase.google.com/docs/firestore/quotas "Usage and limits  |  Firestore  |  Firebase"
[8]: https://firebase.google.com/docs/app-check "Firebase App Check"
[9]: https://firebase.google.com/docs/ai-logic/pricing "Understand pricing  |  Firebase AI Logic"
