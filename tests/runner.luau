local Runner = {}

local tests = {}

local function formatValue(value)
	if type(value) == "table" then
		local parts = {}
		for key, nested in pairs(value) do
			table.insert(parts, tostring(key) .. "=" .. formatValue(nested))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function deepEqual(left, right)
	if left == right then
		return true
	end
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end
	for key, value in pairs(left) do
		if not deepEqual(value, right[key]) then
			return false
		end
	end
	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end
	return true
end

function Runner.test(name, fn)
	table.insert(tests, { name = name, fn = fn })
end

function Runner.expect(condition, message)
	if not condition then
		error(message or "expectation failed", 2)
	end
end

function Runner.expectEqual(actual, expected, message)
	if actual ~= expected then
		error((message or "values are not equal") .. ": expected " .. formatValue(expected) .. ", got " .. formatValue(actual), 2)
	end
end

function Runner.expectDeepEqual(actual, expected, message)
	if not deepEqual(actual, expected) then
		error((message or "tables are not equal") .. ": expected " .. formatValue(expected) .. ", got " .. formatValue(actual), 2)
	end
end

function Runner.expectDeepNotEqual(actual, expected, message)
	if deepEqual(actual, expected) then
		error((message or "tables should differ") .. ": both were " .. formatValue(actual), 2)
	end
end

function Runner.run()
	local failed = 0
	for _, case in ipairs(tests) do
		local ok, err = pcall(case.fn)
		if ok then
			print("✓ " .. case.name)
		else
			failed += 1
			print("✗ " .. case.name .. "\n" .. tostring(err))
		end
	end

	if failed > 0 then
		error(tostring(failed) .. " test(s) failed", 0)
	end

	print("All " .. tostring(#tests) .. " tests passed")
end

return Runner
