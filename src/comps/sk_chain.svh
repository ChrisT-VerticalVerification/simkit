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

//------------------------------------------------------------------------------
//
// Class: sk_chain
//
// The sk_chain class forms a structural integration in the layered UVC 
// architecture and is used in either unit level or top level contexts,
// but not both.
//
// An attachment is composed of a driver/monitor pair that interfaces to 
// the DUT through a virtual interface.  The monitor is always present and the 
// driver is only present if ~is_active~ is UVM_ACTIVE.
//
// The ~seq_item_port~ of the driver and the ~analysis_port~ of the monitor
// should be "wired-out" of the anchor.
//
//| class some_attachment #(type T) extends sk_attachment;
//|
//|   some_driver  driver;
//|   some_monitor monitor;
//|
//|   uvm_analysis_port #(T)        analysis_port;
//|   uvm_seq_item_pull_port #(T,T) seq_item_port;
//|
//|   `uvm_component_param_utils(some_attachment#(T))
//|
//|   function new(string name, uvm_component parent=null);
//|     super.new(name,parent);
//|   endfunction
//|
//|   function void build_phase(uvm_phase phase);
//|     super.build_phase(phase);
//|     if (is_active) begin
//|       driver        = some_driver::type_id::create("m_driver",this);
//|       seq_item_port = new("seq_item_port",this);
//|     end
//|     monitor       = some_monitor::type_id::create("m_monitor",this);
//|     analysis_port = new("analysis_port",this);
//|   endfunction
//|     
//|   function void connect_phase(uvm_phase phase);
//|     super.connect_phase(phase);
//|     if (is_active)
//|       driver.seq_item_port.connect(seq_item_port);
//|     monitor.analysis_port.connect(analysis_port);
//|   endfunction
//|
//| endclass
//
// Agents connect sequencers to anchors with zero or more intervening layers.
//
//| class some_agent #(type T, type U) extends uvm_agent;
//|
//|   some_anchor #(U)       anchor;
//|   some_layer  #(T,U)     layer;
//|   uvm_sequencer #(T)     sequencer;
//|   uvm_analysis_port #(T) analysis_port;
//|
//|   `uvm_component_param_utils(some_agent#(T,U))
//|
//|   function new(string name, uvm_component parent=null);
//|     super.new(name,parent);
//|   endfunction
//|
//|   function void build_phase(uvm_phase phase);
//|     super.build_phase(phase);
//|     anchor = some_anchor#(U)::type_id::create("anchor",this); anchor.is_active = is_active;
//|     layer  = some_layer#(T,U)::type_id::create("layer",this); layer.is_active  = is_active;
//|     if (is_active)
//|       sequencer = uvm_sequencer#(T)::type_id::create("sequencer",this);
//|     analysis_port = new("analysis_port",this);
//|   endfunction
//|     
//|   function void connect_phase(uvm_phase phase);
//|     super.connect_phase(phase);
//|     // stimulus path
//|     if (is_active) begin
//|       anchor.seq_item_port.connect(layer.seq_item_export);
//|       layer.seq_item_port.connect(sequencer.seq_item_export);
//|     end
//|     // analysis path
//|     anchor.analysis_port.connect(layer.analysis_export);
//|     layer.analysis_port.connect(analysis_port);
//|   endfunction
//|
//| endclass
//
//------------------------------------------------------------------------------

virtual class sk_chain extends uvm_agent; // Inherit is_active, that's all.

  //
  // Function: new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for <uvm_component>: ~name~ is the name of the
  // instance, and ~parent~ is the handle to the hierarchical parent, if any.
  
  function new(string name = "", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  constant static string type_name = "sk_chain";
  
  virtual function string get_type_name();
    return type_name;
  endfunction

endclass
