# Bird video poker

# Watch segments are not all individually addressable, the top and bottom are joined
# Ace 2 3 4 5 6 7 8 9 T J Q K W4 W7 W10 WK
#      _   _       _   _       _   _   _   _
# |_|  _|  _| |_| |_  |_   _  |_| |_|  _    | |_| |_
# | | |_   _|   |  _| |_|   | |_|  _| |_|  _|     |
#                                      _
#             |_|          _          |_|          _|
#             |           |            _            |

# Number of different combinations: C(17, 5) = 17! / (12! * 5!) = 6188
# (/ (* 17 16 15 14 13) (* 5 4 3 2 1))
# (/ (apply * (range 1 17)) (* (apply * (range 1 12)) (apply * (range 1 5))))

(symbols 'bird 'pico)


(de CA . (1 14))
(de C2 . 2)
(de C3 . 3)
(de C4 . 4)
(de C5 . 5)
(de C6 . 6)
(de C7 . 7)
(de C8 . 8)
(de C9 . 9)
(de CT . 10)
(de CJ . 11)
(de CQ . 12)
(de CK . 13)

(de SUIT CA C2 C3 C4 C5 C6 C7 C8 C9 CT CJ CQ CK)

(def 'W4 (range 1 4))
(put 'W4 'wild T)
(def 'W7 (range 1 7))
(put 'W7 'wild T)
(def 'WT (range 1 10))
(put 'WT 'wild T)
(def 'WK (range 1 13))
(put 'WK 'wild T)

(de WILDS W4 W7 WT WK)
(def 'DECK (append SUIT WILDS))

(de Royal 5000)
(de FiveK 4000)
(de StrFl 3000)
(de FourK 1000)
(de FllHs  500)
(de Flush  400)
(de Strgt  300)
(de Trips  200)
(de Trp7b  150)
(de TrpLw  140)
(de TwoPr  100)
(de OnePr   20)
(de HighC   10)


(de WINCOMBS . '(Royal FiveK Strgt FourK FllHs Flush Strgt Trips TwoPr OnePr HighC))

(de gen-hand-explode (Hnd)
   (co 'gen-hand-explode
      (let (CdsRng (mapcar '((Cd)
                              (if (num? (val Cd))
                                 (list @)
                                 (val Cd)) ) Hnd) )
         (for Cd1 (get CdsRng 1)
            (for Cd2 (get CdsRng 2)
               (for Cd3 (get CdsRng 3)
                  (for Cd4 (get CdsRng 4)
                     (for Cd5 (get CdsRng 5)
                        (yield (mapcar '((Cd Rk)
                                         (if (get Cd 'wild)
                                             (cons Rk Cd)
                                            (cons Rk) ) )  Hnd (list Cd1 Cd2 Cd3 Cd4 Cd5)))) ) ) ) ) ) ) )

(de hand-explode (Hnd)
  (println "hand-explode" Hnd C2)
  (make
   (while (gen-hand-explode Hnd)
      (link @) ) ) )

# HndRks is cards and a possible rank point assignment for wildcards if any
# Hnd '(C2 W4 WK WT W7) is possibly RkCdL '((2) (3 . W4) (7 . WK) (5 . WT) (1 . W7))
# RkCdL is rank first for sort, wildcard have cdr
# check
# - if flush (no wildcards, only cards from suit)
# - a set combo (FiveK FourK FllHs Trips TwoPr OnePr)
# - a straight (Strgt StrFl Royal)
# - default is HighC
# return (<WINCOMBO> . RankOfHighestCard/RankOfLargestSet)
(de score-hand-unwilded (RkCdL)

   (let (HasWilds (find cdr RkCdL)
         IsFlush (not HasWilds)
         RkCdLS (sort RkCdL) # low to high
         ((R1 . W1) (R2 . W2) (R3 . W3) (R4 . W4) (R5 . W5)) RkCdLS
         IsStraight (and (= (inc R1) R2)
                         (= (inc R2) R3)
                         (= (inc R3) R4)
                         (= (inc R4) R5) )
         )
      (cond
         ((and IsStraight IsFlush (= R5 14))
            (list 'Royal) )
         #
         ((= R1 R5)
            (list 'FiveK R1) )
         #
         ((and IsStraight IsFlush)
            (list 'StrFl R5) )
         #
         ((or (== R1 R4) # xxxx* or *xxxx
               (== R2 R5) )
            (list 'FourK R2) )
         # xxxyy or xxyyy (Note should never match as it requires 3 wildcards, which make a better quads)
         ((or (and (= R1 R3) (= R4 R5))
              (and (= R1 R2) (= R3 R5)) )
            (list 'FllHs R3) )
         #
         (IsFlush
            (list 'Flush R5))
         #
         (IsStraight
            (list 'Strgt R5))
         # xxx** or *xxx* or **xxx
         ((or (= R1 R3)
               (= R2 R4)
               (= R3 R5) )
#             (if (<= 7 R3)
#               (list 'Trp7b R3)
#               (list 'TrpLw R3))
            (list 'Trips R3)
               )
         # xxyy* or xx*yy or *xxyy (Note should never match as it requires 2 wildcards, which make a better trips if 2 pair possible)
         ((or (and (= R1 R2)(= R3 R4))
              (and (= R1 R2) (= R4 R5))
              (and (= R2 R3) (= R4 R5)) )
            (list 'TwoPr R4) )
         # OnePr Pt. 1 xx*** or *xx**
         ((or (= R1 R2) (= R2 R3))
            (list 'OnePr R2) )
         # OnePr Pt. 2 **xx* or ***xx
         ((or (= R3 R4) (= R4 R5))
            (list 'OnePr R4) )
         # default is high card
         (T
            (list 'HighC R5))
      ) ) )


(de best-score (Scores)
     (maxi '(((Comb Rk))
             (cons (val Comb) Rk))
        Scores) )

(or T
   (and (mapcar '((Grp) (cons (length Grp) (car Grp))) (by cdr group '((C2 . 2) (W4 . 2) (WT . 2) (WK . 2) (W7 . 2))))
      (assoc 5 @) ) )
(or T
   (and (by length group (by cdr group '((C2 . 2) (W4 . 2) (WT . 9) (WK . 9) (W7 . 2))))

      (assoc 2 @) ) )

(de scoreDumb (Hnd)
   (co 'gen-hand-explode) # reset gen-hand-explode co
   (make
      (while (gen-hand-explode Hnd)
         (link (score-hand-unwilded @)) ) ) )


(or T
   (hand-explode '(C2 W4 W7 WT WK))
   (scoreDumb '(C2 W4 W7 WT WK))
)

(or T
   (when *Dbg
      (test
         '(FiveOfAKind 2)
         (scoreDumb '(C2 W4 W7 WT WK)) ) ) )

# Hnd '(CK W4 C4 W7 C7) is CdS '((4) (4 . W4) (7) (7 . W7) (13)) Suit becomes (<rank>) wildcard (<rank> . WSym)
# rank tie suit sorts before wildcard
# ace is (1), straight logic handles possible ace high
(de score (Hnd)
   #(println "Dumb Hnd" Hnd)
   (when (pick not Hnd) (quit "NIL IN Hnd"))
   (let (CdL  (sort (mapcar '((C)
                  (cond
                     ((find == WILDS C) (cons (last (val C)) C))
                     ((== C 'CA) (cons 1))
                     (T (cons (val C))) ) ) Hnd) ) )
      # find sets/runs 5 4 or 3 of a kind (full house and 2 pair not possible, due to quads and trip always being the better option then)
      # find first suit card with a following wildcard, and add all following wildcards, due to sorting this will be the highest and longest possible run
      (let (IsFlush (not (find cdr CdL)) # no wildcards == all suited == flush
            (RunLen . (RunRk)) (and (not IsFlush)
                                 (seek '(((Ci Cj))
                                          (cdr Cj) ) # Ci is suit or wildcard, followed by wildcard Cj
                                       CdL)
                                 # all following (equal or higher) wildcards form the run
                                 (cons (inc (cnt cdr (cdr @))) (car @)) )
            # find straights
            CdLs (if (== (caar CdL) 1) # if hand has an ace, also check the version where it plays as highest card
                   (list CdL (append (cdr (copy CdL)) (list (14))))
                   (list CdL) )
            StraightRk (and (maxi '((CdL)
                                    (let (StartRk (caar CdL)
                                          WantedRk (inc StartRk)) # next wanted for straight is first card (either suit or wildcard) + 1
                                       (++ CdL)
                                       (loop
                                          (T (not CdL) (dec WantedRk)) # done all 5 cards and found straight upto WantedR
                                          (NIL (if (cdar CdL) # looking at wildcard
                                                (if (<= WantedRk (caar CdL)) # use wildcard as wanted Rk
                                                  (t (++ CdL)
                                                     (inc 'WantedRk) )
                                                  # in this case wildcard is same as previous card (for example CK WK)
                                                  # use the wildcard as lowest Rk in the straight ("consider it put in the front")
                                                  # hence WantedRk stays the same
                                                  (if (< 1 StartRk)
                                                    (t (++ CdL)
                                                       (dec 'StartRk) )
                                                    NIL # straight not possible, can't start lower than an Ace
                                                  ) )
                                                # looking at suit card
                                                (if (or (== WantedRk (caar CdL))
                                                       # looking at suited card that is not the next wanted card,
                                                       # check if there is a wildcard that can work in its place
                                                       # and if so swap the two in the hand order
                                                       (and
                                                          (find cdr CdL) # find wildcard
                                                          (setq CdL (cons @ (delete @ CdL) ) ) ) )
                                                  (t (++ CdL)
                                                     (inc 'WantedRk) )
                                                  NIL # done straight is not possible
                                                  ) ) )
                                           ) ) )
                                       CdLs )
                                    @@ # max value from maxi
                                    ) )
                              (cond
                                 ((and (== StraightRk 14) IsFlush)(list 'Royal))
                                 ((== RunLen 5) (list 'FiveK RunRk))
                                 ((and StraightRk IsFlush) (list 'StrFl StraightRk))
                                 ((== RunLen 4) (list 'FourK RunRk))
                                 (StraightRk  (list 'Strgt StraightRk))
                                 (IsFlush  (list 'Flush (car (last (last CdLs))))) # for flush use A as high card, hence going thru CdLs
                                 ((== RunLen 3) 
                                    #{ 
                                    (cond
                                     ((<= 7 RunRk)
                                       (list 'Trp7b RunRk))
                                     ((= 6 RunRk)
                                       (list 'Trp6 RunRk))
                                     ((= 5 RunRk)
                                       (list 'Trp5 RunRk))
                                     (T
                                       (list 'TrpLw RunRk) ) )
                                    }#
                                     (list 'Trips RunRk) )
                                 ((== RunLen 2) (list 'OnePr RunRk) )
                                 (T (list 'HighC (car (last (last CdLs)))))
                                 ) ) ) )


(de countComb ()
   (out "combs.txt"
      (let (Freqs NIL
            Cnt 0)
         (for Cd1 DECK
            (for Cd2 (diff (memq Cd1 DECK) (list Cd1))
               (for Cd3 (diff (memq Cd2 DECK) (list Cd1 Cd2))
                  (for Cd4 (diff (memq Cd3 DECK) (list Cd1 Cd2 Cd3))
                     (for Cd5 (diff (memq Cd4 DECK) (list Cd1 Cd2 Cd3 Cd4))
                        (let (Hnd (list Cd1 Cd2 Cd3 Cd4 Cd5)
                              ScoreDumb (best-score (scoreDumb Hnd))
                              (Comb Rk) ScoreDumb
                              Comb (if (= Comb 'Trips)
                                    (pack "Trp" Rk)
                                     Comb)
                              Score (score Hnd) )
                           (println Hnd ScoreDumb Score (= ScoreDumb Score))
                          (unless (= ScoreDumb Score)
                             (println "FAIL " Hnd ScoreDumb Score)
                             (quit "SCORE MATCH FAIL") )
                           (accu 'Freqs Comb 1)
                           (inc 'Cnt)
                           )
                        ) ) ) ) )
         Freqs
         # Cnt
         ) ) )

# (countComb)
# (pretty (by cdr sort @))

#{(("Royal" . 1)
   ("FiveK" . 4)
   ("StrFl" . 9)
   ("HighC" . 139)
   ("FourK" . 198)
   ("Strgt" . 349)
   ("Flush" . 1277)
   ("Trips" . 1327)
   ("OnePr" . 2884) ))
}#

(de countDoubleDraw ()
   (prog # out  NIL # "double_draw.txt"
      (let (Freqs NIL
            Cnt 0)
         (for Cd1 DECK
            (for Cd2 (diff (memq Cd1 DECK) (list Cd1))
               (for Cd3 (diff (memq Cd2 DECK) (list Cd1 Cd2))
                  (for Cd4 (diff (memq Cd3 DECK) (list Cd1 Cd2 Cd3))
                     (for Cd5 (diff (memq Cd4 DECK) (list Cd1 Cd2 Cd3 Cd4))
                        (let (Hnd (list Cd1 Cd2 Cd3 Cd4 Cd5)
                              )
                           # keep all 5
                           (let (#_ (println "Keep5" Hnd)
                                 (Comb . Rk) (score Hnd) )
                              (inc 'Cnt)
                              (accu 'Freqs Comb 1)
                              )

                           # redraw 1
                              (for Pos 5
                                 (for Cd6 (diff DECK Hnd)
                                    (let (Hnd (place Pos Hnd Cd6)
                                          #_ (println "Redraw1" Hnd)
                                          (Comb . Rk) (score Hnd) )
                                       (inc 'Cnt)
                                       (accu 'Freqs Comb 1)
                                       ) ) )

                           # redraw 2
                              (for (P1 1 (<= P1 5) (inc P1))
                                 (for (P2 (inc P1) (<= P2 5) (inc P2))
                                    (for Cd6 (diff DECK Hnd)
                                       (for Cd7 (diff (memq Cd6 DECK) (cons Cd6 Hnd))
                                          (let (Hnd (and (place P1 Hnd Cd6)
                                                         (place P2 @ Cd7) )
                                                #_ (println "Redraw2" Hnd P1 P2 Cd6 Cd7)
                                                (Comb . Rk) (score Hnd))
                                             (inc 'Cnt)
                                            (accu 'Freqs Comb 1) 
                                             ) ) ) ) )

                           # redraw 3 / keep 2
                              (for (P1 1 (<= P1 5) (inc P1))
                                 (for (P2 (inc P1) (<= P2 5) (inc P2))
                                    (for Cd6 (diff DECK Hnd)
                                       (for Cd7 (diff (memq Cd6 DECK) (cons Cd6 Hnd))
                                          (for Cd8 (diff (memq Cd7 DECK) (cons Cd6 (cons Cd7 Hnd)))
                                             (let (Hnd (list (get Hnd P1) (get Hnd P2) Cd6 Cd7 Cd8)
                                                   #_ (println "Redraw3" Hnd)
                                                   (Comb . Rk) (score Hnd) )
                                                (inc 'Cnt)
                                               (accu 'Freqs Comb 1) 
                                                ) ) ) ) ) )

                           # redraw 4 / keep 1
                              (for (P1 1 (<= P1 5) (inc P1))
                                 (for Cd6 (diff DECK Hnd)
                                    (for Cd7 (diff (memq Cd6 DECK) (cons Cd6 Hnd))
                                       (for Cd8 (diff (memq Cd7 DECK) (cons Cd6 (cons Cd7 Hnd)))
                                          (for Cd9 (diff (memq Cd8 DECK) (cons Cd6 (cons Cd7 (cons Cd8 Hnd))))
                                             (let (Hnd (list (get Hnd P1) Cd6 Cd7 Cd8 Cd9)
                                                   #_ (println "Redraw4" Hnd)
                                                   (Comb . Rk) (score Hnd) )
                                                (inc 'Cnt)
                                              (accu 'Freqs Comb 1) 
                                                ) ) ) ) ) )

                           # redraw 5
                              (for Cd6 (diff DECK Hnd)
                                 (for Cd7 (diff (memq Cd6 DECK) (cons Cd6 Hnd))
                                    (for Cd8 (diff (memq Cd7 DECK) (cons Cd6 (cons Cd7 Hnd)))
                                       (for Cd9 (diff (memq Cd8 DECK) (cons Cd6 (cons Cd7 (cons Cd8 Hnd))))
                                          (for Cd10 (diff (memq Cd9 DECK) (cons Cd6 (cons Cd7 (cons Cd8 (cons Cd9 Hnd)))))
                                             (let (Hnd (list Cd6 Cd7 Cd8 Cd9 Cd10)
                                                   #_ (println "Redraw5" Hnd)
                                                   (Comb . Rk) (score Hnd) )
                                                (inc 'Cnt)
                                               (accu 'Freqs Comb 1) 
                                                ) ) ) ) ) )
                    ) ) ) ) ) )
         (list Freqs Cnt)
         # Cnt
         ) ) )
#{
(println "Start" (stamp))
(prog
   (println "Start countDoubleDraw")
   (prog1 (countDoubleDraw)
      (setq F @)
      (println "End" (stamp))
      (pretty @))
   )
}#
#(countComb)


#{
(((HighC . 860132)
  (FiveK . 24752)
  (Royal . 6188)
  (FourK . 1225224)
  (Trp7b . 1893528)
  (TrpLw . 6317948)
  (OnePr . 17846192)
  (Strgt . 2159612)
  (Flush . 7902076)
  (StrFl . 55692) )
   38291344 ))
}#
