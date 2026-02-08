# 第29章：小さな設計：ポート設計のルールを決める📏

この章は「Dockerのネットワークで毎回モヤる😵‍💫」の元凶になりがちな **“ポート番号のぐちゃぐちゃ”** を、最小の設計でスッキリさせる回だよ〜😄🧹✨
（ルールを一回作るだけで、今後ずっとラクになるやつ！）

---

## この章のゴール🎯✨

* 複数プロジェクトを同時に動かしても **ポート衝突しにくいルール** が作れる📦🔌
* 「ホスト側ポート」と「コンテナ側ポート」を混同しなくなる🧠✨
* 自分のPJ用の **ポート表（台帳）** を作れる📋✅

---

## 1) まず最小の考え方：ポートは「入口の番号」🚪🔢

Dockerでややこしくなるのは、ポートが **2種類** あるからだよ〜😵

* **コンテナ側ポート**：コンテナの中のアプリが待ち受けてる入口（例：Nodeが3000で待つ）
* **ホスト側ポート**：Windows（あなたのPC）で開ける入口（例：localhost:4010 で見たい）

Dockerはこの2つを **ひも付け（マッピング）** して外から見えるようにする📌
ポートを外に公開するには `--publish (-p)` を使う、というのが基本ルールだよ🐳✨
（公開されてないポートは、基本的にホストの外から見えない）([Docker Documentation][1])

---

## 2) ルール作りで超重要：ポート番号の「範囲」を知る📐

ポート番号（0〜65535）はざっくり3つのゾーンに分かれてるよ🔢✨

* **0〜1023**：システム用（有名どころ）
* **1024〜49151**：一般アプリ用（登録ポート帯）
* **49152〜65535**：動的/プライベート（いわゆるエフェメラル）([iana.org][2])

さらにWindowsは、送信（クライアント側）で使う **動的ポート範囲が 49152〜65535** になってるのが基本だよ🪟⚙️([Microsoft Learn][3])

✅ なので、**「固定で使う待ち受けポート」は 49152 未満に寄せる**のが無難！
（絶対ダメではないけど、混乱と衝突の芽を減らせる🌱）

---

## 3) ポート設計の“勝ちパターン”3選🏆🎉

「毎回その場で適当に決める」から卒業しよ😇✨
ここでは、個人開発で強いルールを3つ出すね！

---

## パターンA：プロジェクトID方式（おすすめ🥇）🧩

**“プロジェクトごとにベース番号を決めて、役割で+する”** 方式！

例）Todo APIプロジェクトのIDを **41** にすると…

* API：**4100**
* Web：**4101**
* DB：**4102**
* Admin：**4103**
* Redis：**4104**（将来用）

✅ 良いところ

* 覚えやすい🧠✨
* 同時に何個立ち上げても衝突しにくい💥回避
* 表にしやすい📋

---

## パターンB：ポート帯（ブロック）確保方式📦

**1プロジェクトに「20個のポート枠」を渡す**感じ。

例）Todo APIは 4200〜4219 を使う、みたいに決める💡

✅ 良いところ

* サービス増えても枠内で完結しやすい🧱
* 将来Composeで増殖しても事故りにくい🐳🐳🐳

---

## パターンC：慣習ポート（3000/5173/5432）を守る方式🧪

ExpressやNext.jsは3000が多いし、Viteは5173がデフォルトだよね〜ってやつ😄

* Expressの例は3000で待ち受けが定番([Express][4])
* Next.js devは基本3000がデフォルト([Next.js][5])
* Vite devは5173がデフォルト([vitejs][6])

⚠️ ただし複数PJを同時に動かすと **だいたい衝突** する😇
→ だからこの章では、AかBを推すよ🫶✨

---

## 4) Todo API用：ポート台帳（まずこれ作ろう）📋✅✨

ポートは「決めたら終わり」じゃなくて、**書いて残す**のが超大事✍️
（未来の自分が助かる😭✨）

**台帳の方針**：プロジェクトID方式でいく例（ID=41）

> 以下の内容を `ports.md` に保存する想定だよ📄✨

```markdown
## Port Ledger (Todo API)

## Project ID
- 41

## Host Ports (Windows)
- 4100: API (Node/TS)
- 4101: Web (Vite) ※将来
- 4102: DB (Postgres) ※将来
- 4103: DB Admin (Adminer/pgAdmin) ※将来
- 4104: Redis ※将来

## Container Ports (Default)
- API: 3000
- Web: 5173
- Postgres: 5432
- Adminer: 8080 (or 80)
- Redis: 6379
```

この「Host Ports（Windows側）」が今回の設計の主役だよ〜🪟✨

---

## 5) ハンズオン：衝突しないポートを決めて、動くのを確認🚀✅

## Step 1：今、空いてるかチェック🔍🪟

PowerShellでOK！
（例：4100を使いたい）

```powershell
## そのポートを使ってるプロセスがあるか確認
Get-NetTCPConnection -LocalPort 4100 -ErrorAction SilentlyContinue

## もし何か出たら、PIDも見えるので原因追跡できるよ
```

「動的ポート範囲」も一応見れる（雑学だけど役に立つやつ）🧠✨

```powershell
netsh int ipv4 show dynamicport tcp
```

この確認コマンド自体も含めて、Windowsの既定動的ポート範囲が 49152〜65535 って話は公式に書かれてるよ🪟([Microsoft Learn][7])

---

## Step 2：`docker run` のポートを “自分ルール” に合わせる🐳🔌

例：コンテナ内のAPIは **3000** で待ち受けしてるけど、Windows側は **4100** で開けたい。

```bash
docker run --rm -p 4100:3000 your-api-image
```

`docker ps` で `PORTS` を見たり、もっとピンポイントに知りたければ `docker port` が便利だよ👀🪵([Docker Documentation][8])

---

## Step 3：公開範囲を“ローカルだけ”に縛る（安全寄り）🔒🏠

`-p 4100:3000` だと、環境によっては **LANから見えちゃう** 事故が起きることがある😇
ローカルだけにしたいなら、こう！

```bash
docker run --rm -p 127.0.0.1:4100:3000 your-api-image
```

Composeでも同じ考え方で `host_ip: 127.0.0.1` が使える（ロング形式）よ🧷✨([matsuand.github.io][9])

---

## 6) 「環境変数でポートを集約」して、さらに事故を減らす🎛️📦

次の章以降でComposeに入ると、ポートは増える。
だから今のうちに「ポートは.envに集める」クセを付けると強い💪😄✨

`.env`（例）

```env
API_HOST_PORT=4100
API_CONTAINER_PORT=3000
```

これを（将来）Composeで使うと、読みやすさが爆上がりする📈✨

---

## 7) ありがち事故あるある😇🧯（先に潰す）

## 事故①：`Port is already in use` 💥

* 別PJが同じポートを使ってる
* 以前のプロセスが残ってる
* Docker Desktopの何かが握ってる

👉 まずは PowerShell の `Get-NetTCPConnection` で誰が使ってるか見るのが最短🏃‍♂️💨

---

## 事故②：Viteが勝手にポートずらして迷子になる🌀

Viteは、デフォルト5173だけど **埋まってたら次を試す** よ（便利だけど混乱するやつ）([vitejs][6])
「絶対このポートじゃなきゃダメ！」なら `strictPort` を使う発想がある💡([vitejs][6])

---

## 事故③：Next.jsは3000固定っぽく見える問題🧠

Next.js devは基本3000がデフォルトだよ([Next.js][5])
複数プロジェクト並べるなら、最初から「プロジェクトID方式」で逃がすのが精神衛生に良い😌✨

---

## 8) AI活用コーナー🤖✨（そのままコピペOK）

## プロンプト①：ポート設計案を出させる🧩

```text
以下のサービス構成で、Windowsローカル開発用のポート設計ルールを提案して。
条件：
- 固定ポートは 49152 未満にする
- プロジェクトID方式（例：ID=41なら 4100〜）を基本
- API/Web/DB/Admin/Redis まで増える想定
- 表（Host port / Container port / 役割 / メモ）で出す
サービス構成：
- API (Node/TS)
- Web (Vite)
- DB (Postgres)
- Admin (pgAdmin or Adminer)
- Redis
```

## プロンプト②：衝突チェックの観点をチェックリスト化✅

```text
Dockerのポート衝突が起きたときの切り分けチェックリストを作って。
PowerShellでの確認コマンド例（Get-NetTCPConnection など）も入れて。
```

## プロンプト③：ports.md を綺麗に整形📋✨

```text
この ports.md を読みやすい形に整形して。重要：Host port と Container port を混同しない書き方にして。
（ここに ports.md を貼る）
```

---

## 9) まとめ🎓🎉

* ポートは「その場のノリ」で決めると、後で必ず詰まる😇
* **プロジェクトID方式**（例：4100台）みたいな小さな設計が、長期で最強💪✨
* **49152未満**に寄せると、Windowsの動的ポート帯ともバッティングしにくくて安心🪟🔧([Microsoft Learn][3])
* `ports.md` みたいな台帳があると、未来の自分が泣いて喜ぶ😭📋✨

次の章では、この“筋肉”を使って「公開・接続・切り分け」をまとめてトレーニングするよ〜🏋️‍♂️🔥

[1]: https://docs.docker.com/engine/network/port-publishing/?utm_source=chatgpt.com "Port publishing and mapping"
[2]: https://www.iana.org/assignments/service-names-port-numbers?utm_source=chatgpt.com "Service Name and Transport Protocol Port Number Registry"
[3]: https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/default-dynamic-port-range-tcpip-chang?utm_source=chatgpt.com "The default dynamic port range for TCP/IP has changed in ..."
[4]: https://expressjs.com/en/starter/hello-world.html?utm_source=chatgpt.com "Express \"Hello World\" example"
[5]: https://nextjs.org/docs/pages/api-reference/cli/next?utm_source=chatgpt.com "next CLI"
[6]: https://vite.dev/config/server-options?utm_source=chatgpt.com "Server Options"
[7]: https://learn.microsoft.com/ja-jp/troubleshoot/windows-client/networking/tcp-ip-port-exhaustion-troubleshooting?utm_source=chatgpt.com "TCP/IP ポート不足のトラブルシューティング - Windows Client"
[8]: https://docs.docker.com/reference/cli/docker/container/port/?utm_source=chatgpt.com "docker container port"
[9]: https://matsuand.github.io/docker.docs-ja/reference/compose-file/services/?utm_source=chatgpt.com "Docker Compose でのサービス定義"
