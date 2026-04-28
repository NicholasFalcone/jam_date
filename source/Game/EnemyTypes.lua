EnemyTypes = {}

local enemyTypes = {
    {
        id = "scout",
        name = "Scout",
        spritePath = "Sprites/Enemies/Enemy_01",
        health = 100,
        speed = 0.0056,
        spawnWeight = 45,
        hitboxScale = 0.8, 
        hitboxScaleX = 1,      
        hitboxOffsetY = 15,     
    },
    {
        id = "raider",
        name = "Raider",
        spritePath = "Sprites/Enemies/Enemy_02",
        health = 80,
        speed = 0.0050,
        spawnWeight = 35,
        hitboxScale = 0.45,
        hitboxScaleX = 2,         
        hitboxOffsetY = -15,     

        -- Oscillazione orizzontale mentre avanza
        oscillationEnabled = true,
        oscillationAmplitude = 0.15,  -- Ampiezza dell'oscillazione (frazione della larghezza della corsia)
        oscillationFrequency = 2.5,   -- Velocità dell'oscillazione
    },
    {
        id = "brute",
        name = "Brute",
        spritePath = "Sprites/Enemies/Enemy_03",
        health = 140,
        speed = 0.0042,
        spawnWeight = 20,
        hitboxScale = 0.7,  
        hitboxScaleX = 1,         
     
    hitboxOffsetY = 20,     

    },
}

local enemyTypesById = {}

for _, enemyType in ipairs(enemyTypes) do
    enemyTypesById[enemyType.id] = enemyType
end

function EnemyTypes.getAll()
    return enemyTypes
end

function EnemyTypes.getById(id)
    return enemyTypesById[id]
end

function EnemyTypes.rollSpawnType()
    local totalWeight = 0

    for _, enemyType in ipairs(enemyTypes) do
        totalWeight += math.max(0, enemyType.spawnWeight or 0)
    end

    if totalWeight <= 0 then
        return enemyTypes[1]
    end

    local roll = math.random() * totalWeight
    local cumulativeWeight = 0

    for _, enemyType in ipairs(enemyTypes) do
        cumulativeWeight += math.max(0, enemyType.spawnWeight or 0)
        if roll <= cumulativeWeight then
            return enemyType
        end
    end

    return enemyTypes[#enemyTypes]
end