#ifndef bird_poker_FACE_H_
#define bird_poker_FACE_H_

#include "movement.h"

typedef struct {
    // Anything you need to keep track of, put it here!
    uint8_t screen;
    uint64_t balance;
    uint64_t jackpot;
    uint8_t tick_count;
    int8_t display_num_length;
    uint8_t tick_freq;
    uint8_t discards;
    uint32_t dealt;
    uint8_t hand[5];
    uint8_t select_i;
    uint8_t settle_score;
    uint64_t settle_prize;
} bird_poker_face_state_t;

void bird_poker_face_setup(movement_settings_t *settings, uint8_t watch_face_index, void ** context_ptr);
void bird_poker_face_activate(movement_settings_t *settings, void *context);
bool bird_poker_face_loop(movement_event_t event, movement_settings_t *settings, void *context);
void bird_poker_face_resign(movement_settings_t *settings, void *context);

#define bird_poker_face ((const watch_face_t){ \
    bird_poker_face_setup, \
    bird_poker_face_activate, \
    bird_poker_face_loop, \
    bird_poker_face_resign, \
    NULL, \
})

#endif // bird_poker_FACE_H_

