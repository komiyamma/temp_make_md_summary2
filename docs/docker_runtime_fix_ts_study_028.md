# 第28章：WindowsでのDockerはWSL2が基本路線🐧🪟

この章のテーマはシンプルです👇
**WindowsでDockerを安定して使うなら、「WSL2（Linux環境）に寄せる」だけで事故が激減する**って話です😆✨

---

#### 1) まず結論：WSL2が“標準ルート”です✅🐳

Docker Desktop は、Windows上で Linux コンテナを動かすときに **WSL2 バックエンド**を使うのが基本になっています。([Docker Documentation][1])
そして公式のベストプラクティスとしても、

* **WSLは最新推奨**
* **最低でも WSL 2.1.5 以上が必要（古いと不調になりやすい）**

が明言されています。([Docker Documentation][2])

ここを満たしてるだけで「なんか不安定…😇」が激減します👍

---

#### 2) WSL2って何がうれしいの？🤔💡（超ざっくり）

WSL2は「Windowsの中に、ちゃんとLinuxカーネルが動くエリアを作る仕組み」です🐧
DockerはLinuxコンテナなので、**Linuxに近い場所で開発するほど自然に動く**わけです✨

特に効くのがこれ👇

* 🔥 **ファイル監視（ホットリロード）が安定する**
  Linuxコンテナが受け取るファイル変更通知（inotify）は、**ファイルがLinux側にある方が正しく届きやすい**です。([Docker Documentation][2])
* ⚡ **ビルド/実行が速くなりやすい**
  Windows側のファイル（例：`/mnt/c` 経由）を bind mount すると遅くなりやすいので、**プロジェクトはWSL側に置くのが推奨**です。([Docker Documentation][2])

つまり、**置き場所が9割**です😎📦

---

#### 3) 3分でできる「WSL2 健康診断」🩺✨

PowerShell（通常でOK、必要なら管理者）で、順に叩くだけです👇

##### A. WSLが入ってるか＆入れる（未導入なら）

* 未導入なら基本はこれ：`wsl --install`（標準のLinuxも入ります）([Microsoft Learn][3])

##### B. WSLを最新に寄せる（地味に超大事）

* `wsl --update` でWSL更新（コレめちゃ効きます）([Microsoft Learn][4])
* `wsl --version` でバージョン確認できます。([Microsoft Learn][4])
  Docker Desktop側は **WSL 2.1.5+ が目安**です。([Docker Documentation][2])

##### C. ディストリ（Ubuntuなど）が WSL2 になってるか確認

* `wsl -l -v`（入ってるLinux一覧と WSL1/2 が見れます）([Microsoft Learn][5])

もし `VERSION` が 1 になってたら、これで直します👇

* `wsl --set-version <DistroName> 2` ([Microsoft Learn][3])

ついでに、新規インストールを全部WSL2に寄せるなら👇

* `wsl --set-default-version 2` ([Microsoft Learn][3])

---

#### 4) Docker Desktop 側の「WSL連携」チェック✅🔧

ここが外れてると「WSLの中で docker コマンド打ったら動かない😇」が起きます。

Docker Desktop を開いて、設定の
**Settings → Resources → WSL Integration** を見てください。([Docker Documentation][1])

* デフォルトのWSLディストリ（例：Ubuntu）に統合が入ってる
* もし別ディストリ使うなら、そこにも統合をON

という考え方です。([Docker Documentation][1])

---

#### 5) いちばん大事：「プロジェクトはWSL側に置く」📁🐧（これで勝つ）

**遅い・監視効かない・なんか不安定**の大半はここです💥

Docker公式の推奨はズバリ👇

* **Linuxファイルシステムに置いた方が速い**
* **`/mnt/c` みたいな“Windows側ファイル”のマウントは避けたい**([Docker Documentation][2])

たとえば、WSL（Ubuntu）内でこういう場所に置くのが王道です👇

* `~/projects/myapp`（= `/home/<you>/projects/myapp`）

そしてWindowsからもエクスプローラーで見たいなら、だいたい👇みたいな経路で見えます（WSLの共有機能）

* `\\wsl$\Ubuntu\home\...`（※環境でディストリ名は変わります）

**編集はVS CodeをWSL側で開く**のが安定しやすいです🧑‍💻✨（ファイル監視も速度も）

---

#### 6) よくある症状と“即効薬”💊😆

##### 症状①：Docker Desktopが不調・起動が怪しい😇

✅ **WSLを更新** → `wsl --update` ([Microsoft Learn][4])
✅ **WSLが古すぎないか**（2.1.5+ 目安）([Docker Documentation][2])

---

##### 症状②：WSL内で `docker` が動かない / 見つからない🫠

✅ Docker Desktop の **WSL Integration をON**（Settings → Resources → WSL Integration）([Docker Documentation][1])
✅ ディストリが WSL2 になってるか `wsl -l -v` で確認→必要なら `wsl --set-version ... 2` ([Microsoft Learn][3])

---

##### 症状③：ホットリロードが効かない / 監視が飛ぶ👀💥

✅ プロジェクトが **Windows側（`/mnt/c`）に置かれてないか**確認
Linuxコンテナが受け取る監視イベント（inotify）の都合で、**Linux側に置く方が安定**しやすいです。([Docker Documentation][2])

---

##### 症状④：とにかく遅い🐢💦

✅ **`/mnt/c` をマウントしてないか**（避けたい）([Docker Documentation][2])
✅ WSLを最新版に寄せる（`wsl --update`）([Microsoft Learn][4])

---

#### 7) ミニ実践：WSL2ルートで「動作確認」✅🎮

WSLのターミナルで、まずはこれが通ると安心です👇

* `docker version`（Dockerが見えてるか）
* `docker run --rm hello-world`（最小テスト）

ここまでOKなら、以降の章で作った `compose.yml` / `Dockerfile` が **“WindowsでもほぼLinuxと同じ感覚”**で動きやすくなります😆🔥

---

#### 8) 今日からの運用ルール（超かんたん）📏✨

* ✅ WSLは `wsl --update` で最新に寄せる([Microsoft Learn][4])
* ✅ WSLのバージョンは `wsl --version` で確認できる([Microsoft Learn][4])
* ✅ ディストリが WSL2 かは `wsl -l -v` で見る([Microsoft Learn][5])
* ✅ 変だったら `wsl --set-version <Distro> 2`([Microsoft Learn][3])
* ✅ プロジェクトは **WSL側（Linux側）に置く**（速い＆監視安定）([Docker Documentation][2])
* ✅ Docker Desktop の **WSL Integration をON**([Docker Documentation][1])

---

次の章（第29章）の「固定を壊さない運用ルール」に入る前に、もしよければ👇だけ教えてください（すぐ解決に直結します）😆

* いまプロジェクト置いてる場所って **Windows側（Cドライブ配下）**？それとも **WSL側（`/home/...`）**？

[1]: https://docs.docker.com/desktop/features/wsl/?utm_source=chatgpt.com "Docker Desktop WSL 2 backend on Windows"
[2]: https://docs.docker.com/desktop/features/wsl/best-practices/?utm_source=chatgpt.com "Best practices"
[3]: https://learn.microsoft.com/en-us/windows/wsl/install?utm_source=chatgpt.com "How to install Linux on Windows with WSL"
[4]: https://learn.microsoft.com/ja-jp/windows/wsl/basic-commands?utm_source=chatgpt.com "WSL の基本的なコマンド"
[5]: https://learn.microsoft.com/ja-jp/windows/wsl/install?utm_source=chatgpt.com "WSL を使用して Windows に Linux をインストールする方法"
