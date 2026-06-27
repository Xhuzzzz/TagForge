# TagForge

**TagForge** is a small, strongly typed component binder for Roblox.

It lets you turn `CollectionService` tags into automatic components, so you can build clean game systems without placing Scripts inside every object in your map.

Perfect for things like:

* Fishing spots
* Sell zones
* Roll stations
* Chests
* Doors
* Damage zones
* NPCs
* Interactables
* Upgrade stations
* Island zones
* Any tagged object in your game world

---

## Why TagForge?

In Roblox games, you often end up with repeated objects that need behavior:

```txt
Workspace
├─ FishingSpot1
├─ FishingSpot2
├─ FishingSpot3
├─ SellZone
├─ Chest
└─ RollStation
```

Without a binder, you may end up putting scripts everywhere.

With TagForge, you only add a tag:

```txt
FishingSpot
SellZone
Chest
RollStation
```

Then TagForge automatically creates, starts, and destroys the correct component when the tag is added or removed.

---

## Features

* Strongly typed Luau API
* Automatic binding from `CollectionService` tags
* Automatic cleanup when tags are removed
* Optional `Start()` and `Destroy()` lifecycle methods
* Supports custom instance class validation
* Lightweight and dependency-free
* Works on server, client, or shared code
* Great for Rojo + Wally projects

---

## Installation

### Wally

Add TagForge to your `wally.toml`:

```toml
[dependencies]
TagForce = "xhuzzzz/tagforge@0.1.0"
```

Then run:

```bash
wally install
```

In your Rojo project, make sure your `Packages` folder is mapped into `ReplicatedStorage`:

```json
{
  "name": "MyGame",
  "tree": {
    "$className": "DataModel",

    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",

      "Packages": {
        "$path": "Packages"
      }
    }
  }
}
```

Then require it:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TagForge = require(ReplicatedStorage.Packages.TagForge)
local Binder = TagForge.Binder
```

---

## Quick Example

This example binds all parts tagged `"TestPart"` and turns them green when the component starts.

```lua
--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TagForge = require(ReplicatedStorage.Packages.TagForge)
local Binder = TagForge.Binder

type TestComponent = {
	Instance: BasePart,
	DisplayName: string,

	Start: (self: TestComponent) -> (),
	Destroy: (self: TestComponent) -> (),
}

local TestComponent = {}
TestComponent.__index = TestComponent

function TestComponent.new(instance: BasePart): TestComponent
	local self: TestComponent = {
		Instance = instance,
		DisplayName = instance:GetAttribute("DisplayName") :: string? or "Unnamed Part",
	}

	return setmetatable(self, TestComponent) :: any
end

function TestComponent:Start()
	print("Started component:", self.DisplayName)

	self.Instance.Color = Color3.fromRGB(0, 255, 0)
end

function TestComponent:Destroy()
	print("Destroyed component:", self.DisplayName)

	self.Instance.Color = Color3.fromRGB(255, 0, 0)
end

local testBinderOptions: TagForge.BinderOptions = {
	className = "BasePart",
	autoStart = true,
}
local testBinder = Binder.new<BasePart, TestComponent>(
	"TestPart",
	TestComponent.new,
	testBinderOptions
)

testBinder:Start()

local part = Instance.new("Part")
part.Name = "MyTaggedPart"
part.Anchored = true
part.Size = Vector3.new(5, 1, 5)
part.Position = Vector3.new(0, 5, 0)
part:SetAttribute("DisplayName", "Cool Test Part")
part.Parent = workspace

CollectionService:AddTag(part, "TestPart")

task.delay(3, function()
	CollectionService:RemoveTag(part, "TestPart")
end)

task.delay(6, function()
	testBinder:Destroy()
	part:Destroy()
end)
```

Expected output:

```txt
Started component: Cool Test Part
Destroyed component: Cool Test Part
```

---

## Fishing Game Example

TagForge is especially useful for RNG/fishing games.

For example, you can tag parts in your map as:

```txt
FishingSpot
```

Then add attributes in Roblox Studio:

```txt
Island = "AbyssTrench"
FishPool = "AbyssFish"
LuckMultiplier = 2.5
MinRodPower = 150
```

Now every tagged part can become a fishing zone automatically.

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TagForge = require(ReplicatedStorage.Packages.TagForge)
local Binder = TagForge.Binder

type FishingSpot = {
	Instance: BasePart,

	Island: string,
	FishPool: string,
	LuckMultiplier: number,
	MinRodPower: number,

	Start: (self: FishingSpot) -> (),
	Destroy: (self: FishingSpot) -> (),
}

local FishingSpot = {}
FishingSpot.__index = FishingSpot

function FishingSpot.new(instance: BasePart): FishingSpot
	local self: FishingSpot = {
		Instance = instance,

		Island = instance:GetAttribute("Island") :: string? or "Hub",
		FishPool = instance:GetAttribute("FishPool") :: string? or "BasicFish",
		LuckMultiplier = instance:GetAttribute("LuckMultiplier") :: number? or 1,
		MinRodPower = instance:GetAttribute("MinRodPower") :: number? or 0,
	}

	return setmetatable(self, FishingSpot) :: any
end

function FishingSpot:Start()
	print(
		"Fishing spot loaded:",
		self.Island,
		self.FishPool,
		self.LuckMultiplier,
		self.MinRodPower
	)

	-- Example:
	-- Show prompt
	-- Connect proximity prompt
	-- Register zone
	-- Tell FishingService this spot exists
end

function FishingSpot:Destroy()
	print("Fishing spot destroyed:", self.Island, self.FishPool)

	-- Example:
	-- Disconnect prompt
	-- Remove zone
	-- Cleanup effects
end

local fishingSpotBinder = Binder.new<BasePart, FishingSpot>(
	"FishingSpot",
	FishingSpot.new,
	{
		className = "BasePart",
		autoStart = true,
	}
)

fishingSpotBinder:Start()
```

With this pattern, you can create many fishing zones without writing new scripts for each one.

---

## Another Example: Sell Zone

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TagForge = require(ReplicatedStorage.Packages.TagForge)
local Binder = TagForge.Binder

type SellZone = {
	Instance: BasePart,
	Multiplier: number,

	Start: (self: SellZone) -> (),
	Destroy: (self: SellZone) -> (),
}

local SellZone = {}
SellZone.__index = SellZone

function SellZone.new(instance: BasePart): SellZone
	local self: SellZone = {
		Instance = instance,
		Multiplier = instance:GetAttribute("Multiplier") :: number? or 1,
	}

	return setmetatable(self, SellZone) :: any
end

function SellZone:Start()
	print("Sell zone started with multiplier:", self.Multiplier)

	-- Example:
	-- Connect Touched
	-- Open sell UI
	-- Sell player's fish inventory
end

function SellZone:Destroy()
	print("Sell zone destroyed")
end

local sellZoneBinder = Binder.new<BasePart, SellZone>(
	"SellZone",
	SellZone.new,
	{
		className = "BasePart",
		autoStart = true,
	}
)

sellZoneBinder:Start()
```

---

## API

### `Binder.new(tag, constructor, options?)`

Creates a new binder for a specific tag.

```lua
local binder = Binder.new<BasePart, MyComponent>(
	"MyTag",
	MyComponent.new,
	{
		className = "BasePart",
		autoStart = true,
	}
)
```

### Parameters

| Name          | Type                                  | Description                          |
| ------------- | ------------------------------------- | ------------------------------------ |
| `tag`         | `string`                              | The `CollectionService` tag to bind. |
| `constructor` | `(instance: TInstance) -> TComponent` | Function used to create a component. |
| `options`     | `BinderOptions?`                      | Optional binder configuration.       |

---

## Binder Options

```lua
type BinderOptions = {
	className: string?,
	autoStart: boolean?,
	onError: ((message: string, instance: Instance?) -> ())?,
}
```

### `className`

Validates that tagged instances are of a specific Roblox class.

```lua
{
	className = "BasePart"
}
```

### `autoStart`

If `true` or omitted, TagForge automatically calls `component:Start()` when the component is created.

```lua
{
	autoStart = true
}
```

If set to `false`, the component will be created but not started automatically.

```lua
{
	autoStart = false
}
```

### `onError`

Custom error handler.

```lua
{
	onError = function(message, instance)
		warn(message, instance)
	end
}
```

---

## Binder Methods

### `binder:Start()`

Starts listening for tagged instances and binds all existing tagged instances.

```lua
binder:Start()
```

### `binder:Stop()`

Disconnects tag listeners and unbinds all active components.

```lua
binder:Stop()
```

### `binder:Bind(instance)`

Manually binds an instance.

```lua
local component = binder:Bind(part)
```

### `binder:Unbind(instance)`

Manually unbinds an instance.

```lua
binder:Unbind(part)
```

### `binder:Get(instance)`

Gets the component attached to an instance.

```lua
local component = binder:Get(part)
```

### `binder:GetAll()`

Returns all active components.

```lua
local components = binder:GetAll()
```

### `binder:Destroy()`

Stops the binder and clears all internal state.

```lua
binder:Destroy()
```

---

## Component Lifecycle

A component can optionally define `Start()` and `Destroy()`.

```lua
type MyComponent = {
	Instance: BasePart,

	Start: (self: MyComponent) -> (),
	Destroy: (self: MyComponent) -> (),
}
```

TagForge will call:

```txt
constructor(instance)
↓
component:Start()
```

When the tag is added.

And:

```txt
component:Destroy()
```

When the tag is removed or the binder is stopped/destroyed.

---

## Recommended Project Structure

```txt
src
├─ shared
│  └─ Components
│     ├─ FishingSpot.luau
│     ├─ SellZone.luau
│     ├─ RollStation.luau
│     └─ Chest.luau
│
├─ server
│  └─ ComponentBootstrap.server.luau
│
└─ client
   └─ ClientComponentBootstrap.client.luau
```

Example bootstrap:

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TagForge = require(ReplicatedStorage.Packages.TagForge)
local Binder = TagForge.Binder

local FishingSpot = require(ReplicatedStorage.Shared.Components.FishingSpot)
local SellZone = require(ReplicatedStorage.Shared.Components.SellZone)

local binders = {
	Binder.new<BasePart, FishingSpot.FishingSpot>(
		"FishingSpot",
		FishingSpot.new,
		{ className = "BasePart" }
	),

	Binder.new<BasePart, SellZone.SellZone>(
		"SellZone",
		SellZone.new,
		{ className = "BasePart" }
	),
}

for _, binder in binders do
	binder:Start()
end
```

---

## Use Cases

TagForge works well for many Roblox systems:

```txt
FishingSpot         → fishing areas
RollStation         → RNG rod machines
SellZone            → fish selling zones
BoatDock            → boat spawning areas
Chest               → reward chests
DamageZone          → lava, traps, poison areas
Door                → interactive doors
NPC                 → quest NPCs
Checkpoint          → obby checkpoints
UpgradeStation      → upgrade trees
IslandZone          → island multipliers
```

---

## License

MIT License.

---

## Status

TagForge is currently in early development.

The goal is to stay:

* Small
* Typed
* Fast
* Dependency-free
* Easy to use in any Roblox project
