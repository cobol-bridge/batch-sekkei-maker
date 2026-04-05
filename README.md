# バッチ設計書メーカー

> COBOLソースコードを読み込むだけで、業務設計書（Excel / Word）を自動生成するWindowsデスクトップアプリです。

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)](https://github.com/cobol-bridge/batch-sekkei-maker/releases)
[![Qiita](https://img.shields.io/badge/Qiita-記事を読む-55C500)](https://qiita.com/cobol_bridge/items/95d012cb0262d2a8c30d)

---

## なぜ作ったのか

金融・保険・公共系システムではCOBOLバッチが現役稼働しています。  
しかし**設計書が存在しない・古い・現物と乖離している**という現場は珍しくありません。

このツールは「ソースを選んでボタンを押すだけ」で設計書を自動生成します。  
**完全オフライン動作**なので、社外秘のソースコードをクラウドに送信しません。

---

## 特徴

| | |
|---|---|
| 🔒 **完全オフライン** | ソースコードは外部に一切送信しません |
| ⚡ **ワンクリック生成** | COBOLファイルを選んでボタンを押すだけ |
| 📊 **Excel / Word 両対応** | 用途に合わせて出力形式を選択可能 |
| 🗂 **4種類の設計書** | 表紙・I/O定義・処理フロー・例外処理 |
| 📝 **ログ自動出力** | 解析結果・警告を .log ファイルに記録 |
| 🖥 **Windows .exe** | Python不要。そのまま実行できます |

---

## 出力される設計書

| シート／セクション | 内容 |
|---|---|
| **表紙** | 対象ファイル名・生成日時・バージョン |
| **I/O定義** | SELECT句・FD名・レコード長・物理ファイル名・編成・アクセスモード・レコードキー |
| **処理フロー** | PERFORM呼び出し階層（THRU・UNTIL・VARYING対応） |
| **例外処理** | INVALID KEY / AT END / ON SIZE ERROR 等の一覧 |

---

## 動作環境

- Windows 10 / 11（64bit）
- インターネット接続不要
- Python不要（.exe版を使う場合）

---

## インストール・使い方

### .exe版（推奨）

1. [Releases](https://github.com/cobol-bridge/batch-sekkei-maker/releases) から `バッチ設計書メーカー.exe` をダウンロード
2. ダブルクリックで起動
3. COBOLソースファイルを選択 → 出力先フォルダを選択 → **「設計書を生成する」**

### 開発者向け

```bash
# 仮想環境を作成
python -m venv venv
venv\Scripts\activate

# ライブラリをインストール
pip install -r requirements.txt

# 起動
python main.py

# テスト実行
pytest tests/ -v

# .exe ビルド
pyinstaller batch_sekkei_maker.spec --distpath dist --workpath build --noconfirm
```

---

## 対応COBOL方言

- IBM Enterprise COBOL（固定形式）
- Shift-JIS / UTF-8 対応

---

## ライセンス

MIT License

---

## 開発ステータス

**v1.0.0** — 機能実装完了、リリース準備中

| 機能 | 状態 |
|---|---|
| COBOLパーサー | ✅ |
| Excel出力 | ✅ |
| Word出力 | ✅ |
| GUIアプリ | ✅ |
| .exeパッケージング | ✅ |
| ログ出力 | ✅ |
| インストーラー | 🔨 開発中 |
