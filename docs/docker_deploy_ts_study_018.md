# 第18章：手でpushして理解：自動化の前に体験 ✋📤

この章は「CI/CDが裏でやってること」を、**いったん手でやって身体に入れる回**だよ〜！😆
やるのは超シンプルに👇

* ① イメージを作る（build）🧱
* ② ちゃんと名前を付ける（tag）🏷️
* ③ レジストリに送る（push）📤
* ④ 別環境っぽく取り直す（pull）📥
* ⑤ “同じものが動く” を確認する ✅

---

## 0. まずイメージ名のルールだけ覚える 🧠🏷️

イメージ名はだいたいこの形👇（ここが分かると迷子になりにくい！）

* **Docker Hub系**：`USERNAME/REPO:TAG`
* **GitHub Container Registry（ghcr）系**：`ghcr.io/OWNER/REPO:TAG`

ポイントは3つ✨

* `REPO`：置き場（アプリ名みたいなもの）📦
* `TAG`：目印（例：`v1` / `main` / `20260212`）🏷️
* push/pull は **その名前に対して** 行われるよ

---

## ハンズオン（おすすめ：ghcr.io ルート）🐙📦

次章（GitHub Actions）とつながりが良いので、ここでは **ghcr.io を主ルート**にするね！
（Docker Hub ルートは後半に “別ルート” として載せるよ😉）

---

## 1) ghcr.io にログインする 🔐🐙

ghcr は **PAT（Personal Access Token）** を使うのが手作業だと分かりやすい👍
GitHub公式でも `--password-stdin` の形が案内されてるよ。([GitHub Docs][1])

## 1-1. PAT を作る（ざっくり）

GitHubでトークンを作るとき、最低限このへんが必要になりやすい👇（典型例）

* `write:packages`（pushするため）
* `read:packages`（pullするため）

※細かい画面手順より「必要スコープの感覚」を掴むのが大事🧠✨（スコープの説明は公式にあるよ）([GitHub Docs][1])

## 1-2. PowerShell でログイン（安全なやり方）

**コマンドにトークンを直書きしない**のがコツ😇（履歴に残りにくい）

```powershell
$env:CR_PAT = "ここにPATを入れる"
$env:GH_USER = "GitHubのユーザー名（または組織名）"

$env:CR_PAT | docker login ghcr.io -u $env:GH_USER --password-stdin
```

`Login Succeeded` が出たら勝ち！🎉

---

## 2) イメージを build（まずはローカルで完成させる）🧱🐳

プロジェクト直下（Dockerfileがある場所）で👇

```powershell
docker build -t local-demo:dev .
docker image ls
```

ここで一度 `local-demo:dev` が作れていればOK👌
（push用の名前はこのあと付け直すよ）

---

## 3) “レジストリ向けの名前” を付ける（tag）🏷️✨

たとえば GitHub が `komiyamma`、リポジトリ名を `hello-web` にするなら👇

```powershell
$env:OWNER = "komiyamma"
$env:IMAGE = "hello-web"
$env:TAG   = "v0.1"

docker tag local-demo:dev ghcr.io/$env:OWNER/$env:IMAGE:$env:TAG
docker image ls
```

> ✅ **tag は「別名を付けるだけ」**（中身をコピーして増やすわけじゃない）
> だから怖がらなくてOK〜😆

---

## 4) push（レジストリに送る）📤🚀

```powershell
docker push ghcr.io/$env:OWNER/$env:IMAGE:$env:TAG
```

push は「差分アップロード」っぽい動きになることが多くて、
ログに `layer already exists` とか出るのも普通だよ〜📦✨

---

## 5) “別環境チェック” をやる（pull して動かす）📥✅

**ローカルに残ってると “pullした気分” だけで終わる**ので、いったん消してからやるのがコツ😎

```powershell
docker rmi ghcr.io/$env:OWNER/$env:IMAGE:$env:TAG
docker pull ghcr.io/$env:OWNER/$env:IMAGE:$env:TAG
```

最後に起動確認（アプリが 3000 を使う例）👇

```powershell
docker run --rm -p 3000:3000 ghcr.io/$env:OWNER/$env:IMAGE:$env:TAG
```

* ブラウザで `http://localhost:3000` を開く 🌐✨
* 動いたら、**「他の場所から持ってきても同じように動く」**が体験できた！🎊

---

## ここまでの流れ＝CI/CDがやってること 🤖🧠

手でやったことを、CI/CDはだいたいこの順で自動化するだけ👇

1. ログイン（token は Secrets から）🔐
2. build（いつも同じDockerfileで）🧱
3. tag（ルールに従って付ける）🏷️
4. push（レジストリに置く）📤

次章でここが “ボタン押さずに勝手に動く” ようになるよ〜😆🚀

---

## つまずき Top7 😵‍💫➡️💡（超あるある）

## 1) `denied: requested access to the resource is denied`

* **原因**：名前が違う / ログインしてない / 権限足りない
* **対処**：`docker login` をやり直す、`OWNER/IMAGE` の綴り確認👀

## 2) `unauthorized: authentication required`

* **原因**：トークンが無効、期限切れ、スコープ不足
* **対処**：PAT再発行＆ `write:packages` / `read:packages` を確認🔑([GitHub Docs][1])

## 3) `name unknown` / `manifest unknown`

* **原因**：存在しないタグを pull した
* **対処**：pushした `TAG` と同じものを pull してるか確認🏷️

## 4) うっかり `latest` で上書きしまくる

* **対処**：今は `v0.1` みたいに **自分でTAGを決めて**練習しよう😇
  （`latest地獄` は第20章で倒す！⚔️）

## 5) `docker push` が遅い

* **原因**：イメージがデカい、不要物が入ってる
* **対処**：`.dockerignore` / マルチステージ（第10章・第8章）を思い出す📉✨

## 6) トークンをコマンドに直書きしちゃった😱

* **対処**：履歴から消す＋トークン即ローテーション（作り直し）🔁
  （`--password-stdin` が推奨の形だよ）([GitHub Docs][1])

## 7) 「pushできたのにどこで見れるの？」

* **対処**：GitHub の Packages（または Docker Hub の Repositories）に出るよ📦👀

---

## 別ルート：Docker Hub でやるなら（超お手軽）🐳🏪

Docker Hub は `docker login` が **ブラウザでコード入力する方式**（device code flow）になってるのが特徴だよ。([Docker Documentation][2])

```powershell
docker login
```

画面に出るURLへ行ってコード入れて認証 → `Login Succeeded` でOK🎉
あとはイメージ名を👇にして push/pull すれば同じ流れ！

* `USERNAME/REPO:TAG`

---

## ミニ課題（5分）📝✨

✅ **2つのタグを同じ中身に付けて push**してみよう！

* `v0.1`（固定の版）
* `main`（“最新っぽい” 動くタグ）

```powershell
docker tag ghcr.io/$env:OWNER/$env:IMAGE:v0.1 ghcr.io/$env:OWNER/$env:IMAGE:main
docker push ghcr.io/$env:OWNER/$env:IMAGE:main
```

「同じ中身でもタグが違うだけで見え方が変わる」を体験できればOK〜😆🏷️

---

## AIに投げると爆速になるプロンプト例 🤖⚡

* 「このプロジェクトの `Dockerfile` と `.dockerignore` を見直して、**pushが速くなる改善案**を優先度つきで出して」
* 「`denied / unauthorized / manifest unknown` が出た時の **原因の切り分けフローチャート**を作って」
* 「ghcr向けの **命名ルール**（owner/repo/tag）を、個人開発で事故りにくい形に提案して」

---

次の第19章では、この一連を **GitHub Actionsで自動化**して「pushしたら勝手にイメージ更新」へ進むよ〜！🔁📦🚀

[1]: https://docs.github.com/ja/packages/working-with-a-github-packages-registry/working-with-the-container-registry?utm_source=chatgpt.com "コンテナレジストリの利用 - GitHub ドキュメント"
[2]: https://docs.docker.com/reference/cli/docker/login/?utm_source=chatgpt.com "docker login"
