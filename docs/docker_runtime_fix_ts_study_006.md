# 第06章：まずは `docker run` で「閉じ込め」体験🐳💨

この章は **“PCのNodeを一切使わずに” Nodeを動かす** ところまで一気にいきます😆✨
ここで「え、ホストにNodeいらないじゃん！」が腹落ちしたら勝ちです🏆🎉

---

## 1) まず結論：これだけで閉じ込め体験できる✅

VS Code のターミナル（PowerShellでOK）で、これ👇を叩くだけです💥

```powershell
docker run --rm node:24 node -v
```

* 初回は `node:24` イメージのダウンロード（pull）が走るので少し待つことがあります⏬
* 最後に `v24.x.x` みたいなのが出たら成功です🎊
  なお、**Node v24 は Active LTS** の位置づけです。([Node.js][1])

---

## 2) ここで何が起きてるの？（超ざっくり理解）🧠✨

`docker run` はだいたいこういう意味です👇

* `node:24` 👉 **Node入りの箱（イメージ）** を使う📦
* `node -v` 👉 箱の中で実行するコマンド🏃‍♂️💨
* `--rm` 👉 終わったら箱（コンテナ）を自動で捨てる🧼（ゴミが残りにくい！）

つまり、あなたのPCに入ってるNodeが古くても新しくても関係なく、**常に “箱の中のNode v24” が動く** ってことです🔒✨

---

## 3) 「ほんとにPCのNode使ってない？」を確かめる🔎😏

まず、ホスト側（Windows）に Node が入ってる人はこう👇

```powershell
node -v
```

次に、コンテナ側👇（さっきのやつ）

```powershell
docker run --rm node:24 node -v
```

ここでバージョンが違っててもOK🙆‍♂️
大事なのは **プロジェクトでは常にコンテナ側のNodeを使える** ってことです🎯✨

---

## 4) もう一歩：npm も “箱の中” で動く📦📦

「Nodeだけじゃなくてnpmも同じ箱に入ってる」も確認しちゃいましょう😆

```powershell
docker run --rm node:24 npm -v
```

さらに、Nodeの中身（versions）を一発表示もできます👇

```powershell
docker run --rm node:24 node -p "process.versions"
```

---

## 5) “箱の中に入って操作する” 体験（-it）🧑‍💻🐳

今度は「箱の中に入る」モードです✨
（Debian系の `bookworm-slim` を使うと、学習が安定しやすいです👍 タグも公式で用意されています）([Docker Hub][2])

```powershell
docker run -it --rm node:24-bookworm-slim bash
```

入れたら、箱の中で👇

```bash
node -v
npm -v
cat /etc/os-release
exit
```

* `cat /etc/os-release` で「この箱はDebian系なんだ〜」が見えて気持ちいいです😆🐧

---

## 6) 便利ワザ：実行中のコンテナを “別ターミナル” で覗く👀

さっき `bash` で入った状態のまま、別ターミナルを開いて👇

```powershell
docker ps
```

「いま動いてる箱」が一覧で見えます📋✨
出てきたら「おぉ、動いてる！」ってなるやつです😆

---

## 7) よくある詰まりポイント集（ここだけ見れば復帰できる）🧯🔥

## A. `Cannot connect to the Docker daemon` 系🥶

だいたい **Docker Desktop が起動してない** だけです💡
起動してもう一回やればOKなことが多いです✅

## B. WindowsのDockerは WSL2 が基本路線🐧🪟

Docker Desktop は WSL2 バックエンドを使うのが王道です（設定や確認コマンドも公式にあります）([Docker Documentation][3])
WSLの状態チェックだけするなら👇

```powershell
wsl.exe -l -v
```

## C. 初回 pull が遅い・止まる🐢

ネットワーク（社内プロキシ等）で止まることがあります😵‍💫
まずは別イメージで通信確認もアリ👇

```powershell
docker run --rm hello-world
```

---

## 8) この章のミニ課題（5分）📝✨

1. **Node v24 が出る**ことを確認✅

```powershell
docker run --rm node:24 node -v
```

2. `process.versions` を出して「箱の中のNode情報」を眺める👀

```powershell
docker run --rm node:24 node -p "process.versions"
```

3. `-it` で中に入って `cat /etc/os-release` を見る🐧

```powershell
docker run -it --rm node:24-bookworm-slim bash
```

---

## 9) AIに投げる一言（作業スピード爆上げ）🤖⚡

VS Code のAIにこれを投げてOKです👇

* 「PowerShellで、Dockerコンテナ（node:24）を使って `node -v` と `npm -v` を確認するコマンドを3つ出して。`--rm` の意味も1行で！」

---

## おまけ：Docker Desktop は “最新版維持” が安全🛡️✨

Docker Desktop には過去に **重大な脆弱性が修正されたアップデート**もあるので、基本は最新版に寄せるのが安心です🔒（例：4.44.3 で修正された CVE-2025-9074 など）([Docker Documentation][4])

---

ここまでできたら、もう「ランタイム固定」の入口は突破です🚪✨
次（第7章）で **`node:24` の “タグの読み方”** を覚えると、固定が一気にプロっぽくなります😎🏷️

[1]: https://nodejs.org/en/about/previous-releases?utm_source=chatgpt.com "Node.js Releases"
[2]: https://hub.docker.com/_/node?utm_source=chatgpt.com "node - Official Image"
[3]: https://docs.docker.com/desktop/features/wsl/?utm_source=chatgpt.com "Docker Desktop WSL 2 backend on Windows"
[4]: https://docs.docker.com/security/security-announcements/?utm_source=chatgpt.com "Docker security announcements"
