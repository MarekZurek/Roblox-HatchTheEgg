--!nocheck
-- Exact vacancy and 64-bit remainder. Never route using rounded populations.
local PopulationMath={}
function PopulationMath.new(codec)
	assert(codec.VERSION==1,"PopulationMath/UNSUPPORTED_CODEC")
	local U=codec.ExactUInt
	local zero,one=U.fromSafeNumber(0),U.fromSafeNumber(1)
	local function moduloValue(draw,divisor)
		assert(U.compare(divisor,zero)>0,"PopulationMath/ZERO_DIVISOR")
		local remainder=zero
		for _,word in {draw.hi,draw.lo} do
			for shift=31,0,-1 do
				local bit=math.floor(word/(2^shift))%2
				-- r<d. Compute 2*r without overflowing uint64, by comparing r with d-r.
				local gap=U.subtract(divisor,remainder)
				if U.compare(remainder,gap)>=0 then remainder=U.subtract(remainder,gap)
				else remainder=U.add(remainder,remainder) end
				if bit==1 then
					if U.compare(remainder,U.subtract(divisor,one))==0 then remainder=zero
					else remainder=U.add(remainder,one) end
				end
			end
		end
		return remainder
	end
	local api={VERSION=1}
	function api.modulo(drawText,divisorText)
		return U.encode(moduloValue(U.decode(drawText),U.decode(divisorText)))
	end
	function api.vacancy(hab)
		assert(type(hab)=="table" and getmetatable(hab)==nil,"PopulationMath/INVALID_HABITAT")
		local capacity,population,reserved=U.decode(hab.capacity),U.decode(hab.population),U.decode(hab.assignedInTransit)
		if hab.typeIndex==-1 then
			assert(U.compare(capacity,zero)==0 and U.compare(population,zero)==0 and U.compare(reserved,zero)==0,"PopulationMath/INVALID_EMPTY_SLOT")
			return zero
		end
		if U.compare(population,capacity)>=0 then return zero end
		local afterPopulation=U.subtract(capacity,population)
		if U.compare(reserved,afterPopulation)>=0 then return zero end
		return U.subtract(afterPopulation,reserved)
	end
	function api.vacancies(habitats)
		assert(type(habitats)=="table" and getmetatable(habitats)==nil and #habitats==4,"PopulationMath/FOUR_SLOTS_REQUIRED")
		local n=0;for k in habitats do assert(type(k)=="number" and k>=1 and k<=4 and k%1==0,"PopulationMath/INVALID_SLOTS");n+=1 end
		assert(n==4,"PopulationMath/FOUR_SLOTS_REQUIRED")
		local values,total={},zero
		for i=1,4 do values[i]=api.vacancy(habitats[i]);total=U.add(total,values[i]) end
		return values,total
	end
	function api.select(habitats,drawText)
		local values,total=api.vacancies(habitats)
		if U.compare(total,zero)==0 then return nil,"0" end
		local remainder=moduloValue(U.decode(drawText),total)
		for i=1,4 do
			if U.compare(remainder,values[i])<0 then return i,U.encode(total) end
			remainder=U.subtract(remainder,values[i])
		end
		error("PopulationMath/INVALID_SELECTION")
	end
	return table.freeze(api)
end
return table.freeze(PopulationMath)
