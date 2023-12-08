//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of mazeRunner.  Fusion correction     //
// comes from IR_Dtrm when en_fusion is high.   //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,IR_Dtrm,
                  SS_n,SCLK,MOSI,MISO,INT,moving,en_fusion);

  parameter FAST_SIM = 0;	// used to speed up simulation
  
  input clk, rst_n;
  input MISO;							// SPI input from inertial sensor
  input INT;							// goes high when measurement ready
  input strt_cal;						// initiate claibration of yaw readings
  input moving;							// Only integrate yaw when going
  input en_fusion;						// do fusion corr only when forward at decent clip
  input [8:0] IR_Dtrm;					// derivative term of IR sensors (used for fusion)
  
  output logic cal_done;				// pulses high for 1 clock when calibration done
  output signed [11:0] heading;	// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
  output rdy;					// goes high for 1 clock when new outputs ready (from inertial_integrator)
  output SS_n,SCLK,MOSI;		// SPI outputs
 

  ////////////////////////////////////////////
  // Declare any needed internal registers //
  //////////////////////////////////////////
  logic[15:0] timer;
  logic INT_FF1, INT_FF2, yawL_en, yawH_en;
  logic[7:0] yawL, yawH;
  
  //async hardware interupt needs to be flopped so it will be on a clock edge
  always_ff@(posedge clk, negedge rst_n) begin
	 if(!rst_n) begin 
		INT_FF1 <= 1'b0;
		INT_FF2 <= 1'b0;
	 end
	 else begin
		INT_FF1 <= INT;
		INT_FF2 <= INT_FF1;
	 end
  end

  //////////////////////////////////////
  // Outputs of SM are of type logic //
  ////////////////////////////////////
  logic wrt, vld;
  logic[15:0] cmd;

  //////////////////////////////////////////////////////////////
  // Declare any needed internal signals that connect blocks //
  ////////////////////////////////////////////////////////////
  wire done;
  wire [15:0] inert_data;		// Data back from inertial sensor (only lower 8-bits used)
  wire signed [15:0] yaw_rt;
  
  always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n) yawL <= 8'h00;
	 else if(yawL_en) yawL <= inert_data[7:0];
  end
  
  always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n) yawH <= 8'h00;
	 else if(yawH_en) yawH <= inert_data[7:0];
  end  

  ///////////////////////////////////////
  // Create enumerated type for state //
  /////////////////////////////////////
  typedef enum logic[2:0] { INIT1, INIT2, INIT3, WAIT, READ_YAWL, READ_YAWH, DONE} state_t;
  
  ////////////////////////////////////////////////////////////
  // Instantiate SPI monarch for Inertial Sensor interface //
  //////////////////////////////////////////////////////////
  SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),
                 .MISO(MISO),.MOSI(MOSI),.wrt(wrt),.done(done),
				 .rd_data(inert_data),.wrt_data(cmd));
				  
  ////////////////////////////////////////////////////////////////////
  // Instantiate Angle Engine that takes in angular rate readings  //
  // and gaurdrail info and produces a heading reading            //
  /////////////////////////////////////////////////////////////////
  inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),
                        .vld(vld),.rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),
						.en_fusion(en_fusion),.IR_Dtrm(IR_Dtrm),.heading(heading));
  assign yaw_rt = { yawH , yawL };

  // timer that will be used to wait until the nemo is setup
  always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n) timer <= 0;
    else timer <= timer + 1;
  end

  state_t state, nxt_state;
  
  // state FF
  always_ff@(posedge clk, negedge rst_n) begin
    if(!rst_n) state <= INIT1;
    else state <= nxt_state;
  end
  
  // state machine transitions
  always_comb begin
    wrt = 0;
    vld = 0;
    nxt_state = state;
    cmd = 16'h0000;
	 yawL_en = 0;
	 yawH_en = 0;

    case(state)
      // the first three states are configuration states so we can start to collect data
      INIT1: begin
		cmd = 16'h0D02;
		if(&timer) begin
			wrt = 1;
			nxt_state = INIT2;
			end
      end
		
      INIT2: begin
		cmd = 16'h1160;
		if(done) begin
			wrt = 1;
			nxt_state = INIT3; 
			end
      end
		
      INIT3: begin
		cmd = 16'h1440;
		if(done) begin
			wrt = 1;
			nxt_state = WAIT;
			end
      end
      
      // this state is used to wait until there is data ready to consume
      WAIT: begin
		cmd = 16'hA600;
		if(INT_FF2) begin
		nxt_state = READ_YAWL;
		wrt = 1;
			end
		end
      // will loop through these state to collect data from the nemo sensor	
      READ_YAWL: begin
		cmd = 16'hA700;
		if(done) begin
		yawL_en = 1;
		wrt = 1;
		nxt_state = READ_YAWH;
			end
		end
		
      READ_YAWH:
		if(done) begin
		yawH_en = 1;
		nxt_state = DONE;
		end
		
      DONE: begin
		vld = 1;
		nxt_state = WAIT;
      end
    endcase	
  end
  
endmodule
	  