# 第11章：なぜファイル共有が必要？（コードはホスト、実行はコンテナ）🧩

この章は一言でいうと——
**「編集する場所」と「動かす場所」を分けて、つなぐ**回です🙂✨
それができると、Docker開発が一気にラクになります💪🚀

---

## この章のゴール🏁✨

* 「コードはどこで編集して、どこで実行されるのか？」が説明できる🙂🗣️
* **ファイル共有（＝bind mount）**がなぜ必要か、腹落ちする😌📌
* “共有できてるか”を**超ミニ実験**で確認できる✅🔍

---

## まず結論：開発は「ホストで編集」→「コンテナで実行」🪟✍️➡️🐳▶️

あなたが普段触ってるファイル（TS/JSON/READMEなど）は、基本 **Windows（ホスト）側**で編集します🪟🧑‍💻
でも実行は **コンテナ（Linux環境）側**で行います🐳🐧

ここで問題が発生します😵

* ホストにあるコードを、コンテナが見られないと……

  * コンテナの中に毎回コピーしないといけない📦💦
  * 変更するたびに build し直しになりがち🔁😇
  * “即反映”ができず、開発のテンポが死ぬ⏳🪦

だから **ファイル共有**が必要になります📁🔁✨

---

## ざっくり図解（文章でOKなやつ）🗺️✍️

こんな関係です👇

* **ホスト（Windows）**：編集担当🪟✍️
* **コンテナ（Linux）**：実行担当🐳▶️
* **共有（bind mount）**：ホストのフォルダを、コンテナから“同じもの”として見せる橋🌉📁

つまり…

> **「編集した瞬間に、コンテナ側にも同じ変更が見える」**
> が作れます⚡

Docker公式の説明でも、bind mount は「ホストのディレクトリをコンテナに共有できて、保存した変更がすぐ見える」用途として紹介されています。([Docker Documentation][1])

---

## そもそも「ファイル共有」って何？（超やさしく）🙂📌

ファイル共有（主に bind mount）は、

* Windowsの `todo-api/` フォルダを
* コンテナ内の `/work/` に
* **くっつける（マウントする）** 仕組みです📎

「コピー」じゃなくて「直結」なので、編集→即反映が起きます⚡([Docker Documentation][1])

---

## ⚠️ Windows + WSL2 での“重要ポイント”🏎️🐢

WindowsでDockerを使うときは、だいたい **Docker Desktop**（中でWSL2を使う構成）が定番です🐳🪟
このとき「どこにソースコードを置くか」で体感速度が変わりやすいです😳

Docker公式のWSL2ベストプラクティスでは、**bind mountするソースコードは Windows側より Linux（WSL側）のファイルシステムに置くのが推奨**と明記されています📌([Docker Documentation][2])
（理由：ファイルI/Oや監視系が安定・高速になりやすいから、ですね🏎️✨）

さらに、Docker Desktopの設定画面で「File sharing」タブが見当たらないことがありますが、**WSL2モードでは自動共有扱い**で、Hyper-Vのときだけ設定タブが出る、という説明も公式にあります📝([Docker Documentation][3])

---

## ハンズオン：共有できてるか“3分で実験”🧪⏱️

ここは「読むだけ」でOKにします📖（書き込みや権限の沼は次章以降で！🪤）

### 実験A（WindowsのPowerShellでやる）🪟💻

1. 作業フォルダを作って移動📁

```powershell
mkdir todo-api
cd todo-api
"Hello from HOST (Windows)!" | Out-File -Encoding utf8 hello.txt
```

2. コンテナからそのファイルを読む🐳👀
   （軽いLinuxでOK。ここでは例として Alpine を使います）

```powershell
docker run --rm -v ${PWD}:/work -w /work alpine:latest cat hello.txt
```

✅ これで **hello.txt の中身が表示**されたら成功🎉
つまり「ホストのファイルをコンテナが見てる」状態です📎✨

3. 変更してもう一回読む🔁

```powershell
"Hello again! updated on HOST!" | Out-File -Encoding utf8 hello.txt
docker run --rm -v ${PWD}:/work -w /work alpine:latest cat hello.txt
```

✅ 更新した内容が表示されたら、**共有＝直結**が体感できたはずです⚡🙂

---

### 実験B（おすすめ：WSL側に置いてやる）🐧🏎️

Docker公式が推奨する「WSLのLinuxファイルシステム側にコードを置く」流れです📌([Docker Documentation][2])
（特に npm install やホットリロードが絡むと効いてきます⚡）

1. WSLターミナルでフォルダ作成📁

```bash
mkdir -p ~/repos/todo-api
cd ~/repos/todo-api
echo "Hello from WSL (Linux filesystem)!" > hello.txt
```

2. コンテナから読む🐳👀

```bash
docker run --rm -v "$(pwd)":/work -w /work alpine:latest cat hello.txt
```

✅ これも同じく表示されれば成功🎉

---

## ここまでで「何がうれしい？」😆✨

ファイル共有ができると、開発がこう変わります👇

* **ホストで編集**（VS Codeでサクサク）✍️✨
* **コンテナで実行**（環境差を消す）🐳✅
* **保存したら即反映**（ビルド地獄から解放）⚡🕊️

Docker公式も「開発中のソースコード共有」に bind mount を推してます📌([Docker Documentation][1])
そしてWSL2環境なら「ソースはLinux側に置く」推奨も明文化されています📌([Docker Documentation][2])

---

## よくある勘違い・つまずき（この章の範囲で回避）🪤😵

### ① 「コンテナ内のファイルを編集すれば、ホストにもあるはず」

➡️ **マウントしてる場所だけ**です📎
マウントしてない場所は、コンテナの中だけの世界🌍🐳（消えることもある）

### ② 「パスが合ってるのに空っぽに見える」

➡️ だいたいこれ👇

* 実行した場所（カレントディレクトリ）が違う📁❌
* `-v <host>:<container>` の左右を逆にした🔁😇
* Windowsパス表記が崩れてる（スペース等）🪟💥

### ③ 「Docker Desktopに File Sharing が無いんだけど！」

➡️ WSL2モードなら“自動共有扱い”で、Hyper-Vモードのときだけ設定が出る説明があります📝([Docker Documentation][3])

---

## AI活用（Copilot / Codex でこの章を秒速で理解する🤖⚡）

あなたの環境は AI 前提なので、ここも最初から使います😄✨
※名前だけ一回出します：GitHub と OpenAI の支援ツール想定です🤖

### プロンプト例①：たとえ話で理解する🏠📦

「Dockerのbind mountを、中学生でもわかる “家と作業場” のたとえで説明して。
ホスト＝家、コンテナ＝作業場、マウント＝通い道 みたいな感じで。」

### プロンプト例②：図解（文章）を作る🗺️✍️

「ホストとコンテナとマウントの関係を、ASCIIアート1枚で描いて。
“編集→保存→即反映”の流れがわかるように。」

### プロンプト例③：エラーが出たときの切り分け表🔍📋

「このエラーの原因候補トップ5と、確認手順を順番に出して：
（ここにエラー文を貼る）」

---

## ミニ課題（5分）🧠⏱️

✅ 次のどっちかをやってみてください🙂

### 課題1：READMEをコンテナから読む📖🐳

* ホストで `README.md` を作る
* bind mount して `cat README.md` で読めたらOK

### 課題2：Todo API用フォルダっぽくする🌱

* `src/` を作って `src/app.ts` を置く
* まだ実行しなくてOK！（“見える化”が目的）

---

## まとめ🎓✨

* Docker開発は **「編集＝ホスト」「実行＝コンテナ」** が基本🪟✍️🐳▶️
* それをつなぐのが **ファイル共有（bind mount）**📎
* 公式でも「開発中のソース共有」に bind mount が紹介されていて、保存した変更が即見えるのがポイント⚡([Docker Documentation][1])
* Windows+WSL2では、公式が **“ソースはLinux（WSL）側に置く”**のを推奨してます🏎️([Docker Documentation][2])

次の第12章では、この bind mount を **もっとちゃんと**扱います💪
「編集→即反映」を **Todo APIで体に染み込ませる**よ〜😆🔥

---

（豆知識：この章で出てきた Docker、そして Microsoft の WSL2 周りは公式ドキュメントが定期的に更新されるので、迷ったら“公式のBest practices”に戻るのが一番安全です🧭📘）

[1]: https://docs.docker.com/get-started/workshop/06_bind_mounts/?utm_source=chatgpt.com "Part 5: Use bind mounts"
[2]: https://docs.docker.com/desktop/features/wsl/best-practices/?utm_source=chatgpt.com "Best practices"
[3]: https://docs.docker.com/desktop/settings-and-maintenance/settings/?utm_source=chatgpt.com "Change your Docker Desktop settings"
