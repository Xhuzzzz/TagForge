--!strict
local Binder = require(script.Binder)

export type BinderOptions = Binder.BinderOptions
export type Disconnectable = Binder.Disconnectable

return {
	Binder = Binder,
}
