
`ifndef BATHTUB_MACROS_SV
`define BATHTUB_MACROS_SV

`define Given(e) `__register_step_def(bathtub_pkg::Given, e)

`define When(e) `__register_step_def(bathtub_pkg::When, e)

`define Then(e) `__register_step_def(bathtub_pkg::Then, e)

`define __register_step_def(k, e) static bathtub_pkg::step_static_attributes_interface __step_static_attributes = bathtub_pkg::step_nature::register_step(k, e, get_type());\
virtual function step_static_attributes_interface get_step_static_attributes();\
	return __step_static_attributes;\
endfunction : get_step_static_attributes

`define step_parameter_get_args_begin(f=get_step_attributes().get_expression())\
begin : step_parameter_get_args\
    step_parameters __step_params;\
    int __next = 0;\
	__step_params = step_parameters::create_new("__step_params", get_step_attributes().get_text(), f);

`define step_parameter_get_arg_object(i) __step_params.get_arg(i)

`define step_parameter_get_arg_as(i, t) `step_parameter_get_arg_object(i).as_``t()

`define step_parameter_get_next_arg_object `step_parameter_get_arg_object(__next++)

`define step_parameter_get_next_arg_as(t) `step_parameter_get_next_arg_object.as_``t()

`define step_parameter_num_args __step_params.num_args()

`define step_parameter_get_args_end end : step_parameter_get_args

`endif // BATHTUB_MACROS_SV
