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

FONT_TITLE  = ("メイリオ", 18, "bold")
FONT_STEP   = ("メイリオ", 11, "bold")
FONT_LABEL  = ("メイリオ", 11)
FONT_SMALL  = ("メイリオ",  9)
FONT_STATUS = ("メイリオ", 12)


class App:
    def __init__(self):
        if USE_BOOTSTRAP:
            self.root = ttk.Window(themename="cosmo")
        else:
            self.root = tk.Tk()

        self.root.title("バッチ設計書メーカー v1.1")
        self.root.geometry("740x580")
        self.root.resizable(False, False)

        self._selected_file   = tk.StringVar()
        self._selected_folder = tk.StringVar()
        self._output_dir      = tk.StringVar()
        self._encoding        = tk.StringVar(value="shift_jis")
        self._output_format   = tk.StringVar(value="excel")
        self._status          = tk.StringVar(value="STEP 1 からファイルを選択してください")

        self._build_ui()

    def _build_ui(self):
        outer = ttk.Frame(self.root, padding=24)
        outer.pack(fill="both", expand=True)
        outer.columnconfigure(0, weight=1)

        # ---- タイトル ----
        ttk.Label(outer, text="バッチ設計書メーカー", font=FONT_TITLE).grid(
            row=0, column=0, pady=(0, 4))
        ttk.Label(
            outer,
            text="COBOLソースを選ぶだけで設計書（Excel）を自動生成します",
            font=FONT_SMALL, foreground="#666"
        ).grid(row=1, column=0, pady=(0, 16))

        # ---- STEP 1 ----
        self._build_section(outer, row=2, step="STEP 1", label="COBOLファイルを選んでください")
        step1_inner = ttk.Frame(outer, padding=(16, 0, 0, 0))
        step1_inner.grid(row=3, column=0, sticky="ew", pady=(4, 12))
        step1_inner.columnconfigure(1, weight=1)

        self._notebook = ttk.Notebook(step1_inner)
        self._notebook.grid(row=0, column=0, columnspan=3, sticky="ew")

        tab_single = ttk.Frame(self._notebook, padding=10)
        tab_batch  = ttk.Frame(self._notebook, padding=10)
        tab_single.columnconfigure(1, weight=1)
        tab_batch.columnconfigure(1, weight=1)
        self._notebook.add(tab_single, text="  単一ファイル  ")
        self._notebook.add(tab_batch,  text="  フォルダ一括  ")

        ttk.Label(tab_single, text="COBOLファイル：", font=FONT_LABEL).grid(row=0, column=0, sticky="w", pady=6)
        ttk.Entry(tab_single, textvariable=self._selected_file, font=FONT_LABEL).grid(
            row=0, column=1, sticky="ew", padx=8)
        ttk.Button(tab_single, text="ファイルを選ぶ", command=self._select_cobol_file,
                   bootstyle="secondary-outline" if USE_BOOTSTRAP else None).grid(row=0, column=2)

        ttk.Label(tab_batch, text="COBOLフォルダ：", font=FONT_LABEL).grid(row=0, column=0, sticky="w", pady=6)
        ttk.Entry(tab_batch, textvariable=self._selected_folder, font=FONT_LABEL).grid(
            row=0, column=1, sticky="ew", padx=8)
        ttk.Button(tab_batch, text="フォルダを選ぶ", command=self._select_cobol_folder,
                   bootstyle="secondary-outline" if USE_BOOTSTRAP else None).grid(row=0, column=2)
        ttk.Label(tab_batch, text="※ フォルダ内の .cbl / .cob ファイルをすべて処理します",
                  font=FONT_SMALL, foreground="#888").grid(
            row=1, column=0, columnspan=3, sticky="w", pady=(2, 0))

        # ---- STEP 2 ----
        self._build_section(outer, row=4, step="STEP 2", label="設計書の保存先フォルダを選んでください")
        step2_inner = ttk.Frame(outer, padding=(16, 0, 0, 0))
        step2_inner.grid(row=5, column=0, sticky="ew", pady=(4, 12))
        step2_inner.columnconfigure(1, weight=1)

        ttk.Label(step2_inner, text="保存先フォルダ：", font=FONT_LABEL).grid(row=0, column=0, sticky="w")
        ttk.Entry(step2_inner, textvariable=self._output_dir, font=FONT_LABEL).grid(
            row=0, column=1, sticky="ew", padx=8)
        ttk.Button(step2_inner, text="フォルダを選ぶ", command=self._select_output_dir,
                   bootstyle="secondary-outline" if USE_BOOTSTRAP else None).grid(row=0, column=2)

        # ---- STEP 3 ----
        self._build_section(outer, row=6, step="STEP 3", label="設定を確認してください（通常はそのままでOKです）")
        step3_inner = ttk.Frame(outer, padding=(16, 0, 0, 0))
        step3_inner.grid(row=7, column=0, sticky="ew", pady=(4, 12))

        ttk.Label(step3_inner, text="文字コード：", font=FONT_LABEL).grid(row=0, column=0, sticky="w", padx=(0, 12))
        enc_frame = ttk.Frame(step3_inner)
        enc_frame.grid(row=0, column=1, sticky="w")
        ttk.Radiobutton(enc_frame, text="Shift-JIS",
                        variable=self._encoding, value="shift_jis",
                        bootstyle="primary" if USE_BOOTSTRAP else None).pack(side="left")
        ttk.Radiobutton(enc_frame, text="UTF-8",
                        variable=self._encoding, value="utf-8",
                        bootstyle="primary" if USE_BOOTSTRAP else None).pack(side="left", padx=24)

        ttk.Label(step3_inner, text="出力形式：", font=FONT_LABEL).grid(row=1, column=0, sticky="w", pady=(8, 0), padx=(0, 12))
        fmt_frame = ttk.Frame(step3_inner)
        fmt_frame.grid(row=1, column=1, sticky="w", pady=(8, 0))
        ttk.Radiobutton(fmt_frame, text="Excel (.xlsx)",
                        variable=self._output_format, value="excel",
                        bootstyle="primary" if USE_BOOTSTRAP else None).pack(side="left")
        ttk.Radiobutton(fmt_frame, text="Word (.docx)",
                        variable=self._output_format, value="word",
                        bootstyle="primary" if USE_BOOTSTRAP else None).pack(side="left", padx=24)

        # ---- 区切り ----
        ttk.Separator(outer, orient="horizontal").grid(row=8, column=0, sticky="ew", pady=12)

        # ---- 実行ボタン ----
        self._run_btn = ttk.Button(
            outer,
            text="▶  設計書を生成する",
            command=self._run,
            width=28,
            bootstyle="primary" if USE_BOOTSTRAP else None
        )
        self._run_btn.grid(row=9, column=0, pady=4)

        # ---- プログレスバー（処理中のみ表示）----
        self._progress = ttk.Progressbar(
            outer, mode="indeterminate", length=460,
            bootstyle="success" if USE_BOOTSTRAP else None
        )
        self._progress.grid(row=10, column=0, pady=6)
        self._progress.grid_remove()

        # ---- ステータス ----
        ttk.Label(outer, textvariable=self._status, font=FONT_STATUS, foreground="#333").grid(
            row=11, column=0, pady=(4, 0))

        # ---- セキュリティ表示 ----
        ttk.Label(
            outer,
            text="🔒  完全オフライン動作　｜　ソースコードは外部に送信されません",
            font=FONT_SMALL, foreground="#2e7d32"
        ).grid(row=12, column=0, pady=(12, 0))

    def _build_section(self, parent, row: int, step: str, label: str):
        f = ttk.Frame(parent)
        f.grid(row=row, column=0, sticky="ew")
        ttk.Label(f, text=step, font=FONT_STEP, foreground="#1565c0").pack(side="left", padx=(0, 10))
        ttk.Label(f, text=label, font=FONT_LABEL).pack(side="left")

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
        path = filedialog.askdirectory(title="保存先フォルダを選択")
        if path:
            self._output_dir.set(path)

    def _run(self):
        out_dir = self._output_dir.get().strip()
        if not out_dir:
            messagebox.showwarning("確認", "STEP 2 で保存先フォルダを選択してください。")
            return

        tab = self._notebook.index(self._notebook.select())

        if tab == 0:
            src = self._selected_file.get().strip()
            if not src:
                messagebox.showwarning("確認", "STEP 1 でCOBOLファイルを選択してください。")
                return
            if not os.path.isfile(src):
                messagebox.showerror("エラー", "選択したファイルが見つかりません。\nファイルを確認してください。")
                return
            files = [src]
        else:
            folder = self._selected_folder.get().strip()
            if not folder:
                messagebox.showwarning("確認", "STEP 1 でCOBOLフォルダを選択してください。")
                return
            if not os.path.isdir(folder):
                messagebox.showerror("エラー", "選択したフォルダが見つかりません。\nフォルダを確認してください。")
                return
            files = [
                os.path.join(folder, f)
                for f in os.listdir(folder)
                if f.lower().endswith((".cbl", ".cob"))
            ]
            if not files:
                messagebox.showwarning("対象なし", "フォルダの中に .cbl / .cob ファイルがありませんでした。")
                return

        self._run_btn.config(state="disabled")
        self._progress.grid()
        self._progress.start(10)
        self._status.set(f"処理中です... (0 / {len(files)} 件)")

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
            self.root.after(0, self._status.set,
                            f"処理中です... ({i} / {len(files)} 件）　{os.path.basename(src)}")
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
        self._progress.grid_remove()
        self._run_btn.config(state="normal")
        self._status.set(f"完了！　{len(results)} 件の設計書を生成しました")

        msg = f"{len(results)} 件の設計書を生成しました。\n\n保存先：{os.path.dirname(log_path)}"
        if errors:
            msg += f"\n\n注意：{len(errors)} 件の処理でエラーが発生しました。\nログファイルで詳細を確認できます。"
        messagebox.showinfo("完了", msg)

    def _on_error(self, error_msg: str):
        self._progress.stop()
        self._progress.grid_remove()
        self._run_btn.config(state="normal")
        self._status.set("エラーが発生しました。内容を確認してください。")
        messagebox.showerror("エラー", f"設計書の生成に失敗しました。\n\n{error_msg}")

    def run(self):
        self.root.mainloop()


def main():
    app = App()
    app.run()


if __name__ == "__main__":
    main()
