local enableLogging = settings.startup["enable-rfixer-logging"].value
if enableLogging then
    log("=== Research Fixer: Starting ===")
    local techCount = 0
    for techName, techData in pairs(data.raw.technology) do
        techCount = techCount + 1
    end
    log("Total tech count: " .. techCount)
end

-- On vanilla researches this is redundant, but it could be useful if I implement compatibility with some other mod adding custom science packs (e.g. maybe Krastorio?)
local sciencePackToTech = {
    ["automation-science-pack"] = "automation-science-pack",
    ["logistic-science-pack"] = "logistic-science-pack",
    ["military-science-pack"] = "military-science-pack",
    ["chemical-science-pack"] = "chemical-science-pack",
    ["production-science-pack"] = "production-science-pack",
    ["utility-science-pack"] = "utility-science-pack",
    ["space-science-pack"] = "space-science-pack",
}

local debugResearches = {}
local debug = false

local function hasPrereqInChain(techName, targetTechName, visited)
    visited = visited or {}

    if visited[techName] then
        return false
    end
    visited[techName] = true

    local tech = data.raw.technology[techName]
    if not tech or not tech.prerequisites then
        if debug and enableLogging then log("DEBUG: " .. techName .. " has no prereqs!") end
        return false
    end

    for _, prereq in ipairs(tech.prerequisites) do
        if prereq == targetTechName then
            if debug and enableLogging then log("DEBUG: " .. techName .. " has the prereq of " .. targetTechName) end
            return true
        end
        if hasPrereqInChain(prereq, targetTechName, visited) then
            return true
        end
    end

    if debug and enableLogging then log("DEBUG: " .. techName .. " does not have the prereq of " .. targetTechName) end
    return false
end

local processed = {}
local modificationsMade = 0
local function processTech(techName)
    if processed[techName] then
        return
    end
    if debugResearches[techName] then debug = true end
    processed[techName] = true

    local techData = data.raw.technology[techName]
    if not techData then
        return
    end

    -- We loop over prereqs here to ensure we only add science requirements to the first one in a series, instead of all the researches in said series    
    -- We still only process each research once overall, due to the `processed` table
    if techData.prerequisites then
        for _, prereq in ipairs(techData.prerequisites) do
            processTech(prereq)
        end
    end

    if techData.unit and techData.unit.ingredients then
        for _, ingredient in ipairs(techData.unit.ingredients) do
            local ingredientName = ingredient[1] or ingredient.name
            local requiredTech = sciencePackToTech[ingredientName]

            if requiredTech and data.raw.technology[requiredTech] then
                local prereqs = techData.prerequisites
                local prereqsStr = (prereqs and next(prereqs) ~= nil) and table.concat(prereqs, ", ") or "NONE"
                if debug and enableLogging then log("DEBUG: " .. techName .. " has prereqs " .. prereqsStr) end
                if not hasPrereqInChain(techName, requiredTech) then
                    if not techData.prerequisites then
                        techData.prerequisites = {}
                    end
                    table.insert(techData.prerequisites, requiredTech)
                    modificationsMade = modificationsMade + 1
                    if enableLogging then log("Modified: " .. techName .. " now requires " .. requiredTech .. ", previously only required the following: " .. prereqsStr) end
                end
            end
        end
    end
    if debugResearches[techName] then debug = false end
end

for techName in pairs(data.raw.technology) do
    processTech(techName)
end

if enableLogging then log("=== Research Fixer: Complete. Made " .. modificationsMade .. " modifications ===") end
