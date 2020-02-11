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
// Class: sk_layer
//
// The sk_layer class forms a structural reuse atom in the layered UVC 
// architecture.
//
// An layer is composed of one or more sk_translators in the stimulus path,
// each with optional orthogonal sequencers, effecting a translation from
// a high abstraction inbound item to a low abstraction outbound item; and
// one or more sk_translators in the analysis path, each with optional 
// analysis taps, effecting a translation from a low abstraction inbound
// item to a high abstraction outbound item.
//
// The analysis path is always present and the stimulus path is only present
// when ~is_active~ is UVM_ACTIVE.
//
// The ports of terminal translators should be "wired-out" of/"wired-in" to
// the layer.
//
//| class some_layer extends uvm_layer;
//|
//|   // analysis path
//|   uvm_analysis_export #(LO) analysis_export; // accept    LO items
//|   some_translation #(LO,X)  ap_stage_0;      // translate LO items to X  items
//|   some_translation #(X,HI)  ap_stage_1;      // translate X  items to HI items
//|   uvm_analysis_path #(HI)   analysis_port;   // write     HI items
//|
//|   // stimulus path
//|   uvm_seq_item_pull_port #(HI,HI)
//|   HI_to_X  sp_s1;  // Stage 1: translate HI items to X  items
//|   X_to_LO  sp_s0;  // Stage 0: translate X  items to LO items
//|
//|   uvm_analysis_port #(HI)        analysis_port;
//|   uvm_seq_item_pull_port #(T,T) seq_item_port;
//|
//|   `uvm_component_param_utils(some_anchor#(T))
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
//-----------------------------------------------------------------------------

virtual class sk_layer extends uvm_agent; // Inherit is_active, that's all.

  //
  // Function: new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for <uvm_component>: ~name~ is the name of the
  // instance, and ~parent~ is the handle to the hierarchical parent, if any.
  
  function new(string name = "", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  constant static string type_name = "sk_layer";
  
  virtual function string get_type_name();
    return type_name;
  endfunction

endclass
