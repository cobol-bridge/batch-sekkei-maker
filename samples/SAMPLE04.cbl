      *=================================================================
      * SAMPLE04: 在庫更新バッチ
      * 概要: 入出庫トランザクションを読み込み、在庫マスタを更新する
      *       マイナス在庫はエラーとして欠品ログに出力する
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAMPLE04.
       AUTHOR. BATCH-SYSTEM.
       DATE-WRITTEN. 2026-04-04.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TRANS-FILE ASSIGN TO TRANSIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-TRANS-STATUS.
           SELECT ZAIKO-MASTER ASSIGN TO ZAIKOMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS ZM-HINBAN
               FILE STATUS IS WS-ZAIKO-STATUS.
           SELECT KEPIN-LOG ASSIGN TO KEPINLOG
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-KEPIN-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  TRANS-FILE
           RECORD CONTAINS 50 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  TRANS-REC.
           05  TR-HINBAN         PIC X(10).
           05  TR-NYUSYUKKO-KBN  PIC X(01).
               88  TR-NYUKO      VALUE '1'.
               88  TR-SYUKKO     VALUE '2'.
           05  TR-SURYO          PIC 9(07).
           05  TR-HIDUKE         PIC 9(08).
           05  FILLER            PIC X(24).

       FD  ZAIKO-MASTER
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  ZAIKO-REC.
           05  ZM-HINBAN         PIC X(10).
           05  ZM-HINMEI         PIC X(30).
           05  ZM-ZAIKO-SU       PIC S9(09) COMP-3.
           05  ZM-ANZEN-SU       PIC S9(07) COMP-3.
           05  FILLER            PIC X(31).

       FD  KEPIN-LOG
           RECORD CONTAINS 60 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  KEPIN-REC.
           05  KP-HINBAN         PIC X(10).
           05  KP-SYUKKO-SU      PIC 9(07).
           05  KP-ZAIKO-SU       PIC S9(09) COMP-3.
           05  KP-HIDUKE         PIC 9(08).
           05  FILLER            PIC X(22).

       WORKING-STORAGE SECTION.
       01  WS-FLAGS.
           05  WS-TRANS-STATUS   PIC X(02).
           05  WS-ZAIKO-STATUS   PIC X(02).
           05  WS-KEPIN-STATUS   PIC X(02).
           05  WS-EOF-FLAG       PIC X(01) VALUE 'N'.

       01  WS-COUNTERS.
           05  WS-INPUT-CNT      PIC 9(07) VALUE ZEROS.
           05  WS-NYUKO-CNT      PIC 9(07) VALUE ZEROS.
           05  WS-SYUKKO-CNT     PIC 9(07) VALUE ZEROS.
           05  WS-KEPIN-CNT      PIC 9(07) VALUE ZEROS.
           05  WS-ERR-CNT        PIC 9(07) VALUE ZEROS.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 2000-MAIN-LOOP
               UNTIL WS-EOF-FLAG = 'Y'
           PERFORM 3000-CLOSE-FILES
           STOP RUN.

       1000-OPEN-FILES.
           OPEN INPUT  TRANS-FILE
           OPEN I-O    ZAIKO-MASTER
           OPEN OUTPUT KEPIN-LOG
           PERFORM 1100-READ-TRANS.

       1100-READ-TRANS.
           READ TRANS-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-MAIN-LOOP.
           ADD 1 TO WS-INPUT-CNT
           MOVE TR-HINBAN TO ZM-HINBAN
           READ ZAIKO-MASTER
               INVALID KEY
                   ADD 1 TO WS-ERR-CNT
               NOT INVALID KEY
                   PERFORM 2100-ZAIKO-UPDATE
           END-READ
           PERFORM 1100-READ-TRANS.

       2100-ZAIKO-UPDATE.
           IF TR-NYUKO
               ADD TR-SURYO TO ZM-ZAIKO-SU
               REWRITE ZAIKO-REC
               ADD 1 TO WS-NYUKO-CNT
           ELSE
               SUBTRACT TR-SURYO FROM ZM-ZAIKO-SU
                   ON SIZE ERROR
                       PERFORM 2200-KEPIN-SHORI
                   NOT ON SIZE ERROR
                       IF ZM-ZAIKO-SU < ZEROS
                           PERFORM 2200-KEPIN-SHORI
                       ELSE
                           REWRITE ZAIKO-REC
                           ADD 1 TO WS-SYUKKO-CNT
                       END-IF
               END-SUBTRACT
           END-IF.

       2200-KEPIN-SHORI.
           ADD 1 TO WS-KEPIN-CNT
           MOVE TR-HINBAN   TO KP-HINBAN
           MOVE TR-SURYO    TO KP-SYUKKO-SU
           MOVE ZM-ZAIKO-SU TO KP-ZAIKO-SU
           MOVE TR-HIDUKE   TO KP-HIDUKE
           WRITE KEPIN-REC.

       3000-CLOSE-FILES.
           CLOSE TRANS-FILE
           CLOSE ZAIKO-MASTER
           CLOSE KEPIN-LOG.
