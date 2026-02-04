# 第6章：“互換性”の種類：後方互換・前方互換🔁🧠

## 6.1 今日のゴール🎯✨

* 「後方互換」「前方互換」を**言葉で説明できる**ようになる🗣️💡
* 変更が出たときに「これはどっちの互換？🤔」を**分類できる**ようになる📌
* 「クライアント先行／サーバ先行」の現場で**混乱しない考え方**を身につける🧯✨

---

## 6.2 まず結論：互換性は“方向”の話だよ🧭🔁

互換性って、「新旧が混ざってもちゃんと動く？」って話なんだけど、**どっちが新しくて、どっちが古いか**で意味が変わるよ〜！🙌

* **後方互換（backward compatibility）**：
  **新しいもの**が、**古い相手（または古いデータ）**とも一緒に動けること🧡
  例：新しいアプリが、昔の保存データを開ける📂✨
  （“新→古”に強い） ([ウィキペディア][1])

* **前方互換（forward compatibility）**：
  **古いもの**が、**新しい相手（または未来のデータ）**とも一緒に動けること🌈
  例：古いクライアントが、新しいレスポンス（知らない項目が増えた）でも壊れない🧱✨
  （“古→新”に強い） ([ウィキペディア][1])

---

## 6.3 いちばん大事：APIは“2方向”ある🚦➡️⬅️

HTTP APIや関数APIって、だいたいこう👇

* **リクエスト**：クライアント ➡️ サーバ（クライアントが“送る側”）📤
* **レスポンス**：サーバ ➡️ クライアント（クライアントが“受ける側”）📥

つまり…
**「何を変えたか」だけじゃなくて、どっち向きのデータか**が超重要！🧠✨

---

## 6.4 超わかる！2×2の“混在表”📊✨

「どっちが先にアップデートされる？」で事故りやすいので、まずこれを頭に置くよ🧷

| 組み合わせ              | 起きがちな現実       | 欲しい性質                                  |
| ------------------ | ------------- | -------------------------------------- |
| **新サーバ × 旧クライアント** | サーバだけ先に更新されがち | **旧クライアントが壊れない**（＝旧が新を読める＝前方互換っぽい動き）🌈 |
| **旧サーバ × 新クライアント** | アプリだけ先に更新されがち | **新クライアントが古いサーバでも動く**（＝後方互換）🧡         |

ここで混乱ポイント⚠️

* 教科書的には「後方互換／前方互換」は定義があるけど、
* 現場では「**誰を壊したくない？**」で考える方が速いよ🏃‍♀️💨

---

## 6.5 “壊れない”のコツは「読み方」を変えること📥🧠

将来の変更に強くする鉄板がこれ👇

### ✅ 受け取る側は“必要なものだけ読む”🎧✨

* 追加されたフィールドは **無視してOK**（知らないものはスルー🙈）
* 取るべきものが無い／形式が違うときは **丁寧にエラー** or **安全なデフォルト**へ🛟

この考え方は「Tolerant Reader（寛容な読み手）」として有名だよ📚✨
**Martin Fowler** も「読めないものを気にしすぎない」方向を推してるよ。 ([martinfowler.com][2])

---

## 6.6 TypeScriptで体感：レスポンスに項目が増えた📦➕

たとえば、最初はこうだった👇

```ts
type UserV1 = {
  id: string;
  name: string;
};
```

サーバが新しくなって、こう増えた👇（よくある！）

```ts
type UserV2 = {
  id: string;
  name: string;
  nickname?: string; // 追加（しかも optional）
};
```

ここでのポイント💡

* **追加（optional）**は、壊れにくい変更になりやすい🙆‍♀️✨
* クライアント側が `id` と `name` しか使ってないなら、`nickname` が増えても困らない🙈🧡
* これは「新サーバ × 旧クライアント」でも壊れにくい典型例だよ🌈

---

## 6.7 逆に危険：必須にする／名前を変える／型を狭める⚠️💥

同じ `User` でも、こうすると壊れやすい…😱

### ❌ 名前変更（rename）

* `name` → `fullName` みたいに変える
  → 旧クライアントは `name` が無くて壊れる💥

### ❌ 必須にする（optional → required）

* `nickname?: string` を `nickname: string` にする
  → 古いデータや古いサーバが `nickname` を出さないと新クライアントが困る😵‍💫

### ❌ 型を狭める（string → "A" | "B"）

* 受け取れる範囲が減る
  → 今まで通ってた値が弾かれて壊れがち🧨

---

## 6.8 “前方互換”の最強トラップ：enum追加で落ちるやつ😇🧨

サーバ側で「状態」を増やしたときに、クライアントが落ちるのあるある💥
（例：`status: "draft" | "published"` に `"archived"` が追加される）

TypeScriptで“未来の値”に強くするには、受け取った値をこう扱うのがコツ👇

```ts
const knownStatuses = ["draft", "published"] as const;
type KnownStatus = (typeof knownStatuses)[number];

function normalizeStatus(raw: string): KnownStatus | "unknown" {
  return (knownStatuses as readonly string[]).includes(raw) ? (raw as KnownStatus) : "unknown";
}
```

* **知らない値は `"unknown"` に退避**🛟
* UIでは「不明な状態です」みたいに安全に表示できる😊✨
* 「追加に弱いenum」を、そのまま“全部知ってる前提”で握りつぶさないのが大事🙌

（現場でも「enum追加で古い生成クライアントが死ぬ」問題はよく話題になるよ🧯） ([GitHub][3])

---

## 6.9 SemVerとつながる：互換を守るなら MINOR / 壊すなら MAJOR🔢✨

バージョニングの超有名ルール「SemVer」では、

* **互換を保った機能追加** → MINOR
* **互換を壊す変更** → MAJOR

って整理されてるよ📌 ([Semantic Versioning][4])

ここでのコツ🧠

* 「互換」って言ったとき、だいたい **“利用者が壊れない”** を指すことが多い
* だから「利用者が動くか？」を基準に MAJOR/MINOR を決めやすいよ🙆‍♀️✨

---

## 6.10 ミニ演習：どっち互換？分類してみよ〜📌📝

次の変更は「壊れにくい／壊れやすい」をまず直感で分けて、
そのあと「誰が困る？」を1行で書いてみてね😊✨

1. レスポンスに `age?: number` を追加
2. レスポンスの `name` を `fullName` に変更
3. リクエストに `email`（必須）を追加
4. リクエストに `couponCode?: string`（任意）を追加
5. `status: "draft" | "published"` に `"archived"` を追加
6. `price: number` を `price: string` に変更
7. `limit` のデフォルト値を 20 → 100 に変更
8. フィールド `isAdmin` を削除
9. `tags?: string[]` を `tags: string[]` に変更（必須化）
10. レスポンスで「知らないフィールドが来ても無視する」実装にした

### ざっくり答え合わせ（目安）✅✨

* **壊れにくい寄り**：1, 4, 10（ただし“使い方”次第）
* **壊れやすい寄り**：2, 3, 5, 6, 7, 8, 9
  特に 3,5,6,8,9 は事故率高め😇💥

（“新旧スキーマ混在”の互換性をどう定義するかは、スキーマ進化の文脈でも整理されてるよ。） ([Confluent Documentation][5])

---

## 6.11 今日のまとめ：一言で言うと…🧡🌈

* **後方互換**：新しい側が古い相手とも動ける🧡
* **前方互換**：古い側が新しい相手でも壊れにくい🌈
* APIは **リクエスト方向／レスポンス方向**があるので、
  「誰が送る？誰が読む？」で考えると混乱が減るよ🧠✨

---

## 6.12 AI活用（コピペOK）🤖💬✨

* 「この変更は *旧クライアント×新サーバ* で壊れる？理由も3つで」
* 「このレスポンス変更を、互換を壊しにくい形（optional追加など）に直して」
* 「enum追加に強い TypeScript の受け取り方を3案（unknown fallback含む）で」
* 「この変更一覧を、後方互換／前方互換／破壊的変更で分類して、根拠も添えて」

[1]: https://en.wikipedia.org/wiki/Backward_compatibility?utm_source=chatgpt.com "Backward compatibility"
[2]: https://martinfowler.com/bliki/TolerantReader.html?utm_source=chatgpt.com "Tolerant Reader"
[3]: https://github.com/OAI/OpenAPI-Specification/issues/1552?utm_source=chatgpt.com "Extensible enumerations (growable lists) · Issue #1552"
[4]: https://semver.org/?utm_source=chatgpt.com "Semantic Versioning 2.0.0 | Semantic Versioning"
[5]: https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html?utm_source=chatgpt.com "Schema Evolution and Compatibility for Schema Registry ..."
