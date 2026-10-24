--!nocheck
-- Bounded, plain JSON-shaped data. No services and no codec coercion.
local Data = {}
function Data.copy(value)
	local active, nodes = {}, 0
	local function visit(v, depth)
		nodes += 1
		assert(nodes <= 100000 and depth <= 48, "DATA_COMPLEXITY")
		local t = type(v)
		if t == "string" then assert(utf8.len(v) ~= nil, "INVALID_UTF8"); return v end
		if t == "number" then assert(v == v and math.abs(v) < math.huge, "NON_FINITE"); return if v == 0 then 0 else v end
		if t == "boolean" then return v end
		assert(t == "table" and getmetatable(v) == nil and not active[v], "INVALID_DATA")
		active[v] = true
		local out, count, largest, array = {}, 0, 0, nil
		for k, child in v do
			local numeric = type(k) == "number"
			assert(type(k) == "string" or (numeric and k >= 1 and k % 1 == 0), "INVALID_KEY")
			if type(k) == "string" then assert(utf8.len(k) ~= nil, "INVALID_UTF8") end
			assert(array == nil or array == numeric, "MIXED_TABLE")
			array = numeric; count += 1
			if numeric then largest = math.max(largest, k) end
			out[k] = visit(child, depth + 1)
		end
		assert(not array or count == largest, "SPARSE_ARRAY")
		active[v] = nil
		return out
	end
	return visit(value, 0)
end
function Data.fingerprint(value)
	local plain = Data.copy(value)
	local function encode(v)
		if type(v) == "string" then return "s" .. #v .. ":" .. v end
		if type(v) == "number" then return "n" .. string.format("%.17g", v) .. ";" end
		if type(v) == "boolean" then return if v then "t" else "f" end
		local keys = {}
		for k in v do table.insert(keys, k) end
		table.sort(keys, function(a,b) return a < b end)
		local result = { "{" }
		for _, k in keys do table.insert(result, encode(k)); table.insert(result, encode(v[k])) end
		table.insert(result, "}")
		return table.concat(result)
	end
	return encode(plain)
end
return table.freeze(Data)
