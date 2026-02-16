# 第08章：React+TypeScript最小アプリ作成（Vite）⚛️🌱

この章でやることはシンプル！
**「React + TypeScript の最小アプリを Vite で作って、ローカルで起動して、“動いた！”を体験する」**だけです🎉
（次章以降で Firebase を繋げるので、ここは **土台作り** 💪）

---

## 0) 先に“詰まりポイント”だけ知っておく🧯😇

* **Vite 7系は Node の要求が高い**ので、古い Node だと起動で止まります⚠️
  目安：**Node 20.19+ か 22.12+**（新しめの LTS を入れておけばOK）([vitejs][1])
* Node の “今の最新LTSの流れ” を見ると、**v24 が Active LTS** になっています（2026-02 時点）([nodejs.org][2])
* React は docs 上だと **最新が 19.2** になっています⚛️([react.dev][3])
* TypeScript は **安定版の最新が 5.9.3**（npm 表示）で、6.0 は beta の流れです🧠([npm][4])

---

## 1) Node が“足りてるか”だけ確認する🔍🧰

PowerShell を開いて👇

```powershell
node -v
npm -v
```

もし `v18` とか古いのが出たら、ここで一回アップデートした方が早いです🙏
（Vite 7 だと **Node 20.19+ / 22.12+** が必要）([vitejs][1])

**“どの node を見てるか”**分からないときは👇（複数入ってると罠🪤）

```powershell
where node
```

---

## 2) Vite で React+TS プロジェクトを作る⚡📦

いきます！コマンドはこれだけ👇（公式の作り方）([vitejs][5])

```powershell
npm create vite@latest myapp -- --template react-ts
cd myapp
npm install
npm run dev
```

成功すると、ブラウザでだいたい👇が開きます🌐
`http://localhost:5173/`（ポートは環境で変わることもあるよ）

---

## 3) “動いた！”を画面に出す🎉📸

`src/App.tsx` を開いて、いったんこれに置き換えちゃおう👇（最小の「動いた！」表示）

```tsx
export default function App() {
  return (
    <main style={{ padding: 24, fontFamily: "system-ui" }}>
      <h1>動いた！🎉</h1>
      <p>Vite + React + TypeScript の起動確認できたよ✅</p>
      <button onClick={() => alert("OK! ✅")}>押してみる</button>
    </main>
  );
}
```

保存した瞬間、ブラウザが勝手に更新されて表示が変わったら勝ち🏆✨
ここで **スクショ📸** とっておくと「進んでる感」が出ます！

---

## 4) “迷子にならない”超ミニ構造理解🧭📁

この章では、最低これだけ覚えればOK🙂

* `src/main.tsx`：React を起動して `App` を表示する入口🚪
* `src/App.tsx`：今あなたが触ってるメイン画面🖥️
* `index.html`：最終的にここにアプリが載る土台🏠

（深追いは次章で！今日は“動いた”が最優先💨）

---

## 5) 🤖 AIを“今この瞬間”から味方にする（Gemini CLI）💻✨

**目的：エラー解決と「次の一手」を爆速にする**🏃‍♂️💨

Gemini CLI は npm で入れられます👇([Gemini CLI][6])

```powershell
npm install -g @google/gemini-cli
gemini --help
```

（Google Cloud の docs だと「Cloud Shell では追加セットアップ不要」って扱いもあります）([Google Cloud Documentation][7])

### おすすめの使い方（コピペOK）📝🤖

* ① まず状況を短く伝える
* ② そのままログを貼る（秘密情報は除く）
* ③ “やりたいこと”を1行で言う

例👇

```text
Viteで react-ts を作って npm run dev したらエラーです。
WindowsのPowerShellです。
このログの原因と、最短の直し方を手順でください。

（ここにエラーログを貼る）
```

---

## 6) 🌟 Firebase AI を“後でラクする形”で仕込む（30秒）🧠🧩

まだ Firebase を繋いでないけど、**将来 Firebase AI Logic に差し替える前提の“置き場所”だけ作る**と気持ちいいです😄

`src/lib/ai.ts` を作って👇

```ts
// 今はダミー。後で Firebase AI Logic に差し替える用の窓口🚪
export async function askAi(prompt: string): Promise<string> {
  return `（ダミー回答） ${prompt}`;
}
```

`src/App.tsx` にちょい足し👇

```tsx
import { useState } from "react";
import { askAi } from "./lib/ai";

export default function App() {
  const [msg, setMsg] = useState("");

  return (
    <main style={{ padding: 24, fontFamily: "system-ui" }}>
      <h1>動いた！🎉</h1>

      <button
        onClick={async () => {
          const res = await askAi("次にFirebaseで何をすればいい？");
          setMsg(res);
        }}
      >
        AIに聞く🤖
      </button>

      {msg && <p style={{ marginTop: 12 }}>{msg}</p>}
    </main>
  );
}
```

これで「AIボタンがある最小アプリ」ができた！✨
次の章で Firebase を繋げたら、この `askAi()` の中身を **Firebase AI Logic に差し替える**だけで進めます🚀

ちなみに Firebase AI Logic の docs には **モデルの終了予定**も書かれていて、例えば **Gemini 2.0 Flash / Flash-Lite が 2026-03-31 でリタイア予定**などが明記されています🧯（古いモデルに寄らないの大事！）([Firebase][8])

---

## 7) Antigravity でやる場合🛸🕹️（超要点だけ）

やることは同じで、**ターミナルでコマンドを打ってプレビューを見るだけ**です✅
Antigravity は “エージェント前提の開発環境”として案内されています([Google Codelabs][9])

---

## ミニ課題🎯（10分）

1. 画面に **「動いた！🎉」** を表示✅
2. ボタンを押すと `alert("OK! ✅")` が出る✅
3. 「AIに聞く🤖」ボタンを押すと、ダミー回答が表示される✅
4. スクショ📸 1枚保存（あとで自分が助かる）

---

## よくある詰まり🐛🧯（ここだけ見ればOK）

* **`Vite requires Node.js 20.19+ or 22.12+`**
  → Node を新しめの LTS にする（まずここ）([vitejs][1])
* **`npm create` が変なエラー**
  → いったん `npm -v` を確認、社内プロキシ環境ならネットワーク系が原因のことも多い🌐
* **ブラウザが開かない**
  → ターミナルに出てる URL を自分で開く（`localhost:5173` など）🧭

---

## チェック問題✅（3つだけ）

* Q1. `npm run dev` は何をする？（一言で）
* Q2. 画面表示を変えるのは基本どのファイル？
* Q3. Node が古いと何が起きる？（Viteの要求）([vitejs][5])

---

次の章（ファイル構成の超基本）に行く前に、もし `npm run dev` で出たエラーがあれば、そのログをそのまま貼ってくれたら、**Gemini CLI に投げる用の最短プロンプト**もセットで整えるよ🤖🛠️

[1]: https://vite.dev/blog/announcing-vite7?utm_source=chatgpt.com "Vite 7.0 is out!"
[2]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[3]: https://react.dev/versions?utm_source=chatgpt.com "React Versions"
[4]: https://www.npmjs.com/package/typescript?activeTab=versions&utm_source=chatgpt.com "typescript"
[5]: https://vite.dev/guide/?utm_source=chatgpt.com "Getting Started"
[6]: https://geminicli.com/docs/get-started/installation/?utm_source=chatgpt.com "Gemini CLI installation, execution, and releases"
[7]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
[8]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[9]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
