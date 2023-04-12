`include "svunit_defines.svh"
import bathtub_pkg::*;

module step_parameters_unit_test;
	import svunit_pkg::svunit_testcase;

	string name = "step_parameters_ut";
	svunit_testcase svunit_ut;


	//===================================
	// This is the UUT that we're
	// running the Unit Tests on
	//===================================
	bathtub_pkg::step_parameters step_parameters;


	//===================================
	// Build
	//===================================
	function void build();
		svunit_ut = new(name);
	endfunction


	//===================================
	// Setup for running the Unit Tests
	//===================================
	task setup();
		svunit_ut.setup();
	/* Place Setup Code Here */

	endtask


	//===================================
	// Here we deconstruct anything we
	// need after running the Unit Tests
	//===================================
	task teardown();
		svunit_ut.teardown();
	/* Place Teardown Code Here */

	endtask


	//===================================
	// All tests are defined between the
	// SVUNIT_TESTS_BEGIN/END macros
	//
	// Each individual test must be
	// defined between `SVTEST(_NAME_)
	// `SVTEST_END
	//
	// i.e.
	//   `SVTEST(mytest)
	//     <test code>
	//   `SVTEST_END
	//===================================
	`SVUNIT_TESTS_BEGIN


	`SVTEST(\One_real_number_step_parameter )
	// ====================================
	struct {
		string step_text;
		string step_format;
		real expected_value;
	} examples[$];

	(* Examples *)
	examples = '{
		'{
			step_text : "6.0221408e+23",
			step_format : "%f",
			expected_value : 6.0221408e+23
		},
		'{
			step_text : "The number is 6.0221408e+23",
			step_format : "The number is %f",
			expected_value : 6.0221408e+23
		}
	};

	foreach (examples[i]) begin

		(* Given = "step text with one real number parameter" *)
		step_parameters = bathtub_pkg::step_parameters::create_new("step_parameters", examples[i].step_text, examples[i].step_format);

		(* Then *)
		`FAIL_UNLESS_LOG(
			step_parameters.num_args() == 1,
			"should return one value")

		(* And *)
		`FAIL_UNLESS_LOG(
			step_parameters.get_arg(0).as_real() == examples[i].expected_value,
			"should return the correct real number value")

	end

	`SVTEST_END


	`SVTEST(\Extracting_values_from_a_step_parameters_object )
	// =====================================================
	int actual_int_value;
	real actual_real_value;
	string actual_string_value;
	int expected_int_value;
	real expected_real_value;
	string expected_string_value;
	string str;
	string format;

	(* Given = "a new `step_parameters` object whose values are 42, 92.7, and 'puppy'" *)
	step_parameters = bathtub_pkg::step_parameters::create_new("step_parameters", "int= 42 , real= 92.7 , string= puppy", "int= %d , real= %f , string= %s");

	(* When = "I extract the values from the `step_parameters` object" *)
	actual_int_value = step_parameters.get_arg(0).as_int();
	actual_real_value = step_parameters.get_arg(1).as_real();
	actual_string_value = step_parameters.get_arg(2).as_string();

	expected_int_value = 42;
	expected_real_value = 92.7;
	expected_string_value = "puppy";

	(* Then = "integer value should be 42" *)
	`FAIL_UNLESS(actual_int_value == expected_int_value)

	(* And = "real value should be 92.7" *)
	`FAIL_UNLESS(actual_real_value == expected_real_value)

	(* And = "string value should be 'puppy'" *)
	`FAIL_UNLESS(actual_string_value == expected_string_value)

	`SVTEST_END


	`SVTEST(\Step_parameters_class_behaves_like_$sscanf() )
	// ==================================================
	struct {
		string step_text;
		string step_format;
	} examples[$];

	int actual_int_value;
	real actual_real_value;
	string actual_string_value;
	int expected_int_value;
	real expected_real_value;
	string expected_string_value;
	int code;

	(* Examples *)
	examples = '{
		'{
			// Control characters are separate tokens surrounded by white space
			step_text : "int : 42 , real : 92.7 , string : puppy",
			step_format : "int : %d , real : %f , string : %s"
		},
		'{
			// Control characters are attached to the surrounding text with no white space
			step_text : "int=42, real=92.7, string=puppy",
			step_format : "int=%d, real=%f, string=%s"
		}
	};

	foreach (examples[i]) begin
		`ifdef DEBUG
		$info("%s\n%s", examples[i].step_text, examples[i].step_format);
		`endif

		(* Given = "a new `step_parameters` object containing an int, a real number, and a string" *)
		step_parameters = bathtub_pkg::step_parameters::create_new("step_parameters", examples[i].step_text, examples[i].step_format);

		(* And = "I give the same step text and format to $sscanf()" *)
		code = $sscanf(examples[i].step_text, examples[i].step_format, expected_int_value, expected_real_value, expected_string_value);

		(* When = "I extract the values from the `step_parameters` object" *)
		actual_int_value = step_parameters.get_arg(0).as_int();
		actual_real_value = step_parameters.get_arg(1).as_real();
		actual_string_value = step_parameters.get_arg(2).as_string();

		(* Then = "`step_parameters.num_args()` should match `$sscanf()`'s output" *)
		`FAIL_UNLESS_EQUAL(step_parameters.num_args(), code)

		(* And = "integer value should match $sscanf()" *)
		`FAIL_UNLESS(actual_int_value == expected_int_value)

		(* And = "real value should match $sscanf()" *)
		`FAIL_UNLESS(actual_real_value == expected_real_value)

		(* And = "string value should match $sscanf()" *)
		`FAIL_UNLESS(actual_string_value == expected_string_value)
	end

	`SVTEST_END


	// ---
	`SVUNIT_TESTS_END

endmodule
