--!nocheck
-- Local Lune runner; imports the same service-free module mapped by Rojo.
local C = require("../../src/shared/NumericCodec")
local V = require("./reference_vectors")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local asserts = 0

local function equal(actual, expected, context)
	asserts += 1
	assert(actual == expected, (context or "") .. " expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function rejects(code, callback)
	local ok, err = pcall(callback)
	equal(ok, false, code .. " should reject")
	asserts += 1
	assert(string.find(tostring(err), "NumericCodec/" .. code, 1, true), tostring(err))
end
local function hex(value)
	local bytes = buffer.create(8)
	buffer.writef64(bytes, 0, value)
	local parts = {}
	for i = 0, 7 do table.insert(parts, string.format("%02x", buffer.readu8(bytes, i))) end
	return table.concat(parts)
end
local function fromHex(text)
	local bytes = buffer.create(8)
	for i = 0, 7 do buffer.writeu8(bytes, i, tonumber(string.sub(text, i * 2 + 1, i * 2 + 2), 16)) end
	return buffer.readf64(bytes, 0)
end
local U, R, A = C.ExactUInt, C.Real64, C.BigAmount
equal(C.VERSION, 1)
for _, v in V.floats do
	local input = fromHex(v[1])
	local expectedBits = if input == 0 then "0000000000000000" else v[1]
	equal(hex(R.decode(v[2])), expectedBits, "independent decimal " .. v[2])
	equal(hex(R.decode(R.encode(input))), expectedBits, "round-trip " .. v[1])
	if input >= 0 then equal(hex(A.decode(A.encode(input))), expectedBits, "amount") end
end
for _, v in V.integers do
	local n = U.decode(v[1])
	equal(n.hi, v[2]); equal(n.lo, v[3]); equal(U.encode(n), v[1])
	equal(U.encode(U.fromParts(v[2], v[3])), v[1])
	local rounded, exact = U.toReal64Rounded(n)
	equal(hex(rounded), v[4], "uint64 rounded " .. v[1]); equal(exact, v[5])
	if v[6] then
		equal(U.encode(U.fromSafeNumber(U.toSafeNumber(n))), v[1])
	else rejects("UNSAFE_INTEGER", function() U.toSafeNumber(n) end) end
end
for _, v in V.pairs do
	local a, b = U.decode(v[1]), U.decode(v[2])
	equal(U.compare(a, b), v[5])
	if v[3] then equal(U.encode(U.add(a, b)), v[3])
	else rejects("UINT64_OVERFLOW", function() U.add(a, b) end) end
	if v[4] then equal(U.encode(U.subtract(a, b)), v[4])
	else rejects("UINT64_UNDERFLOW", function() U.subtract(a, b) end) end
	equal(U.encode(a), v[1], "left input unchanged")
	equal(U.encode(b), v[2], "right input unchanged")
end
for _, text in { "", " 1", "1 ", "+1", "--1", ".", "1e", "1e+", "1e1e2", "0x10", "nan", "inf", "1,5", "1_0", "1\000" } do
	rejects("INVALID_DECIMAL", function() R.decode(text) end)
end
for _, text in { "", "00", "01", "+1", "-1", "1.0", "1e3", " 1", "1 ", "１２", string.rep("1", 21) } do
	rejects("INVALID_UINT64_TEXT", function() U.decode(text) end)
end
rejects("UINT64_OVERFLOW", function() U.decode("18446744073709551616") end)
for _, value in { math.huge, -math.huge, 0/0 } do
	rejects("NON_FINITE", function() R.encode(value) end)
end
rejects("INVALID_NUMBER", function() R.validate("1") end)
rejects("NON_FINITE", function() R.decode("1e309") end)
rejects("DECIMAL_UNDERFLOW", function() R.decode("1e-999") end)
rejects("DECIMAL_UNDERFLOW", function() R.decode("-1e-999") end)
equal(R.decode("0e-999"), 0)
equal(R.encode(-1 / math.huge), "0")
equal(hex(R.decode("-0")), "0000000000000000")
rejects("NEGATIVE_AMOUNT", function() A.decode("-0.01") end)
rejects("NEGATIVE_AMOUNT", function() A.encode(-1) end)
rejects("UNSAFE_INTEGER", function() U.fromSafeNumber(9007199254740992) end)
rejects("UNSAFE_INTEGER", function() U.fromSafeNumber(0.5) end)
rejects("INVALID_UINT32", function() U.fromParts(4294967296, 0) end)
rejects("INVALID_UINT32", function() U.fromParts(0, -1) end)
rejects("INVALID_UINT64", function() U.encode(setmetatable({ hi = 0, lo = 1 }, {})) end)
rejects("INVALID_UINT32", function() U.encode({ hi = 0, lo = math.huge }) end)
equal(table.isfrozen(U.decode("1")), true)
equal(table.isfrozen(C), true)
equal(hex(U.fromParts(-1 / math.huge, -1 / math.huge).hi), "0000000000000000")
equal(hex(U.fromParts(-1 / math.huge, -1 / math.huge).lo), "0000000000000000")
rejects("INVALID_UINT32", function() U.fromParts(0.5, 0) end)
rejects("INVALID_UINT32", function() U.fromParts(0, 0/0) end)
rejects("INVALID_DECIMAL", function() R.decode(string.rep("1", 65)) end)
equal(A.add(1, 2), 3); equal(A.subtract(3, 2), 1)
equal(A.multiply(3, 2), 6); equal(A.divide(3, 2), 1.5)
equal(R.add(-1, 2), 1); equal(R.subtract(1, 2), -1)
equal(R.multiply(-2, 3), -6); equal(R.divide(-3, 2), -1.5)
rejects("DIVISION_BY_ZERO", function() R.divide(1, 0) end)
rejects("INSUFFICIENT_AMOUNT", function() A.subtract(1, 2) end)
rejects("NON_FINITE", function() A.multiply(1e308, 2) end)
rejects("ARITHMETIC_UNDERFLOW", function() R.multiply(1e-300, 1e-300) end)
rejects("ARITHMETIC_UNDERFLOW", function() R.divide(1e-300, 1e300) end)
-- Explicit contract behavior: smaller-than-ULP debit is binary64, not exact currency.
equal(A.subtract(1e20, 1), 1e20)
equal(A.add(1e20, 1), 1e20)
equal(R.roundFloat32(0.1), 0.10000000149011612)
equal(R.roundFloat32(1e-100), 0)
rejects("NON_FINITE", function() R.roundFloat32(1e100) end)

local result = {
	status = "PASS", level = "L", codecVersion = C.VERSION,
	assertions = asserts, floatVectors = #V.floats,
	uint64Vectors = #V.integers, arithmeticPairs = #V.pairs,
	studioTested = false, dataStoreTested = false,
}
fs.writeFile("build/numeric-results.json", serde.encode("json", result, true))
print(serde.encode("json", result))
