.nolist
.include "m8def.inc"

.equ PWM_MAX = 1000
.equ MAXSPEED = 1000
.equ MAXSPEED_LEFT = MAXSPEED; * 50 / 100
.equ MAXSPEED_RIGHT = MAXSPEED; * 50 / 100

.equ LEFT_TURN_FLAG = 1
.equ RIGHT_TURN_FLAG = 2

.equ SENSOR_BLACK_LIMIT = 230

.def TEMP = r0

.def BUF = r16
.def ARG1 = r17
.def ARG2 = r18
.def ADC_RESULT = r19
.def TURN_FLAGS = r20

#define COM_RIGHT0 COM1A0
#define COM_RIGHT1 COM1A1
#define COM_LEFT0 COM1B0
#define COM_LEFT1 COM1B1

.list
.org 0x00
        rjmp init ; przerwanie od RESET, z tego miejsca zaczyna się wykonywanie programu
.org 0x01
        reti ; unused interrupt
.org 0x02
        reti ; unused interrupt
.org 0x03
        reti ; unused interrupt
.org 0x04
        reti ; unused interrupt
.org 0x05
        reti ; unused interrupt
.org 0x06
        reti ; unused interrupt
.org 0x07
        reti ; unused interrupt
.org 0x08
        reti ; unused interrupt
.org 0x09
        rjmp t0_ovf_handle ; przerwanie od Timer0
.org 0x0a
        reti ; unused interrupt
.org 0x0b
        reti ; unused interrupt
.org 0x0c
        reti ; unused interrupt
.org 0x0d
        reti ; unused interrupt
.org 0x0e
        rjmp adc_complete ; przerwanie, sygnalizujące zakończenie przetwarzania analgowo-cyfrowego
.org 0x0f
        reti ; unused interrupt
.org 0x10
        reti ; unused interrupt
.org 0x11
        reti ; unused interrupt
.org 0x12
        reti ; unused interrupt

init:
        ;; Ustawianie stosu
        ldi BUF, HIGH(RAMEND)
        out SPH, BUF
        ldi BUF, LOW(RAMEND)
        out SPL, BUF

        ;; Ustawianie portów B oraz D jako wyjścia (wpisanie samych jedynek do odpowiednich rejestrów DDR - Data Direction Register)
        ser BUF ; wypełnia rejestr jedynkami
        out DDRB, BUF
        out DDRD, BUF

        clr BUF
        out DDRC, BUF

        clr BUF ; ustawianie portów wyjściowych na 0, żeby nie zbierały elektromagnetyczne zakłócenia (również można było ustawić na 1, nie ma różnicy)
        out PORTB, BUF
        out PORTD, BUF

        ser BUF ; rezystory podciągające na wejścia
        out PORTC, BUF

        ldi BUF, (1<<SE) ; zezwolenie na "uśpienie" procesora (instrukcja sleep)
        out MCUCR, BUF

        sei ; globalne włączenie przerwań

main:

        rcall ADC_setup ; procedura inicjująca układ przetwarzacza analogowego

        rcall PWM_setup ; inicjacja PWM

        ldi ARG1, LOW(MAXSPEED_LEFT) ; ustawianie prędkości 75% na lewy silnik
        ldi ARG2, HIGH(MAXSPEED_LEFT)
        rcall left_PWM

        ldi ARG1, LOW(PWM_MAX - MAXSPEED_RIGHT) ; 70% na prawy <<=====!!!!WTF
        ldi ARG2, HIGH(PWM_MAX - MAXSPEED_RIGHT)

        
        rcall right_PWM


        rcall forward

        ;; clr TURN_FLAGS ; czyszczenie rejestru flag, gdzie zapamiętujemy skręty

mainloop:
        ;; sleep
        ;; rjmp mainloop

        rcall ADC_read
        tst ADC_RESULT
        brne lo
        cbi PORTD, 6
        ;; rcall left_off
        ;; rcall right_off
        rjmp mainloop
lo:
        sbi PORTD, 6
        cpi ADC_RESULT, 0b01000
        brne loli
        rcall left_off
        ldi ARG1, LOW(PWM_MAX - MAXSPEED)
        ldi ARG2, HIGH(PWM_MAX - MAXSPEED)
        rcall right_PWM
        rcall right_on
        rjmp mainloop
loli:
        sbi PORTD, 6
        cpi ADC_RESULT, 0b10000
        brne li
        rcall left_off
        ldi ARG1, LOW(PWM_MAX - MAXSPEED)
        ldi ARG2, HIGH(PWM_MAX - MAXSPEED)
        rcall right_PWM
        rcall right_on
        rjmp mainloop
li:
lic:
c:
        cpi ADC_RESULT, 0b00100
        brne ric
        ldi ARG1, LOW(MAXSPEED_LEFT)
        ldi ARG2, HIGH(MAXSPEED_LEFT)
        rcall left_PWM
        rcall left_on
        ldi ARG1, LOW(PWM_MAX - MAXSPEED_RIGHT)
        ldi ARG2, HIGH(PWM_MAX - MAXSPEED_RIGHT)
        rcall right_PWM
        rcall right_on
        rjmp mainloop
ric:
ri:
rori:
	   cpi ADC_RESULT, 0b00010
        brne ro
        ldi ARG1, LOW(MAXSPEED)
        ldi ARG2, HIGH(MAXSPEED)
        rcall left_PWM
        rcall left_on
        rcall right_off
ro:
        cpi ADC_RESULT, 0b00001
        brne default
        ldi ARG1, LOW(MAXSPEED)
        ldi ARG2, HIGH(MAXSPEED)
        rcall left_PWM
        rcall left_on
        rcall right_off
default:
        rjmp mainloop


;;; SUBROUTINES SECTION

msleep: ; krótkookresowy sleep dla przerwy między
                                ; zmianą kierunku silnika, żeby nie było
                                ; nagłej zmiany prądu, co mogłoby
                                ; spowodować przepalenie mostKa H
        ldi BUF, (1<<CS01) | (1<<CS00)
        rjmp _sleep_skip
sleep: ; zwykły sleep,
                                ; w ARG1 przyjmuje okres czekania (30 to mniej więcej 1 sekunda)
        ldi BUF, (1<<CS00) | (1<<CS02) ; różnica między tymi
                                ; sleep'ami w ustawienu preskalera
                                ; (układu, który zmniejsza częstotliwość
                                ; taktowania wbudowanego zegara):
                                ; CS00 | CS01 => razy 64; CS00 | CS012 => razy 1024.
                                ; Taktowanie wewnętrznego zegara to 8MHz
_sleep_skip:
        out TCCR0, BUF
        ldi BUF, (1<<TOIE0) ; zezwolenie na przerwania od zegara
        out TIMSK, BUF
sleep_loop:
        sleep
        ;; dec ARG1
        brne sleep_loop
        clr BUF
        out TCCR0, BUF
        out TIMSK, BUF
        ret


PWM_setup:
        ldi BUF, HIGH(PWM_MAX)
        out ICR1H, BUF
        ldi BUF, LOW(PWM_MAX)
        out ICR1L, BUF
        ;; ldi BUF, (1<<COM_RIGHT1) | (1<<COM_LEFT1) | (1<<WGM11)
        ;; ldi BUF, (1<<COM_RIGHT1) | (1<<COM_LEFT0) | (1<<COM_LEFT1) | (1<<WGM11)
        ldi BUF, (1<<COM_RIGHT1) | (1<<COM_RIGHT0) | (1<<COM_LEFT1) | (1<<WGM11)
        ;; ldi BUF, (1<<COM_LEFT1) | (1<<WGM11)
        out TCCR1A, BUF
        ldi BUF, (1<<WGM12) | (1<<WGM13) | (1<<CS12)
        out TCCR1B, BUF
        ret

left_PWM:
        out OCR1BH, ARG2
        out OCR1BL, ARG1
        ret

right_PWM:
        out OCR1AH, ARG2
        out OCR1AL, ARG1
        ret

left_on:
        sbic PORTD, PORTD0
        rjmp _left_on
        sbis PORTD, PORTD1
        rjmp _left_on
        rcall left_off
        ldi ARG1, 5
        rcall msleep
_left_on:
        sbi PORTD, PORTD0
        cbi PORTD, PORTD1
        ret

left_rev:
        sbis PORTD, PORTD0
        rjmp _left_rev
        sbic PORTD, PORTD1
        rjmp _left_rev
        rcall left_off
        ldi ARG1, 5
        rcall msleep
_left_rev:
        cbi PORTD, PORTD0
        sbi PORTD, PORTD1
        ret

left_off:
        cbi PORTD, PORTD0
        cbi PORTD, PORTD1
        ret

right_on:
        sbic PORTD, PORTD2
        rjmp _right_on
        sbis PORTD, PORTD3
        rjmp _right_on
        rcall right_off
        ldi ARG1, 5
        rcall msleep
_right_on:
        sbi PORTD, PORTD2
        cbi PORTD, PORTD3
        ret

right_rev:
        sbis PORTD, PORTD2
        rjmp _right_rev
        sbic PORTD, PORTD3
        rjmp _right_rev
        rcall right_off
        ldi ARG1, 5
        rcall msleep
_right_rev:
        cbi PORTD, PORTD2
        sbi PORTD, PORTD3
        ret

right_off:
        cbi PORTD, PORTD2
        cbi PORTD, PORTD3
        ret

forward:
        rcall left_on
        rcall right_on
        ret


ADC_setup:
        ldi BUF, (1<<ADEN) | (1<<ADPS2) | (1<<ADPS1)
        out ADCSRA, BUF
        ldi BUF, (1<<REFS0) | (1<<ADLAR)
        out ADMUX, BUF
        ret

ADC_read:
        sbi ADCSRA, ADIE

        clr ADC_RESULT

        sbi ADMUX, MUX0
        cbi ADMUX, MUX1
        cbi ADMUX, MUX2
        sbi ADCSRA, ADSC
        sleep
        in BUF, ADCH
        cpi BUF, SENSOR_BLACK_LIMIT
        brlo _1_white
        ori ADC_RESULT, 0x10

_1_white:
        cbi ADMUX, MUX0
        sbi ADMUX, MUX1
        cbi ADMUX, MUX2
        sbi ADCSRA, ADSC
        sleep
        in BUF, ADCH
        cpi BUF, SENSOR_BLACK_LIMIT
        brlo _2_white
        ori ADC_RESULT, 0x08

_2_white:
        sbi ADMUX, MUX0
        sbi ADMUX, MUX1
        cbi ADMUX, MUX2
        sbi ADCSRA, ADSC
        sleep
        in BUF, ADCH
        cpi BUF, SENSOR_BLACK_LIMIT
        brlo _3_white
        ori ADC_RESULT, 0x04

_3_white:
        cbi ADMUX, MUX0
        cbi ADMUX, MUX1
        sbi ADMUX, MUX2
        sbi ADCSRA, ADSC
        sleep
        in BUF, ADCH
        cpi BUF, SENSOR_BLACK_LIMIT
        brlo _4_white
        ori ADC_RESULT, 0x02

_4_white:
        sbi ADMUX, MUX0
        cbi ADMUX, MUX1
        sbi ADMUX, MUX2
        sbi ADCSRA, ADSC
        sleep
        in BUF, ADCH
        cpi BUF, SENSOR_BLACK_LIMIT
        brlo _5_white
        ori ADC_RESULT, 0x01

_5_white:
        cbi ADCSRA, ADIE
        ret


sensors_test:
        rcall ADC_read
        tst ADC_RESULT
        breq _sensors_test_white
        sbi PORTD, PORTD6
        ret
_sensors_test_white:
        cbi PORTD, PORTD6
        ret

;;; INTERRUPT HANDLERS SECTION

t0_ovf_handle:
        dec ARG1
        reti

t2_ovf_handle:

        reti

adc_complete:
        ;; in ADC_RESULT, ADCH
        reti
