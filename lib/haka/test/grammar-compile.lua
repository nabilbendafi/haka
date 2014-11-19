-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

TestGrammarCompilation = {}

function TestGrammarCompilation:setUp()
	os.remove("test_grammar.c")
	os.remove("test_grammar.so")
	package.loaded.test_grammar = nil
end

function TestGrammarCompilation:test_new_grammar_create_c_file()
	-- Given
	os.remove("test_grammar.c")
	local grammar = function ()
		elem = record{
			field("num", number(8)),
		}:apply(function (value)
			value.ok = true
		end)

		export(elem)
	end

	-- When
	haka.grammar.new("test", grammar, true)

	-- Then
	local f = assert(io.open("test_grammar.c", "r"))
	local line = f:read("*line")
	assertEquals(line, "/** File automatically generated by Haka. DO NOT EDIT */")
end

function TestGrammarCompilation:test_new_grammar_create_so_module()
	-- Given
	os.remove("test_grammar.so")
	local grammar = function ()
		elem = record{
			field("num", number(8)),
		}:apply(function (value)
			value.ok = true
		end)

		export(elem)
	end

	-- When
	haka.grammar.new("test", grammar, true)

	-- Then
	assert(io.open("test_grammar.so", "r"))
end

function TestGrammarCompilation:test_new_grammar_create_multiple_parsers()
	-- Given
	os.remove("test_grammar.so")
	local grammar = function ()
		foo = record{
			field("num", number(8)),
		}

		bar = record{
			field("num", number(8)),
		}

		export(foo)
		export(bar)
	end

	-- When
	local grammar = haka.grammar.new("test", grammar, true)

	-- Then
	assert(grammar.foo)
	assert(grammar.bar)
end

function TestGrammarCompilation:test_apply_on_record()
	-- Given
	local buf = haka.vbuffer_from("\x42")
	local grammar = haka.grammar.new("test", function ()
		elem = record{
			field("num", number(8)),
		}
		export(elem)
	end, true)

	-- When
	local result = grammar.elem:parse(buf:pos('begin'))

	assertEquals(result.num, 0x42)
end

function TestGrammarCompilation:test_apply_on_sequence()
	-- Given
	local buf = haka.vbuffer_from("\x42\x43")
	local grammar = haka.grammar.new("test", function ()
		elem = sequence{
			number(8),
			record{
				field("num", number(8)),
			},
		}
		export(elem)
	end, true)

	-- When
	local result = grammar.elem:parse(buf:pos('begin'))

	assertEquals(result.num, 0x43)
end

function TestGrammarCompilation:test_apply_on_union()
	-- Given
	local buf = haka.vbuffer_from("\x42")
	local grammar = haka.grammar.new("test", function ()
		elem = union{
			field("foo", number(4)),
			field("bar", number(8)),
		}
		export(elem)
	end, true)

	-- When
	local result = grammar.elem:parse(buf:pos('begin'))

	assertEquals(result.foo, 0x4)
	assertEquals(result.bar, 0x42)
end

addTestSuite('TestGrammarCompilation')