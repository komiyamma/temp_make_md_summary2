# 第08章：環境変数（env）で設定を切り替える🎚️🐳

## 今日のゴール🎯

* **同じイメージ**を、環境変数で**設定だけ変えて**動かせるようになる🙂✨
* `-e/--env` と `--env-file` を使い分けられるようになる📦🧠
* 「動かない…😵」のときに、**環境変数が入ってるか確認**できるようになる🔍🪵

---

## 1) 環境変数ってなに？（超ざっくり）🙂

環境変数は、アプリに渡す「設定のつまみ」🎛️ です。

* ✅ 良い例：`PORT=3000`, `LOG_LEVEL=debug`, `APP_MODE=dev`
* ❌ ありがち：設定をコードに直書き（あとで地獄😇）

Dockerでは、コンテナ起動時に `-e/--env` や `--env-file` で渡すと、**コンテナ内のプロセスがその値を読める**ようになります。さらに、イメージ側（Dockerfileの `ENV`）で定義された値も、起動時に上書きできます。([Docker Documentation][1])

---

## 2) まずは最短で体験：`-e/--env` で1個だけ渡す🚀

### ✅ 例：値を渡して、コンテナ内で表示する

```bash
docker run --rm -e GREETING=Hello alpine sh -c 'echo $GREETING'
```

* `--rm`：終わったら自動で片付け🧹✨
* `-e KEY=VALUE`：環境変数を1個渡す🎁

---

## 3) “設定で挙動が変わる”を体感しよう（Nodeでミニ実験）🧪🟩

「同じコマンド（同じイメージ）なのに、設定だけで出力が変わる」を体験します😄

> 2026-02時点だと、Nodeは **v25系がCurrent**、安定運用の軸は **v24系（LTS）** が分かりやすいです🧭([Node.js][2])

### ✅ `APP_MODE` を渡して表示する（超ミニ）

```bash
docker run --rm -e APP_MODE=dev node:24-alpine node -e 'console.log("APP_MODE=", process.env.APP_MODE)'
```

### ✅ 値だけ変えて、同じことをする（“切り替え”成功🎉）

```bash
docker run --rm -e APP_MODE=prod node:24-alpine node -e 'console.log("APP_MODE=", process.env.APP_MODE)'
```

---

## 4) まとめて渡す：`--env-file`（ファイルで一括）📄✨

環境変数が増えてくると、`-e` を何個も書くのがツラい😵
そこで **envファイル**を使います！

Docker公式の仕様として、`--env-file` の中身は

* `KEY=value`（値をセット）
* `KEY`（ローカル環境から持ってくる）
  が書けて、`#` はコメントとして扱えます（ただし **行頭以外の `#` は値扱い**という罠あり🪤）。([Docker Documentation][1])

### 4-1) envファイルを作る（例：`env.list`）

```bash
cat > env.list << 'EOF'
## comment: この行は無視される
APP_MODE=dev
PORT=3000
EOF
```

### 4-2) `--env-file` で読み込ませる🎁

```bash
docker run --rm --env-file ./env.list node:24-alpine node -e 'console.log(process.env.APP_MODE, process.env.PORT)'
```

### 4-3) “ローカルから持ってくる”もできる（`KEY`だけ書く）

```bash
export TOKEN=abc123
cat > env.list << 'EOF'
TOKEN
EOF

docker run --rm --env-file ./env.list alpine sh -c 'echo $TOKEN'
```

この “`KEY`だけ” の挙動も公式に書かれてます🧾([Docker Documentation][1])

---

## 5) よくある罠まとめ🪤😅（ここ超大事）

### 罠①：`#` が途中にあるとコメントじゃない

```txt
PASSWORD=abc#123
```

これ、`#123` も値に入ります（行頭の `#` だけがコメント扱い）。([Docker Documentation][1])

### 罠②：envファイルで `"..."` って書くと、**ダブルクォートも値に入る**ことがある

Dockerの `--env-file` は「素直に文字として読む」寄りで、引用符が消えない挙動が話題になります😇
👉 **基本はクォート無し**で書くのが安全です。([GitHub][3])

### 罠③：「設定変えたのに反映されない！😡」

envは **起動時に渡すもの**なので、**コンテナを作り直す**（= `docker run` し直す）と反映されます🙂
※ すでに動いてるコンテナの env は、あとから基本変えられません（作り直し！）🧹

---

## 6) デバッグ：環境変数、入ってる？確認しよう🔍🛠️

### 6-1) 一発確認（起動→表示→終了）

```bash
docker run --rm --env-file ./env.list alpine env | grep -E 'APP_MODE|PORT'
```

### 6-2) “動いてるコンテナ” に入って確認（前章の `exec` 活用✨）

```bash
docker run -d --name env-demo --env-file ./env.list alpine sh -c 'sleep 9999'
docker exec env-demo env | grep -E 'APP_MODE|PORT'
docker rm -f env-demo
```

---

## 7) ちょい設計：env名のルール（初心者でも迷わない版）📏🙂

おすすめはこれ👇（シンプルが正義👑）

* **全部大文字＋_区切り**：`APP_MODE`, `LOG_LEVEL`, `DB_HOST`
* **アプリ固有なら接頭辞**：`TODO_API_PORT`, `TODO_API_LOG_LEVEL`
* **値の型っぽさ**

  * bool：`FEATURE_X_ENABLED=true/false`
  * 数字：`PORT=3000`
  * 列挙：`APP_MODE=dev|prod|test`

> さらに先（Compose）では「同じ変数が複数の場所で定義されたときの優先順位」が効いてきます。CLI（`-e`）が強い、などのルールが公式に整理されています📚([Docker Documentation][4])

---

## 8) 秘密情報（パスワード等）はどうする？🔐

envは便利だけど、**秘密をそのまま入れるのは注意**⚠️
（ログに出たり、履歴に残ったり、共有で漏れたり😱）

Docker公式でも、**機密はSecretsを検討**って言っています。([Docker Documentation][5])
この教材の後半で“安全なやり方”に進むときに回収しようね🙂✨

---

## 9) AI活用コーナー🤖✨（コピペで使える！）

### ✅ プロンプト①：env設計の「ありがち事故」先に潰す

「Dockerで環境変数を使うときに初心者がやりがちな失敗を10個、症状→原因→確認コマンド→直し方でまとめて」

### ✅ プロンプト②：Todo API向け env のたたき台

「Todo APIの開発用として必要そうな環境変数を、`APP_` と `DB_` に分けて提案して。型（string/number/bool）と例値もつけて」

### ✅ プロンプト③：`.env.example` を作る

「この `.env` をもとに、秘密情報を伏せた `.env.example` を作って。コメントで用途も添えて」

---

## 10) ミニ課題（5〜10分）📝🔥

1. `env.list` を `APP_MODE=dev` / `APP_MODE=prod` の2種類作る
2. それぞれで `docker run --env-file ...` を実行
3. 出力が切り替わるのを確認🎉

できたら、次章以降で **Todo APIの設定（PORT/LOG_LEVEL/DB接続情報）** を env に寄せていくと、気持ちよく育てられます🌱😄

---

## まとめ🎓✨

* `-e/--env`：少数なら手軽🫶
* `--env-file`：増えたらこれが正解📄
* envファイルは `KEY=value`、`#` の扱いに注意🪤([Docker Documentation][1])
* 秘密は雑に入れない（後半で安全運用へ🔐）([Docker Documentation][5])
* Nodeは「Current」と「LTS」があるので、学習・運用ではLTS軸が安心🧭([endoflife.date][6])

次の章に進む前に、「env渡した値を、コンテナ内で確認できる」まで固めると最強です💪😆

[1]: https://docs.docker.com/reference/cli/docker/container/run/ "docker container run | Docker Docs"
[2]: https://nodejs.org/en/blog/release/v25.6.0?utm_source=chatgpt.com "Node.js 25.6.0 (Current)"
[3]: https://github.com/docker/cli/issues/3630?utm_source=chatgpt.com "Handle quotes in --env-file values consistently with Linux ..."
[4]: https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/ "Environment variables precedence | Docker Docs"
[5]: https://docs.docker.com/compose/how-tos/environment-variables/best-practices/?utm_source=chatgpt.com "Best practices | Docker Docs"
[6]: https://endoflife.date/nodejs?utm_source=chatgpt.com "Node.js"
