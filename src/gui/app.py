"""
バッチ設計書メーカー - メインGUI
"""
import tkinter as tk
from tkinter import filedialog, messagebox
import threading
import os

try:
    import ttkbootstrap as ttk
    from ttkbootstrap.constants import *
    USE_BOOTSTRAP = True
except ImportError:
    import tkinter.ttk as ttk
    USE_BOOTSTRAP = False

from src.parser.cobol_parser import CobolParser
from src.generator.excel_generator import generate_excel


class App:
    def __init__(self):
        if USE_BOOTSTRAP:
            self.root = ttk.Window(themename="cosmo")
        else:
            self.root = tk.Tk()

        self.root.title("バッチ設計書メーカー v1.0")
        self.root.geometry("680x420")
        self.root.resizable(False, False)

        self._selected_file = tk.StringVar()
        self._output_dir = tk.StringVar()
        self._encoding = tk.StringVar(value="shift_jis")
        self._status = tk.StringVar(value="COBOLソースファイルを選択してください")

        self._build_ui()

    def _build_ui(self):
        """UI部品を組み立てる"""
        frame = ttk.Frame(self.root, padding=20)
        frame.pack(fill="both", expand=True)

        # タイトル
        ttk.Label(
            frame,
            text="バッチ設計書メーカー",
            font=("メイリオ", 16, "bold")
        ).grid(row=0, column=0, columnspan=3, pady=(0, 20))

        # COBOLファイル選択
        ttk.Label(frame, text="COBOLソース：").grid(row=1, column=0, sticky="w", pady=6)
        ttk.Entry(frame, textvariable=self._selected_file, width=45).grid(row=1, column=1, padx=6)
        ttk.Button(frame, text="参照...", command=self._select_cobol_file).grid(row=1, column=2)

        # 出力先フォルダ選択
        ttk.Label(frame, text="出力先フォルダ：").grid(row=2, column=0, sticky="w", pady=6)
        ttk.Entry(frame, textvariable=self._output_dir, width=45).grid(row=2, column=1, padx=6)
        ttk.Button(frame, text="参照...", command=self._select_output_dir).grid(row=2, column=2)

        # 文字コード選択
        ttk.Label(frame, text="文字コード：").grid(row=3, column=0, sticky="w", pady=6)
        enc_frame = ttk.Frame(frame)
        enc_frame.grid(row=3, column=1, sticky="w", padx=6)
        ttk.Radiobutton(enc_frame, text="Shift-JIS", variable=self._encoding, value="shift_jis").pack(side="left")
        ttk.Radiobutton(enc_frame, text="UTF-8", variable=self._encoding, value="utf-8").pack(side="left", padx=20)

        # 区切り線
        ttk.Separator(frame, orient="horizontal").grid(row=4, column=0, columnspan=3, sticky="ew", pady=16)

        # 実行ボタン
        self._run_btn = ttk.Button(
            frame,
            text="▶ 設計書を生成する",
            command=self._run,
            width=30,
            bootstyle="primary" if USE_BOOTSTRAP else None
        )
        self._run_btn.grid(row=5, column=0, columnspan=3, pady=6)

        # プログレスバー
        self._progress = ttk.Progressbar(
            frame, mode="indeterminate", length=400,
            bootstyle="info" if USE_BOOTSTRAP else None
        )
        self._progress.grid(row=6, column=0, columnspan=3, pady=8)

        # ステータス表示
        ttk.Label(
            frame,
            textvariable=self._status,
            foreground="#555"
        ).grid(row=7, column=0, columnspan=3)

        # 注意書き
        ttk.Label(
            frame,
            text="※ 本ツールは完全オフラインで動作します。ソースコードは外部に送信されません。",
            font=("メイリオ", 8),
            foreground="#999"
        ).grid(row=8, column=0, columnspan=3, pady=(16, 0))

    def _select_cobol_file(self):
        path = filedialog.askopenfilename(
            title="COBOLソースファイルを選択",
            filetypes=[("COBOLファイル", "*.cbl *.cob *.txt"), ("すべてのファイル", "*.*")]
        )
        if path:
            self._selected_file.set(path)
            # 出力先が未設定なら同じフォルダをデフォルトに
            if not self._output_dir.get():
                self._output_dir.set(os.path.dirname(path))

    def _select_output_dir(self):
        path = filedialog.askdirectory(title="出力先フォルダを選択")
        if path:
            self._output_dir.set(path)

    def _run(self):
        src = self._selected_file.get().strip()
        out_dir = self._output_dir.get().strip()

        if not src:
            messagebox.showwarning("入力エラー", "COBOLソースファイルを選択してください。")
            return
        if not os.path.isfile(src):
            messagebox.showerror("エラー", "指定されたファイルが存在しません。")
            return
        if not out_dir:
            messagebox.showwarning("入力エラー", "出力先フォルダを選択してください。")
            return

        self._run_btn.config(state="disabled")
        self._progress.start(10)
        self._status.set("解析中...")

        # 別スレッドで実行（GUIがフリーズしないように）
        thread = threading.Thread(target=self._execute, args=(src, out_dir), daemon=True)
        thread.start()

    def _execute(self, src: str, out_dir: str):
        try:
            parser = CobolParser()
            result = parser.parse_file(src, encoding=self._encoding.get())

            base_name = os.path.splitext(os.path.basename(src))[0]
            output_path = os.path.join(out_dir, f"{base_name}_設計書.xlsx")

            generate_excel(result, output_path)

            self.root.after(0, self._on_success, output_path, result.errors)
        except Exception as e:
            self.root.after(0, self._on_error, str(e))

    def _on_success(self, output_path: str, errors: list):
        self._progress.stop()
        self._run_btn.config(state="normal")
        self._status.set(f"✅ 生成完了：{output_path}")

        msg = f"設計書を生成しました。\n\n{output_path}"
        if errors:
            msg += f"\n\n⚠ 解析中に {len(errors)} 件の警告がありました。\nログファイルを確認してください。"
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
