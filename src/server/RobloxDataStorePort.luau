--!nocheck
-- Native adapter, constructed explicitly on the server; no automatic service access.
-- Resilient implementation with exponential backoff retries for Roblox DataStoreService.
local Port = {}

function Port.new(dataStore, getOptionsFactory, config)
	assert(dataStore ~= nil, "DATASTORE_REQUIRED")

	local maxAttempts = if config and type(config.maxAttempts) == "number" then config.maxAttempts else 3
	local baseBackoff = if config and type(config.baseBackoff) == "number" then config.baseBackoff else 1
	local waitFn = if config and type(config.waitFn) == "function"
		then config.waitFn
		elseif task and type(task.wait) == "function"
		then task.wait
		else function(_s) end

	local function options()
		if getOptionsFactory then
			local val = getOptionsFactory()
			val.UseCache = false
			return val
		end
		local ok, inst = pcall(function()
			return Instance.new("DataStoreGetOptions")
		end)
		if ok and inst then
			inst.UseCache = false
			return inst
		end
		return { UseCache = false }
	end

	return table.freeze({
		update = function(key, transform)
			local lastErr
			for attempt = 1, maxAttempts do
				local transformRejected = false
				local ok, value = pcall(function()
					return dataStore:UpdateAsync(key, function(current, keyInfo)
						local candidate = transform(current)
						if candidate == nil then
							transformRejected = true
							return nil
						end
						if keyInfo and type(keyInfo.GetUserIds) == "function" and type(keyInfo.GetMetadata) == "function" then
							return candidate, keyInfo:GetUserIds(), keyInfo:GetMetadata()
						end
						return candidate
					end)
				end)

				if transformRejected then
					-- Transform was rejected or cancelled by repository logic (not a network error).
					return true, nil
				end

				if ok then
					return true, value
				end

				lastErr = value
				if attempt < maxAttempts then
					local delaySec = baseBackoff * (2 ^ (attempt - 1))
					waitFn(delaySec)
				end
			end
			return false, lastErr
		end,

		read = function(key)
			local lastErr
			for attempt = 1, maxAttempts do
				local ok, value = pcall(function()
					return dataStore:GetAsync(key, options())
				end)

				if ok then
					return true, value
				end

				lastErr = value
				if attempt < maxAttempts then
					local delaySec = baseBackoff * (2 ^ (attempt - 1))
					waitFn(delaySec)
				end
			end
			return false, lastErr
		end,
	})
end

-- Startup probe is read-only and uses the same retry/cache policy as player reads.
-- A failed open/probe is not an empty player profile and never selects memory.
function Port.open(dataStoreService, getOptionsFactory, config)
	local ok, dataStore = pcall(function()
		return dataStoreService:GetDataStore("HatchTheEgg_PlayerProfile_v1")
	end)
	if not ok or dataStore == nil then return nil, "DATASTORE_OPEN_FAILED" end
	local port = Port.new(dataStore, getOptionsFactory, config)
	local readable = port.read("__HatchTheEgg_StorageHealth_v1__")
	if not readable then return nil, "DATASTORE_PROBE_FAILED" end
	return port
end

return table.freeze(Port)
