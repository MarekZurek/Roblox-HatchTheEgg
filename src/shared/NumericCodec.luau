--!strict
-- Codec v1: finite binary64 and exact uint64. No services, state, UI or economics.
local NumericCodec = { VERSION = 1 }
local BASE = 4294967296
local WORD_MAX = BASE - 1
local SAFE_MAX = 9007199254740991

export type UInt64 = { hi: number, lo: number }

local function fail(code: string): never
	error("NumericCodec/" .. code, 3)
end

local function finite(value: any): number
	if type(value) ~= "number" then fail("INVALID_NUMBER") end
	if value ~= value or value == math.huge or value == -math.huge then fail("NON_FINITE") end
	-- All zero results are +0, including a decoded -0.
	return if value == 0 then 0 else value
end

local function nonnegative(value: any): number
	local n = finite(value)
	if n < 0 then fail("NEGATIVE_AMOUNT") end
	return n
end

local function encodeReal(value: number): string
	return string.format("%.17g", finite(value))
end

local function decodeReal(text: string): number
	if type(text) ~= "string" or #text == 0 or #text > 64 then fail("INVALID_DECIMAL") end
	local mantissa = text
	local exponentAt = string.find(text, "[eE]")
	if exponentAt then
		mantissa = string.sub(text, 1, exponentAt - 1)
		local exponent = string.sub(text, exponentAt + 1)
		if not string.match(exponent, "^[+-]?[0-9]+$") then fail("INVALID_DECIMAL") end
	end
	if not string.match(mantissa, "^-?[0-9]+%.?[0-9]*$")
		and not string.match(mantissa, "^-?[0-9]*%.[0-9]+$") then
		fail("INVALID_DECIMAL")
	end
	local parsed = tonumber(text)
	if parsed == nil then fail("INVALID_DECIMAL") end
	local value = finite(parsed)
	if value == 0 and string.find(mantissa, "[1-9]") then fail("DECIMAL_UNDERFLOW") end
	return value
end

local function checkedResult(value: number, nonzeroProduct: boolean?): number
	local result = finite(value)
	if nonzeroProduct and result == 0 then fail("ARITHMETIC_UNDERFLOW") end
	return result
end

local Real64 = {}
Real64.validate = finite
Real64.encode = encodeReal
Real64.decode = decodeReal
function Real64.add(a: number, b: number): number
	return checkedResult(finite(a) + finite(b))
end
function Real64.subtract(a: number, b: number): number
	return checkedResult(finite(a) - finite(b))
end
function Real64.multiply(a: number, b: number): number
	a, b = finite(a), finite(b)
	return checkedResult(a * b, a ~= 0 and b ~= 0)
end
function Real64.divide(a: number, b: number): number
	a, b = finite(a), finite(b)
	if b == 0 then fail("DIVISION_BY_ZERO") end
	return checkedResult(a / b, a ~= 0)
end
function Real64.roundFloat32(value: number): number
	-- Explicit IEEE-754 conversion; float32 rounding (including tiny -> zero) is intentional.
	local bytes = buffer.create(4)
	buffer.writef32(bytes, 0, finite(value))
	return finite(buffer.readf32(bytes, 0))
end

local BigAmount = {}
BigAmount.validate = nonnegative
function BigAmount.encode(value: number): string return encodeReal(nonnegative(value)) end
function BigAmount.decode(text: string): number return nonnegative(decodeReal(text)) end
function BigAmount.add(a: number, b: number): number
	return nonnegative(Real64.add(nonnegative(a), nonnegative(b)))
end
function BigAmount.subtract(a: number, b: number): number
	a, b = nonnegative(a), nonnegative(b)
	if a < b then fail("INSUFFICIENT_AMOUNT") end
	return nonnegative(Real64.subtract(a, b))
end
function BigAmount.multiply(a: number, b: number): number
	return nonnegative(Real64.multiply(nonnegative(a), nonnegative(b)))
end
function BigAmount.divide(a: number, b: number): number
	return nonnegative(Real64.divide(nonnegative(a), nonnegative(b)))
end

local function word(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 or value > WORD_MAX
		or value % 1 ~= 0 then fail("INVALID_UINT32") end
	return if value == 0 then 0 else value
end

local function parts(value: UInt64): (number, number)
	if type(value) ~= "table" or getmetatable(value) ~= nil then fail("INVALID_UINT64") end
	return word(rawget(value, "hi")), word(rawget(value, "lo"))
end

local function make(hi: number, lo: number): UInt64
	return table.freeze({ hi = word(hi), lo = word(lo) })
end

local ExactUInt = {}
ExactUInt.fromParts = make
function ExactUInt.fromSafeNumber(value: number): UInt64
	value = nonnegative(value)
	if value > SAFE_MAX or value % 1 ~= 0 then fail("UNSAFE_INTEGER") end
	return make(math.floor(value / BASE), value % BASE)
end
function ExactUInt.decode(text: string): UInt64
	if type(text) ~= "string" or #text == 0 or #text > 20
		or not string.match(text, "^[0-9]+$")
		or (#text > 1 and string.sub(text, 1, 1) == "0") then fail("INVALID_UINT64_TEXT") end
	local hi, lo = 0, 0
	for i = 1, #text do
		local lower = lo * 10 + (string.byte(text, i) - 48)
		local upper = hi * 10 + math.floor(lower / BASE)
		if upper > WORD_MAX then fail("UINT64_OVERFLOW") end
		hi, lo = upper, lower % BASE
	end
	return make(hi, lo)
end
function ExactUInt.encode(value: UInt64): string
	local hi, lo = parts(value)
	if hi == 0 and lo == 0 then return "0" end
	local digits = {}
	while hi ~= 0 or lo ~= 0 do
		local quotientHi = math.floor(hi / 10)
		local lower = (hi % 10) * BASE + lo
		table.insert(digits, string.char(48 + lower % 10))
		hi, lo = quotientHi, math.floor(lower / 10)
	end
	return string.reverse(table.concat(digits))
end
function ExactUInt.compare(a: UInt64, b: UInt64): number
	local ah, al = parts(a)
	local bh, bl = parts(b)
	if ah ~= bh then return if ah < bh then -1 else 1 end
	return if al == bl then 0 elseif al < bl then -1 else 1
end
function ExactUInt.add(a: UInt64, b: UInt64): UInt64
	local ah, al = parts(a)
	local bh, bl = parts(b)
	local low = al + bl
	local high = ah + bh + math.floor(low / BASE)
	if high > WORD_MAX then fail("UINT64_OVERFLOW") end
	return make(high, low % BASE)
end
function ExactUInt.subtract(a: UInt64, b: UInt64): UInt64
	local ah, al = parts(a)
	local bh, bl = parts(b)
	if ah < bh or (ah == bh and al < bl) then fail("UINT64_UNDERFLOW") end
	local borrow = if al < bl then 1 else 0
	return make(ah - bh - borrow, al - bl + borrow * BASE)
end
function ExactUInt.toSafeNumber(value: UInt64): number
	local hi, lo = parts(value)
	if hi > 2097151 then fail("UNSAFE_INTEGER") end
	return hi * BASE + lo
end
function ExactUInt.toReal64Rounded(value: UInt64): (number, boolean)
	local hi, lo = parts(value)
	-- hi * 2^32 is exact. Only the addition rounds; no parsing of the full decimal text.
	local probe, highBits = hi, 0
	while probe > 0 do probe = math.floor(probe / 2); highBits += 1 end
	local droppedBits = math.max(0, highBits - 21)
	local exact = lo % (2 ^ droppedBits) == 0
	return hi * BASE + lo, exact
end

NumericCodec.Real64 = table.freeze(Real64)
NumericCodec.BigAmount = table.freeze(BigAmount)
NumericCodec.ExactUInt = table.freeze(ExactUInt)
return table.freeze(NumericCodec)
