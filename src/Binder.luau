--!strict
local CollectionService = game:GetService("CollectionService")

export type Disconnectable = {
	Disconnect: (self: Disconnectable) -> (),
}

export type ComponentLike<TInstance> = {
	Instance: TInstance,
	Start: ((self: any) -> ())?,
	Destroy: ((self: any) -> ())?,
}

export type Constructor<TInstance, TComponent> = (instance: TInstance) -> TComponent

export type BinderOptions = {
	className: string?,
	autoStart: boolean?,
	onError: ((message: string, instance: Instance?) -> ())?,
}

export type Binder<TInstance, TComponent> = {
	Tag: string,

	Start: (self: Binder<TInstance, TComponent>) -> (),
	Stop: (self: Binder<TInstance, TComponent>) -> (),

	Bind: (self: Binder<TInstance, TComponent>, instance: TInstance) -> TComponent?,
	Unbind: (self: Binder<TInstance, TComponent>, instance: TInstance) -> (),

	Get: (self: Binder<TInstance, TComponent>, instance: TInstance) -> TComponent?,
	GetAll: (self: Binder<TInstance, TComponent>) -> { TComponent },

	Destroy: (self: Binder<TInstance, TComponent>) -> (),
}

type Private<TInstance, TComponent> = {
	Tag: string,

	_constructor: Constructor<TInstance, TComponent>,
	_options: BinderOptions,

	_components: { [Instance]: TComponent },
	_connections: { RBXScriptConnection },

	_started: boolean,
	_destroyed: boolean,
}

local Binder = {}
Binder.__index = Binder

local function reportError<TInstance>(options: BinderOptions, message: string, instance: Instance?)
	if options.onError then
		options.onError(message, instance)
	else
		if instance then
			warn(`[TagForge] {message} | Instance: {instance:GetFullName()}`)
		else
			warn(`[TagForge] {message}`)
		end
	end
end

local function isValidInstance<TInstance>(options: BinderOptions, instance: Instance): boolean
	if options.className == nil then
		return true
	end

	return instance:IsA(options.className)
end

local function bindInstance<TInstance, TComponent>(private: Private<TInstance, TComponent>, instance: TInstance): TComponent?
	local rawInstance: Instance = instance :: any

	assert(not private._destroyed, "Binder is destroyed")

	local existingComponent = private._components[rawInstance]
	if existingComponent ~= nil then
		return existingComponent
	end

	if not isValidInstance(private._options, rawInstance) then
		reportError(
			private._options,
			`Instance with tag "{private.Tag}" must be a {private._options.className}`,
			rawInstance
		)

		return nil
	end

	local success, result = pcall(function()
		return private._constructor(instance)
	end)

	if not success then
		reportError(
			private._options,
			`Failed to construct component for tag "{private.Tag}": {tostring(result)}`,
			rawInstance
		)

		return nil
	end

	local component: TComponent = result :: any
	private._components[rawInstance] = component

	if private._options.autoStart ~= false then
		local maybeComponent = component :: any

		if type(maybeComponent.Start) == "function" then
			local startSuccess, startError = pcall(function()
				maybeComponent:Start()
			end)

			if not startSuccess then
				reportError(
					private._options,
					`Failed to start component for tag "{private.Tag}": {tostring(startError)}`,
					rawInstance
				)
			end
		end
	end

	return component
end

local function unbindInstance<TInstance, TComponent>(private: Private<TInstance, TComponent>, instance: TInstance)
	local rawInstance: Instance = instance :: any

	local component = private._components[rawInstance]

	if component == nil then
		return
	end

	private._components[rawInstance] = nil

	local maybeComponent = component :: any

	if type(maybeComponent.Destroy) == "function" then
		local success, err = pcall(function()
			maybeComponent:Destroy()
		end)

		if not success then
			reportError(
				private._options,
				`Failed to destroy component for tag "{private.Tag}": {tostring(err)}`,
				rawInstance
			)
		end
	end
end

local function stopBinder<TInstance, TComponent>(private: Private<TInstance, TComponent>)
	if not private._started then
		return
	end

	private._started = false

	for _, connection in private._connections do
		if connection.Connected then
			connection:Disconnect()
		end
	end

	table.clear(private._connections)

	local instances: { Instance } = {}

	for instance in private._components do
		table.insert(instances, instance)
	end

	for _, instance in instances do
		unbindInstance(private, instance :: any)
	end
end

function Binder.new<TInstance, TComponent>(
	tag: string,
	constructor: Constructor<TInstance, TComponent>,
	options: BinderOptions?
): Binder<TInstance, TComponent>
	assert(type(tag) == "string", "tag must be a string.")
	assert(type(constructor) == "function", "constructor must be a function.")

	local private: Private<TInstance, TComponent> = {
		Tag = tag,

		_constructor = constructor,
		_options = options or {},

		_components = {},
		_connections = {},

		_started = false,
		_destroyed = false,
	}

	return setmetatable(private, Binder) :: any
end

function Binder.Start<TInstance, TComponent>(self: Binder<TInstance, TComponent>)
	local private: Private<TInstance, TComponent> =
		self :: Private<TInstance, TComponent> & Binder<TInstance, TComponent>

	assert(not private._destroyed, "Binder is destroyed")

	if private._started then
		return
	end

	private._started = true

	for _, instance in CollectionService:GetTagged(private.Tag) do
		bindInstance(private, instance)
	end

	table.insert(
		private._connections,
		CollectionService:GetInstanceAddedSignal(private.Tag):Connect(function(instance)
			bindInstance(private, instance)
		end)
	)

	table.insert(
		private._connections,
		CollectionService:GetInstanceRemovedSignal(private.Tag):Connect(function(instance)
			unbindInstance(private, instance)
		end)
	)
end

function Binder.Stop<TInstance, TComponent>(self: Binder<TInstance, TComponent>)
	local private: Private<TInstance, TComponent> =
		self :: Private<TInstance, TComponent> & Binder<TInstance, TComponent>

	stopBinder(private)
end

function Binder.Bind<TInstance, TComponent>(self: Binder<TInstance, TComponent>, instance: TInstance): TComponent?
	local private: Private<TInstance, TComponent> =
		self :: Private<TInstance, TComponent> & Binder<TInstance, TComponent>

	return bindInstance(private, instance)
end

function Binder.Unbind<TInstance, TComponent>(self: Binder<TInstance, TComponent>, instance: TInstance)
	local private: Private<TInstance, TComponent> =
		self :: Private<TInstance, TComponent> & Binder<TInstance, TComponent>

	unbindInstance(private, instance)
end

function Binder.Get<TInstance, TComponent>(self: Binder<TInstance, TComponent>, instance: TInstance): TComponent?
	local private: Private<TInstance, TComponent> =
		self :: Private<TInstance, TComponent> & Binder<TInstance, TComponent>
	local rawInstance: Instance = instance :: Instance & any

	return private._components[rawInstance]
end

function Binder.GetAll<TInstance, TComponent>(self: Binder<TInstance, TComponent>): { TComponent }
	local private: Private<TInstance, TComponent> =
		self :: Private<TInstance, TComponent> & Binder<TInstance, TComponent>

	local result: { TComponent } = {}

	for _, component in private._components do
		table.insert(result, component)
	end

	return result
end

function Binder.Destroy<TInstance, TComponent>(self: Binder<TInstance, TComponent>)
	local private: Private<TInstance, TComponent> = self :: Private<TInstance, TComponent> & any

	if private._destroyed then
		return
	end

	stopBinder(private)

	private._destroyed = true
	table.clear(private._components)
	table.clear(private._connections)
end

return Binder
