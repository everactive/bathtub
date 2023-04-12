`include "svunit_defines.svh"
import bathtub_pkg::*;

module step_nature_unit_test;
	import svunit_pkg::svunit_testcase;

	string name = "step_nature_ut";
	svunit_testcase svunit_ut;


	//===================================
	// This is the UUT that we're
	// running the Unit Tests on
	//===================================
	bathtub_pkg::step_nature step_nature;


	//===================================
	// Build
	//===================================
	function void build();
		svunit_ut = new(name);

		step_nature = new("step_nature");
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


	`SVUNIT_TESTS_END

endmodule
