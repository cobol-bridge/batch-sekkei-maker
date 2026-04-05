      *------------------------------------------------------
      * SAMPLE01.CBL
      * 売上ファイル集計バッチ（テスト用サンプル）
      *------------------------------------------------------
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SAMPLE01.
       AUTHOR.     SUZUKI.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT URIAGE-FILE ASSIGN TO 'URIAGE.DAT'
               ORGANIZATION IS SEQUENTIAL.
           SELECT TOKUISAKI-FILE ASSIGN TO 'TOKUISAKI.DAT'
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS TK-CODE.
           SELECT SHUUKEI-FILE ASSIGN TO 'SHUUKEI.DAT'
               ORGANIZATION IS SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.
       FD URIAGE-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 100 CHARACTERS.
       01 URIAGE-REC.
          05 UR-CODE        PIC X(10).
          05 UR-TOKUISAKI   PIC X(10).
          05 UR-KINGAKU     PIC 9(8).
          05 UR-DATE        PIC 9(8).
          05 FILLER         PIC X(64).

       FD TOKUISAKI-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 80 CHARACTERS.
       01 TOKUISAKI-REC.
          05 TK-CODE        PIC X(10).
          05 TK-NAME        PIC X(40).
          05 TK-AREA        PIC X(10).
          05 FILLER         PIC X(20).

       FD SHUUKEI-FILE
           RECORDING MODE IS F
           RECORD CONTAINS 80 CHARACTERS.
       01 SHUUKEI-REC.
          05 SK-TOKUISAKI   PIC X(10).
          05 SK-GOUKEI      PIC 9(10).
          05 SK-KENSU       PIC 9(5).
          05 FILLER         PIC X(55).

       WORKING-STORAGE SECTION.
       01 WS-EOF-FLAG       PIC X(1) VALUE '0'.
          88 WS-EOF         VALUE '1'.
       01 WS-GOUKEI         PIC 9(10) VALUE ZERO.
       01 WS-KENSU          PIC 9(5)  VALUE ZERO.
       01 WS-RETURN-CODE    PIC 9(4)  VALUE ZERO.

       PROCEDURE DIVISION.

       0000-MAIN.
           PERFORM 1000-INIT
           PERFORM 2000-MAIN-LOOP
               UNTIL WS-EOF
           PERFORM 3000-END
           STOP RUN.

       1000-INIT.
           OPEN INPUT  URIAGE-FILE
           OPEN I-O    TOKUISAKI-FILE
           OPEN OUTPUT SHUUKEI-FILE
           PERFORM 1100-READ-URIAGE.

       1100-READ-URIAGE.
           READ URIAGE-FILE
               AT END
                   MOVE '1' TO WS-EOF-FLAG
               NOT AT END
                   CONTINUE
           END-READ.

       2000-MAIN-LOOP.
           PERFORM 2100-GET-TOKUISAKI
           PERFORM 2200-SHUUKEI
           PERFORM 1100-READ-URIAGE.

       2100-GET-TOKUISAKI.
           MOVE UR-TOKUISAKI TO TK-CODE
           READ TOKUISAKI-FILE
               INVALID KEY
                   MOVE 99 TO WS-RETURN-CODE
                   PERFORM 9000-ERROR
               NOT INVALID KEY
                   CONTINUE
           END-READ.

       2200-SHUUKEI.
           ADD UR-KINGAKU TO WS-GOUKEI
           ADD 1          TO WS-KENSU
           MOVE UR-TOKUISAKI TO SK-TOKUISAKI
           MOVE WS-GOUKEI    TO SK-GOUKEI
           MOVE WS-KENSU     TO SK-KENSU
           WRITE SHUUKEI-REC
               ON SIZE ERROR
                   PERFORM 9000-ERROR
           END-WRITE.

       3000-END.
           CLOSE URIAGE-FILE
           CLOSE TOKUISAKI-FILE
           CLOSE SHUUKEI-FILE.

       9000-ERROR.
           DISPLAY 'ERROR OCCURRED CODE=' WS-RETURN-CODE
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.
