# 第18章：ページング入門②（無限スクロールの考え方）♾️📱

この章は「次へボタンのページング」を、スマホっぽい **無限スクロール** に進化させます😎✨
コツはシンプルで、**Firestoreのカーソル（startAfter）** と、**IntersectionObserver（画面下に来たら読む）** を合体させるだけです💪📜

---

## 0) この章でできるようになること 🎯

* 画面の一番下に近づいたら、**次の10件**を自動で読み込む♾️
* **二重読み込み（連打・多重発火）** を防げる🧱
* **重複表示 / 取りこぼし** を減らす考え方がわかる🧠
* AIで **テストデータを秒速で増やして**、無限スクロールを気持ちよく検証できる🤖✨ ([Firebase][1])

---

## 1) まず“無限スクロールの正体”を理解しよう 👀♾️

無限スクロールって名前だけど、正体は **ページング（ページを小分けに読む）** です📜
違いは「次ページを取りに行くタイミング」が **ボタン** か **スクロール** か、だけ👍

Firestore側は前章と同じで、基本はこれ👇

* `orderBy(...)` で順番を固定
* `limit(10)` で10件ずつ読む
* 次ページは `startAfter(lastDoc)` で **最後のドキュメントの次**から読む ([Firebase][2])

---

## 2) 設計：無限スクロールで死ぬポイント3つ 💥（先に潰す）

無限スクロールは実装自体は簡単なんだけど、事故るのはここ👇

1. **多重発火で二重読み込み**（一瞬で2回読んで重複する）😇
2. **重複表示**（同じdocが2回appendされる）👯
3. **取りこぼし**（順番がブレたり、lastDocの扱いが雑で抜ける）🫥

この章では、最低限のガードとして👇を入れます🧱✨

* `inFlightRef`（通信中フラグ）で **同時実行を禁止**
* `seenIds`（すでに表示したID）で **重複排除**
* `orderBy(createdAt desc)` などで **順番を固定**（順番が固定されないとページが壊れる） ([Firebase][3])

---

## 3) 実装①：Firestore「1ページ取得」関数を作る 📦🔎

前章の「次へボタン」でも使える形にしておくと超ラクです😋

> **注意**：`orderBy()` したフィールドが存在しないドキュメントは、結果に出てきません（存在チェックも兼ねる仕様）
> なので `createdAt` が無いデータが混じると「なんか消えた？」になります🫠 ([Firebase][3])

```ts
import {
  collection,
  query,
  orderBy,
  limit,
  startAfter,
  getDocs,
  type Firestore,
  type QueryDocumentSnapshot,
  type DocumentData,
} from "firebase/firestore";

export type Todo = {
  id: string;
  title: string;
  done: boolean;
  // createdAt / updatedAt は前章までで入れてる想定（serverTimestampでもOK）
  createdAt?: unknown;
  updatedAt?: unknown;
  tags?: string[];
};

const PAGE_SIZE = 10;

export async function fetchTodosPage(
  db: Firestore,
  after?: QueryDocumentSnapshot<DocumentData>
): Promise<{
  items: Todo[];
  lastDoc?: QueryDocumentSnapshot<DocumentData>;
  hasMore: boolean;
}> {
  const baseQuery = query(
    collection(db, "todos"),
    orderBy("createdAt", "desc"),
    limit(PAGE_SIZE)
  );

  const q = after ? query(baseQuery, startAfter(after)) : baseQuery;

  const snap = await getDocs(q);

  const items: Todo[] = snap.docs.map((d) => ({
    id: d.id,
    ...(d.data() as Omit<Todo, "id">),
  }));

  const lastDoc = snap.docs.length ? snap.docs[snap.docs.length - 1] : undefined;

  // 「同じ件数が取れた = まだ続きそう」という雑め推測（学習用には十分）
  const hasMore = snap.docs.length === PAGE_SIZE;

  return { items, lastDoc, hasMore };
}
```

Firestoreのカーソルは **ドキュメントスナップショットをそのまま渡せる** のが気楽で良いです👌 ([Firebase][2])

---

## 4) 実装②：IntersectionObserverで「下に来たら loadMore」👀⬇️

IntersectionObserverは「ある要素が画面内に入ったら教えてくれる」APIです📡
無限スクロールでは、リストの最後に **“見張り役のdiv（sentinel）”** を置いて、見えたら次ページ読みに行きます♾️✨

* `rootMargin` を広げると「ちょい手前で先読み」できて気持ちいいです🚀
  （CSSのmarginっぽい文字列） ([MDN Web Docs][4])

```tsx
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Firestore, QueryDocumentSnapshot, DocumentData } from "firebase/firestore";
import { fetchTodosPage, type Todo } from "./fetchTodosPage";

export function useInfiniteTodos(db: Firestore) {
  const [items, setItems] = useState<Todo[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(true);

  const sentinelRef = useRef<HTMLDivElement | null>(null);

  // 二重読み込みガード🧱
  const inFlightRef = useRef(false);

  // 次ページの起点（カーソル）📌
  const lastDocRef = useRef<QueryDocumentSnapshot<DocumentData> | undefined>(undefined);

  // 重複排除👯❌
  const seenIdsRef = useRef<Set<string>>(new Set());

  const loadMore = useCallback(async () => {
    if (!hasMore) return;
    if (inFlightRef.current) return;

    inFlightRef.current = true;
    setLoading(true);
    setError(null);

    try {
      const { items: nextItems, lastDoc, hasMore: nextHasMore } = await fetchTodosPage(
        db,
        lastDocRef.current
      );

      // 重複排除してから足す
      const filtered = nextItems.filter((t) => !seenIdsRef.current.has(t.id));
      filtered.forEach((t) => seenIdsRef.current.add(t.id));

      setItems((prev) => [...prev, ...filtered]);

      lastDocRef.current = lastDoc;
      setHasMore(Boolean(lastDoc) && nextHasMore);
    } catch (e) {
      const msg = e instanceof Error ? e.message : "読み込みに失敗しました";
      setError(msg);
    } finally {
      setLoading(false);
      inFlightRef.current = false;
    }
  }, [db, hasMore]);

  // 初回ロード（1ページ目）
  useEffect(() => {
    // すでにitemsがあるなら不要（StrictModeで二重実行っぽく見える時の保険）
    if (items.length > 0) return;
    loadMore();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loadMore]);

  // IntersectionObserverで監視👀
  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      (entries) => {
        const first = entries[0];
        if (!first) return;

        if (first.isIntersecting) {
          // ここでloadMoreするだけ♾️
          loadMore();
        }
      },
      {
        root: null,              // 画面（viewport）
        rootMargin: "200px",     // 少し手前で先読み🚀
        threshold: 0,
      }
    );

    observer.observe(el);

    return () => observer.disconnect();
  }, [loadMore]);

  const reset = useCallback(() => {
    setItems([]);
    setHasMore(true);
    setError(null);
    setLoading(false);
    inFlightRef.current = false;
    lastDocRef.current = undefined;
    seenIdsRef.current = new Set();
  }, []);

  return { items, loading, error, hasMore, loadMore, reset, sentinelRef };
}
```

---

## 5) 実装③：画面に組み込む（sentinelを一番下に置く）🧩🧱

```tsx
import React from "react";
import { db } from "./firebase"; // 既存
import { useInfiniteTodos } from "./useInfiniteTodos";

export function TodoListInfinite() {
  const { items, loading, error, hasMore, sentinelRef, loadMore } = useInfiniteTodos(db);

  return (
    <div style={{ maxWidth: 720, margin: "0 auto" }}>
      <h2>ToDo（無限スクロール）♾️</h2>

      {items.map((t) => (
        <div key={t.id} style={{ padding: 12, borderBottom: "1px solid #eee" }}>
          <div style={{ fontWeight: 700 }}>{t.title}</div>
          <div style={{ opacity: 0.7 }}>{t.done ? "✅ done" : "⬜ todo"}</div>
        </div>
      ))}

      {/* 見張り役（ここが見えたら次を読む） */}
      <div ref={sentinelRef} style={{ height: 1 }} />

      {loading && <p>読み込み中…⏳</p>}

      {error && (
        <div style={{ padding: 12 }}>
          <p style={{ color: "crimson" }}>エラー：{error} 😵</p>
          <button onClick={() => loadMore()}>もう一回読み込む🔁</button>
        </div>
      )}

      {!hasMore && !loading && <p>ここまで！🎉</p>}
    </div>
  );
}
```

---

## 6) 事故回避メモ（ここ大事）🧠🧯

## ✅ 二重読み込み（多重発火）対策

* `inFlightRef` で **通信中は無視**🧱
* IntersectionObserverは状況によっては何度も発火します（スクロールやレイアウト更新でも）😅

## ✅ 重複表示対策

* `seenIds` で **IDが同じなら足さない**👯❌
  「同じページを2回読んじゃった」事故が起きても、UI上は守れる✅

## ✅ 取りこぼし対策

* `orderBy(...)` を固定しないと、ページングは壊れます💥
* さらに `orderBy` に使うフィールドが欠けたドキュメントは除外されるので、データ側も整えるのが大事です🧹 ([Firebase][3])

## ✅ コスト意識もちょいだけ💸

無限スクロールは「気持ちいい」反面、スクロールした分だけ読み取りが増えやすいです📈
使いすぎ防止は `limit` 小さめ・`rootMargin` 先読みしすぎない・`hasMore` をちゃんと止める、あたりが効きます👌（使用量の監視方法も公式にあります） ([Firebase][5])

---

## 7) 🤖 AIで“テストデータ作り”を爆速にする（無限スクロールのために）

無限スクロールは **データが少ないと気持ちよさが分からない** んですよね😂
そこで、Firebaseの **Firebase AI Logic** を使って「ToDoタイトルを30個作れ！」→ Firestoreに流し込み、をやります✨
（Web向けのAI Logic SDKで、Gemini/Imagenに安全にアクセスできる系のやつです） ([Firebase][6])

> ちなみにAI Logicの「Get started」には、モデルの提供状況・注意事項（モデルの入れ替え予定など）も載るので、使う前にチラ見推奨です👀 ([Firebase][1])

## 7-1) AIでToDoタイトル配列を作る（JSONで返させる）🧾🤖

```ts
import { getAI, getGenerativeModel, GoogleAIBackend } from "firebase/ai";
import type { FirebaseApp } from "firebase/app";

export function createTodoTitleGenerator(app: FirebaseApp) {
  const ai = getAI(app, { backend: new GoogleAIBackend() });
  const model = getGenerativeModel(ai, { model: "gemini-2.5-flash-lite" });

  return async function generateTodoTitles(count: number): Promise<string[]> {
    const prompt = [
      `日本語のToDoタイトルを${count}個作ってください。`,
      `出力はJSON配列だけにしてください（例：["牛乳を買う","掃除する"]）。`,
      `短く、重複なし。`
    ].join("\n");

    const result = await model.generateContent(prompt);
    const text = result.response.text();

    // 返答が余計な説明付きになっても拾えるように、配列部分だけ抜く（学習用の簡易パース）
    const json = text.match(/\[[\s\S]*\]/)?.[0];
    if (!json) throw new Error("AIの返答がJSON配列じゃなかった…🥲");

    const arr = JSON.parse(json);
    if (!Array.isArray(arr)) throw new Error("JSONが配列じゃない…🥲");

    return arr.map(String);
  };
}
```

この `firebase/ai` 系のAPI（`getAI`, `getGenerativeModel` など）は、公式のAI Logic紹介でも出てきます📚 ([Firebase][1])

## 7-2) 生成したタイトルをFirestoreに入れる（少量ずつでOK）🗃️➕

```ts
import { collection, doc, serverTimestamp, writeBatch, type Firestore } from "firebase/firestore";

export async function seedTodos(db: Firestore, titles: string[]) {
  const batch = writeBatch(db);

  for (const title of titles) {
    const ref = doc(collection(db, "todos")); // 自動ID
    batch.set(ref, {
      title,
      done: false,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      tags: [],
    });
  }

  await batch.commit();
}
```

これで **30件くらい** を一気に作って、無限スクロールが気持ちよく動くかチェックできます♾️🎉

---

## 8) 🧠 AIを“デバッグ相棒”にする（Antigravity / Gemini CLI）🛠️🤖

「二重読み込みがたまに起きる😫」みたいな“地味バグ”は、AIにログとコード見せると早いです🔥

* Google の **Antigravity** は、エージェントに計画→実装→調査までやらせやすい“Mission Control”系です🕹️ ([Google Codelabs][7])
* **Gemini CLI** はターミナル上のオープンソースAIエージェントで、ReActループ＋MCPで「調べる→直す→テスト整える」みたいな流れが得意です🧰 ([Google Cloud Documentation][8])

## そのままコピペで使える依頼テンプレ（おすすめ）📋✨

* 「`useInfiniteTodos` を読んで、**二重読み込みが起きるパターン**を列挙して。発生条件と修正案を出して」🧯
* 「IntersectionObserverの発火が多い。`rootMargin` と `inFlightRef` 周りを改善して、**差分パッチ**で提案して」🔧
* 「Firestoreのページングで、**重複表示・取りこぼし**が起きる原因を3つ挙げて、今のコードで何が起きうるか説明して」🧠

---

## 9) ミニ課題 🧩🎯（この章の“できた！”ライン）

## ✅ ミニ課題A：二重読み込み完全ガード🧱

* すでに入れた `inFlightRef` に加えて、**Observerが連続で発火しても1回しか読まない**のを確認👀
  （ChromeのDevToolsでネットワーク見ながらやると楽しい🕵️）

## ✅ ミニ課題B：重複ゼロの保証👯❌

* `seenIds` を使って、同じIDが混じっても表示が増えないことを確認👍

## ✅ ミニ課題C：AIで50件作って気持ちよくスクロール♾️🎉

* AI Logicでタイトル生成 → seed → 無限スクロールで「ちゃんと追加で読める」を体験✨ ([Firebase][1])

---

## 10) チェックリスト ✅😄

* `startAfter(lastDoc)` が「最後の次から読む」って説明できる 📜 ([Firebase][2])
* `orderBy` のフィールドが欠けると検索結果に出ないのがわかる 🫥 ([Firebase][3])
* IntersectionObserverで「下に来たら読む」を作れた 👀⬇️ ([MDN Web Docs][4])
* 二重読み込み・重複表示を自分で潰せた 🧱✨
* AIでテストデータを作って検証できた 🤖🎯 ([Firebase][1])

---

次の第19章は、ローカルで安全に壊して練習する **Emulator** 編です🧪🧯
無限スクロールは“本番DBでガチャガチャ試す”のが一番危ないので、そこで一気に安心感が上がります😎

[1]: https://firebase.google.com/docs/ai-logic/get-started?utm_source=chatgpt.com "Get started with the Gemini API using the Firebase AI Logic ..."
[2]: https://firebase.google.com/docs/firestore/query-data/query-cursors?utm_source=chatgpt.com "Paginate data with query cursors | Firestore | Firebase"
[3]: https://firebase.google.com/docs/firestore/query-data/order-limit-data?utm_source=chatgpt.com "Order and limit data with Cloud Firestore - Firebase - Google"
[4]: https://developer.mozilla.org/en-US/docs/Web/API/IntersectionObserver/rootMargin?utm_source=chatgpt.com "IntersectionObserver: rootMargin property - Web APIs | MDN"
[5]: https://firebase.google.com/docs/firestore/quotas?utm_source=chatgpt.com "Usage and limits | Firestore - Firebase - Google"
[6]: https://firebase.google.com/docs/ai-logic?utm_source=chatgpt.com "Gemini API using Firebase AI Logic - Google"
[7]: https://codelabs.developers.google.com/getting-started-google-antigravity?utm_source=chatgpt.com "Getting Started with Google Antigravity"
[8]: https://docs.cloud.google.com/gemini/docs/codeassist/gemini-cli?utm_source=chatgpt.com "Gemini CLI | Gemini for Google Cloud"
