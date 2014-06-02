.nolist
.include "m8def.inc"

.equ    PERIOD  =   10
.equ    PWM_MAX =   1000

.equ    LEFT_TURN_FLAG  =   1
.equ    RIGHT_TURN_FLAG =   2


.def    TEMP    =   r0

.def    BUF     =   r16
.def    ARG1    =   r17
.def    ARG2    =   r18
.def    ADC_RESULT      =   r19
.def    TURN_FLAGS      =   r20

#define     COM_RIGHT0     COM1A0
#define     COM_RIGHT1     COM1A1
#define     COM_LEFT0      COM1B0
#define     COM_LEFT1      COM1B1

.list
.org 0x00
        rjmp init
.org 0x01
        reti                    ; unused interrupt
.org 0x02
        reti                    ; unused interrupt
.org 0x03
        reti                    ; unused interrupt
.org 0x04
        rjmp t2_ovf_handle
.org 0x05
        reti                    ; unused interrupt
.org 0x06
        reti                    ; unused interrupt
.org 0x07
        reti                    ; unused interrupt
.org 0x08
        reti                    ; unused interrupt
.org 0x09
        rjmp t0_ovf_handle
.org 0x0a
        reti                    ; unused interrupt
.org 0x0b
        reti                    ; unused interrupt
.org 0x0c
        reti                    ; unused interrupt
.org 0x0d
        reti                    ; unused interrupt
.org 0x0e
        rjmp adc_complete
.org 0x0f
        reti                    ; unused interrupt
.org 0x10
        reti                    ; unused interrupt
.org 0x11
        reti                    ; unused interrupt
.org 0x12
        reti                    ; unused interrupt

init:
        ldi BUF, HIGH(RAMEND)
        out SPH, BUF
        ldi BUF, LOW(RAMEND)
        out SPL, BUF
        ser BUF
        out DDRB, BUF
        out DDRD, BUF

        ldi BUF, (1<<0)
        out DDRC, BUF

        clr BUF
        out PORTB, BUF
        out PORTC, BUF
        out PORTD, BUF

        ldi BUF, (1<<SE)
        out MCUCR, BUF

        sei

main:
        
        rcall ADC_setup

        ;; sbi PORTB, PORTB1
        ;; sbi PORTB, PORTB2
        
        rcall PWM_setup

        ldi ARG1, LOW(750)
        ldi ARG2, HIGH(750)
        rcall left_PWM

        ldi ARG1, LOW(700)
        ldi ARG2, HIGH(700)
        rcall right_PWM

        rcall left_on
        rcall right_on

        clr TURN_FLAGS

mainloop:
        rcall ADC_read
        cpi ADC_RESULT, 0b11111
        breq mainloop

        mov BUF, ADC_RESULT
        andi BUF, 0b11000
        breq white_left
        ;; cbi PORTD, PORTD6
        rcall turn_left
        rjmp mainloop
white_left:
        mov BUF, ADC_RESULT
        andi BUF, 0b00011
        breq white_right
        ;; cbi PORTD, PORTD6
        rcall turn_right
        rjmp mainloop
white_right:
        ;; cpi ADC_RESULT, 0b00100
        ;; brne white_3
        ;; sbi PORTD, PORTD6
        rcall forward
white_3:
        rjmp mainloop


;;; SUBROUTINES SECTION

msleep: 
        ldi BUF, (1<<CS01) | (1<<CS00)
        rjmp _sleep_skip
sleep:
        ldi BUF, (1<<CS00) | (1<<CS02)
_sleep_skip:
        out TCCR0, BUF
        ldi BUF, (1<<TOIE0)
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
        ldi BUF, (1<<COM_RIGHT1) | (1<<COM_LEFT1) | (1<<WGM11)
        ;; ldi BUF, (1<<COM_RIGHT1) | (1<<COM_LEFT0) | (1<<COM_LEFT1) | (1<<WGM11)
        ;; ldi BUF, (1<<COM_RIGHT1) | (1<<COM_RIGHT0) | (1<<COM_LEFT1) | (1<<WGM11)
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

turn_left:
        cbr TURN_FLAGS, RIGHT_TURN_FLAG
        sbrc TURN_FLAGS, LEFT_TURN_FLAG
        rjmp _turn_left_skip_sleep
        ldi ARG1, LOW(100)
        ldi ARG2, HIGH(100)
        rcall left_PWM
        rcall left_rev
        ldi ARG1, 10
        rcall sleep
_turn_left_skip_sleep:
        rcall left_off
        ldi ARG1, LOW(1000)
        ldi ARG2, HIGH(1000)
        rcall right_PWM
        rcall right_on
        ret

turn_right:
        cbr TURN_FLAGS, LEFT_TURN_FLAG
        sbrc TURN_FLAGS, RIGHT_TURN_FLAG
        rjmp _turn_right_skip_sleep
        sbr TURN_FLAGS, RIGHT_TURN_FLAG
        ldi ARG1, LOW(100)
        ldi ARG2, HIGH(100)
        rcall right_PWM
        rcall right_rev
        ldi ARG1, 10
        rcall sleep
_turn_right_skip_sleep:
        rcall right_off
        ldi ARG1, LOW(1000)
        ldi ARG2, HIGH(1000)
        rcall left_PWM
        rcall left_on
        ret

forward:
        clr TURN_FLAGS
        ldi ARG1, LOW(750)
        ldi ARG2, HIGH(750)
        rcall left_PWM
        ldi ARG1, LOW(700)
        ldi ARG2, HIGH(700)
        rcall right_PWM
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
        ;; ldi BUF, (1<<SE) | (1<<SM0)
        ;; out MCUCR, BUF
        sbi ADCSRA, ADIE

        clr ADC_RESULT

        sbi ADMUX, MUX0
        cbi ADMUX, MUX1
        cbi ADMUX, MUX2
        sbi ADCSRA, ADSC
        sleep
        in BUF, ADCH
        cpi BUF, 220
        brlo _1_white
        ori ADC_RESULT, 0x01

_1_white:       
        cbi ADMUX, MUX0
        sbi ADMUX, MUX1
        cbi ADMUX, MUX2
        sbi ADCSRA, ADSC
        sleep
        in BUF, ADCH
        cpi BUF, 220
        brlo _2_white
        ori ADC_RESULT, 0x02

_2_white:       
        sbi ADMUX, MUX0
        sbi ADMUX, MUX1
        cbi ADMUX, MUX2
        sbi ADCSRA, ADSC
        sleep
        in BUF, ADCH
        cpi BUF, 220
        brlo _3_white
        ori ADC_RESULT, 0x04

_3_white:       
        cbi ADMUX, MUX0
        cbi ADMUX, MUX1
        sbi ADMUX, MUX2
        sbi ADCSRA, ADSC
        sleep
        in BUF, ADCH
        cpi BUF, 220
        brlo _4_white
        ori ADC_RESULT, 0x08

_4_white:       
        sbi ADMUX, MUX0
        cbi ADMUX, MUX1
        sbi ADMUX, MUX2
        sbi ADCSRA, ADSC
        sleep
        in BUF, ADCH
        cpi BUF, 220
        brlo _5_white
        ori ADC_RESULT, 0x10

_5_white:       

        cbi ADCSRA, ADIE
        ;; ldi BUF, (1<<SE)
        ;; out MCUCR, BUF

        ;; clr ADC_RESULT
        
        
        ret
        

;;; INTERRUPT HANDLERS SECTION

t0_ovf_handle:
        dec ARG1
;;         brne eoi
;;         ldi ARG1, PERIOD
;; eoi:
        reti

t2_ovf_handle:
        
        reti

adc_complete:
        ;; in ADC_RESULT, ADCH
        reti
