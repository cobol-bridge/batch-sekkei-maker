      *=================================================================
      * SAMPLE09: 日次集計バッチ
      * 概要: 当日の売上トランザクションを読み込み、部門別・商品別に
      *       集計して日次集計マスタを更新し、集計レポートを出力する
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAMPLE09.
       AUTHOR. BATCH-SYSTEM.
       DATE-WRITTEN. 2026-04-04.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT URIAGE-FILE ASSIGN TO URIAGIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-URIAGE-STATUS.
           SELECT NISYU-MASTER ASSIGN TO NISYUMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS NM-BUMON-CD
               FILE STATUS IS WS-NISYU-STATUS.
           SELECT REPORT-FILE ASSIGN TO REPORTOUT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-REPORT-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  URIAGE-FILE
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  URIAGE-REC.
           05  UR-DENPYO-NO      PIC X(10).
           05  UR-BUMON-CD       PIC X(04).
           05  UR-SHOHIN-CD      PIC X(10).
           05  UR-SURYO          PIC 9(07).
           05  UR-TANKA          PIC 9(08).
           05  UR-KINGAKU        PIC 9(11).
           05  UR-HIDUKE         PIC 9(08).
           05  FILLER            PIC X(22).

       FD  NISYU-MASTER
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  NISYU-REC.
           05  NM-BUMON-CD       PIC X(04).
           05  NM-BUMON-MEI      PIC X(20).
           05  NM-URIAGE-SU      PIC S9(09) COMP-3.
           05  NM-URIAGE-KINGAKU PIC S9(13) COMP-3.
           05  NM-KOSHIN-DT      PIC 9(08).
           05  FILLER            PIC X(35).

       FD  REPORT-FILE
           RECORD CONTAINS 100 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  REPORT-REC.
           05  RP-LINE           PIC X(100).

       WORKING-STORAGE SECTION.
       01  WS-FLAGS.
           05  WS-URIAGE-STATUS  PIC X(02).
           05  WS-NISYU-STATUS   PIC X(02).
           05  WS-REPORT-STATUS  PIC X(02).
           05  WS-EOF-FLAG       PIC X(01) VALUE 'N'.

       01  WS-PREV-BUMON        PIC X(04) VALUE SPACES.
       01  WS-TODAY             PIC 9(08) VALUE ZEROS.

       01  WS-SUBTOTAL.
           05  WS-SUB-SU         PIC S9(11) COMP-3.
           05  WS-SUB-KINGAKU    PIC S9(15) COMP-3.

       01  WS-TOTAL.
           05  WS-TOT-SU         PIC S9(13) COMP-3.
           05  WS-TOT-KINGAKU    PIC S9(17) COMP-3.

       01  WS-WORK-LINE          PIC X(100).

       01  WS-COUNTERS.
           05  WS-INPUT-CNT      PIC 9(07) VALUE ZEROS.
           05  WS-OUTPUT-CNT     PIC 9(07) VALUE ZEROS.
           05  WS-ERR-CNT        PIC 9(07) VALUE ZEROS.

       01  WS-EDIT-AREA.
           05  WS-EDIT-SU        PIC ZZZ,ZZZ,ZZ9.
           05  WS-EDIT-KINGAKU   PIC ZZZ,ZZZ,ZZZ,ZZ9.

       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-TODAY
           PERFORM 1000-OPEN-FILES
           PERFORM 9000-HEADER-WRITE
           PERFORM 2000-MAIN-LOOP
               UNTIL WS-EOF-FLAG = 'Y'
           PERFORM 2900-BUMON-BREAK
           PERFORM 2950-TOTAL-WRITE
           PERFORM 3000-CLOSE-FILES
           STOP RUN.

       1000-OPEN-FILES.
           OPEN INPUT  URIAGE-FILE
           OPEN I-O    NISYU-MASTER
           OPEN OUTPUT REPORT-FILE
           PERFORM 1100-READ-URIAGE.

       1100-READ-URIAGE.
           READ URIAGE-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-MAIN-LOOP.
           ADD 1 TO WS-INPUT-CNT
           IF WS-PREV-BUMON NOT = UR-BUMON-CD
               IF WS-PREV-BUMON NOT = SPACES
                   PERFORM 2900-BUMON-BREAK
               END-IF
               MOVE UR-BUMON-CD TO WS-PREV-BUMON
               MOVE ZEROS TO WS-SUB-SU WS-SUB-KINGAKU
           END-IF
           ADD UR-SURYO    TO WS-SUB-SU
           ADD UR-KINGAKU  TO WS-SUB-KINGAKU
           ADD UR-SURYO    TO WS-TOT-SU
           ADD UR-KINGAKU  TO WS-TOT-KINGAKU
           PERFORM 1100-READ-URIAGE.

       2900-BUMON-BREAK.
           MOVE WS-PREV-BUMON TO NM-BUMON-CD
           READ NISYU-MASTER
               INVALID KEY
                   ADD 1 TO WS-ERR-CNT
               NOT INVALID KEY
                   ADD WS-SUB-SU      TO NM-URIAGE-SU
                   ADD WS-SUB-KINGAKU TO NM-URIAGE-KINGAKU
                   MOVE WS-TODAY      TO NM-KOSHIN-DT
                   REWRITE NISYU-REC
           END-READ
           PERFORM 2910-DETAIL-WRITE.

       2910-DETAIL-WRITE.
           MOVE WS-SUB-SU      TO WS-EDIT-SU
           MOVE WS-SUB-KINGAKU TO WS-EDIT-KINGAKU
           STRING '部門:' DELIMITED SIZE
                  WS-PREV-BUMON DELIMITED SIZE
                  '  件数:' DELIMITED SIZE
                  WS-EDIT-SU DELIMITED SIZE
                  '  金額:' DELIMITED SIZE
                  WS-EDIT-KINGAKU DELIMITED SIZE
               INTO WS-WORK-LINE
           MOVE WS-WORK-LINE TO RP-LINE
           WRITE REPORT-REC
           ADD 1 TO WS-OUTPUT-CNT.

       2950-TOTAL-WRITE.
           MOVE WS-TOT-SU      TO WS-EDIT-SU
           MOVE WS-TOT-KINGAKU TO WS-EDIT-KINGAKU
           STRING '合計        件数:' DELIMITED SIZE
                  WS-EDIT-SU DELIMITED SIZE
                  '  金額:' DELIMITED SIZE
                  WS-EDIT-KINGAKU DELIMITED SIZE
               INTO WS-WORK-LINE
           MOVE WS-WORK-LINE TO RP-LINE
           WRITE REPORT-REC.

       3000-CLOSE-FILES.
           CLOSE URIAGE-FILE
           CLOSE NISYU-MASTER
           CLOSE REPORT-FILE.

       9000-HEADER-WRITE.
           MOVE '======= 日次売上集計レポート =======' TO RP-LINE
           WRITE REPORT-REC.
