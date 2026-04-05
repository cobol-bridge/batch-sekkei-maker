      *=================================================================
      * SAMPLE07: 売掛金消込バッチ
      * 概要: 入金データと売掛残高マスタを照合して消込処理を行い
      *       消込結果と未消込残高ファイルを出力する
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAMPLE07.
       AUTHOR. BATCH-SYSTEM.
       DATE-WRITTEN. 2026-04-04.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT NYUKIN-FILE ASSIGN TO NYUKININ
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-NYUKIN-STATUS.
           SELECT URIKAKE-MASTER ASSIGN TO URIKAMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS UM-TOKUI-CD
               FILE STATUS IS WS-URIKAKE-STATUS.
           SELECT KESHIKOMI-FILE ASSIGN TO KESHIOUT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-KESHI-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  NYUKIN-FILE
           RECORD CONTAINS 60 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  NYUKIN-REC.
           05  NK-TOKUI-CD       PIC X(08).
           05  NK-NYUKIN-DT      PIC 9(08).
           05  NK-NYUKIN-KINGAKU PIC 9(11).
           05  NK-NYUKIN-HOKO    PIC X(04).
           05  FILLER            PIC X(29).

       FD  URIKAKE-MASTER
           RECORD CONTAINS 100 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  URIKAKE-REC.
           05  UM-TOKUI-CD       PIC X(08).
           05  UM-TOKUI-MEI      PIC X(30).
           05  UM-ZANDAKA        PIC S9(13) COMP-3.
           05  UM-SAIGO-NYUKIN   PIC 9(08).
           05  FILLER            PIC X(47).

       FD  KESHIKOMI-FILE
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  KESHIKOMI-REC.
           05  KS-TOKUI-CD       PIC X(08).
           05  KS-TOKUI-MEI      PIC X(30).
           05  KS-NYUKIN-KINGAKU PIC 9(11).
           05  KS-ZANDAKA-MAE    PIC S9(13) COMP-3.
           05  KS-ZANDAKA-GO     PIC S9(13) COMP-3.
           05  KS-KESHI-KBN      PIC X(01).
           05  FILLER            PIC X(04).

       WORKING-STORAGE SECTION.
       01  WS-FLAGS.
           05  WS-NYUKIN-STATUS  PIC X(02).
           05  WS-URIKAKE-STATUS PIC X(02).
           05  WS-KESHI-STATUS   PIC X(02).
           05  WS-EOF-FLAG       PIC X(01) VALUE 'N'.

       01  WS-WORK-AREA.
           05  WS-ZANDAKA-MAE    PIC S9(13) COMP-3.
           05  WS-ZANDAKA-GO     PIC S9(13) COMP-3.

       01  WS-COUNTERS.
           05  WS-INPUT-CNT      PIC 9(07) VALUE ZEROS.
           05  WS-KANZEN-CNT     PIC 9(07) VALUE ZEROS.
           05  WS-BUBUN-CNT      PIC 9(07) VALUE ZEROS.
           05  WS-KACHOU-CNT     PIC 9(07) VALUE ZEROS.
           05  WS-ERR-CNT        PIC 9(07) VALUE ZEROS.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 2000-MAIN-LOOP
               UNTIL WS-EOF-FLAG = 'Y'
           PERFORM 3000-CLOSE-FILES
           STOP RUN.

       1000-OPEN-FILES.
           OPEN INPUT  NYUKIN-FILE
           OPEN I-O    URIKAKE-MASTER
           OPEN OUTPUT KESHIKOMI-FILE
           PERFORM 1100-READ-NYUKIN.

       1100-READ-NYUKIN.
           READ NYUKIN-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-MAIN-LOOP.
           ADD 1 TO WS-INPUT-CNT
           MOVE NK-TOKUI-CD TO UM-TOKUI-CD
           READ URIKAKE-MASTER
               INVALID KEY
                   ADD 1 TO WS-ERR-CNT
               NOT INVALID KEY
                   PERFORM 2100-KESHIKOMI-SHORI
           END-READ
           PERFORM 1100-READ-NYUKIN.

       2100-KESHIKOMI-SHORI.
           MOVE UM-ZANDAKA TO WS-ZANDAKA-MAE
           SUBTRACT NK-NYUKIN-KINGAKU FROM UM-ZANDAKA
               ON SIZE ERROR
                   MOVE ZEROS TO UM-ZANDAKA
                   MOVE '3' TO KS-KESHI-KBN
                   ADD 1 TO WS-KACHOU-CNT
               NOT ON SIZE ERROR
                   EVALUATE TRUE
                       WHEN UM-ZANDAKA = ZEROS
                           MOVE '1' TO KS-KESHI-KBN
                           ADD 1 TO WS-KANZEN-CNT
                       WHEN OTHER
                           MOVE '2' TO KS-KESHI-KBN
                           ADD 1 TO WS-BUBUN-CNT
                   END-EVALUATE
           END-SUBTRACT
           MOVE UM-ZANDAKA TO WS-ZANDAKA-GO
           MOVE NK-NYUKIN-DT TO UM-SAIGO-NYUKIN
           REWRITE URIKAKE-REC
           PERFORM 9100-WRITE-KESHIKOMI.

       3000-CLOSE-FILES.
           CLOSE NYUKIN-FILE
           CLOSE URIKAKE-MASTER
           CLOSE KESHIKOMI-FILE.

       9100-WRITE-KESHIKOMI.
           MOVE UM-TOKUI-CD       TO KS-TOKUI-CD
           MOVE UM-TOKUI-MEI      TO KS-TOKUI-MEI
           MOVE NK-NYUKIN-KINGAKU TO KS-NYUKIN-KINGAKU
           MOVE WS-ZANDAKA-MAE    TO KS-ZANDAKA-MAE
           MOVE WS-ZANDAKA-GO     TO KS-ZANDAKA-GO
           WRITE KESHIKOMI-REC.
