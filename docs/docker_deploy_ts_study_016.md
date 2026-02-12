# 第16章：HTTPS/ドメイン/リダイレクト：公開の最後の壁 🌐🔒

この章は一言でいうと、**「ユーザーが触る“入口（URL）”を事故らない形に整える回」**です 🧑‍🚀✨
アプリが動くだけじゃなくて、

* 🔒 **HTTPSで安全に**
* 🏠 **ドメインを自分のものに**
* 🔁 **URLを1本化（www有無・http→https・古いURL→新URL）**
* 🛂 **CORSを必要最小限で通す（ブラウザ連携の壁）**

ここまでできると「公開した！」の完成度が一気に上がります 💪🔥

---

## 1) まずは“入口設計”を1分で決める 🧭

## ✅ 決めるのはこの2つだけ

1. **正規URL（canonical）はどれ？**

   * `https://example.com` に統一？
   * `https://www.example.com` に統一？
   * それ以外は **全部リダイレクト** 🔁

2. **APIはどこに置く？**

   * いちばん分かりやすい定番はこれ👇

     * フロント：`https://app.example.com`
     * API：`https://api.example.com`

> 💡「同じドメインに `/api` で置けばCORSいらないのでは？」
> これは確かに強いんだけど、Cloud Runの“直マッピング”は**パス（`/api`）単位にマッピングできない**制約があります。([Google Cloud Documentation][1])
> パス制御をやるなら **ロードバランサ（推奨）** や **Firebase Hosting** が得意です。([Google Cloud Documentation][1])

---

## 2) Cloud Runでカスタムドメインを使う“3ルート” 🛣️

Cloud Runの公式ドキュメントでは、カスタムドメインのやり方が複数あり、**推奨はロードバランサ**になっています。([Google Cloud Documentation][1])

## ルートA（推奨・本番向け）：ロードバランサの前段でドメイン制御 🥇

* ✅ いろいろ制御できる（パス振り分け、独自TLS、CDN、WAFなど）([Google Cloud Documentation][1])
* ✅ HTTP→HTTPSリダイレクトなども“入口”で処理しやすい
* 少しだけ設定が増える（でも後で必ず役に立つ）

## ルートB（学習・小規模向け）：Cloud Run Domain Mapping（プレビュー）🧪

* ✅ 設定が軽い（サクッといける）
* ✅ **Google管理の証明書が自動で発行＆更新**される([Google Cloud Documentation][1])
* ⚠️ ただし **プレビュー扱いで、レイテンシ問題があり本番非推奨**と明記されています([Google Cloud Documentation][1])
* ⚠️ 証明書は通常15分、最大24時間かかることがある([Google Cloud Documentation][1])
* ⚠️ TLS 1.0/1.1を無効にできない／独自証明書を使えないなど制約あり([Google Cloud Documentation][1])

## ルートC：Firebase Hostingの前段で受ける 🎯

* ✅ 静的フロント＋APIをまとめてやりたい時に強い
* ✅ HostingのrewritesでCloud Runに流せる([Google Cloud Documentation][1])

> この教材の流れ的には、まずは **ルートBで体験** → ちゃんと運用したくなったら **ルートAへ昇格** が気持ちいいです 😆✨

---

## 3) ハンズオン：カスタムドメインを生やす（最短ルートB）🌱

ここでは **Cloud Run Domain Mapping** で「ドメイン→Cloud Run」をつなぎます。

## ステップ1：Cloud Runでドメインマッピングを追加 ➕

* Cloud Run の **Domain mappings** から追加
* 初回は **ドメイン所有確認**が必要（Search Console経由）([Google Cloud Documentation][1])
* マッピング先のサービスを選ぶ

## ステップ2：表示されたDNSレコードを、そのままDNSに入れる 🧩

Cloud Runが「このDNS入れてね」って **レコードを表示**してくれます。
それを **1文字も変えず**にDNSへ登録します。([Google Cloud Documentation][1])

* 種別は `A` / `AAAA` / `CNAME` など、表示通りに([Google Cloud Documentation][1])
* `www` は `www.example.com`、`@` は `example.com` の意味、という説明もあります([Google Cloud Documentation][1])
* 反映は数分〜数時間（TTL次第）([Google Cloud Documentation][1])

## ステップ3：証明書の発行を待つ 🔒⏳

* HTTPS証明書は **自動で発行＆更新**されます([Google Cloud Documentation][1])
* ただし発行は **通常15分、最大24時間**かかることもある([Google Cloud Documentation][1])

## ステップ4：WindowsでDNS確認（超おすすめ）🔍

PowerShellでこれ👇

```powershell
Resolve-DnsName api.example.com
```

または

```powershell
nslookup api.example.com
```

> ✅ ここで「変な古いIP」が出たり「解決できない」なら、DNSがまだ or 入れ間違いです 😵‍💫

## よくある罠：Cloudflare等のCDNが検証を邪魔する 🧨

Cloud Run公式でも「一部CDNが検証リクエストを横取りして、証明書更新に失敗することがある」と注意があります。([Google Cloud Documentation][1])
例として Cloudflare を使う場合、特定設定（“Always use https”）をオフにしないと失敗することがある、と具体例も書かれています。([Google Cloud Documentation][1])

---

## 4) “URLを1本化”する：リダイレクト設計 🔁🏁

## 最低限そろえたいリダイレクト3点セット

1. **http → https**（鍵マーク統一🔒）
2. **www有無を統一**（`www`あり/なし、どっちかに寄せる🏠）
3. **古いパス → 新しいパス**（あとでURL変えても死なない👻）

## どこでリダイレクトする？

* **入口でやる（推奨）**：ロードバランサでHTTP→HTTPSなどを処理

  * Google CloudのLBでHTTP→HTTPSリダイレクトを設定する公式手順があります([Google Cloud Documentation][2])
* **アプリでやる（手軽）**：Express等のミドルウェアで制御

  * 学習段階はアプリ側で“仕組み”を理解するのが超良いです 👍

---

## 5) ハンズオン：Express(TypeScript)で「https強制＆正規ドメイン固定」🛠️

## まず大事：プロキシ配下なら `trust proxy` が必須 🙏

Cloud Runやロードバランサの後ろでは、`req.secure` 判定などに影響するので入れます。

```ts
import express from "express";

const app = express();

// Cloud Run / LB / 代理の後ろ前提
app.set("trust proxy", true);

// ここは自分の正規ホストに変更してね
const CANONICAL_HOST = "api.example.com";

// 1) http → https 強制 + 2) host統一
app.use((req, res, next) => {
  const proto = (req.headers["x-forwarded-proto"] as string | undefined) ?? "https";
  const host = req.headers["host"];

  // httpsへ寄せる
  if (proto !== "https") {
    return res.redirect(308, `https://${host}${req.originalUrl}`);
  }

  // hostを1本化（www有無、別ドメイン等）
  if (host && host !== CANONICAL_HOST) {
    return res.redirect(308, `https://${CANONICAL_HOST}${req.originalUrl}`);
  }

  next();
});

app.get("/healthz", (_req, res) => res.status(200).send("ok"));

app.listen(process.env.PORT ?? 8080, () => {
  console.log("listening...");
});
```

> 💡 301でもいいけど、**308はメソッド（POST等）を保ちやすい**ので、APIだと308が便利なことが多いです 😊

---

## 6) CORS：公開で一番ハマる“見えない壁”🧱😵‍💫

## CORSを超ざっくりで言うと…

ブラウザが「このAPI、別のサイトから呼んでいい？」って確認してくる仕組みです 🛂
サーバー同士の通信（バッチ、curl、バックエンド間）はCORS関係ないです。

## 絶対に覚える1点：`credentials` と `*` は一緒に使えない ❌🍪

Cookieや認証情報を含むリクエスト（`credentials: "include"`）をする時、
`Access-Control-Allow-Origin: *` だとブラウザが拒否します。([MDNウェブドキュメント][3])

さらにヘッダーの意味（`Access-Control-Allow-Origin` が何か）はMDNが基準になります。([MDNウェブドキュメント][4])

---

## 7) ハンズオン：安全寄りCORS（許可リスト方式）🛡️✅

## 例：フロントが `https://app.example.com` だけの想定

```ts
import cors from "cors";
import express from "express";

const app = express();
app.set("trust proxy", true);

const allowlist = new Set([
  "https://app.example.com",
  "http://localhost:5173", // 開発用（必要なら）
]);

app.use(
  cors({
    origin: (origin, cb) => {
      // originが無いケース（curl等）は許可することが多い
      if (!origin) return cb(null, true);

      if (allowlist.has(origin)) return cb(null, true);

      // 許可しないoriginは弾く
      return cb(new Error("CORS blocked"), false);
    },
    credentials: true, // Cookie等を使うならtrue（使わないならfalseが楽！）
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
    maxAge: 600, // preflightをしばらくキャッシュ
  })
);
```

## CORS方針の“安全寄りテンプレ” 🎯

* ✅ まずは **許可するOriginを2〜3個に絞る**（prod＋localhost）
* ✅ 認証が必要なら `credentials: true`、その場合 `*` は使わない([MDNウェブドキュメント][3])
* ✅ `methods` / `headers` も必要最小限に
* ✅ 「Originをそのまま反射して返す」実装は危険になりやすい（OWASPでも危ない例として触れられます）([OWASP Foundation][5])

---

## 8) 動作確認：CORSとリダイレクトを“目で見る”👀🔍

## ① リダイレクト確認（HTTPヘッダーを見る）

```bash
curl -I http://api.example.com/healthz
```

期待：`308`（または`301`）で `https://...` に飛ぶ ✈️

## ② CORSのpreflight確認（OPTIONS）

```bash
curl -i -X OPTIONS "https://api.example.com/some-api" ^
  -H "Origin: https://app.example.com" ^
  -H "Access-Control-Request-Method: GET"
```

期待：`Access-Control-Allow-Origin` が返る（内容は自分の設定次第）([MDNウェブドキュメント][4])

---

## 9) つまずきTop7 😵‍💫➡️😆

1. **DNSが反映されない**
   → `Resolve-DnsName` で今どこに向いてるか確認 🔍

2. **証明書が“待機中”のまま**
   → DNSの入れ間違いが多い／発行は最大24時間もありうる([Google Cloud Documentation][1])

3. **Cloudflare等で証明書更新が失敗する**
   → CDNが検証を邪魔するケースがある（公式注意）([Google Cloud Documentation][1])

4. **wwwとnon-wwwが混在してCookieが効かない**
   → “正規ホスト”を決めてリダイレクトで統一 🏠

5. **CORSエラー（allow-originが無い）**
   → API側のCORSミドルウェアが先に動いてない、など順番ミスが多い 🧩

6. **`credentials: true` なのに `*` にして死ぬ**
   → それはブラウザが仕様で拒否するやつ！([MDNウェブドキュメント][3])

7. **プリフライト（OPTIONS）が落ちる**
   → ルーティングでOPTIONSを落としてる／ミドルウェア未設定／LB側でブロック等

---

## 10) ミニ課題（この章の“完成チェック”）✅🎉

* ✅ `http://` でアクセスしても `https://` に寄せられる
* ✅ `www` あり/なし、どっちでも最終的に **正規URLに揃う**
* ✅ フロント（`app.example.com`）からAPIを叩ける
* ✅ CORS許可Originが“最小”になっている（`*` じゃない）
* ✅ ついでに `/healthz` が生きてる（運用が楽）🩺

---

## 11) Copilot/Codexに投げるプロンプト例 🤖💬

* 「Express(TypeScript)で、`x-forwarded-proto` と `host` を使って https強制＆正規ドメインへ308リダイレクトするミドルウェアを書いて」
* 「APIが `https://api.example.com`、フロントが `https://app.example.com` のとき、安全寄りのCORS設定（許可リスト方式）を提案して。credentialsあり／なし両方」
* 「CORSのpreflight（OPTIONS）が失敗する原因を、優先度順にチェックリスト化して」

---

次の章（第17章）からは「イメージを置く場所＝レジストリ」と「自動化（CI/CD）」に入っていくので、
この第16章で **入口（ドメイン・HTTPS・リダイレクト・CORS）を固めておく**と、公開がめちゃ安定します 🚀✨

[1]: https://docs.cloud.google.com/run/docs/mapping-custom-domains "Mapping custom domains  |  Cloud Run  |  Google Cloud Documentation"
[2]: https://docs.cloud.google.com/load-balancing/docs/https/setting-up-http-https-redirect?hl=ja&utm_source=chatgpt.com "従来のアプリケーション ロードバランサに HTTP から HTTPS ..."
[3]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS/Errors/CORSNotSupportingCredentials?utm_source=chatgpt.com "Reason: Credential is not supported if the CORS header ..."
[4]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Access-Control-Allow-Origin?utm_source=chatgpt.com "Access-Control-Allow-Origin header - HTTP - MDN Web Docs"
[5]: https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/11-Client-side_Testing/07-Testing_Cross_Origin_Resource_Sharing?utm_source=chatgpt.com "Testing Cross Origin Resource Sharing"
