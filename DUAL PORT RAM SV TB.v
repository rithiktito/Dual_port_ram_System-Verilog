// Code your design here
module dual_ram (
    input  logic        clk,
    input  logic        rd,
    input  logic        wr,
    input  logic [11:0] wr_addr,
    input  logic [11:0] rd_addr,
    input  logic [63:0] data_in,
    output logic [63:0] data_out
);

    logic [63:0] mem [0:4095];

    always_ff @(posedge clk)
    begin
        if (wr)
            mem[wr_addr] <= data_in;

        if (rd)
            data_out <= mem[rd_addr];
    end

endmodule
//Interface
// code for verification
//Interfaceinterface ram_if(input bit clk);
interface ram_if(input bit clk);
logic [63:0] data_in;
logic [63:0] data_out;
logic wr;
logic rd;
logic [11:0] wr_addr;
logic [11:0] rd_addr;

clocking wr_drv @(posedge clk);
    default input #1 output #1;
    output wr_addr;
    output data_in;
    output wr;
endclocking

clocking wr_mon @(posedge clk);
    default input #1 output #1;
    input wr_addr;
    input data_in;
    input wr;
endclocking

clocking rd_drv @(posedge clk);
    default input #1 output #1;
    output rd_addr;
    output rd;
endclocking

clocking rd_mon @(posedge clk);
    default input #1 output #1;
    input rd_addr;
    input data_out;
    input rd;
endclocking

modport WR_DRV(clocking wr_drv);
modport WR_MON(clocking wr_mon);
modport RD_DRV(clocking rd_drv);
modport RD_MON(clocking rd_mon);

endinterface

////txn class


class ram_trans;

rand bit rd;
rand bit wr;
rand bit [63:0] data_in;
rand bit [11:0] wr_addr;
rand bit [11:0] rd_addr;

logic [63:0] data_out;

static int read_trans;
static int write_trans;
static int read_write_trans;

constraint c1 { {rd,wr} != 2'b00; }
constraint c2 { rd_addr != wr_addr; }
constraint data { data_in inside {[0:4096]}; }

function void display(input string message);

    $display("========================================");
    $display("\t%s",message);
    $display("\tRead transaction number: %d",read_trans);
    $display("\tWrite transaction number: %d",write_trans);
    $display("\tRead_Write transaction number: %d",read_write_trans);
    $display("\twrite enable is %d",wr);
    $display("\twrite address is %d",wr_addr);
    $display("\tread enable is %d",rd);
    $display("\tread address is %d",rd_addr);
    $display("\tdata_in is %d",data_in);
    $display("\tdata_out is %d",data_out);

endfunction

function void post_randomize();

    if(rd==1 && wr==0)
        read_trans++;
    if(rd==0 && wr==1)
        write_trans++;
    if(rd==1 && wr==1)
        read_write_trans++;
    //display("RANDOMIZED DATA");

endfunction

function bit compare(input ram_trans rcv, output string message);   // RM_DATA.COMPARE(RC_DATA)  
compare=1'b0;                                             //RCVD DATA= ACTUAL O/P FROM DUT   // RM_DATA= REFERENCE MODEL PASSED TXN HANDLE
begin	
  if(this.rd_addr != rcv.rd_addr)
    begin
        message = "address mismatch";
        return 0;
    end
  if(this.data_out != rcv.data_out)
    begin
        message = "data mismatch";
        return 0;
    end
    message = "success";
    return 1;
end
endfunction

endclass

//GENERATOR CLASS

  
class ram_gen;
mailbox #(ram_trans) gen2rd;
mailbox #(ram_trans) gen2wr;

ram_trans gentrans;
ram_trans data2send;

int no_trans;

function new(mailbox #(ram_trans) gen2rd,
             mailbox #(ram_trans) gen2wr);

    this.gen2rd = gen2rd;
    this.gen2wr = gen2wr;

    gentrans = new();

endfunction

virtual task start();
fork
begin
    for(int i=0; i<no_trans; i++)
    begin
        gentrans = new();
        assert(gentrans.randomize());
      //  gentrans.display("GENERATOR");
        data2send = new();
        data2send = gentrans;
        gen2rd.put(data2send);
        gen2wr.put(data2send);
    end
end
join_none
endtask

endclass
//WRITE_DRIVER class



class ram_wr_drv;

virtual ram_if.WR_DRV wr_drv_if;
ram_trans data2duv;
mailbox #(ram_trans) gen2wr;

function new(virtual ram_if.WR_DRV wr_drv_if,
             mailbox #(ram_trans) gen2wr);
    this.wr_drv_if = wr_drv_if;
    this.gen2wr = gen2wr;
endfunction

virtual task start();
fork
forever
begin
    gen2wr.get(data2duv);
    drive();
end
join_none
endtask

task drive();
    @(wr_drv_if.wr_drv);
    wr_drv_if.wr_drv.wr <= data2duv.wr;
    wr_drv_if.wr_drv.wr_addr <= data2duv.wr_addr;
    wr_drv_if.wr_drv.data_in <= data2duv.data_in;
    @(wr_drv_if.wr_drv);
    wr_drv_if.wr_drv.wr <= 1'b0;
endtask

endclass

//READ_DRIVER CLASS



class ram_rd_drv;
ram_trans data2duv;
mailbox #(ram_trans) gen2rd;
virtual ram_if.RD_DRV rd_drv_if;
function new(mailbox #(ram_trans) gen2rd,
             virtual ram_if.RD_DRV rd_drv_if);

this.gen2rd = gen2rd;
this.rd_drv_if = rd_drv_if;
endfunction

virtual task start();
fork
begin
    forever
    begin
        gen2rd.get(data2duv);
        drive();
    end
end
join_none

endtask

task drive();
    @(rd_drv_if.rd_drv);
    rd_drv_if.rd_drv.rd <= data2duv.rd;
    rd_drv_if.rd_drv.rd_addr <= data2duv.rd_addr;
    @(rd_drv_if.rd_drv);
    rd_drv_if.rd_drv.rd <= 1'b0;
endtask
endclass


//CLASS write MONITOR


class ram_wr_mon;
virtual ram_if.WR_MON wr_mon_if;
ram_trans data2rm;
mailbox #(ram_trans) wr2rm;

covergroup covh;
WR_ADDR : coverpoint data2rm.wr_addr {
    bins zero = {0};
    bins low  = {[10:256]};
    bins mid  = {[550:1020]};
    bins high = {[1021:2047]};
									 }

DATA : coverpoint data2rm.data_in {
    bins zero  = {0};
    bins low   = {[1:100]};
    bins mid   = {[110:800]};
    bins high  = {[1000:1256]};
    bins vhigh = {[2000:4000]};
    bins max   = {[4000:4096]};
								  }

WXDATA : cross WR_ADDR,DATA;
endgroup


function new(virtual ram_if.WR_MON wr_mon_if,
             mailbox #(ram_trans) wr2rm);
    this.wr_mon_if = wr_mon_if;
    this.wr2rm = wr2rm;
	covh=new();
//  this.data2rm = new();
endfunction

virtual task start();
fork
begin
    forever
    begin
        monitor();
        wr2rm.put(data2rm);
		covh.sample();
    end
end
join_none
endtask

task monitor();
data2rm=new();
@(wr_mon_if.wr_mon);
wait(wr_mon_if.wr_mon.wr == 1);
   	 	data2rm.wr      = wr_mon_if.wr_mon.wr;
    	data2rm.wr_addr = wr_mon_if.wr_mon.wr_addr;
    	data2rm.data_in = wr_mon_if.wr_mon.data_in;
    	@(wr_mon_if.wr_mon);

endtask

endclass

//READ MONITOR


class ram_rd_mon;
virtual ram_if.RD_MON rd_mon_if;
ram_trans data2rm;

mailbox #(ram_trans) rd2rm;
mailbox #(ram_trans) mon2sb;

function new(virtual ram_if.RD_MON rd_mon_if,
             mailbox #(ram_trans) rd2rm,
             mailbox #(ram_trans) mon2sb);

    this.rd_mon_if = rd_mon_if;
    this.rd2rm = rd2rm;
    this.mon2sb = mon2sb;
    this.data2rm = new();
endfunction

virtual task start();
fork
begin
    forever
    begin
        monitor();
        rd2rm.put(data2rm);
        mon2sb.put(data2rm);
    end
end
join_none
endtask

task monitor();
data2rm=new();
@(rd_mon_if.rd_mon);
wait(rd_mon_if.rd_mon.rd == 1);    
    data2rm.rd       = rd_mon_if.rd_mon.rd;
    data2rm.rd_addr  = rd_mon_if.rd_mon.rd_addr;
    @(rd_mon_if.rd_mon);
    data2rm.data_out = rd_mon_if.rd_mon.data_out;
    //data2rm.display("DATA FROM READ MONITOR");
endtask

endclass

//REFERENCE MODULE


class reference;
ram_trans mon_data1;
ram_trans mon_data2;

logic [63:0] ref_data[int];

mailbox #(ram_trans) rd2rm;
mailbox #(ram_trans) wr2rm;
mailbox #(ram_trans) rm2sb;

function new(mailbox #(ram_trans) rd2rm,
             mailbox #(ram_trans) wr2rm,
             mailbox #(ram_trans) rm2sb);
    this.rd2rm = rd2rm;
    this.wr2rm = wr2rm;
    this.rm2sb = rm2sb;
endfunction

virtual task start();
fork
begin
    fork
    begin
        forever
        begin
            wr2rm.get(mon_data1);
            if(mon_data1.wr)
			ref_data[mon_data1.wr_addr] = mon_data1.data_in;
        end
    end

    begin
        forever
        begin
            rd2rm.get(mon_data2);
            if(mon_data2.rd)
            begin
				if(ref_data.exists(mon_data2.rd_addr))
				mon_data2.data_out = ref_data[mon_data2.rd_addr];
				else
				mon_data2.data_out = 0;
			end
            rm2sb.put(mon_data2);
        end
    end

    join

end
join_none
endtask

endclass

//SCOREBOARD CLASS

class scoreboard;
ram_wr_mon wr_monh;
event DONE;

ram_trans rm_data;
ram_trans rcvd_data;

mailbox #(ram_trans) mon2sb;
mailbox #(ram_trans) rm2sb;

int data_verified;
string diff;
int no_trans;

function new(mailbox #(ram_trans) mon2sb,
             mailbox #(ram_trans) rm2sb,
             int no_trans);
    this.mon2sb = mon2sb;
    this.rm2sb = rm2sb;
    this.no_trans = no_trans;
endfunction

task start();
fork
begin
    forever
    begin
        rm2sb.get(rm_data);
        mon2sb.get(rcvd_data);
        check(rcvd_data);
    end
end
join_none

endtask

  task check(ram_trans rc_data);                      //RCVD DATA= ACTUAAL O/P FROM DUT. (rm2sb) RM_DATA REFERENCE MODEL PASSED TXN HANDLE

    if(!rm_data.compare(rc_data,diff))
    begin
        rc_data.display("RECEIVED DATA IS WRONG");
        rm_data.display("DATA NOT MATCHING IN SB");
        $display("%s",diff);
    end
    else
    begin
        $display("SB: %s",diff);
        data_verified++;
    end

    if (data_verified == ram_trans::read_trans + ram_trans::read_write_trans)
    -> DONE;
endtask

function void report();
$display("===============SCOREBOARD DATA==================");
$display("Current coverage = %f",wr_monh.covh.get_coverage());
$display("Current coverage = %0.2f",wr_monh.covh.WXDATA.get_coverage());
endfunction
endclass


//ENVIRONMENT CLASS

class ram_env;

virtual ram_if.WR_DRV wr_drv_if;
virtual ram_if.RD_DRV rd_drv_if;
virtual ram_if.WR_MON wr_mon_if;
virtual ram_if.RD_MON rd_mon_if;

mailbox #(ram_trans) gen2wr = new();
mailbox #(ram_trans) gen2rd = new();
mailbox #(ram_trans) wr2rm  = new();
mailbox #(ram_trans) rd2rm  = new();
mailbox #(ram_trans) rm2sb  = new();
mailbox #(ram_trans) mon2sb = new();

ram_gen genh;
ram_wr_drv wr_drvh;
ram_rd_drv rd_drvh;
ram_wr_mon wr_monh;
ram_rd_mon rd_monh;
scoreboard sbh;
reference refh;

function new(
    virtual ram_if.WR_DRV wr_drv_if,
    virtual ram_if.RD_DRV rd_drv_if,
    virtual ram_if.WR_MON wr_mon_if,
    virtual ram_if.RD_MON rd_mon_if
);

    this.wr_drv_if = wr_drv_if;
    this.rd_drv_if = rd_drv_if;
    this.wr_mon_if = wr_mon_if;
    this.rd_mon_if = rd_mon_if;

endfunction

task build();

    genh    = new(gen2rd,gen2wr);
    wr_drvh = new(wr_drv_if,gen2wr);
    rd_drvh = new(gen2rd,rd_drv_if);
    wr_monh = new(wr_mon_if,wr2rm);
    rd_monh = new(rd_mon_if,rd2rm,mon2sb);
    refh = new(rd2rm,wr2rm,rm2sb);
    sbh = new(mon2sb,rm2sb,genh.no_trans);
    sbh.wr_monh = wr_monh;

endtask

task reset_dut();

    rd_drv_if.rd_drv.rd <= 0;
    rd_drv_if.rd_drv.rd_addr <= 0;

    wr_drv_if.wr_drv.wr <= 0;
    wr_drv_if.wr_drv.wr_addr <= 0;
    wr_drv_if.wr_drv.data_in <= 0;

    repeat(2) @(wr_drv_if.wr_drv);

    for(int i=0;i<4096;i++)
    begin
        wr_drv_if.wr_drv.wr <= 1;
        wr_drv_if.wr_drv.wr_addr <= i;
        wr_drv_if.wr_drv.data_in <= 0;

        @(wr_drv_if.wr_drv);
    end

    wr_drv_if.wr_drv.wr <= 0;

    repeat(5) @(wr_drv_if.wr_drv);

endtask

task start();

    genh.start();
    wr_drvh.start();
    rd_drvh.start();
    wr_monh.start();
    rd_monh.start();
    refh.start();
    sbh.start();

endtask

task stop();
wait(sbh.DONE.triggered);
endtask

task run();
    reset_dut();
    start();
    stop();
    sbh.report();
endtask

endclass



/* 
'include class transaction
'include class generation
'include class write driver
'include class read driver
'include class write MONITOR
'include class read MONITOR
'include class reference MODEL
'include class SCOREBOARD
'include class ENVIRONMENT

// ===================TEST MODULE=====================//                                                    																		*/

class test;

ram_env envh;

virtual ram_if.WR_DRV wr_drv_if;
virtual ram_if.RD_DRV rd_drv_if;
virtual ram_if.WR_MON wr_mon_if;
virtual ram_if.RD_MON rd_mon_if;

function new(
    virtual ram_if.WR_DRV wr_drv_if,
    virtual ram_if.RD_DRV rd_drv_if,
    virtual ram_if.WR_MON wr_mon_if,
    virtual ram_if.RD_MON rd_mon_if
);

    this.wr_drv_if = wr_drv_if;
    this.rd_drv_if = rd_drv_if;
    this.wr_mon_if = wr_mon_if;
    this.rd_mon_if = rd_mon_if;

    envh = new(wr_drv_if,rd_drv_if,wr_mon_if,rd_mon_if);

endfunction

task build_and_run();
begin
    envh.build();
    envh.genh.no_trans = 8;
    envh.sbh.no_trans = envh.genh.no_trans;
    envh.run();
    $finish;
end
endtask

endclass

 
module top;
parameter cycle=10;
reg clock;
ram_if DUV_IF(clock);
test testh;
dual_ram RAM (.clk(clock),.rd(DUV_IF.rd),.wr(DUV_IF.wr),.wr_addr(DUV_IF.wr_addr),.rd_addr(DUV_IF.rd_addr),.data_in(DUV_IF.data_in),.data_out(DUV_IF.data_out));
initial
begin

	testh=new(DUV_IF,DUV_IF,DUV_IF,DUV_IF);
	testh.build_and_run();
end
initial
begin
      clock=1'b0;
     forever #(cycle/2) clock = ~clock;
end
endmodule



