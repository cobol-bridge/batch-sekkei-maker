      *=================================================================
      * SAMPLE10: エラーレポート出力バッチ
      * 概要: エラーログファイルを読み込み、エラーコードマスタを参照し
      *       エラー詳細レポートと担当者別集計レポートを出力する
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAMPLE10.
       AUTHOR. BATCH-SYSTEM.
       DATE-WRITTEN. 2026-04-04.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ERR-LOG-FILE ASSIGN TO ERRLOGIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-ERRLOG-STATUS.
           SELECT ERRCD-MASTER ASSIGN TO ERRCDMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS EM-ERROR-CD
               FILE STATUS IS WS-ERRCD-STATUS.
           SELECT DETAIL-RPT ASSIGN TO DETAILRPT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-DETAIL-STATUS.
           SELECT SUMMARY-RPT ASSIGN TO SUMMARYRPT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-SUMMARY-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  ERR-LOG-FILE
           RECORD CONTAINS 120 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  ERR-LOG-REC.
           05  EL-PROGRAM-ID     PIC X(08).
           05  EL-TANTOSYA-CD    PIC X(06).
           05  EL-ERROR-CD       PIC X(06).
           05  EL-HASSEI-DT      PIC 9(08).
           05  EL-HASSEI-TM      PIC 9(06).
           05  EL-DATA-KEY       PIC X(20).
           05  EL-ERR-MSG        PIC X(60).
           05  FILLER            PIC X(06).

       FD  ERRCD-MASTER
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  ERRCD-REC.
           05  EM-ERROR-CD       PIC X(06).
           05  EM-ERROR-MEI      PIC X(40).
           05  EM-JUYO-DO        PIC X(01).
               88  EM-CRITICAL   VALUE 'H'.
               88  EM-WARNING    VALUE 'W'.
               88  EM-INFO       VALUE 'I'.
           05  EM-TAISYO         PIC X(30).
           05  FILLER            PIC X(03).

       FD  DETAIL-RPT
           RECORD CONTAINS 132 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  DETAIL-REC.
           05  DR-LINE           PIC X(132).

       FD  SUMMARY-RPT
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  SUMMARY-REC.
           05  SR-LINE           PIC X(80).

       WORKING-STORAGE SECTION.
       01  WS-FLAGS.
           05  WS-ERRLOG-STATUS  PIC X(02).
           05  WS-ERRCD-STATUS   PIC X(02).
           05  WS-DETAIL-STATUS  PIC X(02).
           05  WS-SUMMARY-STATUS PIC X(02).
           05  WS-EOF-FLAG       PIC X(01) VALUE 'N'.

       01  WS-PREV-TANTO         PIC X(06) VALUE SPACES.

       01  WS-COUNTERS.
           05  WS-INPUT-CNT      PIC 9(07) VALUE ZEROS.
           05  WS-CRITICAL-CNT   PIC 9(07) VALUE ZEROS.
           05  WS-WARNING-CNT    PIC 9(07) VALUE ZEROS.
           05  WS-INFO-CNT       PIC 9(07) VALUE ZEROS.
           05  WS-UNKNOWN-CNT    PIC 9(07) VALUE ZEROS.
           05  WS-SUB-ERR-CNT    PIC 9(05) VALUE ZEROS.

       01  WS-EDIT-AREA.
           05  WS-EDIT-CNT       PIC ZZZ,ZZ9.
           05  WS-WORK-LINE      PIC X(132).

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 9000-DETAIL-HEADER
           PERFORM 2000-MAIN-LOOP
               UNTIL WS-EOF-FLAG = 'Y'
           PERFORM 2900-TANTO-BREAK
           PERFORM 9100-SUMMARY-OUTPUT
           PERFORM 3000-CLOSE-FILES
           STOP RUN.

       1000-OPEN-FILES.
           OPEN INPUT  ERR-LOG-FILE
           OPEN INPUT  ERRCD-MASTER
           OPEN OUTPUT DETAIL-RPT
           OPEN OUTPUT SUMMARY-RPT
           PERFORM 1100-READ-ERRLOG.

       1100-READ-ERRLOG.
           READ ERR-LOG-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-MAIN-LOOP.
           ADD 1 TO WS-INPUT-CNT
           IF WS-PREV-TANTO NOT = EL-TANTOSYA-CD
               IF WS-PREV-TANTO NOT = SPACES
                   PERFORM 2900-TANTO-BREAK
               END-IF
               MOVE EL-TANTOSYA-CD TO WS-PREV-TANTO
               MOVE ZEROS          TO WS-SUB-ERR-CNT
           END-IF
           MOVE EL-ERROR-CD TO EM-ERROR-CD
           READ ERRCD-MASTER
               INVALID KEY
                   MOVE '(コード不明)' TO EM-ERROR-MEI
                   MOVE '?' TO EM-JUYO-DO
                   ADD 1 TO WS-UNKNOWN-CNT
               NOT INVALID KEY
                   EVALUATE TRUE
                       WHEN EM-CRITICAL
                           ADD 1 TO WS-CRITICAL-CNT
                       WHEN EM-WARNING
                           ADD 1 TO WS-WARNING-CNT
                       WHEN OTHER
                           ADD 1 TO WS-INFO-CNT
                   END-EVALUATE
           END-READ
           ADD 1 TO WS-SUB-ERR-CNT
           PERFORM 2100-DETAIL-WRITE
           PERFORM 1100-READ-ERRLOG.

       2100-DETAIL-WRITE.
           STRING EL-HASSEI-DT(1:4) '-' EL-HASSEI-DT(5:2)
                  '-' EL-HASSEI-DT(7:2) ' '
                  EL-HASSEI-TM(1:2) ':' EL-HASSEI-TM(3:2)
                  ' [' EM-JUYO-DO '] '
                  EL-ERROR-CD ' '
                  EM-ERROR-MEI ' '
                  EL-DATA-KEY
               DELIMITED SIZE INTO WS-WORK-LINE
           MOVE WS-WORK-LINE TO DR-LINE
           WRITE DETAIL-REC.

       2900-TANTO-BREAK.
           MOVE WS-SUB-ERR-CNT TO WS-EDIT-CNT
           STRING '担当者:' WS-PREV-TANTO
                  '  エラー件数:' WS-EDIT-CNT
               DELIMITED SIZE INTO WS-WORK-LINE
           MOVE WS-WORK-LINE(1:80) TO SR-LINE
           WRITE SUMMARY-REC.

       3000-CLOSE-FILES.
           CLOSE ERR-LOG-FILE
           CLOSE ERRCD-MASTER
           CLOSE DETAIL-RPT
           CLOSE SUMMARY-RPT.

       9000-DETAIL-HEADER.
           MOVE '日時                重要度 ' &
                'エラーCD エラー名称' TO DR-LINE
           WRITE DETAIL-REC
           MOVE ALL '-' TO DR-LINE
           WRITE DETAIL-REC.

       9100-SUMMARY-OUTPUT.
           MOVE ALL '=' TO SR-LINE
           WRITE SUMMARY-REC
           MOVE WS-CRITICAL-CNT TO WS-EDIT-CNT
           STRING '重大エラー(H):' WS-EDIT-CNT
               DELIMITED SIZE INTO WS-WORK-LINE
           MOVE WS-WORK-LINE(1:80) TO SR-LINE
           WRITE SUMMARY-REC
           MOVE WS-WARNING-CNT TO WS-EDIT-CNT
           STRING '警告(W)      :' WS-EDIT-CNT
               DELIMITED SIZE INTO WS-WORK-LINE
           MOVE WS-WORK-LINE(1:80) TO SR-LINE
           WRITE SUMMARY-REC.
