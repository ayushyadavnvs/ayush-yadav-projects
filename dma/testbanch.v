// Code your testbench here
// or browse Examples
`timescale 1ns/ 1ps

module master_dma_tb();

    // Clock and reset signals
    reg clk;
    reg reset;
    
    // DMA control signals
    reg trigger;
    reg [4:0] length;
    reg [31:0] source_address, destination_address;
    wire done;
    
    // AXI Read Address Channel
    wire [31:0] ARADDR;
    wire ARVALID;
    reg ARREADY;
    
    // AXI Read Data Channel
    reg [31:0] RDATA;
    reg RVALID;
    wire RREADY;
    
    // AXI Write Address Channel
    wire [31:0] AWADDR;
    wire AWVALID;
    reg AWREADY;
    
    // AXI Write Data Channel
    wire [31:0] WDATA;
    wire WVALID;
    reg WREADY;
    
    // AXI Write Response Channel
    reg BVALID;
    wire BREADY;
    reg [1:0] BRESP;
    
    // Slave memory model - much larger memory to accommodate all test addresses
    reg [31:0] memory [0:4095]; // 16KB memory model
    
    // Test parameters
    parameter CLK_PERIOD = 10; // 10ns clock period (100MHz)
    
    // Instantiate the DMA controller
    dma_controller dut (
        .clk(clk),
        .reset(reset),
        .trigger(trigger),
        .length(length),
        .source_address(source_address),
        .destination_address(destination_address),
        .done(done),
        
        // AXI Read Address Channel
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        
        // AXI Read Data Channel
        .RDATA(RDATA),
        .RVALID(RVALID),
        .RREADY(RREADY),
        
        // AXI Write Address Channel
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        
        // AXI Write Data Channel
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        
        // AXI Write Response Channel
        .BVALID(BVALID),
        .BREADY(BREADY),
        .BRESP(BRESP)
    );

    // Clock generation
    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Convert byte address to word index for memory access
    function integer addr_to_index;
        input [31:0] byte_addr;
        begin
            addr_to_index = byte_addr[31:2]; // Divide by 4 to get word index
        end
    endfunction
    
    // Memory read task
    task memory_read;
        input [31:0] addr;
        begin
            // Wait for read address
            wait(ARVALID);
            @(posedge clk);
            #1; // Small delay for stability
            
            // Check address
            if (ARADDR != addr) begin
                $display("ERROR: Expected read address 0x%h but got 0x%h", addr, ARADDR);
            end
            
            // Address handshake
            ARREADY = 1'b1;
            @(posedge clk);
            #1;
            ARREADY = 1'b0;
            
            // Wait for RREADY before sending data
            wait(RREADY);
            @(posedge clk);
            #1;
            
            // Send data
            RDATA = memory[addr_to_index(addr)];
            RVALID = 1'b1;
            @(posedge clk);
            
            // Wait for data to be accepted
            wait(!RREADY || !RVALID);
            @(posedge clk);
            #1;
            RVALID = 1'b0;
        end
    endtask
    
    // Memory write task
    task memory_write;
        input [31:0] addr;
        begin
            // Wait for write address
            wait(AWVALID);
            @(posedge clk);
            #1; // Small delay for stability
            
            // Check address
            if (AWADDR != addr) begin
                $display("ERROR: Expected write address 0x%h but got 0x%h", addr, AWADDR);
            end
            
            // Address handshake
            AWREADY = 1'b1;
            @(posedge clk);
            #1;
            AWREADY = 1'b0;
            
            // Wait for write data
            wait(WVALID);
            @(posedge clk);
            #1;
            
            // Receive data
            memory[addr_to_index(addr)] = WDATA;
            $display("INFO: Writing 0x%h to address 0x%h", WDATA, addr);
            WREADY = 1'b1;
            @(posedge clk);
            #1;
            WREADY = 1'b0;
            
            // Send write response
            wait(BREADY);
            @(posedge clk);
            #1;
            BVALID = 1'b1;
            BRESP = 2'b00; // OKAY response
            @(posedge clk);
            
            // Wait for response to be accepted
            wait(!BREADY || !BVALID);
            @(posedge clk);
            #1;
            BVALID = 1'b0;
        end
    endtask
    
    // DMA transfer task
    task perform_dma_transfer;
        input [31:0] src_addr;
        input [31:0] dst_addr;
        input [4:0] transfer_length;
        integer i;
        begin
            $display("INFO: Starting DMA transfer from 0x%h to 0x%h, length=%d", src_addr, dst_addr, transfer_length);
            
            // Set DMA parameters
            source_address = src_addr;
            destination_address = dst_addr;
            length = transfer_length;
            
            // Trigger DMA
            @(posedge clk);
            #1;
            trigger = 1'b1;
            @(posedge clk);
            #1;
            trigger = 1'b0;
            
            // Respond to memory read/write requests
            fork
                // Handle read requests
                begin
                    for (i = 0; i < transfer_length; i = i + 4) begin
                        memory_read(src_addr + i );
                    end
                end
                
                // Handle write requests
                begin
                    for (i = 0; i < transfer_length; i = i + 4) begin
                        memory_write(dst_addr + i );
                    end
                end
                
                // Wait for done signal
                begin
                    wait(done);
                    $display("INFO: DMA transfer completed");
                end
            join
            
            // Verify transfer
            for (i = 0; i < transfer_length; i = i + 4) begin
                if (memory[addr_to_index(src_addr + i )] != memory[addr_to_index(dst_addr + i)]) begin
                    $display("ERROR: Data mismatch at offset %d", i);
                    $display("  Source data: 0x%h", memory[addr_to_index(src_addr + (i * 4))]);
                    $display("  Destination data: 0x%h", memory[addr_to_index(dst_addr + (i * 4))]);
                end
            end
            $display("INFO: Data verification complete");
        end
    endtask
    
    // Initialize memory contents (for test data)
    task initialize_memory;
        integer i;
        begin
            for (i = 0; i < 4096; i = i + 1) begin
                memory[i] = 32'h00000000;
            end
            
            // Set up test pattern at source addresses
            memory[addr_to_index('h1000)] = 32'hAABBCCDD;
            memory[addr_to_index('h1004)] = 32'h11223344;
            memory[addr_to_index('h1008)] = 32'h55667788;
            memory[addr_to_index('h100C)] = 32'h99AABBCC;
            
            // Clear destination area
            memory[addr_to_index('h2000)] = 32'h00000000;
            memory[addr_to_index('h2004)] = 32'h00000000;
            memory[addr_to_index('h2008)] = 32'h00000000;
            memory[addr_to_index('h200C)] = 32'h00000000;
        end
    endtask
    
    // Display memory contents
    task display_memory;
        input [31:0] start_addr;
        input [31:0] num_words;
        integer i;
        begin
            $display("Memory contents from 0x%h:", start_addr);
            for (i = 0; i < num_words; i = i + 1) begin
                $display("  0x%h: 0x%h", start_addr + (i * 4), memory[addr_to_index(start_addr + (i * 4))]);
            end
        end
    endtask
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, master_dma_tb);
end
    
    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        reset = 0;
        trigger = 0;
        length = 0;
        source_address = 0;
        destination_address = 0;
        
        ARREADY = 0;
        RDATA = 0;
        RVALID = 0;
        AWREADY = 0;
        WREADY = 0;
        BVALID = 0;
        BRESP = 0;
        
        // Initialize memory
        initialize_memory();
        
        // Reset DMA
        @(posedge clk);
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        // Display initial memory
        $display("BEFORE DMA TRANSFER:");
        display_memory('h1000, 4); // Source
        display_memory('h2000, 4); // Destination
        
        // Perform DMA transfer as in the example
        perform_dma_transfer('h1000, 'h2000, 16);
        
        // Display final memory
        $display("AFTER DMA TRANSFER:");
        display_memory('h2000, 4); // Destination
        
        // Additional test: larger transfer (8 words)
        $display("\nTEST 2: Larger Transfer (8 words)");
        // Set up test data
        memory[addr_to_index('h3000)] = 32'h00112233;
        memory[addr_to_index('h3004)] = 32'h44556677;
        memory[addr_to_index('h3008)] = 32'h8899AABB;
        memory[addr_to_index('h300C)] = 32'hCCDDEEFF;
        memory[addr_to_index('h3010)] = 32'hFFEEDDCC;
        memory[addr_to_index('h3014)] = 32'hBBAA9988;
        memory[addr_to_index('h3018)] = 32'h77665544;
        memory[addr_to_index('h301C)] = 32'h33221100;
        // Clear destination
        for (int i = 0; i < 8; i = i + 1) begin
            memory[addr_to_index('h4000 + (i * 4))] = 32'h0;
        end
        
        // Reset DMA for new transfer
        @(posedge clk);
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        // Perform transfer
        perform_dma_transfer('h3000, 'h4000, 32);
        
        // Additional test: FIFO handling test - try to transfer more than FIFO can hold
        $display("\nTEST 3: FIFO Handling Test (16 words)");
        // Set up test data
        for (int i = 0; i < 16; i = i + 1) begin
            memory[addr_to_index('h5000 + (i * 4))] = 32'hA0000000 + i;
            memory[addr_to_index('h6000 + (i * 4))] = 32'h0; // Clear destination
        end
        
        // Reset DMA for new transfer
        @(posedge clk);
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        @(posedge clk);
        
        // Perform transfer
        perform_dma_transfer('h5000, 'h6000, 16);
        
        // End simulation
        #100;
        $display("All tests completed");
        $finish;
    end
    
    // Monitor DMA state transitions
    initial begin
        $display("Starting DMA controller simulation");
        $monitor("Time=%0t, ARVALID=%b, ARREADY=%b, RVALID=%b, RREADY=%b, AWVALID=%b, AWREADY=%b, WVALID=%b, WREADY=%b, BVALID=%b, BREADY=%b, done=%b",
                 $time, ARVALID, ARREADY, RVALID, RREADY, AWVALID, AWREADY, WVALID, WREADY, BVALID, BREADY, done);
    end

endmodule