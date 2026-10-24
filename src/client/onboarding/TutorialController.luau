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

local STEP_DEFINITIONS: { [number]: TutorialStepInfo } = table.freeze({
	[1] = table.freeze({
		step = 1,
		title = "Wypuść pierwszego kurczaka",
		instruction = "Naciśnij i przytrzymaj czerwony przycisk wylęgarni, aby wypuścić kury na farmę.",
		targetWidget = "HatchButton",
		isCompleted = false,
	}),
	[2] = table.freeze({
		step = 2,
		title = "Zbadaj pierwsze ulepszenie",
		instruction = "Otwórz menu Badań i zakup pierwsze badanie powszechne (Wygodne gniazda).",
		targetWidget = "ResearchMenuButton",
		isCompleted = false,
	}),
	[3] = table.freeze({
		step = 3,
		title = "Ulepsz infrastrukturę farmy",
		instruction = "Rozbuduj swój kurnik lub flotę pojazdów, aby pomieścić i wyeksportować więcej jaj.",
		targetWidget = "HabitatsMenuButton",
		isCompleted = false,
	}),
	[4] = table.freeze({
		step = 4,
		title = "Odbierz codzienny prezent",
		instruction = "Otwórz kalendarz i odbierz swoją pierwszą nagrodę dzienną.",
		targetWidget = "CalendarMenuButton",
		isCompleted = false,
	}),
	[5] = table.freeze({
		step = 5,
		title = "Samouczek ukończony!",
		instruction = "Znasz już podstawy prowadzenia farmy. Rozwijaj farmę, odkrywaj nowe jaja i prestiżuj!",
		targetWidget = "None",
		isCompleted = true,
	}),
})

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
	if validStep == 5 then
		self.visible = false
	end
end

function TutorialController:getCurrentStepInfo(): TutorialStepInfo
	return STEP_DEFINITIONS[self.currentStep] or STEP_DEFINITIONS[5]
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
