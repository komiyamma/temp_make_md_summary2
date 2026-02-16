# 第10章：UIミニ設計：ログイン前トップの“最低限きれい”🎨✨

この章では、**「ログイン前トップ」**を “それっぽく整って見える” ところまで作ります🙂
あとでFirebase（認証・DB・AIなど）を足しても崩れにくいように、**骨組みと余白**を先に固めよう〜！🧱✨

---

## 1) まずは設計：ログイン前トップに必要な4点セット🧭

「最低限きれい」は、だいたいこの4つで決まります👇

* **Header**：アプリ名＋（あれば）メニュー🧢
* **Main（Hero）**：見出し＋説明＋CTAボタン（＝押したくなるやつ）🚀
* **補足ブロック**：特徴3〜4個、または「次に何ができる？」👀
* **Footer**：コピーライト＋リンク（About/Privacyなど）🧾

✅ これだけで “アプリっぽさ” が出ます。
❌ いきなり盛りすぎると、すぐ崩れて迷子になります（初心者あるある）😇

---

## 2) “最低限きれい”のコツ3つ（これだけ守れば勝ち）🏆✨

* **幅を制限する**：横に伸びすぎると読みにくい → `max-w-*` を使う📏
* **余白を揃える**：`px` / `py` を一定にして “整列感” を出す🧼
* **文字サイズの段差**：見出し＞本文＞補足 の順に小さくする🔠

---

## 3) 実装：Tailwind v4で“秒でそれっぽく”する⚡（おすすめ）

Tailwind v4 は **Viteプラグイン（@tailwindcss/vite）** が公式で用意されていて、Vite + React と相性よしです👍 ([Tailwind CSS][1])
（v4はCSS側で `@import "tailwindcss";` に変わっているのもポイント！）([Tailwind CSS][2])

### 3-1) Tailwind v4 を入れる📦

```bash
npm i -D tailwindcss @tailwindcss/vite
```

`vite.config.ts` をこうします👇

```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
});
```

この「Viteプラグインで入れる」流れが v4 の公式ルートです。([Tailwind CSS][1])

### 3-2) `src/index.css` に Tailwind を読み込む🎛️

```css
@import "tailwindcss";

/* 任意：気持ちよくするミニ設定 */
:root {
  color-scheme: light;
}
```

`src/main.tsx` で `./index.css` を import しているかも確認してね👀（Viteテンプレだと最初から入ってることが多い）

---

## 4) 実装：Header / Hero / Footer を作る🏗️✨

### 4-1) `src/components/Header.tsx`

```tsx
type HeaderProps = {
  appName?: string;
};

export function Header({ appName = "MyApp" }: HeaderProps) {
  return (
    <header className="border-b bg-white/80 backdrop-blur">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
        <div className="flex items-center gap-3">
          <div className="grid h-9 w-9 place-items-center rounded-xl bg-black text-white" aria-hidden="true">
            ⚡
          </div>
          <span className="text-base font-semibold">{appName}</span>
        </div>

        <nav className="hidden items-center gap-4 text-sm text-slate-600 sm:flex">
          <a className="hover:text-slate-900" href="#features">
            特徴
          </a>
          <a className="hover:text-slate-900" href="#about">
            このアプリについて
          </a>
        </nav>
      </div>
    </header>
  );
}
```

### 4-2) `src/components/Hero.tsx`

```tsx
type HeroProps = {
  onStart: () => void;
};

export function Hero({ onStart }: HeroProps) {
  return (
    <section className="mx-auto max-w-5xl px-4 py-10 sm:px-6 lg:px-8">
      <div className="grid items-center gap-8 lg:grid-cols-2">
        <div>
          <p className="inline-flex items-center gap-2 rounded-full bg-slate-100 px-3 py-1 text-xs font-medium text-slate-700">
            🚀 まずは最小で「動いた！」を作る
          </p>

          <h1 className="mt-4 text-3xl font-bold leading-tight tracking-tight text-slate-900 sm:text-4xl">
            迷わず、最短で
            <br />
            はじめるためのミニアプリ 🌱
          </h1>

          <p className="mt-4 text-slate-600">
            これは「ログイン前トップ」です🙂
            ここが整ってると、後で認証やFirebase接続を足しても崩れにくいよ✨
          </p>

          <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center">
            <button
              type="button"
              onClick={onStart}
              className="inline-flex items-center justify-center rounded-xl bg-slate-900 px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:opacity-90 focus:outline-none focus:ring-2 focus:ring-slate-400"
            >
              はじめる 👉
            </button>

            <a className="text-sm font-medium text-slate-700 hover:text-slate-900" href="#features">
              どんなことができる？ 👀
            </a>
          </div>

          <p className="mt-3 text-xs text-slate-500">
            ※このボタンは今はダミー（次章以降でログインや画面遷移につなげるよ🔗）
          </p>
        </div>

        <div className="rounded-2xl border bg-white p-6 shadow-sm">
          <h2 className="text-sm font-semibold text-slate-900">次にやること 🧭</h2>
          <ul className="mt-4 space-y-3 text-sm text-slate-700">
            <li className="flex gap-2">
              <span aria-hidden="true">✅</span>
              <span>UIの骨組み（Header / Main / Footer）を固める</span>
            </li>
            <li className="flex gap-2">
              <span aria-hidden="true">✅</span>
              <span>CTA（はじめる）で「押せた感」を作る</span>
            </li>
            <li className="flex gap-2">
              <span aria-hidden="true">🤖</span>
              <span>後でFirebase AI Logicで文章を自動生成できる形にしておく</span>
            </li>
          </ul>

          <div id="features" className="mt-6 grid gap-3 sm:grid-cols-2">
            <FeatureCard title="シンプル" emoji="🧩" text="要素を絞って迷子を防ぐ" />
            <FeatureCard title="読みやすい" emoji="👀" text="余白と文字サイズで整える" />
            <FeatureCard title="拡張しやすい" emoji="🔧" text="後で機能を足しても壊れにくい" />
            <FeatureCard title="AI対応" emoji="✨" text="文章や提案をAIで更新しやすい" />
          </div>
        </div>
      </div>
    </section>
  );
}

function FeatureCard(props: { title: string; text: string; emoji: string }) {
  return (
    <div className="rounded-xl bg-slate-50 p-4">
      <div className="text-sm font-semibold text-slate-900">
        {props.emoji} {props.title}
      </div>
      <div className="mt-1 text-xs text-slate-600">{props.text}</div>
    </div>
  );
}
```

### 4-3) `src/components/Footer.tsx`

```tsx
export function Footer() {
  return (
    <footer className="border-t bg-white">
      <div className="mx-auto flex max-w-5xl flex-col gap-2 px-4 py-6 text-xs text-slate-500 sm:flex-row sm:items-center sm:justify-between sm:px-6 lg:px-8">
        <p>© {new Date().getFullYear()} MyApp</p>
        <div className="flex gap-4">
          <a className="hover:text-slate-700" href="#about">
            About
          </a>
          <a className="hover:text-slate-700" href="#privacy">
            Privacy
          </a>
        </div>
      </div>
    </footer>
  );
}
```

### 4-4) `src/App.tsx`（ボタンが“押せる”を作る👆）

```tsx
import { useState } from "react";
import { Header } from "./components/Header";
import { Hero } from "./components/Hero";
import { Footer } from "./components/Footer";

export default function App() {
  const [toast, setToast] = useState<string | null>(null);

  return (
    <div className="min-h-dvh bg-slate-50 text-slate-900">
      <Header appName="Firebase Starter" />

      <main>
        <Hero
          onStart={() => {
            setToast("押せた！次はログインや画面遷移につなげよう 😄");
            window.setTimeout(() => setToast(null), 2500);
          }}
        />

        <section id="about" className="mx-auto max-w-5xl px-4 pb-12 sm:px-6 lg:px-8">
          <div className="rounded-2xl border bg-white p-6 shadow-sm">
            <h2 className="text-base font-semibold">このアプリについて 📌</h2>
            <p className="mt-2 text-sm text-slate-600">
              ここは“ログイン前”の入口ページ。後でFirebase認証やAI機能を足していくよ🤖✨
            </p>

            <div className="mt-4 rounded-xl bg-slate-50 p-4">
              <p className="text-sm font-medium text-slate-900">🤖 AIの入れどころ（予告）</p>
              <p className="mt-1 text-sm text-slate-600">
                例えば「アプリ説明文」や「おすすめ機能の文」を、Firebase AI Logicで自動生成して
                更新できるようにする予定だよ🪄
              </p>
            </div>
          </div>
        </section>
      </main>

      <Footer />

      {toast && (
        <div className="fixed bottom-4 left-1/2 w-[calc(100%-2rem)] max-w-md -translate-x-1/2 rounded-xl bg-slate-900 px-4 py-3 text-sm text-white shadow-lg">
          {toast}
        </div>
      )}
    </div>
  );
}
```

---

## 5) 🤖AIと一緒に“文章と見た目”を整える（Gemini CLI / Antigravity）✨

### 5-1) Gemini CLIで「コピー案」を量産する💬

Gemini CLI は npm で入れて、`gemini` コマンドで使えます。([Gemini CLI][3])

```bash
npm install -g @google/gemini-cli
gemini --version
```

次に、こんな感じでUI文言を作らせるのが強い💪✨（例）

```bash
gemini "ログイン前トップの見出し/説明/CTAボタン文言を日本語で5案。初心者に優しく、明るいトーン。アプリはFirebaseで作る学習用。"
```

さらに “画面崩れチェック” もAIに投げられます👇

```bash
gemini "このHeroコンポーネント、スマホ幅(360px)で見たときに崩れそうな点を3つ挙げて、Tailwindクラス修正案を出して。"
```

（Gemini CLI の使い方・例は公式ドキュメントにもまとまってるよ）([Gemini CLI][4])

### 5-2) Antigravityの“Mission Control”で進行管理🕹️🛸

Antigravityは**エージェント中心の開発環境**として「計画→実装→調査」を回すコンセプトが明示されています。([Google Codelabs][5])
なので第10章のおすすめはこれ👇

* エージェントに「トップ画面に必要な要素」を箇条書きさせる🧠
* あなたは **Header/Hero/Footer** を作る（骨組み担当）🏗️
* エージェントに「文言」「余白の改善」「スマホ対応」を詰めさせる🎨📱

---

## 6) FirebaseのAI機能はどう絡むの？（この章の“伏線”）🧵🤖

Firebaseには **Firebase AI Logic（Gemini APIをFirebase経由で扱う）** があり、アプリにAI体験（チャット・文章生成・パーソナライズ等）を入れられます。([Firebase][6])
また、よりサーバー寄りで組むなら **Genkit**（FirebaseのOSSフレームワーク）で、複数モデルを扱う高度な構成もできます。([Firebase][6])

💡 ここで作ったログイン前トップは、将来こう進化できる👇

* 「説明文」をAIで自動生成して、季節や用途で切り替え🌸🎓
* 「おすすめ機能」カードをAIが提案して並べ替え🔁✨
* 「はじめる」押下後に、AIが最初の案内役になる🧭🤖

📌 なお、モデルは入れ替わるので注意！
Firebase AI Logicの参照ドキュメントには **Gemini 2.0 Flash / Flash-Lite が 2026-03-31 にretire予定** と明記があり、更新が必要になります。([Firebase][7])
→ こういうのを踏むと「動いてたのに止まった😇」が起きるので、AI系は特に“現行モデル”を選ぶ癖をここから付けよう👍

---

## 7) よくある詰まりポイント（秒速で直す）🧯

* **Viteが起動しない（Nodeバージョン不足）**
  Vite 7 は **Node 20.19+ / 22.12+** が要件です。([vitejs][8])
  → Windowsだと古いNodeが残ってることがあるので、`node -v` を見て更新しよう🔁

* **Tailwindのクラスが効かない**
  だいたい原因はこれ👇

  * `vite.config.ts` に `tailwindcss()` 入れ忘れ
  * `src/index.css` の `@import "tailwindcss";` 書き忘れ（v4のポイント）([Tailwind CSS][2])
  * `main.tsx` で `index.css` を import してない

---

## 8) ミニ課題 🎯（10分）

✅ どれか1つでOK！

* **課題A**：FeatureCardを1枚増やして、文言を自分のアプリ用に書き換える📝✨
* **課題B**：「はじめる」ボタンの右に「デモを見る」リンク（別ボタンでもOK）を追加👀
* **課題C**：スマホ幅で見たとき、Hero右側のカードが詰まって見えないように余白調整📱🧼

---

## 9) チェック ✅（できたら合格！）

* Header / Main / Footer の3ブロックが揃ってる？🏗️
* “はじめる” を押すと反応（Toastなど）が出る？👆
* 画面幅が広くても読みやすい（`max-w-*` が効いてる）？📏
* 「次にFirebaseを足せる場所」が想像できる？🧠✨

---

## 🔜 次章へのつながり（チラ見せ）👀

このUIができたら、次はいよいよ **Firebaseプロジェクト作成**へ🔥
ここで作ったトップが、あとで **Auth / Firestore / AI Logic** の入口になります🚪🤖

[1]: https://tailwindcss.com/docs?utm_source=chatgpt.com "Installing Tailwind CSS with Vite"
[2]: https://tailwindcss.com/docs/functions-and-directives?utm_source=chatgpt.com "Functions and directives - Core concepts"
[3]: https://geminicli.com/docs/get-started/installation/?utm_source=chatgpt.com "Gemini CLI installation, execution, and releases"
[4]: https://geminicli.com/docs/get-started/examples/?utm_source=chatgpt.com "Gemini CLI examples"
[5]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[6]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[7]: https://firebase.google.com/docs/ai-logic/ref-docs?utm_source=chatgpt.com "Reference documentation for the Firebase AI Logic SDKs"
[8]: https://vite.dev/blog/announcing-vite7?utm_source=chatgpt.com "Vite 7.0 is out!"
