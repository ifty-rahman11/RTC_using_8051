ORG     0000H
                LJMP    START
LCD_RS          BIT     P3.0
LCD_RW          BIT     P3.1
LCD_EN          BIT     P3.2
PWR_KEY         BIT     P3.4
DHT_DATA        BIT     P3.5
I2C_SCL         BIT     P3.6
I2C_SDA         BIT     P3.7
KEYVAL          EQU     30H
RTC_SEC         EQU     31H
RTC_MIN         EQU     32H
RTC_HR          EQU     33H
RTC_DAY         EQU     34H
RTC_DATE        EQU     35H
RTC_MONTH       EQU     36H
RTC_YEAR        EQU     37H
SET_IDX         EQU     38H
CURSORADR       EQU     39H
IN_HH_T         EQU     3AH
IN_HH_U         EQU     3BH
IN_MM_T         EQU     3CH
IN_MM_U         EQU     3DH
IN_SS_T         EQU     3EH
IN_SS_U         EQU     3FH
IN_DD_T         EQU     40H
IN_DD_U         EQU     41H
IN_MO_T         EQU     42H
IN_MO_U         EQU     43H
DAYIDX          EQU     44H
TMP             EQU     45H
TMP2            EQU     46H
TMP3            EQU     47H
LOOPCNT         EQU     48H
DHT_HUM_INT     EQU     49H
DHT_HUM_DEC     EQU     4AH
DHT_TMP_INT     EQU     4BH
DHT_TMP_DEC     EQU     4CH
DHT_CHECK       EQU     4DH
DHT_LASTTEMP    EQU     4EH
MODE_FLAG       EQU     4FH
RTC_WADDR       EQU     0D0H
RTC_RADDR       EQU     0D1H

;======================================================================
START:
                MOV     SP, #70H
                MOV     P1, #00H
                MOV     P2, #0FFH
                CLR     LCD_RS
                CLR     LCD_RW
                CLR     LCD_EN
                SETB    I2C_SCL
                SETB    I2C_SDA
                SETB    DHT_DATA
                MOV     DHT_LASTTEMP, #00H
                MOV     LOOPCNT, #00H
                MOV     MODE_FLAG, #00H
                LCALL   DELAY_50MS
                LCALL   DELAY_50MS
                LCALL   DELAY_50MS
                LCALL   I2C_RECOVER
                LCALL   LCD_INIT
                MOV     A, #01H
                LCALL   LCD_CMD
                LCALL   DELAY_5MS
                MOV     A, #083H
                LCALL   LCD_CMD
                MOV     DPTR, #MSG_INIT
                LCALL   LCD_PRINT
                LCALL   DELAY_2SEC
                LCALL   SETMODE_INIT

;======================================================================
SETMODE_LOOP:
                LCALL   CHECK_POWER_SAVE
                LCALL   KEYPAD_GETKEY
                MOV     A, KEYVAL
                JZ      SETMODE_LOOP
                CJNE    A, #'C', SM_CHECK_PLUS
                LCALL   SETMODE_INIT
                LJMP    SETMODE_LOOP
SM_CHECK_PLUS:
                CJNE    A, #'+', SM_CHECK_EQUAL
                LCALL   NEXT_DAY
                LJMP    SETMODE_LOOP
SM_CHECK_EQUAL:
                CJNE    A, #'=', SM_CHECK_DIGIT
                LCALL   VALIDATE_AND_SAVE
                JC      SM_INVALID
                MOV     A, #01H
                LCALL   LCD_CMD
                LCALL   DELAY_5MS
                MOV     A, #085H
                LCALL   LCD_CMD
                MOV     DPTR, #MSG_SAVED
                LCALL   LCD_PRINT
                LCALL   WRITE_INPUTS_TO_RTC
                LCALL   DELAY_2SEC
                MOV     MODE_FLAG, #01H
                MOV     LOOPCNT, #00H
                LCALL   DHT11_READ
                LJMP    RUNMODE_LOOP
SM_INVALID:
                LJMP    SETMODE_LOOP
SM_CHECK_DIGIT:
                LCALL   IS_NUMERIC_KEY
                JNC     SM_STORE
                LJMP    SETMODE_LOOP
SM_STORE:
                LCALL   STORE_DIGIT
                LJMP    SETMODE_LOOP

;======================================================================
RUNMODE_LOOP:
                LCALL   CHECK_POWER_SAVE
                LCALL   RTC_READ_ALL
                INC     LOOPCNT
                MOV     A, LOOPCNT
                CJNE    A, #40, RM_SKIP_DHT
                MOV     LOOPCNT, #00H
                LCALL   DHT11_READ
RM_SKIP_DHT:
                LCALL   DISPLAY_RTC_AND_TEMP
                LCALL   KEYPAD_GETKEY
                MOV     A, KEYVAL
                JZ      RUNMODE_DELAY
                CJNE    A, #'C', RUNMODE_DELAY
                MOV     MODE_FLAG, #00H
                LCALL   SETMODE_INIT
                LJMP    SETMODE_LOOP
RUNMODE_DELAY:
                LCALL   DELAY_50MS
                LJMP    RUNMODE_LOOP

;======================================================================
CHECK_POWER_SAVE:
                JB      PWR_KEY, ENTER_POWER_SAVE
                RET
ENTER_POWER_SAVE:
                MOV     A, #08H
                LCALL   LCD_CMD
PS_WAIT_LOW:
                JB      PWR_KEY, PS_WAIT_LOW
                MOV     A, #0CH
                LCALL   LCD_CMD
                LCALL   DELAY_5MS
                MOV     A, MODE_FLAG
                JNZ     PS_RUN_REFRESH
                LCALL   SETMODE_REDRAW
                RET
PS_RUN_REFRESH:
                LCALL   RTC_READ_ALL
                LCALL   DHT11_READ
                LCALL   DISPLAY_RTC_AND_TEMP
                RET

;======================================================================
SETMODE_INIT:
                MOV     MODE_FLAG, #00H
                MOV     SET_IDX, #00H
                MOV     DAYIDX, #00H
                MOV     IN_HH_T, #'0'
                MOV     IN_HH_U, #'0'
                MOV     IN_MM_T, #'0'
                MOV     IN_MM_U, #'0'
                MOV     IN_SS_T, #'0'
                MOV     IN_SS_U, #'0'
                MOV     IN_DD_T, #'0'
                MOV     IN_DD_U, #'1'
                MOV     IN_MO_T, #'0'
                MOV     IN_MO_U, #'1'
SETMODE_REDRAW:
                MOV     A, #01H
                LCALL   LCD_CMD
                LCALL   DELAY_5MS
                MOV     A, #084H
                LCALL   LCD_CMD
                MOV     A, IN_HH_T
                LCALL   LCD_DATA
                MOV     A, IN_HH_U
                LCALL   LCD_DATA
                MOV     A, #':'
                LCALL   LCD_DATA
                MOV     A, IN_MM_T
                LCALL   LCD_DATA
                MOV     A, IN_MM_U
                LCALL   LCD_DATA
                MOV     A, #':'
                LCALL   LCD_DATA
                MOV     A, IN_SS_T
                LCALL   LCD_DATA
                MOV     A, IN_SS_U
                LCALL   LCD_DATA
                MOV     A, #0C0H
                LCALL   LCD_CMD
                MOV     A, IN_DD_T
                LCALL   LCD_DATA
                MOV     A, IN_DD_U
                LCALL   LCD_DATA
                MOV     A, #':'
                LCALL   LCD_DATA
                MOV     A, IN_MO_T
                LCALL   LCD_DATA
                MOV     A, IN_MO_U
                LCALL   LCD_DATA
                LCALL   SHOW_DAY_FROM_IDX
                MOV     A, #0CCH
                LCALL   LCD_CMD
                MOV     DPTR, #MSG_TEMP_DASH
                LCALL   LCD_PRINT
                MOV     CURSORADR, #084H
                MOV     A, CURSORADR
                LCALL   LCD_CMD
                RET

;----------------------------------------------------------------------
STORE_DIGIT:
                MOV     A, SET_IDX
                CJNE    A, #0AH, SD_GO
                RET
SD_GO:
                MOV     A, CURSORADR
                LCALL   LCD_CMD
                MOV     A, KEYVAL
                LCALL   LCD_DATA
                MOV     A, SET_IDX
                CJNE    A, #00H, SD_1
                MOV     IN_HH_T, KEYVAL
                LJMP    SD_NEXT
SD_1:           CJNE    A, #01H, SD_2
                MOV     IN_HH_U, KEYVAL
                LJMP    SD_NEXT
SD_2:           CJNE    A, #02H, SD_3
                MOV     IN_MM_T, KEYVAL
                LJMP    SD_NEXT
SD_3:           CJNE    A, #03H, SD_4
                MOV     IN_MM_U, KEYVAL
                LJMP    SD_NEXT
SD_4:           CJNE    A, #04H, SD_5
                MOV     IN_SS_T, KEYVAL
                LJMP    SD_NEXT
SD_5:           CJNE    A, #05H, SD_6
                MOV     IN_SS_U, KEYVAL
                LJMP    SD_NEXT
SD_6:           CJNE    A, #06H, SD_7
                MOV     IN_DD_T, KEYVAL
                LJMP    SD_NEXT
SD_7:           CJNE    A, #07H, SD_8
                MOV     IN_DD_U, KEYVAL
                LJMP    SD_NEXT
SD_8:           CJNE    A, #08H, SD_9
                MOV     IN_MO_T, KEYVAL
                LJMP    SD_NEXT
SD_9:           MOV     IN_MO_U, KEYVAL
SD_NEXT:
                INC     SET_IDX
                LCALL   ADVANCE_INPUT_CURSOR
                RET

;----------------------------------------------------------------------
ADVANCE_INPUT_CURSOR:
                MOV     A, SET_IDX
                CJNE    A, #01H, AIC_1
                MOV     CURSORADR, #085H
                RET
AIC_1:          CJNE    A, #02H, AIC_2
                MOV     CURSORADR, #087H
                RET
AIC_2:          CJNE    A, #03H, AIC_3
                MOV     CURSORADR, #088H
                RET
AIC_3:          CJNE    A, #04H, AIC_4
                MOV     CURSORADR, #08AH
                RET
AIC_4:          CJNE    A, #05H, AIC_5
                MOV     CURSORADR, #08BH
                RET
AIC_5:          CJNE    A, #06H, AIC_6
                MOV     CURSORADR, #0C0H
                RET
AIC_6:          CJNE    A, #07H, AIC_7
                MOV     CURSORADR, #0C1H
                RET
AIC_7:          CJNE    A, #08H, AIC_8
                MOV     CURSORADR, #0C3H
                RET
AIC_8:          CJNE    A, #09H, AIC_9
                MOV     CURSORADR, #0C4H
                RET
AIC_9:          MOV     CURSORADR, #0C4H
                RET

;----------------------------------------------------------------------
NEXT_DAY:
                INC     DAYIDX
                MOV     A, DAYIDX
                CJNE    A, #07H, ND_OK
                MOV     DAYIDX, #00H
ND_OK:
                LCALL   SHOW_DAY_FROM_IDX
                MOV     A, CURSORADR
                LCALL   LCD_CMD
                RET

;----------------------------------------------------------------------
SHOW_DAY_FROM_IDX:
                MOV     A, #0C7H
                LCALL   LCD_CMD
                MOV     A, DAYIDX
                CJNE    A, #00H, SDI_1
                MOV     DPTR, #MSG_SAT
                LJMP    SDI_PRINT
SDI_1:          CJNE    A, #01H, SDI_2
                MOV     DPTR, #MSG_SUN
                LJMP    SDI_PRINT
SDI_2:          CJNE    A, #02H, SDI_3
                MOV     DPTR, #MSG_MON
                LJMP    SDI_PRINT
SDI_3:          CJNE    A, #03H, SDI_4
                MOV     DPTR, #MSG_TUE
                LJMP    SDI_PRINT
SDI_4:          CJNE    A, #04H, SDI_5
                MOV     DPTR, #MSG_WED
                LJMP    SDI_PRINT
SDI_5:          CJNE    A, #05H, SDI_6
                MOV     DPTR, #MSG_THU
                LJMP    SDI_PRINT
SDI_6:          MOV     DPTR, #MSG_FRI
SDI_PRINT:      LCALL   LCD_PRINT
                RET

;======================================================================
VALIDATE_AND_SAVE:
                MOV     A, SET_IDX
                CJNE    A, #0AH, VAS_FAIL1
                SJMP    VAS_HOUR
VAS_FAIL1:      LJMP    VAS_FAIL
VAS_HOUR:
                MOV     A, IN_HH_T
                CLR     C
                SUBB    A, #'0'
                MOV     TMP, A
                MOV     A, IN_HH_U
                CLR     C
                SUBB    A, #'0'
                MOV     TMP2, A
                MOV     A, TMP
                CJNE    A, #00H, VAS_H1
                LJMP    VAS_MINUTE
VAS_H1:         CJNE    A, #01H, VAS_H2
                LJMP    VAS_MINUTE
VAS_H2:         CJNE    A, #02H, VAS_FAIL2
                MOV     A, TMP2
                CLR     C
                SUBB    A, #04H
                JNC     VAS_FAIL2
                LJMP    VAS_MINUTE
VAS_FAIL2:      LJMP    VAS_FAIL
VAS_MINUTE:
                MOV     A, IN_MM_T
                CLR     C
                SUBB    A, #'0'
                CLR     C
                SUBB    A, #06H
                JNC     VAS_FAIL3
                SJMP    VAS_SECOND
VAS_FAIL3:      LJMP    VAS_FAIL
VAS_SECOND:
                MOV     A, IN_SS_T
                CLR     C
                SUBB    A, #'0'
                CLR     C
                SUBB    A, #06H
                JNC     VAS_FAIL4
                SJMP    VAS_DAY
VAS_FAIL4:      LJMP    VAS_FAIL
VAS_DAY:
                MOV     A, IN_DD_T
                CLR     C
                SUBB    A, #'0'
                MOV     TMP, A
                MOV     A, IN_DD_U
                CLR     C
                SUBB    A, #'0'
                MOV     TMP2, A
                MOV     A, TMP
                ORL     A, TMP2
                JZ      VAS_FAIL5
                MOV     A, TMP
                CJNE    A, #03H, VAS_D_CHK
                MOV     A, TMP2
                CLR     C
                SUBB    A, #02H
                JNC     VAS_FAIL5
                SJMP    VAS_MONTH
VAS_FAIL5:      LJMP    VAS_FAIL
VAS_D_CHK:
                MOV     A, TMP
                CLR     C
                SUBB    A, #04H
                JNC     VAS_FAIL6
                SJMP    VAS_MONTH
VAS_FAIL6:      LJMP    VAS_FAIL
VAS_MONTH:
                MOV     A, IN_MO_T
                CLR     C
                SUBB    A, #'0'
                MOV     TMP, A
                MOV     A, IN_MO_U
                CLR     C
                SUBB    A, #'0'
                MOV     TMP2, A
                MOV     A, TMP
                ORL     A, TMP2
                JZ      VAS_FAIL7
                MOV     A, TMP
                JZ      VAS_SAVE
                CJNE    A, #01H, VAS_FAIL7
                MOV     A, TMP2
                CLR     C
                SUBB    A, #03H
                JNC     VAS_FAIL7
VAS_SAVE:       CLR     C
                RET
VAS_FAIL7:
VAS_FAIL:       SETB    C
                RET

;======================================================================
WRITE_INPUTS_TO_RTC:
                MOV     R0, #0EH
                MOV     A, #00H
                LCALL   RTC_WRITE_REG
                LCALL   DELAY_5MS
                MOV     R0, #0FH
                MOV     A, #00H
                LCALL   RTC_WRITE_REG
                LCALL   DELAY_5MS
                LCALL   I2C_START
                MOV     A, #RTC_WADDR
                LCALL   I2C_WRITE_BYTE
                MOV     A, #00H
                LCALL   I2C_WRITE_BYTE
                MOV     A, IN_SS_T
                CLR     C
                SUBB    A, #'0'
                SWAP    A
                ANL     A, #70H
                MOV     TMP, A
                MOV     A, IN_SS_U
                CLR     C
                SUBB    A, #'0'
                ORL     A, TMP
                LCALL   I2C_WRITE_BYTE
                MOV     A, IN_MM_T
                CLR     C
                SUBB    A, #'0'
                SWAP    A
                ANL     A, #70H
                MOV     TMP, A
                MOV     A, IN_MM_U
                CLR     C
                SUBB    A, #'0'
                ORL     A, TMP
                LCALL   I2C_WRITE_BYTE
                MOV     A, IN_HH_T
                CLR     C
                SUBB    A, #'0'
                SWAP    A
                ANL     A, #30H
                MOV     TMP, A
                MOV     A, IN_HH_U
                CLR     C
                SUBB    A, #'0'
                ORL     A, TMP
                LCALL   I2C_WRITE_BYTE
                MOV     A, DAYIDX
                LCALL   DAYIDX_TO_RTC
                LCALL   I2C_WRITE_BYTE
                MOV     A, IN_DD_T
                CLR     C
                SUBB    A, #'0'
                SWAP    A
                ANL     A, #30H
                MOV     TMP, A
                MOV     A, IN_DD_U
                CLR     C
                SUBB    A, #'0'
                ORL     A, TMP
                LCALL   I2C_WRITE_BYTE
                MOV     A, IN_MO_T
                CLR     C
                SUBB    A, #'0'
                SWAP    A
                ANL     A, #10H
                MOV     TMP, A
                MOV     A, IN_MO_U
                CLR     C
                SUBB    A, #'0'
                ORL     A, TMP
                LCALL   I2C_WRITE_BYTE
                MOV     A, #25H
                LCALL   I2C_WRITE_BYTE
                LCALL   I2C_STOP
                LCALL   DELAY_20MS
                RET

;----------------------------------------------------------------------
DAYIDX_TO_RTC:
                CJNE    A, #00H, DITR_1
                MOV     A, #07H
                RET
DITR_1:         CJNE    A, #01H, DITR_2
                MOV     A, #01H
                RET
DITR_2:         CJNE    A, #02H, DITR_3
                MOV     A, #02H
                RET
DITR_3:         CJNE    A, #03H, DITR_4
                MOV     A, #03H
                RET
DITR_4:         CJNE    A, #04H, DITR_5
                MOV     A, #04H
                RET
DITR_5:         CJNE    A, #05H, DITR_6
                MOV     A, #05H
                RET
DITR_6:         MOV     A, #06H
                RET

;======================================================================
RTC_READ_ALL:
                LCALL   I2C_START
                MOV     A, #RTC_WADDR
                LCALL   I2C_WRITE_BYTE
                MOV     A, #00H
                LCALL   I2C_WRITE_BYTE
                LCALL   I2C_START
                MOV     A, #RTC_RADDR
                LCALL   I2C_WRITE_BYTE
                LCALL   I2C_READ_ACK
                MOV     RTC_SEC, A
                LCALL   I2C_READ_ACK
                MOV     RTC_MIN, A
                LCALL   I2C_READ_ACK
                MOV     RTC_HR, A
                LCALL   I2C_READ_ACK
                MOV     RTC_DAY, A
                LCALL   I2C_READ_ACK
                MOV     RTC_DATE, A
                LCALL   I2C_READ_ACK
                MOV     RTC_MONTH, A
                LCALL   I2C_READ_NACK
                MOV     RTC_YEAR, A
                LCALL   I2C_STOP
                RET

;======================================================================
DISPLAY_RTC_AND_TEMP:
                MOV     A, #084H
                LCALL   LCD_CMD
                MOV     A, RTC_HR
                ANL     A, #03FH
                LCALL   LCD_WRITE_BCD2
                MOV     A, #':'
                LCALL   LCD_DATA
                MOV     A, RTC_MIN
                ANL     A, #07FH
                LCALL   LCD_WRITE_BCD2
                MOV     A, #':'
                LCALL   LCD_DATA
                MOV     A, RTC_SEC
                ANL     A, #07FH
                LCALL   LCD_WRITE_BCD2
                MOV     A, #0C0H
                LCALL   LCD_CMD
                MOV     A, RTC_DATE
                ANL     A, #03FH
                LCALL   LCD_WRITE_BCD2
                MOV     A, #':'
                LCALL   LCD_DATA
                MOV     A, RTC_MONTH
                ANL     A, #01FH
                LCALL   LCD_WRITE_BCD2
                MOV     A, #' '
                LCALL   LCD_DATA
                MOV     A, #' '
                LCALL   LCD_DATA
                MOV     A, #0C7H
                LCALL   LCD_CMD
                MOV     A, RTC_DAY
                ANL     A, #07H
                LCALL   LCD_WRITE_DAYNAME
                MOV     A, #' '
                LCALL   LCD_DATA
                MOV     A, #0CCH
                LCALL   LCD_CMD
                MOV     A, DHT_LASTTEMP
                LCALL   LCD_WRITE_BCD2
                MOV     A, #0DFH
                LCALL   LCD_DATA
                MOV     A, #'C'
                LCALL   LCD_DATA
                RET

;----------------------------------------------------------------------
RTC_WRITE_REG:
                MOV     TMP, A
                LCALL   I2C_START
                MOV     A, #RTC_WADDR
                LCALL   I2C_WRITE_BYTE
                MOV     A, R0
                LCALL   I2C_WRITE_BYTE
                MOV     A, TMP
                LCALL   I2C_WRITE_BYTE
                LCALL   I2C_STOP
                RET

;======================================================================
DHT11_READ:
                CLR     DHT_DATA
                LCALL   DELAY_20MS
                SETB    DHT_DATA
                LCALL   DELAY_30US
                LCALL   WAIT_DHT_LOW
                JC      DHT_FAIL
                LCALL   WAIT_DHT_HIGH
                JC      DHT_FAIL
                LCALL   WAIT_DHT_LOW
                JC      DHT_FAIL
                LCALL   READ_DHT_BYTE
                MOV     DHT_HUM_INT, A
                LCALL   READ_DHT_BYTE
                MOV     DHT_HUM_DEC, A
                LCALL   READ_DHT_BYTE
                MOV     DHT_TMP_INT, A
                LCALL   READ_DHT_BYTE
                MOV     DHT_TMP_DEC, A
                LCALL   READ_DHT_BYTE
                MOV     DHT_CHECK, A
                MOV     A, DHT_HUM_INT
                ADD     A, DHT_HUM_DEC
                ADD     A, DHT_TMP_INT
                ADD     A, DHT_TMP_DEC
                CJNE    A, DHT_CHECK, DHT_FAIL
                MOV     A, DHT_TMP_INT
                LCALL   BIN_TO_BCD
                MOV     DHT_LASTTEMP, A
                RET
DHT_FAIL:
                SETB    DHT_DATA
                RET

;----------------------------------------------------------------------
WAIT_DHT_LOW:
                MOV     R6, #255
WDL1:           JNB     DHT_DATA, WDL_OK
                DJNZ    R6, WDL1
                SETB    C
                RET
WDL_OK:         CLR     C
                RET

WAIT_DHT_HIGH:
                MOV     R6, #255
WDH1:           JB      DHT_DATA, WDH_OK
                DJNZ    R6, WDH1
                SETB    C
                RET
WDH_OK:         CLR     C
                RET

READ_DHT_BYTE:
                MOV     R7, #08
                CLR     A
RDB1:           LCALL   WAIT_DHT_HIGH
                JC      RDB_FAIL
                LCALL   SAMPLE_DELAY
                MOV     C, DHT_DATA
                RLC     A
                LCALL   WAIT_DHT_LOW
                JC      RDB_FAIL
                DJNZ    R7, RDB1
                RET
RDB_FAIL:       CLR     A
                RET

;======================================================================
BIN_TO_BCD:
                MOV     B, #10
                DIV     AB
                SWAP    A
                ORL     A, B
                RET

;======================================================================
LCD_INIT:
                MOV     A, #30H
                LCALL   LCD_CMD_INIT
                LCALL   DELAY_5MS
                MOV     A, #30H
                LCALL   LCD_CMD_INIT
                LCALL   DELAY_2MS
                MOV     A, #30H
                LCALL   LCD_CMD_INIT
                LCALL   DELAY_2MS
                MOV     A, #38H
                LCALL   LCD_CMD
                LCALL   DELAY_2MS
                MOV     A, #38H
                LCALL   LCD_CMD
                LCALL   DELAY_2MS
                MOV     A, #08H
                LCALL   LCD_CMD
                LCALL   DELAY_2MS
                MOV     A, #01H
                LCALL   LCD_CMD
                LCALL   DELAY_5MS
                MOV     A, #06H
                LCALL   LCD_CMD
                LCALL   DELAY_2MS
                MOV     A, #0CH
                LCALL   LCD_CMD
                LCALL   DELAY_2MS
                RET

LCD_CMD_INIT:
                MOV     P1, A
                CLR     LCD_RS
                CLR     LCD_RW
                SETB    LCD_EN
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                CLR     LCD_EN
                RET

LCD_CMD:
                MOV     P1, A
                CLR     LCD_RS
                CLR     LCD_RW
                SETB    LCD_EN
                LCALL   DELAY_EN
                CLR     LCD_EN
                LCALL   DELAY_2MS
                RET

LCD_DATA:
                MOV     P1, A
                SETB    LCD_RS
                CLR     LCD_RW
                SETB    LCD_EN
                LCALL   DELAY_EN
                CLR     LCD_EN
                LCALL   DELAY_2MS
                RET

LCD_PRINT:
                CLR     A
LP1:            MOVC    A, @A+DPTR
                JZ      LPD
                LCALL   LCD_DATA
                INC     DPTR
                CLR     A
                SJMP    LP1
LPD:            RET

LCD_WRITE_BCD2:
                MOV     TMP, A
                SWAP    A
                ANL     A, #0FH
                ADD     A, #'0'
                LCALL   LCD_DATA
                MOV     A, TMP
                ANL     A, #0FH
                ADD     A, #'0'
                LCALL   LCD_DATA
                RET

LCD_WRITE_DAYNAME:
                CJNE    A, #01H, LWD_2
                MOV     DPTR, #MSG_SUN
                LJMP    LWD_P
LWD_2:          CJNE    A, #02H, LWD_3
                MOV     DPTR, #MSG_MON
                LJMP    LWD_P
LWD_3:          CJNE    A, #03H, LWD_4
                MOV     DPTR, #MSG_TUE
                LJMP    LWD_P
LWD_4:          CJNE    A, #04H, LWD_5
                MOV     DPTR, #MSG_WED
                LJMP    LWD_P
LWD_5:          CJNE    A, #05H, LWD_6
                MOV     DPTR, #MSG_THU
                LJMP    LWD_P
LWD_6:          CJNE    A, #06H, LWD_7
                MOV     DPTR, #MSG_FRI
                LJMP    LWD_P
LWD_7:          CJNE    A, #07H, LWD_X
                MOV     DPTR, #MSG_SAT
                LJMP    LWD_P
LWD_X:          MOV     DPTR, #MSG_DASH3
LWD_P:          LCALL   LCD_PRINT
                RET

;======================================================================
I2C_RECOVER:
                SETB    I2C_SDA
                MOV     R7, #09H
IR_LOOP:
                CLR     I2C_SCL
                LCALL   I2C_DELAY
                SETB    I2C_SCL
                LCALL   I2C_DELAY
                DJNZ    R7, IR_LOOP
                CLR     I2C_SDA
                LCALL   I2C_DELAY
                SETB    I2C_SCL
                LCALL   I2C_DELAY
                SETB    I2C_SDA
                LCALL   I2C_DELAY
                RET

I2C_START:
                SETB    I2C_SDA
                LCALL   I2C_DELAY
                SETB    I2C_SCL
                LCALL   I2C_DELAY
                LCALL   I2C_DELAY
                CLR     I2C_SDA
                LCALL   I2C_DELAY
                LCALL   I2C_DELAY
                CLR     I2C_SCL
                LCALL   I2C_DELAY
                RET

I2C_STOP:
                CLR     I2C_SDA
                LCALL   I2C_DELAY
                SETB    I2C_SCL
                LCALL   I2C_DELAY
                LCALL   I2C_DELAY
                SETB    I2C_SDA
                LCALL   I2C_DELAY
                LCALL   I2C_DELAY
                RET

I2C_WRITE_BYTE:
                MOV     R7, #08H
IWB1:           MOV     C, ACC.7
                MOV     I2C_SDA, C
                LCALL   I2C_DELAY
                SETB    I2C_SCL
                LCALL   I2C_DELAY
                CLR     I2C_SCL
                LCALL   I2C_DELAY
                RL      A
                DJNZ    R7, IWB1
                SETB    I2C_SDA
                LCALL   I2C_DELAY
                SETB    I2C_SCL
                LCALL   I2C_DELAY
                MOV     C, I2C_SDA
                CLR     I2C_SCL
                LCALL   I2C_DELAY
                RET

I2C_READ_ACK:
                LCALL   I2C_READ_BYTE
                CLR     I2C_SDA
                LCALL   I2C_DELAY
                SETB    I2C_SCL
                LCALL   I2C_DELAY
                CLR     I2C_SCL
                SETB    I2C_SDA
                RET

I2C_READ_NACK:
                LCALL   I2C_READ_BYTE
                SETB    I2C_SDA
                LCALL   I2C_DELAY
                SETB    I2C_SCL
                LCALL   I2C_DELAY
                CLR     I2C_SCL
                RET

I2C_READ_BYTE:
                MOV     R7, #08H
                CLR     A
                SETB    I2C_SDA
IRB1:           SETB    I2C_SCL
                LCALL   I2C_DELAY
                MOV     C, I2C_SDA
                RLC     A
                CLR     I2C_SCL
                LCALL   I2C_DELAY
                DJNZ    R7, IRB1
                RET

I2C_DELAY:
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                NOP
                RET

;======================================================================
KEYPAD_GETKEY:
                MOV     KEYVAL, #00H
                MOV     P2, #0FFH
                MOV     P2, #0FEH
                NOP
                NOP
                JNB     P2.4, K0R0
                JNB     P2.5, K0R1
                JNB     P2.6, K0R2
                JNB     P2.7, K0R3
                LJMP    K_C1
K0R0:           MOV     KEYVAL, #'7'
                LCALL   KP_CONFIRM_R0
                JC      K_C1_JMP
                LJMP    KP_DONE
K0R1:           MOV     KEYVAL, #'4'
                LCALL   KP_CONFIRM_R1
                JC      K_C1_JMP
                LJMP    KP_DONE
K0R2:           MOV     KEYVAL, #'1'
                LCALL   KP_CONFIRM_R2
                JC      K_C1_JMP
                LJMP    KP_DONE
K0R3:           MOV     KEYVAL, #'C'
                LCALL   KP_CONFIRM_R3
                JC      K_C1_JMP
                LJMP    KP_DONE
K_C1_JMP:       LJMP    K_C1
K_C1:
                MOV     P2, #0FDH
                NOP
                NOP
                JNB     P2.4, K1R0
                JNB     P2.5, K1R1
                JNB     P2.6, K1R2
                JNB     P2.7, K1R3
                LJMP    K_C2
K1R0:           MOV     KEYVAL, #'8'
                LCALL   KP_CONFIRM_R0
                JC      K_C2_JMP
                LJMP    KP_DONE
K1R1:           MOV     KEYVAL, #'5'
                LCALL   KP_CONFIRM_R1
                JC      K_C2_JMP
                LJMP    KP_DONE
K1R2:           MOV     KEYVAL, #'2'
                LCALL   KP_CONFIRM_R2
                JC      K_C2_JMP
                LJMP    KP_DONE
K1R3:           MOV     KEYVAL, #'0'
                LCALL   KP_CONFIRM_R3
                JC      K_C2_JMP
                LJMP    KP_DONE
K_C2_JMP:       LJMP    K_C2
K_C2:
                MOV     P2, #0FBH
                NOP
                NOP
                JNB     P2.4, K2R0
                JNB     P2.5, K2R1
                JNB     P2.6, K2R2
                JNB     P2.7, K2R3
                LJMP    K_C3
K2R0:           MOV     KEYVAL, #'9'
                LCALL   KP_CONFIRM_R0
                JC      K_C3_JMP
                LJMP    KP_DONE
K2R1:           MOV     KEYVAL, #'6'
                LCALL   KP_CONFIRM_R1
                JC      K_C3_JMP
                LJMP    KP_DONE
K2R2:           MOV     KEYVAL, #'3'
                LCALL   KP_CONFIRM_R2
                JC      K_C3_JMP
                LJMP    KP_DONE
K2R3:           MOV     KEYVAL, #'='
                LCALL   KP_CONFIRM_R3
                JC      K_C3_JMP
                LJMP    KP_DONE
K_C3_JMP:       LJMP    K_C3
K_C3:
                MOV     P2, #0F7H
                NOP
                NOP
                JNB     P2.4, K3R0
                JNB     P2.5, K3R1
                JNB     P2.6, K3R2
                JNB     P2.7, K3R3
                LJMP    KP_NONE
K3R0:           MOV     KEYVAL, #00H
                LCALL   KP_CONFIRM_R0
                LJMP    KP_NONE
K3R1:           MOV     KEYVAL, #00H
                LCALL   KP_CONFIRM_R1
                LJMP    KP_NONE
K3R2:           MOV     KEYVAL, #00H
                LCALL   KP_CONFIRM_R2
                LJMP    KP_NONE
K3R3:           MOV     KEYVAL, #'+'
                LCALL   KP_CONFIRM_R3
                JC      KP_NONE
                LJMP    KP_DONE
KP_NONE:
                MOV     KEYVAL, #00H
                MOV     P2, #0FFH
                RET
KP_DONE:
                LCALL   KP_WAIT_RELEASE
                MOV     P2, #0FFH
                RET
KP_CONFIRM_R0:
                LCALL   DELAY_20MS
                JNB     P2.4, KP_OK
                SJMP    KP_BAD
KP_CONFIRM_R1:
                LCALL   DELAY_20MS
                JNB     P2.5, KP_OK
                SJMP    KP_BAD
KP_CONFIRM_R2:
                LCALL   DELAY_20MS
                JNB     P2.6, KP_OK
                SJMP    KP_BAD
KP_CONFIRM_R3:
                LCALL   DELAY_20MS
                JNB     P2.7, KP_OK
                SJMP    KP_BAD
KP_OK:          CLR     C
                RET
KP_BAD:         SETB    C
                RET
KP_WAIT_RELEASE:
KWR1:           MOV     P2, #0F0H
                MOV     A, P2
                ANL     A, #0F0H
                CJNE    A, #0F0H, KWR1
                LCALL   DELAY_20MS
                MOV     P2, #0FFH
                RET

;======================================================================
IS_NUMERIC_KEY:
                MOV     A, KEYVAL
                CLR     C
                SUBB    A, #'0'
                JC      INK_BAD
                MOV     A, #'9'
                CLR     C
                SUBB    A, KEYVAL
                JC      INK_BAD
                CLR     C
                RET
INK_BAD:        SETB    C
                RET

;======================================================================
DELAY_EN:
                NOP
                NOP
                NOP
                NOP
                RET

DELAY_2MS:
                MOV     R4, #4
D2A:            MOV     R5, #250
D2B:            DJNZ    R5, D2B
                DJNZ    R4, D2A
                RET

DELAY_5MS:
                MOV     R3, #2
D5A:            LCALL   DELAY_2MS
                DJNZ    R3, D5A
                RET

DELAY_20MS:
                MOV     R2, #10
D20A:           LCALL   DELAY_2MS
                DJNZ    R2, D20A
                RET

DELAY_50MS:
                MOV     R1, #25
D50A:           LCALL   DELAY_2MS
                DJNZ    R1, D50A
                RET

DELAY_2SEC:
                MOV     R0, #100
D2SA:           LCALL   DELAY_20MS
                DJNZ    R0, D2SA
                RET

DELAY_30US:
                MOV     R0, #8
D30A:           NOP
                DJNZ    R0, D30A
                RET

SAMPLE_DELAY:
                MOV     R0, #12
SDL1:           NOP
                DJNZ    R0, SDL1
                RET

;======================================================================
MSG_INIT:       DB      'Initialize',00H
MSG_SAVED:      DB      'Saved',00H
MSG_TIME_ZERO:  DB      '00:00:00',00H
MSG_DATE_DEFAULT: DB    '01:01',00H
MSG_TEMP_DASH:  DB      '--',0DFH,'C',00H
MSG_SUN:        DB      'SUN',00H
MSG_MON:        DB      'MON',00H
MSG_TUE:        DB      'TUE',00H
MSG_WED:        DB      'WED',00H
MSG_THU:        DB      'THU',00H
MSG_FRI:        DB      'FRI',00H
MSG_SAT:        DB      'SAT',00H
MSG_DASH3:      DB      '---',00H

                END