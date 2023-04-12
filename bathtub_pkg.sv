// ===================================================================
package bathtub_pkg;
// ===================================================================

	import uvm_pkg::*;
	import meta_pkg::*;
	
	
	typedef enum {Given, When, Then} step_keyword_t;
	
	
	virtual class bathtub_utils;
		// ===================================================================
		static function bit split_string;
// ===================================================================
			`FUNCTION_METADATA('{

					description:
					"Take a string containing tokens separated by white space, split the tokens, and return them in the supplied SystemVerilog queue.",

					details:
					"",

					categories:
					"utility",

					string: ""
				})

			// Parameters:

			input string str;           // Incoming string of white space-separated tokans

			ref string tokens[$];   // Fills given queue with individual tokens

// ===================================================================
			typedef enum {START, TOKEN, WHITE_SPACE, FINISH} lex_state_t;
			lex_state_t state;
			byte c;
			string token;
			bit ok;

			ok = 1;
			tokens.delete();
			state = START;
			foreach (str[i]) begin
				c = str.getc(i);
				case (state)
					START: begin
						token = "";
						case (c)
							" ", "\t", "\n" : begin
								state = WHITE_SPACE;
							end
							default : begin
								token = {token, c};
								state = TOKEN;
							end
						endcase
					end

					TOKEN: begin
						case (c)
							" ", "\t", "\n" : begin
								tokens.push_back(token);
								token = "";
								state = WHITE_SPACE;
							end
							default : begin
								token = {token, c};
								state = TOKEN;
							end
						endcase
					end

					WHITE_SPACE: begin
						case (c)
							" ", "\t", "\n" : begin
								state = WHITE_SPACE;
							end
							default : begin
								token = {token, c};
								state = TOKEN;
							end
						endcase
					end

					default: begin
						$fatal(1, "Unknown lexer state");
					end
				endcase
			end

			if (state == TOKEN) begin
				tokens.push_back(token);
				state = FINISH;
			end
			return ok;
		endfunction : split_string
		
		
		static function string get_conversion_spec(string str);
			typedef enum {LOOKING_FOR_START, START, WIDTH, CODE} lex_state_t;
			lex_state_t state;
			byte c;
			string spec;

			state = LOOKING_FOR_START;
			spec = "";
			
			foreach (str[i]) begin
				c = str[i];
				case (state)
					LOOKING_FOR_START : begin : state_$looking_for_start
						case (c)
							"%" : begin
								state = START;
								spec = {spec, string'(c)};
							end
						endcase
					end
					
					START : begin : state_$start
						case (c)
							"%" : begin : case_$escaped_percent_sign
								state = LOOKING_FOR_START;
								spec = "";
							end
							
							"0", "1", "2", "3", "4", "5", "6", "7", "8", "9" : begin : case_$optional_width
								state = WIDTH;
								spec = {spec, string'(c)};
							end
							
							"b", "o", "d", "h", "x", "f", "e", "g", "c", "s",
							"B", "O", "D", "H", "X", "F", "E", "G", "C", "S": begin : case_$code
								state = CODE;
								spec = {spec, string'(c)};
							end
							
							default : begin : case_$unsupported_code
								$fatal(1, $sformatf("Unsupported conversion specification character: %s", c));
							end
						endcase
					end
					
					WIDTH : begin : state_$width
						case (c)
							"0", "1", "2", "3", "4", "5", "6", "7", "8", "9" : begin : case_$optional_width
								state = WIDTH;
								spec = {spec, string'(c)};
							end
							
							"b", "o", "d", "h", "x", "f", "e", "g", "c", "s",
							"B", "O", "D", "H", "X", "F", "E", "G", "C", "S": begin : case_$code
								state = CODE;
								spec = {spec, string'(c)};
							end
							
							default : begin : case_$unsupported_code
								$fatal(1, $sformatf("Unsupported conversion specification character: %s", c));
							end
						endcase
					end
					
					CODE : begin : state_$CODE
						break;
					end

					default: begin
						$fatal(1, "Unknown lexer state");
					end
				endcase
			end

			return spec;
		endfunction : get_conversion_spec
		
		
		static function string get_conversion_code(string token);
			typedef enum {LOOKING_FOR_START, START, WIDTH, CODE} lex_state_t;
			lex_state_t state;
			byte c;
			string code;
			string spec;

			spec = get_conversion_spec(token);
			code = (spec == "") ? "" : string'(spec[spec.len() - 1]);
			
			return code;
		endfunction : get_conversion_code
		
		
		static function bit is_regex(string expression);
			bit result;
			byte first_char;
			byte last_char;
			
			expression = trim_white_space(expression);
			first_char = expression[0];
			last_char = expression[expression.len() - 1];
			result = (first_char == "/"  && last_char == "/") ||
				(first_char == "^" && last_char =="$");
			
			return result;
			
		endfunction : is_regex
		
		
		static function string bathtub_to_regexp(string bathtub_exp);
			string regexp_from_code[string] = '{
				"b" : "([0-1XxZz?_]+)",
				"o" : "([0-7XxZz?_]+)",
				"d" : "(([-+]?[0-9_]+)|[xXzZ?])",
				"h" : "([0-9a-fA-FxXzZ?_]+)",
				"x" : "([0-9a-fA-FxXzZ?_]+)",
				"f" : "([+-]?[0-9]+.?[0-9]*[eE]?[+-]?[0-9]*)",
				"e" : "([+-]?[0-9]+.?[0-9]*[eE]?[+-]?[0-9]*)",
				"g" : "([+-]?[0-9]+.?[0-9]*[eE]?[+-]?[0-9]*)",
				"s" : "(\\S*)",
				"c" : "(.)"
			};
			string result = bathtub_exp;

			forever begin
				string spec = get_conversion_spec(result);
				string code;
				string subst_regexp;
				int result_length = result.len();
				int spec_length = spec.len();
				string before_subst = result;
				
//				$info(result);
				
				if (spec == "") break;
				
				code = get_conversion_code(spec);
				code = code.tolower();
				subst_regexp = regexp_from_code[code];
				
				for (int i = 0; i < result_length; i++) begin
					if (result.substr(i, i + spec_length - 1) == spec) begin
						result = {result.substr(0, i - 1), subst_regexp, result.substr(i + spec.len(), result_length - 1)};
						break;
					end
				end
				
				// Prevents an infinite loop.
				assert_substitution_done : assert (before_subst != result) else
					$fatal(1, "Failed to substitute conversion spec '%s' in expression '%s'", spec, result);
			end

			return {"/^", result, "$/"};
		endfunction : bathtub_to_regexp
		
		
		static function int re_match(string re, string str);
			return uvm_re_match(re, str);
		endfunction : re_match


		static function bit string_starts_with(string text_to_search, string search_text);
			return (search_text == text_to_search.substr(0, search_text.len() - 1));
		endfunction : string_starts_with


		static function string trim_white_space(string line_buf);
			byte c;
			int index_of_first_non_white_space;
			int index_of_last_non_white_space;

			index_of_first_non_white_space = line_buf.len(); // Beyond the end
			for (int i = 0; i < line_buf.len(); i++) begin
				c = line_buf[i];

				if (!(c inside {" ", "\t", "\n"})) begin
					index_of_first_non_white_space = i;
					break;
				end
			end

			index_of_last_non_white_space = -1; // Beyond the end
			for (int i = line_buf.len() - 1; i >= 0; i--) begin
				c = line_buf[i];

				if (!(c inside {" ", "\t", "\n"})) begin
					index_of_last_non_white_space = i;
					break;
				end
			end

			line_buf = line_buf.substr(index_of_first_non_white_space, index_of_last_non_white_space);
			return line_buf;
		endfunction : trim_white_space

	endclass : bathtub_utils


	class line_value;
		string text;
		string file_name;
		int line_number;
		bit eof;

		function new(string text, string file_name, int line_number=0, bit eof=0);
			this.text = text;
			this.file_name = file_name;
			this.line_number = line_number;
			this.eof = eof;
		endfunction : new
	endclass : line_value
	
	
	class step_parameter_arg extends uvm_object;
		typedef enum {INVALID, INT, REAL, STRING} arg_type_t;
		protected int int_arg;
		protected real real_arg;
		protected string string_arg;
		protected arg_type_t arg_type;
		

		function new(string name="step_parameter_arg");
			super.new(name);
			arg_type = INVALID;
		endfunction : new
		

		`uvm_object_utils_begin(step_parameter_arg)
			`uvm_field_enum(arg_type_t, arg_type, UVM_ALL_ON)
			`uvm_field_int(int_arg, UVM_ALL_ON)
			`uvm_field_real(real_arg, UVM_ALL_ON)
			`uvm_field_string(string_arg, UVM_ALL_ON)
		`uvm_object_utils_end
		
		
		static function step_parameter_arg create_new_int_arg(string name, int value);
			step_parameter_arg new_obj = new(name);
			new_obj.int_arg = value;
			new_obj.arg_type = INT;
			return new_obj;
		endfunction : create_new_int_arg
		
		
		static function step_parameter_arg create_new_real_arg(string name, real value);
			step_parameter_arg new_obj = new(name);
			new_obj.real_arg = value;
			new_obj.arg_type = REAL;
			return new_obj;
		endfunction : create_new_real_arg
		
		
		static function step_parameter_arg create_new_string_arg(string name, string value);
			step_parameter_arg new_obj = new(name);
			new_obj.string_arg = value;
			new_obj.arg_type = STRING;
			return new_obj;
		endfunction : create_new_string_arg
		
		
		virtual function int as_int();
			case (arg_type)
				INVALID : return 0;
				INT : return int_arg;
				REAL : return int'(real_arg);
				STRING : return string_arg.atoi(); // decimal
			endcase
		endfunction : as_int
		
		
		virtual function real as_real();
			case (arg_type)
				INVALID : return 0.0;
				INT : return real'(int_arg);
				REAL : return real_arg;
				STRING : return string_arg.atoreal();
			endcase
		endfunction : as_real
		
		
		virtual function string as_string();
			case (arg_type)
				INVALID : return "";
				INT : return $sformatf("%d", int_arg);
				REAL : return $sformatf("%f", real_arg);
				STRING : return string_arg;
			endcase
		endfunction : as_string
		
	endclass : step_parameter_arg
	
	
	class step_parameters extends uvm_object;
		protected step_parameter_arg argv[$];
		protected string step_text;
		protected string format;
		local bit has_been_scanned;
		
		
		`uvm_field_utils_begin(step_parameters)
		`uvm_field_utils_end
		
		
		function new(string str="", string format="");
			super.new("step_parameters");
			has_been_scanned = 1'b0;
		endfunction : new
		
		
		static function step_parameters create_new(string name, string step_text="", string format="");
			step_parameters new_obj = new(name);
			
			new_obj.step_text = step_text;
			new_obj.format = format;
			
			return new_obj;
			
		endfunction : create_new
		
		
		virtual function step_parameter_arg get_arg(int i);
			if (!has_been_scanned) begin
				void'(step_parameters::scan_step_params(step_text, format, argv));
				has_been_scanned = 1'b1;
			end
			return argv[i];
		endfunction : get_arg
		
		
		virtual function int num_args();
			if (!has_been_scanned) begin
				void'(step_parameters::scan_step_params(step_text, format, argv));
				has_been_scanned = 1'b1;
			end
			return argv.size();
		endfunction : num_args
			
		

// ===================================================================
		static function int scan_step_params(string step_text, string scanf_format, ref step_parameter_arg step_argv[$]);
// ===================================================================
			string text_tokens[$];
			string format_tokens[$];
			bit ok;
			
			`uvm_info_begin(`get_scope_name(-2), "", UVM_HIGH)
				`uvm_message_add_string(step_text)
				`uvm_message_add_string(scanf_format)
			`uvm_info_end

			step_argv.delete();

			ok = bathtub_utils::split_string(scanf_format, format_tokens);
			ok = bathtub_utils::split_string(step_text, text_tokens);

			for (int i = 0; i < format_tokens.size(); i++) begin
				int sscanf_code;
				string conversion_code;
				int int_arg;
				real real_arg;
				string string_arg;

				conversion_code = bathtub_utils::get_conversion_code(format_tokens[i]);

				case (conversion_code)
					"b", "o", "d", "h", "x",
					"B", "O", "D", "H", "X" : begin : case_$int
						sscanf_code = $sscanf(text_tokens[i], format_tokens[i], int_arg);

						if (sscanf_code == 1) begin
							step_argv.push_back(step_parameter_arg::create_new_int_arg("anonymous", int_arg));
						end
						else begin
							$fatal(1, $sformatf("Unexpected result (%0d) while parsing string '%s' with format '%s'",
								sscanf_code, text_tokens[i], format_tokens[i]));
						end
					end

					"f", "e", "g",
					"F", "E", "G" : begin : case_$real
						sscanf_code = $sscanf(text_tokens[i], format_tokens[i], real_arg);

						if (sscanf_code == 1) begin
							step_argv.push_back(step_parameter_arg::create_new_real_arg("anonymous", real_arg));
						end
						else begin
							$fatal(1, $sformatf("Unexpected result (%0d) while parsing string '%s' with format '%s'",
								sscanf_code, text_tokens[i], format_tokens[i]));
						end
					end

					"s", "c",
					"S", "C" : begin : case_$string
						sscanf_code = $sscanf(text_tokens[i], format_tokens[i], string_arg);

						if (sscanf_code == 1) begin
							step_argv.push_back(step_parameter_arg::create_new_string_arg("anonymous", string_arg));
						end
						else begin
							$fatal(1, $sformatf("Unexpected result (%0d) while parsing string '%s' with format '%s'",
								sscanf_code, text_tokens[i], format_tokens[i]));
						end
					end

					default : begin : case_$no_arg
						sscanf_code = $sscanf(text_tokens[i], format_tokens[i]);

						if (sscanf_code != 0) begin
							$fatal(1, $sformatf("Unexpected result (%0d) while parsing string '%s' with format '%s'",
								sscanf_code, text_tokens[i], format_tokens[i]));
						end
					end
				endcase
			end

			foreach (step_argv[i]) begin
				`uvm_info(`get_scope_name(), {"\n", step_argv[i].sprint()}, UVM_HIGH)
			end

			return step_argv.size();
		endfunction : scan_step_params



	endclass : step_parameters
	
	
	interface class step_static_attributes_interface;
		
		// Set keyword
		pure virtual function void set_keyword(step_keyword_t keyword);

		// Get keyword
		pure virtual function step_keyword_t get_keyword();

		// Set regexp
		pure virtual function void set_regexp(string regexp);

		// Get regexp
		pure virtual function string get_regexp();

		// Get expression
		pure virtual function string get_expression();

		// Set expression
		pure virtual function void set_expression(string expression);

		// Get step_obj
		pure virtual function uvm_object_wrapper get_step_obj();

		// Set obj_name
		pure virtual function void set_step_obj(uvm_object_wrapper step_obj);
		
		// Get step_obj_name
		pure virtual function string get_step_obj_name();
		
		pure virtual function void print_attributes(uvm_verbosity verbosity);
		
	endclass : step_static_attributes_interface


	class step_nature extends uvm_object implements step_static_attributes_interface;

		protected step_keyword_t keyword;
		protected string expression;
		protected string regexp;
		protected uvm_object_wrapper step_obj;
		protected string step_obj_name;

		function new(string name="step_nature");
			super.new(name);
		endfunction : new


		`uvm_object_utils_begin(step_nature)
			`uvm_field_enum(step_keyword_t, keyword, UVM_DEFAULT)
			`uvm_field_string(expression, UVM_DEFAULT)
			`uvm_field_string(regexp, UVM_DEFAULT)
			`uvm_field_string(step_obj_name, UVM_DEFAULT)
		`uvm_object_utils_end

		static function step_static_attributes_interface register_step(step_keyword_t keyword, string expression, uvm_object_wrapper step_obj);
			step_nature new_obj;

			new_obj = new("static_step_object");
			new_obj.keyword = keyword;
			new_obj.expression = expression;
			new_obj.set_step_obj(step_obj);
			
			if (bathtub_utils::is_regex(expression)) begin
				new_obj.regexp = expression;
			end
			else begin
				new_obj.regexp = bathtub_utils::bathtub_to_regexp(expression);
			end
			
			uvm_resource_db#(uvm_object_wrapper)::set(new_obj.regexp, keyword.name(), step_obj);
			
			`uvm_info(`get_scope_name(), {"\n", new_obj.sprint()}, UVM_HIGH)
			return new_obj;
		endfunction
		
		virtual function void print_attributes(uvm_verbosity verbosity);
			`uvm_info_begin(get_name(), "", verbosity)
			`uvm_message_add_tag("keyword", keyword.name())
			`uvm_message_add_string(expression)
			`uvm_message_add_string(regexp)
			`uvm_message_add_string(step_obj_name)
			`uvm_info_end
		endfunction : print_attributes
				
		// Set keyword
		virtual function void set_keyword(step_keyword_t keyword);
			this.keyword = keyword;
		endfunction : set_keyword

		// Get keyword
		virtual function step_keyword_t get_keyword();
			return keyword;
		endfunction : get_keyword

		// Get expression
		virtual function string get_expression();
			return expression;
		endfunction : get_expression

		// Set expression
		virtual function void set_expression(string expression);
			this.expression = expression;
		endfunction : set_expression

		// Set regexp
		virtual function void set_regexp(string regexp);
			this.regexp = regexp;
		endfunction : set_regexp

		// Get regexp
		virtual function string get_regexp();
			return regexp;
		endfunction : get_regexp

		// Get obj_name
		virtual function uvm_object_wrapper get_step_obj();
			return step_obj;
		endfunction : get_step_obj

		// Set obj_name
		virtual function void set_step_obj(uvm_object_wrapper step_obj);
			this.step_obj = step_obj;
			this.step_obj_name = step_obj.get_type_name();
		endfunction : set_step_obj
		
		// Get step_obj_name
		virtual function string get_step_obj_name();
			return step_obj_name;
		endfunction : get_step_obj_name

		// Set step_obj_name
		virtual function void set_step_obj_name(string step_obj_name);
			this.step_obj_name = step_obj_name;
		endfunction : set_step_obj_name
		
	endclass : step_nature


	interface class step_attributes_interface;
		pure virtual function string get_runtime_keyword();
		pure virtual function void set_runtime_keyword(string runtime_keyword);
		pure virtual function string get_text();
		pure virtual function void set_text(string step_text);
		pure virtual function gherkin_pkg::step_argument get_argument();
		pure virtual function void set_argument(gherkin_pkg::step_argument step_argument);
		pure virtual function step_static_attributes_interface get_static_attributes();
		pure virtual function void set_static_attributes(step_static_attributes_interface static_attributes);
		pure virtual function string get_format();
				
		pure virtual function step_keyword_t get_static_keyword();
		pure virtual function string get_expression();
		pure virtual function string get_regexp();
		pure virtual function uvm_object_wrapper get_step_obj();
		pure virtual function string get_step_obj_name();
		
		pure virtual function void print_attributes(uvm_verbosity verbosity);
	endclass : step_attributes_interface
	
	
	class step_nurture extends uvm_object implements step_attributes_interface;

		string runtime_keyword;
		string text;
		gherkin_pkg::step_argument argument;
		step_static_attributes_interface static_attributes;

		function new(string name="step_nurture");
			super.new(name);
		endfunction : new

		`uvm_object_utils_begin(step_nurture)
			`uvm_field_string(runtime_keyword, UVM_ALL_ON)
			`uvm_field_string(text, UVM_ALL_ON)
			`uvm_field_object(argument, UVM_ALL_ON)
		`uvm_object_utils_end
		
		virtual function void print_attributes(uvm_verbosity verbosity);
			`uvm_info_begin(get_name(), "", verbosity)
			`uvm_message_add_string(runtime_keyword)
			`uvm_message_add_string(text)
			`uvm_message_add_object(argument)
			`uvm_info_end
			static_attributes.print_attributes(verbosity);
		endfunction : print_attributes


		virtual function string get_runtime_keyword();
			return this.runtime_keyword;
		endfunction : get_runtime_keyword

		virtual function void set_runtime_keyword(string runtime_keyword);
			this.runtime_keyword = runtime_keyword;
		endfunction : set_runtime_keyword
		
		virtual function string get_text();
			return this.text;
		endfunction : get_text

		virtual function void set_text(string step_text);
			this.text = step_text;
		endfunction : set_text

		virtual function gherkin_pkg::step_argument get_argument();
			return this.argument;
		endfunction : get_argument

		virtual function void set_argument(gherkin_pkg::step_argument step_argument);
			this.argument = step_argument;
		endfunction : set_argument

		virtual function void set_static_attributes(step_static_attributes_interface static_attributes);
			this.static_attributes = static_attributes;			
		endfunction : set_static_attributes

		virtual function step_static_attributes_interface get_static_attributes();
			return this.static_attributes;			
		endfunction : get_static_attributes

		virtual function string get_format();
			return static_attributes.get_expression();
		endfunction : get_format

		virtual function step_keyword_t get_static_keyword();
			return static_attributes.get_keyword();
		endfunction : get_static_keyword

		virtual function string get_expression();
			return static_attributes.get_expression();
		endfunction : get_expression

		virtual function string get_regexp();
			return static_attributes.get_regexp();
		endfunction : get_regexp
		
		virtual function uvm_object_wrapper get_step_obj();
			return static_attributes.get_step_obj();
		endfunction : get_step_obj

		virtual function string get_step_obj_name();
			return static_attributes.get_step_obj_name();
		endfunction : get_step_obj_name
	
	endclass : step_nurture


	interface class step_definition_interface;
		pure virtual function step_attributes_interface get_step_attributes();
		pure virtual function void set_step_attributes(step_attributes_interface step_attributes);
		pure virtual function step_static_attributes_interface get_step_static_attributes();
	endclass : step_definition_interface


	typedef class gherkin_document_printer;
	typedef class gherkin_document_runner;
	
	
	// Bundle the document with its file name externally.
	// The AST doesn't provide a place for the file name inside the document.
	class gherkin_doc_bundle;
		string file_name;
		gherkin_pkg::gherkin_document document;
		
		function new(string file_name, gherkin_pkg::gherkin_document document);
			this.file_name = file_name;
			this.document = document;
		endfunction : new
		
	endclass : gherkin_doc_bundle
	

	class bathtub extends uvm_object;

		typedef struct {
			string token_before_space;
			string token_before_colon;
			string remainder_after_space;
			string remainder_after_colon;
			string secondary_keyword;
			string remainder_after_secondary_keyword;
		} line_analysis_result_t;

		string feature_files[$];

		gherkin_doc_bundle gherkin_docs[$];
		mailbox line_mbox;
		mailbox gherkin_mbox;
		uvm_sequencer_base sequencer;
		uvm_sequence_base parent_sequence;
		int sequence_priority;
		bit sequence_call_pre_post;
		bit dry_run;
		int starting_scenario_number;
		int stopping_scenario_number;

		`uvm_object_utils_begin(bathtub)
			`uvm_field_queue_string(feature_files, UVM_ALL_ON)
			`uvm_field_int(dry_run, UVM_ALL_ON)
			`uvm_field_int(starting_scenario_number, UVM_ALL_ON)
			`uvm_field_int(stopping_scenario_number, UVM_ALL_ON)
		`uvm_object_utils_end

		function new(string name = "bathtub");
			super.new(name);

			feature_files.delete();
			line_mbox = new(1);
			gherkin_mbox = new(1);
			sequencer = null;
			parent_sequence = null;
			sequence_priority = -1;
			sequence_call_pre_post = 1;
			dry_run = 0;
			starting_scenario_number = 0;
			stopping_scenario_number = 0;
		endfunction : new


		virtual function void configure(
				uvm_sequencer_base sequencer,
				uvm_sequence_base parent_sequence = null,
				int sequence_priority = -1,
				bit sequence_call_pre_post = 1
			);
			this.sequencer = sequencer;
			this.parent_sequence = parent_sequence;
			this.sequence_priority = sequence_priority;
			this.sequence_call_pre_post = sequence_call_pre_post;
		endfunction : configure


		virtual task run_test();
			integer fd;
			integer code;
			line_value line_obj;
			int line_number;
			gherkin_doc_bundle gherkin_doc_bundle;
			gherkin_document_printer printer;
			gherkin_document_runner runner;

			foreach (feature_files[i]) begin
				
				`uvm_info(`get_scope_name(-2), {"Feature file: ", feature_files[i]}, UVM_LOW)

				start_file_parser(feature_files[i]);

				fd = $fopen(feature_files[i], "r");
				assert_fopen_succeeded : assert (fd != 0) else begin
					string ferror_msg;
					integer errno;

					errno = $ferror(fd, ferror_msg);
					`uvm_fatal(`get_scope_name(-2), ferror_msg)
				end

				line_number = 1;
				while (!$feof(fd)) begin
					string line_buf;

					code = $fgets(line_buf, fd);
					line_obj = new(line_buf, feature_files[i], line_number);
					line_number++;
					line_mbox.put(line_obj);
				end

				$fclose(fd);

				line_obj = new(.eof (1),
					.text (""),
					.file_name (feature_files[i])
				); // Special signal that file is done
				line_mbox.put(line_obj);

				gherkin_mbox.get(gherkin_doc_bundle);

				assert_gherkin_doc_is_not_null : assert (gherkin_doc_bundle.document);

				if (uvm_get_report_object().get_report_verbosity_level() >= UVM_HIGH) begin
					printer = gherkin_document_printer::create_new("printer", gherkin_doc_bundle.document);
					printer.print();
				end

				runner = gherkin_document_runner::create_new("runner", gherkin_doc_bundle.document);
				runner.configure(sequencer, parent_sequence, sequence_priority, sequence_call_pre_post, dry_run, starting_scenario_number, stopping_scenario_number);
				runner.run();

			end

		endtask : run_test


		virtual task start_file_parser(string file_name);
			fork
				parse_lines();
			join_none
		endtask : start_file_parser


		function void analyze_line(string line_buf, ref line_analysis_result_t result);
			int start_of_keyword;
			int first_space_after_keyword;
			int first_colon_after_keyword;
			byte c;
			static string secondary_strings[] = {"\"\"\"", "|", "@", "#"};

			start_of_keyword = -1;
			first_space_after_keyword = -1;
			first_colon_after_keyword = -1;

			line_buf = bathtub_utils::trim_white_space(line_buf);

			for (int i = 0; i < line_buf.len(); i++) begin
				c = line_buf[i];

				if (start_of_keyword == -1) begin
					if (!(c inside {" ", "\t", "\n"})) begin
						start_of_keyword = i;
					end
				end

				if (start_of_keyword != -1 && first_space_after_keyword == -1) begin
					if (c inside {" ", "\t", "\n"}) begin
						first_space_after_keyword = i;
					end
				end

				if (start_of_keyword != -1 && first_colon_after_keyword == -1) begin
					if (c == ":") begin
						first_colon_after_keyword = i;
					end
				end
			end

			result.token_before_space = bathtub_utils::trim_white_space(line_buf.substr(start_of_keyword, first_space_after_keyword - 1));
			result.token_before_colon = bathtub_utils::trim_white_space(line_buf.substr(start_of_keyword, first_colon_after_keyword - 1));
			result.remainder_after_space = bathtub_utils::trim_white_space(line_buf.substr(first_space_after_keyword + 1, line_buf.len() - 1));
			result.remainder_after_colon = bathtub_utils::trim_white_space(line_buf.substr(first_colon_after_keyword + 1, line_buf.len() - 1));

			result.secondary_keyword = "";
			result.remainder_after_secondary_keyword = "";

			foreach (secondary_strings[i]) begin
				int length = secondary_strings[i].len();
				string leading_string = line_buf.substr(0, length - 1);

				if (leading_string == secondary_strings[i]) begin
					result.secondary_keyword = leading_string;
					result.remainder_after_secondary_keyword = bathtub_utils::trim_white_space(line_buf.substr(length, line_buf.len() - 1));
					break;
				end
			end

		endfunction : analyze_line


		virtual task get_next_line(ref line_value line_obj);
			forever begin
				line_mbox.get(line_obj);

				if (line_obj.eof) begin
					return;
				end
				else begin
					$write("%s [%4d]: %s", line_obj.file_name, line_obj.line_number, line_obj.text);

					if (bathtub_utils::trim_white_space(line_obj.text) == "") begin
						// Ignore empty lines
						continue;
					end
					else begin
						return;
					end
				end
			end
		endtask : get_next_line


		virtual task split_table_row(ref string cell_values[$], input string line_buf);
			int start_pos;
			int end_pos;
			string cell_value;

			cell_values.delete();
			line_buf = bathtub_utils::trim_white_space(line_buf);

			assert_table_row_starts_with_separator : assert (line_buf[0] == "|") else
				`uvm_fatal(`get_scope_name(-2), $sformatf("%s\nTable row must start with \"|\" separator character", line_buf))

			assert_table_row_ends_with_separator : assert (line_buf[line_buf.len() - 1] == "|") else
				`uvm_fatal(`get_scope_name(-2), $sformatf("%s\nTable row must end with \"|\" separator character", line_buf))

			start_pos = -1;
			end_pos = -1;
			foreach (line_buf[i]) begin
				if (line_buf[i] == "|") begin
					end_pos = i - 1;
					if (start_pos > 0 && end_pos >= start_pos) begin
						cell_value = bathtub_utils::trim_white_space(line_buf.substr(start_pos, end_pos));
						cell_values.push_back(cell_value);
					end
					start_pos = i + 1;
				end
			end
		endtask : split_table_row


		virtual task parse_lines();
			line_value line_obj;
			line_analysis_result_t line_analysis_result;

			get_next_line(line_obj);

			forever begin : documents
				gherkin_pkg::gherkin_document gherkin_doc;
				gherkin_doc_bundle bundle;

				if (line_obj.eof) break;

				gherkin_doc = new("gherkin_doc");

				forever begin : document_elements

					if (line_obj.eof) break;

					analyze_line(line_obj.text, line_analysis_result);

					case (line_analysis_result.token_before_colon)

						"Feature" : begin : construct_feature
							gherkin_pkg::feature feature;
							string keyword;
							string name;
							bit can_receive_description = 1;

							keyword = line_analysis_result.token_before_colon;
							name = line_analysis_result.remainder_after_colon;
							feature = gherkin_pkg::feature::create_new(
								.name ("feature"),
								.keyword (keyword),
								.feature_name (name)
							);
							get_next_line(line_obj);

							forever begin : feature_elements

								if (line_obj.eof) break;

								analyze_line(line_obj.text, line_analysis_result);

								case (line_analysis_result.token_before_colon)

									"Background" : begin : construct_background
										gherkin_pkg::background background;
										string keyword;
										string name;
										bit can_receive_description = 1;
										bit can_receive_step = 1;

										keyword = line_analysis_result.token_before_colon;
										name = line_analysis_result.remainder_after_colon;
										background = gherkin_pkg::background::create_new(
											.name ("background"),
											.keyword (keyword),
											.scenario_definition_name(name),
											.description("")
										);
										get_next_line(line_obj);

										forever begin : background_elements

											if (line_obj.eof) break;

											analyze_line(line_obj.text, line_analysis_result);

											if (line_analysis_result.token_before_space inside {
														"Given",
														"When",
														"Then",
														"And",
														"But",
														"*"})  begin : construct_step
												gherkin_pkg::step step;
												string keyword;
												string text;

												keyword = line_analysis_result.token_before_space;
												text = line_analysis_result.remainder_after_space;
												step = gherkin_pkg::step::create_new(
													.name ("step"),
													.keyword (keyword),
													.text (text)
												);
												get_next_line(line_obj);

												forever begin : step_elements

													if (line_obj.eof) break;

													analyze_line(line_obj.text, line_analysis_result);

													case (line_analysis_result.secondary_keyword)
														"|" : begin : construct_data_table
															gherkin_pkg::data_table data_table;

															data_table = new("data_table");

															forever begin : data_table_elements

																if (line_obj.eof) break;

																analyze_line(line_obj.text, line_analysis_result);

																if (line_analysis_result.secondary_keyword == "|") begin
																	gherkin_pkg::table_row table_row;
																	string cell_values[$];

																	table_row = new("table_row");

																	split_table_row(cell_values, bathtub_utils::trim_white_space(line_obj.text));
																	foreach (cell_values[i]) begin
																		gherkin_pkg::table_cell table_cell;

																		table_cell = gherkin_pkg::table_cell::create_new(
																			.name ("table_cell"),
																			.value (cell_values[i])
																		);
																		table_row.cells.push_back(table_cell);
																	end
																	data_table.rows.push_back(table_row);
																	get_next_line(line_obj);
																end
																else begin
																	break;
																end
															end

															step.argument = data_table;
														end

														"\"\"\"" : begin : construct_doc_string
															$warning("Placeholder");
															get_next_line(line_obj);
														end

														default: begin
															break;
														end
													endcase

												end

												background.steps.push_back(step);

											end

											else if (line_analysis_result.token_before_colon inside {
														"Feature",
														"Rule",
														"Example",
														"Scenario",
														"Background",
														"Scenario Outline",
														"Scenario Template",
														"Examples",
														"Scenarios"}) begin : terminate_background
												// Any primary keyword terminates the background.
												break;
											end

											else begin

												case (line_analysis_result.secondary_keyword)
													"#" : begin : ignore_comment
														get_next_line(line_obj);
													end

													default : begin
														if (can_receive_description) begin : construct_description
															string description;
															description = {description, bathtub_utils::trim_white_space(line_obj.text), "\n"};
															get_next_line(line_obj);
															forever begin : description_elements
																if (line_obj.eof) break;
																analyze_line(line_obj.text, line_analysis_result);
																if (line_analysis_result.token_before_space inside {"Given", "When", "Then", "And", "But", "*"}) begin
																	break;
																end
																else begin
																	description = {description, bathtub_utils::trim_white_space(line_obj.text), "\n"};
																	get_next_line(line_obj);
																end
															end
															background.description = description;
															can_receive_description = 0;
														end
														else begin
															$error("Unexpected line");
															break;
														end
													end
												endcase
											end

										end

										feature.scenario_definitions.push_back(background);
									end

									"Scenario", "Example" : begin : construct_scenario
										gherkin_pkg::scenario scenario;
										string keyword;
										string name;
										bit can_receive_description = 1;
										bit can_receive_step = 1;

										keyword = line_analysis_result.token_before_colon;
										name = line_analysis_result.remainder_after_colon;
										scenario = gherkin_pkg::scenario::create_new(
											.name ("scenario"),
											.keyword (keyword),
											.scenario_definition_name(name),
											.description("")
										);
										get_next_line(line_obj);

										forever begin : scenario_elements

											if (line_obj.eof) break;

											analyze_line(line_obj.text, line_analysis_result);

											if (line_analysis_result.token_before_space inside {
														"Given",
														"When",
														"Then",
														"And",
														"But",
														"*"})  begin : construct_step
												gherkin_pkg::step step;
												string keyword;
												string text;

												keyword = line_analysis_result.token_before_space;
												text = line_analysis_result.remainder_after_space;
												step = gherkin_pkg::step::create_new(
													.name ("step"),
													.keyword (keyword),
													.text (text)
												);
												get_next_line(line_obj);

												forever begin : step_elements

													if (line_obj.eof) break;

													analyze_line(line_obj.text, line_analysis_result);

													case (line_analysis_result.secondary_keyword)
														"|" : begin : construct_data_table
															gherkin_pkg::data_table data_table;

															data_table = new("data_table");

															forever begin : data_table_elements

																if (line_obj.eof) break;

																analyze_line(line_obj.text, line_analysis_result);

																if (line_analysis_result.secondary_keyword == "|") begin
																	gherkin_pkg::table_row table_row;
																	string cell_values[$];

																	table_row = new("table_row");

																	split_table_row(cell_values, bathtub_utils::trim_white_space(line_obj.text));
																	foreach (cell_values[i]) begin
																		gherkin_pkg::table_cell table_cell;

																		table_cell = gherkin_pkg::table_cell::create_new(
																			.name ("table_cell"),
																			.value (cell_values[i])
																		);
																		table_row.cells.push_back(table_cell);
																	end
																	data_table.rows.push_back(table_row);
																	get_next_line(line_obj);
																end
																else begin
																	break;
																end
															end

															step.argument = data_table;
														end

														"\"\"\"" : begin : construct_doc_string
															$warning("Placeholder");
															get_next_line(line_obj);
														end

														default: begin
															break;
														end
													endcase

												end

												scenario.steps.push_back(step);

											end

											else if (line_analysis_result.token_before_colon inside {
														"Feature",
														"Rule",
														"Example",
														"Scenario",
														"Background",
														"Scenario Outline",
														"Scenario Template",
														"Examples",
														"Scenarios"}) begin : terminate_scenario
												// Any primary keyword terminates the scenario outline.
												break;
											end

											else begin

												case (line_analysis_result.secondary_keyword)
													"#" : begin : ignore_comment
														get_next_line(line_obj);
													end

													default : begin
														if (can_receive_description) begin : construct_description
															string description;
															description = {description, bathtub_utils::trim_white_space(line_obj.text), "\n"};
															get_next_line(line_obj);
															forever begin : description_elements
																if (line_obj.eof) break;
																analyze_line(line_obj.text, line_analysis_result);
																if (line_analysis_result.token_before_space inside {"Given", "When", "Then", "And", "But", "*"}) begin
																	break;
																end
																else begin
																	description = {description, bathtub_utils::trim_white_space(line_obj.text), "\n"};
																	get_next_line(line_obj);
																end
															end
															scenario.description = description;
															can_receive_description = 0;
														end
														else begin
															$error("Unexpected line");
															break;
														end
													end
												endcase
											end

										end

										feature.scenario_definitions.push_back(scenario);
									end

									"Scenario Outline", "Scenario Template" : begin : construct_scenario_outline
										gherkin_pkg::scenario_outline scenario_outline;
										string keyword;
										string name;
										bit can_receive_description = 1;
										bit can_receive_step = 1;

										keyword = line_analysis_result.token_before_colon;
										name = line_analysis_result.remainder_after_colon;
										scenario_outline = gherkin_pkg::scenario_outline::create_new(
											.name ("scenario_outline"),
											.keyword (keyword),
											.scenario_definition_name(name),
											.description("")
										);
										get_next_line(line_obj);

										forever begin : scenario_outline_elements

											if (line_obj.eof) break;

											analyze_line(line_obj.text, line_analysis_result);

											if (line_analysis_result.token_before_space inside {
														"Given",
														"When",
														"Then",
														"And",
														"But",
														"*"})  begin : construct_step
												gherkin_pkg::step step;
												string keyword;
												string text;

												keyword = line_analysis_result.token_before_space;
												text = line_analysis_result.remainder_after_space;
												step = gherkin_pkg::step::create_new(
													.name ("step"),
													.keyword (keyword),
													.text (text)
												);
												get_next_line(line_obj);

												forever begin : step_elements

													if (line_obj.eof) break;

													analyze_line(line_obj.text, line_analysis_result);

													case (line_analysis_result.secondary_keyword)
														"|" : begin : construct_data_table
															gherkin_pkg::data_table data_table;

															data_table = new("data_table");

															forever begin : data_table_elements

																if (line_obj.eof) break;

																analyze_line(line_obj.text, line_analysis_result);

																if (line_analysis_result.secondary_keyword == "|") begin
																	gherkin_pkg::table_row table_row;
																	string cell_values[$];

																	table_row = new("table_row");

																	split_table_row(cell_values, bathtub_utils::trim_white_space(line_obj.text));
																	foreach (cell_values[i]) begin
																		gherkin_pkg::table_cell table_cell;

																		table_cell = gherkin_pkg::table_cell::create_new(
																			.name ("table_cell"),
																			.value (cell_values[i])
																		);
																		table_row.cells.push_back(table_cell);
																	end
																	data_table.rows.push_back(table_row);
																	get_next_line(line_obj);
																end
																else begin
																	break;
																end
															end

															step.argument = data_table;
														end

														"\"\"\"" : begin : construct_doc_string
															$warning("Placeholder");
															get_next_line(line_obj);
														end

														default: begin
															break;
														end
													endcase

												end

												scenario_outline.steps.push_back(step);

											end

											else if (line_analysis_result.token_before_colon inside {"Examples", "Scenarios"}) begin : construct_examples
												gherkin_pkg::examples examples;
												string keyword;
												string name;

												keyword = line_analysis_result.token_before_colon;
												name = line_analysis_result.remainder_after_colon;
												examples = gherkin_pkg::examples::create_new(
													.name ("examples"),
													.keyword(keyword),
													.examples_name(name)
												);
												get_next_line(line_obj);

												forever begin : examples_elements

													if (line_obj.eof) break;

													analyze_line(line_obj.text, line_analysis_result);

													case (line_analysis_result.secondary_keyword)
														"|" : begin : construct_examples_header
															gherkin_pkg::table_row header;
															string cell_values[$];

															header = new("header");

															split_table_row(cell_values, bathtub_utils::trim_white_space(line_obj.text));
															foreach (cell_values[i]) begin
																gherkin_pkg::table_cell table_cell;

																table_cell = gherkin_pkg::table_cell::create_new(
																	.name ("table_cell"),
																	.value (cell_values[i])
																);
																header.cells.push_back(table_cell);
															end
															examples.header = header;
															get_next_line(line_obj);

															forever begin : examples_rows

																if (line_obj.eof) break;

																analyze_line(line_obj.text, line_analysis_result);

																if (line_analysis_result.secondary_keyword == "|") begin
																	gherkin_pkg::table_row table_row;
																	string cell_values[$];

																	table_row = new("table_row");

																	split_table_row(cell_values, bathtub_utils::trim_white_space(line_obj.text));
																	foreach (cell_values[i]) begin
																		gherkin_pkg::table_cell table_cell;

																		table_cell = gherkin_pkg::table_cell::create_new(
																			.name ("table_cell"),
																			.value (cell_values[i])
																		);
																		table_row.cells.push_back(table_cell);
																	end
																	examples.rows.push_back(table_row);
																	get_next_line(line_obj);
																end
																else begin
																	break;
																end
															end
														end

														default: begin
															break;
														end
													endcase

												end

												scenario_outline.examples.push_back(examples);
												can_receive_step = 0;
											end

											else if (line_analysis_result.token_before_colon inside {
														"Feature",
														"Rule",
														"Example",
														"Scenario",
														"Background",
														"Scenario Outline",
														"Scenario Template"}) begin : terminate_scenario_outline
												// Any other primary keyword terminates the scenario outline.
												break;
											end

											else begin

												case (line_analysis_result.secondary_keyword)
													"#" : begin : ignore_comment
														get_next_line(line_obj);
													end

													default : begin
														if (can_receive_description) begin : construct_description
															string description;
															description = {description, bathtub_utils::trim_white_space(line_obj.text), "\n"};
															get_next_line(line_obj);
															forever begin : description_elements
																if (line_obj.eof) break;
																analyze_line(line_obj.text, line_analysis_result);
																if (line_analysis_result.token_before_space inside {"Given", "When", "Then", "And", "But", "*"}) begin
																	break;
																end
																else begin
																	description = {description, bathtub_utils::trim_white_space(line_obj.text), "\n"};
																	get_next_line(line_obj);
																end
															end
															scenario_outline.description = description;
															can_receive_description = 0;
														end
														else begin
															$error("Unexpected line");
															break;
														end
													end
												endcase
											end

										end

										feature.scenario_definitions.push_back(scenario_outline);
									end

									default : begin
										if (can_receive_description) begin
											string description;
											description = {description, bathtub_utils::trim_white_space(line_obj.text), "\n"};
											get_next_line(line_obj);
											forever begin
												if (line_obj.eof) break;
												analyze_line(line_obj.text, line_analysis_result);
												if (line_analysis_result.token_before_colon inside {"Background", "Scenario", "Example", "Scenario Outline", "Scenario Template"}) begin
													break;
												end
												else begin
													description = {description, bathtub_utils::trim_white_space(line_obj.text), "\n"};
													get_next_line(line_obj);
												end
											end
											feature.description = description;
											can_receive_description = 0;
										end
										else begin
											break;
										end
									end

								endcase

							end

							gherkin_doc.feature = feature;

						end

					endcase

				end

				bundle = new(
					.document (gherkin_doc),
					.file_name (line_obj.file_name)
				);

				$display(); // Final new line if we are printing for debug
				gherkin_mbox.put(bundle);

			end

		endtask : parse_lines

	endclass : bathtub


	class gherkin_document_printer extends uvm_object implements gherkin_pkg::visitor;

		gherkin_pkg::gherkin_document document;

		`uvm_object_utils_begin(gherkin_document_printer)
			`uvm_field_object(document, UVM_ALL_ON)
		`uvm_object_utils_end


		function new(string name = "gherkin_document_printer");
			// TODO Auto-generated constructor stub
			super.new(name);

		endfunction : new


		static function gherkin_document_printer create_new(string name = "gherkin_document_printer", gherkin_pkg::gherkin_document document);
			gherkin_document_printer new_printer;

			new_printer = new(name);
			new_printer.document = document;
			return new_printer;
		endfunction : create_new


		virtual task print();
			document.accept(this);
		endtask : print

		/**
		 * @param background -
		 */
		virtual task visit_background(gherkin_pkg::background background);
			$display({1{"  "}}, background.keyword, ": ", background.scenario_definition_name);

			if (background.description.len() > 0) begin
				$write({2{"  "}});
				foreach (background.description[i]) begin
					byte c = background.description[i];

					$write(string'(c));
					if (c == "\n") begin
						$write({2{"  "}});
					end
				end
				$display();
			end

			foreach (background.steps[i]) begin
				background.steps[i].accept(this);
			end
			$display();

		endtask : visit_background

		/**
		 * @param comment -
		 */
		virtual task visit_comment(gherkin_pkg::comment comment);
		// TODO Auto-generated task stub

		endtask : visit_comment

		virtual task visit_data_table(gherkin_pkg::data_table data_table);
			foreach (data_table.rows[i]) begin
				data_table.rows[i].accept(this);
			end
		endtask : visit_data_table

		/**
		 * @param doc_string -
		 */
		virtual task visit_doc_string(gherkin_pkg::doc_string doc_string);
		// TODO Auto-generated task stub

		endtask : visit_doc_string

		virtual task visit_examples(gherkin_pkg::examples examples);
			$display({{2{"  "}}, examples.keyword, ": ", examples.examples_name});

			if (examples.description != "") begin
				$write({2{"  "}});
				foreach (examples.description[i]) begin
					byte c = examples.description[i];

					$write(string'(c));
					if (c == "\n") begin
						$write({2{"  "}});
					end
				end
				$display();
			end

			examples.header.accept(this);

			foreach (examples.rows[i]) begin
				examples.rows[i].accept(this);
			end
			$display();
			
		endtask : visit_examples

		/**
		 * @param feature -
		 */
		virtual task visit_feature(gherkin_pkg::feature feature);
			$display({"# language: ", feature.language});

			foreach (feature.tags[i]) begin
				feature.tags[i].accept(this);
			end

			$display(feature.keyword, ": ", feature.feature_name);

			$write({1{"  "}});
			foreach (feature.description[i]) begin
				byte c = feature.description[i];

				$write(string'(c));
				if (c == "\n") begin
					$write({1{"  "}});
				end
			end
			$display();

			foreach(feature.scenario_definitions[i]) begin
				feature.scenario_definitions[i].accept(this);
			end
		endtask : visit_feature

		virtual task visit_gherkin_document(gherkin_pkg::gherkin_document gherkin_document);
			foreach (gherkin_document.comments[i]) begin
				gherkin_document.comments[i].accept(this);
			end

			gherkin_document.feature.accept(this);

		endtask : visit_gherkin_document

		virtual task visit_scenario(gherkin_pkg::scenario scenario);
			foreach (scenario.tags[i]) begin
				scenario.tags[i].accept(this);
			end

			$display({1{"  "}}, scenario.keyword, ": ", scenario.scenario_definition_name);

			$write({2{"  "}});
			foreach (scenario.description[i]) begin
				byte c = scenario.description[i];

				$write(string'(c));
				if (c == "\n") begin
					$write({2{"  "}});
				end
			end
			$display();

			foreach (scenario.steps[i]) begin
				scenario.steps[i].accept(this);
			end
			$display();
			
		endtask : visit_scenario

		virtual task visit_scenario_definition(gherkin_pkg::scenario_definition scenario_definition);
			gherkin_pkg::background background;
			gherkin_pkg::scenario_outline scenario_outline;
			gherkin_pkg::scenario scenario;

			if ($cast(background, scenario_definition)) background.accept(this);
			else if ($cast(scenario_outline, scenario_definition)) scenario_outline.accept(this);
			else if ($cast(scenario, scenario_definition)) scenario.accept(this);
			else `uvm_fatal(`get_scope_name(), {"Unknown scenario_definition: ", scenario_definition.get_type_name()})
		endtask : visit_scenario_definition

		virtual task visit_scenario_outline(gherkin_pkg::scenario_outline scenario_outline);
			foreach (scenario_outline.tags[i]) begin
				scenario_outline.tags[i].accept(this);
			end

			$display({1{"  "}}, scenario_outline.keyword, ": ", scenario_outline.scenario_definition_name);

			$write({2{"  "}});
			foreach (scenario_outline.description[i]) begin
				byte c = scenario_outline.description[i];

				$write(string'(c));
				if (c == "\n") begin
					$write({2{"  "}});
				end
			end
			$display();

			foreach (scenario_outline.steps[i]) begin
				scenario_outline.steps[i].accept(this);
			end
			$display();

			foreach (scenario_outline.examples[i]) begin
				scenario_outline.examples[i].accept(this);
			end

		endtask : visit_scenario_outline

		virtual task visit_step(gherkin_pkg::step step);
			$display({2{"  "}}, step.keyword, " ", step.text);
			if (step.argument != null) begin
				step.argument.accept(this);
			end
		endtask : visit_step

		virtual task visit_step_argument(gherkin_pkg::step_argument step_argument);
			gherkin_pkg::data_table data_table;
			gherkin_pkg::doc_string doc_string;

			if ($cast(data_table, step_argument)) data_table.accept(this);
			else if ($cast(doc_string, step_argument)) doc_string.accept(this);
			else `uvm_fatal(`get_scope_name(), {"Unknown step_argument: ", step_argument.get_type_name()})
		endtask : visit_step_argument

		virtual task visit_table_cell(gherkin_pkg::table_cell table_cell);
			$write({" ", table_cell.value, " |"});
		endtask : visit_table_cell

		virtual task visit_table_row(gherkin_pkg::table_row table_row);
			$write({{2{"  "}}, "|"});
			foreach (table_row.cells[i]) begin
				table_row.cells[i].accept(this);
			end
			$display();
		endtask : visit_table_row

		/**
		 * @param tag -
		 */
		virtual task visit_tag(gherkin_pkg::tag tag);
		// TODO Auto-generated task stub

		endtask : visit_tag

	endclass : gherkin_document_printer

	class gherkin_document_runner extends uvm_object implements gherkin_pkg::visitor;

		gherkin_pkg::gherkin_document document;
		gherkin_pkg::background feature_background;

		uvm_sequencer_base sequencer;
		uvm_sequence_base parent_sequence;
		int sequence_priority;
		bit sequence_call_pre_post;
		string example_values[string];
		string current_step_keyword;
		bit dry_run;
		int starting_scenario_number;
		int stopping_scenario_number;

		`uvm_object_utils_begin(gherkin_document_runner)
			`uvm_field_object(document, UVM_ALL_ON)
			`uvm_field_int(dry_run, UVM_ALL_ON)
			`uvm_field_int(starting_scenario_number, UVM_ALL_ON | UVM_DEC)
			`uvm_field_int(stopping_scenario_number, UVM_ALL_ON | UVM_DEC)
		`uvm_object_utils_end

		function new(string name = "gherkin_document_runner");
			super.new(name);

			current_step_keyword = "Given";
			feature_background = null;
			starting_scenario_number = 0;
			stopping_scenario_number = 0;
		endfunction : new


		static function gherkin_document_runner create_new(string name = "gherkin_document_runner", gherkin_pkg::gherkin_document document);
			gherkin_document_runner new_printer;

			new_printer = new(name);
			new_printer.document = document;
			return new_printer;
		endfunction : create_new


		virtual function void configure(
				uvm_sequencer_base sequencer,
				uvm_sequence_base parent_sequence = null,
				int sequence_priority = -1,
				bit sequence_call_pre_post = 1,
				bit dry_run = 0,
				int starting_scenario_number = 0,
				int stopping_scenario_number = 0
			);
			this.sequencer = sequencer;
			this.parent_sequence = parent_sequence;
			this.sequence_priority = sequence_priority;
			this.sequence_call_pre_post = sequence_call_pre_post;
			this.dry_run = dry_run;
			this.starting_scenario_number = starting_scenario_number;
			this.stopping_scenario_number = stopping_scenario_number;
		endfunction : configure


		virtual task run();
			`uvm_info(get_name(), {"\n", sprint()}, UVM_MEDIUM)
			document.accept(this);
		endtask : run

		/*
		 * Function: start_step
		 * Executes a sequence passed as Gherkin step.
		 *
		 * Parameters:
		 * wrap - A sequence or sequence item's type as returned by its get_type() method
		 */
		virtual task start_step(gherkin_pkg::step step);

			uvm_object obj;
			uvm_factory factory;
			uvm_sequence_base seq;
			uvm_resource_db#(uvm_object_wrapper)::rsrc_t step_resource;
			uvm_object_wrapper step_seq_object_wrapper;
			step_definition_interface step_seq;
			int success;
			string search_keyword;

			`uvm_info(`get_scope_name(), $sformatf("%s %s", step.keyword, step.text), UVM_MEDIUM)

			if (step.keyword inside {"Given", "When", "Then"}) begin
				// Look for a simple exact match for keyword.
				search_keyword = step.keyword;
			end
			else if (step.keyword inside {"And", "But", "*"}) begin
				// Keyword is syntactic sugar so throw it out and look for the current keyword again.
				search_keyword = current_step_keyword;
			end
			else begin
				`uvm_fatal(get_name(), $sformatf("Illegal step keyword: '%s'", step.keyword))
			end

			`uvm_info_begin(get_name(), "uvm_resource_db search parameters", UVM_HIGH)
			`uvm_message_add_string(step.text)
			`uvm_message_add_string(search_keyword)
			`uvm_info_end

			step_resource = uvm_resource_db#(uvm_object_wrapper)::get_by_name(step.text, search_keyword, 1);

			assert_step_resource_is_not_null : assert (step_resource) else begin
				if (uvm_get_report_object().get_report_verbosity_level() >= UVM_HIGH) begin
					uvm_resource_db#(uvm_object_wrapper)::dump();
				end
				`uvm_fatal(`get_scope_name(), $sformatf("No match for this step found in `uvm_resource_db`:\n> %s %s", search_keyword, step.text))
			end

			// Success. Update current keyword.
			current_step_keyword = search_keyword;

			step_seq_object_wrapper = step_resource.read();

			factory = uvm_factory::get();

			obj = factory.create_object_by_type(step_seq_object_wrapper, get_full_name(), step_seq_object_wrapper.get_type_name());

			success = $cast(seq ,obj);
			assert_step_object_is_sequence : assert (success) else begin
				`uvm_fatal(`get_scope_name(), $sformatf("Matched an object in `uvm_resource_db` that is not a sequence."))
			end

			if ($cast(step_seq, obj)) begin
				step_nurture step_attributes = step_nurture::type_id::create("step_attributes");
				step_attributes.set_runtime_keyword(step.keyword);
				step_attributes.set_text(step.text);
				step_attributes.set_argument(step.argument);
				step_attributes.set_static_attributes(step_seq.get_step_static_attributes());
				step_seq.set_step_attributes(step_attributes);
			end
			else begin
				`uvm_fatal(`get_scope_name(), $sformatf("Matched an object in `uvm_resource_db` that is not a valid step sequence."))
			end

			`uvm_info(get_name(), {"Executing sequence ", seq.get_name(),
					" (", seq.get_type_name(), ")"}, UVM_HIGH)

			seq.print_sequence_info = 1;
			if (!dry_run) begin
				seq.start(this.sequencer, this.parent_sequence, this.sequence_priority, this.sequence_call_pre_post);
			end

		endtask : start_step

		virtual task visit_background(gherkin_pkg::background background);

			`uvm_info(get_name(), $sformatf("%s: %s", background.keyword, background.scenario_definition_name), UVM_MEDIUM)

			foreach (background.steps[i]) begin
				background.steps[i].accept(this);
			end

		endtask : visit_background

		/**
		 * @param comment -
		 */
		virtual task visit_comment(gherkin_pkg::comment comment);
		// TODO Auto-generated task stub

		endtask : visit_comment

		/**
		 * @param data_table -
		 */
		virtual task visit_data_table(gherkin_pkg::data_table data_table);
		// TODO Auto-generated task stub

		endtask : visit_data_table

		/**
		 * @param doc_string -
		 */
		virtual task visit_doc_string(gherkin_pkg::doc_string doc_string);
		// TODO Auto-generated task stub

		endtask : visit_doc_string

		/**
		 * @param examples -
		 */
		virtual task visit_examples(gherkin_pkg::examples examples);
		// TODO Auto-generated task stub

		endtask : visit_examples

		virtual task visit_feature(gherkin_pkg::feature feature);
			gherkin_pkg::background feature_background;
			int start;
			int stop;
			gherkin_pkg::scenario_definition only_scenarios[$];

			`uvm_info(get_name(), $sformatf("%s: %s", feature.keyword, feature.feature_name), UVM_MEDIUM);
			
			// Separate background from scenario definitions
			only_scenarios.delete();
			foreach (feature.scenario_definitions[i]) begin
				if ($cast(feature_background, feature.scenario_definitions[i])) begin
					assert_only_one_background : assert (this.feature_background == null) else
						`uvm_fatal_begin(get_name(), "Found more than one background definition")
						`uvm_message_add_string(this.feature_background.scenario_definition_name, "Existing background")
						`uvm_message_add_string(feature_background.scenario_definition_name, "Conflicting background")
						`uvm_fatal_end
					this.feature_background = feature_background;
				end
				else begin
					only_scenarios.push_back(feature.scenario_definitions[i]);
				end
			end
			
			start = this.starting_scenario_number;
			stop = this.stopping_scenario_number;
			while (start < 0) start += only_scenarios.size();
			if (start > only_scenarios.size()) start = only_scenarios.size();
			while (stop <= 0) stop += only_scenarios.size();
			if (stop > only_scenarios.size()) stop = only_scenarios.size();
				
			for(int i = start; i < stop; i++) begin
				only_scenarios[i].accept(this);
			end

		endtask : visit_feature

		virtual task visit_gherkin_document(gherkin_pkg::gherkin_document gherkin_document);
			if (gherkin_document.feature) begin
				gherkin_document.feature.accept(this);
			end
		endtask : visit_gherkin_document

		virtual task visit_scenario(gherkin_pkg::scenario scenario);

			`uvm_info(get_name(), $sformatf("%s: %s", scenario.keyword, scenario.scenario_definition_name), UVM_MEDIUM)

			if (this.feature_background != null) begin
				this.feature_background.accept(this);
			end

			foreach (scenario.steps[i]) begin
				scenario.steps[i].accept(this);
			end

		endtask : visit_scenario

		virtual task visit_scenario_definition(gherkin_pkg::scenario_definition scenario_definition);
			gherkin_pkg::background background;
			gherkin_pkg::scenario_outline scenario_outline;
			gherkin_pkg::scenario scenario;

			// Reset current keyword to default "Given" in case first step is "And" or "But".
			current_step_keyword = "Given";
			if ($cast(background, scenario_definition)) background.accept(this);
			else if ($cast(scenario_outline, scenario_definition)) scenario_outline.accept(this);
			else if ($cast(scenario, scenario_definition)) scenario.accept(this);
			else `uvm_fatal(`get_scope_name(), {"Unknown scenario_definition: ", scenario_definition.get_type_name()})
		endtask : visit_scenario_definition

		virtual task visit_scenario_outline(gherkin_pkg::scenario_outline scenario_outline);

			`uvm_info(get_name(), $sformatf("%s: %s", scenario_outline.keyword, scenario_outline.scenario_definition_name), UVM_MEDIUM)

			foreach (scenario_outline.examples[k]) begin

				foreach (scenario_outline.examples[k].rows[j]) begin
				
					`uvm_info(get_name(), $sformatf("Example #%0d:", j + 1), UVM_MEDIUM)

					example_values.delete();

					// Store the example values in a hash.
					// Put the "<" ears ">" on the key.
					foreach (scenario_outline.examples[k].rows[j].cells[i]) begin
						example_values[{"<", scenario_outline.examples[k].header.cells[i].value, ">"}] = scenario_outline.examples[k].rows[j].cells[i].value;
					end
					
					if (this.feature_background != null) begin
						this.feature_background.accept(this);
					end

					foreach (scenario_outline.steps[i]) begin
						scenario_outline.steps[i].accept(this);
					end

					example_values.delete();

				end

			end

		endtask : visit_scenario_outline


		static function string replace_string(string str, string search, string repl);
			int str_len = str.len();
			int search_len = search.len();
			int i;

			assert_search_string_not_empty : assert (search != "") else
				$fatal(1, "Search string is empty");

			replace_string = "";
			i = 0;
			while (i < str_len) begin
				if (str.substr(i, i + search_len - 1) == search) begin
					replace_string = {replace_string, repl};
					i += search_len;
				end
				else begin
					replace_string = {replace_string, str[i]};
					i++;
				end
			end
		endfunction : replace_string


		virtual task visit_step(gherkin_pkg::step step);
			string example_parameter;
			string replaced_text = step.text;
			gherkin_pkg::step replaced_step;
			gherkin_pkg::data_table data_table;
			gherkin_pkg::doc_string doc_string;
			gherkin_pkg::doc_string replaced_doc_string;

			`uvm_info(get_name(), $sformatf("Before replacement: %s %s", step.keyword, step.text), UVM_HIGH)

			if (example_values.first(example_parameter)) do
					replaced_text = replace_string(replaced_text, example_parameter, example_values[example_parameter]);
				while (example_values.next(example_parameter));

			replaced_step = gherkin_pkg::step::create_new("replaced_step", step.keyword, replaced_text);

			if (step.argument) begin

				if ($cast(data_table, step.argument)) begin
					gherkin_pkg::data_table replaced_data_table;

					replaced_data_table = new("replaced_data_table");

					foreach (data_table.rows[row]) begin
						gherkin_pkg::table_row replaced_table_row;

						replaced_table_row =new("replaced_table_row");
						foreach (data_table.rows[row].cells[col]) begin
							string replaced_cell_value = data_table.rows[row].cells[col].value;

							if (example_values.first(example_parameter)) do
									replaced_cell_value = replace_string(replaced_cell_value, example_parameter, example_values[example_parameter]);
								while (example_values.next(example_parameter));

							replaced_table_row.cells.push_back(gherkin_pkg::table_cell::create_new("anonymous", replaced_cell_value));

						end

						replaced_data_table.rows.push_back(replaced_table_row);

					end

					replaced_step.argument = replaced_data_table;

				end
				else if ($cast(doc_string, step.argument)) begin
				end
				else
					`uvm_fatal(get_name(), "Unexpected type of step argument")
			end


			`uvm_info(get_name(), $sformatf("%s %s", replaced_step.keyword, replaced_step.text), UVM_MEDIUM)
			start_step(replaced_step);
		endtask : visit_step

		/**
		 * @param step_argument -
		 */
		virtual task visit_step_argument(gherkin_pkg::step_argument step_argument);
		// TODO Auto-generated task stub

		endtask : visit_step_argument

		/**
		 * @param table_cell -
		 */
		virtual task visit_table_cell(gherkin_pkg::table_cell table_cell);
		// TODO Auto-generated task stub

		endtask : visit_table_cell

		/**
		 * @param table_row -
		 */
		virtual task visit_table_row(gherkin_pkg::table_row table_row);
		// TODO Auto-generated task stub

		endtask : visit_table_row

		/**
		 * @param tag -
		 */
		virtual task visit_tag(gherkin_pkg::tag tag);
		// TODO Auto-generated task stub

		endtask : visit_tag



	endclass : gherkin_document_runner

endpackage : bathtub_pkg
