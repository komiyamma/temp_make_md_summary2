# 第20章：データ進化①：安全な変更・危険な変更🧬⚖️

## この章のゴール🎯

データ（JSONなど）の形を変えるときに、

* ✅ **安全（だいたいOK）**
* ⚠️ **注意（条件つき）**
* ❌ **危険（破壊変更になりがち）**

をサクッと判定できるようになることです🫶✨

---

## 20-1. まずは「誰が読む？」で安全度が変わる👀🔁

データの変更って、じつは **“読む側（Consumer）” がどれだけ厳しいか**で事故りやすさが激変します💥

## 代表的な2タイプ🧩

* **ゆるめ受け取り（寛容）**：知らない項目が来ても無視して処理できる🙂
* **かため受け取り（厳格）**：知らない項目が来たらエラーにする😠

ここがポイント👇
JSON Schema では、`additionalProperties` が **デフォルトで true**（= 基本は「知らないプロパティ来てもOK」寄り）という考え方があります。([Confluent Documentation][1])
でも現実は、バリデータや実装次第で **厳格にもできちゃう**んだよね⚠️

たとえば Zod は、オブジェクトの**未定義キーをデフォルトで strip（落とす）**し、厳格にしたいなら `z.strictObject()`、ゆるくしたいなら `z.looseObject()` みたいに切り替えできます。([Zod][2])

---

## 20-2. いちばん大事：安全度の“ざっくりルール”🧠✨

## ✅ 安全寄り（だいたいOK）

* **任意フィールド（optional）を追加**
* **制約をゆるめる**（例：`minLength: 3` → `minLength: 1`）
* **新しい値を許可する方向に広げる**（例：enumに値を追加）※ただし注意点あり⚠️

## ❌ 危険寄り（破壊変更になりがち）

* **必須フィールド（required）を追加**
* **フィールド削除**（特にレスポンスやイベントpayload）
* **型変更**（string ↔ number など）
* **意味変更**（同じフィールド名のまま意味だけ変える）
* **制約をきつくする**（例：`minLength`を上げる、`pattern`を追加）

このへんは “だいたい破壊” になりやすいので、やるなら移行設計（第21章）で段階的にね🪜⏳

---

## 20-3. 安全/危険 早見表📋🧡（OK/注意/NG）

ここでは **「古いクライアントが新しいデータを受け取る」**ケース（後方互換の典型）を中心に見ます🔁
※「新しいクライアントが古いデータを読む」も同じように考えるよ！

| 変更パターン                            |              判定 | ひとこと理由                           |                       |
| --------------------------------- | --------------: | -------------------------------- | --------------------- |
| 任意フィールドを追加（例：`nickname?: string`） |               ✅ | 知らない項目を無視できれば壊れにくい🙂             |                       |
| 必須フィールドを追加（例：`nickname: string`）  |               ❌ | 旧クライアントが未対応で落ちやすい💥              |                       |
| フィールド削除                           |               ❌ | 旧クライアントが参照してたら即死😇               |                       |
| フィールド名変更（rename）                  |               ❌ | 削除＋追加と同じ。ほぼ破壊🧨                  |                       |
| 型変更（string→number）                |               ❌ | パース/表示/計算で事故る🧯                  |                       |
| enumに値を追加                         |              ⚠️ | `switch` が default なしだと落ちることある⚠️ |                       |
| enumから値を削除                        |               ❌ | 古いデータや古い送信側が送ると詰む😵‍💫           |                       |
| 制約をゆるめる                           |               ✅ | 受け取り側が困りにくい🙆‍♀️                 |                       |
| 制約をきつくする                          |            ⚠️/❌ | “今までOKだったデータ”が突然NGに😱            |                       |
| nullable化（`string`→`string        |          null`） | ⚠️                               | 取り扱い漏れが出やすい（UI表示とか）💦 |
| 非nullable化（`string                | null`→`string`） | ❌                                | 既存データにnullが残ってると崩壊💥  |

---

## 20-4. JSON Schemaの“必須/任意”の基本（超重要）📌✨

JSON Schemaは、`properties` に書いた項目は **デフォルトでは必須じゃない**です。必須にしたいものだけ `required` 配列で指定します。([JSON Schema][3])

そして `default` は「欠けてたら自動で埋める」動作ではなく、あくまで **ヒント**（ドキュメントやUI向け）です。([JSON Schema][4])
だから「追加したけど既定値あるから平気でしょ？」は油断しがち⚠️（埋める処理は自分で書く必要があるよ🧠）

---

## 20-5. Zodで体感！安全変更と危険変更を見てみよ🧪✨

## 例：Userデータ（v1）👤

```ts
import * as z from "zod";

export const UserV1 = z.object({
  id: z.string(),
  name: z.string(),
});

export type UserV1 = z.infer<typeof UserV1>;
```

---

## ✅ ケースA：任意フィールド追加（だいたい安全）➕🙂

```ts
export const UserV2 = UserV1.extend({
  nickname: z.string().optional(),
});
```

* 旧クライアントが `id` と `name` だけ使ってたら、たいてい壊れない✨
* ただし **「知らないキーが来たらエラー」**な受け手だと事故る😱

Zodは、unknown key の扱いを選べます👇([Zod][2])

```ts
// 厳格（知らないキーが来たらエラー）
const Strict = z.strictObject({
  id: z.string(),
  name: z.string(),
});

// ゆるい（知らないキーも残す）
const Loose = z.looseObject({
  id: z.string(),
  name: z.string(),
});
```

> 「将来フィールド増えるかも」なデータは、受け取り側を**厳格にしすぎない**のがコツだよ🧁✨

---

## ❌ ケースB：必須フィールド追加（危険）➕💥

```ts
export const UserV2Bad = UserV1.extend({
  nickname: z.string(), // required
});
```

これ、**新しい送信側**が `nickname` を必ず入れる前提だと、旧クライアントが「そんなの知らん！」ってなる可能性大😇
（バリデータや型、UIの想定で落ちます）

---

## ❌ ケースC：型変更（ほぼ破壊）🧨

```ts
export const UserV2VeryBad = z.object({
  id: z.string(),
  name: z.number(), // string → number に変更
});
```

* 表示、検索、ソート、保存…ぜんぶ影響しがち😵‍💫
* しかも “静かにバグる” 率が高い（最悪）😱

---

## ⚠️ ケースD：enumに値追加（注意）🎲

「追加は安全！」って言いたいけど、現場あるある👇

* クライアントが `switch` で **defaultなし**
* もしくは「この値しか来ない」前提のUI分岐

で落ちることあるよ⚠️（`default` / フォールバック大事🛟）

---

## 20-6. “完全互換”が難しい世界もある（知っておく話）😵‍💫🧠

JSON Schema の世界では、**open/closed content model**（`additionalProperties` をどうするか）によって「追加/削除の安全度」が変わります。([Confluent Documentation][1])
さらに、open/closed の両方を同時に満たして “完全互換” をやり切るのが難しいケースがある、という整理もあります。([Yandex Cloud][5])

なので現実的には👇

* **“どっちの互換を優先するか”**（後方？前方？）
* **受け手が strict か loose か**
* **互換テストを回す**（第28〜）

で勝つのが強いよ💪✨

---

## 20-7. 安全に育てるための定番テク集🧰🌷

## ① 追加するときは “optional + 意味が自然なデフォルト” 🧁

* optional にして、無いときも破綻しない設計にする
* ただし default は自動注入じゃないから、必要なら **補完処理**を書く([JSON Schema][4])

## ② “意味変更” はしない（新フィールドを作る）🚫🧠

* `status` の意味をコッソリ変える…は事故率MAX😇
* 新しい意味は `statusV2` とか、別名で追加して段階移行が安全🪜

## ③ rename は「旧→新の併存期間」を作る🪄

* 旧フィールドを残しつつ、新フィールドも追加
* 送信側は両方出す期間を作って、受信側が移行したら旧を消す（第21章へ）⏳

## ④ unknown key に対する方針を決める🎭

* “増えうるデータ” は、受け取り側で **strictにしすぎない**
* Zodなら `strict/loose` を明示してチームで統一しよう🧁([Zod][2])

---

## 20-8. ミニ演習✍️📊（OK/注意/NGに分類しよう！）

次の変更を **✅OK / ⚠️注意 / ❌NG** に分けてみてね😊✨

1. `user` に `avatarUrl?: string` を追加
2. `user` に `email: string`（必須）を追加
3. `user.name` を削除
4. `user.age: number` を `string` に変更
5. `user.role` の enum に `admin` を追加
6. `user.role` の enum から `guest` を削除
7. `user.nickname?: string` を `nickname: string`（必須）に変更
8. `user.bio` の `maxLength: 160` を `maxLength: 80` に変更
9. `user.bio` の `maxLength` を削除（制約ゆるめ）
10. `user.status` の意味を「有効/無効」から「課金/無料」に変更（名前は同じ）

## こたえ合わせ🎀

1. ✅　2) ❌　3) ❌　4) ❌　5) ⚠️　6) ❌　7) ❌　8) ⚠️/❌　9) ✅　10) ❌

---

## 20-9. AI活用プロンプト集🤖💗（コピペOK）

## 変更の安全度チェック🔍

* 「この JSON の変更（diff貼るね）が、後方互換/前方互換のどちらで危険？理由も3つで教えて」
* 「この変更を ✅/⚠️/❌ に分類して、事故る具体例も1つずつ作って」

## “安全な代替案”を出してもらう🧠🪄

* 「この破壊変更を、段階移行できる設計に直して（旧新併存→移行→削除の3段で）」
* 「rename を安全にやるためのフィールド設計と運用手順を提案して」

## テスト観点を作る🧪

* 「旧スキーマで新データをパースするテストケースを10個作って（境界値も）」
* 「Zodで互換性テストを書くなら、どんな `safeParse` テストが必要？」

---

## 20-10. 章末チェックリスト✅🧡

リリース前にこれだけ確認しよう✨

* [ ] 変更は **追加中心**になってる？（削除・型変更してない？）
* [ ] 必須追加してない？（やるなら段階移行）
* [ ] enum追加は **default/fallback** がある？
* [ ] バリデーションは **strict/loose 方針が統一**されてる？([Zod][2])
* [ ] defaultに頼りすぎてない？（自動注入じゃない）([JSON Schema][4])
* [ ] スキーマの互換性を “バージョン管理してチェック” できる仕組みがある？（Schema Registry等）([Confluent Documentation][6])

---

## 今日のミニまとめ🌸

**データ進化は「追加は比較的安全、削除/型変更/意味変更は危険」**が基本ルール💡
でも実戦では **受け手の strict/loose** と **互換テスト** が勝敗を分けるよ🧁✨

[1]: https://docs.confluent.io/platform/current/schema-registry/fundamentals/serdes-develop/serdes-json.html?utm_source=chatgpt.com "JSON Schema Serializer and Deserializer for ..."
[2]: https://zod.dev/api?utm_source=chatgpt.com "Defining schemas | Zod"
[3]: https://json-schema.org/understanding-json-schema/reference/object?utm_source=chatgpt.com "object"
[4]: https://json-schema.org/understanding-json-schema/reference/annotations?utm_source=chatgpt.com "Annotations"
[5]: https://yandex.cloud/en/docs/metadata-hub/concepts/schema-registry-content-model?utm_source=chatgpt.com "Content models and JSON schema evolution issues"
[6]: https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html?utm_source=chatgpt.com "Schema Evolution and Compatibility for Schema Registry ..."
