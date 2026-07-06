

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ECS = require(ReplicatedStorage.ECS)
local TweenManager = require(ReplicatedStorage.Modules.TweenManager)


local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local PlayerInterface =
	PlayerGui:WaitForChild("MainInterface"):WaitForChild("PlayerInterface")

local Container =
	PlayerInterface:WaitForChild("Notifications"):WaitForChild("Container")

local NotificationTemplate =
	Container:WaitForChild("NotificationTemplate") :: Frame


local NotificationModule = {}



local SLIDE_IN: UDim2 = UDim2.fromScale(0, 0)
local SLIDE_OUT: UDim2 = UDim2.fromScale(1.2, 0)

local IN_TWEEN: TweenInfo =
	TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local OUT_TWEEN: TweenInfo =
	TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)


function NotificationModule.Notify(text: string, duration: number, color: Color3): ()
        local wrapper: Frame = Instance.new("Frame")
        wrapper.Name = "NotificationWrapper"
        wrapper.BackgroundTransparency = 1
        wrapper.Size = NotificationTemplate.Size
        wrapper.AutomaticSize = Enum.AutomaticSize.Y
        wrapper.Parent = Container

        local content: Frame = Instance.new("Frame")
        content.Name = "Content"
        content.BackgroundTransparency = 1
        content.Size = UDim2.fromScale(1, 1)
        content.Position = SLIDE_OUT
        content.Parent = wrapper

        local notification: Frame = NotificationTemplate:Clone()
        notification.Visible = true
        notification.Parent = content
        notification.AnchorPoint = Vector2.zero
        notification.Position = UDim2.fromScale(0,0)
        notification.Size = UDim2.fromScale(1, 1)

        local textLabel =
                notification:WaitForChild("NotificationText") :: TextLabel

        textLabel.Text = text
        textLabel.TextColor3 = color or Color3.new(1,1,1)

        TweenManager.Interface(content, {
                Position = SLIDE_IN
        }, IN_TWEEN)

        ECS.createEntity({
                Name = "NotificationSlideOut",
                ScheduledTask = {
                        delay = duration,
                        elapsed = 0,
                        callback = function()
                                if not wrapper.Parent then
                                        return
                                end

                                TweenManager.Interface(content, {
                                        Position = SLIDE_OUT
                                }, OUT_TWEEN)

                                ECS.createEntity({
                                        Name = "NotificationCleanup",
                                        ScheduledTask = {
                                                delay = OUT_TWEEN.Time,
                                                elapsed = 0,
                                                callback = function()
                                                        wrapper:Destroy()
                                                end,
                                        },
                                })
                        end,
                },
        })
end

return NotificationModule
