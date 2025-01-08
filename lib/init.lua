local DataStoreService = game:GetService("DataStoreService")

local AbstractDataStore = {
	warnings = true,
	showErrors = false,
	maxRetries = 5,
	budgetCooldown = 1,
	
	-- Function that provides the current attempt index and returns a cooldown in seconds
	retryCooldown = function(currentAttempt: number): number
		return currentAttempt*2
	end, 
}

local METHOD_TO_REQUEST_TYPE = {
	GetAsync = Enum.DataStoreRequestType.GetAsync,
	SetAsync = Enum.DataStoreRequestType.SetIncrementAsync,
	OnUpdate = Enum.DataStoreRequestType.OnUpdate,
	UpdateAsync = Enum.DataStoreRequestType.UpdateAsync,
	RemoveAsync = Enum.DataStoreRequestType.SetIncrementAsync,
	ListKeysAsync = Enum.DataStoreRequestType.ListAsync,
	GetSortedAsync = Enum.DataStoreRequestType.GetSortedAsync,
	IncrementAsync = Enum.DataStoreRequestType.SetIncrementSortedAsync,
	ListVersionsAsync = Enum.DataStoreRequestType.ListAsync,
	RemoveVersionAsync = Enum.DataStoreRequestType.RemoveVersionAsync,
}

--[[
This method yields until a response is returned or the maxRetries has been reached.
]]
function AbstractDataStore:requestAsync(method: string, ...)
	assert(typeof(method) == "string", "[PSTORE] The provided method is not a string: "..method)

	local requestType = METHOD_TO_REQUEST_TYPE[method]
	assert(METHOD_TO_REQUEST_TYPE[method], "[PSTORE] Unsupported or invalid method: "..method)
	
	local retriesLeft = self.maxRetries
	local retryCooldown = self.retryCooldown
	
	local success, result

	repeat
		while DataStoreService:GetRequestBudgetForRequestType(requestType) == 0 do
			task.wait(self.budgetCooldown)
		end
		
		success, result = pcall(self.__DataStore[method], self.__DataStore, ...)
		
		if not success then
			retriesLeft -= 1
			
			if self.showErrors then
				warn("[PSTORE] Failed to call :"..method.."() on DataStore: "..result)
			end
			
			local waitTime = self.retryCooldown(math.abs(self.maxRetries - retriesLeft))
			task.wait(waitTime)
		else
			return result
		end
	until retriesLeft == 0
end

local module = {}

function module:GetDataStore(name: string, scope: string?)
	assert(typeof(name) == "string", "[PSTORE] Failed to get DataStore: provided name is not string")
	assert(typeof(scope) == "string" or typeof(scope) == "nil", "[PSTORE] Failed to get DataStore: provided scope is not a string")

	local self = setmetatable({}, {
		__index = AbstractDataStore,
	})
	
	self.__DataStore = DataStoreService:GetDataStore(name, scope)

	return self
end

function module:GetOrderedDataStore(name: string, scope: string?)
	assert(typeof(name) == "string", "[PSTORE] Failed to get OrderedDataStore: provided name is not string")
	assert(typeof(scope) == "string" or typeof(scope) == "nil", "[PSTORE] Failed to get OrderedDataStore: provided scope is not a string")
	
	local self = setmetatable({}, {
		__index = AbstractDataStore,
	})
	
	self.__DataStore = DataStoreService:GetOrderedDataStore(name, scope)
	
	return self
end

return module