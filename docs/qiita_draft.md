# COBOLのバッチ設計書、もう手書きしなくていい――自動生成ツールを作った話

## はじめに

「このバッチ、設計書ありますか？」

そう聞くと「...ちょっと探してみます」という返答が返ってくることがある。見つかったとしても、最終更新が10年前だったりする。

金融・保険・公共系のCOBOLバッチ現場では珍しくない光景だと思う。

設計書を書こうにも、ソースを読み解きながら手作業でExcelに転記するのは時間がかかる。しかも書いた直後からドキュメントは腐り始める。

**「ソースから設計書を自動生成できないか？」** と考えてPythonで作ったのが、今回紹介する **バッチ設計書メーカー** だ。

---

## ツールの概要

- COBOLソースファイル（`.cbl` / `.cob`）を選択するだけで設計書を自動生成
- **完全オフライン動作**（ソースコードは外部に一切送信しない）
- Excel / Word 両形式に対応
- Windows .exe で配布（Python不要）

GitHub: https://github.com/cobol-bridge/batch-sekkei-maker

---

## 完全オフラインにこだわった理由

最初にこだわったのがオフライン動作だ。

金融・保険系のシステムは社外秘コードが多く、「クラウドに送信しない」は要件レベルの話になる。ChatGPTにコードを貼り付けてドキュメントを作る、という方法もあるが、情報セキュリティ上NGな現場がほとんどだろう。

このツールはすべてローカルで完結する。ネットワーク通信は一切行わない。

---

## 何を抽出するか

COBOLバッチ設計書として最低限必要な情報を4種類に絞った。

### 1. I/O定義

`SELECT` 句と `FD` 句から、入出力ファイルの一覧を抽出する。

```cobol
FILE-CONTROL.
    SELECT URIAGE-FILE ASSIGN TO 'URIAGE.DAT'
        ORGANIZATION IS SEQUENTIAL.
    SELECT TOKUISAKI-FILE ASSIGN TO 'TOKUISAKI.DAT'
        ORGANIZATION IS INDEXED
        ACCESS MODE IS RANDOM
        RECORD KEY IS TK-CODE.
```

↓ こんな形で抽出される

| No | ファイル名 | FD名 | レコード長 | 物理ファイル名 | ファイル編成 | アクセスモード | レコードキー |
|----|-----------|------|-----------|--------------|-------------|--------------|------------|
| 1 | URIAGE-FILE | URIAGE-FILE | 100 | URIAGE.DAT | SEQUENTIAL | | |
| 2 | TOKUISAKI-FILE | TOKUISAKI-FILE | 80 | TOKUISAKI.DAT | INDEXED | RANDOM | TK-CODE |

### 2. 処理フロー

`PERFORM` 文から呼び出し階層を抽出する。`THRU`・`UNTIL`・`VARYING` にも対応。

```cobol
0000-MAIN.
    PERFORM 1000-INIT
    PERFORM 2000-MAIN-LOOP UNTIL WS-EOF
    PERFORM 9000-END.
```

↓ こんな形で抽出される

| No | 呼び出し元 | 呼び出し先 | 種別 |
|----|-----------|-----------|------|
| 1 | 0000-MAIN | 1000-INIT | PERFORM |
| 2 | 0000-MAIN | 2000-MAIN-LOOP | UNTIL |
| 3 | 0000-MAIN | 9000-END | PERFORM |

### 3. 例外処理

`INVALID KEY` / `AT END` / `ON SIZE ERROR` などを一覧化する。`NOT AT END` が `AT END` に誤マッチしないよう、キーワードの検索順を工夫した。

### 4. 表紙

ファイル名・生成日時・バージョンを自動記入。

---

## 実装のポイント：固定形式COBOLのパース

COBOLの固定形式は少し特殊で、列位置に意味がある。

```
列1-6:   連番（シーケンス番号）
列7:     標識欄（* でコメント行）
列8-11:  A領域（段落名・節名など）
列12-72: B領域（文）
列73-:   識別欄（無視）
```

まずコメント行と連番を除去してから本文を処理する。

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

SELECT句は複数行にまたがることが多いので、`SELECT` から次の `SELECT` または `FD` までをひとつのブロックとして扱う正規表現を使った。

```python
select_block_pattern = r"(SELECT\s+\S+.*?)(?=SELECT\s|\bFD\b|\Z)"
```

---

## 使い方

`.exe` をダブルクリックして起動。

1. 「参照...」でCOBLソースファイルを選択
2. 出力先フォルダを指定
3. 出力形式を選択（Excel / Word）
4. **「設計書を生成する」** をクリック

数秒で設計書と実行ログが出力される。

---

## 動作確認

テストは `pytest` で18件。SELECT句・FD句・PERFORM・例外ハンドラの抽出精度を検証している。

```
$ pytest tests/ -v
==================== 18 passed in 0.71s ====================
```

---

## まとめ

作ってみて気づいたのは、**設計書がない現場ほどこのツールが刺さる**ということだ。

既存のソースから設計書のたたき台を数秒で生成して、あとは人間が確認・加筆する。そのサイクルが回れば、ドキュメントが現物に追いつくかもしれない。

ソースはGitHubに公開している。IssueやPRも歓迎。

https://github.com/cobol-bridge/batch-sekkei-maker

---

*本ツールはCOBOLの設計書作成を補助するものです。出力結果は必ず目視で確認してください。*
