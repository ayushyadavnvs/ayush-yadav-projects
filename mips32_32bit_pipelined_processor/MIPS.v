`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/04/2025 01:16:47 AM
// Design Name: 
// Module Name: MIPS
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


module MIPS(input clk1 , input clk2

    );
    reg [31:0] PC, IF_ID_IR , IF_ID_NPC;
    reg [31:0] ID_EX_IR , ID_EX_NPC , ID_EX_A , ID_EX_B , ID_EX_IMM ;
    reg [31:0] EX_MEM_B, EX_MEM_IR , EX_MEM_COND , EX_MEM_ALUOUT;
    reg [31:0] MEM_WB_LMD , MEM_WB_IR , MEM_WB_ALUOUT;
    reg [2:0] ID_EX_TYPE , EX_MEM_TYPE , MEM_WB_TYPE ;
    
    reg[31:0] Reg [31:0];
    reg [31:0] Mem [1023:0];
    parameter ADD = 6'b000000 , SUB = 6'b000001 , AND  = 6'b000010 , OR = 6'b000011 ,
    SLT = 6'b000100, MUL = 6'b000101, HLT = 6'b111111 , 
    LW = 6'b001000 , SW = 6'b001001 , ADDI = 6'b001010 , SUBI = 6'b001011,
    SLTI = 6'b001100 , BNEQZ = 6'b001101 , BEQZ = 6'b001110 ;
    
    parameter RR_ALU = 3'B000 , RM_ALU = 3'b001 , LOAD = 3'b010 , STORE = 3'b011, BRANCH = 3'b100, HALT = 3'b101;
    reg HALTED;
    reg BRANCH_TAKEN ;
    
        always@(posedge clk1)begin  //if stage (instruction stage )
        if (HALTED == 0)begin 
        if (((EX_MEM_IR[31:26] == BEQZ) && (EX_MEM_COND==1) )|| ((EX_MEM_IR[31:26] == BNEQZ)&& (EX_MEM_COND ==0)))
        begin 
        IF_ID_IR <= Mem[EX_MEM_ALUOUT];
        BRANCH_TAKEN <= 1'b1;
        IF_ID_NPC <= EX_MEM_ALUOUT +1;
        PC <= EX_MEM_ALUOUT +1;
        end
        else begin 
        IF_ID_IR <= Mem[PC];
        PC <= PC+1;
        IF_ID_NPC <= PC+1;
        end
        end 
        end 
        // DECODE STAGE 
        
        always@(posedge clk2)
        begin 
        if(HALTED==0)begin
        if (IF_ID_IR[25:21] == 5'b00000 ) ID_EX_A <=0 ;
        else ID_EX_A <= Reg[IF_ID_IR[25:21]];
       if (IF_ID_IR[20:16] == 5'b00000 ) ID_EX_B <=0 ;
        else ID_EX_B <= Reg[IF_ID_IR[20:16]];
        ID_EX_NPC <= IF_ID_NPC;
        ID_EX_IR  <= IF_ID_IR;
        ID_EX_IMM <= {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}} ;
        case(IF_ID_IR[31:26])
        ADD,SUB,AND,OR,SLT,MUL : ID_EX_TYPE <= RR_ALU;
        ADDI , SUBI , SLTI : ID_EX_TYPE <= RM_ALU;
        LW : ID_EX_TYPE <= LOAD;
        SW : ID_EX_TYPE <= STORE;
        BNEQZ , BEQZ : ID_EX_TYPE <= BRANCH;
        HLT : ID_EX_TYPE <= HALT;
        default : ID_EX_TYPE <= HALT;
        endcase
        end 
        end
        
        // EXECUTE STAGE 
        always @(posedge clk1)begin
        EX_MEM_TYPE <= ID_EX_TYPE;
        EX_MEM_B <= ID_EX_B;
        EX_MEM_IR <= ID_EX_IR;
        
        case(ID_EX_TYPE)
        
        RR_ALU : begin case(ID_EX_IR[31:26])
                       ADD: EX_MEM_ALUOUT <= ID_EX_A + ID_EX_B;
                       SUB: EX_MEM_ALUOUT <= ID_EX_A - ID_EX_B;
                       AND: EX_MEM_ALUOUT <= ID_EX_A & ID_EX_B;
                       OR: EX_MEM_ALUOUT <= ID_EX_A | ID_EX_B;
                       SLT: EX_MEM_ALUOUT <= ID_EX_A < ID_EX_B;
                       MUL:  EX_MEM_ALUOUT <= ID_EX_A * ID_EX_B;
                       endcase 
                       end 
       RM_ALU : begin case(ID_EX_IR[31:26])
                       ADDI: EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;
                       SUBI: EX_MEM_ALUOUT <= ID_EX_A - ID_EX_IMM;
                       SLTI: EX_MEM_ALUOUT <= ID_EX_A < ID_EX_IMM;
                       default : EX_MEM_ALUOUT <= 32'hxxxxxxxx;
                      endcase 
                    end
        LOAD , STORE  : begin
                        EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;
                        EX_MEM_B <= ID_EX_B;
                        end               
       BRANCH :  begin 
                EX_MEM_ALUOUT <= ID_EX_NPC +ID_EX_IMM;
                EX_MEM_COND <= (ID_EX_A==0);
                end
                default : EX_MEM_ALUOUT <= 32'hxxxxxxxx;
                
                endcase
                end 
                
                
                //MEMORY STAGE
                
                always@(posedge clk2)begin 
                if(HALTED == 0)begin 
                MEM_WB_TYPE <= EX_MEM_TYPE;
                MEM_WB_IR <= EX_MEM_IR;
                case(EX_MEM_TYPE)
                RR_ALU , RM_ALU: MEM_WB_ALUOUT <= EX_MEM_ALUOUT;
                LOAD: MEM_WB_LMD <= Mem[EX_MEM_ALUOUT];
                STORE : if(BRANCH_TAKEN == 0)Mem[EX_MEM_ALUOUT] <= EX_MEM_B;
                
                endcase 
                end
                end
                
 always @(posedge clk1)begin
   if (BRANCH_TAKEN == 0 )
    case(MEM_WB_TYPE)
    RR_ALU: Reg[MEM_WB_IR[15:11]] <= MEM_WB_ALUOUT;
    RM_ALU : Reg[MEM_WB_IR[20:16]] <= MEM_WB_ALUOUT;
    LOAD : Reg[MEM_WB_IR[20:16]] <= MEM_WB_LMD;
    HALT: HALTED<= 1'b1;
    endcase
 end
                
                
          
                
                                
                                     
                  
        
        
        
        
        
        
        
     
endmodule
