"""
Excelファイルの設計書生成
"""
from datetime import datetime
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter


# ヘッダー行の背景色（紺）
HEADER_FILL = PatternFill(start_color="1F4E79", end_color="1F4E79", fill_type="solid")
HEADER_FONT = Font(color="FFFFFF", bold=True, name="メイリオ", size=10)
BODY_FONT = Font(name="メイリオ", size=10)
SUBHEADER_FILL = PatternFill(start_color="BDD7EE", end_color="BDD7EE", fill_type="solid")
SUBHEADER_FONT = Font(bold=True, name="メイリオ", size=10)

thin_border = Border(
    left=Side(style="thin"),
    right=Side(style="thin"),
    top=Side(style="thin"),
    bottom=Side(style="thin"),
)


def _apply_header(cell, value: str):
    cell.value = value
    cell.font = HEADER_FONT
    cell.fill = HEADER_FILL
    cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
    cell.border = thin_border


def _apply_body(cell, value):
    cell.value = value
    cell.font = BODY_FONT
    cell.alignment = Alignment(vertical="center", wrap_text=True)
    cell.border = thin_border


def generate_excel(parse_result, output_path: str):
    """
    パース結果からExcel設計書を生成する

    Args:
        parse_result: CobolParseResult
        output_path: 出力先ファイルパス
    """
    wb = openpyxl.Workbook()

    _create_cover_sheet(wb, parse_result)
    _create_io_sheet(wb, parse_result)
    _create_flow_sheet(wb, parse_result)
    _create_exception_sheet(wb, parse_result)

    # デフォルトシートを削除
    if "Sheet" in wb.sheetnames:
        del wb["Sheet"]

    wb.save(output_path)


def _create_cover_sheet(wb, parse_result):
    """シート1：表紙"""
    ws = wb.create_sheet("表紙", 0)
    ws.column_dimensions["A"].width = 25
    ws.column_dimensions["B"].width = 50

    title_font = Font(name="メイリオ", size=18, bold=True, color="1F4E79")
    ws["B2"].value = "バッチ処理 業務設計書"
    ws["B2"].font = title_font

    rows = [
        ("対象ファイル", parse_result.source_file),
        ("生成日時", datetime.now().strftime("%Y年%m月%d日 %H:%M")),
        ("ツールバージョン", "v1.0.0"),
        ("備考", "本設計書はバッチ設計書メーカーにより自動生成されました。\n内容は必ず目視で確認してください。"),
    ]

    for i, (label, value) in enumerate(rows, start=4):
        label_cell = ws.cell(row=i, column=1, value=label)
        label_cell.font = SUBHEADER_FONT
        label_cell.fill = SUBHEADER_FILL
        label_cell.border = thin_border
        label_cell.alignment = Alignment(vertical="center")

        value_cell = ws.cell(row=i, column=2, value=value)
        value_cell.font = BODY_FONT
        value_cell.border = thin_border
        value_cell.alignment = Alignment(vertical="center", wrap_text=True)

    ws.row_dimensions[7].height = 40


def _create_io_sheet(wb, parse_result):
    """シート2：I/O定義一覧"""
    ws = wb.create_sheet("IO定義")
    ws.column_dimensions["A"].width = 5
    ws.column_dimensions["B"].width = 25
    ws.column_dimensions["C"].width = 25
    ws.column_dimensions["D"].width = 15
    ws.column_dimensions["E"].width = 30

    headers = ["No", "ファイル名（SELECT）", "FD名", "レコード長", "備考"]
    for col, h in enumerate(headers, start=1):
        _apply_header(ws.cell(row=1, column=col), h)

    if not parse_result.file_definitions:
        ws.cell(row=2, column=1).value = "（I/O定義が検出されませんでした）"
        return

    for i, fd in enumerate(parse_result.file_definitions, start=1):
        row = i + 1
        _apply_body(ws.cell(row=row, column=1), i)
        _apply_body(ws.cell(row=row, column=2), fd.file_name or "（不明）")
        _apply_body(ws.cell(row=row, column=3), fd.fd_name or "（不明）")
        _apply_body(ws.cell(row=row, column=4), fd.record_length or "（不明）")
        _apply_body(ws.cell(row=row, column=5), "")


def _create_flow_sheet(wb, parse_result):
    """シート3：処理フロー"""
    ws = wb.create_sheet("処理フロー")
    ws.column_dimensions["A"].width = 5
    ws.column_dimensions["B"].width = 30
    ws.column_dimensions["C"].width = 30
    ws.column_dimensions["D"].width = 20
    ws.column_dimensions["E"].width = 30

    headers = ["No", "呼び出し元（段落名）", "呼び出し先（段落名）", "種別", "備考"]
    for col, h in enumerate(headers, start=1):
        _apply_header(ws.cell(row=1, column=col), h)

    if not parse_result.perform_entries:
        ws.cell(row=2, column=1).value = "（処理フローが検出されませんでした）"
        return

    for i, entry in enumerate(parse_result.perform_entries, start=1):
        row = i + 1
        _apply_body(ws.cell(row=row, column=1), i)
        _apply_body(ws.cell(row=row, column=2), entry.caller or "（不明）")
        _apply_body(ws.cell(row=row, column=3), entry.callee)
        _apply_body(ws.cell(row=row, column=4), entry.perform_type)
        _apply_body(ws.cell(row=row, column=5), "")


def _create_exception_sheet(wb, parse_result):
    """シート4：例外処理一覧"""
    ws = wb.create_sheet("例外処理")
    ws.column_dimensions["A"].width = 5
    ws.column_dimensions["B"].width = 30
    ws.column_dimensions["C"].width = 25
    ws.column_dimensions["D"].width = 40
    ws.column_dimensions["E"].width = 30

    headers = ["No", "発生箇所（段落名）", "例外種別", "処理内容（抜粋）", "備考"]
    for col, h in enumerate(headers, start=1):
        _apply_header(ws.cell(row=1, column=col), h)

    if not parse_result.exception_entries:
        ws.cell(row=2, column=1).value = "（例外処理が検出されませんでした）"
        return

    for i, entry in enumerate(parse_result.exception_entries, start=1):
        row = i + 1
        _apply_body(ws.cell(row=row, column=1), i)
        _apply_body(ws.cell(row=row, column=2), entry.location or "（不明）")
        _apply_body(ws.cell(row=row, column=3), entry.exception_type)
        _apply_body(ws.cell(row=row, column=4), entry.handling)
        _apply_body(ws.cell(row=row, column=5), "")
