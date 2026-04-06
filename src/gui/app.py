"""
バッチ設計書メーカー - メインGUI
"""
import tkinter as tk
from tkinter import filedialog, messagebox
import threading
import os
import logging
from datetime import datetime

try:
    import ttkbootstrap as ttk
    from ttkbootstrap.constants import *
    USE_BOOTSTRAP = True
except ImportError:
    import tkinter.ttk as ttk
    USE_BOOTSTRAP = False

from src.parser.cobol_parser import CobolParser
from src.generator.excel_generator import generate_excel
from src.generator.word_generator import generate_word


class App:
    def __init__(self):
        if USE_BOOTSTRAP:
            self.root = ttk.Window(themename="cosmo")
        else:
            self.root = tk.Tk()

        self.root.title("バッチ設計書メーカー v1.1")
        self.root.geometry("680x480")
        self.root.resizable(False, False)

        self._selected_file = tk.StringVar()
        self._selected_folder = tk.StringVar()
        self._output_dir = tk.StringVar()
        self._encoding = tk.StringVar(value="shift_jis")
        self._output_format = tk.StringVar(value="excel")
        self._status = tk.StringVar(value="COBOLソースファイルを選択してください")

        self._build_ui()

    def _build_ui(self):
        frame = ttk.Frame(self.root, padding=20)
        frame.pack(fill="both", expand=True)

        # タイトル
        ttk.Label(
            frame,
            text="バッチ設計書メーカー",
            font=("メイリオ", 16, "bold")
        ).grid(row=0, column=0, columnspan=3, pady=(0, 12))

        # タブ（単一ファイル / フォルダ一括）
        self._notebook = ttk.Notebook(frame)
        self._notebook.grid(row=1, column=0, columnspan=3, sticky="ew", pady=(0, 8))

        tab_single = ttk.Frame(self._notebook, padding=10)
        tab_batch = ttk.Frame(self._notebook, padding=10)
        self._notebook.add(tab_single, text="  単一ファイル  ")
        self._notebook.add(tab_batch, text="  フォルダ一括  ")

        # --- 単一ファイルタブ ---
        ttk.Label(tab_single, text="COBOLソース：").grid(row=0, column=0, sticky="w", pady=4)
        ttk.Entry(tab_single, textvariable=self._selected_file, width=42).grid(row=0, column=1, padx=6)
        ttk.Button(tab_single, text="参照...", command=self._select_cobol_file).grid(row=0, column=2)

        # --- フォルダ一括タブ ---
        ttk.Label(tab_batch, text="COBOLフォルダ：").grid(row=0, column=0, sticky="w", pady=4)
        ttk.Entry(tab_batch, textvariable=self._selected_folder, width=42).grid(row=0, column=1, padx=6)
        ttk.Button(tab_batch, text="参照...", command=self._select_cobol_folder).grid(row=0, column=2)
        ttk.Label(tab_batch, text="※ フォルダ内の .cbl / .cob ファイルを一括処理します",
                  font=("メイリオ", 8), foreground="#888").grid(
            row=1, column=0, columnspan=3, sticky="w", pady=(2, 0))

        # 出力先フォルダ
        ttk.Label(frame, text="出力先フォルダ：").grid(row=2, column=0, sticky="w", pady=6)
        ttk.Entry(frame, textvariable=self._output_dir, width=45).grid(row=2, column=1, padx=6)
        ttk.Button(frame, text="参照...", command=self._select_output_dir).grid(row=2, column=2)

        # 文字コード
        ttk.Label(frame, text="文字コード：").grid(row=3, column=0, sticky="w", pady=6)
        enc_frame = ttk.Frame(frame)
        enc_frame.grid(row=3, column=1, sticky="w", padx=6)
        ttk.Radiobutton(enc_frame, text="Shift-JIS", variable=self._encoding, value="shift_jis").pack(side="left")
        ttk.Radiobutton(enc_frame, text="UTF-8", variable=self._encoding, value="utf-8").pack(side="left", padx=20)

        # 出力形式
        ttk.Label(frame, text="出力形式：").grid(row=4, column=0, sticky="w", pady=6)
        fmt_frame = ttk.Frame(frame)
        fmt_frame.grid(row=4, column=1, sticky="w", padx=6)
        ttk.Radiobutton(fmt_frame, text="Excel (.xlsx)", variable=self._output_format, value="excel").pack(side="left")
        ttk.Radiobutton(fmt_frame, text="Word (.docx)", variable=self._output_format, value="word").pack(side="left", padx=20)

        # 区切り線
        ttk.Separator(frame, orient="horizontal").grid(row=5, column=0, columnspan=3, sticky="ew", pady=12)

        # 実行ボタン
        self._run_btn = ttk.Button(
            frame,
            text="▶ 設計書を生成する",
            command=self._run,
            width=30,
            bootstyle="primary" if USE_BOOTSTRAP else None
        )
        self._run_btn.grid(row=6, column=0, columnspan=3, pady=6)

        # プログレスバー
        self._progress = ttk.Progressbar(
            frame, mode="indeterminate", length=400,
            bootstyle="info" if USE_BOOTSTRAP else None
        )
        self._progress.grid(row=7, column=0, columnspan=3, pady=6)

        # ステータス
        ttk.Label(frame, textvariable=self._status, foreground="#555").grid(
            row=8, column=0, columnspan=3)

        # 注意書き
        ttk.Label(
            frame,
            text="※ 本ツールは完全オフラインで動作します。ソースコードは外部に送信されません。",
            font=("メイリオ", 8), foreground="#999"
        ).grid(row=9, column=0, columnspan=3, pady=(12, 0))

    def _select_cobol_file(self):
        path = filedialog.askopenfilename(
            title="COBOLソースファイルを選択",
            filetypes=[("COBOLファイル", "*.cbl *.cob *.txt"), ("すべてのファイル", "*.*")]
        )
        if path:
            self._selected_file.set(path)
            if not self._output_dir.get():
                self._output_dir.set(os.path.dirname(path))

    def _select_cobol_folder(self):
        path = filedialog.askdirectory(title="COBOLソースフォルダを選択")
        if path:
            self._selected_folder.set(path)
            if not self._output_dir.get():
                self._output_dir.set(path)

    def _select_output_dir(self):
        path = filedialog.askdirectory(title="出力先フォルダを選択")
        if path:
            self._output_dir.set(path)

    def _run(self):
        out_dir = self._output_dir.get().strip()
        if not out_dir:
            messagebox.showwarning("入力エラー", "出力先フォルダを選択してください。")
            return

        tab = self._notebook.index(self._notebook.select())

        if tab == 0:
            # 単一ファイルモード
            src = self._selected_file.get().strip()
            if not src:
                messagebox.showwarning("入力エラー", "COBOLソースファイルを選択してください。")
                return
            if not os.path.isfile(src):
                messagebox.showerror("エラー", "指定されたファイルが存在しません。")
                return
            files = [src]
        else:
            # フォルダ一括モード
            folder = self._selected_folder.get().strip()
            if not folder:
                messagebox.showwarning("入力エラー", "COBOLソースフォルダを選択してください。")
                return
            if not os.path.isdir(folder):
                messagebox.showerror("エラー", "指定されたフォルダが存在しません。")
                return
            files = [
                os.path.join(folder, f)
                for f in os.listdir(folder)
                if f.lower().endswith((".cbl", ".cob"))
            ]
            if not files:
                messagebox.showwarning("対象なし", "フォルダ内に .cbl / .cob ファイルが見つかりませんでした。")
                return

        self._run_btn.config(state="disabled")
        self._progress.start(10)
        self._status.set(f"解析中... (0/{len(files)})")

        thread = threading.Thread(target=self._execute_batch, args=(files, out_dir), daemon=True)
        thread.start()

    def _setup_logger(self, log_path: str) -> logging.Logger:
        logger = logging.getLogger("batch_sekkei_maker")
        logger.setLevel(logging.DEBUG)
        logger.handlers.clear()
        fh = logging.FileHandler(log_path, encoding="utf-8")
        fh.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
        logger.addHandler(fh)
        return logger

    def _execute_batch(self, files: list, out_dir: str):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_path = os.path.join(out_dir, f"batch_{timestamp}.log")
        logger = self._setup_logger(log_path)
        logger.info(f"一括処理開始: {len(files)}件")

        results = []
        errors_total = []

        for i, src in enumerate(files, start=1):
            self.root.after(0, self._status.set, f"解析中... ({i}/{len(files)}) {os.path.basename(src)}")
            try:
                base_name = os.path.splitext(os.path.basename(src))[0]
                logger.info(f"[{i}/{len(files)}] 解析開始: {src}")

                parser = CobolParser()
                result = parser.parse_file(src, encoding=self._encoding.get())

                for err in result.errors:
                    logger.error(f"{base_name}: {err}")
                    errors_total.append(err)

                fmt = self._output_format.get()
                if fmt == "word":
                    output_path = os.path.join(out_dir, f"{base_name}_設計書.docx")
                    generate_word(result, output_path)
                else:
                    output_path = os.path.join(out_dir, f"{base_name}_設計書.xlsx")
                    generate_excel(result, output_path)

                logger.info(f"出力完了: {output_path}")
                results.append(output_path)

            except Exception as e:
                logger.exception(f"{os.path.basename(src)}: 処理失敗")
                errors_total.append(f"{os.path.basename(src)}: {e}")

        self.root.after(0, self._on_batch_success, results, errors_total, log_path)

    def _on_batch_success(self, results: list, errors: list, log_path: str):
        self._progress.stop()
        self._run_btn.config(state="normal")
        self._status.set(f"✅ 完了：{len(results)}件生成")

        msg = f"{len(results)}件の設計書を生成しました。"
        if errors:
            msg += f"\n\n⚠ {len(errors)}件の警告/エラーがありました。"
        msg += f"\n\nログ：{log_path}"
        messagebox.showinfo("完了", msg)

    def _on_error(self, error_msg: str):
        self._progress.stop()
        self._run_btn.config(state="normal")
        self._status.set("❌ エラーが発生しました")
        messagebox.showerror("エラー", f"設計書の生成に失敗しました。\n\n{error_msg}")

    def run(self):
        self.root.mainloop()


def main():
    app = App()
    app.run()


if __name__ == "__main__":
    main()
