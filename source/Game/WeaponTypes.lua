WeaponTypes = WeaponTypes or {}

local registry = WeaponTypes.registry or {}
local order = WeaponTypes.order or {}

WeaponTypes.registry = registry
WeaponTypes.order = order

function WeaponTypes.register(definition)
	if not definition or not definition.id then
		return
	end

	local alreadyRegistered = registry[definition.id] ~= nil
	registry[definition.id] = definition

	if not alreadyRegistered then
		table.insert(order, definition.id)
	end
end

function WeaponTypes.getById(id)
	return registry[id]
end

function WeaponTypes.getAll()
	local definitions = {}
	for _, id in ipairs(order) do
		table.insert(definitions, registry[id])
	end
	return definitions
end

function WeaponTypes.getIds()
	local ids = {}
	for index, id in ipairs(order) do
		ids[index] = id
	end
	return ids
end

function WeaponTypes.getDefaultId()
	return order[1] or "Minigun"
end

function WeaponTypes.getRandomStartingAmmo(id)
	local definition = registry[id]
	if definition and definition.getRandomStartingAmmo then
		return definition.getRandomStartingAmmo()
	end

	local minAmmo = (definition and definition.startingAmmoMin) or 10
	local maxAmmo = (definition and definition.startingAmmoMax) or minAmmo
	if maxAmmo < minAmmo then
		maxAmmo = minAmmo
	end

	return math.random(minAmmo, maxAmmo)
end

function WeaponTypes.rollAmmo(id, dieValue)
	local definition = registry[id]
	if definition and definition.rollAmmo then
		return definition.rollAmmo(dieValue)
	end
	return dieValue
end

function WeaponTypes.getHitMode(id)
	local definition = registry[id]
	return (definition and definition.hitMode) or "closest_once"
end