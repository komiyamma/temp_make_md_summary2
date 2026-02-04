# 第30章：CDC入門＋CI＋運用まとめ（最終章）🎓✅✨

## この章でゴールにすること🎯✨

* CDC（Consumer-Driven Contract）の考え方を「言葉」じゃなく「流れ」で説明できる🙆‍♀️💡
* TypeScriptで、**最小のCDC（契約生成→検証）**を動かせる🧪✅
* CIで「契約が壊れたら止まる🚦」を作れる
* CHANGELOG / リリースノート / ADR まで含めて、**守り続ける運用**にできる📚🛠️✨

---

## 1) CDCってなに？🤝📜（ざっくり1分で）

CDCはひとことで言うと…

**「使う側（Consumer）が “こう動いてほしい！” を契約（Contract）として残して、提供側（Provider）がそれを守れてるか確認する」** って考え方だよ😊✨
この契約をCIで回すと、**“いつの間にか壊れてた😱”** をかなり減らせるのが強み！⚡

代表的な実装として Pact が有名で、HTTP/RESTだけじゃなくイベント駆動にも対応してるよ📣✨ ([GitHub][1])

---

## 2) 全体像（5行で）🗺️✨

1. Consumerが「期待するやりとり」をテストで書く🧪
2. その結果、**契約ファイル（pact）**が生成される📄
3. 契約ファイルを共有場所（Broker）に置く📦 ([Pact Docs][2])
4. Providerは契約を取りに行って「守れてるか」を検証する✅ ([Pact Docs][3])
5. CIで落とす（守れてないならマージ/デプロイ不可🚫）

---

## 3) まずは最小のCDCをTypeScriptで体験しよ〜！🧁🧪✨

### 今日のお題（小さくてかわいいAPI）🍬

`GET /todos/1` がこう返す、って約束にするよ👇

* `id`: number（必須）
* `title`: string（必須）
* `done`: boolean（必須）

---

## 4) ハンズオン構成📦✨（ミニモノレポ風）

フォルダはこんな感じにするよ👇

* `cdc-demo/`

  * `consumer/`（使う側🧑‍💻）
  * `provider/`（提供する側🧑‍🍳）

---

## 5) Provider（提供側）を用意する🍳🌐

`provider` は **Expressで最小API**を作るよ✨

### provider/package.json（イメージ）📦

```json
{
  "name": "provider",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "node src/server.js",
    "test:contract": "node src/verify-pact.js"
  },
  "dependencies": {
    "express": "^4.19.2"
  },
  "devDependencies": {
    "@pact-foundation/pact": "^13.0.0"
  }
}
```

### provider/src/server.js 🌐

```js
import express from "express";

export function createApp() {
  const app = express();

  app.get("/todos/1", (_req, res) => {
    res.json({ id: 1, title: "buy milk", done: false });
  });

  return app;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const app = createApp();
  const port = process.env.PORT ?? 3001;
  app.listen(port, () => console.log(`provider listening on ${port}`));
}
```

---

## 6) Consumer（利用側）で「期待」をテストにする🧑‍💻🧪✨

Consumerは **モックProvider**に対してテストを書くよ！
このテストが通ると **pactファイル**が出力される📄✨

### consumer/package.json（イメージ）📦

```json
{
  "name": "consumer",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node src/consumer.pact.test.js"
  },
  "devDependencies": {
    "@pact-foundation/pact": "^13.0.0"
  }
}
```

### consumer/src/consumer.pact.test.js 🧪

```js
import path from "node:path";
import { PactV3, MatchersV3 } from "@pact-foundation/pact";

const { like, integer, boolean } = MatchersV3;

const provider = new PactV3({
  consumer: "todo-web",
  provider: "todo-api",
  dir: path.resolve(process.cwd(), "pacts")
});

async function fetchTodo1(baseUrl) {
  const res = await fetch(`${baseUrl}/todos/1`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

(async () => {
  await provider
    .given("todo 1 exists")
    .uponReceiving("a request for todo 1")
    .withRequest({
      method: "GET",
      path: "/todos/1"
    })
    .willRespondWith({
      status: 200,
      headers: { "Content-Type": "application/json; charset=utf-8" },
      body: {
        id: integer(1),
        title: like("buy milk"),
        done: boolean(false)
      }
    });

  await provider.executeTest(async (mockServer) => {
    const todo = await fetchTodo1(mockServer.url);
    if (typeof todo.id !== "number") throw new Error("id must be number");
    if (typeof todo.title !== "string") throw new Error("title must be string");
    if (typeof todo.done !== "boolean") throw new Error("done must be boolean");
  });

  console.log("✅ pact generated!");
})();
```

> ✅ ここでやってること：
>
> * Consumerが「この形で返ってきてね💖」を定義
> * その定義が **契約（pact）**として保存される

---

## 7) Providerが「契約を守れてるか」検証する✅🧪✨

Provider側は **pactファイルを入力**にして検証するよ。
Pactの流れは「契約を取り込んで、Providerを叩いて、期待どおりかチェック」って感じ！ ([GitHub][4])

### provider/src/verify-pact.js ✅

```js
import path from "node:path";
import { Verifier } from "@pact-foundation/pact";
import { createApp } from "./server.js";

const port = 3001;
const pactPath = path.resolve(process.cwd(), "..", "consumer", "pacts");

const app = createApp();
const server = app.listen(port, async () => {
  try {
    const verifier = new Verifier({
      providerBaseUrl: `http://localhost:${port}`,
      pactUrls: [
        // consumer が出した pact ファイルを読む（最小構成）
        `${pactPath}/todo-web-todo-api.json`
      ]
    });

    const output = await verifier.verifyProvider();
    console.log(output);
    console.log("✅ provider verified the pact!");
  } catch (e) {
    console.error("❌ provider verification failed!");
    console.error(e);
    process.exitCode = 1;
  } finally {
    server.close();
  }
});
```

---

## 8) ここまでの実行手順（PowerShell想定）🪟✨

### 1) Consumerで契約生成📄

```powershell
cd cdc-demo\consumer
npm test
```

### 2) Providerで契約検証✅

```powershell
cd ..\provider
npm run test:contract
```

---

## 9) 「契約の共有」をちゃんとやる（Broker）📦🌍

チーム開発だと、pactファイルを手渡しはつらい😭
だから **契約を集める場所＝Broker** を使うのが王道！

* Pact Broker（自前運用のOSS） ([Pact Docs][5])
* PactFlow（マネージド版の選択肢） ([Pact Docs][5])

そして強いのが **Can I Deploy?** 🚦
「今デプロイして安全？」をBrokerの情報から判定できる思想だよ✨ ([Pact Docs][6])

---

## 10) CIに入れる（壊したら止める🚦）🧯✨

### CIで止めたいポイント（最小セット）✅

* Consumer：契約生成（pact作る）🧪📄
* Consumer：契約を共有（Brokerへ）📦 ([Pact Docs][2])
* Provider：契約を取得して検証✅ ([Pact Docs][3])
* （できたら）Can I Deploy?でデプロイ可否を判定🚦 ([Pact Docs][6])

---

### GitHub Actionsの例（超ミニ）🤖✨

GitHub の `actions/setup-node` は依存のキャッシュもサポートしてるよ📦⚡（node_modules自体じゃなく、依存取得を速くする感じ） ([GitHub][7])

#### consumer/.github/workflows/contract.yml（例）

```yaml
name: consumer-contract

on:
  push:
    paths:
      - "consumer/**"

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: "lts/*"
          cache: "npm"
          cache-dependency-path: "consumer/package-lock.json"

      - name: Install
        working-directory: consumer
        run: npm ci

      - name: Generate pact
        working-directory: consumer
        run: npm test

      # ここで pact を Broker に publish する（本番運用）
      # Pact Docs: "Sharing Pacts with the Pact Broker" の流れを参照✨
      # (publish 自体は pact-cli 等で行うのが一般的)
```

Broker共有の全体の流れは Pactの “Sharing Pacts” が分かりやすいよ📦✨ ([Pact Docs][2])

> ※ `publish` は `pact-cli`（Docker等）でやることが多いよ📦🐳（環境や運用方針で変えてOK） ([GitHub][8])

---

## 11) 運用まとめ（CHANGELOG / リリースノート / ADR）📰📚✨

CDCを回し始めると、次に効いてくるのが「伝え方」だよ🫶
守る仕組みは **テストだけじゃ完成しない** からね！

---

### 11-1) CHANGELOG（何が変わったかの公式ノート）📝✨

Keep a Changelogは **CHANGELOGの型**として有名だよ📚

* 「重要な変更を、時系列で、バージョンごとに」
* 読む人（利用者）が迷子になりにくい🧭✨ ([Keep a Changelog][9])

#### CHANGELOG.md（最小テンプレ）

```md
## Changelog

## [Unreleased]
### Added
- ...

### Changed
- ...

### Fixed
- ...

## [1.2.0] - 2026-02-04
### Added
- ...
```

---

### 11-2) バージョン運用（SemVer）🔢✨

SemVerは「バージョン番号に意味を持たせる」ルールだよ📌 ([Semantic Versioning][10])

* MAJOR：破壊的変更💥
* MINOR：後方互換のある機能追加➕
* PATCH：後方互換のある修正🩹

CDCと相性いい理由：
**“破壊的変更をしたら、契約が落ちる”** → “MAJORにしよう” が自然に決まる😊✨

---

### 11-3) コミット規約（Conventional Commits）🧾✨

Conventional Commitsは、コミットメッセージを機械が読める形にするルールだよ🧠
これがあると、自動CHANGELOG生成や自動リリースがやりやすい！ ([Conventional Commits][11])

例：

* `feat: add filtering to list`
* `fix: handle null title`
* `feat!: change response schema`（破壊的変更）

---

### 11-4) 自動で版上げ＆CHANGELOG（Changesets / semantic-release）🦋🚀

* Changesets：版上げとCHANGELOGを扱いやすくする仕組み（特に複数パッケージに強い） ([changesets-docs.vercel.app][12])
* semantic-release：コミット規約から次バージョン・CHANGELOG・リリースを自動化しやすい ([semantic-release.gitbook.io][13])

「まずは手動でいい」→「慣れたら自動化」って段階でOKだよ😊✨

---

### 11-5) ADR（意思決定のメモ）🧠📌✨

ADRは「なんでこの設計にしたっけ？」を未来の自分に残すメモ！
有名な型（Nygard ADR）だと👇が基本セットだよ✨ ([Architectural Decision Records][14])

* Title
* Status
* Context
* Decision
* Consequences

#### ADRの最小テンプレ（例）

```md
## ADR 0001: Use Pact for CDC

## Status
Accepted

## Context
- ...

## Decision
- ...

## Consequences
- ...
```

---

## 12) 最終キャップストーン（提出物セット📦🧾）🎓✨

ここまでの全部を、1セットにまとめよう！💖

### お題（どれか1つ選ぶ）🎮

A. 小さなHTTP API（例：Todo / Notes / Bookmark）🌐
B. 小さなnpmライブラリ（例：日付フォーマット / バリデータ）📦
C. 小さなイベント（例：`TodoCreated` みたいなメッセージ）📣

### 提出物（これが“運用できる契約”の完成形）✅✨

1. **契約（仕様）**：入力/出力（JSON）とルール📜
2. **互換ポリシー**：破壊変更の定義、非推奨期間、サポート期限⏳
3. **移行計画**：旧新併存のステップ（4段くらい）🪜
4. **互換性テスト**：CDC（pact）＋最低限のユニット🧪
5. **リリースノート**：今回何が変わった？どう移行する？📰
6. **ADR 1本**：「なぜその方式にした？」📌

### 採点（セルフチェック）💯✨

* [ ] Consumerの期待が「具体的」になってる？（曖昧ワード少なめ）
* [ ] Provider検証がCIで回る？（落ちると分かる）
* [ ] 破壊変更の扱い（MAJOR / 非推奨）が説明できる？
* [ ] CHANGELOGとリリースノートが、初見の人に優しい？🫶
* [ ] ADRに「迷いどころ」が書いてある？（未来で効く！）

---

## 13) “契約を守り続ける”ための最終チェックリスト🚦✨

### PR前（開発者の儀式🧙‍♀️）

* [ ] 変更は「公開API/JSON/イベント」に触れてる？
* [ ] 触れてるなら、互換性はOK？（追加はOK寄り、削除や型変更は危険寄り⚠️）
* [ ] CDCテスト（Consumer/Provider）どっちが落ちる？を想像できる？

### マージ前（CIの門番👮‍♀️）

* [ ] Consumerが契約生成できてる📄
* [ ] Providerが契約検証できてる✅ ([Pact Docs][3])
* [ ] （運用するなら）Can I Deploy? 相当のゲートがある🚦 ([Pact Docs][6])

### リリース時（伝える力💌）

* [ ] CHANGELOG更新（Keep a Changelog形式だと読みやすい） ([Keep a Changelog][9])
* [ ] バージョン番号が妥当（SemVer） ([Semantic Versioning][10])
* [ ] 破壊変更なら移行ガイドがある🧭

---

## 14) AI活用（レビュー係にして強くする🔍🤖✨）

コピペで使えるプロンプト例だよ💖（レビューが一気に楽になる！）

* 「この変更は契約（公開API/JSON）を壊してる？壊してるなら理由と代替案も」🧠
* 「CDCの観点で、Consumerが期待するべきレスポンス例を3パターン出して」🧪
* 「このCHANGELOG、利用者が移行できる書き方になってる？不足を指摘して」📰
* 「ADRとして残すべき意思決定ポイントを箇条書きにして」📌

---

## まとめ🎀✨

CDCは「契約を作る」だけじゃなくて、
**CIで止める🚦＋CHANGELOGで伝える📰＋ADRで残す📌** が揃ったときに完成するよ😊💖

この第30章のキャップストーンを1回やると、もう“契約を守る運用”が一生モノになるはず！🎓✨

[1]: https://github.com/pact-foundation?utm_source=chatgpt.com "Pact Foundation"
[2]: https://docs.pact.io/getting_started/sharing_pacts?utm_source=chatgpt.com "Sharing Pacts with the Pact Broker"
[3]: https://docs.pact.io/implementation_guides/javascript/docs/provider?utm_source=chatgpt.com "Provider Verification | Pact Docs"
[4]: https://github.com/pact-foundation/pact-js?utm_source=chatgpt.com "pact-foundation/pact-js"
[5]: https://docs.pact.io/pact_broker?utm_source=chatgpt.com "Introduction | Pact Docs"
[6]: https://docs.pact.io/pact_broker/can_i_deploy?utm_source=chatgpt.com "Can I Deploy"
[7]: https://github.com/actions/setup-node?utm_source=chatgpt.com "actions/setup-node"
[8]: https://github.com/pact-foundation/pact-ruby-cli/pkgs/container/pact-cli?utm_source=chatgpt.com "Package pact-cli"
[9]: https://keepachangelog.com/en/1.1.0/?utm_source=chatgpt.com "Keep a Changelog"
[10]: https://semver.org/?utm_source=chatgpt.com "Semantic Versioning 2.0.0 | Semantic Versioning"
[11]: https://www.conventionalcommits.org/en/v1.0.0/?utm_source=chatgpt.com "Conventional Commits"
[12]: https://changesets-docs.vercel.app/?utm_source=chatgpt.com "Changesets - Changesets"
[13]: https://semantic-release.gitbook.io/?utm_source=chatgpt.com "README | semantic-release"
[14]: https://adr.github.io/adr-templates/?utm_source=chatgpt.com "ADR Templates | Architectural Decision Records"
