local ffi = require("ffi")
local C = ffi.C

ffi.cdef [[
  typedef uint64_t UniverseID;

	UniverseID GetPlayerID(void);

  typedef struct {
    int major;
    int minor;
  } GameVersion;

  GameVersion GetGameVersion();
]]

local traceEnabled = false

local expandCollapse = {
  mapMenu = nil,
  gameVersion = C.GetGameVersion(),
  sortByText = ""
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

function expandCollapse:addButton(numdisplayed, instance, currentTable, infoTableData)
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
    if (isCustomTab or numdisplayed > 0) and currentTable ~= nil and currentTable.rows ~= nil and type(currentTable.rows[1]) == "table" then
      local headerRowIndex = 1
      if self.gameVersion.major == 9 then
        for i = 2, #currentTable.rows do
          if currentTable.rows[i].rowdata == nil or currentTable.rows[i].rowdata == nil then
            local cell = currentTable.rows[i][1]
            if cell ~= nil and cell.type == "text" and cell.properties.text == expandCollapse.sortByText then
              headerRowIndex = i
              break
            end
          end
        end
        if headerRowIndex ~= 1 and headerRowIndex < #currentTable.rows then
          debug("Found sub-title row at index: " .. tostring(headerRowIndex))
        else
          debug("Header row not found; exiting without adding button")
          return
        end
      end
      local headerRow = currentTable.rows[headerRowIndex]
      local headerRowProperties = headerRow.properties or {}
      local headerRowHeight = headerRow:getHeight()
      if (headerRow[1] ~= nil and type(headerRow[1]) == "table") then
        local colSpan = (headerRow[1].colspan == currentTable.numcolumns) and (headerRow[1].colspan - 1) or headerRow[1].colspan
        local cellProperties = headerRow[1].properties or {}
        local headerTitle = cellProperties and cellProperties.text or ""
        local row = currentTable:addRow(true, headerRowProperties)
        currentTable.rows[headerRowIndex] = row
        headerRow = currentTable.rows[headerRowIndex]
        headerRow.index = headerRowIndex
        table.remove(currentTable.rows, #currentTable.rows)
        headerRow[2]:setColSpan(colSpan):createText(headerTitle, cellProperties)
        local isAnyExpanded = self:isAnyExpanded(mode, infoTableData)
        local buttonProperties = { scaling = false }
        if self.gameVersion.major == 9 then
          buttonProperties.height = headerRowHeight
          buttonProperties.affectRowHeight = false
          buttonProperties.x = Helper.standardContainerOffset
        end
        headerRow[1]:createButton(buttonProperties):setText(isAnyExpanded and "-" or "+", { scaling = true, halign = "center" })
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
  if expandCollapse.gameVersion.major ~= 8 and false then
    debug("Unsupported game version: " .. tostring(expandCollapse.gameVersion.major) .. "." .. tostring(expandCollapse.gameVersion.minor) .. ". Expand/Collapse UI extension will not be initialized.")
    return
  end
  playerId = ConvertStringTo64Bit(tostring(C.GetPlayerID()))
  debug("Initializing Expand/Collapse UI extension with PlayerID: " .. tostring(playerId))
  local menu = Helper.getMenu("MapMenu")
  ---@diagnostic disable-next-line: undefined-field
  if menu ~= nil and type(menu.registerCallback) == "function" then
    ---@diagnostic disable-next-line: undefined-field
    if expandCollapse.gameVersion.major == 8 then
      menu.registerCallback("createPropertyOwned_on_createPropertySection_unassignedships", bind(expandCollapse, "addButton"))
    elseif expandCollapse.gameVersion.major == 9 then
      menu.registerCallback("createPropertyOwned_on_tabtable_end", bind(expandCollapse, "addButton"))
    end

    expandCollapse.mapMenu = menu
    expandCollapse.sortByText = (ReadText(1001, 2906) .. ReadText(1001, 120)) or ""
    debug("Registered callback for Expand/Collapse button")
  else
    debug("Failed to get MapMenu or registerCallback is not a function")
  end
end


Register_OnLoad_Init(Init)
