module MazeRunner_tb();

  // << optional include or import >>
  
  reg clk,RST_n;
  reg send_cmd;					// assert to send command to MazeRunner_tb
  reg [15:0] cmd;				// 16-bit command to send
  reg [11:0] batt;				// battery voltage 0xDA0 is nominal
  
  logic cmd_sent;				
  logic resp_rdy;				// MazeRunner has sent a pos acknowledge
  logic [7:0] resp;				// resp byte from MazeRunner (hopefully 0xA5)
  logic hall_n;					// magnet found?
  
  /////////////////////////////////////////////////////////////////////////
  // Signals interconnecting MazeRunner to RunnerPhysics and RemoteComm //
  ///////////////////////////////////////////////////////////////////////
  wire TX_RX,RX_TX;
  wire INRT_SS_n,INRT_SCLK,INRT_MOSI,INRT_MISO,INRT_INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;
  wire IR_lft_en,IR_cntr_en,IR_rght_en;  
  
  localparam FAST_SIM = 1'b1;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  MazeRunner iDUT(.clk(clk),.RST_n(RST_n),.INRT_SS_n(INRT_SS_n),.INRT_SCLK(INRT_SCLK),
                  .INRT_MOSI(INRT_MOSI),.INRT_MISO(INRT_MISO),.INRT_INT(INRT_INT),
				  .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
				  .A2D_MISO(A2D_MISO),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
				  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.RX(RX_TX),.TX(TX_RX),
				  .hall_n(hall_n),.piezo(),.piezo_n(),.IR_lft_en(IR_lft_en),
				  .IR_rght_en(IR_rght_en),.IR_cntr_en(IR_cntr_en),.LED());
	
  ///////////////////////////////////////////////////////////////////////////////////////
  // Instantiate RemoteComm which models bluetooth module receiving & forwarding cmds //
  /////////////////////////////////////////////////////////////////////////////////////
  RemoteComm iCMD(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX), .cmd(cmd), .send_cmd(send_cmd),
               .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
			   
				  
  RunnerPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(INRT_SS_n),.SCLK(INRT_SCLK),.MISO(INRT_MISO),
                      .MOSI(INRT_MOSI),.INT(INRT_INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),
                     .IR_lft_en(IR_lft_en),.IR_cntr_en(IR_cntr_en),.IR_rght_en(IR_rght_en),
					 .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
					 .A2D_MISO(A2D_MISO),.hall_n(hall_n),.batt(batt));
	
					 
  initial begin
	batt = 12'hDA0;  	// this is value to use with RunnerPhysics
    	// << Your magic goes here >>
    	clk = 0;

    	// Reset
    	RST_n = 0;
	repeat(2) @(posedge clk) RST_n = 1;
	
	// wait for some time
	repeat(10000) @(posedge clk);
	
	// send calibration cmd, check to make sure that the calabration was sucessful
	cmd = 16'h0000;
	send_cmd = 1;
	@(posedge clk) send_cmd = 0;
	fork
		begin: cal_timeout
			repeat(1500000) @(posedge clk);
			$display("ERR: timed out waiting for cal_done");
			$stop();
		end
		begin
			@(posedge iDUT.iNEMO.cal_done);
			$display("Calibration completed successfully!");
			disable cal_timeout;
		end
	join
	// check to make sure that the cmd was ack'd
	fork
		begin: ack_timeout
			repeat(1500000) @(posedge clk);
			$display("ERR: timed out waiting for postive ack");
			$stop();
		end
		begin
			@(posedge resp_rdy);
			if(resp == 8'ha5) begin
				$display("cmd was acknowledged correctly!");
			end else begin
				$display("cmd was incorrectly acknowledged, should have been 8'ha5 but was 8'h%h", resp);
			end
			disable ack_timeout;
		end
	join
	// send er'
	cmd = 16'h6000;
	send_cmd = 1;
	@(posedge clk) send_cmd = 0;
	// check for solve complete, as well as making sure the robot navigates the maze correctly
	fork
		begin: timeout
			repeat(50_000_000) @(posedge clk);
			$display("ERR: timed out waiting for sol_cmplt");
			$stop();
		end
		begin
			@(posedge iDUT.mv_cmplt);
			// should have moved forward to (2,1), and still facing foreward
			if(iPHYS.xx > 15'h2950 || iPHYS.xx < 15'h26B0) begin
				$display("x value is incorrect it should be between 15'h2950 and 15'h26B0 but was 15'h%h", iPHYS.xx);
				$stop();
			end
			$display("x position test 1 passed!");
			if(iPHYS.yy > 15'h1950 || iPHYS.yy < 15'h16B0) begin
				$display("y value is incorrect it should be between 15'h1950 and 15'h16B0 but was 15'h%h", iPHYS.yy);
				$stop();
			end
			$display("y position test 1 passed!");
			if(iPHYS.heading_robot[19:8] > 12'h20 || $signed(iPHYS.heading_robot[19:8]) < $signed(-12'h20)) begin
				$display("heading value is incorrect it should be between 12'h20 and -12'h20 but was 12'h%h", iPHYS.heading_robot[19:8]);
				$stop();
			end
			$display("heading value test 1 passed!");
			@(posedge iDUT.mv_cmplt);
			// should have turned to the left, and not moved
			if(iPHYS.xx > 15'h2950 || iPHYS.xx < 15'h26B0) begin
				$display("x value is incorrect it should be between 15'h2950 and 15'h26B0 but was 15'h%h", iPHYS.xx);
				$stop();
			end
			$display("x position test 2 passed!");
			if(iPHYS.yy > 15'h1950 || iPHYS.xx < 15'h16B0) begin
				$display("y value is incorrect it should be between 15'h1950 and 15'h16B0 but was 15'h%h", iPHYS.yy);
				$stop();
			end
			$display("y position test 2 passed!");
			if(iPHYS.heading_robot[19:8] > 12'h490 || $signed(iPHYS.heading_robot[19:8]) < $signed(12'h370)) begin
				$display("heading value is incorrect it should be between 12'h490 and 12'h370 but was 12'h%h", iPHYS.heading_robot[19:8]);
				$stop();
			end
			$display("heading value test 2 passed!");
			@(posedge iDUT.mv_cmplt);
			// should have moved one sqaure to the left (1,1), and still facing the left
			if(iPHYS.xx > 15'h1950 || iPHYS.xx < 15'h16B0) begin
				$display("x value is incorrect it should be between 15'h1950 and 15'h16B0 but was 15'h%h", iPHYS.xx);
				$stop();
			end
			$display("x position test 3 passed!");
			if(iPHYS.yy > 15'h1950 || iPHYS.xx < 15'h16B0) begin
				$display("y value is incorrect it should be between 15'h1950 and 15'h16B0 but was 15'h%h", iPHYS.yy);
				$stop();
			end
			$display("y position test 3 passed!");
			if(iPHYS.heading_robot[19:8] > 12'h490 || $signed(iPHYS.heading_robot[19:8]) < $signed(12'h370)) begin
				$display("heading value is incorrect it should be between 12'h490 and 12'h370 but was 12'h%h", iPHYS.heading_robot[19:8]);
				$stop();
			end
			$display("heading value test 3 passed!");
			@(posedge iDUT.mv_cmplt);
			// should have turned to the right, and not moved
			if(iPHYS.xx > 15'h1950 || iPHYS.xx < 15'h16B0) begin
				$display("x value is incorrect it should be between 15'h1950 and 15'h16B0 but was 15'h%h", iPHYS.xx);
				$stop();
			end
			$display("x position test 4 passed!");
			if(iPHYS.yy > 15'h1950 || iPHYS.xx < 15'h16B0) begin
				$display("y value is incorrect it should be between 15'h1950 and 15'h16B0 but was 15'h%h", iPHYS.yy);
				$stop();
			end
			$display("y position test 4 passed!");
			if(iPHYS.heading_robot[19:8] > 12'h50 || $signed(iPHYS.heading_robot[19:8]) < $signed(-12'h50)) begin
				$display("heading value is incorrect it should be between 12'h50 and -12'h50 but was 15'h%h", iPHYS.heading_robot[19:8]);
				$stop();
			end
			$display("heading value test 4 passed!");
			// should have moved up one square (1,2), and still be facing foreward
			@(posedge iDUT.mv_cmplt);
			if(iPHYS.xx > 15'h1950 || iPHYS.xx < 15'h16B0) begin
				$display("x value is incorrect it should be between 15'h1950 and 15'h16B0 but was 15'h%h", iPHYS.xx);
				$stop();
			end
			$display("x position test 5 passed!");
			if(iPHYS.yy > 15'h2950 || iPHYS.yy < 15'h26B0) begin
				$display("y value is incorrect it should be between 15'h2950 and 15'h26B0 but was 15'h%h", iPHYS.yy);
				$stop();
			end
			$display("y position test 5 passed!");
			if(iPHYS.heading_robot[19:8] > 12'h50 || $signed(iPHYS.heading_robot[19:8]) < $signed(-12'h50)) begin
				$display("heading value is incorrect it should be between 12'h20 and -12'h50 but was 15'h%h", iPHYS.heading_robot[19:8]);
				$stop();
			end
			$display("heading value test 5 passed!");
			@(posedge iDUT.mv_cmplt);
			// should have turned to the right, and not moved
			if(iPHYS.xx > 15'h1950 || iPHYS.xx < 15'h16B0) begin
				$display("x value is incorrect it should be between 15'h1950 and 15'h16B0 but was 15'h%h", iPHYS.xx);
				$stop();
			end
			$display("x position test 6 passed!");
			if(iPHYS.yy > 15'h2950 || iPHYS.yy < 15'h26B0) begin
				$display("y value is incorrect it should be between 15'h2950 and 15'h26B0 but was 15'h%h", iPHYS.yy);
				$stop();
			end
			$display("y position test 6 passed!");
			if($signed(iPHYS.heading_robot[19:8]) > $signed(-12'h350) || $signed(iPHYS.heading_robot[19:8]) < $signed(-12'h450)) begin
				$display("heading value is incorrect it should be between -12'h350 and -12'h450 but was 15'h%h", iPHYS.heading_robot[19:8]);
				$stop();
			end
			$display("heading value test 6 passed!");
			@(posedge iDUT.mv_cmplt);
			// should have moved to the right 2 squares (3,2), and not turned
			if(iPHYS.xx > 15'h3950 || iPHYS.xx < 15'h36B0) begin
				$display("x value is incorrect it should be between 15'h3950 and 15'h36B0 but was 15'h%h", iPHYS.xx);
				$stop();
			end
			$display("x position test 7 passed!");
			if(iPHYS.yy > 15'h2a00 || iPHYS.yy < 15'h25B0) begin
				$display("y value is incorrect it should be between 15'h2a00 and 15'h26B0 but was 15'h%h", iPHYS.yy);
				$stop();
			end
			$display("y position test 7 passed!");
			if($signed(iPHYS.heading_robot[19:8]) > $signed(-12'h350) || $signed(iPHYS.heading_robot[19:8]) < $signed(-12'h450)) begin
				$display("heading value is incorrect it should be between -12'h350 and -12'h450 but was 15'h%h", iPHYS.heading_robot[19:8]);
				$stop();
			end
			$display("heading value test 7 passed!");
			@(posedge iDUT.mv_cmplt);
			// should have turned right, and not moved
			if(iPHYS.xx > 15'h3950 || iPHYS.xx < 15'h36B0) begin
				$display("x value is incorrect it should be between 15'h3950 and 15'h36B0 but was 15'h%h", iPHYS.xx);
				$stop();
			end
			$display("x position test 8 passed!");
			if(iPHYS.yy > 15'h2a00 || iPHYS.yy < 15'h26B0) begin
				$display("y value is incorrect it should be between 15'h2a00 and 15'h26B0 but was 15'h%h", iPHYS.yy);
				$stop();
			end
			$display("y position test 8 passed!");
			if(iPHYS.heading_robot[19:8] > 12'h81F || iPHYS.heading_robot[19:8] < 12'h7DF) begin
				$display("heading value is incorrect it should be between 12'h81F and 12'h7DF but was 15'h%h", iPHYS.heading_robot[19:8]);
				$stop();
			end
			$display("heading value test 8 passed!");
			@(posedge iDUT.mv_cmplt);
			// should have turned moved down 2 sqaures (3,0), and not turned
			if(iPHYS.xx > 15'h3950 || iPHYS.xx < 15'h36B0) begin
				$display("x value is incorrect it should be between 15'h3950 and 15'h36B0 but was 15'h%h", iPHYS.xx);
				$stop();
			end
			$display("x position test 9 passed!");
			if(iPHYS.yy > 15'h850 || iPHYS.yy < 15'h6B0) begin
				$display("y value is incorrect it should be between 15'h2950 and 15'h26B0 but was 15'h%h", iPHYS.yy);
				$stop();
			end
			$display("y position test 9 passed!");
			if(iPHYS.heading_robot[19:8] > 12'h81F || iPHYS.heading_robot[19:8] < 12'h7DF) begin
				$display("heading value is incorrect it should be between 12'81F and 12'h7DF but was 12'h%h", iPHYS.heading_robot[19:8]);
				$stop();
			end
			$display("heading value test 9 passed!");
			@(posedge iDUT.mv_cmplt);
			// should rotate 180, and not move
			if(iPHYS.xx > 15'h3950 || iPHYS.xx < 15'h36B0) begin
				$display("x value is incorrect it should be between 15'h3950 and 15'h36B0 but was 15'h%h", iPHYS.xx);
				$stop();
			end
			$display("x position test 10 passed!");
			if(iPHYS.yy > 15'h850 || iPHYS.yy < 15'h6B0) begin
				$display("y value is incorrect it should be between 15'h2950 and 15'h26B0 but was 15'h%h", iPHYS.yy);
				$stop();
			end
			$display("y position test 10 passed!");
			if($signed(iPHYS.heading_robot[19:8]) > $signed(12'h50) || iPHYS.heading_robot[19:8] < 12'hF70) begin
				$display("heading value is incorrect it should be between 12'h50 and 12'hF70 but was 12'h%h", iPHYS.heading_robot[19:8]);
				$stop();
			end
			$display("heading value test 10 passed!");
			// should now move foreward into the magnet
			@(posedge iDUT.iSLV.sol_cmplt);
			$display("sol_cmplt assert!");
			disable timeout;
		end
	join
	$display("maze solved in the correct order (left affinity)!!");
	// Reset back to the starting position
	iPHYS.xx = 15'h2800;
	iPHYS.yy = 15'h800;
    	RST_n = 0;
	repeat(2) @(posedge clk) RST_n = 1;
	
	// wait for some time
	repeat(10000) @(posedge clk);
	
	// send calibration cmd, check to make sure that the calabration was sucessful
	cmd = 16'h0000;
	send_cmd = 1;
	@(posedge clk) send_cmd = 0;
	fork
		begin: rght_cal_timeout
			repeat(1500000) @(posedge clk);
			$display("ERR: timed out waiting for cal_done");
			$stop();
		end
		begin
			@(posedge iDUT.iNEMO.cal_done);
			$display("Calibration completed successfully!");
			disable rght_cal_timeout;
		end
	join
	// check to make sure that the cmd was ack'd
	fork
		begin: rght_ack_timeout
			repeat(1500000) @(posedge clk);
			$display("ERR: timed out waiting for postive ack");
			$stop();
		end
		begin
			@(posedge resp_rdy);
			if(resp == 8'ha5) begin
				$display("cmd was acknowledged correctly!");
			end else begin
				$display("cmd was incorrectly acknowledged, should have been 8'ha5 but was 8'h%h", resp);
			end
			disable rght_ack_timeout;
		end
	join
	// send er'
	cmd = 16'h6001;
	send_cmd = 1;
	@(posedge clk) send_cmd = 0;
	// check for solve complete, as well as making sure the robot navigates the maze correctly
	fork
		begin: rght_sol_timeout
			repeat(1500000) @(posedge clk);
			$display("ERR: timed out waiting for sol_timeout");
			$stop();
		end
		begin
			@(posedge iDUT.iSLV.sol_cmplt);
			$display("sol_timeout completed successfully!");
			disable rght_sol_timeout;
		end
	join
	$display("maze solved in the correct order (right affinity)!!");
	$stop();
  end
  
  always
    #5 clk = ~clk;
	
endmodule