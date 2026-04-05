      *=================================================================
      * SAMPLE02: 口座振替バッチ
      * 概要: 振替依頼ファイルを読み込み、口座マスタを照合して
      *       振替結果ファイルを出力する
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAMPLE02.
       AUTHOR. BATCH-SYSTEM.
       DATE-WRITTEN. 2026-04-04.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT FURIKAE-FILE ASSIGN TO FURIKAEIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-FURIKAE-STATUS.
           SELECT KOZA-MASTER ASSIGN TO KOZAMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS KM-KOZA-NO
               FILE STATUS IS WS-KOZA-STATUS.
           SELECT KEKKA-FILE ASSIGN TO KEKKAOUT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-KEKKA-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  FURIKAE-FILE
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  FURIKAE-REC.
           05  FR-KOZA-NO        PIC X(10).
           05  FR-KINGAKU        PIC 9(10).
           05  FR-HIDUKE         PIC 9(08).
           05  FILLER            PIC X(52).

       FD  KOZA-MASTER
           RECORD CONTAINS 100 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  KOZA-REC.
           05  KM-KOZA-NO        PIC X(10).
           05  KM-MEIGI          PIC X(40).
           05  KM-ZANDAKA        PIC S9(13) COMP-3.
           05  KM-STATUS         PIC X(01).
           05  FILLER            PIC X(36).

       FD  KEKKA-FILE
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  KEKKA-REC.
           05  KR-KOZA-NO        PIC X(10).
           05  KR-KINGAKU        PIC 9(10).
           05  KR-RESULT-CD      PIC X(02).
           05  KR-MSG            PIC X(40).
           05  FILLER            PIC X(18).

       WORKING-STORAGE SECTION.
       01  WS-FLAGS.
           05  WS-FURIKAE-STATUS PIC X(02).
           05  WS-KOZA-STATUS    PIC X(02).
           05  WS-KEKKA-STATUS   PIC X(02).
           05  WS-EOF-FLAG       PIC X(01) VALUE 'N'.

       01  WS-COUNTERS.
           05  WS-INPUT-CNT      PIC 9(07) VALUE ZEROS.
           05  WS-OK-CNT         PIC 9(07) VALUE ZEROS.
           05  WS-NG-CNT         PIC 9(07) VALUE ZEROS.

       PROCEDURE DIVISION.
       0000-MAIN.
           PERFORM 1000-OPEN-FILES
           PERFORM 2000-MAIN-LOOP
               UNTIL WS-EOF-FLAG = 'Y'
           PERFORM 3000-CLOSE-FILES
           STOP RUN.

       1000-OPEN-FILES.
           OPEN INPUT  FURIKAE-FILE
           OPEN I-O    KOZA-MASTER
           OPEN OUTPUT KEKKA-FILE
           PERFORM 1100-READ-FURIKAE.

       1100-READ-FURIKAE.
           READ FURIKAE-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-MAIN-LOOP.
           ADD 1 TO WS-INPUT-CNT
           MOVE FR-KOZA-NO TO KM-KOZA-NO
           READ KOZA-MASTER
               INVALID KEY
                   PERFORM 2200-KOZA-NOT-FOUND
               NOT INVALID KEY
                   PERFORM 2100-FURIKAE-SHORI
           END-READ
           PERFORM 1100-READ-FURIKAE.

       2100-FURIKAE-SHORI.
           IF KM-STATUS = '1'
               MOVE FR-KINGAKU TO WS-WORK-KINGAKU
               SUBTRACT FR-KINGAKU FROM KM-ZANDAKA
                   ON SIZE ERROR
                       PERFORM 2300-ZANDAKA-FUSOKU
                   NOT ON SIZE ERROR
                       REWRITE KOZA-REC
                       MOVE '00' TO KR-RESULT-CD
                       MOVE '振替正常終了' TO KR-MSG
                       ADD 1 TO WS-OK-CNT
               END-SUBTRACT
           ELSE
               MOVE '10' TO KR-RESULT-CD
               MOVE '口座利用停止' TO KR-MSG
               ADD 1 TO WS-NG-CNT
           END-IF
           PERFORM 9100-WRITE-KEKKA.

       2200-KOZA-NOT-FOUND.
           MOVE '20' TO KR-RESULT-CD
           MOVE '口座番号不存在' TO KR-MSG
           ADD 1 TO WS-NG-CNT
           PERFORM 9100-WRITE-KEKKA.

       2300-ZANDAKA-FUSOKU.
           MOVE '30' TO KR-RESULT-CD
           MOVE '残高不足' TO KR-MSG
           ADD 1 TO WS-NG-CNT
           PERFORM 9100-WRITE-KEKKA.

       3000-CLOSE-FILES.
           CLOSE FURIKAE-FILE
           CLOSE KOZA-MASTER
           CLOSE KEKKA-FILE.

       9100-WRITE-KEKKA.
           MOVE FR-KOZA-NO  TO KR-KOZA-NO
           MOVE FR-KINGAKU  TO KR-KINGAKU
           WRITE KEKKA-REC.

       01  WS-WORK-KINGAKU   PIC 9(10).
