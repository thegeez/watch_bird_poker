(symbols 'lcd 'pico)

# Weekday 1
(de s0A 1) # todo find segments
(de s0B 2)
(de s0C 3)
(de s0D 4)
(de s0E 5)
(de s0F 6)
(de s0G 7)
(de s0H 9) # inner vert bar top
(de s0I 10) # inner vert bar bottom
(de s0 . (s0A s0B s0C s0D s0E s0F s0G s0H s0I))

# Weekday 2
(de s1A 1) # todo find segments
(de s1B 2)
(de s1C 3)
(de s1D 4)
(de s1E 5)
(de s1F 6)
(de s1G 7)
(de s1 . (s1A s1B s1C s1D s1E s1F s1G))

# Day digits 1
(de s2A 1) # todo find segments
(de s2B 2)
(de s2C 3)
(de s2D 4)
(de s2E 5)
(de s2F 6)
(de s2G 7)
(de s2 . (s2A s2B s2C s2D s2E s2F s2G))

# Day digits 2
(de s3A 1) # todo find segments
(de s3B 2)
(de s3C 3)
(de s3D 4)
(de s3E 5)
(de s3F 6)
(de s3G 7)
(de s3 . (s3A s3B s3C s3D s3E s3F s3G))

# hour 1
(de s4A (com1 . seg18)) # with s4D
(de s4B (com2 . seg19))
(de s4C (com0 . seg19))
(de s4D (com1 . seg18)) # with s4A
(de s4E (com0 . seg18))
(de s4F (com2 . seg18))
(de s4G (com1 . seg19))
(de s4 . (s4A s4B s4C s4D s4E s4F s4G))

# hour 2
(de s5A (com2 . seg20))
(de s5B (com2 . seg21))
(de s5C (com1 . seg21))
(de s5D (com0 . seg21))
(de s5E (com0 . seg20))
(de s5F (com1 . seg17))
(de s5G (com1 . seg20))
(de s5 . (s5A s5B s5C s5D s5E s5F s5G))

# hour 3
(de s6A (com0 . seg22)) # with 6D
(de s6B (com2 . seg23))
(de s6C (com0 . seg23))
(de s6D (com0 . seg22)) # with 6A
(de s6E (com1 . seg22))
(de s6F (com2 . seg22))
(de s6G (com1 . seg23))
(de s6 . (s6A s6B s6C s6D s6E s6F s6G))

# hour 4
(de s7A (com2 . seg1))
(de s7B (com2 . seg10))
(de s7C (com0 . seg1))
(de s7D (com0 . seg0))
(de s7E (com1 . seg0))
(de s7F (com2 . seg0))
(de s7G (com1 . seg1))
(de s7 . (s7A s7B s7C s7D s7E s7F s7G))

# second 1
(de s8A (com2 . seg2))
(de s8B (com2 . seg3))
(de s8C (com0 . seg4))
(de s8D (com0 . seg3))
(de s8E (com0 . seg2))
(de s8F (com1 . seg2))
(de s8G (com1 . seg3))
(de s8 . (s8A s8B s8C s8D s8E s8F s8G))

# second 2
(de s9A (com2 . seg4))
(de s9B (com2 . seg5))
(de s9C (com1 . seg6))
(de s9D (com0 . seg6))
(de s9E (com0 . seg5))
(de s9F (com1 . seg4))
(de s9G (com1 . seg5))
(de s9 . (s9A s9B s9C s9D s9E s9F s9G))


#{
    A _
  F |   | B
    G _
  E |   | C
    D _
}#

# LcdState is sym with props LcdState -> com<N> -> seg<N> -> T
(de prUW (ShowB)
   (or (and ShowB "_")
       " ") )
(de prBW (ShowB)
   (or (and ShowB "|")
       " ") )
(de prUL (showUL B)
   (if showUL
      (pack "\e[0;4m" B "\e[24m")
      B ) )

# digits 4-7 are HH:MM 8-9 is ss
# 4-7 have double length side bars to be bigger then the second digits
(de prLcd (LcdState)
  (prinl "     " " " (prUW (get LcdState 's0A)) "    " (prUW (get LcdState 's1A)) "      " "   " (prUW (get LcdState 's2A)) "    " (prUW (get LcdState 's3A)) " " " ;")
  (prinl "     " (prBW (get LcdState 's0F)) (prUL (get LcdState 's0G) (prBW (get LcdState 's0H))) (prBW (get LcdState 's0B)) "  " (prBW (get LcdState 's1F)) (prUW (get LcdState 's1G)) (prBW (get LcdState 's1B)) "       " (prBW (get LcdState 's2F)) (prUW (get LcdState 's2G)) (prBW (get LcdState 's2B)) "  " (prBW (get LcdState 's3F)) (prUW (get LcdState 's3G)) (prBW (get LcdState 's3B)) " ;")
  (prinl "     " (prBW (get LcdState 's0E)) (prUL (get LcdState 's0D) (prBW (get LcdState 's0I))) (prBW (get LcdState 's0C)) "  " (prBW (get LcdState 's1E)) (prUW (get LcdState 's1D)) (prBW (get LcdState 's1C)) "       "  (prBW (get LcdState 's2E)) (prUW (get LcdState 's2D)) (prBW (get LcdState 's2C)) "  " (prBW (get LcdState 's3E)) (prUW (get LcdState 's3D)) (prBW (get LcdState 's3C)) " ;")

  (prinl " " (prUW (get LcdState 's4A)) "   "
         " " (prUW (get LcdState 's5A)) "   "
         " " (prUW (get LcdState 's6A)) "   "
         " " (prUW (get LcdState 's7A)) "            ;"
)
  (prinl (prBW (get LcdState 's4F)) " " (prBW (get LcdState 's4B))
         "  " (prBW (get LcdState 's5F)) " " (prBW (get LcdState 's5B))
         "  " (prBW (get LcdState 's6F)) " " (prBW (get LcdState 's6B))
         "  " (prBW (get LcdState 's7F)) " " (prBW (get LcdState 's7B))
         "           ;")
  (prinl (prBW (get LcdState 's4F)) (prUW (get LcdState 's4G)) (prBW (get LcdState 's4B))
    "  " (prBW (get LcdState 's5F)) (prUW (get LcdState 's5G)) (prBW (get LcdState 's5B))
    "  " (prBW (get LcdState 's6F)) (prUW (get LcdState 's6G)) (prBW (get LcdState 's6B))
    "  " (prBW (get LcdState 's7F)) (prUW (get LcdState 's7G)) (prBW (get LcdState 's7B))
    "   " (prUW (get LcdState 's8A))
    "    " (prUW (get LcdState 's9A))
    "  ;"
         )
  (prinl (prBW (get LcdState 's4E)) " " (prBW (get LcdState 's4C))
         "  " (prBW (get LcdState 's5E)) " " (prBW (get LcdState 's5C))
         "  " (prBW (get LcdState 's6E)) " " (prBW (get LcdState 's6C))
         "  " (prBW (get LcdState 's7E)) " " (prBW (get LcdState 's7C))
         "  " (prBW (get LcdState 's8F)) (prUW (get LcdState 's8G)) (prBW (get LcdState 's8B))
         "  " (prBW (get LcdState 's9F)) (prUW (get LcdState 's9G)) (prBW (get LcdState 's9B)) " ;" )
  (prinl (prBW (get LcdState 's4E)) (prUW (get LcdState 's4D)) (prBW (get LcdState 's4C))
         "  "(prBW (get LcdState 's5E)) (prUW (get LcdState 's5D)) (prBW (get LcdState 's5C))
         "  "(prBW (get LcdState 's6E)) (prUW (get LcdState 's6D)) (prBW (get LcdState 's6C))
         "  "(prBW (get LcdState 's7E)) (prUW (get LcdState 's7D)) (prBW (get LcdState 's7C))
         "  "(prBW (get LcdState 's8E)) (prUW (get LcdState 's8D)) (prBW (get LcdState 's8C))
         "  "(prBW (get LcdState 's9E)) (prUW (get LcdState 's9D)) (prBW (get LcdState 's9C))
 " ;")   )


(de setChar (LcdSym LocSym Chr)
   (let (BindE (mapcar cons '(sA sB sC sD sE sF sG sH sI) (val LocSym)))
      (bind BindE
         (case Chr
            (("#" "F" "P" "R" "S" "_" "A" "0" "2" "3" "5" "6" "8" "9" "T" "J" "WT")
               (put LcdSym sA T)
               ))
         (case Chr
            (("#" "d" "H" "P" "R" "U" "W" "A" "0" "1" "2" "3" "4" "8" "9" "J" "Q" "W4" "WT" "WK")
               (put LcdSym sB T)
               ))
         (case Chr
            (("#" "b" "d" "n" "H" "S" "U" "W" "A" "0" "1" "3" "4" "5" "6" "7" "8" "9" "T" "J" "WK")
               (put LcdSym sC T)
               ))
         (case Chr
            (("#" "b" "d" "t" "L" "S" "U" "W" "_" "0" "2" "3" "5" "6" "8" "9" "T" "J" "WT")
               (put LcdSym sD T)
               ))
         (case Chr
            (("#" "b" "d" "i" "n" "r" "t" "F" "H" "I" "L" "P" "R" "U" "W" "A" "0" "2" "6" "8" "T" "K" "W4" "W7")
               (put LcdSym sE T)
               ))
         (case Chr
            (("#" "b" "t" "F" "H" "I" "L" "P" "R" "S" "U" "W" "A" "0" "4" "5" "6" "8" "9" "Q" "K" "W4" "WT")
               (put LcdSym sF T)
               ))
         (case Chr
            (("#" "b" "d" "n" "r" "t" "F" "H" "P" "R" "S" "-" "A" "2" "3" "4" "5" "6" "7" "8" "9" "T" "Q" "K" "W4" "W7" "WT" "WK")
               (put LcdSym sG T)
               ))
         (case Chr
            (("#" "W")
               (put LcdSym sH T)
               ))
         (case Chr
            (("#" "R" "W")
               (put LcdSym sI T)
               ))
        ) ) )
