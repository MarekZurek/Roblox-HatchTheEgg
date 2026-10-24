--!nocheck
-- Native adapter, constructed explicitly on the server; no automatic service access.
local Port = {}
function Port.new(dataStore, getOptionsFactory)
	assert(dataStore ~= nil, "DATASTORE_REQUIRED")
	local function options()
		local value = if getOptionsFactory then getOptionsFactory() else Instance.new("DataStoreGetOptions")
		value.UseCache = false
		return value
	end
	return table.freeze({
		update = function(key, transform)
			local ok, value = pcall(function()
				return dataStore:UpdateAsync(key, function(current,keyInfo)
					local candidate=transform(current)
					if candidate==nil then return nil end
					if keyInfo then return candidate,keyInfo:GetUserIds(),keyInfo:GetMetadata() end
					return candidate
				end)
			end)
			return ok, value
		end,
		read = function(key)
			local ok, value = pcall(function() return dataStore:GetAsync(key, options()) end)
			return ok, value
		end,
	})
end
return table.freeze(Port)
