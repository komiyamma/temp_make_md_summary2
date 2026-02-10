# 第01章：ゴール設定「速く回る開発ループ」って何？🎯🚀

この章は、いきなり設定地獄に入る前に「**開発って、結局なにが気持ちいい状態なの？**」をハッキリさせる回だよ😊✨
ここが曖昧だと、ホットリロードやLintを入れても「結局めんどい…😇」ってなりがち。

---

## 1) “速く回る開発ループ” を一言で言うと？🌀💨

**変更 → すぐ反映 → すぐ確認 → 自動チェックで安心 → 次の変更**
この1周を、できるだけ短く・迷わず回せる状態のこと！🧠✨

たとえば、理想の1周はこんな感じ👇

* ✍️ コードを1行変える
* 💾 保存する
* 🔥 自動で再実行（ホットリロード）
* ✅ 画面/ログで即確認
* 🧪 テスト & 🧹 Lint が自動で「変な壊し方してない？」を見張る
* 😌 安心して次へ進める

---

## 2) この教材で作る“完成形”のイメージ🧩🎁

この30章を通して最終的に目指すのは、ざっくりこう👇

* 🟢 **起動は1コマンド**（覚える呪文が1個だけ）
* 🔥 **保存したら勝手に反映**（ホットリロード / watch）
* 🧪 **テストはすぐ回る**（速く・必要な範囲で）
* 🧹 **Lint/整形で事故を減らす**（レビューが楽になる）
* 🤝 **手元とCIの差が小さい**（「自分のPCでは動いたのに…😭」を減らす）

しかも、2026の「今どき」の土台で組む想定だよ👇

* Nodeは **v24がActive LTS**、v25がCurrent（更新日も2026-02あたりまで追えてる）([Node.js][1])
* TypeScriptは **5.9系**のリリースノートが公式で更新されてる([TypeScript][2])
* WindowsのDockerは **WSL2エンジン**が基本線として公式が案内してる([Docker Documentation][3])
* Compose側にも **watch機能**が用意されていて「保存→自動反映」寄りにできる([Docker Documentation][4])

---

## 3) まずは“2つのゴール”だけ覚えよう🎯🎯

開発体験って、実はこの2本柱だけで説明できるよ😉✨

## ゴールA：とにかく速い⚡

* ⏱️ 起動が遅いと、やる気が死ぬ（マジで）💀
* 🔁 反映が遅いと、試行回数が減る → 成長が遅くなる🐢

## ゴールB：安心して触れる🛡️

* 😱 “怖くて触れないコード” が増えると詰む
* ✅ テスト/Lintがあると「触ってOK」が増えて前に進める

---

## 4) 今日のミッション：自分の“開発ループ”を見える化する👀📝

ここからが大事！
第1章の成果は「環境を完成させる」じゃなくて、**“何を速くしたいか”が言語化できる**こと👍✨

## ✅ ミッション1：今の1周は何秒？（ベースライン計測）⏱️

「今の自分は、変更→確認に何秒かかってる？」を測ろう！

## 例：ざっくり計測する項目

* 🚀 起動：`npm run dev`（or docker起動）が「動くまで何秒？」
* 🔥 反映：保存してから再実行/再表示まで何秒？
* 🧪 テスト：1回の実行が何秒？
* 🧹 Lint：何秒？（重いとやらなくなる😇）

「測る」だけで、改善が一気にやりやすくなるよ📈✨

---

## 5) 30秒デモ：ホットリロードの“気持ちよさ”だけ先に体験🔥😆

まだComposeもテストもLintも入れない！
まずは **“保存したら勝手に再実行される”** を一瞬で味わおう🍿✨

ここでは `tsx` の watch を使う（最速で体験できるやつ）
`tsx watch` は公式で watch モードを案内してるよ([tsx][5])

## 手順（PowerShell想定）🪟⚡

```powershell
mkdir dx-ch01
cd dx-ch01
npm init -y

npm i -D typescript tsx
mkdir src
```

`src/index.ts` を作って、これを書いてね👇

```ts
console.log("hello DX 👋");
setInterval(() => console.log("tick..."), 2000);
```

watch起動！

```powershell
npx tsx watch src/index.ts
```

✅ ここで `hello DX 👋` が出たらOK！
次に `src/index.ts` の文字をちょっと変えて保存してみて👇

* 例：`hello DX 👋` → `hello DX !!! 😆`

すると… **勝手に再実行**されるはず！🔥
これが「開発ループが速い」って感覚の第一歩だよ😆✨

> ※ `tsx` は“型チェックは別途”という考え方になるので（ここは後半でちゃんと整える）、今日は「体感」だけでOK👌
> 後で `tsc --noEmit` などの“安心セット”を足していくよ🧪🧠

---

## 6) “ワンコマンド化”って何をするの？🧰🪄

ここも第1章で方向性だけ決める！

理想はこう👇（名前はこの教材でも固定していく）

* `dev`：開発サーバ起動（ホットリロード込み🔥）
* `test`：テスト🧪
* `lint`：Lint🧹
* `format`：整形✍️
* `check`：↑ぜんぶまとめて実行✅（迷ったらコレ）

今はまだ中身スカスカでOK。
でも「入口の名前」を揃えるだけで、未来の自分が救われる😇✨

---

## 7) ミニ課題🎒✨（5〜10分）

## 課題A：ベースラインを書き残す📝

READMEにこれを書くだけ！

* 起動：___秒
* 反映：___秒
* テスト：___秒（まだなら“未導入”でOK）
* Lint：___秒（まだなら“未導入”でOK）

## 課題B：npm scripts の“入口だけ”作る🧩

`package.json` の `"scripts"` をこうしておく（中身は後で育てる🌱）

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "test": "echo \"(coming soon)\"",
    "lint": "echo \"(coming soon)\"",
    "format": "echo \"(coming soon)\"",
    "check": "npm run lint && npm run test"
  }
}
```

---

## 8) よくある詰まりポイント（第1章編）💣🧯

* 😵 `npx` が動かない / npm周りが変
  → まず `node -v` / `npm -v` を確認（バージョン事故は最初に潰すのが正解）
* 🐢 反映が遅い
  → 後の章で「どこにコードを置くと速いか（WSL2含む）」をちゃんと扱うよ（公式もWSL2連携を推してる）([Docker Documentation][3])
* 🔥 watchが効かない
  → 監視方式はOS/ファイル配置で差が出ることがある（ここは第3章以降で“地雷回避”を体系化する💪）

---

## 9) AI拡張での時短ポイント🤖✨（安全運転でいこう）

AIは「丸投げ」より、**“小さく頼む”** が強いよ😉

## 使えるお願いテンプレ（コピペOK）📋

* 「この `package.json` の scripts を、dev/test/lint/format/check の形で整えて。いったん中身は仮でOK」
* 「READMEに“開発ループの定義”を短く、初心者向けに書いて」
* 「この章の課題Aの“ベースライン記録欄”を読みやすく整形して」

## AIの出力を採用するときのチェック✅

* 👀 コマンドが“何をするか”自分で説明できる？
* 🧨 `rm -rf` とか変な破壊コマンド混ざってない？（念のため）
* 🔁 後で直せる“入口（scripts名）”が揃ってる？

---

## 次章予告チラ見せ👀✨

次の第2章は「開発用」と「本番用」を分けて考える回🧠
ここを押さえると、後の章（ホットリロード・テスト・Lint）が全部スムーズになるよ🚀

---

## おまけ：Docker Desktopは“更新大事”🛡️🧯

Docker Desktopには過去に **CVE-2025-9074** みたいな「コンテナからホストに影響しうる」系があり、**4.44.3で修正**された、と公式がアナウンスしてるよ。([Docker Documentation][6])
開発体験を良くするほど日常的に触るので、更新はサボらないのが吉🙏✨

---

次は、第1章の“成果物（READMEとscripts）”を、教材用にもっと「テンプレっぽく」整えた版も作れるよ😊📚
（章ごとに積み上がって、最終的に“DXテンプレ”として完成する感じ🎁✨）

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html?utm_source=chatgpt.com "Documentation - TypeScript 5.9"
[3]: https://docs.docker.com/desktop/features/wsl/?utm_source=chatgpt.com "Docker Desktop WSL 2 backend on Windows"
[4]: https://docs.docker.com/compose/how-tos/file-watch/?utm_source=chatgpt.com "Use Compose Watch"
[5]: https://tsx.is/watch-mode?utm_source=chatgpt.com "Watch mode"
[6]: https://docs.docker.com/security/security-announcements/?utm_source=chatgpt.com "Docker security announcements"
