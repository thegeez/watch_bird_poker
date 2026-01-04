(load "bird.l")
(load "lcd.l")
(symbols 'cli 'bird 'lcd 'pico)

(load "@lib/term.l") # no symbol namespace

(setq *Deck NIL) # full deck to cards remaining
(setq *Hand NIL) # cards currently in hand
(setq *Discards NIL)
(setq *Balance 0)

# TopLeft = Light button
# BottomLeft = Mode button (= close watchface and move to next)
# BottomRight = Alarm button

# 'Welcome -BottomRight-> 'WelcomeBalance -BR-> 'WelcomeComboRoyal -BR-> 'WelcomeCombos -BR-> 'WelcomeCards -Br-> loop
#  | TopLeft               | TL                 | TL                      | TL                |
#  V                       V                    V                         V                   V
# 'Deal <=> Tick -bust-> 'Bust -TL-> 'Welcome
#  | Tick
#  V
# 'Select
#  | TopLeft
#  V
# 'Redraw <=> Tick
#  |
#  V
# 'Settle -BottomRight-> 'SettlePrize -BR-> 'SettleBalance -BR-> 'SettleJackPot -BR-> loop to 'Settle
#  | TopLeft             | TopLeft          | Topleft            | TopLeft
#  V                     V                  V                    V
# loop to 'Deal

(setq *State NIL)
(setq *TickCnt NIL) # tick count for animations or subscreen index
(setq *SelectI NIL) # idx of current card that can be selected
(setq *SettleScore NIL)
(setq *SettlePrize NIL)
(setq *DispNumL NIL) # the number of shifts to display all digits in Num by showing max 6 at a time

(setq *Lcd NIL)

(de Payouts
   (Royal 250)
   (FiveK 30)
   (StrFl 10)
   (FourK 4)
   (Strgt 3)
   (Flush 2)
   (Trips 1)
   (OnePr 0)
   (HighC 0) )

# Ranks in Weekday Digits and highest card in day digit 3
# Royal           rF
# FiveOfAKind     5|-
# Straight Flush  SF
# FourOfAKind     4|-
# Straight        St
# ThreeOfAKind    3|-
# Pair            P
# Flush           FL
# HighC           HI
(de dispComb (Comb)
   (case Comb
      (Royal '("r" "F"))
      (FiveK '("5" "K"))
      (StrFl '("S" "F"))
      (FourK '("4" "K"))
      (Strgt '("S" "t"))
      (Flush '("F" "L"))
      (Trips '("3" "K"))
      (OnePr '("P" NIL))
      (HighC '("H" "I")) ) )

(de prDisp (Disp)
   (putl *Lcd NIL)
   (mapc '((Seg C)
         (setCard *Lcd Seg C))
      '(lcd~s0 lcd~s1 lcd~s2 lcd~s3 lcd~s4 lcd~s5 lcd~s6 lcd~s7 lcd~s8 lcd~s9)
      Disp)
   (setChar *Lcd 's0 (get Disp 1))
   (setChar *Lcd 's1 (get Disp 2))
   (setChar *Lcd 's3 (get Disp 4))
   (prLcd *Lcd) )

(de dispNum (N *TickCnt)
   (if (< N 1000000)
      (chop (align 6 (chop N)))
      (if (=0 *TickCnt)
         (cons " " (head 5 (chop N))) # need a space before most significant digit, otherwise won't know where scroll starts
         (head 6 (nth (chop N) *TickCnt)) ) ) )

(de setState (State)
   (setq *State State)
   (handleEvent 'Init) )

(de handleEventWelcome (Ev)
   (case Ev
      (Init
         (when (=0 *Balance)
            (setq *Balance 20) ) )
      (TopLeft
         (setState 'Deal) )
      (BottomRight
         (setState 'WelcomeBalance) ) )
   (clear)
   (prDisp '(NIL NIL NIL NIL NIL "b" "i" "r" "d" "P"))
   (prinl "q = TopLeft = Light button Deal/redraw cards")
   (prinl "s = BottomRight = Alarm button Move to next subscreen with more info or move selector left")
   (prinl "ESC = quit") )

(de handleEventWelcomeBalance (Ev)
   (handleEventTitleNumber Ev '("b" "A" NIL "L") *Balance 'WelcomeComboRoyal) )

(de handleEventWelcomeComboRoyal (Ev)
   (handleEventTitleNumber Ev (append (dispComb 'Royal) '(NIL NIL)) *Jackpot 'WelcomeCombos) )

(de handleEventWelcomeCombos (Ev)
   (case Ev
      (Init
         (setq *TickCnt 1) )
      (TopLeft
         (setState 'Deal) )
      (BottomRight
         (inc '*TickCnt)
         (when (= (length Payouts) *TickCnt)
            (setState 'WelcomeCards)) ) )
   (case Ev
      ((Init BottomRight)
         (when (< 0 *TickCnt (length Payouts))
            (let ((Comb Prize) (get Payouts (inc *TickCnt))
                  DispComb (dispComb Comb)
                  DispNum (dispNum Prize 0))
               (clear)
               (prDisp (append DispComb '(NIL NIL) DispNum)) ) ) ) ) )

(de handleEventWelcomeCards (Ev)
   (case Ev
      (Init
         (setq *TickCnt 0) )
      (TopLeft
         (setState 'Deal) )
      (BottomRight
         (inc '*TickCnt)
         (when (= 4 *TickCnt)
            (setState 'Welcome)) ) )
   (case Ev
      ((Init BottomRight)
         (when (< *TickCnt 4)
            (clear)
            (case *TickCnt
               (0 (prDisp (append '("S" "U" "i" "t") '(NIL bird~CA bird~C2 bird~C3 bird~C4 bird~C5))))
               (1 (prDisp (append '("S" "U" "i" "t") '(NIL bird~C6 bird~C7 bird~C8 bird~C9 bird~CT))))
               (2 (prDisp (append '("S" "U" "i" "t") '(NIL NIL NIL bird~CJ bird~CQ bird~CK))))
               (3 (prDisp (append '("W" "1" "i" "d") '(NIL NIL bird~W4 bird~W7 bird~WT bird~WK)))) ) )
      ) ) )

(de handleEventDealAndRedraw (Ev NextState)
   (case Ev
      (Init
         (setq *TickCnt 0) )
      (Tick
         (when *TickCnt
            (inc '*TickCnt)
            (when (= *TickCnt 4)
               (off *TickCnt) ) )
          )
      (TopLeft
         (off *TickCnt)
         (setState NextState) ) )
   
   (if *TickCnt
      (let (Disp (mapcar '((C Discard)
                           (ifn Discard
                              C
                              (case *TickCnt
                                 ((0 2 4) 'B0)
                                 (T 'B1) ) ) ) *Hand *Discards)
            Disp (append '(NIL NIL NIL NIL NIL) Disp) ) # use 3 large digits and 2 small ones, skip first
         (clear)
         (prDisp Disp) )

      (setState NextState) ) )

(de handleEventDeal (Ev)
   (case Ev
      (Init
         (if (=0 *Balance)
            (setState 'Bust)
            #
            (setq *SettleScore NIL)
            (setq *SettlePrize NIL)
            (setq *Discards '(T T T T T))
            (setq *Deck (copy bird~DECK))
            (setq *Hand NIL)
            (do 5
               (let (CIdx (rand 1 (length *Deck))
                     C (get *Deck CIdx) )
                  (setq *Deck (remove CIdx *Deck))
                  (push '*Hand C) ) )
#          (setq *Hand '(bird~CA bird~CK bird~CQ bird~CJ bird~CT))
            (dec '*Balance)
            (inc '*Jackpot)
            (handleEventDealAndRedraw Ev 'Select)) )
      (T (handleEventDealAndRedraw Ev 'Select)) ) )

(de _selectNext ()
   (inc '*SelectI)
   (when (= *SelectI 6)
      (zero *SelectI) )
   # reset *TickCnt to start blink animation immediately on next card
   (zero *TickCnt) )

(de handleEventSelect (Ev)
   (case Ev
      (Init
         (setq *Discards '(NIL NIL NIL NIL NIL))
         (zero *TickCnt)
         (zero *SelectI) )
      (Tick
         (inc '*TickCnt)
         (when (= *TickCnt 4)
            (zero *TickCnt) ) )
      (BottomRight
         (_selectNext) )
      (TopLeft
         (if (=0 *SelectI)
            (let NextState (if (find prog *Discards) # only redraw if any card discarded
                  'Redraw
                  'Settle)
               (setState NextState) )
            # mark card for discard
            (setq *Discards
               (place *SelectI *Discards (not (get *Discards *SelectI))) )
            ) ) )
   (when (= *State 'Select) # skip in case of TopLeft pressed
      (let (Disp (mapcar '((I C Discard)
                  (case *TickCnt
                     (0
                        (unless (= *SelectI I)
                           C ) )
                     ((1 3)
                        (unless Discard
                           C ) )
                     (2 C)
                     ) )
               (1 2 3 4 5)
               *Hand
               *Discards )
            ZeroCursor (when (=0 *SelectI)
               (unless (= 1 *TickCnt)
                  "-" ) )
            # use 3 large and 2 small digits, select cursor perhaps in the first digit
            Disp (append '(NIL NIL NIL NIL) (list ZeroCursor) Disp) )
         (clear)
         (prDisp Disp)
         (prinl "q = TopLeft = Light button To redraw cards (pos 0/-) or mark card for discarding")
         (prinl "s = BottomRight = Alarm button Move selector to the left")
         ) ) )

(de handleEventRedraw (Ev)
   (case Ev
      (Init
         (setq *Hand
            (mapcar
               '((Discard C)
                  (if Discard
                     (let (CIdx (rand 1 (length *Deck))
                           C (get *Deck CIdx) )
                        (setq *Deck (remove CIdx *Deck))
                        C)
                     C ) )
               *Discards
               *Hand ) ) ) )
   (handleEventDealAndRedraw Ev 'Settle) )

(de _settleScore ()
   (let ((Sc HighCard) *SettleScore
         D1D2 (dispComb Sc)
         D4 (case HighCard
            ((2 3 4 5 6 7 8 9) (format HighCard))
            ((1 14) "A")
            (10 "T")
            (11 "J")
            (12 "Q")
            (13 "K")
            (T NIL) ) )
      (clear)
      (prDisp (append D1D2 '(NIL) (list D4) '(NIL) *Hand)) ) )

(de handleEventSettle (Ev)
   (case Ev
      (Init
         (unless *SettleScore # avoid rescoring, if coming back from balance screen
            (setq *SettleScore (score *Hand))
            (setq *SettlePrize (cadr (assoc (car *SettleScore) Payouts)))
            (when (= (car *SettleScore) 'Royal)
               (setq *SettlePrize *Jackpot)
               (setq *Jackpot (cadr (assoc 'Royal Payouts))) )
            (inc '*Balance *SettlePrize) )
         (_settleScore) )
      (TopLeft
         (setState 'Deal) )
      (BottomRight
         (setState 'SettlePrize) )
      ) )

(de handleEventTitleNumber (Ev Title Num NextState)
   (case Ev
      (Init
         (setq *TickCnt 0)
         (setq *DispNumL
            (let (I 0
                  Fac 1000000)
               (loop
                  (T (< Num Fac) I)
                  (inc 'I)
                  (setq Fac (* Fac 10)) ) ) ) )
      (Tick
         (when (gt0 *DispNumL)
            (inc '*TickCnt)
            (when (<= (* 2 (+ 2 *DispNumL)) *TickCnt) # slow down with 2 ticks per DispNum, and show most significant digits with space+5 digits (hence (+ 2))
               (zero *TickCnt)) ) )
      (TopLeft
         (setState 'Deal) )
      (BottomRight
         (setState NextState) ) )
      (case Ev
         ((Init Tick)
            (let (Disp (dispNum Num (/ *TickCnt 2)))
               (clear)
               (prDisp (append Title Disp)) ) ) ) )

(de handleEventSettlePrize (Ev)
   (handleEventTitleNumber Ev '("W" "i" NIL "n") *SettlePrize 'SettleBalance) )

(de handleEventSettleBalance (Ev)
   (handleEventTitleNumber Ev '("b" "A" NIL "L") *Balance 'SettleJackpot) )

(de handleEventSettleJackpot (Ev)
   (handleEventTitleNumber Ev (append (dispComb 'Royal) '(NIL NIL)) *Jackpot 'Settle) )

(de handleEventBust (Ev)
   (case Ev
      (Init
         (setq *TickCnt 0) )
      (Tick
         (inc '*TickCnt)
         (when (= *TickCnt 2)
            (zero *TickCnt) ) )
      (TopLeft
         (setState 'Welcome) ) )
   (case Ev
      ((Init Tick)
         (clear)
         (if (=0 *TickCnt)
            (prDisp '(NIL NIL NIL NIL NIL "b" "Q" "S" "t" NIL NIL))
            (prDisp '(NIL NIL NIL NIL NIL NIL NIL NIL NIL NIL NIL)) ) ) ) )

(de handleEvent (Ev)
   (case *State
      (Welcome (handleEventWelcome Ev))
      (WelcomeBalance (handleEventWelcomeBalance Ev))
      (WelcomeComboRoyal (handleEventWelcomeComboRoyal Ev))
      (WelcomeCombos (handleEventWelcomeCombos Ev))
      (WelcomeCards (handleEventWelcomeCards Ev))
      (Deal (handleEventDeal Ev))
      (Select (handleEventSelect Ev))
      (Redraw (handleEventRedraw Ev))
      (Settle (handleEventSettle Ev))
      (SettlePrize (handleEventSettlePrize Ev))
      (SettleBalance (handleEventSettleBalance Ev))
      (SettleJackpot (handleEventSettleJackpot Ev))
      (Bust (handleEventBust Ev)) ) )

(de start ()
   (setq *Deck NIL
         *Hand NIL
         *Discards '(NIL NIL NIL NIL NIL)
         *Jackpot 1234567890
         )
   (setState 'Welcome)
   (while (case (key 500)
            ("^[" NIL)
            (NIL 'Tick)
            ("q" 'TopLeft)
            ("s" 'BottomRight)
            (T T) )
      (handleEvent @) ) )

(de setCard (Lcd Sym Card)
   (setChar Lcd Sym
      (case Card
         (B0 "-") # Bn is a dealing animation back of card
         (B1 "_") # _ underscore, not space
         (bird~CA "H")
         (bird~C2 "2")
         (bird~C3 "3")
         (bird~C4 "4")
         (bird~C5 "5")
         (bird~C6 "6")
         (bird~C7 "7")
         (bird~C8 "8")
         (bird~C9 "9")
         (bird~CT "T")
         (bird~CJ "J")
         (bird~CQ "Q")
         (bird~CK "K")
         (bird~W4 "W4")
         (bird~W7 "W7")
         (bird~WT "WT")
         (bird~WK "WK")
         (T Card) ) ) )
