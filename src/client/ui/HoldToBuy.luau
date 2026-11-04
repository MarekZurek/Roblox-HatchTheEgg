--!strict
-- Pointer presses buy on down; Activated is reserved for other input sources.
local HoldToBuy = {}

export type Options = {
 native: boolean,
 spawn: ((() -> ()) -> any),
 wait: ((number) -> any),
 isPointerActivation: ((any) -> boolean),
}

function HoldToBuy.bind(button: any, action: () -> boolean?, options: Options)
 local holding = false
 local token = 0
 local handledPointer = false
 local function stop()
  holding = false
  token += 1
 end
 if options.native then
  button.MouseButton1Down:Connect(function()
   stop()
   if not button.Active or not button.Visible then return end
   handledPointer = true
   holding = true
   local currentToken = token
   if action() == false then stop(); return end
   options.spawn(function()
    options.wait(0.35)
    while holding and token == currentToken do
     if not button.Active or not button.Visible or action() == false then
      stop()
      break
     end
     options.wait(0.20)
    end
   end)
  end)
  button.MouseButton1Up:Connect(stop)
  button.MouseLeave:Connect(stop)
 end
 button.Activated:Connect(function(input: any)
  if options.native and handledPointer and options.isPointerActivation(input) then
   handledPointer = false
   return
  end
  if button.Active and button.Visible then action() end
 end)
end

return table.freeze(HoldToBuy)
