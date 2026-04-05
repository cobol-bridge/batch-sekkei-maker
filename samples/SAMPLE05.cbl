      *=================================================================
      * SAMPLE05: 住民税計算バッチ
      * 概要: 課税データを読み込み、税率マスタを参照して
      *       住民税額を算出し、納税通知ファイルを出力する
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAMPLE05.
       AUTHOR. BATCH-SYSTEM.
       DATE-WRITTEN. 2026-04-04.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT KAZEI-FILE ASSIGN TO KAZEIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-KAZEI-STATUS.
           SELECT ZEIRITSU-MASTER ASSIGN TO ZEIRITMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS ZR-SHOTOKU-KBN
               FILE STATUS IS WS-ZEIRITSU-STATUS.
           SELECT NOFU-FILE ASSIGN TO NOFUOUT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-NOFU-STATUS.
           SELECT ERROR-FILE ASSIGN TO ERROUT
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-ERROR-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  KAZEI-FILE
           RECORD CONTAINS 100 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  KAZEI-REC.
           05  KZ-JYUMIN-NO      PIC X(12).
           05  KZ-SHIMEI         PIC X(20).
           05  KZ-SHOTOKU-KBN    PIC X(02).
           05  KZ-KAZEI-SHOTOKU  PIC 9(10).
           05  KZ-KOJIN-KOJO     PIC 9(08).
           05  FILLER            PIC X(48).

       FD  ZEIRITSU-MASTER
           RECORD CONTAINS 40 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  ZEIRITSU-REC.
           05  ZR-SHOTOKU-KBN    PIC X(02).
           05  ZR-KENMIN-RITSU   PIC V9(04).
           05  ZR-SHIMIN-RITSU   PIC V9(04).
           05  ZR-KINTOWARIMAE   PIC 9(05).
           05  FILLER            PIC X(25).

       FD  NOFU-FILE
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  NOFU-REC.
           05  NF-JYUMIN-NO      PIC X(12).
           05  NF-SHIMEI         PIC X(20).
           05  NF-KENMIN-ZEI     PIC 9(08).
           05  NF-SHIMIN-ZEI     PIC 9(08).
           05  NF-KINTOWARIMAE   PIC 9(05).
           05  NF-GOUKEI         PIC 9(09).
           05  FILLER            PIC X(18).

       FD  ERROR-FILE
           RECORD CONTAINS 60 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  ERROR-REC.
           05  ER-JYUMIN-NO      PIC X(12).
           05  ER-ERROR-CD       PIC X(04).
           05  ER-MSG            PIC X(40).
           05  FILLER            PIC X(04).

       WORKING-STORAGE SECTION.
       01  WS-FLAGS.
           05  WS-KAZEI-STATUS   PIC X(02).
           05  WS-ZEIRITSU-STATUS PIC X(02).
           05  WS-NOFU-STATUS    PIC X(02).
           05  WS-ERROR-STATUS   PIC X(02).
           05  WS-EOF-FLAG       PIC X(01) VALUE 'N'.

       01  WS-WORK-AREA.
           05  WS-KAZEI-KIGO     PIC S9(11) COMP-3.
           05  WS-KENMIN-ZEI     PIC S9(09) COMP-3.
           05  WS-SHIMIN-ZEI     PIC S9(09) COMP-3.
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
           OPEN INPUT  KAZEI-FILE
           OPEN INPUT  ZEIRITSU-MASTER
           OPEN OUTPUT NOFU-FILE
           OPEN OUTPUT ERROR-FILE
           PERFORM 1100-READ-KAZEI.

       1100-READ-KAZEI.
           READ KAZEI-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-MAIN-LOOP.
           ADD 1 TO WS-INPUT-CNT
           MOVE KZ-SHOTOKU-KBN TO ZR-SHOTOKU-KBN
           READ ZEIRITSU-MASTER
               INVALID KEY
                   MOVE 'E001' TO ER-ERROR-CD
                   MOVE '税率区分不存在' TO ER-MSG
                   PERFORM 9200-WRITE-ERROR
               NOT INVALID KEY
                   PERFORM 2100-ZEI-KEISAN
           END-READ
           PERFORM 1100-READ-KAZEI.

       2100-ZEI-KEISAN.
           SUBTRACT KZ-KOJIN-KOJO FROM KZ-KAZEI-SHOTOKU
               GIVING WS-KAZEI-KIGO
               ON SIZE ERROR
                   MOVE 0 TO WS-KAZEI-KIGO
           END-SUBTRACT
           COMPUTE WS-KENMIN-ZEI =
               WS-KAZEI-KIGO * ZR-KENMIN-RITSU
           COMPUTE WS-SHIMIN-ZEI =
               WS-KAZEI-KIGO * ZR-SHIMIN-RITSU
           ADD ZR-KINTOWARIMAE TO WS-KENMIN-ZEI
               GIVING WS-GOUKEI
           ADD WS-SHIMIN-ZEI TO WS-GOUKEI
           PERFORM 2200-WRITE-NOFU.

       2200-WRITE-NOFU.
           MOVE KZ-JYUMIN-NO  TO NF-JYUMIN-NO
           MOVE KZ-SHIMEI     TO NF-SHIMEI
           MOVE WS-KENMIN-ZEI TO NF-KENMIN-ZEI
           MOVE WS-SHIMIN-ZEI TO NF-SHIMIN-ZEI
           MOVE ZR-KINTOWARIMAE TO NF-KINTOWARIMAE
           MOVE WS-GOUKEI     TO NF-GOUKEI
           WRITE NOFU-REC
           ADD 1 TO WS-OUTPUT-CNT.

       3000-CLOSE-FILES.
           CLOSE KAZEI-FILE
           CLOSE ZEIRITSU-MASTER
           CLOSE NOFU-FILE
           CLOSE ERROR-FILE.

       9200-WRITE-ERROR.
           MOVE KZ-JYUMIN-NO TO ER-JYUMIN-NO
           WRITE ERROR-REC
           ADD 1 TO WS-ERR-CNT.
