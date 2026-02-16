# 第09章：ファイル構成の超基本：迷子にならない3点セット🧭📁

この章は「**どこを触れば画面が変わるの？**」を“体で覚える”回だよ〜😄✨
（ここが分かると、以降のFirebase導入やAI連携が一気にラクになる！🤖⚡）

---

## この章のゴール🎯

* ✅ **`src` / `public` / `package.json`** の役割が1分で言える
* ✅ `App.tsx` を触って **画面の文字を変えられる**
* ✅ コンポーネントを1つ分けて **`TopPage.tsx` に切り出せる**
* ✅ “AIやFirebaseのコードはどこに置くと綺麗か”の感覚がつく🧠✨

---

## 1) まずは「家の見取り図」🏠🗺️

Vite + React + TypeScript の最小構成は、だいたいこんな感じ👇
（ファイル名はテンプレで多少違っても、考え方は同じ！）

```txt
your-app/
  ├─ index.html        ← 入口（超大事！）
  ├─ package.json      ← コマンド・依存関係の台帳📒
  ├─ public/           ← そのまま配る素材置き場📦
  └─ src/              ← ふだん触るコード置き場🧠
      ├─ main.tsx      ← 起動スイッチ🔌（あまり触らない）
      ├─ App.tsx       ← 画面の親玉👑（よく触る）
      └─ ...
```

Viteは **`index.html` がプロジェクト直下にいる**のが特徴だよ（「入口を隠さない」設計）🕳️🚫
これが「迷子になりにくい」理由の1つ！ ([vitejs][1])

---

## 2) 3点セット① `package.json`：このアプリの“取扱説明書”📘⚙️

ここには主に2つあるよ👇

## A. コマンド（scripts）🏃‍♂️💨

よく使うのはこの3つ！

* `npm run dev`：開発サーバー起動（作業用）🧪
* `npm run build`：本番ビルド（配布用）📦
* `npm run preview`：ビルド結果をローカルで確認👀

（Viteの公式ガイドにも、この流れが基本として整理されてるよ） ([vitejs][2])

## B. 依存関係（dependencies / devDependencies）🧩

* ReactやVite、TypeScriptなどの“部品一覧”だよ🔧

---

## ⚠️ 2026年の注意：Node.jsのバージョン🧯

最近のViteは **Node.js 20.19+ / 22.12+ が必要**になってるよ（Node 18はEOLで切られた）🚫
「動かない…😢」の原因がここ、めっちゃ多い！ ([vitejs][3])

---

## 3) 3点セット② `src/`：あなたがほぼ毎日触る場所🧠🔥

## `src/main.tsx`：起動スイッチ🔌（基本は触らない）

ここは **ReactをDOMに接続する**ところ。
`createRoot(...)` で `<div id="root">` にアプリを差し込むイメージだよ🪄 ([react.dev][4])

## `src/App.tsx`：画面の親玉👑（めっちゃ触る）

ここが「最初に表示される大枠」になってることが多いよ！

---

## 4) 3点セット③ `public/`：そのまま配る素材置き場📦🖼️

ここに入れたファイルは **加工されずにそのまま配られる**よ。
だから用途はだいたいこんな感じ👇

* `favicon.ico`（タブのアイコン）🌐
* `robots.txt` 🤖
* “絶対この名前/パスで配りたい画像”🖼️（例：`/logo.png`）

Viteの「静的アセット」ルールは公式にまとまってるよ🧾 ([vitejs][5])

## ✨ ちょい重要：`public` と `src/assets` の感覚

* `public/`：そのまま配る（URLが固定で安心）📦
* `src/` 側に置いて import：ビルド時に最適化＆ファイル名にハッシュが付いてキャッシュに強い💪 ([vitejs][5])

初心者のうちは、画像はまず `public/` でOK！👍

---

## 5) 手を動かす：10分で「迷子脱出」🏃‍♂️💨✨

## Step 1：`App.tsx` をいじって画面を変える✍️

`src/App.tsx` を開いて、表示をこう変えてみて👇

```tsx
export default function App() {
  return (
    <main style={{ padding: 24 }}>
      <h1>動いた！第9章🎉</h1>
      <p>App.tsx を編集すると画面が変わる！</p>
    </main>
  );
}
```

保存した瞬間にブラウザが更新されたらOK（いわゆるHMR🔥）！

---

## Step 2：`TopPage.tsx` に切り出す🧩

「画面＝部屋」だと思うと分かりやすいよ🏠
まず `src/pages/TopPage.tsx` を作って👇

```tsx
export function TopPage() {
  return (
    <main style={{ padding: 24 }}>
      <h1>TopPageだよ〜🧭</h1>
      <p>コンポーネントを分ける練習！</p>
    </main>
  );
}
```

次に `App.tsx` をこうする👇

```tsx
import { TopPage } from "./pages/TopPage";

export default function App() {
  return <TopPage />;
}
```

✅ 画面が TopPage 表示になったら成功🎉

---

## Step 3：`public/` の画像を表示してみる🖼️✨

例えば `public/logo.png` を置いたとして、こう👇

```tsx
export function TopPage() {
  return (
    <main style={{ padding: 24 }}>
      <img src="/logo.png" alt="logo" width={120} />
      <h1>TopPageだよ〜🧭</h1>
    </main>
  );
}
```

`public` のものは `/ファイル名` で参照できる感覚が持てればOK！ ([vitejs][5])

---

## Step 4（任意）：AI/Firebaseコードの置き場所を“先に”作る🤖🔥

ここが第9章の「未来への投資」ポイント💰✨

`src/lib/ai.ts` を作って👇（今はダミーでOK）

```ts
// いまはダミー。後でFirebaseのAI LogicやGenkitにつなぐ予定🤖
export async function askAi(question: string): Promise<string> {
  await new Promise((r) => setTimeout(r, 300));
  return `（AIのダミー回答）質問: ${question}`;
}
```

`TopPage.tsx` で使ってみる👇

```tsx
import { useState } from "react";
import { askAi } from "../lib/ai";

export function TopPage() {
  const [answer, setAnswer] = useState<string>("");

  async function onAsk() {
    const res = await askAi("この画面の役割を小学生向けに説明して！");
    setAnswer(res);
  }

  return (
    <main style={{ padding: 24 }}>
      <h1>TopPageだよ〜🧭</h1>

      <button onClick={onAsk}>AIに聞く🤖</button>
      {answer && <pre style={{ whiteSpace: "pre-wrap" }}>{answer}</pre>}
    </main>
  );
}
```

✅ ボタン押して文字が出たらOK！
このあと本物のAIにつなぐ時も「置き場所が決まってる」から迷子にならない😄✨

---

## 6) ここで“AI×Firebase”をちょい予告🤖⚡（でも今は重くしない）

今どきFirebaseには「AIを組み込む導線」がちゃんと用意されてるよ👇

* **Firebase AI Logic**：クライアント（Web/モバイル）からAIを呼ぶ導線の1つ
  ※モデルの世代交代が明記されるタイプで、**2026/03/31に一部モデル退役**みたいな情報が出るので、教材でも“古いモデル名固定”は避けたい🧯 ([Firebase][6])
* **Genkit**：AIアプリを作るためのOSSフレームワーク（サーバー側/本格派） ([genkit.dev][7])

そして、開発体験として強いのが👇

* **Firebase MCP server**：Antigravity / Gemini CLI / Firebase Studio などからFirebase操作を“道案内”してくれる🧭🤖 ([Firebase][8])

第9章では「置き場所」を作っただけでOK！
本格接続は後の章で、順番に安全にやるよ〜😊

---

## 7) よくある詰まりポイント😵‍💫🧯

## ❌ 画面が変わらない

* 保存してない（意外と多い）💾
* ブラウザが別タブ（`localhost` のポート違い）🌐
* そもそも `App.tsx` じゃなく別ルートを描画してた（`main.tsx` をチラ見）👀

## ❌ `npm run dev` が動かない

* Nodeのバージョンが足りない（Vite 7は要件高め）⚠️ ([vitejs][3])

## ❌ 画像が出ない

* `public` に置いたのに `./logo.png` みたいに相対で書いてる
  → `public` は `/logo.png` で参照が基本📦 ([vitejs][5])

---

## 8) AIに聞く例（そのままコピペOK）🤖📝

迷子になったら、AIに“地図を描かせる”のが最強だよ🧭✨

* 「このプロジェクトの **エントリーポイント** はどれ？（`index.html` → `main.tsx` → `App.tsx` の流れを説明して）」
* 「`public` と `src/assets` の違いを、**画像の置き場**という観点で教えて」
* 「`TopPage.tsx` を追加した。次に `Header` と `Footer` を作るなら、フォルダ構成どうする？」
* 「後でFirebaseを入れる予定。`firebase.ts` や `ai.ts` はどこに置くと管理しやすい？」
* 「このリポジトリ構成を見て、初心者が迷うポイントを3つ挙げて、対策も書いて」

Firebase MCP server / Gemini CLI拡張が入ってる環境なら、Firebase側の作業もかなり案内が強くなるよ💪🤖 ([Firebase][8])

---

## 9) ミニ課題🎯：迷子にならない“部屋分け”を完成させる🏠✨

## やること（15分）

* ✅ `src/pages/TopPage.tsx` を作って `App.tsx` から表示
* ✅ `src/lib/ai.ts` の `askAi()` を呼んで、ボタンで表示
* ✅ `public/logo.png` を置いて表示（なければ適当な画像でOK）

## 合格ライン✅

* 「どこを直すと画面が変わるか」言える
* 「`public` は素材置き場、`src` はコード置き場」言える
* 「AIやFirebaseは `src/lib` に寄せると散らからない」って思えたら勝ち🏆

---

## 次の章につながる話📌

次の第10章では、この `TopPage` を「それっぽく整える」よ🎨✨
（Header/Main/Footer、ボタンの見た目、最低限のレイアウト！）

必要なら、第9章の完成形フォルダ構成（`components/` や `lib/` の最小テンプレ）も、あなたの好みに合わせて“固定の型”を作るよ〜😄📦

[1]: https://ja.vite.dev/guide/?utm_source=chatgpt.com "はじめに"
[2]: https://vite.dev/guide/?utm_source=chatgpt.com "Getting Started"
[3]: https://vite.dev/blog/announcing-vite7?utm_source=chatgpt.com "Vite 7.0 is out!"
[4]: https://react.dev/reference/react-dom/client/createRoot?utm_source=chatgpt.com "createRoot"
[5]: https://vite.dev/guide/assets?utm_source=chatgpt.com "Static Asset Handling"
[6]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[7]: https://genkit.dev/docs/overview/?utm_source=chatgpt.com "Open-source AI development framework by Google"
[8]: https://firebase.google.com/docs/ai-assistance/mcp-server?utm_source=chatgpt.com "Firebase MCP server | Develop with AI assistance - Google"
