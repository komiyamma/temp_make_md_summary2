# 第04章：ReactからFirestoreへ接続（最初の配線）🔌⚛️🗃️

この章は「**React → Firestore に“つながった！”を最速で体感する**」回だよ〜😆✨
ゴールはシンプルにこれ👇

* ✅ Firestore を初期化して `db` を作る
* ✅ `todos` を **一覧取得して表示（0件でもOK）**
* ✅ 初期化コードの置き場所がブレない（地味に超大事）🧠

> ちなみに今どきは **Firebase Web SDK は npm + モジュラーAPIが強く推奨**だよ〜（tree-shaking効く）🌲✨ ([Firebase][1])
> 2026-02-16時点で `firebase` の最新版は **12.9.0**（npm）だよ。([npm][2])

---

## 1) 全体像を10秒でつかむ 🧭⚡

やることはこの順番👇

1. Firebase コンソールで **Webアプリ登録** → `firebaseConfig` を入手 🧾([Firebase][1])
2. React側で `firebase` を入れる（npm）📦([Firebase][1])
3. `initializeApp(firebaseConfig)` で **Firebase App** を作る 🧩([Firebase][1])
4. `getFirestore(app)` で **db** を作る 🗃️
5. `getDocs(collection(db, "todos"))` で **0件表示**まで到達🎯

---

## 2) Firebaseコンソール側：Webアプリ登録で「設定値」を取る 🧾🌐

Firebase コンソールで Web アプリを登録すると、アプリ接続用の **Firebase configuration**（`firebaseConfig`）が出てくるよ。([Firebase][1])

* 途中で「**Gemini in Firebase（AI支援）を有効にする**」選択肢が出ることがある（開発体験がかなりラクになるやつ🤖✨）([Firebase][1])

---

## 3) React側：firebase を入れる 📦✨

まずは依存追加！

```powershell
npm install --save firebase@12.9.0
```

（`firebase@12.9.0` は公式の代替セットアップ手順にも出てるよ）([Firebase][3])

---

## 4) 設計のコツ：初期化は「1ファイルに固定」しよう 🧠🧱

ここ、初心者が一番ハマるポイント😇
Firebase初期化があちこちに散ると、将来 **「二重初期化」**とかで泣くことになる…💥

おすすめ配置👇

* `src/lib/firebase.ts` ＝ Firebase 初期化専用ファイル（ここに集約）✨
* 画面（components/pages）は `db` を import して使うだけ

---

## 5) `.env.local` に設定値を入れる 🔐🧾

（Vite構成だと `VITE_` から始めるのが定番だよ）

```ini
VITE_FIREBASE_API_KEY=xxxxx
VITE_FIREBASE_AUTH_DOMAIN=xxxxx
VITE_FIREBASE_PROJECT_ID=xxxxx
VITE_FIREBASE_APP_ID=xxxxx
VITE_FIREBASE_STORAGE_BUCKET=xxxxx
VITE_FIREBASE_MESSAGING_SENDER_ID=xxxxx
```

⚠️ **`.env.local` を作った/編集したら、開発サーバー再起動**がほぼ必須だよ（反映されなくて沼るやつ）🌀

---

## 6) `src/lib/firebase.ts` を作る（最初の配線）🔌⚛️

Firebase公式のセットアップは `initializeApp` で App を作る形になってるよ。([Firebase][1])
それに Firestore をぶら下げて `db` を作る！

```ts
// src/lib/firebase.ts
import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
};

export const firebaseApp = initializeApp(firebaseConfig);
export const db = getFirestore(firebaseApp);
```

---

## 7) 接続確認：`todos` を一覧取得して「0件表示」まで行く 🎯🗒️

## `TodoList.tsx`（一覧取得→表示）

```tsx
import { useEffect, useState } from "react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "./lib/firebase"; // パスは環境に合わせて調整してね

type Todo = {
  id: string;
  title?: string;
  done?: boolean;
};

export function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const snap = await getDocs(collection(db, "todos"));
        const items = snap.docs.map((d) => ({
          id: d.id,
          ...(d.data() as Omit<Todo, "id">),
        }));
        setTodos(items);
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  if (loading) return <p>読み込み中…⏳</p>;
  if (error) return <p>エラー😵‍💫：{error}</p>;

  return (
    <section>
      <h2>ToDo（{todos.length}件）🗒️</h2>

      {todos.length === 0 ? (
        <p>まだToDoがありません🌱（ここまで来たら接続OK！）</p>
      ) : (
        <ul>
          {todos.map((t) => (
            <li key={t.id}>
              {t.done ? "✅" : "⬜"} {t.title ?? "(no title)"}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
```

## `App.tsx` に置いて表示してみる

```tsx
import { TodoList } from "./TodoList";

export default function App() {
  return (
    <main style={{ padding: 16 }}>
      <h1>Firestore 接続テスト🔌⚛️</h1>
      <TodoList />
    </main>
  );
}
```

---

## 8) よくあるハマりポイント集（最短で抜ける）🧯💡

* **`Firebase: No Firebase App '[DEFAULT]' has been created`**
  → `initializeApp` が呼ばれてない / import先が違う / ファイルが実行されてない可能性大🥲

* **画面がずっと0件 or 変化しない**
  → `.env.local` 変更後に再起動してないパターン多め🌀

* **`Missing or insufficient permissions`**
  → Firestoreのルール（Rules）で弾かれてる！🛡️
  ルールはこの後の章でちゃんと鍛えるから、まずは「エラー文が出る＝接続できてる」って捉えてOK🙆‍♂️

---

## 9) 🧩ミニ課題：接続確認を“気持ちよく”仕上げる

やることは3つだけ👇（でも達成感すごい✨）

* ✅ 0件のとき：`まだToDoがありません🌱` を出す
* ✅ 件数：`ToDo（0件）` を出す
* ✅ エラー：`エラー😵‍💫：...` を出す（原因追跡の入口になる）

---

## 10) 🤖AIを絡める（この章の“今すぐ効く”使い方）

## 10-1) コンソールの「Gemini in Firebase」で迷子を防ぐ 🧠🧭

Firebaseのセットアップフロー中に AI 支援（Gemini in Firebase）を有効にできる導線があるよ。([Firebase][1])
これ、**設定・用語・Rulesの読み解き**でめちゃ助かるやつ🤖✨

---

## 10-2) Antigravity に投げる“指示文テンプレ”🛰️🧑‍💻

Antigravity は Mission Control 的に複数エージェントを動かして、計画→実装→検証まで回しやすい設計だよ。([Google Codelabs][4])
例えばこんな指示が強い👇

* 「`src/lib/firebase.ts` を作って、Viteの `import.meta.env` から config を読む」
* 「`TodoList` を作って `todos` を `getDocs` で取得し、0件/読み込み/エラー状態も表示」
* 「二重初期化が起きない構造にして」

（実際にファイル差分まで作ってくれる動きが得意✨）

---

## 10-3) Gemini CLI を“デバッグ係”にする 🧰🤖

Gemini CLI はターミナル上のAIエージェントで、ReAct ループ＋MCP 連携とかで **バグ修正や調査を回しやすい**よ。([Google Cloud Documentation][5])
なので例えば👇を投げると強い💪

* 「このエラー文を読んで原因候補を3つ、確認コマンドも添えて」
* 「Firestore接続の最小構成に直して（Vite+React+TS）」
* 「`.env.local` の読み込みを確認するチェック手順を作って」

---

## 10-4) Firebase AI Logic は“後で自然に合流”する（配線が似てる）🧩🤖

Firebase AI Logic は、アプリから Gemini / Imagen を使うための仕組みだよ。([Firebase][6])
この章でやった「Firebase App を初期化して、サービス（Firestore）を取り出す」流れは、AI Logic も同じノリで合流できるのが気持ちいい✨

⚠️ ひとつだけ大事：AI Logic のセットアップで作られる **Gemini API key をコードに直書きしない**って明確に書かれてるよ。([Firebase][7])
（この辺も次のAI章でガッツリ安全にやろう🛡️）

あと、AI Logic のモデルは更新・移行があるので、**古いモデルの提供終了日**みたいな情報もチェックしておくと事故りにくいよ（例：2026-03-31で退役するモデルがある旨が明記されてる）🧯([Firebase][6])

---

## ✅この章のチェック（言えたら勝ち）🏁✨

* ✅ `src/lib/firebase.ts` に初期化をまとめる理由が言える🧠
* ✅ `db` を import して `getDocs(collection(db,"todos"))` が書ける🗃️
* ✅ 0件/読み込み/エラーの3状態をUIで出せる🎛️

---

次の章（Create）に入ると、ここで作った `db` がそのまま **追加処理（addDoc / setDoc）**に直結するよ➕📄✨

[1]: https://firebase.google.com/docs/web/setup "Add Firebase to your JavaScript project  |  Firebase for web platforms"
[2]: https://www.npmjs.com/package/firebase?utm_source=chatgpt.com "firebase - npm JavaScript library"
[3]: https://firebase.google.com/docs/web/alt-setup "Alternative ways to add Firebase to your JavaScript project  |  Firebase for web platforms"
[4]: https://codelabs.developers.google.com/getting-started-google-antigravity "Getting Started with Google Antigravity  |  Google Codelabs"
[5]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli "Gemini CLI  |  Gemini for Google Cloud  |  Google Cloud Documentation"
[6]: https://firebase.google.com/docs/ai-logic "Gemini API using Firebase AI Logic  |  Firebase AI Logic"
[7]: https://firebase.google.com/docs/ai-logic/get-started "Get started with the Gemini API using the Firebase AI Logic SDKs  |  Firebase AI Logic"
