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
// Class: sk_translator
//
// This is the key class underpinning a component based layered UVC 
// architecture.
//
// Translators translate a stream of inbound items into a stream of outbound 
// items.
//
// The inbound and outbound item types are parameterized and the specific 
// nature of the translation is implemented an extension to the class that 
// overrides the pure virtual translate() task.
//
// Translators have three operational modes set by the ~is_active~ and 
// ~is_sequenced~ configuration settings.
//
// Passive Translation - In this mode inbound items are ~pushed~ into the 
/      ~analysis_export~, subsequently translated into outbound items then 
//     pushed out the ~analysis_port~.  Passive Translation is intended
//     for analysis path contexts and is the operational mode when 
//     ~is_active~ is UVM_PASSIVE.  This is the default operational mode.
//
// Active Translation - In this mode outbound items are ~pulled~ out the
//     ~seq_item_export~ export, triggering a translation and the subsequent
//     pull of inbound items from the ~seq_item_port~.  Active Translation
//     is intended for stimulus path contexts and is the operational mode 
//     when ~is_active~ is UVM_ACTIVE and the is_sequenced bit is not set.
//
// Inline Sequencing - In this mode outbound items are ~pulled~ from the 
//     ~inline_sqr~ sequencer instead of from the translation.  Inline 
//     Sequencing is intended for stimulus path scenarios where the stream
//     of outbound items can not be effectively generated from a stream of
//     inbound items through the translation.  Inline Sequencing is the 
//     operational mode when ~is_active~ is UVM_ACTIVE and the is_sequenced
//     bit is set.
//
// Note that the names and types (and hence the semantics) of ports present a
// are determined by the setting of the ~is_active~ bit.  Translations are 
// thus semantically independent because though the semantics of the port 
// connections change, the translation does not.  The implication is that 
// translations are independent of their usage contexts.
// 
//------------------------------------------------------------------------------

virtual class sk_translator #(type t_inbound_item = uvm_sequence_item, type t_outbound_item = uvm_sequence_item) extends uvm_component;

  typedef sk_translator #(t_inbound_item, t_outbound_item) this_type;

  //****************************************************************************
  //
  // Public Properites
  //
  //****************************************************************************
 
  //----------------------------------------------------------------------------
  // Group: Operational Modes
  //----------------------------------------------------------------------------
  //
  // if      UVM_PASSIVE,      translate from analysis_port to analysis_export
  // else if not is_sequenced, translate to seq_item_export from seq_item_port
  // else                      sequence out the seq_item_export from inline_sqr
  //
  //----------------------------------------------------------------------------
  
  uvm_active_passive_enum is_active;
  bit                     is_sequenced;

  //----------------------------------------------------------------------------
  // Group: Interface Ports
  //----------------------------------------------------------------------------
  //
  // These ports are the primary entry/exit points for inbound/outbound items.
  // The ports that are present depend on the ~is_active~ setting.
  //
  //----------------------------------------------------------------------------

  //
  // Port: analysis_export
  //
  // This is the entry port for inbound items in Passive Translation mode.
  // This port is not present in Active Translation or Inline Sequencing modes.
  
  uvm_analysis_export #(t_inbound_item) analysis_export;
  
  //
  // Port: analysis_port
  //
  // This is the exit port for outbound items in Passive Translation mode.
  // This port is not present in Active Translation or Inline Sequencing modes.
  
  uvm_analysis_port #(t_outbound_item) analysis_port;

  //
  // Port: seq_item_port
  //
  // This is the entry port for inbound items in Active Translation mode.
  // This port is not present in Passive Translation mode and not used in 
  // Inline Sequencing mode.
  
  uvm_seq_item_pull_port #(t_inbound_item,t_inbound_item) seq_item_port;
  
  //
  // Port: seq_item_export
  //
  // This is the exit port for outbound items in Active Translation mode or 
  // Inline Sequencing mode. This port is not present in Passive Translation
  // mode.
  
  uvm_seq_item_pull_imp #(t_outbound_item,t_outbound_item,this_type) seq_item_export;
  
  //
  // Port: inline_sqr
  //
  // This is the sequencer handle on which outbound item sequences can be 
  // started in Inline Sequencing mode.  The inline sequencer is only
  // present in Inline Sequencing mode.
  
  uvm_sequencer #(t_outbound_item) inline_sqr;

  //----------------------------------------------------------------------------
  // Group: Debugging Hooks
  //----------------------------------------------------------------------------
  //
  // Arriving inbound items and departing outbound items may be logged to files
  // and/or sent out analysis ports.
  //
  //----------------------------------------------------------------------------

  //
  // Inbound items can be logged to a file by setting ~inbound_log~ to the name 
  // of the file before the run phase.

  string inbound_log;

  //
  // Outbound items can also be logged to a file by setting ~outbound_log~ to 
  // the name of the file before the run phase.

  string outbound_log;

  //
  // Arriving inbound items are sent out the ~inbound_tap~ analsys port if the 
  // ~has_inbound_tap~ bit is set before the build phase.
  
  bit has_inbound_tap;

  //
  // Port: inbound_tap
  //
  // When present, arriving inbound items are written out the ~inbound_tap~
  // analysis port.  This port is only present when the ~has_inbound_tap~
  // configuration bit is set before the build phase.
  
  uvm_analysis_port #(t_inbound_item)  inbound_tap;

  //
  // Departing outbound items are sent out the ~outbound_tap~ analsys port if  
  // the ~has_outbound_tap~ bit is set before the build phase.
  
  bit has_outbound_tap;
  
  //
  // Port: outbound_tap
  //
  // When present, departing outbound items are written out the ~outbound_tap~
  // analysis port.  This port is only present when the ~has_outbound_tap~
  // configuration bit is set before the build phase.
  
  uvm_analysis_port #(t_outbound_item) outbound_tap;
  
  //
  // Property registration
  //

  `uvm_component_param_utils_begin(this_type)
    `uvm_field_enum(uvm_active_passive_enum,is_active,UVM_DEFAULT)
    `uvm_field_int(is_sequenced,UVM_DEFAULT)
    `uvm_field_int(has_inbound_tap,UVM_DEFAULT)
    `uvm_field_int(has_outbound_tap,UVM_DEFAULT)
    `uvm_field_string(inbound_log,UVM_DEFAULT)
    `uvm_field_string(outbound_log,UVM_DEFAULT)
  `uvm_component_utils_end
  
  //****************************************************************************
  //
  // Public Methods
  //
  //****************************************************************************

  //
  // Function: new
  //
  // Creates and initializes an instance of this class using the normal
  // constructor arguments for <uvm_component>: ~name~ is the name of the
  // instance, and ~parent~ is the handle to the hierarchical parent, if any.
  
  function new(string name = "", uvm_component parent = null);
    super.new(name,parent);
    is_active         = UVM_PASSIVE;
    is_sequenced      = 0;
    has_inbound_tap   = 0;
    has_outbound_tap  = 0;
    inbound_fh        = 0;
    outbound_fh       = 0;
    inbound_log       = "";
    outbound_log      = "";
    translate_request = 0;
  endfunction
  
  //
  // Function: translate
  //
  // Extensions to this class must implement the translate() pure
  // virtual task using the following translation API:
  //
  //|  get_inbound_item(output t_inbound_item item);
  //|  try_inbound_item(output t_inbound_item item);
  //|  put_outbound_item(input t_outbound_item item);
  //|  put_uncloned_outbound_item(input t_outbound_item item);
  // 
  // Implementations must also follow a get/try-transform-put pattern:
  //
  //|  task translate()
  //|    // Get
  //|    get_inbound_item(inbound);
  //|    // Transform the inbound into an outbound
  //|    ...
  //|    // Put
  //|    put_outbound_item(outbound);
  //|  endtask
  //
  // though the pattern does not need to be one-to-one.  Implemenations
  // may implement one-to-one, many-to-one, one-to-many or many-to-many
  // translations that are either periodic or aperiodic as long as you
  // get enough input before putting out output.

  pure virtual task translate();
   
  //----------------------------------------------------------------------------
  // Group: Translation API
  //----------------------------------------------------------------------------
  // 
  // Extensions must implement the <translate> task using the Translation API
  // and follow a get/try-transform-put pattern.  
  // 
  //----------------------------------------------------------------------------

  //
  // Function: get_inbound_item
  //
  // This task returns an inbound item or blocks if one is not ready.

  task get_inbound_item(output t_inbound_item t);
     t_inbound_item u;
     if (is_active == UVM_PASSIVE)
       inbound_fifo.get(t);  // Block until items arrive
     else
       seq_item_port.get(t); // Blocks if sequence is finished
     if (uvm_report_enabled(UVM_HIGH,UVM_INFO,"GET")) uvm_report_info("GET",{"Inbound item: ",t.convert2string()},UVM_HIGH);
     if (inbound_fh) $fdisplay(inbound_fh,"%0s",t.convert2string());
     if (has_inbound_tap) begin void'($cast(u,t.clone())); inbound_tap.write(u); end
  endtask

  //
  // Function: try_inbound_item
  //
  // This task returns and inbound item or null if one is not ready.

  task try_inbound_item(output t_inbound_item t);
    t_inbound_item u;
    if (is_active == UVM_PASSIVE) 
      uvm_report_fatal("uvm_translator","try_inbound_item can only be called when is_active is UVM_ACTIVE.");
    else begin
      uvm_wait_for_nba_region();      // Wait for the neighbour to do it's thing (if anything).
      seq_item_port.try_next_item(t);
    end
    if (t != null) begin
      seq_item_port.item_done();
      if (uvm_report_enabled(UVM_HIGH,UVM_INFO,"TRY")) uvm_report_info("TRY",{"Inbound item: ",t.convert2string()},UVM_HIGH);
      if (inbound_fh) $fdisplay(inbound_fh,"%0s",t.convert2string());
      if (has_inbound_tap) begin void'($cast(u,t.clone())); inbound_tap.write(u); end
    end
  endtask
  
  //
  // Function: put_outbound_item
  //
  // This task sends out a cloned outbound item.

  task put_outbound_item(input t_outbound_item t);
    t_outbound_item u;
    void'($cast(u,t.clone()));
    put_uncloned_outbound_item(u);
  endtask

  //
  // Function: put_uncloned_outbound_item
  //
  // This task sends out an uncloned outbound item.

  task put_uncloned_outbound_item(input t_outbound_item t);
    t_outbound_item u;
    if (has_outbound_tap) begin void'($cast(u,t.clone())); outbound_tap.write(u); end
    if (outbound_fh) $fdisplay(outbound_fh,"%0s",t.convert2string());
    if (uvm_report_enabled(UVM_HIGH,UVM_INFO,"PUT")) uvm_report_info("PUT",{"Outbound item: ",t.convert2string()},UVM_HIGH); // Check level first to optimize run time
    if (is_active == UVM_PASSIVE)
      analysis_port.write(t);
    else
      outbound_fifo.put(t); // does not block
  endtask

  //********************************************
  //
  // Private Properties & Methods
  //
  //********************************************

  local uvm_tlm_analysis_fifo #(t_inbound_item)  inbound_fifo;  // For analysis path - to convert to pull semantic
  local uvm_tlm_fifo          #(t_outbound_item) outbound_fifo; // For stimulus path

  local int inbound_fh;
  local int outbound_fh;
  
  local int translate_request; // For background, possibly blocking, translation initiated by a try_inbound_item 

  //
  // UVM Phases
  //

  function void build_phase(uvm_phase phase);
    bit is_active_bit;
    super.build_phase(phase);
    void'(uvm_config_db#(bit)::get(this,"","is_sequenced",is_sequenced));
    if   (uvm_config_db#(bit)::get(this,"","is_active",is_active_bit)) is_active = uvm_active_passive_enum'(is_active_bit); // in case it was set as a bit instead of the enum
    void'(uvm_config_db#(uvm_active_passive_enum)::get(this,"","is_active",is_active));
    if (is_active == UVM_PASSIVE) begin
      analysis_export = new("analysis_export",this);
      analysis_port   = new("analysis_port",this);
      inbound_fifo    = new("inbound_fifo",this);
    end
    else if (!is_sequenced) begin
      seq_item_export = new("seq_item_export",this);
      seq_item_port   = new("seq_item_port",this);
      outbound_fifo   = new("outbound_fifo",this,0);
    end
    else begin
      seq_item_export = new("seq_item_export",this);
      seq_item_port   = new("seq_item_port",this); // Connected but unused.  Allows for in-situ inline sequencing.
      inline_sqr      = new("inline_sqr",this);
    end
    void'(uvm_config_db#(bit)::get(this,"","has_inbound_tap",has_inbound_tap));
    void'(uvm_config_db#(bit)::get(this,"","has_outbound_tap",has_outbound_tap));
    if (has_inbound_tap)  inbound_tap  = new("inbound_tap",this);
    if (has_outbound_tap) outbound_tap = new("outbound_tap",this);
  endfunction    

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_PASSIVE) analysis_export.connect(inbound_fifo.analysis_export);
  endfunction
  
  function void start_of_simulation_phase(uvm_phase phase);
    t_inbound_item  ib;
    t_outbound_item ob;
    super.start_of_simulation_phase(phase);
    if (get_report_verbosity_level() > UVM_MEDIUM) begin
      ib = new("ib");
      ob = new("ob");
      if (is_active == UVM_PASSIVE)
        uvm_report_info("MODE",$psprintf("Translating '%s' items into '%s' items in the analysis path",ib.get_type_name(),ob.get_type_name()));
      else if (!is_sequenced)
        uvm_report_info("MODE",$psprintf("Translating '%s' items into '%s' items in the stimulus path",ib.get_type_name(),ob.get_type_name()));
      else
        uvm_report_info("MODE",$psprintf("Sequencing '%s' items in the stimulus path",ob.get_type_name()));
    end
  endfunction
  
  task run_phase(uvm_phase phase);
    void'(uvm_config_db#(string)::get(this,"","inbound_log",inbound_log));
    if (inbound_log  != "") inbound_fh  = $fopen(inbound_log,"w");

    void'(uvm_config_db#(string)::get(this,"","outbound_log",outbound_log));
    if (outbound_log != "") outbound_fh = $fopen(outbound_log,"w");

    if (is_active == UVM_PASSIVE) forever translate();  // Flips semantic from push to pull to align with stimulus semantic
  endtask

  function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    if (inbound_fh)  $fclose(inbound_fh);
    if (outbound_fh) $fclose(outbound_fh);
  endfunction

  //
  // Stimulus path translation - implement the seq_item_export interface
  //

  task get_next_item(output t_outbound_item t);
    if (is_sequenced)
      inline_sqr.get_next_item(t);
    else begin
      if (outbound_fifo.is_empty()) translate(); // Blocks when the leaf sequence finishes
      outbound_fifo.get(t);                      // Should never block, since the translate will block first
    end
  endtask
  
  task try_next_item(output t_outbound_item t);
    t = null;
    if (is_sequenced)
      inline_sqr.try_next_item(t);
    else begin
      uvm_wait_for_nba_region();                                      // Wait for the sequence to start, if started
      if (!translate_request) fork background_translate(); join_none  // Kick start a task to do translations (which may block) in the background
      translate_request++;                                            // Trigger a translation
      uvm_wait_for_nba_region();                                      // Wait for it to complete
      void'(outbound_fifo.try_get(t));
    end
  endtask
  
  function void item_done(input t_outbound_item item = null);
    if (is_sequenced) inline_sqr.item_done(item);
  endfunction
  
  task wait_for_sequences();
    if (is_sequenced) inline_sqr.wait_for_sequences();
  endtask
  
  function bit has_do_available();
    if (is_sequenced)
      return inline_sqr.has_do_available();
    else
      return !outbound_fifo.is_empty();
  endfunction 
  
  task get(output t_outbound_item t);
    if (is_sequenced)
      inline_sqr.get(t);
    else begin
      get_next_item(t);
      item_done();
    end
  endtask  
  
  task peek(output t_outbound_item t);
    if (is_sequenced)
      inline_sqr.peek(t);
    else
      try_next_item(t);
  endtask
  
  task put(input t_outbound_item t);
    if (is_sequenced) inline_sqr.put(t);
  endtask

  function void put_response(input t_outbound_item t);
    if (is_sequenced) inline_sqr.put_response(t);
  endfunction
  
  local task background_translate();
    int translate_done;
    translate_done = 0;
    forever begin
      wait (translate_request != translate_done);  // Wait for a trigger to initiate a translation
      translate();                                 // Blocks if no sequences started or all sequences finished, otherwise fills the outbound fifo
      translate_done = translate_request;          // Reset our wait condition. (Note that many requests may have come in while blocked).
    end
  endtask

endclass
