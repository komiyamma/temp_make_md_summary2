# 第03章：Consoleの歩き方：迷子にならない最低ルート🔧🚦

この章のゴールはシンプルです👇
**「ここだけ覚えれば、とりあえず迷子にならない！」**っていう“最低ルート”を身体に入れます🧠✨
（Firebaseは機能が多いので、最初は**道順だけ**覚えるのが勝ちです🏁）

---

## 読む：Consoleは「3つの場所」さえ押さえればOK🙂🧭

Firebase Consoleで、初心者がまず触るべき場所はこの3つです👇

1. **Project Overview（プロジェクトの玄関）**🏠

* いま見てるプロジェクトが正しいか、まずここで確認✅
* “Webアプリ追加”もここから入ることが多いです ([Firebase][1])

2. **Project settings（設定の本丸）⚙️**

* **WebアプリのSDK設定（firebaseConfig）**を探す場所がここ🎯
* 具体的には **Project settings → General → Your apps →（対象のWebアプリ）→ Config** です ([Firebase][2])

3. **Usage & billing（お金と使用量の交通整理）💸🚧**

* Firebase/Google Cloud側の利用状況がまとまって見えるダッシュボードです👀
* “いつの間にか課金”の芽を早めに見つける場所🌱 ([Googleヘルプ][3])

ついでに超重要な現実として👇
**Cloud Storageは条件によってBlaze（従量課金）必須になるケースがある**ので、こういう告知を“見に行ける導線”を持つのが大事です🧯（今後の章で触る時に効きます） ([Firebase][4])

---

## 手を動かす：迷子ゼロの“最低ルート”を実際に歩く🚶‍♂️🗺️

### 0) まず「いまどのプロジェクト？」を毎回チェック✅

* Firebase Consoleを開いたら、**左上のプロジェクト名**を見る👀
* もし違ったらプロジェクト切り替え🔁
  👉 これだけで事故率が激減します💥

---

### 1) Project Overviewに戻れるようになる🏠🔙

やることは1つ👇

* 左メニュー（または上部）から **Project Overview** に戻る

**コツ**：

* 迷ったら「玄関に戻る」🏠
* 玄関に戻れば、だいたい“やりたい導線”が見つかります😄

---

### 2) Project settings（⚙️）に最短で行く⚙️🚀

次に覚えるのはこれ👇

* **Project Overviewの近くにある⚙️（歯車） → Project settings** ([Firebase][2])

ここに辿り着ければ、今後ほぼ勝ちです🏆

---

### 3) 「WebアプリのSDK設定（firebaseConfig）」を見つける🏷️🌐

やること👇

* **Project settings → General** を開く
* 下の方へスクロールして **Your apps** を見つける
* 自分の **Webアプリ** を選ぶ
* **Firebase SDK snippet** 的なところで **Config** を選んでコピー📋 ([Firebase][2])

**ここでの注意（初心者あるある）⚠️**

* 「SDKのコードどこ！？」→ **Generalタブの下の方**にあります（だいたい“下の方”）🧻
* Webアプリをまだ作ってないと出ません → その場合はProject OverviewからWeb追加の導線へ ([Firebase][1])

---

### 4) Usage & billing に行って“見る場所”だけ覚える💸👀

* Console内の **Usage and billing（使用量と請求）** を開いて、
  「こんな画面があるんだな〜」って眺めるだけでOKです🙂 ([Googleヘルプ][3])

**ここで見るポイント3つ👀✨**

* 料金プラン（Spark / Blaze）っぽい情報はどこにある？
* どのサービスが使われてる？（Auth/Firestore/Hosting…）
* “急に増えたらヤバい”のは何っぽい？（回数・通信量・ストレージなど）📈

---

### 5) （おまけ）Google Cloud側の「Budgets & alerts」入口だけ見ておく🔔💳

Firebaseだけだと「止める」系のコントロールが弱いので、
**Google Cloud Billingの予算アラート**は導線だけ知っておくと安心です🧯

* Google Cloud console → **Billing → Budgets & alerts** ([Google Cloud Documentation][5])

※この章では設定しなくてOK！「入口の場所」だけで十分です🙆‍♂️

---

## 🤖AI（Gemini）を“Console迷子防止ナビ”にする💬🧭

FirebaseはUIが更新されがちなので、迷ったら**AIに「今の画面基準」で道案内させる**のが強いです💪✨
（Firebase公式もAI支援の流れを強めてます） ([Firebase][6])

そのための質問テンプレ（コピペOK）👇

```text
Firebase Consoleで「WebアプリのfirebaseConfig」を取りたいです。
今いる画面は（Project Overview / Project settings / それ以外）で、見えてるメニューは（ここに列挙）です。
最短クリック手順を5ステップで教えて。見つからない場合の代替ルートも。
```

```text
Firebase Consoleで「Usage & billing」を開いて、
課金事故を防ぐために最初に見るべき場所を3つ教えて。
それぞれ“何が増えると危険か”も一言で。
```

AIがズレたら、こう返すと復帰しやすいです👇😄

```text
そのボタン名が見当たりません。近い名前の候補を3つ挙げて、見つけ方（どの位置にあるか）も教えて。
```

---

## ミニ課題：「迷子ハント」3本勝負🎯🗺️

制限時間は合計10分くらいでOK⌛✨

1. **Project Overviewに戻る**🏠
2. **Project settingsへ行く（⚙️）**⚙️
3. **General → Your apps → Webアプリ → Config** まで行って、
   firebaseConfig を見つける📋 ([Firebase][2])

最後に、見つけた情報をこの形でメモ📝（※値は貼らなくてOK）👇

```text
プロジェクト名：
プロジェクトID：
Webアプリ名：
firebaseConfigの場所：Project settings > General > Your apps > (Web app) > Config
Usage & billingの場所：（自分の言葉で）
```

---

## よくある詰まりポイント😵‍💫➡️😄

* **「⚙️が見つからない」**
  → まずProject Overviewに戻る🏠（玄関）
  → その近くに⚙️があることが多いです ([Firebase][2])

* **「Your appsがない」**
  → そもそもWebアプリ未登録の可能性大
  → Project OverviewからWeb追加の導線へ ([Firebase][1])

* **「Usage & billingがどこ？」**
  → Console内にダッシュボードがある（名前が微妙に変わる時もある）ので、
  画面内検索 or AIに“いま見えてるメニュー名”を渡して聞くのが早いです ([Googleヘルプ][3])

---

## チェック：これが言えたら合格✅🎉

1. **Project Overview**は何のための場所？🏠
2. **Project settings**は何ができる場所？⚙️
3. **firebaseConfig**はどのルートで取れる？🏷️ ([Firebase][2])
4. **Usage & billing**は何を見る場所？💸 ([Googleヘルプ][3])
5. 困った時、AIに道案内させるなら何を伝える？（目的・現状・見えてるメニュー）🤖🧭

---

次の第4章（AIに聞く“型”）に入ると、ここで覚えた導線がさらに強化されて「詰まっても自力で復帰」しやすくなります💪✨

[1]: https://firebase.google.com/docs/web/setup?utm_source=chatgpt.com "Add Firebase to your JavaScript project"
[2]: https://firebase.google.com/codelabs/firebase-get-to-know-web?utm_source=chatgpt.com "Get to know Firebase for web - Google"
[3]: https://support.google.com/firebase/answer/9628313?hl=en&utm_source=chatgpt.com "Usage and billing dashboard - Firebase Help"
[4]: https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024?utm_source=chatgpt.com "FAQs about changes to Cloud Storage for Firebase pricing ..."
[5]: https://docs.cloud.google.com/billing/docs/how-to/budgets?utm_source=chatgpt.com "Create, edit, or delete budgets and budget alerts"
[6]: https://firebase.google.com/docs/ai?utm_source=chatgpt.com "AI | Firebase Documentation"
