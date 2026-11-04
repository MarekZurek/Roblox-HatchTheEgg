--!strict
-- Client presentation controller for HatchTheEgg onboarding & tutorial steps.
-- Spec: docs/31 §4; docs/28; Issue #35 (NEXT-10).
-- Invariant: NEVER mutates authoritative state; presents guidance based on StateStore/reconciled steps.

local TutorialController = {}
TutorialController.__index = TutorialController

export type TutorialStepInfo = {
	step: number,
	title: string,
	instruction: string,
	targetWidget: string,
	isCompleted: boolean,
}

export type TutorialVisibilityMap = {
	HatcheryFrame: boolean,
	TopBar: boolean,
	BottomLeftCluster: boolean,
	DiamondsPillFrame: boolean,
	PlayerFarmBadge: boolean,
	RightDock: boolean,
	ResearchMenuButton: boolean,
	HabitatsMenuButton: boolean,
	VehiclesMenuButton: boolean,
	CalendarMenuButton: boolean,
	ShopMenuButton: boolean,
	EpicResearchMenuButton: boolean,
	PrestigeMenuButton: boolean,
}

local STEP_DEFINITIONS: { [number]: TutorialStepInfo } = table.freeze({
	[1] = table.freeze({
		step = 1,
		title = "Hatch your first chicken",
		instruction = "Step onto the red hatchery pad in the center of the farm to release chickens!",
		targetWidget = "HatchButton",
		isCompleted = false,
	}),
	[2] = table.freeze({
		step = 2,
		title = "Research your first upgrade",
		instruction = "Open the Research menu on the right and purchase your first upgrade!",
		targetWidget = "ResearchMenuButton",
		isCompleted = false,
	}),
	[3] = table.freeze({
		step = 3,
		title = "Upgrade farm infrastructure",
		instruction = "Open Habitats or Vehicles on the right to expand your farm capacity and shipping.",
		targetWidget = "HabitatsMenuButton",
		isCompleted = false,
	}),
	[4] = table.freeze({
		step = 4,
		title = "Claim daily gift",
		instruction = "Open Rewards on the right side of the screen and claim your first daily gift.",
		targetWidget = "CalendarMenuButton",
		isCompleted = false,
	}),
	[5] = table.freeze({
		step = 5,
		title = "Tutorial complete!",
		instruction = "You know the basics of running the farm. Expand your empire, discover new eggs, and prestige!",
		targetWidget = "None",
		isCompleted = true,
	}),
})

local STEP_VISIBILITY: { [number]: TutorialVisibilityMap } = table.freeze({
	[1] = table.freeze({
		HatcheryFrame = true,
		TopBar = false,
		BottomLeftCluster = false,
		DiamondsPillFrame = false,
		PlayerFarmBadge = false,
		RightDock = false,
		ResearchMenuButton = false,
		HabitatsMenuButton = false,
		VehiclesMenuButton = false,
		CalendarMenuButton = false,
		ShopMenuButton = false,
		EpicResearchMenuButton = false,
		PrestigeMenuButton = false,
	}),
	[2] = table.freeze({
		HatcheryFrame = true,
		TopBar = true,
		BottomLeftCluster = true,
		DiamondsPillFrame = false,
		PlayerFarmBadge = false,
		RightDock = true,
		ResearchMenuButton = true,
		HabitatsMenuButton = false,
		VehiclesMenuButton = false,
		CalendarMenuButton = false,
		ShopMenuButton = false,
		EpicResearchMenuButton = false,
		PrestigeMenuButton = false,
	}),
	[3] = table.freeze({
		HatcheryFrame = true,
		TopBar = true,
		BottomLeftCluster = true,
		DiamondsPillFrame = false,
		PlayerFarmBadge = true,
		RightDock = true,
		ResearchMenuButton = true,
		HabitatsMenuButton = true,
		VehiclesMenuButton = true,
		CalendarMenuButton = false,
		ShopMenuButton = false,
		EpicResearchMenuButton = false,
		PrestigeMenuButton = false,
	}),
	[4] = table.freeze({
		HatcheryFrame = true,
		TopBar = true,
		BottomLeftCluster = true,
		DiamondsPillFrame = false,
		PlayerFarmBadge = true,
		RightDock = true,
		ResearchMenuButton = true,
		HabitatsMenuButton = true,
		VehiclesMenuButton = true,
		CalendarMenuButton = true,
		ShopMenuButton = false,
		EpicResearchMenuButton = false,
		PrestigeMenuButton = false,
	}),
	[5] = table.freeze({
		HatcheryFrame = true,
		TopBar = true,
		BottomLeftCluster = true,
		DiamondsPillFrame = true,
		PlayerFarmBadge = true,
		RightDock = true,
		ResearchMenuButton = true,
		HabitatsMenuButton = true,
		VehiclesMenuButton = true,
		CalendarMenuButton = true,
		ShopMenuButton = true,
		EpicResearchMenuButton = true,
		PrestigeMenuButton = true,
	}),
})

function TutorialController.resolveStepFromFarm(farm: any, fallbackTotalPop: number?): number
	if type(farm) ~= "table" then
		return 1
	end
	if type(farm.tutorialStep) == "number" then
		return math.clamp(farm.tutorialStep, 1, 5)
	end
	local progress = farm.progress
	if type(progress) == "table" and type(progress.tutorialStep) == "number" then
		return math.clamp(progress.tutorialStep, 1, 5)
	end

	local dailyClaimed = (type(progress) == "table" and (tonumber(progress.numDailyGiftsCollected) or 0) > 0) or false
	local hasPrestigedOrAdvanced = ((tonumber(farm.eggIndex) or 0) > 0)
		or (type(progress) == "table" and (tonumber(progress.SE) or 0) > 0)
	if dailyClaimed or hasPrestigedOrAdvanced then
		return 5
	end

	local hasUpgradedInfra = false
	if type(farm.habitats) == "table" then
		for s = 1, 4 do
			local h = farm.habitats[s]
			if type(h) == "table" then
				local idx = h.habitatIndex
				if idx == nil then idx = h.typeIndex end
				if (s == 1 and type(idx) == "number" and idx > 0) or (s > 1 and type(idx) == "number" and idx >= 0) then
					hasUpgradedInfra = true
					break
				end
			end
		end
	end
	if not hasUpgradedInfra and type(farm.fleet) == "table" and type(farm.fleet.vehicles) == "table" then
		if #farm.fleet.vehicles > 1 then
			hasUpgradedInfra = true
		elseif #farm.fleet.vehicles == 1 and (tonumber(farm.fleet.vehicles[1].vehicleIndex) or 0) > 0 then
			hasUpgradedInfra = true
		end
	end
	if hasUpgradedInfra then
		return 4
	end

	local hasResearch = false
	if type(farm.common) == "table" then
		for k, r in pairs(farm.common) do
			if type(r) == "table" and (tonumber(r.level) or 0) > 0 then
				hasResearch = true
				break
			elseif type(k) == "string" and type(r) == "number" and r > 0 then
				hasResearch = true
				break
			end
		end
	end
	if hasResearch then
		return 3
	end

	local totalPop = tonumber(fallbackTotalPop) or 0
	if totalPop <= 0 and type(farm.habitats) == "table" then
		for _, h in ipairs(farm.habitats) do
			if type(h) == "table" then
				totalPop += (tonumber(h.population) or 0) + (tonumber(h.reservedInTransit) or 0)
			end
		end
	end
	local cashNum = tonumber(farm.cash) or 0
	if totalPop > 0 or cashNum > 0 then
		return 2
	end

	return 1
end

function TutorialController.new(stateStore: any?, uiRoot: any?)
	local self = setmetatable({
		stateStore = stateStore,
		uiRoot = uiRoot,
		currentStep = 1,
		visible = true,
	}, TutorialController)
	return self
end

function TutorialController:setStep(step: number)
	local validStep = math.clamp(step, 1, 5)
	self.currentStep = validStep
	self.visible = (validStep < 5)
end

function TutorialController:getCurrentStepInfo(): TutorialStepInfo
	return STEP_DEFINITIONS[self.currentStep] or STEP_DEFINITIONS[5]
end

function TutorialController.getStepVisibility(selfOrStep: any, stepOverride: number?): TutorialVisibilityMap
	local s = 5
	if typeof(selfOrStep) == "number" then
		s = selfOrStep
	elseif typeof(selfOrStep) == "table" then
		s = stepOverride or selfOrStep.currentStep or 1
	elseif stepOverride then
		s = stepOverride
	end
	s = math.clamp(s, 1, 5)
	return STEP_VISIBILITY[s] or STEP_VISIBILITY[5]
end

function TutorialController.isWidgetVisible(selfOrWidget: any, widgetOrStep: any, stepOverride: number?): boolean
	local widgetName = ""
	local s = 5
	if typeof(selfOrWidget) == "table" and selfOrWidget.currentStep ~= nil then
		widgetName = tostring(widgetOrStep)
		s = math.clamp(stepOverride or selfOrWidget.currentStep, 1, 5)
	else
		widgetName = tostring(widgetOrWidget or selfOrWidget)
		if typeof(widgetOrStep) == "number" then
			s = widgetOrStep
		elseif stepOverride then
			s = stepOverride
		else
			s = 1
		end
		s = math.clamp(s, 1, 5)
	end
	local vis = STEP_VISIBILITY[s] or STEP_VISIBILITY[5]
	if (vis :: any)[widgetName] ~= nil then
		return (vis :: any)[widgetName] == true
	end
	return s >= 5
end

function TutorialController:isCompleted(): boolean
	return self.currentStep >= 5
end

function TutorialController:getTargetWidget(): string
	local info = self:getCurrentStepInfo()
	return info.targetWidget
end

function TutorialController:getInstruction(): string
	local info = self:getCurrentStepInfo()
	return info.instruction
end

return table.freeze(TutorialController)
