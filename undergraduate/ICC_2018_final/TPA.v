module TPA(clk, reset_n, 
	   SCL, SDA, 
	   cfg_req, cfg_rdy, cfg_cmd, cfg_addr, cfg_wdata, cfg_rdata);
input 		clk; 
input 		reset_n;
// Two-Wire Protocol slave interface 
input 		SCL;  
inout		SDA;

// Register Protocal Master interface 
input		cfg_req;
output		cfg_rdy;
input		cfg_cmd;
input	[7:0]	cfg_addr;
input	[15:0]	cfg_wdata;
output	[15:0]  cfg_rdata;

reg	[15:0] Register_Spaces_r[0:255], Register_Spaces_w[0:255];
reg cfg_rdy_r, cfg_rdy_w;

// ===== Coding your RTL below here ================================= 
integer i;
parameter S_RIM_IDLE = 0;
parameter S_RIM_READ = 1;
parameter S_RIM_WRITE = 2;
parameter S_RIM_WRITE_DONE = 3;
parameter S_RIM_READY = 4;

parameter S_TWP_IDLE = 0;
parameter S_TWP_START = 1;
parameter S_TWP_WRITE_ADDR = 2;
parameter S_TWP_WRITE_DATA = 3;
parameter S_TWP_WRITE_END = 4;
parameter S_TWP_READ_ADDR = 5;
parameter S_TWP_READ_DATA_START1 = 6;
parameter S_TWP_READ_DATA_START2 = 7;
parameter S_TWP_READ_DATA_START3 = 8;
parameter S_TWP_READ_DATA_START4 = 9;
parameter S_TWP_READ_DATA = 10;
parameter S_TWP_READ_END = 11;

parameter S_COL_IDLE = 0;
parameter S_COL_WRITE_DETECT = 1;
parameter S_COL_ADDR_DETECT = 2;
parameter S_COL_DETECT = 3;

parameter S_WRITE_IDLE = 0;
parameter S_WRITE_DONE = 1;

reg [2:0] rim_state_r, rim_state_w;
reg [3:0] twp_state_r, twp_state_w;
reg [1:0] col_state_r, col_state_w;
reg	[15:0] cfg_rdata_r, cfg_rdata_w;
reg [3:0] twp_counter_r, twp_counter_w;
reg [7:0] twp_addr_r, twp_addr_w;
reg [15:0] twp_data_r, twp_data_w;
reg [7:0] col_addr_r, col_addr_w;
reg rim_slow_r, rim_slow_w;
reg SDA_w;
reg [1:0] write_state_r, write_state_w;

assign cfg_rdata = cfg_rdata_r;
assign cfg_rdy = cfg_rdy_r;
assign SDA = (twp_state_r == S_TWP_READ_DATA_START2 || twp_state_r == S_TWP_READ_DATA_START3 || twp_state_r == S_TWP_READ_DATA_START4
                    || twp_state_r == S_TWP_READ_DATA || twp_state_r == S_TWP_READ_END) ? SDA_w : 1'bZ;
always@(*) begin
    col_state_w = col_state_r;
    col_addr_w = col_addr_r;
    case(col_state_r)
        S_COL_IDLE: begin
            if(rim_state_r == S_RIM_WRITE && twp_state_r == S_TWP_START) begin
                col_addr_w = cfg_addr;
                col_state_w = S_COL_WRITE_DETECT;
            end
        end
        S_COL_WRITE_DETECT: begin
            if(twp_state_r == S_TWP_WRITE_ADDR) col_state_w = S_COL_ADDR_DETECT;
            else col_state_w = S_COL_IDLE;
        end
        S_COL_ADDR_DETECT: begin
            if(twp_state_r == S_TWP_WRITE_DATA && twp_addr_r == col_addr_r) col_state_w = S_COL_DETECT;
        end
        S_COL_DETECT: begin
            if(twp_state_r == S_TWP_IDLE) col_state_w = S_COL_IDLE;
        end
    endcase
end

always@(*) begin
    write_state_w = write_state_r;
    for(i=0;i<256;i=i+1) Register_Spaces_w[i] = Register_Spaces_r[i];
    case(write_state_r)
        S_WRITE_IDLE: begin
            if(twp_state_r == S_TWP_WRITE_END && col_state_r != S_COL_DETECT && rim_slow_r == 0) begin
                Register_Spaces_w[twp_addr_r] = twp_data_r;
                write_state_w = S_WRITE_DONE;
            end
            else begin 
                if(rim_state_r == S_RIM_WRITE) begin
                    Register_Spaces_w[cfg_addr] = cfg_wdata;
                    write_state_w = S_WRITE_DONE;
                end
            end
        end
        S_WRITE_DONE: begin
            write_state_w = S_WRITE_IDLE;
        end
    endcase
end



always@(*) begin
    twp_state_w = twp_state_r;
    twp_counter_w = twp_counter_r;
    twp_addr_w = twp_addr_r;
    twp_data_w = twp_data_r;
    rim_slow_w = rim_slow_r;
    SDA_w = 0;
    case(twp_state_r)
        S_TWP_IDLE: begin
            if(SDA == 0) twp_state_w = S_TWP_START;
        end
        S_TWP_START: begin
            if(SDA == 0) twp_state_w = S_TWP_READ_ADDR;
            else twp_state_w = S_TWP_WRITE_ADDR;
        end
        S_TWP_WRITE_ADDR: begin
            twp_counter_w = twp_counter_r + 1;
            twp_addr_w[twp_counter_r] = SDA;
            if(rim_state_r == S_RIM_WRITE) rim_slow_w = 1;
            if(twp_counter_r == 7) begin
                twp_state_w = S_TWP_WRITE_DATA;
                twp_counter_w = 0;
            end
        end
        S_TWP_WRITE_DATA: begin
            twp_counter_w = twp_counter_r + 1;
            twp_data_w[twp_counter_r] = SDA;
            if(rim_state_r == S_RIM_WRITE) rim_slow_w = 1;
            if(twp_counter_r == 15) twp_state_w = S_TWP_WRITE_END;
        end
        S_TWP_WRITE_END: begin
            twp_state_w = S_TWP_IDLE;
            rim_slow_w = 0;
        end
        S_TWP_READ_ADDR: begin
            twp_counter_w = twp_counter_r + 1;
            twp_addr_w[twp_counter_r] = SDA;
            if(twp_counter_r == 7) begin
                twp_state_w = S_TWP_READ_DATA_START1;
                twp_counter_w = 0;
            end
        end
        S_TWP_READ_DATA_START1: begin
            twp_state_w = S_TWP_READ_DATA_START2;
        end
        S_TWP_READ_DATA_START2: begin
            twp_state_w = S_TWP_READ_DATA_START3;
            SDA_w = 1;
        end
        S_TWP_READ_DATA_START3: begin
            twp_state_w = S_TWP_READ_DATA_START4;
            SDA_w = 1;
        end
        S_TWP_READ_DATA_START4: begin
            twp_state_w = S_TWP_READ_DATA;
            SDA_w = 0;
        end
        S_TWP_READ_DATA: begin
            twp_counter_w = twp_counter_r + 1;
            SDA_w = Register_Spaces_r[twp_addr_r][twp_counter_r];
            if(twp_counter_r == 15) begin
                twp_state_w = S_TWP_READ_END;
                twp_counter_w = 0;
            end
        end
        S_TWP_READ_END: begin
            SDA_w = 1;
            twp_state_w = S_TWP_IDLE;
        end
    endcase
end


always@(*) begin
    rim_state_w = rim_state_r;
    cfg_rdy_w = cfg_rdy_r;
    cfg_rdata_w = cfg_rdata_r;
    case(rim_state_r)
        S_RIM_IDLE: begin
            if(cfg_req == 1) begin
                cfg_rdy_w = 1;
                if(cfg_cmd == 0) rim_state_w = S_RIM_READ;
                else rim_state_w = S_RIM_WRITE;
            end
        end
        S_RIM_READ: begin
            cfg_rdata_w = Register_Spaces_r[cfg_addr];
            rim_state_w = S_RIM_READY;
        end
        S_RIM_WRITE: begin
            rim_state_w = S_RIM_WRITE_DONE;
        end
        S_RIM_WRITE_DONE: begin
            if(write_state_r == S_WRITE_DONE) rim_state_w = S_RIM_READY;
        end
        S_RIM_READY: begin
            cfg_rdy_w = 0;
            rim_state_w = S_RIM_IDLE;
        end
    endcase
end

always@(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        rim_state_r <= S_RIM_IDLE;
        for(i=0;i<256;i=i+1) Register_Spaces_r[i] <= 0;
        cfg_rdy_r <= 0;
        twp_state_r <= S_TWP_IDLE;
        twp_counter_r <= 0;
        twp_addr_r <= 0;
        twp_data_r <= 0;
        col_state_r <= S_COL_IDLE;
        col_addr_r <= 0;
        rim_slow_r <= 0;
        write_state_r <= S_WRITE_IDLE;
        cfg_rdata_r <= cfg_rdata_w;
    end
    else begin
        rim_state_r <= rim_state_w;
        for(i=0;i<256;i=i+1) Register_Spaces_r[i] <= Register_Spaces_w[i];
        cfg_rdy_r <= cfg_rdy_w;
        twp_state_r <= twp_state_w;
        twp_counter_r <= twp_counter_w;
        twp_addr_r <= twp_addr_w;
        twp_data_r <= twp_data_w;
        col_state_r <= col_state_w;
        col_addr_r <= col_addr_w;
        rim_slow_r <= rim_slow_w;
        write_state_r <= write_state_w;
        cfg_rdata_r <= cfg_rdata_w;
    end
end



endmodule
