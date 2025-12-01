local expandCollapse = {
  mapMenu = nil,
  traceEnabled = false
}

function expandCollapse:debug(message)
  local text = "ExpandCollapse: " .. message
  if type(DebugError) == "function" then
    DebugError(text)
  end
end

function expandCollapse:trace(message)
  ---@diagnostic disable-next-line: unnecessary-if
  if self.traceEnabled then
    self:debug(message)
  end
end

function expandCollapse:isAnyExpanded()
  self:debug("Checking if any sections are expanded")
  local menu = self.mapMenu
  ---@diagnostic disable-next-line: undefined-field
  if (menu ~= nil and type(menu.extendedproperty) == "table") then
    ---@diagnostic disable-next-line: undefined-field
    for key, _ in pairs(menu.extendedproperty) do
      if (key ~= nil and type(key) == "string" and string.len(key) > 0) then
        if string.sub(key, 1, 3) == "ID:" then
          self:trace("Found expanded object: " .. key)
          return true
        end
      end
    end
  end
  return false
end

function expandCollapse:expandArray(array, infoTableData)
  self:debug("Expanding array with " .. tostring(#array) .. " items")
  local processed = 0
  ---@diagnostic disable-next-line: undefined-field
  if self.mapMenu ~= nil and self.mapMenu.extendedproperty ~= nil then
    for i = 1, #array do
      local object = array[i]
      if object ~= nil then
        local component = tostring(object)
        local realClassId = GetComponentData(object, "realclassid") or nil
        local isStation = realClassId ~= nil and Helper.isComponentClass(realClassId, "station") or false
        local subordinates = infoTableData.subordinates[component] or {}
        local dockedShips = infoTableData.dockedships[component] or {}
        local constructions = infoTableData.constructions[component] or {}
        local subordinateFound = false
        for _, subordinate in ipairs(subordinates) do
          if (subordinate.component and (infoTableData.fleetUnitSubordinates[tostring(subordinate.component)] ~= true)) or subordinate.fleetunit then
            subordinateFound = true
            break
          end
        end
        if subordinates.hasRendered and subordinateFound or (#dockedShips > 0) or (isStation and (#constructions > 0)) then
          self.mapMenu.extendedproperty[component] = true
          self:trace("Expanding station ID: " .. tostring(component))
          processed = processed + 1
        end
      end
    end
  end
  return processed
end

function expandCollapse:process(isAnyExpanded, infoTableData)
  self:debug("Expand All button clicked when isAnyExpanded is " .. tostring(isAnyExpanded))
  local processed = 0
  if self.mapMenu == nil then
    self:debug("MapMenu is nil; cannot process")
    return
  end
  local menu = self.mapMenu
  if isAnyExpanded then
    self:debug("Collapsing all sections")
    -- Placeholder logic; replace with actual implementation
    ---@diagnostic disable-next-line: undefined-field
    if type(menu.extendedproperty) == "table" then
      ---@diagnostic disable-next-line: undefined-field
      for key, _ in pairs(menu.extendedproperty) do
        if (key ~= nil and type(key) == "string" and string.len(key) > 0) then
          if string.sub(key, 1, 3) == "ID:" then
            self:trace("Collapsing object: " .. key)
            ---@diagnostic disable-next-line: undefined-field
            menu.extendedproperty[key] = nil
            processed = processed + 1
          end
        end
      end
      processed = processed + #menu.extendedmoduletypes
      menu.extendedmoduletypes = {}
      processed = processed + #menu.extendeddockedships
      menu.extendeddockedships = {}
      processed = processed + #menu.extendedconstruction
      menu.extendedconstruction = {}
    end
    self:debug("All sections collapsed")
    ---@diagnostic disable-next-line: undefined-field
  elseif type(menu.propertyMode) == "string" then
    ---@diagnostic disable-next-line: undefined-field
    if (menu.propertyMode == "stations") or (menu.propertyMode == "propertyall") then
      processed = processed + self:expandArray(infoTableData.stations or {}, infoTableData)
    end
    if (menu.propertyMode == "fleets") or (menu.propertyMode == "propertyall") then
      processed = processed + self:expandArray(infoTableData.fleetLeaderShips or {}, infoTableData)
    end
    if (menu.propertyMode == "unassignedships") or (menu.propertyMode == "propertyall") then
      processed = processed + self:expandArray(infoTableData.unassignedShips or {}, infoTableData)
    end
  else
    self:debug("MapMenu or propertyMode is invalid; cannot expand all")
  end
  if type(menu.refreshInfoFrame) == "function" and processed > 0 then
    menu.refreshInfoFrame()
  end
end

function expandCollapse:addButton(numdisplayed, instance, ftable, infoTableData)
  self:debug("Adding Expand All button")
  if self.mapMenu == nil then
    self:debug("MapMenu is nil; cannot process")
    return
  end
  local menu = self.mapMenu
  if menu.propertyMode == "propertyall" or menu.propertyMode == "stations" or menu.propertyMode == "fleets" or menu.propertyMode == "unassignedships" then
    if numdisplayed > 0 and ftable ~= nil and ftable.rows ~= nil and type(ftable.rows[1]) == "table" then
      local headerRow = ftable.rows[1]
      if (headerRow[1] ~= nil and type(headerRow[1]) == "table") then
        local colSpan = headerRow[1].colspan - 1
        local headerTitle = headerRow[1] and headerRow[1].properties and headerRow[1].properties.text or ReadText(1001, 1000)
        local row = ftable:addRow(true, { fixed = true, bgColor = Color["row_title_background"] })
        ftable.rows[1] = row
        headerRow = ftable.rows[1]
        headerRow.index = 1
        table.remove(ftable.rows, #ftable.rows)
        headerRow[2]:setColSpan(colSpan):createText(headerTitle, Helper.headerRowCenteredProperties)
        local isAnyExpanded = self:isAnyExpanded()
        headerRow[1]:createButton({ scaling = false }):setText(isAnyExpanded and "-" or "+", { scaling = true, halign = "center" })
        headerRow[1].handlers.onClick = function() self:process(isAnyExpanded, infoTableData) end
      end
    end
  end
end

local function bind(obj, methodName)
  return function(...)
    return obj[methodName](obj, ...)
  end
end

local function Init()
  local menu = Helper.getMenu("MapMenu")
  ---@diagnostic disable-next-line: undefined-field
  if menu ~= nil and type(menu.registerCallback) == "function" then
    ---@diagnostic disable-next-line: undefined-field
    menu.registerCallback("createPropertyOwned_on_createPropertySection_unassignedships", bind(expandCollapse, "addButton"))
    expandCollapse.mapMenu = menu
    expandCollapse:debug("Registered callback for Expand/Collapse button")
  else
    expandCollapse:debug("Failed to get MapMenu or registerCallback is not a function")
  end
end

Init()
