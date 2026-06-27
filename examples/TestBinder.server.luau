--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TagForge = require(ReplicatedStorage.TagForge)
local Binder = TagForge.Binder

type TestComponent = {
	Instance: BasePart,
	Name: string,

	Start: (self: TestComponent) -> (),
	Destroy: (self: TestComponent) -> (),
}

local TestComponent = {}
TestComponent.__index = TestComponent

function TestComponent.new(instance: BasePart): TestComponent
	local self: TestComponent = setmetatable({
		Instance = instance,
		Name = instance:GetAttribute("DisplayName") :: string? or "No Name",
	}, TestComponent) :: TestComponent & any

	return self
end

function TestComponent:Start()
	local Component = self :: TestComponent

	print("[TestComponent]: Started:", Component.Instance.Name, self.Name)
	Component.Instance.Color = Color3.fromRGB(0, 255, 0)
end

function TestComponent:Destroy()
	local Component = self :: TestComponent

	print("[TestComponent]: Destroyed", Component.Instance.Name)
	Component.Instance.Color = Color3.fromRGB(255, 0, 0)
end

local testBinderOptions: TagForge.BinderOptions = {
	className = "BasePart",
	autoStart = true,
}
local testBinder = Binder.new("TestPart", TestComponent.new, testBinderOptions)
testBinder:Start()

local part = Instance.new("Part")
part.Name = "MyTaggedPart"
part.Size = Vector3.new(5, 1, 5)
part.Position = Vector3.new(0, 5, 0)
part.Anchored = true
part:SetAttribute("DisplayName", "Cool Test Part")
part.Parent = workspace

print("Adding tag...")
CollectionService:AddTag(part, "TestPart")

task.delay(3, function()
	print("Removing tag...")
	CollectionService:RemoveTag(part, "TestPart")
end)

task.delay(6, function()
	print("Destroying binder...")
	testBinder:Destroy()
	part:Destroy()
end)
