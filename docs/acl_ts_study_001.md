# 1章：ACLってなに？“翻訳係”のイメージをつかもう 🗣️🌍

## 今日のゴール 🎯✨

この章を読み終わったら、次の3つができればOKだよ〜！😊💡

* ACL（Anti-Corruption Layer）が何をするものか、ひとことで言える 🗣️
* 「外部のクセが内側に入るとヤバい理由」をイメージできる 😱
* ACLが“通訳＋防波堤”って感覚でわかる 🌊🛡️

---

# 1. ACLってなに？超ざっくり一言で！🧼🧱

ACLはね、

**「外部システムの言葉を、自分のアプリの言葉に翻訳してから渡す層」**だよ〜！🗣️➡️📘✨

外部（APIとか古い基幹システムとか）って、こっちの都合を考えてくれないんだよね…😇
だから、その“外部のクセ”をそのままアプリの中に持ち込むと、内側がどんどん汚れていく（＝腐敗）🫠
それを防ぐのがACL！🛡️✨

Microsoftのパターン解説でも「意味（セマンティクス）が違うサブシステム間に、変換する層を入れる」って説明されてるよ。([Microsoft Learn][1])
microservices.ioでも「2つのドメインモデルの間を翻訳する」って定義されてるよ。([microservices.io][2])

---

# 2. “翻訳係”のたとえでイメージしよう 🗣️🌍💬

たとえば、あなた（アプリの内側）が日本語で話したいのに、外部APIが英語＋方言＋略語で返してくる感じ！😵‍💫

* 外部「`stu_kbn=1`」
* 内側「え、`1`って何！？学部生？院生？留学生？🤯」

ここでACL（翻訳係）が登場！🦸‍♀️✨

* 外部「`stu_kbn=1`」
* ACL「`studentType = Undergraduate` に変換するね！」🔁
* 内側「うん、意味わかる！助かる！🥹✨」

---

# 3. 「外部のクセ」って具体的にどんなの？👻🧾

外部って、こういう“クセ”がめっちゃあるよ〜😇💦

## よくあるクセ一覧 🧨

* **命名が独特**：`stu_kbn`, `user_flg`, `s_y` とか略しすぎ問題 🥲
* **コード値が謎**：`"1"`, `"2"`, `"9"`（9って何！？）🔤❓
* **null / 空文字 / 欠損が混ざる**：`null`なのか`""`なのか`" "`なのか…😇
* **型がブレる**：数字のはずが文字列 `"100"` で来る 😵
* **単位が違う**：円なの？ドルなの？税込？税抜？💴💲
* **日時がややこしい**：タイムゾーン不明・フォーマットぐちゃぐちゃ ⏰🌍

ACLは、こういうのを**内側に入る前に整えて、意味のある形にする**役目だよ🧼✨

---

# 4. 外部のクセが内側に入ると起きる事故 😱💥

「別にそのまま使えば早くない？」って思いがちなんだけど…ここが落とし穴！🕳️😵

## 事故①：内側のコードが“外部語”だらけになる 🧟‍♀️

* 変数名が `stu_kbn` になる
* `if (stu_kbn === "1")` みたいな謎分岐が増える
* だんだん「このアプリ何のアプリだっけ？」状態に…😇

## 事故②：外部がちょっと変わるだけで内側が全壊 💣

外部APIが

* `stu_kbn` → `student_kbn` に変えました！
* `"1"` → `1` に変えました！

…みたいな変更をすると、内側のあちこちが壊れる😱
ACLがあれば「外との境界」だけ直せば済むのに〜！🛡️✨

## 事故③：テストがしんどい 🧪💦

内側のロジックをテストしたいのに、外部DTOの形に引っ張られると

* テストデータ作るだけで疲れる
* 仕様変更でテスト全部書き換え
  になりがち😭

ACLを入れると「内側は内側のルール」でテストできるようになるよ✨

---

# 5. まずは“図”で理解しよう 📦🚪🧱

イメージはこれ！👇😊

* 外部API（相手の都合）🌩️
* **ACL（翻訳・防御）🧱🛡️**
* アプリの内側（自分のルール）📘✨

つまり、ACLは「境界の門番」みたいな存在だよ🚪🛡️
外部の情報は、**いったんACLで“読みやすい形”にしてから**内側へ通す！✅

---

# 6. TypeScriptで“雰囲気”だけ先に見よう 🔍✨

## ❌ 例：外部DTOをそのまま内側で使う（危険）😇

```ts
// 外部APIが返す形（外の都合）
type StudentDto = {
  stu_kbn: "1" | "2";     // 1=学部生, 2=院生…みたいな謎コード
  name: string | null;   // nullが来ることもある
};

// 内側のロジックが外部DTOに依存しちゃう
function canUseLibrary(dto: StudentDto): boolean {
  if (dto.stu_kbn === "1") return true;  // ←「1」って何だっけ…？
  return false;
}
```

これ、読んだ瞬間に「1って何！？」ってなるよね😵‍💫💦

---

## ✅ 例：ACLで翻訳してから、内側の型で扱う（安全）🛡️✨

```ts
// 内側の言葉（自分の都合）
type StudentType = "Undergraduate" | "Graduate";

type Student = {
  type: StudentType;
  name: string; // 内側では「null禁止」にしたい！
};

// ACL：外→内への翻訳係 🧱
function toDomainStudent(dto: { stu_kbn: "1" | "2"; name: string | null }): Student {
  const type: StudentType = dto.stu_kbn === "1" ? "Undergraduate" : "Graduate";
  const name = (dto.name ?? "").trim();
  if (!name) throw new Error("名前が空はダメ"); // ここで守る（詳細は後の章で！）
  return { type, name };
}

// 内側ロジックは「意味がわかる言葉」だけで書ける 💖
function canUseLibrary(student: Student): boolean {
  return student.type === "Undergraduate";
}
```

ポイントはここ！👇✨

* 内側は `Undergraduate` みたいな**意味がわかる言葉**だけで動く📘
* 外部の`"1"`や`null`は、**境界（ACL）で処理して終わり**🧼🛡️

Microsoftの説明でも「ファサード/アダプター層で変換して、外部依存で設計が縛られないようにする」って言ってるよ。([Microsoft Learn][3])

---

# 7. ミニ演習（3分）📝⏱️✨

次の外部レスポンスが来たとするよ👇😇

* `payment_status = "A"`（Aってなに？）
* `amount = "1200"`（数値じゃないの？）
* `paid_at = "2026/01/29 08:00"`（タイムゾーン不明）

## やること 💪

1. 「内側で使いたい形」を考える（例：`PaymentStatus` を enum にする）🔤✨
2. 「ACLで直す場所」を3つ書く（例：status翻訳、金額パース、日時パース）🧱🧼
3. 「内側に入れたくないもの」を1つ書く（例：`"A"`みたいな謎コード）🚫

---

# 8. AI（Copilot/Codex）を使うときのコツ 🤖💡✨

ACLのコードって「変換が多い」からAIと相性いいよ〜！🧠⚡

## 使いやすいお願い例 💬

* 「このDTOをドメイン型に変換する関数を作って。未知コードはエラーにして」
* 「DTO→ドメイン変換のユニットテスト観点を箇条書きして」

## でも注意！⚠️

AIは“意味”を勝手に決めちゃうことがあるよ😇

* `"1"`が学部生、って仕様は本当に合ってる？
* 金額は税込？税抜？通貨は？
  ここは必ず人間が監督〜！🛡️✨

---

# 9. まとめ 🧼🧱🎉

* ACLは**外部の言葉を内側の言葉に翻訳**する層 🗣️➡️📘
* 外部DTOが内側に入ると、命名汚染・変更で崩壊・テスト地獄が起きがち 😱💥
* だから境界にACLを置いて、**内側をキレイに保つ**🧼✨

---

# 10. チェック問題（サクッと！）✅🧠

1. ACLを一言で説明すると？🗣️
2. 外部DTOが内側に入ると困ることを2つ言える？😱
3. 「翻訳するのはどこ？」→ **境界（ACL）**って言える？🧱

---

## おまけ：2026年の“今”の空気ちょいメモ 🧩✨

* TypeScriptは GitHub のリリースページ上で **5.9.3 が Latest**として表示されているよ。([GitHub][4])
* Node.jsは **v24 が Active LTS**、**v25 が Current**として掲載されてるよ。([nodejs.org][5])

[1]: https://learn.microsoft.com/ja-jp/azure/architecture/patterns/anti-corruption-layer?utm_source=chatgpt.com "破損対策レイヤー パターン - Azure Architecture Center"
[2]: https://microservices.io/patterns/refactoring/anti-corruption-layer.html?utm_source=chatgpt.com "Pattern: Anti-corruption layer"
[3]: https://learn.microsoft.com/en-us/azure/architecture/patterns/anti-corruption-layer "Anti-corruption Layer pattern - Azure Architecture Center | Microsoft Learn"
[4]: https://github.com/microsoft/typescript/releases "Releases · microsoft/TypeScript · GitHub"
[5]: https://nodejs.org/en/about/previous-releases "Node.js — Node.js Releases"
