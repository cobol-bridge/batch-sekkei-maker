      *=================================================================
      * SAMPLE03: 給与計算バッチ
      * 概要: 勤怠データを読み込み、給与マスタを参照して
      *       給与明細ファイルを出力する
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAMPLE03.
       AUTHOR. BATCH-SYSTEM.
       DATE-WRITTEN. 2026-04-04.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT KINTAI-FILE ASSIGN TO KINTAIIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-KINTAI-STATUS.
           SELECT KYUYO-MASTER ASSIGN TO KYUYOMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS KYM-SHAIN-NO
               FILE STATUS IS WS-KYUYO-STATUS.
           SELECT MEISAI-FILE ASSIGN TO MEISAIOUT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-MEISAI-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  KINTAI-FILE
           RECORD CONTAINS 60 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  KINTAI-REC.
           05  KT-SHAIN-NO       PIC X(08).
           05  KT-KINMU-DAYS     PIC 9(02).
           05  KT-ZANGYO-H       PIC 9(04).
           05  KT-KYUJITU-H      PIC 9(04).
           05  KT-TIKOKU-CNT     PIC 9(02).
           05  FILLER            PIC X(40).

       FD  KYUYO-MASTER
           RECORD CONTAINS 120 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  KYUYO-REC.
           05  KYM-SHAIN-NO      PIC X(08).
           05  KYM-SHIMEI        PIC X(20).
           05  KYM-KIHON-KYU     PIC S9(07) COMP-3.
           05  KYM-ZANGYO-TAN    PIC S9(05) COMP-3.
           05  KYM-KYUJITU-TAN   PIC S9(05) COMP-3.
           05  FILLER            PIC X(72).

       FD  MEISAI-FILE
           RECORD CONTAINS 100 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  MEISAI-REC.
           05  MS-SHAIN-NO       PIC X(08).
           05  MS-SHIMEI         PIC X(20).
           05  MS-KIHON-KYU      PIC 9(07).
           05  MS-ZANGYO-TEA     PIC 9(07).
           05  MS-KYUJITU-TEA    PIC 9(07).
           05  MS-TIKOKU-KOJO    PIC 9(05).
           05  MS-TOTAL-KYU      PIC 9(08).
           05  FILLER            PIC X(38).

       WORKING-STORAGE SECTION.
       01  WS-FLAGS.
           05  WS-KINTAI-STATUS  PIC X(02).
           05  WS-KYUYO-STATUS   PIC X(02).
           05  WS-MEISAI-STATUS  PIC X(02).
           05  WS-EOF-FLAG       PIC X(01) VALUE 'N'.

       01  WS-WORK-AREA.
           05  WS-ZANGYO-TEA     PIC S9(09) COMP-3.
           05  WS-KYUJITU-TEA    PIC S9(09) COMP-3.
           05  WS-TIKOKU-KOJO    PIC S9(07) COMP-3.
           05  WS-TOTAL-KYU      PIC S9(09) COMP-3.

       01  WS-COUNTERS.
           05  WS-INPUT-CNT      PIC 9(07) VALUE ZEROS.
           05  WS-OUTPUT-CNT     PIC 9(07) VALUE ZEROS.
           05  WS-ERR-CNT        PIC 9(07) VALUE ZEROS.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 2000-MAIN-LOOP
               UNTIL WS-EOF-FLAG = 'Y'
           PERFORM 3000-CLOSE-FILES
           STOP RUN.

       1000-OPEN-FILES.
           OPEN INPUT  KINTAI-FILE
           OPEN INPUT  KYUYO-MASTER
           OPEN OUTPUT MEISAI-FILE
           PERFORM 1100-READ-KINTAI.

       1100-READ-KINTAI.
           READ KINTAI-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-MAIN-LOOP.
           ADD 1 TO WS-INPUT-CNT
           MOVE KT-SHAIN-NO TO KYM-SHAIN-NO
           READ KYUYO-MASTER
               INVALID KEY
                   ADD 1 TO WS-ERR-CNT
               NOT INVALID KEY
                   PERFORM 2100-KYUYO-KEISAN
                   PERFORM 2200-WRITE-MEISAI
           END-READ
           PERFORM 1100-READ-KINTAI.

       2100-KYUYO-KEISAN.
           MULTIPLY KT-ZANGYO-H  BY KYM-ZANGYO-TAN
               GIVING WS-ZANGYO-TEA
               ON SIZE ERROR MOVE 0 TO WS-ZANGYO-TEA
           END-MULTIPLY
           MULTIPLY KT-KYUJITU-H BY KYM-KYUJITU-TAN
               GIVING WS-KYUJITU-TEA
               ON SIZE ERROR MOVE 0 TO WS-KYUJITU-TEA
           END-MULTIPLY
           COMPUTE WS-TIKOKU-KOJO = KT-TIKOKU-CNT * 1000
           ADD KYM-KIHON-KYU WS-ZANGYO-TEA WS-KYUJITU-TEA
               GIVING WS-TOTAL-KYU
           SUBTRACT WS-TIKOKU-KOJO FROM WS-TOTAL-KYU.

       2200-WRITE-MEISAI.
           MOVE KYM-SHAIN-NO  TO MS-SHAIN-NO
           MOVE KYM-SHIMEI    TO MS-SHIMEI
           MOVE KYM-KIHON-KYU TO MS-KIHON-KYU
           MOVE WS-ZANGYO-TEA TO MS-ZANGYO-TEA
           MOVE WS-KYUJITU-TEA TO MS-KYUJITU-TEA
           MOVE WS-TIKOKU-KOJO TO MS-TIKOKU-KOJO
           MOVE WS-TOTAL-KYU  TO MS-TOTAL-KYU
           WRITE MEISAI-REC
           ADD 1 TO WS-OUTPUT-CNT.

       3000-CLOSE-FILES.
           CLOSE KINTAI-FILE
           CLOSE KYUYO-MASTER
           CLOSE MEISAI-FILE.
