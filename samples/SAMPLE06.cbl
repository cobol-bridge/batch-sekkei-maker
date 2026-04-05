      *=================================================================
      * SAMPLE06: 保険料計算バッチ
      * 概要: 被保険者データを読み込み、料率マスタから保険料を算出し
      *       保険料通知ファイルと口座振替依頼ファイルを出力する
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAMPLE06.
       AUTHOR. BATCH-SYSTEM.
       DATE-WRITTEN. 2026-04-04.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT HIHOKEN-FILE ASSIGN TO HIHOKNIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-HIHOKEN-STATUS.
           SELECT RYO-MASTER ASSIGN TO RYORITMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS RM-HOKEN-KBN
               FILE STATUS IS WS-RYO-STATUS.
           SELECT TSUCHI-FILE ASSIGN TO TSUCHIOUT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-TSUCHI-STATUS.
           SELECT FURIKAE-REQ ASSIGN TO FURIKAEQ
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-FURIKAE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  HIHOKEN-FILE
           RECORD CONTAINS 120 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  HIHOKEN-REC.
           05  HH-HIHOKEN-NO     PIC X(12).
           05  HH-SHIMEI         PIC X(20).
           05  HH-HOKEN-KBN      PIC X(04).
           05  HH-HYOJUN-HYO     PIC 9(08).
           05  HH-KOZA-NO        PIC X(14).
           05  HH-FUYO-CNT       PIC 9(02).
           05  FILLER            PIC X(60).

       FD  RYO-MASTER
           RECORD CONTAINS 60 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  RYO-REC.
           05  RM-HOKEN-KBN      PIC X(04).
           05  RM-HIHOKEN-RITSU  PIC V9(05).
           05  RM-JIGYOSYA-RITSU PIC V9(05).
           05  RM-FUYO-KASAN     PIC 9(06).
           05  FILLER            PIC X(41).

       FD  TSUCHI-FILE
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  TSUCHI-REC.
           05  TC-HIHOKEN-NO     PIC X(12).
           05  TC-SHIMEI         PIC X(20).
           05  TC-HOKEN-RYO      PIC 9(08).
           05  TC-FUYO-KASAN     PIC 9(07).
           05  TC-GOUKEI         PIC 9(09).
           05  FILLER            PIC X(24).

       FD  FURIKAE-REQ
           RECORD CONTAINS 40 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  FURIKAE-REC.
           05  FQ-KOZA-NO        PIC X(14).
           05  FQ-KINGAKU        PIC 9(09).
           05  FILLER            PIC X(17).

       WORKING-STORAGE SECTION.
       01  WS-FLAGS.
           05  WS-HIHOKEN-STATUS PIC X(02).
           05  WS-RYO-STATUS     PIC X(02).
           05  WS-TSUCHI-STATUS  PIC X(02).
           05  WS-FURIKAE-STATUS PIC X(02).
           05  WS-EOF-FLAG       PIC X(01) VALUE 'N'.

       01  WS-WORK-AREA.
           05  WS-HOKEN-RYO      PIC S9(09) COMP-3.
           05  WS-FUYO-KASAN     PIC S9(09) COMP-3.
           05  WS-GOUKEI         PIC S9(11) COMP-3.

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
           OPEN INPUT  HIHOKEN-FILE
           OPEN INPUT  RYO-MASTER
           OPEN OUTPUT TSUCHI-FILE
           OPEN OUTPUT FURIKAE-REQ
           PERFORM 1100-READ-HIHOKEN.

       1100-READ-HIHOKEN.
           READ HIHOKEN-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-MAIN-LOOP.
           ADD 1 TO WS-INPUT-CNT
           MOVE HH-HOKEN-KBN TO RM-HOKEN-KBN
           READ RYO-MASTER
               INVALID KEY
                   ADD 1 TO WS-ERR-CNT
               NOT INVALID KEY
                   PERFORM 2100-RYOKIN-KEISAN
                   PERFORM 2200-WRITE-TSUCHI
                   PERFORM 2300-WRITE-FURIKAE
           END-READ
           PERFORM 1100-READ-HIHOKEN.

       2100-RYOKIN-KEISAN.
           COMPUTE WS-HOKEN-RYO =
               HH-HYOJUN-HYO * RM-HIHOKEN-RITSU
               ON SIZE ERROR
                   MOVE 999999999 TO WS-HOKEN-RYO
           END-COMPUTE
           MULTIPLY HH-FUYO-CNT BY RM-FUYO-KASAN
               GIVING WS-FUYO-KASAN
               ON SIZE ERROR MOVE 0 TO WS-FUYO-KASAN
           END-MULTIPLY
           ADD WS-HOKEN-RYO WS-FUYO-KASAN GIVING WS-GOUKEI.

       2200-WRITE-TSUCHI.
           MOVE HH-HIHOKEN-NO TO TC-HIHOKEN-NO
           MOVE HH-SHIMEI     TO TC-SHIMEI
           MOVE WS-HOKEN-RYO  TO TC-HOKEN-RYO
           MOVE WS-FUYO-KASAN TO TC-FUYO-KASAN
           MOVE WS-GOUKEI     TO TC-GOUKEI
           WRITE TSUCHI-REC
           ADD 1 TO WS-OUTPUT-CNT.

       2300-WRITE-FURIKAE.
           MOVE HH-KOZA-NO  TO FQ-KOZA-NO
           MOVE WS-GOUKEI   TO FQ-KINGAKU
           WRITE FURIKAE-REC.

       3000-CLOSE-FILES.
           CLOSE HIHOKEN-FILE
           CLOSE RYO-MASTER
           CLOSE TSUCHI-FILE
           CLOSE FURIKAE-REQ.
