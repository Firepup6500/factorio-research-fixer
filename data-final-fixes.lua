log("=== Research Fixer: Starting ===")
local tech_count = 0
for tech_name, tech_data in pairs(data.raw.technology) do
    tech_count = tech_count + 1
-- Debugging stuff
--    if tech_data.unit and tech_data.unit.ingredients then
--        local ingredients_str = ""
--        for _, ing in ipairs(tech_data.unit.ingredients) do
--            local ing_name = ing[1] or ing.name
--            ingredients_str = ingredients_str .. ing_name .. ", "
--        end
--        log("Tech: " .. tech_name .. " | Ingredients: " .. ingredients_str .. " | Prerequisites: " .. (tech_data.prerequisites and table.concat(tech_data.prerequisites, ", ") or "NONE"))
--    end
end
log("Total tech count: " .. tech_count)

-- On vanilla researches this is redundant, but it could be useful if I implement compatibility with some other mod adding custom science packs, and it also has the issue that this mod fixes
local science_pack_to_tech = {
    ["automation-science-pack"] = "automation-science-pack",
    ["logistic-science-pack"] = "logistic-science-pack",
    ["military-science-pack"] = "military-science-pack",
    ["chemical-science-pack"] = "chemical-science-pack",
    ["production-science-pack"] = "production-science-pack",
    ["utility-science-pack"] = "utility-science-pack",
    ["space-science-pack"] = "space-science-pack",
}

local debug_researches = {}
local debug = false

local researches_that_lie = {}

-- There's some researches that we *try* to fix that we shouldn't, due to it having no effect in the UI other than saying we modified the research
-- It's also stored as a table instead of a list here, to let us look up truthful values on it, to save some code elsewhere
local skip_fixes = {}

local function should_skip_prereq_for_tech(prereq_tech_name, target_tech_name)
    if researches_that_lie[prereq_tech_name] then
        for _, pack in ipairs(researches_that_lie[prereq_tech_name]) do
            local required_tech = science_pack_to_tech[pack]
            if required_tech == target_tech_name then
                return true
            end
        end
    end
    return false
end

local function has_prerequisite_in_chain(tech_name, target_tech_name, visited)
    visited = visited or {}

    if visited[tech_name] then
        return false
    end
    visited[tech_name] = true

    local tech = data.raw.technology[tech_name]
    if not tech or not tech.prerequisites then
        if debug then log("DEBUG: " .. tech_name .. " has no prereqs!") end
        return false
    end

    if should_skip_prereq_for_tech(tech_name, target_tech_name) then
        return false
    end

    for _, prereq in ipairs(tech.prerequisites) do
        if prereq == target_tech_name then
            if debug then log("DEBUG: " .. tech_name .. " has the prereq of " .. target_tech_name) end
            return true
        end
        if not should_skip_prereq_for_tech(prereq, target_tech_name) and has_prerequisite_in_chain(prereq, target_tech_name, visited) then
            return true
        end
    end

    if debug then log("DEBUG: " .. tech_name .. " does not have the prereq of " .. target_tech_name) end
    return false
end

local processed = {}
local modifications_made = 0
local debugging = ""
local function process_tech(tech_name)
    if processed[tech_name] then
        return
    end
    if skip_fixes[tech_name] then
        return
    end
    if debug_researches[tech_name] then debug = true end
    processed[tech_name] = true

    local tech_data = data.raw.technology[tech_name]
    if not tech_data then
        return
    end

    -- We loop over prereqs here to ensure we only add science requirements to the first one in a series, instead of all the researches in said series    
    if tech_data.prerequisites then
        for _, prereq in ipairs(tech_data.prerequisites) do
            process_tech(prereq)
        end
    end

    if tech_data.unit and tech_data.unit.ingredients then
        for _, ingredient in ipairs(tech_data.unit.ingredients) do
            local ingredient_name = ingredient[1] or ingredient.name
            local required_tech = science_pack_to_tech[ingredient_name]

            if required_tech and data.raw.technology[required_tech] then
                local prereqs = tech_data.prerequisites
                local prereqs_str = (prereqs and next(prereqs) ~= nil) and table.concat(prereqs, ", ") or "NONE"
                if debug then log("DEBUG: " .. tech_name .. " has prereqs " .. prereqs_str) end
                if not has_prerequisite_in_chain(tech_name, required_tech) then
                    if not tech_data.prerequisites then
                        tech_data.prerequisites = {}
                    end
                    table.insert(tech_data.prerequisites, required_tech)
                    modifications_made = modifications_made + 1
                    log("Modified: " .. tech_name .. " now requires " .. required_tech .. ", previously only required the following: " .. prereqs_str)
                end
            end
        end
    end
    if debug_researches[tech_name] then debug = false end
end

for tech_name in pairs(data.raw.technology) do
    process_tech(tech_name)
end

log("=== Research Fixer: Complete. Made " .. modifications_made .. " modifications ===")
