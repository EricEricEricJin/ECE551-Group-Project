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
	// wait for some time to see what happens
	// repeat(1000000) @(posedge clk);

	// check for solve complete
	fork
		begin: timeout
			repeat(50_000_000) @(posedge clk);
			$display("ERR: timed out waiting for sol_cmplt");
			$stop();
		end
		begin
			@(posedge iDUT.iSLV.sol_cmplt);
			$display("sol_cmplt assert!");
			disable timeout;
		end
	join
	$stop();

  end
  
  always
    #5 clk = ~clk;
	
endmodule