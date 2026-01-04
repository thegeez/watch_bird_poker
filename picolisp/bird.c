// gcc bird.c -o bird.so -shared
#define CA 1
#define C2 2
#define C3 3
#define C4 4
#define C5 5
#define C6 6
#define C7 7
#define C8 8
#define C9 9
#define CT 10
#define CJ 11
#define CQ 12
#define CK 13
#define W4 14
#define W7 15
#define WT 16
#define WK 17
// CAHigh only used in output, not in hnd, doesn't clash with W4
#define CAHigh 14

int is_wild(int);
inline int is_wild(int c) {
   return c >= W4;
}

int wildcard_rank(int);
inline int wildcard_rank(int c) {
   if (c == W4) {
      return 4;
   } else if (c == W7) {
      return 7;
   } else if (c == WT) {
      return 10;
   } else if (c == WK) {
      return 13;
   } else {
      return c;
   }
}

#define Royal 9
#define FiveK 8
#define StrFl 7
#define FourK 6
#define Strgt 5
#define Flush 4
#define Trips 3
#define OnePr 2
#define HighC 1

void handsort(int[]);

void handsort(int hnd[]) {
   int i = 0;
   int j = 0;
   int swap = 0;
   for (i = 0; i < 4; i++) {
      swap = 0; // card is never 0
      for (j = 0; j < 4 - i; j++) {
         if (hnd[j] > hnd[j+1]) {
            swap = hnd[j+1];
            hnd[j+1] = hnd[j];
            hnd[j] = swap;
         }
      }
      if (!swap) {
         break;
      }
   }
}

int highcard(int[], int);

// hnd is sorted
int highcard(int hnd[], int wildcard_count) {
   if (hnd[0] == CA) {
      return CAHigh;
   } else {
      int highc = hnd[4];
      if (highc >= W4) {
        highc = wildcard_rank(highc);
        // check if the highest non-wildcard is better
        if (hnd[4 - wildcard_count] > highc) {
          highc = hnd[4 - wildcard_count];
        }
      }
      return highc;
   }
}

int score(int, int, int, int, int);

int score(int h0, int h1, int h2, int h3, int h4) {
   int hnd[] = {h0, h1, h2, h3, h4};
   handsort(hnd);

   // find flush
   int is_flush = 1; // assume true unless hnd has any wildcard

   int lowest_wildcard = 0; // needed for run/Nkind detection
   int second_lowest_wildcard = 0;
   int wildcard_count = 0;
   int i = 0;
   for (i = 0; i < 5; i++) {
      if (is_wild(hnd[i])) {
        is_flush = 0;
        lowest_wildcard = hnd[i];
        if (i < 4) {
         second_lowest_wildcard = hnd[i+1];
        }
        wildcard_count = 5 - i;
        break;
      }
   }

   // find 5,4,3 (of a kind), 2 (pair)
   int run_length = 0;
   int run_rank = 0;
   if (lowest_wildcard) { // aka when not a flush
    // can make at least wildcard_count of a kind with rank lowest_wildcard
    // if there's a card lower or equal to lowest_wildcard there's a wildcard_count+1 of a kind
    run_rank = wildcard_rank(lowest_wildcard);
    for (i = 4 - wildcard_count; i >= 0; i--) { // high to low non-wildcards
      if (hnd[i] <= run_rank) {
         run_rank = hnd[i];
         run_length = wildcard_count + 1;
         break;
      }
    }
    if (!run_length) { // no run found yet
       // check if there is a card to make a better rank to replace the lowest_wildcard in the N of a kind
       if (second_lowest_wildcard) {
         run_rank = wildcard_rank(second_lowest_wildcard);
         for (i = 4 - wildcard_count; i >= 0; i--) {
            if (hnd[i] <= run_rank) {
               run_rank = hnd[i];
               run_length = wildcard_count;
               break;
            }
         }
       }
       if (!run_length) {
         run_rank = wildcard_rank(lowest_wildcard);
         run_length = wildcard_count;
       }
    }
   }

   int straight_rank = 0;
   if (is_flush) { // straight without wildcards is always a straight flush
      if (hnd[0] == (hnd[4] - 4)) {
         straight_rank = hnd[4];
      } else if (hnd[0] == CA && hnd[1] == CT) {
         straight_rank = CAHigh;
      }
   } else { // straight with wildcards
     if (hnd[0] == CA) {
       if ((lowest_wildcard == WT && hnd[1] >= CJ) ||
           (lowest_wildcard == WK && hnd[1] >= CT)) {
         straight_rank = CAHigh;
       }
     }
     if (!straight_rank) {
       int highest_suit_card = hnd[4 - wildcard_count];
       if ((highest_suit_card - hnd[0]) <= 4) { // highest and lowest non-wildcard can form a straight
         int straight_rank_low_bound = highest_suit_card >= 5 ? highest_suit_card : 5;
         for (i = hnd[0] + 4; i >= straight_rank_low_bound; i--) {
            // try all possible end ranks (from high to low) and see if the available wildcards can fill the gaps
            int wanted_rank = i;
            int wanted_rank_low = i - 4;
            if (lowest_wildcard < wanted_rank_low) {
               continue;
            }
            int suit_i = 4 - wildcard_count;
            int wildcard_i = 4;
            int wildcard_i_low_bound = suit_i + 1;
            while (wanted_rank >= wanted_rank_low) {
               if (wanted_rank == hnd[suit_i]) {
                  if (suit_i > 0) {
                     suit_i--;
                  };
               } else if (wanted_rank <= wildcard_rank(hnd[wildcard_i])) {
                  if (wildcard_i > wildcard_i_low_bound) {
                     wildcard_i--;
                  };
               } else {
                  break; // no suit or wildcard to be the wanted_rank
               }
               wanted_rank--;
            }
            if (wanted_rank < wanted_rank_low) {
               straight_rank = i;
               break;
            }
         }
       }
     }
   }
   int combi = 0;
   int highc = 0;

   if (is_flush && (straight_rank == CAHigh)) {
      combi = Royal;
   } else if (run_length == 5) {
      combi = FiveK;
      highc = run_rank;
   } else if (is_flush && straight_rank) {
      combi = StrFl;
      highc = straight_rank;
   } else if (run_length == 4) {
      combi = FourK;
      highc = run_rank;
   } else if (straight_rank) {
      combi = Strgt;
      highc = straight_rank;
   } else if (is_flush) {
      combi = Flush;
      highc = highcard(hnd, 0);
   } else if (run_length == 3) {
      combi = Trips;
      highc = run_rank;
   } else if (run_length == 2) {
      combi = OnePr;
      highc = run_rank;
   } else {
      combi = HighC;
      highc = highcard(hnd, wildcard_count);
   }
//   printf("CHand: %d %d %d %d %d Sorted: %d %d %d %d %d\n", h0, h1, h2, h3, h4, hnd[0], hnd[1], hnd[2], hnd[3], hnd[4]);
//   printf("Combi: %d HighC: %d\n", combi, highc);
   return ((combi << 4) | highc) ;
}
