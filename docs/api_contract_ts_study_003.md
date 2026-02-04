# 第3章：契約の種類を整理しよう🗂️🌈

## ねらい🎯✨

「契約（Contract）」って、実は **いろんな種類** がごちゃ混ぜになりがち😵‍💫
この章では、契約を **きれいに分類** して、変更に強い設計の土台を作ります💪💕

---

## 1) まず結論：契約は “3種類” に分けるとラク🧠🔖

契約はだいたいこの3つに分けると、頭がスッキリします✨

1. **コード契約（Code Contract）** 🧩
   → TypeScriptの型・関数の引数/戻り値・公開APIなど
2. **データ契約（Data Contract）** 🧾
   → JSON/DTO/設定ファイル/localStorage/イベントpayloadなど
3. **運用契約（Operational Contract）** ⏳📣
   → バージョン、非推奨、サポート期間、移行ガイド、配布方法など（「どう変えていいか」の約束）

この3つを分けると、
**「何を壊したのか」「どこを直せばいいのか」** が一気に見えるようになります👀✨

---

## 2) コード契約（Code Contract）🧩🟦

## 2-1. 何が契約になるの？🤝

TypeScriptで一番イメージしやすいのがこれ💡

* `export` してる **関数/クラス/型**（＝外部に約束してる入口）🚪
* 引数・戻り値の型（例：`(id: string) => Promise<User>`）🧷
* 例外/エラーの出し方（throwする？Result型？）⚠️
* 「同じ入力なら同じ出力」みたいな **振る舞いの約束** 🎭

> ✨ポイント：TypeScriptの型は強いけど **コンパイル時の約束が中心**。
> 実行時に壊れることは普通にあります（これは第19章で深掘り）🚧

## 2-2. ありがち事故💥（コード契約）

* 公開関数の名前変更（`getUser` → `fetchUser`）🚫
* 引数の型を狭める（`string | number` → `string`）😱
* 戻り値の形を変える（`User` → `{ user: User }`）📦
* 同じ入力でも挙動が変わる（意味変更）🌀

---

## 3) データ契約（Data Contract）🧾📦

## 3-1. 何が契約になるの？🤝

データ契約は「型がない世界」に出ていくほど重要になります🌍✨

* HTTP APIの **Request/Response JSON** 🌐
* DB・キャッシュ・localStorageの保存形式💾
* 設定ファイル（`config.json`）⚙️
* イベント（非同期）のpayload📣
* CSV/TSV/ログのフォーマット🧾

データ契約は、**仕様書があるとめちゃ強い**です🛡️
代表例：

* **OpenAPI**（HTTP API仕様）([Swagger][1])
* **JSON Schema**（JSONの形・制約）([JSON Schema][2])

## 3-2. データ契約は「形」だけじゃなく「意味」もある💡

例えば `price: 1000` でも…

* 単位は？（円？ドル？）💴💵
* 税込み？税抜き？🧾
* 小数OK？（`1000.5` はあり？）🔢

この “意味” を曖昧にすると、後で地獄になります😇🔥
なのでデータ契約は、できればこう書くのが勝ち✨

* **形（Shape）**：必須/任意、型、null可否
* **意味（Semantics）**：単位、範囲、解釈
* **既定値（Defaults）**：省略されたらどう扱う？

---

## 4) 運用契約（Operational Contract）⏳📣

## 4-1. 何が契約になるの？🤝

「作るコード」じゃなくて「届け方・変え方」の約束です📦✨

* バージョン番号（SemVerなど）🔢
* 変更の伝え方（CHANGELOG、リリースノート）📰
* 非推奨（Deprecated）の出し方🚧
* サポート期間（いつまで旧版を面倒見る？）🫶
* 配布の入口（npmのエントリポイント、exportsなど）🚪

SemVerは「バージョンの上げ方も契約」として定義してます📏✨([Semantic Versioning][3])
npm配布の `package.json` は運用契約の代表格です📦([npmドキュメント][4])
さらに `exports` は、現代Nodeの “入口の契約” として超重要です🚪🧠([Node.js][5])

---

## 5) 3種類が混ざると事故る😵‍💫💥（例で体感）

## 例：`getProfile()` を提供するライブラリ🧩📦

* **コード契約**：`export function getProfile(id: string): Promise<Profile>`
* **データ契約**：`Profile` のJSON形（APIや保存形式）
* **運用契約**：`v1.2.0` とかのバージョン付け、非推奨の出し方

ここでありがちな事故👇

* 型だけ変えて「契約守ったつもり」→ 実行時のJSONが違って落ちる😱
* JSONだけ変えて「動くでしょ」→ 古いクライアントが死ぬ🧟‍♀️
* 破壊変更したのに「PATCH上げちゃう」→ 利用者が炎上🔥

---

## 6) 契約マップ（Contract Map）を作ろう🗺️✨（この章のメイン演習）

## 6-1. 契約マップって何？🧠

「自分のアプリにある契約を、利用者（Consumer）ごとに一覧化した地図」です🗺️💕

## 6-2. 手順（超かんたん）🪄

1. **利用者（Consumer）を列挙**する👥

   * 例：フロント、別サービス、社内ツール、自分の未来の自分…🥹
2. **“触ってる入口” を書く**🚪

   * 例：`export` 関数、HTTP API、JSON、イベント
3. それが **どの契約タイプか** を付ける🟦🧾⏳
4. **壊れやすさ** と **守り方（テスト/検証）** をメモ📝

## 6-3. テンプレ（そのままコピペOK）📋✨

| Consumer（誰が使う？）👥 | 入口（何を触る？）🚪              | 種類（コード/データ/運用）🗂️ | 壊れたら何が起きる？😱 | 守り方（最低限）🛡️ |
| ----------------- | ------------------------ | ----------------- | ------------ | ----------- |
| 例：フロント            | `/api/users/{id}`        | データ＋運用            | 画面が真っ白💥     | スキーマ＋互換テスト  |
| 例：社内バッチ           | `export function calc()` | コード               | バッチ失敗⛔       | 型チェック＋ユニット  |

---

## 7) TypeScript視点：型は “契約の入口” 🟦🚪（でも万能じゃない）

## 7-1. `satisfies` は「契約チェック」に超便利🧁✨

設定オブジェクトとか「形は守りたい、でも推論も欲しい」時に強いです💪
（最近も解説が更新されてて、学びやすくなってます）([TypeScript入門『サバイバルTypeScript』][6])

```ts
type AppConfig = {
  apiBaseUrl: string;
  retryCount: number;
};

const config = {
  apiBaseUrl: "https://example.com",
  retryCount: 3,
  // extra: "ok"  // 余計なキーをどう扱うかは設計次第✨
} satisfies AppConfig;
```

* `:`（型注釈）より「推論が残る」ことが多くて扱いやすいです🧠✨
* ただし「実行時に正しいか」は別問題（ここがデータ契約の世界）🚧

---

## 8) ミニ演習📝✨（15〜30分）

## 演習A：自作アプリを “契約3分類” してみよう🗂️🌈

1. 自分のコードから「入口っぽいもの」を5つ探す🔍

   * `export`、HTTP、JSON、設定、イベント…
2. それぞれにラベルを貼る

   * 🧩コード / 🧾データ / ⏳運用
3. 「誰が困るか」を1行で書く👥

## 演習B：契約マップを1枚完成させよう🗺️💖

上の表テンプレに、まず **3行だけ** 埋めてOKです👌✨
（いきなり全部やろうとすると疲れるので、ミニスタートが正義🫶）

---

## 9) AI活用🤖💡（この章向けプロンプト集）

## 9-1. 契約一覧を作る🧾✨

* 「このリポジトリの “外部に約束してる入口” を列挙して。`export`/HTTP/JSON/設定/イベントで分類して🗂️」

## 9-2. 契約マップを埋める🗺️

* 「この機能のConsumerを想像して、契約マップの表を3行作って👥📋」

## 9-3. “壊れ方” を先に知る😱➡️🙂

* 「この変更は、コード契約・データ契約・運用契約のどれを壊しそう？利用者の被害を3パターンで🥺」

※ GitHub のCopilot系や、OpenAI 系の拡張は「レビュー係」として使うと超強いです🧠🔍✨

---

## 10) 章末チェック✅🌸（サクッと確認）

次のうち「運用契約」に入るものはどれ？（複数OK）🎯

1. `export function add(a:number,b:number):number` 🧩
2. APIレスポンスJSONの `userId` が必須 🧾
3. **破壊変更はMAJORを上げる** 🔢⏳
4. `config.json` の `retryCount` は省略時3 ⚙️🧾

答え💡：**3** がド真ん中（運用契約）✨
2と4はデータ契約、1はコード契約です🗂️🌈

---

## 11) 最新動向メモ📰✨（2026年視点）

* TypeScriptは大きめの節目に向かっていて、**6.0が“橋渡し”、その先にネイティブ実装の流れ**が語られています（開発進捗として公式ブログでも説明あり）([Microsoft for Developers][7])
* 現行の安定版系としては 5.9 系のリリースが確認できます([GitHub][8])
* Node.js もLTS/Currentが動くので、運用契約（サポート対象の決め方）を意識するとチームが助かります🫶（例：LTSの更新情報）([Node.js][9])

---

[1]: https://swagger.io/specification/?utm_source=chatgpt.com "OpenAPI Specification - Version 3.1.0"
[2]: https://json-schema.org/specification?utm_source=chatgpt.com "JSON Schema - Specification [#section]"
[3]: https://semver.org/?utm_source=chatgpt.com "Semantic Versioning 2.0.0 | Semantic Versioning"
[4]: https://docs.npmjs.com/files/package.json/?utm_source=chatgpt.com "package.json"
[5]: https://nodejs.org/api/packages.html?utm_source=chatgpt.com "Modules: Packages | Node.js v25.5.0 Documentation"
[6]: https://typescriptbook.jp/releasenotes/2026-01-23?utm_source=chatgpt.com "2026-01-23 satisfies演算子・this型の解説を全面改訂など"
[7]: https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/?utm_source=chatgpt.com "Progress on TypeScript 7 - December 2025"
[8]: https://github.com/microsoft/typescript/releases?utm_source=chatgpt.com "Releases · microsoft/TypeScript"
[9]: https://nodejs.org/en/blog/release/v22.22.0?utm_source=chatgpt.com "Node.js 22.22.0 (LTS)"
