
local function niceName(name)
    local base = string.NiceName(string.sub(name, 5))
    local words = string.Split(base, " ")
    for i, word in ipairs(words) do
        if string.lower(word) == "smh" or string.lower(word) == "rgm" then
            words[i] = string.upper(word)
            continue
        end

        local firstLetter = word[1]
        words[i] = string.gsub(word, firstLetter, string.upper(firstLetter), 1)
    end
    return table.concat(words, " ")
end

---@param cPanel ControlPanel
local function settings(cPanel)
    SMH.UI.Open()
    SMH.UI.Close()

    ---Helper for DForm
    ---@param cPanel ControlPanel|DForm
    ---@param name string
    ---@param type "ControlPanel"|"DForm"
    ---@return ControlPanel|DForm
    local function makeCategory(cPanel, name, type)
        ---@type DForm|ControlPanel
        local category = vgui.Create(type, cPanel)

        category:SetLabel(name)
        cPanel:AddItem(category)
        return category
    end

    cPanel:Help("This is a dump of all of the clientside SMH console variables")
    cPanel:Help("If they have help text, a tooltip will display if you hover over them")

    local cvars = SMH.ConVars.Get()
    ---@type table<string, DForm|ControlPanel>
    local categories = {}
    for name, cvarInfo in pairs(cvars) do
        local categoryName = cvarInfo.category
        local categoryId = string.lower(categoryName)
        local category = categories[categoryId] or makeCategory(cPanel, categoryName, "ControlPanel")
        categories[categoryId] = category

        ---@type Panel
        local panel
        local helpText = cvarInfo.helptext
        local niceName = niceName(name)

        if cvarInfo.type == TYPE_NUMBER then
            local cvar = cvarInfo.cvar
            panel = category:NumSlider(niceName, name, cvar:GetMin() or 0, cvar:GetMax() or 100, 3)
        elseif cvarInfo.type == TYPE_BOOL then
            panel = category:CheckBox(niceName, name)
        else
            panel = category:TextEntry(niceName, name)
        end
        panel:SetTooltip(helpText)
    end
end

hook.Add( "AddToolMenuCategories", "SMHCategory", function()
    spawnmenu.AddToolCategory( "Utilities", "smh", "Stop Motion Helper" )
end )
hook.Add( "PopulateToolMenu", "SMHSettings", function()
    spawnmenu.AddToolMenuOption( "Utilities", "smh", "smh_settings", "Settings", "", "", settings) -- Add an entry to our new category
end)
