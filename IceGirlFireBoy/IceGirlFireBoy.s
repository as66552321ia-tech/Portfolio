
#----------------------------------------------------------------------------------------------
# 1. Collision detection
# - All related function implements standard AABB collision detection where a collision  occurs if the rectangles overlap on both x and y axes. 
# 2. Movement
# Watergirl - W: Jump A: Right D: Left; Fireboy - I: Jump L: Right J: Left
# - Only one character can be controlled at a time   
# - pressing the jump key will interrupt any ongoing left- or right-movement. If you wish to continue moving horizontally after jumping, you will
# need to press the corresponding movement key again
# 3. Death
# If you meet the restriction of the game, game over. you can tap "R" to restart
#----------------------------------------------------------------------------------------------

.data  
# Image File Paths  
bg_path_1:       .asciiz "game_image/map_1_1.jpg"  # Background map 1  
bg_path_2:       .asciiz "game_image/map_2_1.png"  # Background map 2  
player1_path:    .asciiz "game_image/ice_girl.png"  # WaterGirl sprite  
player2_path:    .asciiz "game_image/fire_boy.png"  # FireBoy sprite  
fire_stone:      .asciiz "game_image/fire_stone.png"  # Red gem  
ice_stone:       .asciiz "game_image/ice_stone.png"  # Blue gem  
box_path:        .asciiz "game_image/box.png"  # Box sprite  

# Initial Player Coordinates  
player1_x_map_1:  .word 190  
player1_y_map_1:  .word 380  # WaterGirl starts on platform  
player2_x_map_1:  .word 190  
player2_y_map_1:  .word 225  # FireBoy starts on second platform  
player1_x_map_2:  .word 720   
player1_y_map_2:  .word 390  
player2_x_map_2:  .word 820  
player2_y_map_2:  .word 390  

# Current Player Coordinates  
player1_x:        .word 190  
player1_y:        .word 380  
player2_x:        .word 190  
player2_y:        .word 225  

# Previous Player Coordinates   
last_player1_x:   .word 190  
last_player1_y:   .word 380  

# Gem Coordinates  
red_stone_x:      .word 400      # Red gem X coordinate  
red_stone_y:      .word 400      # Red gem Y coordinate  
red_stone_active: .word 1        # Red gem state (1=visible, 0=collected)  

blue_stone_x:     .word 610      # Blue gem X coordinate  
blue_stone_y:     .word 400      # Blue gem Y coordinate  
blue_stone_active: .word 1       # Blue gem state (1=visible, 0=collected)  

# Box Coordinates  
box_map_2_x:      .word 330  
box_map_2_y:      .word 390  
box_x:            .word 330  
box_y:            .word 390  

# Character Size Constants  
.eqv PLAYER_WIDTH     40  
.eqv PLAYER_HEIGHT    70  

# Box Size Constants  
.eqv BOX_WIDTH        80  
.eqv BOX_HEIGHT       70  


# Gem Size Constants  
.eqv GEM_WIDTH        40
.eqv GEM_HEIGHT       40  

# System Constants  
.eqv PRINT_STRING     4  
.eqv PRINT_INT        1  
.eqv SLEEP            32   
.eqv EXIT             10  
.eqv SYSCALL_WINDOW   120  
.eqv FRAME_DELAY      30  

# Game State  
game_running:    .word 1  
score:           .word 0  

# Movement Parameters  
.eqv MOVE_SPEED       10   

# Key Constants  
.eqv KEY_W          87  
.eqv KEY_A          65  
.eqv KEY_S          83  
.eqv KEY_D          68  
.eqv KEY_I          73  
.eqv KEY_J          74  
.eqv KEY_K          75  
.eqv KEY_L          76  
.eqv KEY_Q          81  
.eqv KEY_E          69  
.eqv KEY_U          85  
.eqv KEY_O          79  
.eqv KEY_R          82  
.eqv KEY_ESCAPE     27  

# Window Service Codes  
.eqv INIT_SERVICE       1  
.eqv GET_KEY_SERVICE    2  
.eqv CLEAR_KEY_SERVICE  3  
.eqv DRAW_ON_LAYER      6  
.eqv CLEAR_LAYER        7  

# Layer Constants  
.eqv BACKGROUND_LAYER   0  
.eqv CHARACTER_LAYER    1  
.eqv WALL_LAYER         2   # Wall layer  
.eqv RED_STONE_LAYER    3   # Red gem layer  
.eqv BLUE_STONE_LAYER   4   # Blue gem layer  

.align 2  
key_buffer:        .space 400  # Space for 100 key values  
key_count:         .word 0     # Actual key count  

# Game Status Flags  
screen_clear_flag: .word 0     # Initially 0   
player_move_flag:  .word 1     # Initially 1   

# Jump Physics Variables  
jumpVelocity:      .word -19   # Initial jump velocity  
gravity:           .word 1      # Gravity acceleration  
groundLevel:       .word 450    # Ground level height  
playerSize:        .word 70     # Player height  
player1Jumping:    .word 0      # Player 1 jump status (1=jumping)  
player1VY:         .word 0      # Player 1 vertical velocity  
player2Jumping:    .word 0      # Player 2 jump status (1=jumping)  
player2VY:         .word 0      # Player 2 vertical velocity   
is_grounded:       .word 1      # Whether on ground  
max_jump_height:   .word 120    # Maximum jump height  
jump_start_y:      .word 0      # Jump starting Y coordinate  
move_horizon:      .word 0      # Horizontal movement status  
headCollision:     .word 0      # Head collision detection for player 1  
headCollision2:    .word 0      # Head collision detection for player 2

# Game Variables 
currentPlayer:     .word 0      # Current active player  
currentMap:        .word 0      # Current map  
pressed_keys:      .space 256   # Pressed keys array  
is_dead:           .word 0      # Death status  

# Map 1 Wall Data  
wall_count_1:      .word 17  
walls_1:  			  # .word left, top, right, down
    .word 0, 0, 40, 450           # Left boundary  
    .word 40, 145, 405, 185       # Third layer left wall  
    .word 405, 145, 445, 265      # Third layer slope  
    .word 445, 220, 635, 265      # Third layer middle platform  
    .word 751, 220, 860, 265      # Third layer right platform  
    .word 635, 240, 751, 265      # Third layer green pool  
    .word 605, 265, 675, 302      # Third layer lower obstacle   
    .word 40, 297, 345, 345       # Second layer wall  
    .word 984, 140, 1024, 337     # Second layer right wall  
    .word 0, 451, 484, 600        # First layer bottom left boundary  
    .word 600, 451, 690, 600      # First layer middle block  
    .word 908, 340, 1024, 450     # First layer right boundary  
    .word 806, 451, 1024, 600     # First layer bottom right boundary  
    .word 484, 470, 600, 600      # First layer red pool  
    .word 690, 470, 806, 600      # First layer blue pool  
    .word 495, 0, 1024, 30        # Top obstacle  
    .word 920, 30, 1024, 140      # Top right obstacle 
    
# Map 2 Wall Data  
wall_count_2:      .word 13  
walls_2:                          # .word left, top, right, down
    .word 0, 0, 15, 450           # Left boundary   
    .word 280, 150, 317, 240      # Third layer slope  
    .word 680, 200, 790, 290      # Third layer middle block   
    .word 415, 240, 680, 290      # Third layer middle platform 
    .word 790, 240, 1000, 290     # Third layer right platform   
    .word 15, 260, 145, 460       # Second layer left wall  
    .word 1000, 0, 1024, 460      # Second layer right wall   
    .word 280, 240, 415, 380      # Second layer middle wall  
    .word 145, 390, 225, 460      # Box platform       
    .word 490, 375, 685, 600      # First layer middle block   
    .word 0, 460, 490, 600        # First layer bottom left boundary  
    .word 685, 460, 1024, 600     # First layer bottom right boundary  
    .word 15, 0, 1024, 30         # Top obstacle   
    
# Pool Data  
pool_count:        .word 3  
pools:  # .word left, top, right, down
    .word 490, 440, 575, 470      # Red pool  
    .word 690, 440, 780, 470      # Blue pool  
    .word 650, 204, 730, 234      # Poison pool  
    
# Map 1 Door Data  
door_count_1:      .word 2  
doors_map_1:  # .word left, top, right, down
    .word 190, 110, 210, 140      # Blue door  
    .word 280, 110, 300, 140      # Red door  
    
# Map 2 Door Data  
door_count_2:      .word 2  
doors_map_2:  # .word left, top, right, down
    .word 565, 210, 585, 230     
    .word 475, 210, 495, 230     
  
.text  
.globl main  

main:  
    # Initialize stack pointer  
    la $sp, 0x7ffffffc  

    # 1) Initialize window  
    li $a0, INIT_SERVICE              
    la $a1, bg_path_1        
    la $a2, key_buffer     
    li $v0, 120            
    syscall  
    
    # 2) Initialize gems, doors, and boxes  
    jal draw_tools  
    jal draw_game  
    

    # Enter main loop  
    j game_loop  

game_loop:  
    # Exit condition check  
    lw $t0, game_running  
    beqz $t0, exit_game  
    
    # Frame delay  
    li $v0, SLEEP  
    li $a0, FRAME_DELAY  
    syscall  

    # Handle keyboard input  
    jal handle_keyboard  
    sw $zero, move_horizon          # Reset move_horizon to 0  
    
    # Check if the player is dead  
    lw $t0, is_dead  
    li $t1, 1  
    beq $t0, $t1, game_loop  
         
    # Clear the wall layer  
    li $a0, CLEAR_LAYER  
    li $a1, WALL_LAYER   
    li $v0, SYSCALL_WINDOW  
    syscall  

    # Update physics  
    jal updatePhysics     
    
    # Check interactions  
    jal check_pool  
    jal check_door  
    jal check_box  
    jal check_stone

    # Clear the character layer  
    li $a0, CLEAR_LAYER  
    li $a1, CHARACTER_LAYER  
    li $v0, SYSCALL_WINDOW  
    syscall  
    
    # Redraw the game  
    jal draw_game  
    jal draw_tools  
    
    # game loop
    j game_loop 
    
 

# ===========================  
#   Check Stone (Gem) Collisions  
# ===========================   
check_stone:  
    # Save registers  
    addi $sp, $sp, -24  
    sw $ra, 0($sp)  
    sw $s0, 4($sp)  
    sw $s1, 8($sp)  
    sw $s2, 12($sp)  
    sw $s3, 16($sp)  
    sw $s4, 20($sp)  
    
    # Check collisions between characters and gems  
    jal check_stone_collision  
    
    # Check if gems need to be cleared  
    lw $t0, screen_clear_flag  
    beqz $t0, stone_end    # If no clearing needed, skip to end  
    
    # Clear gems if flag is set  
    jal clear_stone  
    sw $zero, screen_clear_flag   # Reset the clear flag  
    
stone_end:  
    # Restore registers  
    lw $ra, 0($sp)  
    lw $s0, 4($sp)  
    lw $s1, 8($sp)  
    lw $s2, 12($sp)  
    lw $s3, 16($sp)  
    lw $s4, 20($sp)  
    addi $sp, $sp, 24  
    jr $ra  


# ===========================  
#   Clear Stone (Gem) Layers  
# ===========================   
clear_stone:  
    # Save return address  
    addi $sp, $sp, -4  
    sw $ra, 0($sp)  
    
    # Clear red gem layer if active  
    lw $t0, red_stone_active  
    beqz $t0, clear_blue_stone_layer  
    
    li $a0, CLEAR_LAYER  
    li $a1, RED_STONE_LAYER  
    li $v0, SYSCALL_WINDOW  
    syscall  
    
clear_blue_stone_layer:  
    # Clear blue gem layer if active  
    lw $t0, blue_stone_active  
    beqz $t0, clear_stone_end  
    
    li $a0, CLEAR_LAYER  
    li $a1, BLUE_STONE_LAYER  
    li $v0, SYSCALL_WINDOW  
    syscall  
    
clear_stone_end:  
    # Restore return address  
    lw $ra, 0($sp)  
    addi $sp, $sp, 4  
    jr $ra  

    
    
# ===========================  
#   Check Pool  
# ===========================   
# Pool collision detection function  
check_pool:  
    addi $sp, $sp, -24   
    sw $ra, 0($sp)  
    sw $s0, 4($sp)  
    sw $s1, 8($sp)  
    sw $s2, 12($sp)  
    sw $s3, 16($sp)  
    sw $s4, 20($sp)   
    
    
    # Read currentMap value  
    lw $t0, currentMap        # Load currentMap value into $t0  
    # Check currentMap value  
    beq $t0, 1, pool_end     # If currentMap is 1, jump to pool_end  

    # Load current player  
    lw $s0, currentPlayer  

    # Load player coordinates  
    beqz $s0, load_player1_coords  
    
    # Player 2 coordinates  
    lw $s1, player2_x  
    lw $s2, player2_y  
    j check_pool_collision  

load_player1_coords:  
    # Player 1 coordinates  
    lw $s1, player1_x  
    lw $s2, player1_y  

check_pool_collision:  
    # Address of pool data  
    la $t4, pools  
    lw $t5, pool_count     # Load pool count from global variable  
    li $t6, 0              # Initialize pool index to 0  

    # Character boundaries  
    li $t7, PLAYER_WIDTH   # Player width  
    li $t8, PLAYER_HEIGHT  # Player height  
    move $t0, $s1          # left  
    add $t1, $s1, $t7      # right  
    move $t2, $s2          # top  
    add $t3, $s2, $t8      # bottom  

pool_loop:  
    # Check if there are more pools  
    bge $t6, $t5, no_pool_collision  

    # Load current pool coordinates  
    lw $s3, 0($t4)   # pool left  
    lw $s4, 4($t4)   # pool top  
    lw $s5, 8($t4)   # pool right  
    lw $s6, 12($t4)  # pool bottom  

    # Collision detection logic  
    bge $t0, $s5, skip_pool   # Character left >= pool right  
    ble $t1, $s3, skip_pool   # Character right <= pool left  
    bge $t2, $s6, skip_pool   # Character top >= pool bottom  
    ble $t3, $s4, skip_pool   # Character bottom <= pool top  
    
    # Collision detected, check pool type  
    # Red pool index 0  
    beqz $t6, check_red_pool  
    # Blue pool index 1  
    li $t7, 1  
    beq $t6, $t7, check_blue_pool  
    # Poison pool index 2  
    li $t7, 2  
    beq $t6, $t7, check_poison_pool  

    j game_over  

check_red_pool:  
    # Player 1 cannot pass through red pool  
    beqz $s0, game_over  
    # Player 2 can pass through red pool  
    j no_pool_collision  

check_blue_pool:  
    # Player 1 can pass through blue pool  
    beqz $s0, no_pool_collision  
    # Player 2 cannot pass through blue pool  
    j game_over  

check_poison_pool:  
    # No player can pass through poison pool  
    j game_over  

skip_pool:  
    addi $t4, $t4, 16  # Move to next pool  
    addi $t6, $t6, 1   # Increment pool index  
    j pool_loop        # Continue loop to check next pool  

no_pool_collision:  
    # No game over triggered, return  
    j pool_end  

game_over:  
    # Player dies  
    li $t0, 1  
    sw $t0, is_dead   

pool_end:  
    lw $ra, 0($sp)  
    lw $s0, 4($sp)  
    lw $s1, 8($sp)  
    lw $s2, 12($sp)  
    lw $s3, 16($sp)  
    lw $s4, 20($sp)  
    addi $sp, $sp, 24  
    jr $ra  
    
    
# ===========================  
#   Check door   
# ===========================   
check_door:  
    addi $sp, $sp, -24   
    sw $ra, 0($sp)  
    sw $s0, 4($sp)  
    sw $s1, 8($sp)  
    sw $s2, 12($sp)  
    sw $s3, 16($sp)  
    sw $s4, 20($sp)   
    
    # Read currentMap value  
    lw $t0, currentMap        # Load currentMap value into $t0  
    # Check currentMap value  
    beqz $t0, load_first_map  # If currentMap is 0, load first map data  
    beq $t0, 1, load_second_map  # If currentMap is 1, load second map data  
    j door_end  # Invalid map, exit directly  

load_first_map:  
    la $t4, doors_map_1  
    lw $t5, door_count_1  
    j continue_door_check  

load_second_map:  
    la $t4, doors_map_2  
    lw $t5, door_count_2  

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

continue_door_check:  
 

    # 1. Load character positions
    lw $s0, player1_x   
    lw $s1, player1_y
    lw $s2, player2_x   
    lw $s3, player2_y

    # 2. Initialize door checking
    li $s4, 0              # collision_flags
    li $t6, 0              # door_index
  
# 3. For each door in doors:
door_loop:
    bge $t6, $t5, door_check_finish

    lw $t0, 0($t4)   # left
    lw $t1, 4($t4)   # top
    lw $t2, 8($t4)   # right
    lw $t3, 12($t4)  # bottom

    # If door_index==0 
    beqz $t6, check_b_door

    # If door_index==1 
    li $t7, 1
    beq $t6, $t7, check_r_door
    j inc_door_index

check_b_door:
    move $a0, $s0
    move $a1, $s1
    addi $a2, $s0, PLAYER_WIDTH
    addi $a3, $s1, PLAYER_HEIGHT
    bge $a0, $t2, skip_b
    ble $a2, $t0, skip_b
    bge $a1, $t3, skip_b
    ble $a3, $t1, skip_b

    # collision 
    ori $s4, $s4, 1

skip_b:
    j inc_door_index

check_r_door:
    move $a0, $s2
    move $a1, $s3
    addi $a2, $s2, PLAYER_WIDTH
    addi $a3, $s3, PLAYER_HEIGHT
    bge $a0, $t2, skip_r
    ble $a2, $t0, skip_r
    bge $a1, $t3, skip_r
    ble $a3, $t1, skip_r
    
    # collision 
    ori $s4, $s4, 2

skip_r:
inc_door_index:
    addi $t4, $t4, 16
    addi $t6, $t6, 1
    j door_loop

# 4. Check collision results 
door_check_finish:
    li $t7, 3
    beq $s4, $t7, do_map_change     
    j no_door_collision

do_map_change:
    lw $t0, currentMap      
    li $t1, 1
    beq $t0, $t1, set_game_exit  

    j changeMap




no_door_collision:  
    # No game ending triggered, return  
    j door_end  

change_map:  
    # Read current map  
    lw $t0, currentMap  
    # Check current map  
    beqz $t0, changeMap # If current is map 1, switch to next map  
    # If map 2, end game  
    j set_game_exit   

door_end:  
    lw $ra, 0($sp)  
    lw $s0, 4($sp)  
    lw $s1, 8($sp)  
    lw $s2, 12($sp)  
    lw $s3, 16($sp)  
    lw $s4, 20($sp)  
    addi $sp, $sp, 24  
    jr $ra  
    
# ===========================  
#   Check box  
# ===========================   
check_box:  
    addi $sp, $sp, -24   
    sw $ra, 0($sp)  
    sw $s0, 4($sp)  
    sw $s1, 8($sp)  
    sw $s2, 12($sp)  
    sw $s3, 16($sp)  
    sw $s4, 20($sp)   
    
    # Read currentMap value  
    lw $t0, currentMap        # Load currentMap value into $t0  
    # Check currentMap value  
    beqz $t0, check_box_done  # If currentMap is 0, exit  
    
    lw $a0, box_x    # box left  
    li $t0, 145  
    ble $a0, $t0, add_box_wall  

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


# Calculate box bounding box 
    lw $t1, box_x
    lw $t2, box_y
    addi $t3, $t1, BOX_WIDTH
    addi $t4, $t2, BOX_HEIGHT

    # check collision 
    lw $s0, player1_x
    lw $s1, player1_y
    addi $s2, $s0, PLAYER_WIDTH
    addi $s3, $s1, PLAYER_HEIGHT

   
    bge $s0, $t3, check_player2
    ble $s2, $t1, check_player2
    bge $s1, $t4, check_player2
    ble $s3, $t2, check_player2

   
    li $t7, MOVE_SPEED

    sub $t1, $t1, $t7
    sw $t1, box_x
    j check_player2

check_player2:
    # check collision 
    lw $s0, player2_x
    lw $s1, player2_y
    addi $s2, $s0, PLAYER_WIDTH
    addi $s3, $s1, PLAYER_HEIGHT

    bge $s0, $t3, check_box_done
    ble $s2, $t1, check_box_done
    bge $s1, $t4, check_box_done
    ble $s3, $t2, check_box_done

    
    li $t7, MOVE_SPEED

    sub $t1, $t1, $t7
    sw $t1, box_x

    j check_box_done




add_box_wall:  
    li $t0, 13  
    sw $t0, wall_count_2  
    
check_box_done:  
    lw $ra, 0($sp)  
    lw $s0, 4($sp)  
    lw $s1, 8($sp)  
    lw $s2, 12($sp)  
    lw $s3, 16($sp)  
    lw $s4, 20($sp)  
    addi $sp, $sp, 24  
    jr $ra  

# ===========================  
#   Draw the door and jewel and box  
# ===========================  
    
draw_tools:  
    # Save registers and stack state upon function entry  
    addi $sp, $sp, -8           # Allocate space for registers  
    sw $ra, 4($sp)              # Save return address  
    sw $s0, 0($sp)              # Save $s0 register (if used)  
    
    
    # Read currentMap value  
    lw $t0, currentMap          # Load currentMap value into $t0  
    # Check if currentMap is 1  
    beq $t0, 1, check_box_status  

    # 1) Initialize red gem  
    lw $t0, red_stone_x         # Load red gem X coordinate  
    lw $t1, red_stone_y         # Load red gem Y coordinate  
    lw $t2, red_stone_active    # Load red gem state  
    beqz $t2, check_blue_stone  # If red gem state is 0, jump to blue gem check  

    # Draw red gem  
    li $a0, DRAW_ON_LAYER  
    la $a1, fire_stone          # Use fire stone image as red gem  
    move $a2, $t0               # Red gem X  
    move $a3, $t1               # Red gem Y  
    li $t0, WALL_LAYER  
    li $v0, SYSCALL_WINDOW  
    syscall                      # Draw red gem  

check_blue_stone:  
    # 2) Initialize blue gem  
    lw $t0, blue_stone_x        # Load blue gem X coordinate  
    lw $t1, blue_stone_y        # Load blue gem Y coordinate  
    lw $t2, blue_stone_active   # Load blue gem state  
    beqz $t2, draw_tools_end    # If blue gem state is 0, exit function  

    # Draw blue gem  
    li $a0, DRAW_ON_LAYER  
    la $a1, ice_stone           # Use ice stone image as blue gem  
    move $a2, $t0               # Blue gem X  
    move $a3, $t1               # Blue gem Y  
    li $t0, WALL_LAYER  
    li $v0, SYSCALL_WINDOW  
    syscall                      # Draw blue gem  
    
check_box_status:  
    # Read currentMap value  
    lw $t0, currentMap          # Load currentMap value into $t0  
    # Check if currentMap is 0  
    beq $t0, 0, draw_tools_end  
    
    # 3) Draw box   
    lw $t0, box_x               # Load box X coordinate  
    lw $t1, box_y               # Load box Y coordinate  

    # Draw box  
    li $a0, DRAW_ON_LAYER  
    la $a1, box_path          
    move $a2, $t0               
    move $a3, $t1               
    li $t0, CHARACTER_LAYER  
    li $v0, SYSCALL_WINDOW  
    syscall                      # Draw box  

draw_tools_end:  
    # Restore register state before exiting function  
    lw $ra, 4($sp)               # Restore return address  
    lw $s0, 0($sp)               # Restore $s0 register  
    addi $sp, $sp, 8             # Restore stack space  

    jr $ra                        # Return to caller  
    
handle_keyboard:  
    addi $sp, $sp, -16  
    sw $ra, 0($sp)  
    sw $s0, 4($sp)   # Store key count  
    sw $s1, 8($sp)   # Key buffer base address  
    sw $s2, 12($sp)  # Temporary storage  

    # Get key count and buffer  
    li $a0, GET_KEY_SERVICE  
    la $a1, key_buffer  
    li $v0, SYSCALL_WINDOW  
    syscall  

    # Save key count  
    move $s0, $v0  

    # If no keys pressed, jump to end  
    beqz $s0, keyboard_done  


    # Set movement flag  
    li $t0, 1  
    sw $t0, player_move_flag  

    # Initialize pressed_keys state to zero  
    li $t1, 0            
init_keys:  
    sb $zero, pressed_keys($t1) # Initialize state  
    addi $t1, $t1, 1  
    blt $t1, 256, init_keys     # Initialize 256 key states  

    # Prepare to traverse key buffer  
    la $s1, key_buffer  
    li $t2, 0                   # Valid key counter  

process_keys_loop:  
    # Load current key value  
    lw $t8, ($s1)  

    # Skip zero values  
    beqz $t8, skip_key  

    # Confirm key value is in valid range (0-255)  
    li $t9, 255                 # Set upper range limit  
    ble $t8, $t9, set_pressed_state  # If in range, set state  
    j skip_key  

set_pressed_state:  
    # Set key state to 1  
    li $t9, 1                   # Set pressed state to 1  
    sb $t9, pressed_keys($t8)   # Update pressed keys state using key value as index  

    # Check for ESC key  
    li $t0, KEY_ESCAPE  
    beq $t8, $t0, set_game_exit  

    # Ice Girl (Player 1) key handling  
    li $t0, KEY_A  
    beq $t8, $t0, player1_left  

    li $t0, KEY_D  
    beq $t8, $t0, player1_right  

    li $t0, KEY_W  
    beq $t8, $t0, player1_up  


    # Fire Boy key handling  
    li $t0, KEY_J  
    beq $t8, $t0, player2_left  

    li $t0, KEY_L  
    beq $t8, $t0, player2_right  

    li $t0, KEY_I  
    beq $t8, $t0, player2_up  
    
    # Map switching key R  
    li $t0, KEY_R  
    beq $t8, $t0, Reload_Map  

    # Increment valid key count  
    addi $t2, $t2, 1  

skip_key:  
    # Move to next key  
    addi $s1, $s1, 4       # Move to next key address  
    addi $s0, $s0, -1      # Decrement remaining key count  

    # If more keys exist, continue loop  
    bnez $s0, process_keys_loop  

key_handled:  
    # Restore registers  
    lw $ra, 0($sp)  
    lw $s0, 4($sp)  
    lw $s1, 8($sp)  
    lw $s2, 12($sp)  
    addi $sp, $sp, 16  
    jr $ra  

keyboard_done:  
    # Clear movement flag  
    sw $zero, player_move_flag  

    # Clear key states  
    li $t1, 0  
clear_keys:  
    sb $zero, pressed_keys($t1)  # Reset pressed keys  
    addi $t1, $t1, 1  
    blt $t1, 256, clear_keys  

    # Restore registers  
    lw $ra, 0($sp)  
    lw $s0, 4($sp)  
    lw $s1, 8($sp)  
    lw $s2, 12($sp)  
    addi $sp, $sp, 16  
    jr $ra  

# ===========================  
#     Draw the characters
# ===========================  
draw_game:  
    addi $sp, $sp, -4  
    sw $ra, 0($sp)  
   

    # Draw Ice Girl  
    li $a0, DRAW_ON_LAYER  
    la $a1, player1_path  
    lw $a2, player1_x  
    lw $a3, player1_y  
    li $t0, CHARACTER_LAYER  
    li $v0, SYSCALL_WINDOW  
    syscall 
    
     
    # Draw Fire Boy  
    li $a0, DRAW_ON_LAYER  
    la $a1, player2_path  
    lw $a2, player2_x  
    lw $a3, player2_y  
    li $t0, CHARACTER_LAYER  
    li $v0, SYSCALL_WINDOW  
    syscall   

    # Update character cooedinates
    lw $t1, player1_x   
    lw $t2, player1_y  

    addi $t3, $t1, PLAYER_WIDTH  
    addi $t4, $t2, PLAYER_HEIGHT  
    li $t0, 0xFF00FF00  

    lw $ra, 0($sp)  
    addi $sp, $sp, 4  
    jr $ra  

# ===========================  
# Exit Game Branch  
# ===========================  
set_game_exit:  
    li $t0, 0  
    sw $t0, game_running  
    j key_handled  
    
exit_game:  
    li $v0, EXIT  
    syscall  

# ===========================  
# Collision Detection - left and right  
# ===========================  
check_collision:  
    addi $sp, $sp, -24   
    sw $ra, 0($sp)  
    sw $s0, 4($sp)  
    sw $s1, 8($sp)  
    sw $s2, 12($sp)  
    sw $s3, 16($sp)  
    sw $s4, 20($sp)   

    move $s0, $a0  # new x  
    move $s1, $a1  # new y  
    li $s2, PLAYER_WIDTH  
    li $s3, PLAYER_HEIGHT  

    # Character boundaries  
    move $t0, $s0          # left  
    add $t1, $s0, $s2      # right  
    move $t2, $s1          # top  
    add $t3, $s1, $s3      # bottom  
    
    # Read currentMap value  
    lw $t4, currentMap     # Load currentMap value into $t4  
    
    # Check currentMap value and select appropriate wall data  
    beq $t4, $zero, select_walls_1  # If currentMap is 0, jump to walls_1  
    beq $t4, 1, select_walls_2      # If currentMap is 1, jump to walls_2  

select_walls_1:  
    la $t4, walls_1          # Load starting address of walls_1  
    lw $t5, wall_count_1     # Load wall count for walls_1  
    j collision_loop         # Jump to subsequent processing  

select_walls_2:  
    la $t4, walls_2          # Load starting address of walls_2  
    lw $t5, wall_count_2     # Load wall count for walls_2  


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

collision_loop:  


    beqz $t5, no_collision

    lw $t6, 0($t4)   # wall_left
    lw $t7, 4($t4)   # wall_top
    lw $t8, 8($t4)   # wall_right
    lw $t9, 12($t4)  # wall_bottom

    
    bge $t0, $t8, skip
    ble $t1, $t6, skip
    bge $t2, $t9, skip
    ble $t3, $t7, skip

   
    lw $t4, move_horizon
    bnez $t4, collision_detected

    
    bgt $t3, $t9, upward_collision

collision_detected:
    li $v0, 0
    j collision_end

skip:
    addi $t4, $t4, 16
    addi $t5, $t5, -1

    j collision_loop





upward_collision:  
    # Determine which player called this function  
    lw $t0, currentPlayer  # Load current player state variable into $t0  

    # Set v0 to specific value to indicate upward collision  
    li $v0, 2   # Use 2 to represent upward collision  

    beq $t0, $zero, player1_collision  # If player1 called: $t0 == 0  
    # Otherwise handle player2 collision logic  
    sw $t9, headCollision2  # Save player2's head collision  

    j collision_end  # End  
    
player1_collision:  
    sw $t9, headCollision  # Save player1's head collision  
    j collision_end  # End  

no_collision:  
    li $v0, 1          # No collision, set v0 to 1  

collision_end:  
    lw $ra, 0($sp)  
    lw $s0, 4($sp)  
    lw $s1, 8($sp)  
    lw $s2, 12($sp)  
    lw $s3, 16($sp)   
    lw $s4, 20($sp)  
    addi $sp, $sp, 24  
    jr $ra  
    
# ===========================  
#   Check Collision with Stones  
# ===========================  
check_stone_collision:  
    # Save return address  
    addi $sp, $sp, -20  
    sw $ra, 0($sp)  
    sw $s0, 4($sp)  
    sw $s1, 8($sp)  
    sw $s2, 12($sp)  
    sw $s3, 16($sp)  

    # Check current player  
    lw $t9, currentPlayer  # Load current player (0 for player1, 1 for player2)  

    # Calculate player boundaries  
    beqz $t9, player1_stone_check  # If player1, jump to blue gem detection  
    j player2_stone_check          # Otherwise player2, jump to red gem detection  
    
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

player1_stone_check:  


    # 1. Calculate player1's bounding box 
    lw $t0, player1_x
    lw $t1, player1_y
    addi $t2, $t0, PLAYER_WIDTH
    addi $t3, $t1, PLAYER_HEIGHT

    # 2. Check if blue gem is active
    lw $t4, blue_stone_active
    beqz $t4, no_stone_collision

    # 3. Calculate blue gem's bounding box 
    lw $t5, blue_stone_x
    lw $t6, blue_stone_y
    addi $t7, $t5, GEM_WIDTH
    addi $t8, $t6, GEM_HEIGHT

    # 4. Perform collision detection using bounding box overlap test  
    bge $t0, $t7, no_stone_collision
    ble $t2, $t5, no_stone_collision
    bge $t1, $t8, no_stone_collision
    ble $t3, $t6, no_stone_collision

    # 5. If collision detected: 
    sw $zero, blue_stone_active
    lw $t9, score
    addi $t9, $t9, 10
    sw $t9, score

    li $v0, 1

    j stone_collision_end

player2_stone_check:
    lw $t0, player2_x
    lw $t1, player2_y
    addi $t2, $t0, PLAYER_WIDTH
    addi $t3, $t1, PLAYER_HEIGHT

    lw $t4, red_stone_active
    beqz $t4, no_stone_collision

    lw $t5, red_stone_x
    lw $t6, red_stone_y
    addi $t7, $t5, GEM_WIDTH
    addi $t8, $t6, GEM_HEIGHT

    bge $t0, $t7, no_stone_collision
    ble $t2, $t5, no_stone_collision
    bge $t1, $t8, no_stone_collision
    ble $t3, $t6, no_stone_collision

    sw $zero, red_stone_active
    lw $t9, score
    addi $t9, $t9, 10
    sw $t9, score

    li $v0, 1

    j stone_collision_end




no_stone_collision:  
    li $v0, 0                     # No collision  

stone_collision_end:  
    lw $ra, 0($sp)  
    lw $s0, 4($sp)  
    lw $s1, 8($sp)  
    lw $s2, 12($sp)  
    lw $s3, 16($sp)  
    addi $sp, $sp, 20  
    jr $ra  
    
# ===========================   
# Player 1 (Ice Girl) Movement Handlers  
# ===========================  
player1_left:  
    # Set as player1  
    li $t2, 0  
    sw $t2, currentPlayer   # Set currentPlayer to 0, representing player1  
      
    lw $t0, player1_x  
    li $t1, MOVE_SPEED  
    sub $t0, $t0, $t1  

    move $a0, $t0  # New x coordinate  
    lw $a1, player1_y  # Current y coordinate  
    
    li $t4, 1              # Set move_horizon to 1  
    sw $t4, move_horizon   # Update move_horizon variable  
    

      
    jal check_collision  
    beqz $v0, key_handled  # If collision, don't update position  
    sw $a0, player1_x  
    
    # Check if falling  
    j player1_downward   

player1_right:  
    # Set as player1  
    li $t2, 0  
    sw $t2, currentPlayer   # Set currentPlayer to 0, representing player1  
      
    lw $t0, player1_x  
    li $t1, MOVE_SPEED  
    add $t0, $t0, $t1  
    
    move $a0, $t0  # New x coordinate  
    lw $a1, player1_y  # Current y coordinate  
    
    li $t4, 1              # Set move_horizon to 1  
    sw $t4, move_horizon   # Update move_horizon variable  
    
    jal check_collision  
    beqz $v0, key_handled  
      
    sw $a0, player1_x   

    j player1_downward   

                                
# Jump handling function  
player1_up:  
    # Set as player1  
    li $t2, 0  
    sw $t2, currentPlayer   # Set currentPlayer to 0, representing player1  
    # Can only jump when on the ground  
    lw $t4, player1Jumping  
    bne $t4, $zero, key_handled  
    
    # Check if on the ground  
    lw $a0, player1_x  
    lw $a1, player1_y  
    addi $a1, $a1, 5  # Check bottom  
    jal check_collision   
    bnez $v0, key_handled  # If not on ground, can't jump  
    
    # Set jump state  
    li $t4, 1  
    sw $t4, player1Jumping  
    
    # Set initial upward velocity  
    lw $t4, jumpVelocity  
    sw $t4, player1VY  
    j key_handled  
    
    
# ===========================  
# Player 2 (Fire Boy) Movement Handlers  
# ===========================  

player2_left:  
    # Set as player2  
    li $t2, 1  
    sw $t2, currentPlayer   # Set currentPlayer to 1, representing player2  

    #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    # Fireboy move Left
    lw $t0, player2_x
    li $t1, MOVE_SPEED
    sub $t0, $t0, $t1
    move $a0, $t0
    lw $a1, player2_y  
    
    #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    li $t4, 1              # Set move_horizon to 1  
    sw $t4, move_horizon   # Update move_horizon variable  
      
    jal check_collision  
    beqz $v0, key_handled  # If collision, don't update position  
    sw $a0, player2_x  
    j player2_downward  

player2_right:  
    # Set as player2  
    li $t2, 1  
    sw $t2, currentPlayer   # Set currentPlayer to 1, representing player2  

    
    #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    # Fireboy move right
    lw $t0, player2_x
    li $t1, MOVE_SPEED
    add $t0, $t0, $t1
    move $a0, $t0
    lw $a1, player2_y

    #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    li $t4, 1              # Set move_horizon to 1  
    sw $t4, move_horizon   # Update move_horizon variable  
    
    jal check_collision  
    beqz $v0, key_handled  
      
    sw $a0, player2_x  
    j player2_downward  
    
# Jump handling function  
player2_up:  
    # Set as player2  
    li $t2, 1  
    sw $t2, currentPlayer   # Set currentPlayer to 1, representing player2  
    # Can only jump when on the ground  
    lw $t4, player2Jumping  
    bne $t4, $zero, key_handled  
    
    # Check if on the ground  
    lw $a0, player2_x  
    lw $a1, player2_y  
    addi $a1, $a1, 5  # Check bottom  
    jal check_collision   
    bnez $v0, key_handled  # If not on ground, can't jump  
    
    # Set jump state  
    li $t4, 1  
    sw $t4, player2Jumping  # Update Fire Boy's jump state  

    # Set initial upward velocity  
    lw $t4, jumpVelocity  
    sw $t4, player2VY  # Update Fire Boy's vertical velocity  
    j key_handled  
    

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

player2_downward:  



    # 1
    lw $t0, player2Jumping
    bne $t0, $zero, key_handled

    # 2
    lw $t1, player2_x
    lw $t2, player2_y
    addi $t2, $t2, 5
    move $a0, $t1
    move $a1, $t2
    jal check_collision
    beqz $v0, key_handled

    # 3
    li $t4, 1
    sw $t4, player2Jumping
    li $t4, 1
    sw $t4, player2VY

    j key_handled

player1_downward:
    # 1
    lw $t0, player1Jumping
    bne $t0, $zero, key_handled

    # 2
    lw $t1, player1_x
    lw $t2, player1_y
    addi $t2, $t2, 5
    move $a0, $t1
    move $a1, $t2
    jal check_collision
    beqz $v0, key_handled

    # 3
    li $t4, 1
    sw $t4, player1Jumping
    li $t4, 1
    sw $t4, player1VY

    j key_handled



# ===========================   
# JUMP or DROP  
# ===========================  
updatePhysics:  
    addi $sp, $sp, -16        # Allocate space for return address and registers  
    sw $ra, 12($sp)           # Save return address  
    sw $s0, 8($sp)            # Save $s0  
    sw $s1, 4($sp)            # Save $s1  
    sw $s2, 0($sp)            # Save $s2  

    # Select wall data for current map  
    lw $s0, currentMap        # Load currentMap value  
    beq $s0, $zero, updatePhysics_select_walls_1  
    beq $s0, 1, updatePhysics_select_walls_2  
    j updatePhysicsDone       # Invalid map, exit directly  

updatePhysics_select_walls_1:  
    la $s1, walls_1           # Wall data starting address  
    lw $s2, wall_count_1      # Number of walls  
    j process_player1  

updatePhysics_select_walls_2:  
    la $s1, walls_2           # Wall data starting address  
    lw $s2, wall_count_2      # Number of walls  

process_player1:  
    # Process player 1 jumping  
    lw $t0, player1Jumping  
    beq $t0, $zero, process_player2  

    li $t0, 1  
    sw $t0, player_move_flag   

    # Update vertical velocity and position  
    lw $t1, player1VY  
    lw $t2, gravity  
    add $t1, $t1, $t2  
    sw $t1, player1VY  
    
    lw $t3, player1_y  
    add $t3, $t3, $t1  
    
    # Check for collisions  
    lw $a0, player1_x  
    move $a1, $t3  
    jal check_collision  
    
    # Handle based on collision result  
    beqz $v0, handle_player1_stop_jump    # Bottom collision  
    beq $v0, 1, update_player1_position   # No collision  
    beq $v0, 2, handle_player1_head_collision  # Head collision  
    j process_player2  

handle_player1_head_collision:  
    lw $t6, headCollision  
    beqz $t6, update_player1_position  

    addi $t3, $t6, 1          # Set character top to wall bottom+1  
    sw $t3, player1_y  
    li $t1, 1  
    sw $t1, player1VY  
    j process_player2  

handle_player1_stop_jump:  
    sw $zero, player1VY  
    sw $zero, player1Jumping  
    
    # Find the nearest wall bottom coordinate  
    move $t4, $s1             # Wall data starting address  
    move $t5, $s2             # Number of walls  

find_bottom_wall_1:  
    lw $t6, 0($t4)   # wall left  
    lw $t7, 4($t4)   # wall top  
    lw $t8, 8($t4)   # wall right  
    lw $t9, 12($t4)  # wall bottom  

    lw $t0, player1_x              
    addi $t1, $t0, PLAYER_WIDTH     

    ble $t1, $t6, next_wall1  
    bge $t0, $t8, next_wall1    
    bge $t3, $t9, next_wall1   

    subi $t3, $t7, PLAYER_HEIGHT  
    j set_player1_y  

next_wall1:  
    addi $t4, $t4, 16  
    addi $t5, $t5, -1  
    bgtz $t5, find_bottom_wall_1  

    li $t3, 380  # Default ground height  
    
set_player1_y:  
    addi $t3, $t3, -1  
    sw $t3, player1_y  
    j process_player2  

update_player1_position:                    
    sw $a1, player1_y  

process_player2:  
    # Similarly process player 2  
    lw $t0, player2Jumping  
    beq $t0, $zero, updatePhysicsDone  

    li $t0, 1  
    sw $t0, player_move_flag    

    lw $t1, player2VY  
    lw $t2, gravity  
    add $t1, $t1, $t2  
    sw $t1, player2VY  
    
    lw $t3, player2_y  
    add $t3, $t3, $t1  
    
    lw $a0, player2_x  
    move $a1, $t3  
    jal check_collision  
    
    beqz $v0, handle_player2_stop_jump  
    beq $v0, 1, update_player2_position  
    beq $v0, 2, handle_player2_head_collision  
    j updatePhysicsDone  

handle_player2_head_collision:  
    lw $t6, headCollision2  
    beqz $t6, update_player2_position  

    addi $t3, $t6, 1  
    sw $t3, player2_y  
    li $t1, 1  
    sw $t1, player2VY  
    j updatePhysicsDone  

handle_player2_stop_jump:  
    sw $zero, player2VY  
    sw $zero, player2Jumping  
    
    move $t4, $s1             # Use previously selected wall data  
    move $t5, $s2             # Number of walls  

find_bottom_wall_2:  
    lw $t6, 0($t4)   # wall left  
    lw $t7, 4($t4)   # wall top  
    lw $t8, 8($t4)   # wall right  
    lw $t9, 12($t4)  # wall bottom  

    lw $t0, player2_x              
    addi $t1, $t0, PLAYER_WIDTH     

    ble $t1, $t6, next_wall2  
    bge $t0, $t8, next_wall2    
    bge $t3, $t9, next_wall2   

    subi $t3, $t7, PLAYER_HEIGHT  
    j set_player2_y  

next_wall2:  
    addi $t4, $t4, 16  
    addi $t5, $t5, -1  
    bgtz $t5, find_bottom_wall_2  

    li $t3, 380  # Default ground height  
    
set_player2_y:  
    addi $t3, $t3, -1  
    sw $t3, player2_y  
    j updatePhysicsDone  

update_player2_position:                    
    sw $a1, player2_y  

updatePhysicsDone:  
    lw $ra, 12($sp)           # Restore return address  
    lw $s0, 8($sp)            # Restore registers  
    lw $s1, 4($sp)            
    lw $s2, 0($sp)            
    addi $sp, $sp, 16         # Restore stack space  
    jr $ra                    # Return  

    
# ===========================   
# Change Map and Reload  
# ===========================  
changeMap:  
    
    # Read currentMap value  
    lw $t0, currentMap        # Load currentMap value into $t0  
    # Check if currentMap is 1  
    beq $t0, 1, set_to_zero  
    # If currentMap is not 1 (i.e., 0), set it to 1 and jump to load_map_2  
    li $t0, 1  
    sw $t0, currentMap  
    j load_map_2  

set_to_zero:  
    # If currentMap is 1, set it to 0 and jump to load_map_1  
    li $t0, 0  
    sw $t0, currentMap  
    j load_map_1  
    
    
Reload_Map:	   

    sw $zero, is_dead  
    # Read currentMap value  
    lw $t0, currentMap        # Load currentMap value into $t0  
    # Check if currentMap is 1  
    beq $t0, 1, load_map_2   
    # If currentMap is not 1 (i.e., 0), jump to load_map_1  
    j load_map_1  

load_map_1:  
    # Set initial coordinates  
    lw $t1, player1_x_map_1  
    sw $t1, player1_x  
    lw $t1, player1_y_map_1  
    sw $t1, player1_y  
    lw $t1, player2_x_map_1  
    sw $t1, player2_x  
    lw $t1, player2_y_map_1  
    sw $t1, player2_y  
    
    
    jal clear_stone  
    
    li $t1, 1  
    sw $t1, red_stone_active  
    sw $t1, blue_stone_active    
    
    # Change background  
    li $a0, 13                # New service code for changing background  
    la $a1, bg_path_1         # New background image path  
    li $v0, 120               # GameWindow system call  
    syscall  
  
    j changeMapDone             # Jump to end after loading  
  
load_map_2:   
    lw $t1, player1_x_map_2  
    sw $t1, player1_x  
    lw $t1, player1_y_map_2  
    sw $t1, player1_y  
    lw $t1, player2_x_map_2  
    sw $t1, player2_x  
    lw $t1, player2_y_map_2  
    sw $t1, player2_y  
    
    lw $t1, box_map_2_x  
    sw $t1, box_x  
    lw $t1, box_map_2_y  
    sw $t1, box_y  
    
    jal clear_stone  
      
    # Change background  
    li $a0, 13                # New service code for changing background  
    la $a1, bg_path_2         # New background image path  
    li $v0, 120               # GameWindow system call  

    syscall                   # Execute system call  

  

changeMapDone:  
    # Frame delay  
    li $v0, SLEEP  
    li $a0, FRAME_DELAY  
    syscall  
    j key_handled  
