(load "bird.l")
(symbols 'bird_c 'bird 'pico)

(de CombInt
   (Royal . 9)
   (FiveK . 8)
   (StrFl . 7)
   (FourK . 6)
   (Strgt . 5)
   (Flush . 4)
   (Trips . 3)
   (OnePr . 2)
   (HighC . 1) )

(de cscore (Hand)
   (let ((H1 H2 H3 H4 H5) Hand
         _ (println "Hand CScore" H1 H2 H3 H4 H5 Hand)
         RetInt (native "./bird.so" "score" 'I H1 H2 H3 H4 H5)
         CombI (>> 4 RetInt)
         Comb (car (rassoc CombI CombInt))
         HighC (& 15 RetInt)
         HighC (if (=0 HighC)
                  NIL
                  HighC ) )
   (println 'RetInt RetInt)
     (if HighC
         (list Comb HighC)
         (list Comb) ) ) )

(de intHands ()
   (let (Cnt 0
         FailCnt 0)
      (for (H1 1 (<= H1 13) (inc H1))
         (for (H2 (inc H1) (<= H2 14) (inc H2))
            (for (H3 (inc H2) (<= H3 15) (inc H3))
               (for (H4 (inc H3) (<= H4 16) (inc H4))
                  (for (H5 (inc H4) (<= H5 17) (inc H5))
                     (inc 'Cnt)
                     (let (Hand (list H3 H2 H1 H5 H4)
                           BHand (mapcar '((HI) (get bird~DECK HI)) Hand)
                           BirdScore (bird~score BHand)
                           (BSc BHi) BirdScore
                           CHand Hand
                           CScore (cscore CHand)
                           (CSc CHi) CScore)
                        (unless (= BirdScore CScore)
                           (inc 'FailCnt)
                           (println "MISMATCH: " BHand BSc BHi BirdScore CHand CSc CHi CScore) )
                         ) ) ) ) ) )
      (println (list Cnt FailCnt)) ) )

(intHands)

