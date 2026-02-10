# 第03章：Windowsで詰まりやすいポイント先回り💣

この章は「**ハマりどころを最短で回避して、快適なDXに一直線**」がテーマだよ😊✨
Windowsは便利だけど、DockerやLinuxと混ざると **“ズレ”** が出やすいんだ。先に潰しちゃおう🧨

---

## まず結論：快適さは「置き場所」で8割決まる📌

💡 一番効くルールはこれ👇

* ✅ **プロジェクト（ソースコード）はWSL側（Linux側）のファイルシステムに置く**
  → 体感でホットリロードやnpmが速くなりやすい🏎️💨 ([Docker][1])
* ✅ **DockerコマンドもWSL側から叩く**（開発がスムーズになりやすい） ([Docker][1])
* ✅ **VS CodeはWSL拡張で“WSLのフォルダを開く”**（編集はWindows、実行はWSLで気持ちいい）🧠✨ ([Visual Studio Code][2])

---

## 0. まずはサクッと健康診断🩺（詰まりの芽を早期発見）

## WSLのバージョンは要チェック👀

Docker DesktopのWSL連携は、**WSL 2.1.5以上が最低ライン**（できれば最新版）だよ🧩 ([Docker Documentation][3])

```bash
wsl --version
wsl -l -v
```

💡 ついでに、Docker DesktopのWSL連携でおすすめされてる設定として **autoMemoryReclaim**（メモリ戻りを良くするやつ）もあるよ🧠（重たいビルドの後にPCがモッサリしがちな人に効く）([Docker Documentation][3])

---

## 1. 罠①：プロジェクトを `C:\...` に置くと遅くなりがち🐢💥

## ありがちな症状😵

* 保存したのに反映が遅い（ホットリロードが“温くない”）🥶
* `npm install` がやたら遅い🐌
* ファンが回る🌀（CPUが元気すぎる）

## 回避策✅

**WSLのホーム配下に置く**だけで改善しやすいよ（ここが最重要）📌 ([Docker][1])

```bash
mkdir -p ~/work
cd ~/work
git clone <your-repo>
cd <your-repo>
```

## VS Codeの開き方（ここも大事）🧠

* VS Codeの **WSL拡張** を使って “WSL側のフォルダ” を開く
  → これで「編集はVS Code、実行はWSL」の気持ちいい流れになるよ😊 ([Visual Studio Code][2])

---

## 2. 罠②：パス問題（Windowsパス・Linuxパスが混ざる）🧩🌀

## ありがちミス例😇

* compose.yaml に `C:\something\project` みたいなWindowsパスを書いちゃう
* `\`（バックスラッシュ）と `/`（スラッシュ）が混ざる

## 安全ルール✅

* Composeの `volumes:` は **相対パス（`.`）で書く**のが安定しやすい
* どうしても絶対パスが必要なら、**WSL側のパス（`/home/...`）で統一**

```yaml
services:
  app:
    volumes:
      - .:/app
```

---

## 3. 罠③：改行（CRLF/LF）でシェルが死ぬ💀🧨

## ありがちな症状😵‍💫

* `bad interpreter: /bin/sh^M` みたいなエラー
* コンテナ内でスクリプトが動かない
* 差分が改行だらけになる😭

## 回避策A：`.gitattributes` で改行を“ルール化”📏（おすすめ）

Gitの属性で「この拡張子はLFね！」って決めると強い💪
（GitHubも改行問題の対策として `.gitattributes` を案内してるよ） ([Stack Overflow][4])

```gitattributes
## まずは主要テキストをLFに統一（必要に応じて追加してOK）
*.ts   text eol=lf
*.tsx  text eol=lf
*.js   text eol=lf
*.jsx  text eol=lf
*.json text eol=lf
*.yml  text eol=lf
*.yaml text eol=lf
*.md   text eol=lf
*.sh   text eol=lf

## バイナリは変換しない
*.png  binary
*.jpg  binary
*.gif  binary
*.pdf  binary
```

## 回避策B：Git設定でCRLF事故を減らす🧯

`core.autocrlf` の挙動はOSで事故りやすいので、**WSL側でGitを使うなら“Linux前提”の設定**に寄せるのが定番だよ🧠 ([Git][5])

```bash
git config --global core.autocrlf input
```

---

## 4. 罠④：大文字/小文字が“Windowsでは通るのにLinuxで落ちる”⚠️

## ありがちな症状😇

* `import "./UserService"` と書いてるけど、実ファイルは `userService.ts`
* Windowsだと動くのに、コンテナ（Linux）で落ちる💥

## 回避策✅：TypeScriptに“厳しくチェック”させる👮‍♂️

```json
{
  "compilerOptions": {
    "forceConsistentCasingInFileNames": true
  }
}
```

これ入れておくと「将来の地雷」を早めに踏める（＝直せる）よ😊💣

---

## 5. 罠⑤：権限（実行ビット）でスクリプトが動かない🔒

## 症状😵

* `Permission denied`
* `./scripts/dev.sh` が実行できない

## 回避策✅

* WSL側で `chmod +x` を付ける
* そして **改行がLF** であることもセットで大事（CRLFだと別の死に方する）💀

```bash
chmod +x ./scripts/dev.sh
```

---

## 6. 罠⑥：`node_modules` をマウントして地獄を見る😇🔥

## ありがちな失敗😵‍💫

* `node_modules` がホスト側にできて爆重＆不安定
* OS差でネイティブ依存が壊れる（特にWindowsとLinuxが混ざると…）💥

## 定番の回避策✅（“ソースだけ”マウントする）

「ソースは共有、node_modulesはコンテナ側」の形が安定しやすいよ🧰

```yaml
services:
  app:
    volumes:
      - .:/app
      - /app/node_modules
```

ポイント：`/app/node_modules` を **匿名ボリューム** にして、ホストに出さない作戦🧠✨

---

## 7. 罠⑦：ホットリロードが効かない（watchが拾えない）👀💤

## 原因あるある😵

* ファイルイベントが遅い／取りこぼす
* マウント越しの監視が重い

## 回避策A：とにかく“WSL側に置く”📌（またこれ！でも強い）

Docker公式でも「WSL側に置くのが大事」って言ってるやつだよ🧱 ([Docker][1])

## 回避策B：Compose Watchで“同期＆必要ならリビルド”へ👀✨

Compose Watchは「保存したら同期」「依存が変わったらリビルド」みたいなルール運用ができるよ🧠

* **Docker Compose 2.22.0+ が必要** ([Docker Documentation][6])
* パスは「プロジェクト基準」「glob非対応」「.dockerignore適用」などルールあり ([Docker Documentation][6])
* `ignore` は `path` からの相対になる（ここ初心者がハマりやすい） ([Docker Documentation][6])

```yaml
services:
  web:
    build: .
    command: npm run dev
    develop:
      watch:
        - action: sync
          path: ./src
          target: /app/src
          ignore:
            - node_modules/
        - action: rebuild
          path: package.json
```

実行はこんな感じ👇

```bash
docker compose up --watch
```

---

## 8. 罠⑧：ネットワーク（localhostの“向き”問題）🌐🔁

## まず知っておくと楽な話😊

* Windows ↔ WSL は設定やモード（NAT / mirrored）で挙動が変わることがあるよ🧩
* 新しめの **mirrored mode** だと `localhost` で相互アクセスしやすい、って説明があるよ📌 ([Microsoft Learn][7])

## もし「WSLからWindowsのlocalhostに繋がらない…」となったら😵

* NATモードだと **IPで繋ぐ**のが必要になるケースがある（Microsoftの説明でも触れられてる） ([Microsoft Learn][7])
* さらにLAN公開絡みだとファイアウォールも絡む（Windows 11 22H2以降はHyper-V firewallが既定で有効…みたいな話） ([Microsoft Learn][8])

「この章では深入りしないけど、詰まったらここが原因かも！」くらい覚えておけばOK👍✨

---

## ミニ課題（10〜15分）🧪✨

## 課題1：置き場所の最適化🚚

1. プロジェクトをWSL側（`~/work`）に移す
2. `docker compose up` を回す
3. 保存→反映の速さが体感で変わるかチェック👀

## 課題2：改行事故を予防🧯

1. `.gitattributes` を追加
2. わざとCRLFになりそうなファイル（`.sh`）を作って、動作確認
3. “差分が改行だらけ”が減るか見てみよう😊

---

## よくある詰まりQ&A🧩

* ❓「`npm install` が遅い」
  ✅ まずは **プロジェクト場所** と **node_modulesの置き方** を疑う（本章の罠①＆⑥）🏎️💨

* ❓「変更しても反映されない」
  ✅ まずは **WSL側に置けてるか** → 次に **Compose Watch**（罠⑦）👀

* ❓「`^M` が出た」
  ✅ ほぼ改行（CRLF/LF）！ `.gitattributes` が最強🧯

---

## AIで時短🤖✨（でも安全運転）

* 🧠 **`.gitattributes` の叩き台**を作ってもらう（拡張子追加案も出してもらう）*attachして差分レビューが楽*
* 🧰 **compose.yaml の watch ルール案**を作らせる（`ignore` の位置とかミスりやすいので、最後は自分で確認） ([Docker Documentation][6])
* 🧯 詰まりログを貼って「原因候補を3つ」出させる → 1個ずつ潰す（闇雲に触らない！）😊

（GitHubの拡張や OpenAI系ツールを使うと、この辺の“叩き台作り”がめっちゃ速いよ🤖💨）

---

次の章（第4章）で「題材プロジェクト（最小のNode/TS API）」を作り始めると、ここで潰した罠の効果が一気に効いてくるよ😊🔥

[1]: https://www.docker.com/blog/docker-desktop-wsl-2-best-practices/?utm_source=chatgpt.com "Docker Desktop: WSL 2 Best practices"
[2]: https://code.visualstudio.com/docs/remote/wsl?utm_source=chatgpt.com "Developing in WSL"
[3]: https://docs.docker.com/desktop/features/wsl/ "WSL | Docker Docs"
[4]: https://stackoverflow.com/questions/21822650/disable-git-eol-conversions?utm_source=chatgpt.com "Disable git EOL Conversions"
[5]: https://git-scm.com/book/ja/v2/Git-%E3%81%AE%E3%82%AB%E3%82%B9%E3%82%BF%E3%83%9E%E3%82%A4%E3%82%BA-Git-%E3%81%AE%E8%A8%AD%E5%AE%9A?utm_source=chatgpt.com "Git - Git の設定"
[6]: https://docs.docker.com/compose/how-tos/file-watch/ "Use Compose Watch | Docker Docs"
[7]: https://learn.microsoft.com/en-us/windows/wsl/networking?utm_source=chatgpt.com "Accessing network applications with WSL"
[8]: https://learn.microsoft.com/ja-jp/windows/wsl/networking?utm_source=chatgpt.com "WSL を使用したネットワーク アプリケーションへのアクセス"
