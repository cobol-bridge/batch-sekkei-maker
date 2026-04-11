"""
COBOLソースコードのパーサー
"""
import re
from dataclasses import dataclass, field

_PIC_CHARS = "X9AZPB"
_PIC_REPEAT = re.compile(rf"[{_PIC_CHARS}]\((\d+)\)")


@dataclass
class FileDefinition:
    """ファイル定義（FD句から抽出）"""
    file_name: str = ""        # ファイル名（SELECT句）
    fd_name: str = ""          # FD名
    record_length: str = ""    # レコード長
    assign_to: str = ""        # 物理ファイル名（ASSIGN TO）
    organization: str = ""     # ファイル編成（SEQUENTIAL/INDEXED/RELATIVE）
    access_mode: str = ""      # アクセスモード（SEQUENTIAL/RANDOM/DYNAMIC）
    record_key: str = ""       # レコードキー（INDEXEDのみ）
    io_mode: str = ""          # I/O区分（INPUT/OUTPUT/I-O/EXTEND）
    fields: list = field(default_factory=list)  # フィールド一覧


@dataclass
class FieldItem:
    """レコードのフィールド定義（PIC句から抽出）"""
    name: str = ""       # フィールド名
    pic: str = ""        # PIC句
    byte_len: int = 0    # バイト数（計算値）
    start_pos: int = 0   # 開始位置（1始まり）


@dataclass
class PerformEntry:
    """処理フローのエントリ（PERFORM呼び出し）"""
    caller: str = ""           # 呼び出し元の段落名
    callee: str = ""           # 呼び出し先の段落名
    perform_type: str = ""     # PERFORM / PERFORM UNTIL 等


@dataclass
class ExceptionEntry:
    """例外処理のエントリ"""
    location: str = ""         # 発生箇所（段落名）
    exception_type: str = ""   # INVALID KEY / AT END / ON SIZE ERROR 等
    handling: str = ""         # 処理内容


@dataclass
class CobolParseResult:
    """パース結果をまとめたクラス"""
    source_file: str = ""
    file_definitions: list = field(default_factory=list)
    perform_entries: list = field(default_factory=list)
    exception_entries: list = field(default_factory=list)
    errors: list = field(default_factory=list)


class CobolParser:
    """
    COBOLソースコードを解析して設計書情報を抽出するクラス
    対応方言：IBM Enterprise COBOL（固定形式）
    """

    def __init__(self):
        self.result = CobolParseResult()

    def parse_file(self, file_path: str, encoding: str = "shift_jis") -> CobolParseResult:
        """
        COBOLソースファイルを読み込んでパースする

        Args:
            file_path: COBOLソースファイルのパス
            encoding: 文字コード（デフォルト：shift_jis）

        Returns:
            CobolParseResult: パース結果
        """
        self.result = CobolParseResult(source_file=file_path)

        try:
            with open(file_path, encoding=encoding, errors="replace") as f:
                lines = f.readlines()
        except FileNotFoundError:
            self.result.errors.append(f"ファイルが見つかりません: {file_path}")
            return self.result
        except Exception as e:
            self.result.errors.append(f"ファイル読み込みエラー: {e}")
            return self.result

        # コメント行・連番列を除去して本文のみ抽出
        clean_lines = self._clean_lines(lines)

        # 各セクションを解析
        self._parse_select_clauses(clean_lines)
        self._parse_fd_clauses(clean_lines)
        self._parse_field_definitions(clean_lines)
        self._parse_open_statements(clean_lines)
        self._parse_perform_statements(clean_lines)
        self._parse_exception_handlers(clean_lines)

        return self.result

    def _clean_lines(self, lines: list) -> list:
        """
        固定形式COBOLのコメント行・連番を除去して本文を返す
        列7がアスタリスク(*) or スラッシュ(/) の行はコメント行
        """
        clean = []
        for line in lines:
            # 固定形式：1-6列が連番、7列が標識、8-72列が本文
            if len(line) < 7:
                clean.append(line.rstrip())
                continue
            indicator = line[6] if len(line) > 6 else " "
            if indicator in ("*", "/"):
                continue  # コメント行をスキップ
            # 本文部分（7列目以降、72列まで）を取得
            content = line[6:72].rstrip() if len(line) > 6 else ""
            if content:
                clean.append(content)
        return clean

    @staticmethod
    def _join(lines: list) -> str:
        """行リストをスペース区切りで結合して大文字化（パーサー共通）"""
        return " ".join(lines).upper()

    def _parse_select_clauses(self, lines: list):
        """SELECT句からファイル情報を抽出（複数行対応）"""
        full_text = self._join(lines)

        # SELECT句ブロックを取得（次のSELECTまたはFD句まで）
        # ※ピリオド区切りはしない（ASSIGN TO 'FILE.DAT' のピリオドと混同するため）
        select_block_pattern = r"(SELECT\s+\S+.*?)(?=SELECT\s|\bFD\b|\Z)"
        for block_match in re.finditer(select_block_pattern, full_text, re.DOTALL):
            block = block_match.group(1)

            name_match = re.search(r"SELECT\s+(\S+)", block)
            if not name_match:
                continue
            fd = FileDefinition(file_name=name_match.group(1))

            assign_match = re.search(r"ASSIGN\s+TO\s+['\"]?(\S+?)['\"]?(?:\s|$)", block)
            if assign_match:
                fd.assign_to = assign_match.group(1).strip("'\".,")

            org_match = re.search(r"ORGANIZATION\s+IS\s+(\S+)", block)
            if org_match:
                fd.organization = org_match.group(1).rstrip(".")

            access_match = re.search(r"ACCESS\s+MODE\s+IS\s+(\S+)", block)
            if access_match:
                fd.access_mode = access_match.group(1).rstrip(".")

            key_match = re.search(r"RECORD\s+KEY\s+IS\s+(\S+)", block)
            if key_match:
                fd.record_key = key_match.group(1).rstrip(".")

            self.result.file_definitions.append(fd)

    def _parse_fd_clauses(self, lines: list):
        """FD句からレコード長を抽出してfile_definitionsに補完"""
        full_text = self._join(lines)
        # FD ファイル名 RECORDING MODE ... RECORD CONTAINS XX CHARACTERS
        pattern = r"FD\s+(\S+).*?RECORD\s+CONTAINS\s+(\d+)"
        for match in re.finditer(pattern, full_text):
            fd_name = match.group(1)
            record_len = match.group(2)
            # 既存のfile_definitionsと照合してfd_nameとレコード長を補完
            for fd in self.result.file_definitions:
                if fd.file_name == fd_name or fd.fd_name == fd_name:
                    fd.fd_name = fd_name
                    fd.record_length = record_len
                    break
            else:
                # SELECT句で見つからなかった場合は新規追加
                self.result.file_definitions.append(
                    FileDefinition(fd_name=fd_name, record_length=record_len)
                )

    def _parse_field_definitions(self, lines: list):
        """FILE SECTIONのFD配下フィールド（05レベル）を抽出してfile_definitionsに補完"""
        full_text = "\n".join(lines).upper()
        # FD名 〜 次のFDまたはWORKING-STORAGEまでのブロックを取得
        fd_block_pattern = re.compile(
            r"FD\s+([\w\-]+).*?(?=\nFD\s|\nWORKING-STORAGE|\Z)",
            re.IGNORECASE | re.DOTALL
        )
        pic_pattern = re.compile(
            r"^\s*05\s+([\w\-]+)\s+PIC\s+([\w\(\)V9XSZBPb/,\.\+\-\*]+)",
            re.IGNORECASE | re.MULTILINE
        )

        for fd_match in fd_block_pattern.finditer(full_text):
            fd_name = fd_match.group(1).upper()
            block = fd_match.group(0)

            fields = []
            pos = 1
            for f_match in pic_pattern.finditer(block):
                fname = f_match.group(1).upper()
                pic = f_match.group(2).upper()
                blen = self._calc_pic_bytes(pic)
                fields.append(FieldItem(name=fname, pic=pic, byte_len=blen, start_pos=pos))
                pos += blen

            # 対応するfile_definitionに補完
            for fd in self.result.file_definitions:
                if fd.file_name == fd_name or fd.fd_name == fd_name:
                    fd.fields = fields
                    break

    @staticmethod
    def _calc_pic_bytes(pic: str) -> int:
        """PIC句の文字列からバイト数を計算する"""
        pic = re.sub(r'V[\w\(\)]*', '', pic.upper()).replace('S', '')
        total = sum(int(m.group(1)) for m in _PIC_REPEAT.finditer(pic))
        remaining = _PIC_REPEAT.sub('', pic)
        total += sum(1 for c in remaining if c in _PIC_CHARS)
        return total or 1

    def _parse_open_statements(self, lines: list):
        """OPEN文からI/O区分を抽出してfile_definitionsに補完"""
        full_text = self._join(lines)
        # OPEN INPUT/OUTPUT/I-O/EXTEND ファイル名1 ファイル名2 ...
        # 次のOPENまたは文末まで
        open_pattern = re.compile(
            r"OPEN\s+(INPUT|OUTPUT|I-O|EXTEND)\s+((?:[\w\-]+\s*)+?)(?=OPEN\s|CLOSE\s|PERFORM\s|MOVE\s|READ\s|WRITE\s|IF\s|STOP\s|\Z)",
            re.DOTALL
        )
        for match in open_pattern.finditer(full_text):
            mode = match.group(1)
            names_block = match.group(2)
            file_names = re.findall(r"[\w\-]+", names_block)
            for name in file_names:
                for fd in self.result.file_definitions:
                    if fd.file_name == name or fd.fd_name == name:
                        if not fd.io_mode:
                            fd.io_mode = mode
                        break

    def _parse_perform_statements(self, lines: list):
        """PERFORM文から呼び出し階層を抽出（THRU対応）"""
        current_paragraph = ""
        perform_pattern = re.compile(
            r"PERFORM\s+([\w\-]+)(?:\s+THRU\s+([\w\-]+))?(\s+UNTIL|\s+VARYING|\s+TIMES)?",
            re.IGNORECASE
        )
        paragraph_pattern = re.compile(r"^([\w\-]+)\.$", re.IGNORECASE)

        for line in lines:
            stripped = line.strip().upper()

            para_match = paragraph_pattern.match(stripped)
            if para_match:
                current_paragraph = para_match.group(1)
                continue

            for match in perform_pattern.finditer(stripped):
                callee = match.group(1)
                thru = match.group(2)
                modifier = match.group(3)
                if modifier:
                    perform_type = modifier.strip()
                elif thru:
                    perform_type = f"THRU {thru}"
                else:
                    perform_type = "PERFORM"
                entry = PerformEntry(
                    caller=current_paragraph,
                    callee=callee,
                    perform_type=perform_type
                )
                self.result.perform_entries.append(entry)

    def _parse_exception_handlers(self, lines: list):
        """例外処理句を抽出"""
        current_paragraph = ""
        # NOT系を先に並べる（"AT END"が"NOT AT END"にマッチしないよう順序が重要）
        exception_keywords = [
            "NOT INVALID KEY",
            "NOT AT END",
            "NOT ON SIZE ERROR",
            "INVALID KEY",
            "AT END",
            "ON SIZE ERROR",
            "ON OVERFLOW",
        ]
        paragraph_pattern = re.compile(r"^([\w\-]+)\.$", re.IGNORECASE)

        for i, line in enumerate(lines):
            stripped = line.strip().upper()

            para_match = paragraph_pattern.match(stripped)
            if para_match:
                current_paragraph = para_match.group(1)
                continue

            for keyword in exception_keywords:
                if keyword in stripped:
                    # 次の行から処理内容を取得（簡易）
                    handling = lines[i + 1].strip() if i + 1 < len(lines) else ""
                    entry = ExceptionEntry(
                        location=current_paragraph,
                        exception_type=keyword,
                        handling=handling[:50]  # 長すぎる場合は切り詰め
                    )
                    self.result.exception_entries.append(entry)
                    break
