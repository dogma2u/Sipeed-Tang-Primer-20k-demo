// sw_config.vh -- Space Wars gameplay knobs (`define only)
//
// - Included by sw_physics.v:  `include "sw_config.vh"
// - On project FileList: tang20k_lcd.gprj lists src/sw_config.vh
// `define-only so Gowin Education accepts it on FileList.

`ifndef SW_CONFIG_VH
`define SW_CONFIG_VH

// --- Display / world ---
`define CFG_FB_W            800
`define CFG_FB_H            470
`define CFG_MARGIN          20
`define CFG_SUN_X           400
`define CFG_SUN_Y           240
`define CFG_SUN_R           18
`define CFG_FRAMES_PER_SEC  50
`define CFG_WALL_KEEP       60

// --- Sun / black hole ---
`define CFG_SUN_HITS_BH     10
`define CFG_BH_HITS_SUN     5
`define CFG_SUN_HIT_M       22
`define CFG_SUN_NEAR_M      100
`define CFG_ANTI_GRAV_SEC   10

// --- Shots / fire ---
`define CFG_NSHOT           8
`define CFG_NSHOT_PL        5
`define CFG_PL_BUL_LIFE     28
`define CFG_SHOT_SPD_PX     10
`define CFG_FIRE_GAP_FR     5
`define CFG_FIRE_RELOAD_FR  25
`define CFG_FIRE_MAG_MAX    5
`define CFG_PL_THRUST       40

// --- Lives / fuel / score / timer ---
`define CFG_LIFE_MAX        5
`define CFG_LIFE_START      3
`define CFG_KILL_FOR_LIFE   5
`define CFG_FUEL_MAX_MS     15000
`define CFG_FUEL_FRAME_MS   20
`define CFG_TIMER_START     130
`define CFG_TIMER_BONUS     5
`define CFG_TIMER_MAX       9999
`define CFG_DEMO_TIMER      9999
`define CFG_SCORE_LO        (-11'sd999)
`define CFG_SCORE_HI        (11'sd999)

// --- Spawn / vanish / hyperspace ---
`define CFG_SPAWN_INVULN_FR 75
`define CFG_AI_VANISH_FR    25
`define CFG_HS_VANISH_FR    50
`define CFG_HS_FLASH_FR     75

// --- AI playtime ramps ---
`define CFG_PLAY_MAX_SEC         300
`define CFG_AI_CD_INIT           20
`define CFG_AI_RANGE_NUM         3
`define CFG_AI_RANGE_DEN         4
`define CFG_AI_AIM_FIRE_MIN_PCT  15
`define CFG_AI_RELOAD_POOR_EXTRA 15
`define CFG_AI_GAP_POOR_EXTRA    10
`define CFG_AI_BP_LIFE_0    45
`define CFG_AI_BP_LIFE_1    150
`define CFG_AI_LIFE_0       14
`define CFG_AI_LIFE_1       18
`define CFG_AI_BP_SO_0      45
`define CFG_AI_BP_SO_1      90
`define CFG_AI_BP_SO_2      150
`define CFG_AI_SO_0         280
`define CFG_AI_SO_1         210
`define CFG_AI_SO_2         140
`define CFG_AI_SO_3         70
`define CFG_AI_BP_AIM_0     45
`define CFG_AI_BP_AIM_1     90
`define CFG_AI_BP_AIM_2     150
`define CFG_AI_BP_AIM_3     300
`define CFG_AI_AIM_0        0
`define CFG_AI_AIM_1        25
`define CFG_AI_AIM_2        55
`define CFG_AI_AIM_3        75
`define CFG_AI_AIM_4        100
`define CFG_AI_BP_THR_0     75
`define CFG_AI_BP_THR_1     150
`define CFG_AI_BP_THR_2     225
`define CFG_AI_THR_0        12
`define CFG_AI_THR_1        20
`define CFG_AI_THR_2        28
`define CFG_AI_THR_3        40
`define CFG_AI_WILD_SEC     150
`define CFG_AI_MAXV_0       10
`define CFG_AI_MAXV_1       16
`define CFG_AI_MAXV_2       21
// Demo attract: top ship speed clamp (px/frame Q8.8); thrust = this * CFG_DEMO_THR_NUM/DEN
`define CFG_SHIP_MAXV       21
`define CFG_DEMO_THR_NUM    3
`define CFG_DEMO_THR_DEN    2

// --- Secret green sun (todo 22; not in README) ---
`define CFG_GREEN_SUN_HITS      50
`define CFG_GREEN_SUN_GRAV_MAG  24

`endif
