#lang racket

(require bitsyntax)
(require racket/contract)
(require cbor)
(require rnrs/io/ports-6)
(require rutus/lib/bitport)

(provide
 low7
 natural/e
 integral/e
 integer/e
 flat-pad
 flat-pad/e
 print-bits
 cbor-bytes)

; zigzag encoding is used for converting integers into naturals in a specific way.
; interlacing negatives with positives. 0, -1, 1, -2, 2, and so on.
(define/contract (zigzag n)
  (-> exact-integer? exact-nonnegative-integer?)
  (bitwise-xor
    (arithmetic-shift n 1)
    (arithmetic-shift n (- (integer-length n)))))

(define/contract (low7 n)
  (-> exact-integer? exact-integer?)
  (bitwise-and n #x7F))

(define (w7-list t)
  (let [(l (low7 t))
        (t1 (arithmetic-shift t -7))
        (w7 (λ (l) (bitwise-ior l #x80)))]
    (cond
      [(eq? t1 0) (list l)]
      [else (cons (w7 l) (w7-list t1))])))

(define/contract (natural/e n out)
  (-> exact-nonnegative-integer? output-bitport? void?)
  (integral/e n out))

(define/contract (integer/e n out)
  (-> exact-integer? output-bitport? void?)
  (integral/e (zigzag n) out))

(define/contract (integral/e n out)
  (-> exact-integer? output-bitport? void?)
  (let [(vs (w7-list n))]
    (integral-ws/e vs out)))

(define/contract (integral-ws/e xs out)
  (-> (listof exact-integer?) output-bitport? void?)
  (for ([x (in-list xs)])
        (bitport-write (bit-string [x :: bytes 1]) out)))

;; Pad remaining bits a la flat
(define/contract (flat-pad/e out)
  (-> output-bitport? void?)
  (define padding-required (- 8 (bitport-remainder-bitcount out)))
  (bitport-write (bit-string (1 :: bits padding-required little-endian)) out))

(define/contract (flat-pad bs)
  (-> bit-string? bit-string?)
  (letrec [(padding-required (- 8 (modulo (bit-string-length bs) 8)))
           (end-padding (cond
                          [(not (= padding-required 0))
                           (bit-string [1 :: bits padding-required little-endian])]
                          [else (bit-string)]))]
    (bit-string-append bs end-padding)))

;; turn a bytestring into its cbor bytestring equivalent
(define (cbor-bytes a) 
  (call-with-bytevector-output-port 
    (λ(out)
      (cbor-write
       cbor-empty-config
       a
       out))))

(define (print-bits bs)
  (cond
     [(list? bs)
      (string-join (map (λ (b) (~r b #:base 2 #:min-width 8 #:pad-string "0")) bs) " ")]
     [(bytes? bs)
      (print-bits (bytes->list bs))]
     [(bit-string? bs)
      (print-bits (bit-string->bytes bs))]))