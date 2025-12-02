local ffi = require("ffi")
local C = ffi.C

ffi.cdef [[
  typedef uint64_t UniverseID;

	UniverseID GetPlayerID(void);
]]

local traceEnabled = false

local expandCollapse = {
  mapMenu = nil,
}

local playerId = nil
local customTabsBlackBoardDataName = "$customTabsData"

function debug(message)
  local text = "ExpandCollapse: " .. message
  if type(DebugError) == "function" then
    DebugError(text)
  end
end

function trace(message)
  ---@diagnostic disable-next-line: unnecessary-if
  if traceEnabled then
    debug(message)
  end
end

local function isInArray(value, array)
  for i = 1, #array do
    if tostring(array[i]) == value then
      return true
    end
  end
  return false
end

local function getCustomTabNumber(mode)
  if string.len(mode) > 11 and string.sub(mode, 1, 11) == "custom_tab_" then
    local tabNumberStr = string.sub(mode, 12)
    local tabNumber = tonumber(tabNumberStr)
    if tabNumber ~= nil then
      return tabNumber
    end
  end
  return 0
end



local function removeFromArrayWithId(value, array)
  for i = #array, 1, -1 do
    if array[i].id ~= nil and tostring(array[i].id) == value then
      table.remove(array, i)
    end
  end
end

function expandCollapse:isAnyExpanded(mode, infoTableData)
  debug("Checking if any sections are expanded")
  local menu = self.mapMenu
  local data = nil
  ---@diagnostic disable-next-line: undefined-field
  if (menu ~= nil and type(menu.extendedproperty) == "table") then
    ---@diagnostic disable-next-line: undefined-field
    for key, _ in pairs(menu.extendedproperty) do
      if (key ~= nil and type(key) == "string" and string.len(key) > 0) then
        if string.sub(key, 1, 3) == "ID:" then
          if data == nil then
            data = self:getTabData(mode, infoTableData) or {}
          end
          if isInArray(key, data) then
            trace("Found expanded object: " .. key)
            return true
          end
        end
      end
    end
  end
  return false
end

function expandCollapse:expandArray(array, infoTableData)
  debug("Expanding array with " .. tostring(#array) .. " items")
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
        for i = 1, #subordinates do
          local subordinate = subordinates[i]
          if (subordinate.component and (infoTableData.fleetUnitSubordinates[tostring(subordinate.component)] ~= true)) or subordinate.fleetunit then
            subordinateFound = true
            break
          end
        end
        if subordinates.hasRendered and subordinateFound or (#dockedShips > 0) or (isStation and (#constructions > 0)) then
          self.mapMenu.extendedproperty[component] = true
          trace("Expanding station ID: " .. tostring(component))
          processed = processed + 1
        end
      end
    end
  end
  return processed
end

function expandCollapse:getTabData(mode, infoTableData)
  debug("Getting tab data for mode: " .. tostring(mode))
  local result = {}
  local customTabNumber = getCustomTabNumber(mode)
  local tabData = {}
  if customTabNumber > 0 then
    if playerId ~= nil then
      local customTabsData = GetNPCBlackboard(playerId, customTabsBlackBoardDataName) or {}
      if customTabNumber <= #customTabsData then
        tabData = customTabsData[customTabNumber] or {}
      end
    end
  end
  if mode == "stations" or mode == "propertyall" or #tabData > 0 then
    for i = 1, #infoTableData.stations do
      local object = infoTableData.stations[i]
      if #tabData == 0 or isInArray(tostring(object), tabData) then
        result[#result + 1] = object
      end
    end
  end
  if mode == "fleets" or mode == "propertyall" or #tabData > 0 then
    for i = 1, #infoTableData.fleetLeaderShips do
      local object = infoTableData.fleetLeaderShips[i]
      if #tabData == 0 or isInArray(tostring(object), tabData) then
        result[#result + 1] = object
      end
    end
  end
  if mode == "unassignedships" or mode == "propertyall" or #tabData > 0 then
    for i = 1, #infoTableData.unassignedShips do
      local object = infoTableData.unassignedShips[i]
      if #tabData == 0 or isInArray(tostring(object), tabData) then
        result[#result + 1] = object
      end
    end
  end
  return result
end

function expandCollapse:process(isAnyExpanded, infoTableData)
  debug("Expand All button clicked when isAnyExpanded is " .. tostring(isAnyExpanded))
  local processed = 0
  if self.mapMenu == nil then
    debug("MapMenu is nil; cannot process")
    return
  end
  local menu = self.mapMenu
  local data = self:getTabData(menu.propertyMode, infoTableData)
  if isAnyExpanded then
    debug("Collapsing all sections")
    if type(menu.extendedproperty) == "table" then
      for i = 1, #data do
        local component = tostring(data[i])
        if menu.extendedproperty[component] ~= nil then
          menu.extendedproperty[component] = nil
          if #menu.extendedmoduletypes > 0 then
            removeFromArrayWithId(component, menu.extendedmoduletypes)
          end
          if #menu.extendeddockedships > 0 then
            removeFromArrayWithId(component, menu.extendeddockedships)
          end
          if #menu.extendedconstruction > 0 then
            removeFromArrayWithId(component, menu.extendedconstruction)
          end
          processed = processed + 1
        end
      end
    end
    debug("All sections collapsed")
  elseif type(menu.propertyMode) == "string" then
    processed = processed + self:expandArray(data, infoTableData)
  else
    debug("MapMenu or propertyMode is invalid; cannot expand all")
  end
  if type(menu.refreshInfoFrame) == "function" and processed > 0 then
    menu.refreshInfoFrame()
  end
end

function expandCollapse:addButton(numdisplayed, instance, ftable, infoTableData)
  debug("Adding Expand All button")
  if self.mapMenu == nil then
    debug("MapMenu is nil; cannot process")
    return
  end
  local menu = self.mapMenu
  local mode = menu.propertyMode
  if type(mode) ~= "string" or string.len(mode) < 3 then
    debug("Invalid propertyMode; cannot add button")
    return
  end
  local isCustomTab = getCustomTabNumber(mode) > 0
  if mode == "propertyall" or mode == "stations" or mode == "fleets" or mode == "unassignedships" or isCustomTab then
    if (isCustomTab or numdisplayed > 0) and ftable ~= nil and ftable.rows ~= nil and type(ftable.rows[1]) == "table" then
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
        local isAnyExpanded = self:isAnyExpanded(mode, infoTableData)
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
  playerId = ConvertStringTo64Bit(tostring(C.GetPlayerID()))
  debug("Initializing Expand/Collapse UI extension with PlayerID: " .. tostring(playerId))
  local menu = Helper.getMenu("MapMenu")
  ---@diagnostic disable-next-line: undefined-field
  if menu ~= nil and type(menu.registerCallback) == "function" then
    ---@diagnostic disable-next-line: undefined-field
    menu.registerCallback("createPropertyOwned_on_createPropertySection_unassignedships", bind(expandCollapse, "addButton"))
    expandCollapse.mapMenu = menu
    debug("Registered callback for Expand/Collapse button")
  else
    debug("Failed to get MapMenu or registerCallback is not a function")
  end
end


Register_OnLoad_Init(Init)
