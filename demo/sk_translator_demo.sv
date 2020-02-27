////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Copyright 2020 David Cornfield                                             //
//                                                                            //
// Licensed under the Apache License, Version 2.0 (the "License");            //
// you may not use this file except in compliance with the License.           //
// You may obtain a copy of the License at                                    //
//                                                                            //
//     http://www.apache.org/licenses/LICENSE-2.0                             //
//                                                                            //
// Unless required by applicable law or agreed to in writing, software        //
// distributed under the License is distributed on an "AS IS" BASIS,          //
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   //
// See the License for the specific language governing permissions and        //
// limitations under the License.                                             //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

//
//
// This module demonstrates the creation of a translator type,
// it's connection to peers, and it's operation in both the
// analysis and stimulus paths.
//
//
module sk_translator_demo();

//
// Import the UVM
//
import uvm_pkg::*;

`include "uvm_macros.svh"

//
// Not part of UVM (yet), so include it separately
//
`include "sk_translator.svh"

//
// Create a data class to translate
//
class t_bitstream_item #(BW) extends uvm_sequence_item;

  rand bit [BW-1:0] data;

  `uvm_object_param_utils_begin(t_bitstream_item #(BW))
    `uvm_field_int(data,UVM_DEFAULT|UVM_HEX)
  `uvm_object_utils_end

  local string format;
  
  function new(string name="");
    super.new(name);
    format = $sformatf("%%0%1dx",(BW>>2)+(BW&3?1:0));
  endfunction
  
  function string convert2string();
    return $sformatf(format,data);     
  endfunction

endclass

//
// Create a translator that arbitrarily changes the width of a bitstream
//
class t_gearbox #(BWI, BWO) extends sk_translator #(t_bitstream_item#(BWI),t_bitstream_item#(BWO));

  t_bitstream_item#(BWO) ob;
  int j;
  
  function new(string name="", uvm_component parent=null);
    super.new(name,parent);
    ob = new("ob");
    j  = 0;
  endfunction

  task translate();
    t_bitstream_item#(BWI) ib;
    
    // (1) Get
    get_inbound_item(ib);
    for (int i=0;i<BWI;i++) begin
      // (2) Transform
      ob.data[j++] = ib.data[i];
      if (j == BWO) begin
        // (3) Put
        put_outbound_item(ob);
        j = 0;
      end
    end
  endtask
  
endclass

//
// Create a sequence type and sequence for our test
//
typedef t_bitstream_item#(32) t_word;

class t_random_word extends uvm_sequence #(t_word);

  int words;
  
  function new(string name="");
    super.new(name);
    words = 25;
  endfunction
  
  task body();
    t_word p,q;
    p = new("p");
    repeat (words) begin
      wait_for_grant();
      void'(p.randomize());
      $cast(q,p.clone());
      send_request(q);
    end
  endtask

endclass

//
// Create a loopback class to emulate going down to a virtual interface and back
//
class t_loopback #(type t_item = uvm_sequence_item) extends uvm_component;
 
  uvm_analysis_port #(t_item)             analysis_port;
  uvm_seq_item_pull_port #(t_item,t_item) seq_item_port;
   
  function new(string name="", uvm_component parent=null);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_port = new("analysis_port",this);
    seq_item_port = new("seq_item_port",this);
  endfunction
  
  task run_phase(uvm_phase phase);
    t_item item;
    super.run_phase(phase);
    forever begin
      seq_item_port.get_next_item(item);
      uvm_report_info("LBPK",item.convert2string());
      analysis_port.write(item);
    end
  endtask
   
endclass

//
// Create a test that demos chaining translators and operating them in both analysis & stimulus contexts
//
class t_translator_demo extends uvm_test;

  `uvm_component_utils(t_translator_demo)

  // Stimulus Path
  t_random_word                     seqL2;
  uvm_sequencer #(t_word)           sqrL2;
  t_gearbox#(32,8)                  genL2; // A nice 4:1 ratio
  t_gearbox#(8,3)                   genL1; // A not-so-nice 8:3 ratio

  // Loopback
  t_loopback#(t_bitstream_item#(3)) lpbk0;

  // Analysis Path
  t_gearbox#(3,8)                   monL1;
  t_gearbox#(8,32)                  monL2;

  function new(string name="", uvm_component parent=null);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seqL2 = new("seqL2");
    sqrL2 = new("sqrL2",this);
    genL2 = new("genL2",this); genL2.is_active = UVM_ACTIVE;
    genL1 = new("genL1",this); genL1.is_active = UVM_ACTIVE;
    lpbk0 = new("lpbk0",this);
    monL1 = new("monL1",this);
    monL2 = new("monL2",this);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Stimulus Path
    genL2.seq_item_port.connect(sqrL2.seq_item_export);
    genL1.seq_item_port.connect(genL2.seq_item_export);
    lpbk0.seq_item_port.connect(genL1.seq_item_export);
    // Analysis Path
    lpbk0.analysis_port.connect(monL1.analysis_export);
    monL1.analysis_port.connect(monL2.analysis_export);
  endfunction
  
  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
    // Turn on inbound/outbound logging
    genL2.inbound_log    = "input.dat";
    //genL2.inbound_log  = "genL2i.dat";
    //genL2.outbound_log = "genL2o.dat";
    //genL1.inbound_log  = "genL1i.dat";
    //genL1.outbound_log = "genL1o.dat";
    //monL1.inbound_log  = "monL1i.dat";
    //monL1.outbound_log = "monL1o.dat";
    //monL2.inbound_log  = "monL2i.dat";
    //monL2.outbound_log = "monL2o.dat";
    monL2.outbound_log   = "output.dat";
    // Turn up verbosity
    genL2.set_report_verbosity_level(UVM_HIGH);
    genL1.set_report_verbosity_level(UVM_HIGH);
    monL1.set_report_verbosity_level(UVM_HIGH);
    monL2.set_report_verbosity_level(UVM_HIGH);
  endfunction
  
  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);
    seqL2.words = 2400;
    seqL2.start(sqrL2);
    phase.drop_objection(this);
  endtask
  
endclass

initial run_test("t_translator_demo");

endmodule
