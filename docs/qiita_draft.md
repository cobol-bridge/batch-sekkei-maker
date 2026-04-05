# COBOLのバッチ設計書、もう手書きしなくていい――自動生成ツールを作った話

## はじめに

「このバッチ、設計書ありますか？」

そう聞くと、「…ちょっと探してみます」と返ってくる。ようやく見つかっても、最終更新が10年前。金融・保険・公共系のCOBOLバッチでは、割と"あるある"だと思う。

とはいえ、設計書を新しく書こうとすると、ソースを読みながらExcelに転記する作業が延々と続く。時間はかかるし、書いたそばから現物とズレていく。

「ソースから設計書を自動生成できればいいのでは？」
そんな思いつきから、Pythonで **バッチ設計書メーカー** を作った。

## ツールの概要

- COBOLソース（`.cbl` / `.cob`）を選ぶだけで設計書を自動生成
- **完全オフライン動作**（ソースは外部に送信されない）
- Excel / Word の両形式に対応
- Windows向けに `.exe` で配布（Python不要）

GitHub: https://github.com/cobol-bridge/batch-sekkei-maker

## 完全オフラインにこだわった理由

最初に決めたのが「オフラインで完結させる」こと。

金融・保険系の現場では、ソースコードは社外秘。外部サービスに送るのは基本NGだ。ChatGPTに貼り付けてドキュメント化する方法もあるが、セキュリティ要件的に許されないケースがほとんど。

このツールはネットワーク通信を一切行わず、すべてローカルで処理する。安心して使えることを最優先にした。

## 抽出する情報

COBOLバッチの設計書として最低限必要な情報を、次の4つに絞った。

### 1. I/O定義

`SELECT` と `FD` から入出力ファイルを抽出する。

```cobol
FILE-CONTROL.
    SELECT URIAGE-FILE ASSIGN TO 'URIAGE.DAT'
        ORGANIZATION IS SEQUENTIAL.
    SELECT TOKUISAKI-FILE ASSIGN TO 'TOKUISAKI.DAT'
        ORGANIZATION IS INDEXED
        ACCESS MODE IS RANDOM
        RECORD KEY IS TK-CODE.
```

抽出結果はこんな感じ。

| No | ファイル名 | FD名 | レコード長 | 物理ファイル名 | ファイル編成 | アクセスモード | レコードキー |
|----|-----------|------|-----------|--------------|-------------|--------------|------------|
| 1 | URIAGE-FILE | URIAGE-FILE | 100 | URIAGE.DAT | SEQUENTIAL | | |
| 2 | TOKUISAKI-FILE | TOKUISAKI-FILE | 80 | TOKUISAKI.DAT | INDEXED | RANDOM | TK-CODE |

### 2. 処理フロー

`PERFORM` 文から呼び出し関係を抽出する。`THRU`・`UNTIL`・`VARYING` にも対応。

```cobol
0000-MAIN.
    PERFORM 1000-INIT
    PERFORM 2000-MAIN-LOOP UNTIL WS-EOF
    PERFORM 9000-END.
```

抽出結果はこんな形。

| No | 呼び出し元 | 呼び出し先 | 種別 |
|----|-----------|-----------|------|
| 1 | 0000-MAIN | 1000-INIT | PERFORM |
| 2 | 0000-MAIN | 2000-MAIN-LOOP | UNTIL |
| 3 | 0000-MAIN | 9000-END | PERFORM |

### 3. 例外処理

`INVALID KEY` / `AT END` / `ON SIZE ERROR` などを一覧化。
`NOT AT END` が `AT END` に誤マッチしないよう、検索順を工夫している。

### 4. 表紙

ファイル名・生成日時・バージョンを自動で記入。

## 実装のポイント：固定形式COBOLのパース

COBOLの固定形式は、列位置に意味がある独特の構造だ。

```
列1-6:   連番（シーケンス番号）
列7:     標識欄（* でコメント行）
列8-11:  A領域（段落名・節名など）
列12-72: B領域（文）
列73-:   識別欄（無視）
```

まずはコメント行と連番を取り除き、本文だけを扱うようにした。

```python
def _clean_lines(self, lines: list) -> list:
    clean = []
    for line in lines:
        if len(line) < 7:
            clean.append(line.rstrip())
            continue
        indicator = line[6] if len(line) > 6 else " "
        if indicator in ("*", "/"):
            continue  # コメント行をスキップ
        content = line[6:72].rstrip() if len(line) > 6 else ""
        if content:
            clean.append(content)
    return clean
```

`SELECT` は複数行にまたがることが多いため、`SELECT` から次の `SELECT` または `FD` までをひとまとまりとして扱う正規表現を使っている。

```python
select_block_pattern = r"(SELECT\s+\S+.*?)(?=SELECT\s|\bFD\b|\Z)"
```

## 使い方

`.exe` を起動して、

1. 「参照…」でCOBOLソースを選ぶ
2. 出力先フォルダを指定
3. Excel / Word を選択
4. **「設計書を生成する」** をクリック

数秒で設計書とログが出力される。

## 動作確認

テストは `pytest` で18件。
`SELECT`句・`FD`句・`PERFORM`・例外ハンドラの抽出精度を確認している。

```
$ pytest tests/ -v
==================== 18 passed in 0.71s ====================
```

## まとめ

作ってみて実感したのは、設計書が存在しない現場ほど、このツールの価値が大きいということ。

まずはソースからたたき台を数秒で作り、人間が確認して整える。
そのサイクルが回り始めれば、ドキュメントが現物に追いつく未来も見えてくる。

ソースはGitHubに公開しているので、Issue や PR も歓迎。

https://github.com/cobol-bridge/batch-sekkei-maker

---

*本ツールはCOBOL設計書作成を補助するものです。出力結果は必ず目視で確認してください。*
