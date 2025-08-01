`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2025 02:51:01 AM
// Design Name: 
// Module Name: master_dma
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module dma_controller(
    input clk, reset, trigger,
    input [4:0] length,
    input [31:0] source_address, destination_address,
    output reg done,
    
    // AXI Read Address Channel
    output reg [31:0] ARADDR,
    output reg ARVALID,
    input ARREADY,
    
    // AXI Read Data Channel
    input [31:0] RDATA,
    input RVALID,
    output reg RREADY,
    
    // AXI Write Address Channel
    output reg [31:0] AWADDR,
    output reg AWVALID,
    input AWREADY,
    
    // AXI Write Data Channel
    output reg [31:0] WDATA,
    output reg WVALID,
    input WREADY,
    
    // AXI Write Response Channel
    input BVALID,
    output reg BREADY,
    input [1:0] BRESP
);



    // FIFO signals
    wire FIFO_EMPTY, FIFO_FULL;
    wire [31:0] FIFO_RD_DATA;
    reg FIFO_WR_ENABLE;
    reg FIFO_RD_EN;
    reg FIFO_RST;
    
    // FIFO Instantiation
    SYNC_FIFO fifo_inst(
        .FIFO_RST(FIFO_RST),
        .clk(clk),
        .FIFO_WR_DATA(RDATA),  // Connect directly to RDATA
        .FIFO_WR_ENABLE(FIFO_WR_ENABLE),
        .FIFO_RD_EN(FIFO_RD_EN),
        .FIFO_RD_DATA(FIFO_RD_DATA),
        .FIFO_EMPTY(FIFO_EMPTY),
        .FIFO_FULL(FIFO_FULL)
    );

    // Read State Machine
    reg [2:0] read_state;
    reg [31:0] read_address;
    reg [4:0] read_counter;
    
    parameter READ_IDLE = 3'b000, 
              READ_ADDR = 3'b001, 
              READ_DATA = 3'b010,
              READ_DONE = 3'b011;

    // Write State Machine
    reg [2:0] write_state;
    reg [31:0] write_address;
    reg [4:0] write_counter;
    
    parameter WRITE_IDLE = 3'b000, 
              WRITE_ADDR = 3'b001, 
              WRITE_DATA = 3'b010,
              WRITE_RESP = 3'b011,
              WRITE_DONE = 3'b100;

function [31:0] word_to_byte_address;
    input [31:0] word_address;
    parameter WORD_SIZE = 4; // 4 for 32 bit system 
begin
    word_to_byte_address = word_address * WORD_SIZE;
end
endfunction

    
    // State machine sequential logic for both read and write 
    always @(posedge clk or posedge reset) begin
        if (reset) begin //it is ACTIVE HIGH  reset , it will reset the whole system 
            read_state <= READ_IDLE; 
            write_state <= WRITE_IDLE;
            read_address <= 0;
            write_address <= 0;
            read_counter <= 0;
            write_counter <= 0;
            FIFO_RST <= 1;
            done <= 0;
            
            // Reset AXI signals
            ARVALID <= 0;
            RREADY <= 0;
            AWVALID <= 0;
            WVALID <= 0;
            BREADY <= 0;
            FIFO_WR_ENABLE <= 0;
            FIFO_RD_EN <= 0;
        end 
        else begin
            // Default - no FIFO operations
            FIFO_WR_ENABLE <= 0; // default value for enables so that latches are not formed 
            FIFO_RD_EN <= 0;
            
            // Read state machine
            case (read_state)
                READ_IDLE: begin
                ARVALID =0;
                    if (trigger) begin
                        read_state <= READ_ADDR;
                        read_address <= source_address; // converting the word address to byte address as memory expects byte address
                        read_counter <= 0; 
                        FIFO_RST <= 0; // De-assert reset to FIFO
                    end
                end
                
                READ_ADDR: begin
                    ARVALID <= 1; // for handshaking 
                    ARADDR <= read_address;
                    
                    if (ARREADY && ARVALID) begin
                        ARVALID <= 0;  // Clear ARVALID after handshake
                        read_state <= READ_DATA;
                        RREADY <= 1;   // Pre-assert RREADY for data phase
                    end
                end
                
                READ_DATA: begin
                    if (RVALID && RREADY && !FIFO_FULL) begin
                        FIFO_WR_ENABLE <= 1;  // Write data to FIFO
                        RREADY <= 0;          // De-assert RREADY after handshake
                        
                        if (read_counter == length ) begin
                            read_state <= READ_DONE;
                        end else begin
                            read_address <= read_address + 4;  // Word-aligned increment in address 
                            read_counter <= read_counter + 4; // as length is word aligned 
                            read_state <= READ_ADDR;
                        end
                    end
                end
                
                READ_DONE: begin
                    read_state <= READ_IDLE; 
                end
            endcase
            
            // Write state machine
            case (write_state)
                WRITE_IDLE: begin
                    if (trigger) begin
                        write_state <= WRITE_ADDR;
                        write_address <=destination_address;
                        write_counter <= 0;
                        done <= 0;  // Clear done signal
                    end
                    else if (!FIFO_EMPTY) begin
                        // Only transition if the fifo has data 
                        write_state <= WRITE_ADDR;
                    end
                end
                
                WRITE_ADDR: begin
                    if (!FIFO_EMPTY) begin
                        AWVALID <= 1;
                        AWADDR <= write_address;
                        
                        if (AWREADY && AWVALID) begin
                            AWVALID <= 0;  // Clear AWVALID after handshake
                            FIFO_RD_EN <= 1;  // Read from FIFO after address handshake
                            write_state <= WRITE_DATA;
                        end
                    end
                end
                
                WRITE_DATA: begin
                    // Use the data read from FIFO
                    WVALID <= 1;
                    WDATA <= FIFO_RD_DATA;
                    
                    if (WREADY && WVALID) begin
                        WVALID <= 0;  // Clear WVALID after handshake
                        BREADY <= 1;  // Pre-assert BREADY for response phase
                        write_state <= WRITE_RESP;
                    end
                end
                
                WRITE_RESP: begin
                    if (BVALID && BREADY) begin
                        BREADY <= 0;  // Clear BREADY after handshake
                        
                        if (write_counter == length ) begin
                            write_state <= WRITE_DONE;
                        end else begin
                            write_address <= write_address + 4;  // Word-aligned increment
                            write_counter <= write_counter + 4; // word aligned increment in length
                            write_state <= WRITE_ADDR;
                        end
                    end
                end
                
                WRITE_DONE: begin
                    done <= 1;  // Assert done signal
                    write_state <= WRITE_IDLE;
                end
            endcase
        end
    end

endmodule

module SYNC_FIFO(
    input FIFO_RST,
    input clk,
    input [31:0] FIFO_WR_DATA,
    input FIFO_WR_ENABLE,
    input FIFO_RD_EN,
    output reg [31:0] FIFO_RD_DATA,
    output FIFO_EMPTY,
    output FIFO_FULL
);
    reg [31:0] mem [0:15];  // 16-depth FIFO
    reg [3:0] FIFO_RD_PTR;
    reg [3:0] FIFO_WR_PTR;
    reg [4:0] FIFO_CNT; 
      reg [1:0] x_cnt; // Need 5 bits to count up to 16

    assign FIFO_EMPTY = (FIFO_CNT == 0);
    assign FIFO_FULL = (FIFO_CNT == 16);

    // Write logic
    always @(posedge clk or posedge FIFO_RST) begin 
        if (FIFO_RST) begin
            FIFO_WR_PTR <= 4'b0;
        end else if (FIFO_WR_ENABLE && !FIFO_FULL) begin 
            mem[FIFO_WR_PTR][x_cnt] <= FIFO_WR_DATA;
            x_cnt <= x_cnt + 1;
            if (x_cnt == 3) begin
                x_cnt <= 0;
                FIFO_WR_PTR <= (FIFO_WR_PTR == 15) ? 0 : FIFO_WR_PTR + 1;  // Correct wrap condition
            end
            
        end
    end

    // Read logic
    always @(posedge clk or posedge FIFO_RST) begin
        if (FIFO_RST) begin
            FIFO_RD_PTR <= 4'b0;
            FIFO_RD_DATA <= 32'b0;  // Initialize output data
        end else if (FIFO_RD_EN && !FIFO_EMPTY) begin 
            FIFO_RD_DATA <= mem[FIFO_RD_PTR];
            FIFO_RD_PTR <= (FIFO_RD_PTR == 15) ? 0 : FIFO_RD_PTR + 1;  // Correct wrap condition
        end
    end
    
    // Counter logic - separate process for better clarity
    always @(posedge clk or posedge FIFO_RST) begin
        if (FIFO_RST) begin
            FIFO_CNT <= 5'b0;
        end else begin
            case ({FIFO_WR_ENABLE && !FIFO_FULL, FIFO_RD_EN && !FIFO_EMPTY})
                2'b10: FIFO_CNT <= FIFO_CNT + 1;  // Only writing
                2'b01: FIFO_CNT <= FIFO_CNT - 1;  // Only reading
                2'b11: FIFO_CNT <= FIFO_CNT;      // Both reading and writing - no change
                default: FIFO_CNT <= FIFO_CNT;    // No operation
            endcase
        end
    end
endmodule




