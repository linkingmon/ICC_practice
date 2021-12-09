module SGDE ( ready, done, clk, reset, sprite, start, type, X, Y, SR_CEN, SR_A, SR_Q, FB_CEN, FB_WEN, FB_A, FB_D, FB_Q);

input clk, reset, sprite, start;
input [1:0] type;
input [5:0] X, Y;
input [12:0] SR_Q;
input [11:0] FB_Q;

output ready, done;
output SR_CEN, FB_CEN, FB_WEN;
output [8:0] SR_A;
output [11:0] FB_A, FB_D;

reg [5:0] x_r [0:18], x_w [0:18];
reg [5:0] y_r [0:18], y_w [0:18];
reg [1:0] type_r [0:18], type_w [0:18];
reg [5:0] man_x_r, man_x_w;
reg [5:0] man_y_r, man_y_w;
reg ghost_mask_all_r [0:63][0:63], ghost_mask_all_w [0:63][0:63];
reg candy_mask_all_r [0:63][0:63], candy_mask_all_w [0:63][0:63];

reg ghost_mask_r [0:7][0:7], ghost_mask_w [0:7][0:7];
reg candy_mask_r [0:7][0:7], candy_mask_w [0:7][0:7];
reg man_mask_r [0:7][0:7], man_mask_w [0:7][0:7];

reg [1:0] M_state_r, M_state_w;
reg [1:0] man_state_r, man_state_w;

reg [2:0] state_r, state_w;
reg [8:0] SR_A_r, SR_A_w;
reg [8:0] SR_A_delay_r;

reg ready_r, ready_w;
reg start_r, start_w;

reg sprite_r, sprite_w;
reg [5:0] x_i_w, x_i_r;
reg [5:0] y_i_w, y_i_r;
reg [1:0] type_i_w, type_i_r;

reg [4:0] other_pt_r, other_pt_w;
reg [4:0] flower_pt_r, flower_pt_w;
reg [4:0] draw_pt_r, draw_pt_w;
reg [4:0] mask_pt_r, mask_pt_w;
reg [5:0] mask_ctr_r, mask_ctr_w;
wire [5:0] mask_x, mask_y;
wire [5:0] man_mask_x, man_mask_y;

reg [11:0] FB_A_r, FB_A_w;
reg [11:0] FB_D_r, FB_D_w;
reg FB_WEN_r, FB_WEN_w;

reg [11:0] bg_ctr_w, bg_ctr_r;
reg bg_state_r, bg_state_w;
reg FB_WEN_start_w, FB_WEN_start_r;

parameter S_READ_MASK = 0;
parameter S_READ_DATA = 1;
parameter S_DRAW_FLOWER = 2;
parameter S_DRAW_OTHER = 3;
parameter S_DRAW_MAN = 4;
parameter S_DONE = 5;
parameter S_READ_MAN_MASK = 6;


parameter S_M_IDLE = 0;
parameter S_M_COMBINE = 1;
parameter S_M_MAN = 2;
parameter S_M_DONE = 3;

assign SR_CEN = 0;
assign FB_CEN = 0;
assign FB_WEN = (bg_state_r == 1'b0) ? 1'b0 : FB_WEN_r;
assign SR_A = SR_A_r;
assign ready = ready_r;
assign FB_A = (bg_state_r == 1'b0) ? bg_ctr_r : FB_A_r;
assign FB_D = (bg_state_r == 1'b0) ? 12'b1100_1111_0000 : FB_D_r;

integer i, j;
assign mask_x = x_r[mask_pt_r]+mask_ctr_r[2:0];
assign mask_y = y_r[mask_pt_r]+mask_ctr_r[5:3];
assign man_mask_x = man_x_r+mask_ctr_r[2:0];
assign man_mask_y = man_y_r+mask_ctr_r[5:3];
assign done = (state_r == S_DONE) ? 1'b1 : 1'b0;

always@(*) begin
    bg_ctr_w = bg_ctr_r;
    bg_state_w = bg_state_r;
    if(bg_state_r == 1'b0)
        bg_ctr_w = bg_ctr_r + 1;
        if(bg_ctr_r == 12'd4095)
            bg_state_w = 1'b1;
end

always@(*) begin
    man_state_w = man_state_r;
    M_state_w = M_state_r;
    mask_pt_w = mask_pt_r;
    mask_ctr_w = mask_ctr_r;
    for(i=0;i<64;i=i+1) begin
        for(j=0;j<64;j=j+1) begin
            ghost_mask_all_w[i][j] = ghost_mask_all_r[i][j];
            candy_mask_all_w[i][j] = candy_mask_all_r[i][j];
        end
    end
    case(M_state_r)
        S_M_IDLE: begin
            if (state_r==S_DRAW_FLOWER) M_state_w = S_M_COMBINE;
        end
        S_M_COMBINE: begin
            if ((mask_pt_r==other_pt_r-1) && (mask_ctr_r==6'd63)) M_state_w = S_M_MAN;
            if (type_r[mask_pt_r]==2'b01) begin //G
                ghost_mask_all_w[mask_y][mask_x] = (ghost_mask_r[mask_ctr_r[5:3]][mask_ctr_r[2:0]]==1'b1)? 1'b1: ghost_mask_all_r[mask_y][mask_x];
            end else begin
                candy_mask_all_w[mask_y][mask_x] = (candy_mask_r[mask_ctr_r[5:3]][mask_ctr_r[2:0]]==1'b1)? 1'b1: candy_mask_all_r[mask_y][mask_x];
            end
            if (mask_ctr_r==6'd63) begin
                mask_pt_w = mask_pt_r + 1'b1;
            end
            mask_ctr_w = mask_ctr_r + 1'b1;
        end

        S_M_MAN: begin
            if (mask_ctr_r==6'd63) M_state_w = S_M_DONE;
            mask_ctr_w = mask_ctr_r + 1'b1;
            man_state_w = man_mask_r[mask_ctr_r[5:3]][mask_ctr_r[2:0]]==1'b0 ?  man_state_r :
                        candy_mask_all_r[man_mask_y][man_mask_x]==1'b1 || man_state_r==1'b1 ? 2'b01 : 
                        ghost_mask_all_r[man_mask_y][man_mask_x]==1'b1 ? 2'b10 : man_state_r; 
        end
        S_M_DONE: begin
        end

    endcase
end

always@(*) begin
    SR_A_w = SR_A_r;
    state_w = state_r;
    ready_w = ready_r;
    sprite_w = sprite_r;
    x_i_w = x_i_r;
    y_i_w = y_i_r;
    type_i_w = type_i_r;
    other_pt_w = other_pt_r;
    flower_pt_w = flower_pt_r;
    draw_pt_w = draw_pt_r;
    start_w = start_r;
    for(i=0;i<19;i=i+1) begin
        x_w[i] = x_r[i];
        y_w[i] = y_r[i];
        type_w[i] = type_r[i];
    end
    man_x_w = man_x_r;
    man_y_w = man_y_r;
    for(i=0;i<8;i=i+1) begin
        for(j=0;j<8;j=j+1) begin
            ghost_mask_w[i][j] = ghost_mask_r[i][j];
            candy_mask_w[i][j] = candy_mask_r[i][j];
            man_mask_w[i][j] = man_mask_r[i][j];
        end
    end
    FB_A_w = FB_A_r;
    FB_D_w = FB_D_r;
    FB_WEN_w = FB_WEN_r;
    FB_WEN_start_w = FB_WEN_start_r;
    case(state_r)
        S_READ_MAN_MASK: begin
            if (SR_A_r==9'd63) SR_A_w = 192;
            else SR_A_w = SR_A_r + 1'b1;

            man_mask_w[SR_A_delay_r[5-:3]][SR_A_delay_r[2-:3]] = SR_Q[0];

            if(SR_A_delay_r == 9'd63) begin
                state_w = S_READ_MASK;
            end
        end
        S_READ_MASK: begin
            SR_A_w = SR_A_r + 1'b1;
            if(SR_A_delay_r[8])
                candy_mask_w[SR_A_delay_r[5-:3]][SR_A_delay_r[2-:3]] = SR_Q[0];
            else 
                ghost_mask_w[SR_A_delay_r[5-:3]][SR_A_delay_r[2-:3]] = SR_Q[0];
            if(SR_A_delay_r == 9'd319) begin
                state_w = S_READ_DATA;
                ready_w = 1'b1;
            end
        end
        S_READ_DATA: begin
            sprite_w = sprite;
            x_i_w = X;
            y_i_w = Y;
            type_i_w = type;
            start_w = start | start_r;
            if(sprite_r) begin
                case(type_i_r)
                    2'b00: begin    // man
                        man_x_w = x_i_r;
                        man_y_w = y_i_r;
                    end
                    2'b01: begin    // ghost
                        x_w[other_pt_r] = x_i_r;
                        y_w[other_pt_r] = y_i_r;
                        type_w[other_pt_r] = type_i_r;
                        other_pt_w = other_pt_r + 1'b1;
                    end
                    2'b10: begin    // candy
                        x_w[other_pt_r] = x_i_r;
                        y_w[other_pt_r] = y_i_r;
                        type_w[other_pt_r] = type_i_r;
                        other_pt_w = other_pt_r + 1'b1;
                    end
                    2'b11: begin    // flower
                        x_w[flower_pt_r] = x_i_r;
                        y_w[flower_pt_r] = y_i_r;
                        type_w[flower_pt_r] = type_i_r;
                        flower_pt_w = flower_pt_r - 1'b1;
                    end
                endcase
            end
            else if(start_r) begin
                other_pt_w = other_pt_r;
                flower_pt_w = flower_pt_r;
                SR_A_w = 320;
                if(bg_state_r == 1'b1)
                    state_w = S_DRAW_FLOWER;
            end
        end
        S_DRAW_FLOWER: begin
            // mask_all
            // draw flower > other
            SR_A_w = SR_A_r + 1'b1;
            FB_A_w[5:0] = x_r[draw_pt_r] + SR_A_delay_r[2:0];
            FB_A_w[11:6] = y_r[draw_pt_r] + SR_A_delay_r[5:3];
            FB_D_w = SR_Q[12:1];
            if(SR_A_r[5:0] == 63)
                SR_A_w = 320;
            if(SR_A_delay_r[5:0] == 63) begin
                draw_pt_w = draw_pt_r - 1'b1;
            end
            if(draw_pt_r == flower_pt_r) begin
                state_w = S_DRAW_OTHER;
                draw_pt_w = 0;
                FB_WEN_w = 1;
                SR_A_w = (type_r[0] == 2'b01) ? 192 : 256;
            end
            else  
                FB_WEN_start_w = (SR_A_r[5:0] == 0) ? 1 : FB_WEN_start_r;
                FB_WEN_w = (FB_WEN_start_r == 1 & SR_Q[0] == 1) ? 1'b0 : 1'b1;
        end
        S_DRAW_OTHER: begin
            // mask_all
            // draw flower > other
            SR_A_w = SR_A_r + 1'b1;
            FB_A_w[5:0] = x_r[draw_pt_r] + SR_A_delay_r[2:0];
            FB_A_w[11:6] = y_r[draw_pt_r] + SR_A_delay_r[5:3];
            FB_D_w = SR_Q[12:1];
            if(SR_A_r[5:0] == 63)
                SR_A_w = (type_r[draw_pt_r+1'b1] == 2'b01) ? 192 : 256;
            if(SR_A_delay_r[5:0] == 63) begin
                draw_pt_w = draw_pt_r + 1'b1;
            end
            if(draw_pt_r == other_pt_r) begin
                SR_A_w = SR_A_r;
                FB_WEN_w = 1;
                if (M_state_r == S_M_DONE) begin
                    state_w = S_DRAW_MAN;
                    case(man_state_r)
                        2'b00: SR_A_w = 0;
                        2'b01: SR_A_w = 64;
                        2'b10: SR_A_w = 128;
                    endcase
                end
            end
            else 
                FB_WEN_start_w = (SR_A_r[5:0] == 0) ? 1 : FB_WEN_start_r;
                FB_WEN_w = (FB_WEN_start_r == 1 & SR_Q[0] == 1) ? 1'b0 : 1'b1;
        end
        S_DRAW_MAN: begin
            SR_A_w = SR_A_r + 1'b1;
            FB_A_w[5:0] = man_x_r + SR_A_delay_r[2:0];
            FB_A_w[11:6] = man_y_r + SR_A_delay_r[5:3];
            FB_D_w = SR_Q[12:1];
            if(SR_A_delay_r[5:0] == 63) begin
                state_w = S_DONE;
                FB_WEN_w = 1;
            end
            else 
                FB_WEN_start_w = (SR_A_r[5:0] == 0) ? 1 : FB_WEN_start_r;
                FB_WEN_w = (FB_WEN_start_r == 1 & SR_Q[0] == 1) ? 1'b0 : 1'b1;
        end
        S_DONE: begin
            
        end
    endcase
end

always@(posedge clk or posedge reset) begin
    if(reset) begin
        SR_A_delay_r <= 0;
        SR_A_r <= 0;
        state_r <= S_READ_MAN_MASK;
        ready_r <= 0;
        sprite_r <= 0;
        x_i_r <= 0;
        y_i_r <= 0;
        type_i_r <= 0;
        other_pt_r <= 0;
        flower_pt_r <= 18;
        draw_pt_r <= 18;
        start_r <= 0;
        for(i=0;i<19;i=i+1) begin
            x_r[i] <= 0;
            y_r[i] <= 0;
            type_r[i] <= 0;
        end
        man_x_r <= 0;
        man_y_r <= 0;
        for(i=0;i<64;i=i+1) begin
            for(j=0;j<64;j=j+1) begin
                ghost_mask_all_r[i][j] <= 0;
                candy_mask_all_r[i][j] <= 0;
            end
        end
        for(i=0;i<8;i=i+1) begin
            for(j=0;j<8;j=j+1) begin
                ghost_mask_r[i][j] <= 0;
                candy_mask_r[i][j] <= 0;
                man_mask_r[i][j] <= 0;
            end
        end
        FB_A_r <= 0;
        FB_D_r <= 0;
        FB_WEN_r <= 1;
        man_state_r <= 2'b00;
        M_state_r <= S_M_IDLE;
        mask_pt_r <= 0;
        mask_ctr_r <= 0;
        bg_ctr_r <= 0;
        bg_state_r <= 0;
        FB_WEN_start_r <= 0;
    end
    else begin
        SR_A_delay_r <= SR_A_r;
        SR_A_r <= SR_A_w;
        state_r <= state_w;
        ready_r <= ready_w;
        sprite_r <= sprite_w;
        x_i_r <= x_i_w;
        y_i_r <= y_i_w;
        type_i_r <= type_i_w;
        other_pt_r <= other_pt_w;
        flower_pt_r <= flower_pt_w;
        draw_pt_r <= draw_pt_w;
        start_r <= start_w;
        for(i=0;i<19;i=i+1) begin
            x_r[i] <= x_w[i];
            y_r[i] <= y_w[i];
            type_r[i] <= type_w[i];
        end
        man_x_r <= man_x_w;
        man_y_r <= man_y_w;
        for(i=0;i<64;i=i+1) begin
            for(j=0;j<64;j=j+1) begin
                ghost_mask_all_r[i][j] <= ghost_mask_all_w[i][j];
                candy_mask_all_r[i][j] <= candy_mask_all_w[i][j];
            end
        end
        for(i=0;i<8;i=i+1) begin
            for(j=0;j<8;j=j+1) begin
                ghost_mask_r[i][j] <= ghost_mask_w[i][j];
                candy_mask_r[i][j] <= candy_mask_w[i][j];
                man_mask_r[i][j] <= man_mask_w[i][j];
            end
        end
        FB_A_r <= FB_A_w;
        FB_D_r <= FB_D_w;
        FB_WEN_r <= FB_WEN_w;

        man_state_r <= man_state_w;
        M_state_r <= M_state_w;
        mask_pt_r <= mask_pt_w;
        mask_ctr_r <= mask_ctr_w;
        bg_ctr_r <= bg_ctr_w;
        bg_state_r <= bg_state_w;
        FB_WEN_start_r <= FB_WEN_start_w;
    end
end

endmodule
