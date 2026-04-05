      *=================================================================
      * SAMPLE08: マスタ更新バッチ
      * 概要: 変更依頼ファイルを読み込み、顧客マスタと住所マスタを
      *       更新する。新規・変更・削除の3種を処理する
      *=================================================================
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAMPLE08.
       AUTHOR. BATCH-SYSTEM.
       DATE-WRITTEN. 2026-04-04.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT HENKO-FILE ASSIGN TO HENKOIN
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-HENKO-STATUS.
           SELECT KOKYAKU-MASTER ASSIGN TO KOKYAKUMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS KK-KOKYAKU-CD
               FILE STATUS IS WS-KOKYAKU-STATUS.
           SELECT JUSHO-MASTER ASSIGN TO JUSHOMST
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS JM-KOKYAKU-CD
               FILE STATUS IS WS-JUSHO-STATUS.
           SELECT KEKKA-LOG ASSIGN TO KEKKALOG
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-KEKKA-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  HENKO-FILE
           RECORD CONTAINS 150 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  HENKO-REC.
           05  HN-SHORI-KBN      PIC X(01).
               88  HN-SHINKI     VALUE '1'.
               88  HN-HENKOU     VALUE '2'.
               88  HN-SAKUJO     VALUE '3'.
           05  HN-KOKYAKU-CD     PIC X(10).
           05  HN-SHIMEI         PIC X(30).
           05  HN-KANA           PIC X(30).
           05  HN-TEL            PIC X(15).
           05  HN-YUBINNO        PIC X(08).
           05  HN-JYUSYO         PIC X(50).
           05  FILLER            PIC X(06).

       FD  KOKYAKU-MASTER
           RECORD CONTAINS 100 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  KOKYAKU-REC.
           05  KK-KOKYAKU-CD     PIC X(10).
           05  KK-SHIMEI         PIC X(30).
           05  KK-KANA           PIC X(30).
           05  KK-TEL            PIC X(15).
           05  KK-TOUROKU-DT     PIC 9(08).
           05  FILLER            PIC X(07).

       FD  JUSHO-MASTER
           RECORD CONTAINS 80 CHARACTERS
           LABEL RECORDS ARE STANDARD.
       01  JUSHO-REC.
           05  JM-KOKYAKU-CD     PIC X(10).
           05  JM-YUBINNO        PIC X(08).
           05  JM-JYUSYO         PIC X(50).
           05  FILLER            PIC X(12).

       FD  KEKKA-LOG
           RECORD CONTAINS 60 CHARACTERS
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS.
       01  KEKKA-REC.
           05  KL-KOKYAKU-CD     PIC X(10).
           05  KL-SHORI-KBN      PIC X(01).
           05  KL-RESULT         PIC X(01).
           05  KL-MSG            PIC X(40).
           05  FILLER            PIC X(08).

       WORKING-STORAGE SECTION.
       01  WS-FLAGS.
           05  WS-HENKO-STATUS   PIC X(02).
           05  WS-KOKYAKU-STATUS PIC X(02).
           05  WS-JUSHO-STATUS   PIC X(02).
           05  WS-KEKKA-STATUS   PIC X(02).
           05  WS-EOF-FLAG       PIC X(01) VALUE 'N'.

       01  WS-TODAY              PIC 9(08) VALUE ZEROS.
       01  WS-COUNTERS.
           05  WS-INPUT-CNT      PIC 9(07) VALUE ZEROS.
           05  WS-SHINKI-CNT     PIC 9(07) VALUE ZEROS.
           05  WS-HENKOU-CNT     PIC 9(07) VALUE ZEROS.
           05  WS-SAKUJO-CNT     PIC 9(07) VALUE ZEROS.
           05  WS-ERR-CNT        PIC 9(07) VALUE ZEROS.

       PROCEDURE DIVISION.
       0000-MAIN.
           MOVE FUNCTION CURRENT-DATE(1:8) TO WS-TODAY
           PERFORM 1000-OPEN-FILES
           PERFORM 2000-MAIN-LOOP
               UNTIL WS-EOF-FLAG = 'Y'
           PERFORM 3000-CLOSE-FILES
           STOP RUN.

       1000-OPEN-FILES.
           OPEN INPUT  HENKO-FILE
           OPEN I-O    KOKYAKU-MASTER
           OPEN I-O    JUSHO-MASTER
           OPEN OUTPUT KEKKA-LOG
           PERFORM 1100-READ-HENKO.

       1100-READ-HENKO.
           READ HENKO-FILE
               AT END MOVE 'Y' TO WS-EOF-FLAG
           END-READ.

       2000-MAIN-LOOP.
           ADD 1 TO WS-INPUT-CNT
           EVALUATE TRUE
               WHEN HN-SHINKI
                   PERFORM 2100-SHINKI-SHORI
               WHEN HN-HENKOU
                   PERFORM 2200-HENKOU-SHORI
               WHEN HN-SAKUJO
                   PERFORM 2300-SAKUJO-SHORI
               WHEN OTHER
                   MOVE 'N' TO KL-RESULT
                   MOVE '処理区分不正' TO KL-MSG
                   PERFORM 9100-WRITE-LOG
           END-EVALUATE
           PERFORM 1100-READ-HENKO.

       2100-SHINKI-SHORI.
           MOVE HN-KOKYAKU-CD TO KK-KOKYAKU-CD
           MOVE HN-SHIMEI     TO KK-SHIMEI
           MOVE HN-KANA       TO KK-KANA
           MOVE HN-TEL        TO KK-TEL
           MOVE WS-TODAY      TO KK-TOUROKU-DT
           WRITE KOKYAKU-REC
               INVALID KEY
                   MOVE 'N' TO KL-RESULT
                   MOVE '顧客CD重複' TO KL-MSG
                   ADD 1 TO WS-ERR-CNT
               NOT INVALID KEY
                   PERFORM 2110-JUSHO-WRITE
           END-WRITE.

       2110-JUSHO-WRITE.
           MOVE HN-KOKYAKU-CD TO JM-KOKYAKU-CD
           MOVE HN-YUBINNO    TO JM-YUBINNO
           MOVE HN-JYUSYO     TO JM-JYUSYO
           WRITE JUSHO-REC
           MOVE 'Y' TO KL-RESULT
           MOVE '新規登録完了' TO KL-MSG
           ADD 1 TO WS-SHINKI-CNT
           PERFORM 9100-WRITE-LOG.

       2200-HENKOU-SHORI.
           MOVE HN-KOKYAKU-CD TO KK-KOKYAKU-CD
           READ KOKYAKU-MASTER
               INVALID KEY
                   MOVE 'N' TO KL-RESULT
                   MOVE '顧客CD不存在' TO KL-MSG
                   ADD 1 TO WS-ERR-CNT
                   PERFORM 9100-WRITE-LOG
               NOT INVALID KEY
                   MOVE HN-SHIMEI TO KK-SHIMEI
                   MOVE HN-TEL    TO KK-TEL
                   REWRITE KOKYAKU-REC
                   MOVE 'Y' TO KL-RESULT
                   MOVE '変更完了' TO KL-MSG
                   ADD 1 TO WS-HENKOU-CNT
                   PERFORM 9100-WRITE-LOG
           END-READ.

       2300-SAKUJO-SHORI.
           MOVE HN-KOKYAKU-CD TO KK-KOKYAKU-CD
           DELETE KOKYAKU-MASTER
               INVALID KEY
                   MOVE 'N' TO KL-RESULT
                   MOVE '削除対象不存在' TO KL-MSG
                   ADD 1 TO WS-ERR-CNT
               NOT INVALID KEY
                   MOVE 'Y' TO KL-RESULT
                   MOVE '削除完了' TO KL-MSG
                   ADD 1 TO WS-SAKUJO-CNT
           END-DELETE
           PERFORM 9100-WRITE-LOG.

       3000-CLOSE-FILES.
           CLOSE HENKO-FILE
           CLOSE KOKYAKU-MASTER
           CLOSE JUSHO-MASTER
           CLOSE KEKKA-LOG.

       9100-WRITE-LOG.
           MOVE HN-KOKYAKU-CD TO KL-KOKYAKU-CD
           MOVE HN-SHORI-KBN  TO KL-SHORI-KBN
           WRITE KEKKA-REC.
