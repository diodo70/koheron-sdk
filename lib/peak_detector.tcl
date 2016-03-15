
proc add_peak_detector {module_name wfm_width} {

  set bd [current_bd_instance .]
  current_bd_instance [create_bd_cell -type hier $module_name]

  create_bd_pin -dir I -type clk              clk
  create_bd_pin -dir I -from 31 -to 0         din
  create_bd_pin -dir I                        tvalid
  create_bd_pin -dir O -from $wfm_width -to 0 address_out
  create_bd_pin -dir O -from 31 -to 0         maximum_out
  set compare_latency 0

  # Add comparator
  cell xilinx.com:ip:floating_point:7.1 comparator {
    Operation_Type Compare
    C_Compare_Operation Greater_Than
    Flow_Control NonBlocking
    Maximum_Latency False
    C_Latency $compare_latency
  } {
    s_axis_a_tdata din
    s_axis_a_tvalid tvalid
    s_axis_b_tvalid tvalid
  }

  cell xilinx.com:ip:xlslice:1.0 slice_compare {
    DIN_WIDTH 8
  } {
    Din comparator/m_axis_result_tdata
  }

  # Address starting counting at tvalid
  cell xilinx.com:ip:c_counter_binary:12.0 address_counter {
    CE true
    Output_Width $wfm_width
  } {
    CLK clk
    CE tvalid
  }

  cell xilinx.com:ip:xlconstant:1.1 reset_cycle_constant {
    CONST_WIDTH $wfm_width
    CONST_VAL [expr 2**$wfm_width-1]
  } {}

  cell koheron:user:comparator:1.0 reset_cycle {
    DATA_WIDTH $wfm_width
    OPERATION "EQ"
  } {
    a address_counter/Q
    b reset_cycle_constant/dout
  }

  # OR
  cell xilinx.com:ip:util_vector_logic:2.0 logic_or {
    C_SIZE 1
    C_OPERATION or
  } {
    Op1 slice_compare/Dout
    Op2 reset_cycle/dout
  }

  # Register storing the current maximum
  cell xilinx.com:ip:c_shift_ram:12.0 maximum_reg {
    CE true
    Width 32
    Depth 1
  } {
    CLK clk
    D din
    CE logic_or/Res
    Q comparator/s_axis_b_tdata
  }

  # Register storing the address of current maximum
  cell xilinx.com:ip:c_shift_ram:12.0 address_reg {
    CE true
    Width $wfm_width
    Depth 1
  } {
    CLK clk
    D address_counter/Q
    CE logic_or/Res
  }

  # Register storing the maximum of one cycle
  cell xilinx.com:ip:c_shift_ram:12.0 maximum_out {
    CE true
    Width 32
    Depth 1
  } {
    CLK clk
    CE reset_cycle/dout
    D maximum_reg/Q
    Q maximum_out
  }

  # Register storing the address of the maximum of one cycle
  cell xilinx.com:ip:c_shift_ram:12.0 address_out {
    CE true
    Width $wfm_width
    Depth 1
  } {
    CLK clk
    CE reset_cycle/Dout
    D address_reg/Q
    Q address_out
  }

  current_bd_instance $bd

}