local PalNames = require("pal_names")

print("[LuckyTracker] Loaded successfully!\n")

local HookInstalled = false
local LuckyCounts = {}

local TrackerVisible = false

local HeaderWidget = nil
local ColumnWidgets = {}

local PlayerController = nil

local SaveFileName = "LuckyTracker_counts.txt"

local TrackerWidgetClassPath =
    "/Game/Pal/Blueprint/UI/UserInterface/MainMenu/WBP_NoData.WBP_NoData_C"

------------------------------------------------
-- TRACKER LAYOUT
------------------------------------------------

local MaxRowsPerColumn = 10

local HeaderX = -785.0
local HeaderY = -175.0

local FirstColumnX = -800.0
local ColumnSpacing = 260.0

-- Column 1 stays at the position we already perfected.
local ColumnY = 0.0

-- Columns 2+ are moved upward so their first row
-- lines up with the first row of column 1.
local ExtraColumnY = -110.0


------------------------------------------------
-- LOAD SAVED COUNTS
------------------------------------------------

local function LoadLuckyCounts()

    local File, Error =
        io.open(SaveFileName, "r")

    if not File then

        print("[LuckyTracker] No existing count file found.\n")
        print("[LuckyTracker] A new one will be created after the first Lucky capture.\n")

        return
    end

    for Line in File:lines() do

        local SpeciesID, Count =
            Line:match("^([^=]+)=(%d+)$")

        if SpeciesID and Count then

            LuckyCounts[SpeciesID] =
                tonumber(Count)

            local PalName =
                PalNames[SpeciesID]
                or SpeciesID

            print(
                "[LuckyTracker] Loaded "
                .. PalName
                .. " ("
                .. SpeciesID
                .. ") = "
                .. tostring(LuckyCounts[SpeciesID])
                .. "\n"
            )
        end
    end

    File:close()

    print("[LuckyTracker] Lucky counts loaded successfully!\n")
end


------------------------------------------------
-- SAVE COUNTS
------------------------------------------------

local function SaveLuckyCounts()

    local File, Error =
        io.open(
            SaveFileName,
            "w"
        )

    if not File then

        print(
            "[LuckyTracker] Could not open count file for writing: "
            .. tostring(Error)
            .. "\n"
        )

        return false
    end

    local SpeciesList = {}

    for SpeciesID, _ in pairs(LuckyCounts) do
        table.insert(SpeciesList, SpeciesID)
    end

    table.sort(SpeciesList)

    for _, SpeciesID in ipairs(SpeciesList) do

        File:write(
            SpeciesID
            .. "="
            .. tostring(LuckyCounts[SpeciesID])
            .. "\n"
        )
    end

    File:flush()
    File:close()

    print("[LuckyTracker] Lucky counts saved!\n")

    return true
end


------------------------------------------------
-- GET SORTED PAL LIST
------------------------------------------------

local function GetSortedPalList()

    local SpeciesList = {}

    for SpeciesID, Count in pairs(LuckyCounts) do

        table.insert(
            SpeciesList,
            {
                ID = SpeciesID,
                Name = PalNames[SpeciesID] or SpeciesID,
                Count = Count
            }
        )
    end

    table.sort(
        SpeciesList,
        function(A, B)
            return A.Name < B.Name
        end
    )

    return SpeciesList
end


------------------------------------------------
-- BUILD AUTOMATIC COLUMNS
------------------------------------------------

local function BuildTrackerColumns()

    local SpeciesList =
        GetSortedPalList()

    local Columns = {}

    if #SpeciesList == 0 then

        Columns[1] =
            "No Lucky Pals captured yet."

        return Columns
    end

    for Index, Pal in ipairs(SpeciesList) do

        local ColumnIndex =
            math.floor(
                (Index - 1)
                / MaxRowsPerColumn
            ) + 1

        if not Columns[ColumnIndex] then
            Columns[ColumnIndex] = {}
        end

        table.insert(
            Columns[ColumnIndex],
            Pal.Name
            .. "  "
            .. tostring(Pal.Count)
        )
    end

    for ColumnIndex, ColumnLines in ipairs(Columns) do

        if type(ColumnLines) == "table" then

            Columns[ColumnIndex] =
                table.concat(
                    ColumnLines,
                    "\n"
                )
        end
    end

    return Columns
end


------------------------------------------------
-- HIDE DECORATIVE IMAGES
------------------------------------------------

local function HideDecorativeImages(Widget)

    local DecorativeImages = {
        Widget.Image,
        Widget.Image_1,
        Widget.Image_2,
        Widget.Image_3,
        Widget.Image_4,
        Widget.Image_5,
        Widget.Image_32,
        Widget.Image_80,
        Widget.Image_142
    }

    local HiddenImageCount = 0

    for _, ImageWidget in ipairs(DecorativeImages) do

        if ImageWidget then

            local HideSuccess,
                HideError =
                pcall(
                    function()
                        ImageWidget:SetRenderOpacity(0.0)
                    end
                )

            if HideSuccess then

                HiddenImageCount =
                    HiddenImageCount + 1

            else

                print(
                    "[LuckyTracker] Could not hide decorative image: "
                    .. tostring(HideError)
                    .. "\n"
                )
            end
        end
    end

    return HiddenImageCount
end


------------------------------------------------
-- APPLY TEXT SHADOW
------------------------------------------------

local function ApplyTextShadow(TextChild)

    TextChild:SetShadowOffset(
        {
            X = 2.0,
            Y = 2.0
        }
    )

    TextChild:SetShadowColorAndOpacity(
        {
            R = 0.0,
            G = 0.0,
            B = 0.0,
            A = 0.9
        }
    )
end


------------------------------------------------
-- CREATE ONE TRACKER WIDGET
------------------------------------------------

local function CreateTrackerWidget(
    WidgetLibrary,
    WidgetClass,
    Text,
    X,
    Y,
    Justification
)

    local Widget =
        WidgetLibrary:Create(
            PlayerController,
            WidgetClass,
            PlayerController
        )

    if not Widget then

        print(
            "[LuckyTracker] UI ERROR: Widget creation returned nil.\n"
        )

        return nil
    end

    local TextChild =
        Widget.BP_PalTextBlock_C

    if not TextChild then

        print(
            "[LuckyTracker] UI ERROR: BP_PalTextBlock_C was nil.\n"
        )

        return nil
    end

    local HiddenImageCount =
        HideDecorativeImages(
            Widget
        )

    print(
        "[LuckyTracker] Hidden decorative images: "
        .. tostring(HiddenImageCount)
        .. "\n"
    )

    TextChild:SetRenderTranslation(
        {
            X = X,
            Y = Y
        }
    )

    TextChild:SetJustification(
        Justification
    )

    ApplyTextShadow(
        TextChild
    )

    Widget:SetText(
        FText(Text)
    )

    return Widget
end


------------------------------------------------
-- REMOVE COLUMN WIDGETS
------------------------------------------------

local function RemoveColumnWidgets()

    for _, Widget in ipairs(ColumnWidgets) do

        if Widget then

            pcall(
                function()
                    Widget:RemoveFromParent()
                end
            )
        end
    end

    ColumnWidgets = {}
end


------------------------------------------------
-- CREATE ALL COLUMN WIDGETS
------------------------------------------------

local function CreateColumnWidgets(
    WidgetLibrary,
    WidgetClass,
    HUDLayout
)

    local ColumnTexts =
        BuildTrackerColumns()

    for ColumnIndex, ColumnText in ipairs(ColumnTexts) do

        local ColumnX =
            FirstColumnX
            + (
                (ColumnIndex - 1)
                * ColumnSpacing
            )

        local ThisColumnY =
            ColumnY

        if ColumnIndex > 1 then
            ThisColumnY = ExtraColumnY
        end

        local NewColumnWidget =
            CreateTrackerWidget(
                WidgetLibrary,
                WidgetClass,
                ColumnText,
                ColumnX,
                ThisColumnY,
                0
            )

        if not NewColumnWidget then

            print(
                "[LuckyTracker] UI ERROR: Column "
                .. tostring(ColumnIndex)
                .. " failed to create.\n"
            )

            return false
        end

        HUDLayout:AddHUD(
            NewColumnWidget,
            1000
        )

        table.insert(
            ColumnWidgets,
            NewColumnWidget
        )

        print(
            "[LuckyTracker] Created column "
            .. tostring(ColumnIndex)
            .. " at X = "
            .. tostring(ColumnX)
            .. ", Y = "
            .. tostring(ThisColumnY)
            .. "\n"
        )
    end

    return true
end


------------------------------------------------
-- REFRESH OPEN TRACKER
------------------------------------------------

local function RefreshTracker()

    if not TrackerVisible then
        return
    end

    ExecuteInGameThread(
        function()

            local Success, Error =
                pcall(
                    function()

                        if not PlayerController then
                            return
                        end

                        local HUD =
                            PlayerController:GetHUD()

                        if not HUD then
                            return
                        end

                        local HUDLayout =
                            HUD.HUDLayout

                        if not HUDLayout then
                            return
                        end

                        local WidgetClass =
                            StaticFindObject(
                                TrackerWidgetClassPath
                            )

                        if not WidgetClass then
                            return
                        end

                        local WidgetLibrary =
                            StaticFindObject(
                                "/Script/UMG.Default__WidgetBlueprintLibrary"
                            )

                        if not WidgetLibrary then
                            return
                        end

                        RemoveColumnWidgets()

                        local ColumnsCreated =
                            CreateColumnWidgets(
                                WidgetLibrary,
                                WidgetClass,
                                HUDLayout
                            )

                        if not ColumnsCreated then

                            print(
                                "[LuckyTracker] Could not refresh tracker columns.\n"
                            )

                            return
                        end

                        print(
                            "[LuckyTracker] Automatic columns refreshed!\n"
                        )
                    end
                )

            if not Success then

                print(
                    "[LuckyTracker] Tracker refresh error: "
                    .. tostring(Error)
                    .. "\n"
                )
            end
        end
    )
end


------------------------------------------------
-- CHECK PALWORLD HUD
------------------------------------------------

local function CheckPalHUD()

    ExecuteInGameThread(
        function()

            local Success, Error =
                pcall(
                    function()

                        if not PlayerController then

                            print(
                                "[LuckyTracker] HUD TEST: PlayerController is not available.\n"
                            )

                            return
                        end

                        local HUD =
                            PlayerController:GetHUD()

                        if not HUD then

                            print(
                                "[LuckyTracker] HUD TEST: GetHUD returned nil.\n"
                            )

                            return
                        end

                        local HUDLayout =
                            HUD.HUDLayout

                        if not HUDLayout then

                            print(
                                "[LuckyTracker] HUD TEST: HUDLayout was nil.\n"
                            )

                            return
                        end

                        print(
                            "[LuckyTracker] HUD TEST: SUCCESS!\n"
                        )
                    end
                )

            if not Success then

                print(
                    "[LuckyTracker] HUD TEST ERROR: "
                    .. tostring(Error)
                    .. "\n"
                )
            end
        end
    )
end


------------------------------------------------
-- OPEN TRACKER
------------------------------------------------

local function OpenTracker()

    ExecuteInGameThread(
        function()

            local Success, Error =
                pcall(
                    function()

                        if not PlayerController then

                            print(
                                "[LuckyTracker] UI ERROR: PlayerController is not available.\n"
                            )

                            return
                        end

                        local WidgetClass =
                            StaticFindObject(
                                TrackerWidgetClassPath
                            )

                        if not WidgetClass then

                            print(
                                "[LuckyTracker] UI ERROR: WBP_NoData_C was not found.\n"
                            )

                            return
                        end

                        local WidgetLibrary =
                            StaticFindObject(
                                "/Script/UMG.Default__WidgetBlueprintLibrary"
                            )

                        if not WidgetLibrary then

                            print(
                                "[LuckyTracker] UI ERROR: WidgetBlueprintLibrary was not found.\n"
                            )

                            return
                        end

                        local HUD =
                            PlayerController:GetHUD()

                        if not HUD then

                            print(
                                "[LuckyTracker] UI ERROR: Player HUD was nil.\n"
                            )

                            return
                        end

                        local HUDLayout =
                            HUD.HUDLayout

                        if not HUDLayout then

                            print(
                                "[LuckyTracker] UI ERROR: HUDLayout was nil.\n"
                            )

                            return
                        end

                        ------------------------------------------------
                        -- HEADER
                        ------------------------------------------------

                        local NewHeaderWidget =
                            CreateTrackerWidget(
                                WidgetLibrary,
                                WidgetClass,
                                "LUCKY TRACKER",
                                HeaderX,
                                HeaderY,
                                0
                            )

                        if not NewHeaderWidget then

                            print(
                                "[LuckyTracker] UI ERROR: Header widget failed.\n"
                            )

                            return
                        end

                        HUDLayout:AddHUD(
                            NewHeaderWidget,
                            1000
                        )

                        HeaderWidget =
                            NewHeaderWidget

                        ------------------------------------------------
                        -- AUTOMATIC COLUMNS
                        ------------------------------------------------

                        ColumnWidgets = {}

                        local ColumnsCreated =
                            CreateColumnWidgets(
                                WidgetLibrary,
                                WidgetClass,
                                HUDLayout
                            )

                        if not ColumnsCreated then

                            if HeaderWidget then
                                HeaderWidget:RemoveFromParent()
                            end

                            HeaderWidget = nil

                            RemoveColumnWidgets()

                            print(
                                "[LuckyTracker] UI ERROR: Tracker columns failed.\n"
                            )

                            return
                        end

                        TrackerVisible =
                            true

                        print(
                            "[LuckyTracker] AUTOMATIC COLUMN TRACKER OPEN!\n"
                        )

                        print(
                            "[LuckyTracker] Header X = "
                            .. tostring(HeaderX)
                            .. ", Y = "
                            .. tostring(HeaderY)
                            .. "\n"
                        )

                        print(
                            "[LuckyTracker] First column X = "
                            .. tostring(FirstColumnX)
                            .. "\n"
                        )

                        print(
                            "[LuckyTracker] Column spacing = "
                            .. tostring(ColumnSpacing)
                            .. "\n"
                        )

                        print(
                            "[LuckyTracker] Extra column Y = "
                            .. tostring(ExtraColumnY)
                            .. "\n"
                        )
                    end
                )

            if not Success then

                print(
                    "[LuckyTracker] UI creation error: "
                    .. tostring(Error)
                    .. "\n"
                )

                HeaderWidget = nil
                ColumnWidgets = {}

                TrackerVisible = false
            end
        end
    )
end


------------------------------------------------
-- CLOSE TRACKER
------------------------------------------------

local function CloseTracker()

    ExecuteInGameThread(
        function()

            local Success, Error =
                pcall(
                    function()

                        if HeaderWidget then
                            HeaderWidget:RemoveFromParent()
                        end

                        HeaderWidget = nil

                        RemoveColumnWidgets()

                        TrackerVisible = false

                        print(
                            "[LuckyTracker] Tracker removed!\n"
                        )
                    end
                )

            if not Success then

                print(
                    "[LuckyTracker] UI removal error: "
                    .. tostring(Error)
                    .. "\n"
                )

                HeaderWidget = nil
                ColumnWidgets = {}

                TrackerVisible = false
            end
        end
    )
end


------------------------------------------------
-- LOAD COUNTS
------------------------------------------------

local LoadSuccess,
    LoadError =
    pcall(
        LoadLuckyCounts
    )

if not LoadSuccess then

    print(
        "[LuckyTracker] Count loading error: "
        .. tostring(LoadError)
        .. "\n"
    )
end


------------------------------------------------
-- PLAYER CONTROLLER / CAPTURE HOOK
------------------------------------------------

RegisterHook(
    "/Script/Engine.PlayerController:ClientRestart",

    function(Context)

        local ControllerSuccess,
            Controller =
            pcall(
                function()
                    return Context:get()
                end
            )

        if ControllerSuccess
            and Controller
        then

            PlayerController =
                Controller

            print(
                "[LuckyTracker] PlayerController captured for UI.\n"
            )

            ExecuteWithDelay(
                2000,

                function()
                    CheckPalHUD()
                end
            )
        end

        if HookInstalled then
            return
        end

        ExecuteWithDelay(
            5000,

            function()

                local Success, Error =
                    pcall(
                        function()

                            RegisterHook(
                                "/Game/Pal/Blueprint/Weapon/Other/NewPalSphere/BP_PalSphere_Body.BP_PalSphere_Body_C:CaptureSuccessEvent",

                                function(Context)

                                    print(
                                        "[LuckyTracker] SUCCESSFUL CAPTURE DETECTED!\n"
                                    )

                                    local Sphere =
                                        Context:get()

                                    if not Sphere then

                                        print(
                                            "[LuckyTracker] Could not unwrap capture sphere.\n"
                                        )

                                        return
                                    end

                                    local HandleSuccess,
                                        TargetHandle =
                                        pcall(
                                            function()

                                                local OutHandle = {}

                                                Sphere:GetTargetHandle(
                                                    OutHandle
                                                )

                                                return
                                                    OutHandle.targetHandle
                                            end
                                        )

                                    if not HandleSuccess then

                                        print(
                                            "[LuckyTracker] GetTargetHandle failed: "
                                            .. tostring(TargetHandle)
                                            .. "\n"
                                        )

                                        return
                                    end

                                    if not TargetHandle then

                                        print(
                                            "[LuckyTracker] targetHandle was nil.\n"
                                        )

                                        return
                                    end

                                    local ParameterSuccess,
                                        IndividualParameter =
                                        pcall(
                                            function()

                                                return
                                                    TargetHandle:TryGetIndividualParameter()
                                            end
                                        )

                                    if not ParameterSuccess then

                                        print(
                                            "[LuckyTracker] TryGetIndividualParameter failed: "
                                            .. tostring(IndividualParameter)
                                            .. "\n"
                                        )

                                        return
                                    end

                                    if not IndividualParameter then

                                        print(
                                            "[LuckyTracker] Individual Pal data was nil.\n"
                                        )

                                        return
                                    end

                                    -- Good Catch Stats temporary Alpha + gender detection test.
                                    -- This only logs capture properties.
                                    -- It does not change the existing Lucky save format or UI.

                                    local IDSuccess,
                                        CharacterID =
                                        pcall(
                                            function()
                                                return IndividualParameter:GetCharacterID()
                                            end
                                        )

                                    if not IDSuccess or not CharacterID then
                                        print(
                                            "[GoodCatchStats] GetCharacterID FAILED: "
                                            .. tostring(CharacterID)
                                            .. "\n"
                                        )
                                    else
                                        local IDStringSuccess,
                                            CharacterIDStringForTest =
                                            pcall(
                                                function()
                                                    return CharacterID:ToString()
                                                end
                                            )

                                        if IDStringSuccess then
                                            print(
                                                "[GoodCatchStats] CharacterID: "
                                                .. tostring(CharacterIDStringForTest)
                                                .. "\n"
                                            )
                                        end

                                        local Utility =
                                            StaticFindObject(
                                                "/Script/Pal.Default__PalUtility"
                                            )

                                        if not Utility then
                                            print(
                                                "[GoodCatchStats] Alpha test: Default__PalUtility was not found.\n"
                                            )
                                        else
                                            local DatabaseSuccess,
                                                CharacterDatabase =
                                                pcall(
                                                    function()
                                                        return Utility:GetDatabaseCharacterParameter(
                                                            PlayerController
                                                        )
                                                    end
                                                )

                                            if not DatabaseSuccess or not CharacterDatabase then
                                                print(
                                                    "[GoodCatchStats] Alpha test: GetDatabaseCharacterParameter FAILED: "
                                                    .. tostring(CharacterDatabase)
                                                    .. "\n"
                                                )
                                            else
                                                local BossSuccess,
                                                    IsBoss =
                                                    pcall(
                                                        function()
                                                            return CharacterDatabase:GetIsBoss(
                                                                CharacterID
                                                            )
                                                        end
                                                    )

                                                if BossSuccess then
                                                    print(
                                                        "[GoodCatchStats] GetIsBoss SUCCESS!\n"
                                                    )
                                                    print(
                                                        "[GoodCatchStats] Boss raw value: "
                                                        .. tostring(IsBoss)
                                                        .. "\n"
                                                    )
                                                else
                                                    print(
                                                        "[GoodCatchStats] GetIsBoss FAILED: "
                                                        .. tostring(IsBoss)
                                                        .. "\n"
                                                    )
                                                end

                                                local ZukanSuccess,
                                                    ZukanIndex =
                                                    pcall(
                                                        function()
                                                            return CharacterDatabase:GetZukanIndex(
                                                                CharacterID
                                                            )
                                                        end
                                                    )

                                                if ZukanSuccess then
                                                    print(
                                                        "[GoodCatchStats] ZukanIndex raw value: "
                                                        .. tostring(ZukanIndex)
                                                        .. "\n"
                                                    )
                                                else
                                                    print(
                                                        "[GoodCatchStats] GetZukanIndex FAILED: "
                                                        .. tostring(ZukanIndex)
                                                        .. "\n"
                                                    )
                                                end
                                            end
                                        end
                                    end

                                    ------------------------------------------------
                                    -- GOOD CATCH STATS: PALDECK ORDER TEST
                                    ------------------------------------------------
                                    -- Log-only test. No new counters/save format/UI.
                                    -- Alpha Kingpaca is the confirmed special test case:
                                    -- BOSS_KingAlpaca -> Alpaca.
                                    ------------------------------------------------

                                    if IDSuccess and CharacterID and IDStringSuccess then

                                        local BaseSpeciesIDString =
                                            CharacterIDStringForTest

                                        if BaseSpeciesIDString == "BOSS_KingAlpaca" then
                                            BaseSpeciesIDString = "Alpaca"
                                        else
                                            BaseSpeciesIDString =
                                                BaseSpeciesIDString:gsub(
                                                    "^BOSS_",
                                                    ""
                                                )
                                        end

                                        print(
                                            "[GoodCatchStats] Base species candidate: "
                                            .. tostring(BaseSpeciesIDString)
                                            .. "\n"
                                        )

                                        local BaseNameSuccess,
                                            BaseSpeciesFName =
                                            pcall(
                                                function()
                                                    return FName(
                                                        BaseSpeciesIDString
                                                    )
                                                end
                                            )

                                        if not BaseNameSuccess then

                                            print(
                                                "[GoodCatchStats] Base FName creation FAILED: "
                                                .. tostring(BaseSpeciesFName)
                                                .. "\n"
                                            )

                                        else

                                            local Utility =
                                                StaticFindObject(
                                                    "/Script/Pal.Default__PalUtility"
                                                )

                                            if Utility then

                                                local DatabaseSuccess,
                                                    CharacterDatabase =
                                                    pcall(
                                                        function()
                                                            return Utility:GetDatabaseCharacterParameter(
                                                                PlayerController
                                                            )
                                                        end
                                                    )

                                                if DatabaseSuccess and CharacterDatabase then

                                                    local BaseZukanSuccess,
                                                        BaseZukanIndex =
                                                        pcall(
                                                            function()
                                                                return CharacterDatabase:GetZukanIndex(
                                                                    BaseSpeciesFName
                                                                )
                                                            end
                                                        )

                                                    if BaseZukanSuccess then

                                                        print(
                                                            "[GoodCatchStats] NORMALIZED ZukanIndex: "
                                                            .. tostring(BaseZukanIndex)
                                                            .. "\n"
                                                        )

                                                        if BaseZukanIndex >= 0 then
                                                            print(
                                                                "[GoodCatchStats] PALDECK ORDER TEST SUCCESS!\n"
                                                            )
                                                        else
                                                            print(
                                                                "[GoodCatchStats] PALDECK ORDER TEST: candidate still has no valid index.\n"
                                                            )
                                                        end

                                                    else

                                                        print(
                                                            "[GoodCatchStats] NORMALIZED GetZukanIndex FAILED: "
                                                            .. tostring(BaseZukanIndex)
                                                            .. "\n"
                                                        )
                                                    end
                                                end
                                            end
                                        end
                                    end

                                    local GenderSuccess,
                                        GenderType =
                                        pcall(
                                            function()
                                                return IndividualParameter:GetGenderType()
                                            end
                                        )

                                    if GenderSuccess then

                                        print(
                                            "[GoodCatchStats] GetGenderType SUCCESS!\n"
                                        )

                                        print(
                                            "[GoodCatchStats] Gender raw value: "
                                            .. tostring(GenderType)
                                            .. "\n"
                                        )

                                    else

                                        print(
                                            "[GoodCatchStats] GetGenderType FAILED: "
                                            .. tostring(GenderType)
                                            .. "\n"
                                        )

                                    end

                                    local RareSuccess,
                                        IsRare =
                                        pcall(
                                            function()
                                                return IndividualParameter:IsRarePal()
                                            end
                                        )

                                    if not RareSuccess then

                                        print(
                                            "[LuckyTracker] IsRarePal failed: "
                                            .. tostring(IsRare)
                                            .. "\n"
                                        )

                                        return
                                    end

                                    if not IsRare then

                                        print(
                                            "[LuckyTracker] Captured Pal is not Lucky.\n"
                                        )

                                        return
                                    end

                                    print(
                                        "[LuckyTracker] CAPTURED PAL IS LUCKY!\n"
                                    )

                                    local IDSuccess,
                                        CharacterID =
                                        pcall(
                                            function()
                                                return IndividualParameter:GetCharacterID()
                                            end
                                        )

                                    if not IDSuccess then

                                        print(
                                            "[LuckyTracker] GetCharacterID failed: "
                                            .. tostring(CharacterID)
                                            .. "\n"
                                        )

                                        return
                                    end

                                    if not CharacterID then

                                        print(
                                            "[LuckyTracker] GetCharacterID returned nil.\n"
                                        )

                                        return
                                    end

                                    local StringSuccess,
                                        CharacterIDString =
                                        pcall(
                                            function()
                                                return CharacterID:ToString()
                                            end
                                        )

                                    if not StringSuccess then

                                        print(
                                            "[LuckyTracker] FName ToString failed: "
                                            .. tostring(CharacterIDString)
                                            .. "\n"
                                        )

                                        return
                                    end

                                    print(
                                        "[LuckyTracker] Lucky CharacterID: "
                                        .. CharacterIDString
                                        .. "\n"
                                    )

                                    local SpeciesID =
                                        CharacterIDString:gsub(
                                            "^BOSS_",
                                            ""
                                        )

                                    local PalName =
                                        PalNames[SpeciesID]
                                        or SpeciesID

                                    print(
                                        "[LuckyTracker] Species ID: "
                                        .. SpeciesID
                                        .. "\n"
                                    )

                                    print(
                                        "[LuckyTracker] Pal Name: "
                                        .. PalName
                                        .. "\n"
                                    )

                                    LuckyCounts[SpeciesID] =
                                        (
                                            LuckyCounts[SpeciesID]
                                            or 0
                                        ) + 1

                                    print(
                                        "[LuckyTracker] Lucky "
                                        .. PalName
                                        .. " count: "
                                        .. tostring(LuckyCounts[SpeciesID])
                                        .. "\n"
                                    )

                                    local SaveCallSuccess,
                                        Saved =
                                        pcall(
                                            SaveLuckyCounts
                                        )

                                    if not SaveCallSuccess then

                                        print(
                                            "[LuckyTracker] Count saving error: "
                                            .. tostring(Saved)
                                            .. "\n"
                                        )

                                    elseif not Saved then

                                        print(
                                            "[LuckyTracker] Count file was not saved.\n"
                                        )

                                    else

                                        RefreshTracker()
                                    end
                                end
                            )
                        end
                    )

                if Success then

                    HookInstalled =
                        true

                    print(
                        "[LuckyTracker] CaptureSuccessEvent hook REGISTERED!\n"
                    )

                else

                    print(
                        "[LuckyTracker] CaptureSuccessEvent not loaded yet.\n"
                    )

                    print(
                        "[LuckyTracker] "
                        .. tostring(Error)
                        .. "\n"
                    )
                end
            end
        )
    end
)


------------------------------------------------
-- F7 TOGGLE
------------------------------------------------

RegisterKeyBind(
    Key.F7,

    function()

        if TrackerVisible then

            print(
                "[LuckyTracker] F7 - closing tracker...\n"
            )

            CloseTracker()

        else

            print(
                "[LuckyTracker] F7 - opening tracker...\n"
            )

            OpenTracker()
        end
    end
)


print(
    "[LuckyTracker] F7 tracker hotkey registered!\n"
)

print(
    "[LuckyTracker] Waiting for world...\n"
)