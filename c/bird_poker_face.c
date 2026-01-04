#include <stdlib.h>
#include <string.h>
#include <math.h>
#if __EMSCRIPTEN__
#include <time.h> // to seed random in emulator
#endif
#include "bird_poker_face.h"
#include "watch_private_display.h"

#define SCREEN_WELCOME 10
#define SCREEN_WELCOME_BALANCE 11
#define SCREEN_WELCOME_COMBO_ROYAL 12
#define SCREEN_WELCOME_COMBOS 13
#define SCREEN_WELCOME_CARDS 14
#define SCREEN_DEAL 20
#define SCREEN_SELECT 30
#define SCREEN_REDRAW 40
#define SCREEN_SETTLE  50
#define SCREEN_SETTLE_PRIZE 51
#define SCREEN_SETTLE_BALANCE 52
#define SCREEN_SETTLE_JACKPOT 53
#define SCREEN_BUST 60

#define EV_INIT 1
#define EV_TOP_LEFT 2
#define EV_BOTTOM_RIGHT 3
#define EV_TICK 4

#define Royal 9
#define FiveK 8
#define StrFl 7
#define FourK 6
#define Strgt 5
#define Flush 4
#define Trips 3
#define OnePr 2
#define HighC 1

const uint8_t PAYOUTS_LENGTH = 9;
const char* const PAYOUTS_NAMES[] = {"  ", "H1", "P ", "3K", "FL", "St", "4K", "SF", "5K", "rF"};
const uint8_t PAYOUTS_PRIZES[] = {0, 0, 0, 1, 2, 3, 4, 10, 30, 250};

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

// A a, 2, 3, 4, 5, 6, 7, 8, 9, T, J, Q, K, W4 f, W7 r, WT t, WK k
const char CARD_CHARS[] = {' ', 'H', '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'f', 'r', 't', 'k'};

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


static void handsort(int hnd[]) {
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

// hnd is sorted
static int highcard(int hnd[], int wildcard_count) {
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

static int score(int h0, int h1, int h2, int h3, int h4) {
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
   return ((combi << 4) | highc) ;
}


// returns a random integer r with 0 <= r < max
static uint8_t generate_random_number(uint8_t num_values) {
    // Emulator: use rand. Hardware: use arc4random.
#if __EMSCRIPTEN__
    return rand() % num_values;
#else
    return arc4random_uniform(num_values);
#endif
}

void bird_poker_face_setup(movement_settings_t *settings, uint8_t watch_face_index, void ** context_ptr) {
    (void) settings;
    (void) watch_face_index;
    if (*context_ptr == NULL) {
        *context_ptr = malloc(sizeof(bird_poker_face_state_t));
        memset(*context_ptr, 0, sizeof(bird_poker_face_state_t));
        // Do any one-time tasks in here; the inside of this conditional happens only at boot.
         bird_poker_face_state_t *state = (bird_poker_face_state_t *)*context_ptr;
         state->jackpot = PAYOUTS_PRIZES[Royal];
    }
#if __EMSCRIPTEN__
    // simulator only: seed the randon number generator
    time_t t;
    srand((unsigned)time(&t));
#endif
}

void bird_poker_face_activate(movement_settings_t *settings, void *context) {
    (void) settings;

    // Handle any tasks related to your watch face coming on screen.
    //watch_set_colon();
    bird_poker_face_state_t *state = (bird_poker_face_state_t *)context;
    state->screen = SCREEN_WELCOME;
}

static void setChar(uint8_t position, char chr) {
    switch (chr) {
        case '7': {
            switch (position) {
                case 3: {
                    watch_set_pixel(2,7);
                    watch_set_pixel(1,8);
                    return;
                }
                case 5: {
                    watch_set_pixel(1,21);
                    watch_set_pixel(1,20);
                    return;
                }
                case 6: {
                    watch_set_pixel(0,23);
                    watch_set_pixel(1,23);
                    return;
                }
                case 7: {
                    watch_set_pixel(0,1);
                    watch_set_pixel(1,1);
                    return;
                }
                case 8: {
                    watch_set_pixel(0,4);
                    watch_set_pixel(1,3);
                    return;
                }
                case 9: {
                    watch_set_pixel(1,6);
                    watch_set_pixel(1,5);
                    return;
                }
            }
            break;
        }
        case 'T': {
            switch (position) {
                case 3: {
                    watch_set_pixel(0,7);
                    watch_set_pixel(2,7);
                    watch_set_pixel(2,6);
                    watch_set_pixel(2,8);
                    watch_set_pixel(1,8);
                    return;
                }
                case 5: {
                    watch_set_pixel(2,20);
                    watch_set_pixel(1,21);
                    watch_set_pixel(0,21);
                    watch_set_pixel(0,20);
                    watch_set_pixel(1,20);
                    return;
                }
                case 6: {
                    watch_set_pixel(0,22);
                    watch_set_pixel(0,23);
                    watch_set_pixel(0,22);
                    watch_set_pixel(1,22);
                    watch_set_pixel(1,23);
                    return;
                }
                case 7: {
                    watch_set_pixel(2,1);
                    watch_set_pixel(0,1);
                    watch_set_pixel(0,0);
                    watch_set_pixel(1,0);
                    watch_set_pixel(1,1);
                    return;
                }
                case 8: {
                    watch_set_pixel(2,2);
                    watch_set_pixel(0,4);
                    watch_set_pixel(0,3);
                    watch_set_pixel(0,2);
                    watch_set_pixel(1,3);
                    return;
                }
                case 9: {
                    watch_set_pixel(2,4);
                    watch_set_pixel(1,6);
                    watch_set_pixel(0,6);
                    watch_set_pixel(0,5);
                    watch_set_pixel(1,5);
                    return;
                }
            }
            break;
        }
        case 'J': {
            chr = ']';
            break;
        }
        case 'Q': {
            chr = 'u';
            break;
        }
        case 'K': {
            chr = '+';
            break;
        }
        case 'f': { // W4
            switch (position) {
                case 3: {
                    watch_set_pixel(1,7);
                    watch_set_pixel(2,8);
                    watch_set_pixel(0,8);
                    watch_set_pixel(1,8);
                    return;
                }
                case 5: {
                    watch_set_pixel(2,21);
                    watch_set_pixel(0,20);
                    watch_set_pixel(1,17);
                    watch_set_pixel(1,20);
                    return;
                }
                case 6: {
                    watch_set_pixel(2,23);
                    watch_set_pixel(1,22);
                    watch_set_pixel(2,22);
                    watch_set_pixel(1,23);
                    return;
                }
                case 7: {
                    watch_set_pixel(2,10);
                    watch_set_pixel(1,0);
                    watch_set_pixel(2,0);
                    watch_set_pixel(1,1);
                    return;
                }
                case 8: {
                    watch_set_pixel(2,3);
                    watch_set_pixel(0,2);
                    watch_set_pixel(1,2);
                    watch_set_pixel(1,3);
                    return;
                }
                case 9: {
                    watch_set_pixel(2,5);
                    watch_set_pixel(0,5);
                    watch_set_pixel(1,4);
                    watch_set_pixel(1,5);
                    return;
                }
            }
            break;
        }
        case 't': { //WT
            switch (position) {
                case 3: {
                    watch_set_pixel(0,7);
                    watch_set_pixel(1,7);
                    watch_set_pixel(2,6);
                    watch_set_pixel(0,8);
                    watch_set_pixel(1,8);
                    return;
                }
                case 5: {
                    watch_set_pixel(2,20);
                    watch_set_pixel(2,21);
                    watch_set_pixel(0,21);
                    watch_set_pixel(1,17);
                    watch_set_pixel(1,20);
                    return;
                }
                case 6: {
                    watch_set_pixel(0,22);
                    watch_set_pixel(2,23);
                    watch_set_pixel(0,22);
                    watch_set_pixel(2,22);
                    watch_set_pixel(1,23);
                    return;
                }
                case 7: {
                    watch_set_pixel(2,1);
                    watch_set_pixel(2,10);
                    watch_set_pixel(0,0);
                    watch_set_pixel(2,0);
                    watch_set_pixel(1,1);
                    return;
                }
                case 8: {
                    watch_set_pixel(2,2);
                    watch_set_pixel(2,3);
                    watch_set_pixel(0,3);
                    watch_set_pixel(1,2);
                    watch_set_pixel(1,3);
                    return;
                }
                case 9: {
                    watch_set_pixel(2,4);
                    watch_set_pixel(2,5);
                    watch_set_pixel(0,6);
                    watch_set_pixel(1,4);
                    watch_set_pixel(1,5);
                    return;
                }
            }
            break;
        }
        case 'k': { // WK
            switch (position) {
                case 3: {
                    watch_set_pixel(1,7);
                    watch_set_pixel(2,7);
                    watch_set_pixel(1,8);
                    return;
                }
                case 5: {
                    watch_set_pixel(2,21);
                    watch_set_pixel(1,21);
                    watch_set_pixel(1,20);
                    return;
                }
                case 6: {
                    watch_set_pixel(2,23);
                    watch_set_pixel(0,23);
                    watch_set_pixel(1,23);
                    return;
                }
                case 7: {
                    watch_set_pixel(2,10);
                    watch_set_pixel(0,1);
                    watch_set_pixel(1,1);
                    return;
                }
                case 8: {
                    watch_set_pixel(2,3);
                    watch_set_pixel(0,4);
                    watch_set_pixel(1,3);
                    return;
                }
                case 9: {
                    watch_set_pixel(2,5);
                    watch_set_pixel(1,6);
                    watch_set_pixel(1,5);
                    return;
                }
            }
            break;
        }
        case '_': {
            switch (position) {
                case 5: {
                    watch_set_pixel(2,20);
                    watch_set_pixel(0,21);
                    return;
                }
                case 6: {
                    watch_set_pixel(0,22);
                    return;
                }
                case 7: {
                    watch_set_pixel(2,1);
                    watch_set_pixel(0,0);
                    return;
                }
                case 8: {
                    watch_set_pixel(2,2);
                    watch_set_pixel(0,3);
                    return;
                }
                case 9: {
                    watch_set_pixel(2,4);
                    watch_set_pixel(0,6);
                    return;
                }
            }
            break;
        }
        case '^': { // t in SUIt
            chr = 't';
        }
    }
     
    // this is watch_display_character, without the builtin character replacements
    watch_display_character_lp_seconds(chr, position);
    
}

static void setNum(uint64_t num, int8_t display_num_length, uint8_t tick_count) {
    char buffer[22];
    sprintf(buffer," %20lld",num);
    
    if (num < 1000000) {
        watch_display_string(buffer+15, 4);
    } else {
        if (tick_count == 0) {
            watch_display_string(buffer + (21 - 6 - display_num_length), 5);
        } else {
            watch_display_string(buffer + (21 - 7 - display_num_length) + tick_count, 4);
        }
    }
}

static void handleEvent(bird_poker_face_state_t *state, uint8_t ev);

static void setScreen(bird_poker_face_state_t *state, uint8_t screen) {
    state->screen = screen;
    handleEvent(state, EV_INIT);
}

static void handleEventTitleNumber(bird_poker_face_state_t *state, uint8_t ev, char t1, char t2, char t3, uint64_t num, uint8_t next_screen) {
    switch (ev) {
        case EV_INIT: {
            state->tick_count = 0;
            state->display_num_length = (((int) floor(log(num)/log(10))) + 1) - 6;
            if (0 < state->display_num_length) {
                state->tick_freq = 2;
                movement_request_tick_frequency(2);
            }
            break;
        }
        case EV_TICK: {
            if (0 < state->display_num_length) {
                state->tick_count++;
                if ((2 * (2 + state->display_num_length)) <= state->tick_count) {
                    state->tick_count = 0;
                }
            }
            break;
        }
        case EV_TOP_LEFT:
            setScreen(state, SCREEN_DEAL);
            return;
        case EV_BOTTOM_RIGHT:
            setScreen(state, next_screen);
            return;
    }
    watch_clear_display();
    setChar(0, t1);
    setChar(1, t2);
    setChar(3, t3);
    setNum(num, state->display_num_length, (int)(state->tick_count / 2));
}

static void handleEvent_WELCOME(bird_poker_face_state_t *state, uint8_t ev) {
    switch (ev) {
        case EV_INIT:
            state->tick_freq = 1;
            movement_request_tick_frequency(1);
            watch_clear_display();
            watch_display_string(" birdP", 4);
            if (state->balance == 0) {
                state->balance = 20;
            }
            break;
        case EV_TOP_LEFT:
            setScreen(state, SCREEN_DEAL);
            break;
        case EV_BOTTOM_RIGHT:
            setScreen(state, SCREEN_WELCOME_BALANCE);
            break;
    }
}

static void handleEvent_WELCOME_BALANCE(bird_poker_face_state_t *state, uint8_t ev) {
    handleEventTitleNumber(state, ev, 'b', 'A', 'L', state->balance, SCREEN_WELCOME_COMBO_ROYAL);
}

static void handleEvent_WELCOME_COMBO_ROYAL(bird_poker_face_state_t *state, uint8_t ev) {
    const char* ROYAL_NAME = PAYOUTS_NAMES[Royal];
    handleEventTitleNumber(state, ev, ROYAL_NAME[0], ROYAL_NAME[1], ' ', state->jackpot, SCREEN_WELCOME_COMBOS);
}

static void handleEvent_WELCOME_COMBOS(bird_poker_face_state_t *state, uint8_t ev) {
    switch (ev) {
        case EV_INIT:
            state->tick_freq = 1;
            movement_request_tick_frequency(1);
            state->tick_count = PAYOUTS_LENGTH - 1;
            break;
        case EV_TOP_LEFT:
            setScreen(state, SCREEN_DEAL);
            return;
        case EV_BOTTOM_RIGHT:
            state->tick_count--;
            if (state->tick_count == 0) {
                setScreen(state, SCREEN_WELCOME_CARDS);
                return;
            }
            break;
        case EV_TICK:
            return;
    }
    watch_clear_display();
    const char *combo_name = PAYOUTS_NAMES[state->tick_count];
    setChar(0, combo_name[0]);
    setChar(1, combo_name[1]);
    
    uint8_t prize = PAYOUTS_PRIZES[state->tick_count];
    setNum(prize,0,0);
    
}

static void handleEvent_WELCOME_CARDS(bird_poker_face_state_t *state, uint8_t ev) {
    switch (ev) {
        case EV_INIT:
            state->tick_freq = 1;
            movement_request_tick_frequency(1);
            state->tick_count = 0;
            break;
        case EV_TOP_LEFT:
            setScreen(state, SCREEN_DEAL);
            return;
        case EV_BOTTOM_RIGHT:
            state->tick_count++;
            if (state->tick_count == 4) {
                setScreen(state, SCREEN_WELCOME);
                return;
            }
            break;
        case EV_TICK:
            return;
    }
    watch_clear_display();
    if (state->tick_count <= 2) {
        setChar(0, 'S');
        setChar(1, 'U');
        setChar(2, 'i');
        setChar(3, '^'); // t as not 10 card
    } else {
        setChar(0, 'W');
        setChar(1, '1');
        setChar(2, 'l');
        setChar(3, 'd'); 
    }
    if (state->tick_count == 0) {
        setChar(5, CARD_CHARS[1]);
        setChar(6, CARD_CHARS[2]);
        setChar(7, CARD_CHARS[3]);
        setChar(8, CARD_CHARS[4]);
        setChar(9, CARD_CHARS[5]);
    } else if (state->tick_count == 1) {
        setChar(5, CARD_CHARS[6]);
        setChar(6, CARD_CHARS[7]);
        setChar(7, CARD_CHARS[8]);
        setChar(8, CARD_CHARS[9]);
        setChar(9, CARD_CHARS[10]);
    } else if (state->tick_count == 2) {
        setChar(7, CARD_CHARS[11]);
        setChar(8, CARD_CHARS[12]);
        setChar(9, CARD_CHARS[13]);
    } else {
        setChar(6, CARD_CHARS[14]);
        setChar(7, CARD_CHARS[15]);
        setChar(8, CARD_CHARS[16]);
        setChar(9, CARD_CHARS[17]);
    }
    
}

static void handleEvent_DEAL_AND_REDRAW(bird_poker_face_state_t *state, uint8_t ev, uint8_t next_screen) {
    switch (ev) {
        case EV_INIT: {
            state->tick_count = 0;
            state->tick_freq = 4;
            movement_request_tick_frequency(4);
            break;
        }
        case EV_TICK: {
            state->tick_count++;
            break;
        }
    }
    if (state->tick_count == 5) {
        setScreen(state, next_screen);
        return;
    } else {
        watch_clear_display();
        for (int8_t i = 0; i < 5; i++) {
            char c = 0;
            if (state->discards & (1 << i)) {
                switch (state->tick_count) {
                    case 0:
                    case 2:
                    case 4: {
                        c = '_';
                        break;
                    }
                    default: {
                        c = '-';
                        break;
                    }
                }
            } else {
                c = CARD_CHARS[state->hand[i]];
            }
            setChar(5 + i, c);
        }
    }
}

static void _deal(bird_poker_face_state_t *state) {
    for (int8_t i = 0; i < 5; i++) {
        if (state->discards & (1 << i)) {
            int8_t dealt_count = __builtin_popcount(state->dealt);
            // idx 1 - 17 inc
            int32_t idx = generate_random_number(17 - dealt_count) + 1;
            int32_t c = idx;
            for (int32_t j = 1; j <= idx; j++) {
                if (state->dealt & (1 << j)) {
                    c++;
                }
            }
            while (state->dealt & (1 << c)) {
                c++;
                if (c > 18) { break; }
            }
            state->dealt |= 1 << c;
            state->hand[i] = c;
        }
    }
}

static void handleEvent_DEAL(bird_poker_face_state_t *state, uint8_t ev){
    switch (ev) {
        case EV_INIT: {
            if (state->balance == 0) {
                setScreen(state, SCREEN_BUST);
                return;
            }
            
            state->settle_score = 0;
            state->settle_prize = 0;
            state->discards = 0xFF; //all discarded to animate 5 cards
            state->dealt = 0;
            _deal(state);
            state->balance--;
            state->jackpot++;
            break;
        }
        case EV_TOP_LEFT: {
            setScreen(state, SCREEN_DEAL);
            return;
        }
        case EV_BOTTOM_RIGHT: {
            setNum(state->dealt,0,0);
            //setNum(1 << 1, 0,0);
            return;
        }
    }

    handleEvent_DEAL_AND_REDRAW(state, ev, SCREEN_SELECT);
    
}

static void handleEvent_SELECT(bird_poker_face_state_t *state, uint8_t ev) {
    switch (ev) {
        case EV_INIT: {
            state->discards = 0;
            state->tick_count = 0;
            state->select_i = 0;
            state->tick_freq = 4;
            movement_request_tick_frequency(4);
            break;
        }
        case EV_TICK: {
            state->tick_count++;
            if (state->tick_count == 4) {
                state->tick_count = 0;
            }
            break;
        }
        case EV_BOTTOM_RIGHT: {
            state->select_i++;
            if (state->select_i == 6) {
                state->select_i = 0;
            }
            state->tick_count = 0;
            break;
        }
        case EV_TOP_LEFT: {
            if (state->select_i == 0) {
                if (state->discards > 0) {
                    setScreen(state, SCREEN_REDRAW);
                    return;
                } else {
                    setScreen(state, SCREEN_SETTLE);
                    return;
                }
            } else {    
                int8_t b = (1 << (state->select_i - 1));
                if (state->discards & b) {
                    state->discards &= ~b;
                } else {
                    state->discards |= b;
                }
            }
            break;
        }
    }
    watch_clear_display();
    uint8_t c = ' ';
    if (state->select_i == 0) {
        if (state->tick_count != 1) {
            c = '-';
        }
    }
    //setChar(3, '0' + state->tick_count);
    setChar(4, c);
    
    for (uint8_t i = 0; i < 5; i++) {
        c = 0;
        switch (state->tick_count) {
            case 0: {
                if (i != (state->select_i - 1)) {
                    c = state->hand[i];
                }
                break;
            }
            case 1:
            case 3: {
                if (!(state->discards & (1 << i))) {
                    c = state->hand[i];
                }
                break;
            }
            case 2: {
                c = state->hand[i];
                break;
            }
        }
        //c = state->hand[i];
        setChar(5 + i, CARD_CHARS[c]);
    }
    
}

static void handleEvent_REDRAW(bird_poker_face_state_t *state, uint8_t ev) {
    switch (ev) {
        case EV_INIT: {
            _deal(state);
            break;
        }
    }
    handleEvent_DEAL_AND_REDRAW(state, ev, SCREEN_SETTLE);
    
}

static void handleEvent_SETTLE(bird_poker_face_state_t *state, uint8_t ev) {
    switch (ev) {
        case EV_INIT: {
            state->tick_freq = 1;
            movement_request_tick_frequency(1);

            if (state->settle_score == 0) {
                state->settle_score = score(state->hand[0],state->hand[1],state->hand[2],state->hand[3],state->hand[4]);
                int combi = state->settle_score >> 4;
                state->settle_prize = PAYOUTS_PRIZES[combi];
                if (combi == Royal) {
                    state->settle_prize = state->jackpot;
                    state->balance += state->settle_prize;
                    state->jackpot = PAYOUTS_PRIZES[Royal];
                } else {
                    state->settle_prize = PAYOUTS_PRIZES[combi];
                    state->balance += state->settle_prize;
                }
            }
            break;
        }
        case EV_TOP_LEFT: {
            setScreen(state, SCREEN_DEAL);
            return;
        }
        case EV_BOTTOM_RIGHT: {
            setScreen(state, SCREEN_SETTLE_PRIZE);
            return;
        }
    }

    int combi = state->settle_score >> 4;
    int highc = state->settle_score & 15;

    const char* PAYOUT_NAME = PAYOUTS_NAMES[combi];

    watch_clear_display();
    setChar(0, PAYOUT_NAME[0]);
    setChar(1, PAYOUT_NAME[1]);

    uint8_t c = highc == CAHigh ? 1 : highc;
    setChar(3, CARD_CHARS[c]);
    

    for (int8_t i = 0; i < 5; i++) {
        setChar(5 + i, CARD_CHARS[state->hand[i]]);
    }
    //setNum(state->settle_score,0,0);
}

static void handleEvent_SETTLE_PRIZE(bird_poker_face_state_t *state, uint8_t ev) {
    handleEventTitleNumber(state, ev, 'W', '1', 'n', state->settle_prize, SCREEN_SETTLE_BALANCE);
}

static void handleEvent_SETTLE_BALANCE(bird_poker_face_state_t *state, uint8_t ev) {
    handleEventTitleNumber(state, ev, 'b', 'A', 'L', state->balance, SCREEN_SETTLE_JACKPOT);
}

static void handleEvent_SETTLE_JACKPOT(bird_poker_face_state_t *state, uint8_t ev) {
    const char* ROYAL_NAME = PAYOUTS_NAMES[Royal];
    handleEventTitleNumber(state, ev, ROYAL_NAME[0], ROYAL_NAME[1], ' ', state->jackpot, SCREEN_SETTLE);
}

static void handleEvent_BUST(bird_poker_face_state_t *state, uint8_t ev) {
    switch (ev) {
        case EV_INIT: {
            state->tick_freq = 2;
            movement_request_tick_frequency(2);

            state->tick_count = 0;
            state->balance = 20;
            break;
        }
        case EV_TOP_LEFT: {
            setScreen(state, SCREEN_WELCOME);
            return;
        }
        case EV_TICK: {
            state->tick_count++;
            if (state->tick_count == 2) {
                state->tick_count = 0;
            }
            break;
        }
    }

    watch_clear_display();
    if (state->tick_count == 0) {
        setChar(5, 'b');
        setChar(6, 'Q'); // u
        setChar(7, 'S');
        setChar(8, '^'); // t
    }
}

static void handleEvent(bird_poker_face_state_t *state, uint8_t ev) {
    switch (state->screen) {
        case SCREEN_WELCOME: {
            handleEvent_WELCOME(state, ev);
            break;
        }
        case SCREEN_WELCOME_BALANCE: {
            handleEvent_WELCOME_BALANCE(state, ev);
            break;
        }
        case SCREEN_WELCOME_COMBO_ROYAL: {
            handleEvent_WELCOME_COMBO_ROYAL(state, ev);
            break;
        }
        case SCREEN_WELCOME_COMBOS: {
            handleEvent_WELCOME_COMBOS(state, ev);
            break;
        }
        case SCREEN_WELCOME_CARDS: {
            handleEvent_WELCOME_CARDS(state, ev);
            break;
        }
        case SCREEN_DEAL: {
            handleEvent_DEAL(state, ev);
            break;
        }
        case SCREEN_SELECT: {
            handleEvent_SELECT(state, ev);
            break;
        }
        case SCREEN_REDRAW: {
            handleEvent_REDRAW(state, ev);
            break;
        }
        case SCREEN_SETTLE: {
            handleEvent_SETTLE(state, ev);
            break;
        }
        case SCREEN_SETTLE_PRIZE: {
            handleEvent_SETTLE_PRIZE(state, ev);
            break;
        }
        case SCREEN_SETTLE_BALANCE: {
            handleEvent_SETTLE_BALANCE(state, ev);
            break;
        }
        case SCREEN_SETTLE_JACKPOT: {
            handleEvent_SETTLE_JACKPOT(state, ev);
            break;
        }
        case SCREEN_BUST: {
            handleEvent_BUST(state, ev);
            break;
        }
    }
}

bool bird_poker_face_loop(movement_event_t event, movement_settings_t *settings, void *context) {

    bird_poker_face_state_t *state = (bird_poker_face_state_t *)context;
    
    switch (event.event_type) {
        case EVENT_ACTIVATE:
            // Show your initial UI here.
            //_bird_poker_face_update_display(settings);
            setScreen(state, SCREEN_WELCOME);

            break;
        case EVENT_TICK:
            // If needed, update your display here.
            //_bird_poker_face_update_display(settings);
            handleEvent(state, EV_TICK);
            break;
        case EVENT_LIGHT_BUTTON_DOWN:
            // empty case makes led not light
            break;
        case EVENT_LIGHT_BUTTON_UP:
            // You can use the Light button for your own purposes. Note that by default, Movement will also
            // illuminate the LED in response to EVENT_LIGHT_BUTTON_DOWN; to suppress that behavior, add an
            // empty case for EVENT_LIGHT_BUTTON_DOWN.
            handleEvent(state, EV_TOP_LEFT);
            break;
        case EVENT_ALARM_BUTTON_UP:
            // Just in case you have need for another button.
            handleEvent(state, EV_BOTTOM_RIGHT);
            break;
        case EVENT_TIMEOUT:
            // Your watch face will receive this event after a period of inactivity. If it makes sense to resign,
            // you may uncomment this line to move back to the first watch face in the list:
            // movement_move_to_face(0);
            break;
        case EVENT_LOW_ENERGY_UPDATE:
            // If you did not resign in EVENT_TIMEOUT, you can use this event to update the display once a minute.
            // Avoid displaying fast-updating values like seconds, since the display won't update again for 60 seconds.
            // You should also consider starting the tick animation, to show the wearer that this is sleep mode:
            // watch_start_tick_animation(500);
            //_bird_poker_face_update_display(settings);
            break;
        default:
            // Movement's default loop handler will step in for any cases you don't handle above:
            // * EVENT_LIGHT_BUTTON_DOWN lights the LED
            // * EVENT_MODE_BUTTON_UP moves to the next watch face in the list
            // * EVENT_MODE_LONG_PRESS returns to the first watch face (or skips to the secondary watch face, if configured)
            // You can override any of these behaviors by adding a case for these events to this switch statement.
            return movement_default_loop_handler(event, settings);
    }

    // return true if the watch can enter standby mode. Generally speaking, you should always return true.
    // Exceptions:
    //  * If you are displaying a color using the low-level watch_set_led_color function, you should return false.
    //  * If you are sounding the buzzer using the low-level watch_set_buzzer_on function, you should return false.
    // Note that if you are driving the LED or buzzer using Movement functions like movement_illuminate_led or
    // movement_play_alarm, you can still return true. This guidance only applies to the low-level watch_ functions.
    return true;
}

void bird_poker_face_resign(movement_settings_t *settings, void *context) {
    (void) settings;
    (void) context;
 
    bird_poker_face_state_t *state = (bird_poker_face_state_t *)context;
    
    if (state->tick_freq != 1) {
        movement_request_tick_frequency(1);
    }
}