# 第20章：総合ミニ課題（ToDo/メモ完成）＋AIで“実用っぽさ”を足す🎯🤖✨

この章はゴールがシンプルです👇
**「CRUD＋リアルタイム＋クエリ＋ページング」が一通り動く ToDo/メモアプリを“完成品”にする**＆**AIで便利さを一段上げる**🤖💨

---

## 1) この章で“完成”にする機能一覧 ✅

## 必須（ここまでの総復習）🧠✨

* 追加 / 編集 / 削除 ✅
* 一覧はリアルタイム更新 ⚡（勝手に増えるやつ）
* 未完了だけ表示（フィルタ）🔎
* ページング（もっと読む or 無限スクロール）📜♾️
* `createdAt` / `updatedAt` を入れてソート＆更新管理 ⏱️

## AIで“実用っぽさ”を足す（今回の主役）🤖🌟

* ✨ **AI整形**：メモ本文を「読みやすく整える」
* 🏷️ **AIタグ抽出**：本文からタグ（配列）を作って `tags: string[]` に保存
* 🧾（おまけ）**AIタイトル提案**：本文から短いタイトルを提案して `title` に反映

このAI部分は **Firebase AI Logic** を使って、アプリから **Gemini** を安全に呼ぶ流れにします。([Firebase][1])
※モデルは **`gemini-2.5-flash-lite`** など新しめ推奨。古い `gemini-2.0-flash` 系は **2026-03-31 でリタイア予定**が明記されています（地味に重要⚠️）。([Firebase][2])

---

## 2) データ設計（迷子防止）🧭🗃️

コレクション：`todos`
ドキュメント（例）：

```ts
export type Todo = {
  title: string;          // 表示用タイトル
  body?: string;          // メモ本文（任意）
  done: boolean;          // 完了フラグ
  tags: string[];         // AI抽出タグ（空配列OK）
  createdAt: any;         // Timestamp（Firestore）
  updatedAt: any;         // Timestamp（Firestore）
};
```

（`createdAt/updatedAt` を Timestamp にするのがソート＆ページングの基本になります⏱️）

---

## 3) “完成品っぽくする”実装ステップ（順番が大事）🧩

## Step A：一覧（リアルタイム）＋フィルタ（未完了だけ）🔎⚡

* 一覧は基本 `onSnapshot()` で購読
* フィルタは `where("done", "==", false)` を切り替えるだけ🎛️
* ソートは `orderBy("createdAt", "desc")` で新しい順⬆️

ポイント👀

* **フィルタを変えたら購読を張り替える**（unsubscribe 忘れがち🧯）

---

## Step B：ページング（“リアルタイム＋追加読み”の現実解）📜✨

Firestoreのページングは「カーソル」方式です（`startAfter(lastDoc)`）📌([Firebase][3])

**おすすめ構成（初心者に優しい＆破綻しにくい）**👇

* **先頭のN件だけリアルタイム**（最新が勝手に反映⚡）
* **“もっと読む”で古い分を追加取得**（ここは `getDocs` でOK）

これで「リアルタイム全部＋無限スクロール全部」を無理に混ぜて爆発💥しにくいです。

ざっくり実装イメージ（要点だけ）：

```ts
const PAGE_SIZE = 10;

// ① 先頭ページ（リアルタイム）
const headQuery = query(
  collection(db, "todos"),
  where("done", "==", false),          // フィルタON時だけ
  orderBy("createdAt", "desc"),
  limit(PAGE_SIZE)
);

// ② 追加ページ（もっと読む）
const nextQuery = query(
  collection(db, "todos"),
  where("done", "==", false),
  orderBy("createdAt", "desc"),
  startAfter(lastDoc),
  limit(PAGE_SIZE)
);
```

（カーソル式ページングの基本はこの形です。）([Firebase][3])

---

## Step C：AI Logic を組み込む（今回の目玉🤖🔥）

ここは **Firebase JS SDK v12.9.0** で入っている `firebase/ai` を使うのがポイントです。([Google for Developers][4])

## 1) まずは AI の初期化（1ファイルにまとめる）🧰

例：`src/lib/ai.ts`

```ts
import { app } from "./firebaseApp"; // 既に作ってある初期化を想定
import { getAI, getGenerativeModel, GoogleAIBackend } from "firebase/ai";

export const ai = getAI(app, { backend: new GoogleAIBackend() });

// ★モデル名はあとで差し替えやすいように定数に
export const GEMINI_MODEL = "gemini-2.5-flash-lite";

export const model = getGenerativeModel(ai, {
  model: GEMINI_MODEL,
});
```

（`getAI` / `GoogleAIBackend` / `getGenerativeModel` の形は公式Getting Startedに沿っています。）([Firebase][1])

---

## 2) AI整形：本文を読みやすくする ✨📝

例：`src/lib/aiEnhance.ts`

```ts
import { model } from "./ai";

export async function aiPolishBody(body: string): Promise<string> {
  const prompt =
    "次のメモを、意味は変えずに読みやすい日本語に整えてください。"
    + "出力は整形後の本文だけ（余計な前置き/箇条書き/解説なし）。\n\n"
    + body;

  const result = await model.generateContent(prompt);
  return result.response.text().trim();
}
```

（まずは“テキストを返すだけ”でOK。ここで複雑にしないのがコツ😺）

UIはこういう感じが作りやすいです👇

* テキストエリアの下に **「AI整形」ボタン**
* 押したらスピナー表示→整形後の本文で置き換え→「保存」へ✅

---

## 3) AIタグ抽出：JSONで返させて `tags: string[]` にする 🏷️🧾

ここは事故が起きやすいので、**“構造化出力（JSON）”**の考え方でガードします。([Firebase][5])

初心者向けに「まずは堅いプロンプト」でやる版👇

```ts
import { model } from "./ai";

export async function aiExtractTags(body: string): Promise<string[]> {
  const prompt =
    "次のメモ本文から、タグを3〜8個抽出してください。\n"
    + "条件：\n"
    + "- 出力はJSONのみ\n"
    + "- 形式は {\"tags\": [\"...\", \"...\"]}\n"
    + "- タグは短い名詞、重複なし、日本語\n\n"
    + body;

  const result = await model.generateContent(prompt);
  const text = result.response.text().trim();

  // ゆるくパース（失敗したら空配列にする）
  try {
    const obj = JSON.parse(text);
    const tags = Array.isArray(obj.tags) ? obj.tags : [];
    return tags
      .filter((x) => typeof x === "string")
      .map((x) => x.trim())
      .filter((x) => x.length > 0)
      .slice(0, 8);
  } catch {
    return [];
  }
}
```

ポイントはこれ👇

* **JSON以外を許さない**（雑談で返されると壊れるので🧯）
* **失敗してもアプリが落ちない**（空配列で逃がす😺）

---

## Step D：AI結果をFirestoreに保存する（安全に）✅🗃️

保存時は「AIで整形→タグ抽出→まとめて保存」みたいに一気にやると気持ちいいです✨

例（流れだけ）：

```ts
const polished = await aiPolishBody(body);
const tags = await aiExtractTags(polished);

await updateDoc(doc(db, "todos", id), {
  body: polished,
  tags,
  updatedAt: serverTimestamp(),
});
```

---

## 4) “公開しても恥ずかしくない”ひと工夫（軽め）🧯✨

## ✅ AI呼び出しの濫用対策（重要）

AIは便利だけど、呼ばれ放題だとコストも事故も増えます💸😇
**Firebase AI Logicの本番チェック項目**としても、保護や運用面がまとまっています。([Firebase][6])

おすすめガード👇

* AIボタンは **連打不可**（処理中はdisabled）
* 1回の整形で最大文字数を制限（例：2000文字まで）✂️
* **App Check** を有効化して、勝手な呼び出しを減らす🛡️（できたらやる）([Firebase][7])
* モデル名はコード直書きじゃなく **後から差し替え可能**に（Remote Configなど）🔧([Firebase][8])

---

## 5) 発展（任意）：サーバー側で自動化したい人へ ☁️🧠

「保存した瞬間に、サーバー側で自動タグ付けしたい！」みたいな発展もあります🔥

* **Cloud Functions for Firebase（Node）**：Node.js **20/22** がサポートとして案内されています。([Stack Overflow][9])
* **Cloud Functions for Firebase（Python）**：Python **3.12** で動かす流れが出てきます（CLIのリリースノートにも言及あり）。([Firebase][10])
* **C#でやりたい**：Firebase Functions本体というより、Google Cloudの **2nd genで .NET 8**（Cloud Run functions/Cloud Functions）側で組むのが現実的です。([Google Cloud Documentation][11])

サーバーから Firestore を触るなら Admin SDK が便利で、現時点の目安は👇

* Admin Node：**13.6.1** ([Firebase][12])
* Admin Python：**7.1.0** ([nuget.org][13])
* Admin .NET：**3.4.0（.NET 8+）** ([PyPI][14])

---

## 6) AIで“開発そのもの”を速くする（Antigravity / Gemini CLI）🚀🤖

実装が詰まったら、ここがめちゃ効きます。

## Antigravity（設計→実装の段取りを作る）🛰️

* 「この章の要件をToDoに分解して」
* 「今のファイル構成に合わせて差分パッチ案を出して」
  みたいな使い方がハマります（Mission Control的な進め方の例あり）。

## Gemini CLI（ターミナルで調査＆修正支援）⌨️✨

* 「このエラーの原因と直し方、最短で」
* 「このhooksのメモリリークの可能性ある？」
* 「この関数、型安全にリファクタして」
  みたいな“雑に聞いて、速く直す”がやりやすいです。([LinkedIn][15])

---

## 7) ミニ課題（提出物イメージ）🧩🎯

最低ラインはこれでOK👇

1. ToDo/メモが CRUD できる✅
2. 一覧がリアルタイムで増える⚡
3. 未完了フィルタが効く🔎
4. “もっと読む”で追加ロードできる📜
5. AI整形ボタンで本文が整う✨
6. AIタグ抽出ボタンで `tags` が入る🏷️

余裕があれば✨

* ローディング/空状態/エラー状態の表示が綺麗
* AI処理中はボタン無効＆進捗表示
* App Check / モデル差し替え（Remote Config）まで到達🛡️🔧

---

## 8) 最終チェックリスト（自己採点）✅✅✅

* [ ] `createdAt desc` で新しい順になってる？
* [ ] 別タブで追加しても一覧が即更新される？⚡
* [ ] フィルタ切替で購読が二重になってない？（メモリリークなし）🧯
* [ ] 追加ロードで重複表示しない？
* [ ] AIの返答が変でもアプリが落ちない？（JSONパース失敗→空配列など）
* [ ] 2.0系モデル名を固定してない？（3/31問題⚠️）([Firebase][2])

---

必要なら、この第20章の内容を **「完成版のファイル構成（src/ 配下）＋コピペで動く最小実装」**として、`useTodos()` / `TodoEditor` / `AIボタン周り` まで一気に“完成形コード”にして出します😺📦

[1]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
[2]: https://firebase.google.com/docs/ai-logic/models?utm_source=chatgpt.com "Learn about supported models | Firebase AI Logic - Google"
[3]: https://firebase.google.com/support/release-notes/js "Firebase JavaScript SDK Release Notes"
[4]: https://developers.google.com/ad-manager/mobile-ads-sdk/ios/rel-notes?utm_source=chatgpt.com "Release Notes | Mobile Ads SDK for iOS"
[5]: https://firebase.google.com/docs/ai-logic/generate-structured-output?utm_source=chatgpt.com "Generate structured output (like JSON and enums ... - Firebase"
[6]: https://firebase.google.com/docs/ai-logic/production-checklist?utm_source=chatgpt.com "Production checklist for using Firebase AI Logic - Google"
[7]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[8]: https://firebase.google.com/docs/ai-logic/model-parameters?utm_source=chatgpt.com "Use model configuration to control responses | Firebase AI Logic"
[9]: https://stackoverflow.com/questions/77880067/python-azure-function-not-working-with-higher-python-version-installed?utm_source=chatgpt.com "Python Azure Function not working with higher ..."
[10]: https://firebase.google.com/support/releases?utm_source=chatgpt.com "Release Notes | Firebase"
[11]: https://docs.cloud.google.com/functions/docs/release-notes?utm_source=chatgpt.com "Cloud Run functions (formerly known as Cloud Functions ..."
[12]: https://firebase.google.com/support/release-notes/admin/python?utm_source=chatgpt.com "Firebase Admin Python SDK Release Notes - Google"
[13]: https://www.nuget.org/packages/FirebaseAdmin?utm_source=chatgpt.com "FirebaseAdmin 3.4.0"
[14]: https://pypi.org/project/firebase-admin/?utm_source=chatgpt.com "firebase-admin"
[15]: https://www.linkedin.com/posts/iromin_google-antigravity-googleantigravity-activity-7396971021930516481-_Lm7?utm_source=chatgpt.com "\"Learn Google Antigravity with this tutorial and codelab\""
