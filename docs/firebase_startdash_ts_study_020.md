# 第20章：仕上げミニ課題：ログイン前トップ画面を完成させる🎨🏁

今日は「**作品っぽい**」ところまで持っていく回だよ〜！😄✨
“動く”だけじゃなくて、**見た目・説明・導線（CTA）**が揃うと一気に完成度が上がる👍

---

## この章のゴール（合格ライン）✅✅✅

次の3つが揃ったらクリア！

1. **見た目OK**：ヘッダー / ヒーロー / CTA / フッター が揃っている🎨
2. **起動OK**：`npm run dev` で毎回表示できる🚀
3. **Firebase初期化OK**：画面上に「Firebase: OK」表示が出せる🌱

---

## 0) 3分ウォームアップ（バージョン確認だけ）🔎

Vite 7系は **Nodeの下限が上がってる**ので、ここだけ先に確認しよう⚡
最低ライン：**Node 20.19+ / 22.12+** あたりが安心（Vite 7の基準）。([vitejs][1])

```bash
node -v
npm -v
```

---

## 1) 今日作るトップ画面の“型”🧱✨

最低限、これが入ってれば強い！

* **Header**：アプリ名 + 右上にボタン（例：はじめる）🧭
* **Hero**：でかい見出し + 1行説明 + CTAボタン🔥
* **Features**：3つくらいでOK（短文で）📌
* **Footer**：コピーライト / リンク（ダミーOK）🔗
* **Firebase状態**：小さく “OK/NG” 表示🌱

---

## 2) 実装ステップ（手を動かす）🛠️💨

## Step A：ファイルを3つに分けて“迷子防止”🧭📁

`src` の中をこう分ける（超おすすめ）

* `src/pages/TopPage.tsx`
* `src/components/TopLayout.tsx`
* `src/lib/firebase.ts`

---

## Step B：Firebase 初期化を「失敗しても画面が死なない」形にする🌱🧯

Viteの環境変数は **`VITE_` 接頭辞のものだけが `import.meta.env` で読める**（漏洩防止のため）だよ。([vitejs][2])
Firebase公式のWebセットアップも “npmで入れて `initializeApp`” の流れ。([Firebase][3])

### 1) `.env.local` をプロジェクト直下に作る📝

（値は Console で取ったものを入れる）

```env
VITE_FIREBASE_API_KEY=xxxxxxxx
VITE_FIREBASE_AUTH_DOMAIN=xxxx.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=xxxx
VITE_FIREBASE_APP_ID=1:xxxx:web:xxxx
```

> ここを変えたら、開発サーバーは再起動するのが確実😺

### 2) `src/lib/firebase.ts` を作る🧩

「設定が足りない」も「初期化失敗」も、**文字列で返す**形にしておくと強い💪

```ts
// src/lib/firebase.ts
import type { FirebaseApp } from "firebase/app";
import { getApps, initializeApp } from "firebase/app";

type FirebaseInitResult =
  | { ok: true; app: FirebaseApp }
  | { ok: false; error: string };

function getEnv(name: string): string | undefined {
  const v = (import.meta.env as Record<string, string | undefined>)[name];
  return v && v.trim().length > 0 ? v : undefined;
}

export function initFirebase(): FirebaseInitResult {
  const apiKey = getEnv("VITE_FIREBASE_API_KEY");
  const authDomain = getEnv("VITE_FIREBASE_AUTH_DOMAIN");
  const projectId = getEnv("VITE_FIREBASE_PROJECT_ID");
  const appId = getEnv("VITE_FIREBASE_APP_ID");

  const missing = [
    !apiKey && "VITE_FIREBASE_API_KEY",
    !authDomain && "VITE_FIREBASE_AUTH_DOMAIN",
    !projectId && "VITE_FIREBASE_PROJECT_ID",
    !appId && "VITE_FIREBASE_APP_ID",
  ].filter(Boolean) as string[];

  if (missing.length) {
    return { ok: false, error: `env不足: ${missing.join(", ")}` };
  }

  try {
    const app =
      getApps().length > 0
        ? getApps()[0]
        : initializeApp({ apiKey, authDomain, projectId, appId });

    return { ok: true, app };
  } catch (e) {
    return { ok: false, error: `初期化失敗: ${String(e)}` };
  }
}
```

---

## Step C：トップ画面（ページ）を作る⚛️🎨

`TopPage.tsx` で、Firebase状態を **小さく表示**しよう🌱

```tsx
// src/pages/TopPage.tsx
import { useMemo } from "react";
import { initFirebase } from "../lib/firebase";
import { TopLayout } from "../components/TopLayout";

export function TopPage() {
  const fb = useMemo(() => initFirebase(), []);

  const firebaseBadge = fb.ok
    ? "Firebase: OK ✅"
    : `Firebase: NG ⚠️（${fb.error}）`;

  return (
    <TopLayout firebaseBadge={firebaseBadge} />
  );
}
```

---

## Step D：UIを“それっぽく”組み立てる（レイアウト部品）🏗️✨

Tailwind未導入でもいけるように、まずはシンプルCSS前提でいくね（後でTailwindに置き換えやすい構造にしてあるよ😉）

```tsx
// src/components/TopLayout.tsx
type Props = {
  firebaseBadge: string;
};

export function TopLayout({ firebaseBadge }: Props) {
  return (
    <div style={{ fontFamily: "system-ui", lineHeight: 1.5 }}>
      {/* Header */}
      <header
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          padding: "16px 20px",
          borderBottom: "1px solid #e5e7eb",
        }}
      >
        <div style={{ fontWeight: 800 }}>My Firebase App 🚀</div>
        <button
          style={{
            padding: "10px 14px",
            borderRadius: 12,
            border: "1px solid #e5e7eb",
            background: "white",
            cursor: "pointer",
            fontWeight: 700,
          }}
          onClick={() => alert("次の章でログイン導線に進めるよ！🔐")}
        >
          はじめる 👉
        </button>
      </header>

      {/* Main */}
      <main style={{ padding: "28px 20px", maxWidth: 960, margin: "0 auto" }}>
        <div style={{ marginBottom: 12, fontSize: 13, opacity: 0.8 }}>
          {firebaseBadge}
        </div>

        {/* Hero */}
        <section
          style={{
            padding: 20,
            borderRadius: 16,
            border: "1px solid #e5e7eb",
          }}
        >
          <h1 style={{ fontSize: 32, margin: "0 0 8px", fontWeight: 900 }}>
            “最小で動いた！”を、ここから積み上げる😄🌱
          </h1>
          <p style={{ margin: "0 0 16px", opacity: 0.85 }}>
            まずはログイン前のトップを完成させて、次は認証（メール＋Google）へ！🔐✨
          </p>

          <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
            <button
              style={{
                padding: "12px 16px",
                borderRadius: 14,
                border: "none",
                background: "#111827",
                color: "white",
                cursor: "pointer",
                fontWeight: 800,
              }}
              onClick={() => alert("OK！次はログイン画面に繋げよう😺")}
            >
              今すぐはじめる 🚀
            </button>

            <button
              style={{
                padding: "12px 16px",
                borderRadius: 14,
                border: "1px solid #e5e7eb",
                background: "white",
                cursor: "pointer",
                fontWeight: 800,
              }}
              onClick={() =>
                navigator.clipboard.writeText(
                  [
                    "あなたはUIコピーのプロです。",
                    "このアプリのログイン前トップ画面のコピーを、",
                    "初心者向けに3案ください。",
                    "条件：短い / 明るい / Firebase学習が怖くならない / 絵文字少なめでOK",
                  ].join("\n")
                )
              }
            >
              AIに聞く用プロンプトをコピー 🤖📋
            </button>
          </div>
        </section>

        {/* Features */}
        <section style={{ marginTop: 18 }}>
          <h2 style={{ fontSize: 18, marginBottom: 10 }}>できること（予定）📌</h2>
          <div style={{ display: "grid", gap: 12 }}>
            <Feature title="ログイン（メール＋Google）" body="認証がアプリの背骨になる！🔐" />
            <Feature title="データ保存（Firestore）" body="ユーザーごとに安全に持つ🗃️" />
            <Feature title="AI（Firebase AI Logic）" body="将来：キャッチコピー生成や要約も🤖✨" />
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer
        style={{
          padding: "16px 20px",
          borderTop: "1px solid #e5e7eb",
          opacity: 0.8,
          fontSize: 13,
        }}
      >
        © {new Date().getFullYear()} My Firebase App ✨
      </footer>
    </div>
  );
}

function Feature({ title, body }: { title: string; body: string }) {
  return (
    <div
      style={{
        padding: 14,
        borderRadius: 14,
        border: "1px solid #e5e7eb",
      }}
    >
      <div style={{ fontWeight: 900, marginBottom: 6 }}>{title}</div>
      <div style={{ opacity: 0.85 }}>{body}</div>
    </div>
  );
}
```

### 仕上げ：`App.tsx` から `TopPage` を呼ぶ📌

```tsx
// src/App.tsx
import { TopPage } from "./pages/TopPage";

export default function App() {
  return <TopPage />;
}
```

---

## Step E：動作チェック（開発＆本番ビルド）🚀🏁

```bash
npm run dev
npm run build
```

* `dev` で表示できる ✅
* `build` が通る ✅（本番に出す最低条件）

---

## 3) ミニ課題（提出物）📸📝

提出はこれだけ！

1. **トップ画面のスクショ1枚**（HeroとFirebaseバッジが見える状態）📸
2. **3行メモ**（コピペでOK）📝

   * できたこと✅
   * 詰まったこと⚠️
   * 次にやりたいこと🚀

---

## 4) よくある詰まり（ここで9割救える）🧯😺

## ❌ Firebase: NG（env不足）

* `.env.local` が **プロジェクト直下**じゃない
* `VITE_` が付いてない（例：`FIREBASE_API_KEY` になってる）
* `.env.local` 変えたのに **devサーバー再起動してない**

Viteのルール上、`VITE_` 以外は `import.meta.env` に出ないよ。([vitejs][2])

## ❌ 画面は出るけど build が落ちる

* どこかで `import` パスが崩れてる（`../` 1個ズレ）
* TypeScript の型ミス（いったんエラー行だけ直す）

## ❌ 見た目が微妙…

* 迷ったら「余白」「太字」「見出しサイズ」だけ直せばOK！✨

  * padding増やす
  * タイトルを太く
  * 文章を短く

---

## 5) AIを“実務の相棒”にする使い方（今日の範囲）🤖🧠

## Gemini CLI / Agent に投げると強い質問テンプレ💬

（そのままコピペOK！）

* 「このトップ画面、初心者が怖くならないコピーに修正して。3案。CTAも短く」
* 「Firebase初期化がNG。`env不足` と出る。原因候補とチェック順を箇条書きで」
* 「この `TopLayout.tsx` を Tailwind 版に置き換えるなら、最小でどうやる？」

Gemini CLI は Cloud Shell などで追加セットアップ無しで使える案内があるよ。([Google Cloud Documentation][4])
（Antigravityも “エージェント中心の作業場” って位置づけで、Mission Control 的に使えるよ🕹️🛸）([Google Codelabs][5])

---

## 6) FirebaseのAI機能はどう絡める？（次の布石）🤖🔥

このスタートダッシュでは **接続までやらなくてOK**！でも「どう使うかの形」は先に知っておくと一気に迷わない。

* **Firebase AI Logic** は Web（JavaScript）含めてクライアントSDKが用意されてて、Gemini系モデルに繋げられる。([Firebase][6])
* もともと “Vertex AI in Firebase” だったのが “Firebase AI Logic” に進化した、という流れも公式で説明されてるよ。([The Firebase Blog][7])

そしてAIを安全にやる王道は2択👇

* **クライアント直結**（まず試すのに速い⚡）
* **サーバー側（Genkit / Functions / Cloud Run）**（本番で堅い🧱）([Firebase][8])

---

## 7) 章末チェック（5問）✅

1. `VITE_` が付いてない環境変数は、`import.meta.env` で読める？（Yes/No）([vitejs][2])
2. 画面に Firebase の状態を出すメリットを1つ言える？🌱
3. `npm run build` を通す意味を一言で言える？🏁
4. UIの最低4ブロック（Header/Hero/Features/Footer）を説明できる？🧱
5. AIに投げる質問テンプレを1つ作れた？🤖

---

## おまけ：本日時点の“最新版メモ”🆕（2026-02-16）

* React：**19.2.4** が最新リリースとして出ているよ⚛️([GitHub][9])
* Vite：**7.3.1** が最新として案内されているよ⚡([npm][10])
* Functions（後で触る時）：Nodeは **20/22** がサポート中心、18はdeprecated扱い👀([Firebase][11])
* Python Functions（後で触る時）：**3.10〜3.13** サポート、**3.13がデフォルト**の案内🐍([Firebase][12])

---

必要なら、今の `TopLayout.tsx` を「Tailwind版」に置き換えた“見た目つよつよ”テンプレもすぐ出すよ😄🎨

[1]: https://vite.dev/blog/announcing-vite7?utm_source=chatgpt.com "Vite 7.0 is out!"
[2]: https://vite.dev/guide/env-and-mode?utm_source=chatgpt.com "Env Variables and Modes"
[3]: https://firebase.google.com/docs/web/setup?utm_source=chatgpt.com "Add Firebase to your JavaScript project"
[4]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[5]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[6]: https://firebase.google.com/products/firebase-ai-logic?utm_source=chatgpt.com "Firebase AI Logic client SDKs | Build generative AI features ..."
[7]: https://firebase.blog/posts/2025/05/building-ai-apps/?utm_source=chatgpt.com "Building AI-powered apps with Firebase AI Logic"
[8]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[9]: https://github.com/facebook/react/releases?utm_source=chatgpt.com "Releases · facebook/react"
[10]: https://www.npmjs.com/package/vite?utm_source=chatgpt.com "vite"
[11]: https://firebase.google.com/docs/functions/manage-functions?utm_source=chatgpt.com "Manage functions | Cloud Functions for Firebase - Google"
[12]: https://firebase.google.com/docs/functions/get-started?utm_source=chatgpt.com "Get started: write, test, and deploy your first functions - Firebase"
