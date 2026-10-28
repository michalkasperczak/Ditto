$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Assert-SourcePattern {
    param(
        [Parameter(Mandatory = $true)]
        [string] $RelativePath,

        [Parameter(Mandatory = $true)]
        [string] $Pattern,

        [Parameter(Mandatory = $true)]
        [string] $FailureMessage
    )

    $path = Join-Path $repositoryRoot $RelativePath
    $text = Get-Content -LiteralPath $path -Raw
    if ($text -notmatch $Pattern) {
        throw "$FailureMessage ($RelativePath)"
    }
}

# Stable enum values: new commands must remain appended immediately before LAST_ACTION.
Assert-SourcePattern "src\ActionEnums.h" '(?s)SHOW_STARRED_CLIPS,\s*RENAME_CLIP,\s*ASSIGN_CLIP_HOTKEY,\s*LAST_ACTION' "Focused clip property actions are not appended to the action enum"

$actionEnumText = Get-Content -LiteralPath (Join-Path $repositoryRoot "src\ActionEnums.h") -Raw
$actionEnumBody = [regex]::Match($actionEnumText, '(?s)enum ActionEnumValues\s*\{(?<body>.*?)LAST_ACTION').Groups['body'].Value
$actionNames = @([regex]::Matches($actionEnumBody, '(?m)^\s*([A-Z][A-Z0-9_]*),?\s*(?://.*)?$') | ForEach-Object { $_.Groups[1].Value })
$renameActionId = [Array]::IndexOf($actionNames, "RENAME_CLIP")
$assignHotKeyActionId = [Array]::IndexOf($actionNames, "ASSIGN_CLIP_HOTKEY")
if ($renameActionId -lt 0 -or $assignHotKeyActionId -lt 0) {
    throw "Focused clip property action IDs could not be derived from ActionEnums.h"
}

# User-facing command names and their default local shortcuts.
Assert-SourcePattern "src\ActionEnums.cpp" '(?s)case RENAME_CLIP:\s*val = "Rename Clip";' "Rename Clip has no user-facing action name"
Assert-SourcePattern "src\ActionEnums.cpp" '(?s)case ASSIGN_CLIP_HOTKEY:\s*val = "Assign Clip Hot Key";' "Assign Clip Hot Key has no user-facing action name"
Assert-SourcePattern "src\ActionEnums.cpp" '(?s)case ActionEnums::RENAME_CLIP:\s*return VK_F2;' "Rename Clip does not default to F2"
Assert-SourcePattern "src\ActionEnums.cpp" "(?s)case ActionEnums::ASSIGN_CLIP_HOTKEY:\s*return ACCEL_MAKEKEY\('S', HOTKEYF_CONTROL \| HOTKEYF_SHIFT\);" "Assign Clip Hot Key does not default to Ctrl+Shift+S"

# Keyboard routing must execute the same focused operations exposed by the menu.
Assert-SourcePattern "src\QPasteWnd.cpp" '(?s)case ActionEnums::RENAME_CLIP:\s*ret = DoActionClipProperties\(CCopyProperties::INITIAL_FOCUS_ITEM_TITLE\);' "Rename Clip is not routed to title focus"
Assert-SourcePattern "src\QPasteWnd.cpp" '(?s)case ActionEnums::ASSIGN_CLIP_HOTKEY:\s*ret = DoActionClipProperties\(CCopyProperties::INITIAL_FOCUS_HOT_KEY\);' "Assign Clip Hot Key is not routed to hot-key focus"
Assert-SourcePattern "src\QPasteWnd.cpp" '(?s)ON_COMMAND\(ID_MENU_RENAME_CLIP, OnMenuRenameClip\).*ON_COMMAND\(ID_MENU_ASSIGN_CLIP_HOTKEY, OnMenuAssignClipHotKey\)' "Focused property commands are missing menu routing"
Assert-SourcePattern "src\QPasteWnd.cpp" '(?s)OnUpdateMenuRenameClip.*UpdateMenuShortCut\(pCmdUI, ActionEnums::RENAME_CLIP\);' "Rename Clip menu does not expose its configured shortcut"
Assert-SourcePattern "src\QPasteWnd.cpp" '(?s)OnUpdateMenuAssignClipHotKey.*UpdateMenuShortCut\(pCmdUI, ActionEnums::ASSIGN_CLIP_HOTKEY\);' "Assign Clip Hot Key menu does not expose its configured shortcut"

# Both commands must be visible with intentional labels in the menu and keyboard settings.
Assert-SourcePattern "CP_Main.rc" '(?s)"Rename Clip",\s+ID_MENU_RENAME_CLIP.*"Assign Clip Hot Key",\s+ID_MENU_ASSIGN_CLIP_HOTKEY' "Focused property commands are missing from the Quick Paste menu"
Assert-SourcePattern "Debug\Language\English.xml" "<Item English_Text = `"Rename Clip`" ID = `"$renameActionId`">" "Rename Clip is missing from Quick Paste keyboard translations"
Assert-SourcePattern "Debug\Language\English.xml" "<Item English_Text = `"Assign Clip Hot Key`" ID = `"$assignHotKeyActionId`">" "Assign Clip Hot Key is missing from Quick Paste keyboard translations"

# Initial focus is part of the command contract used by keyboard and screen-reader users.
Assert-SourcePattern "src\CopyProperties.cpp" '(?s)m_initialFocus == INITIAL_FOCUS_HOT_KEY\).*m_HotKey.SetFocus\(\);' "Hot-key assignment does not focus the hot-key control"
Assert-SourcePattern "src\CopyProperties.cpp" '(?s)m_initialFocus == INITIAL_FOCUS_ITEM_TITLE\).*m_description.SetSel\(0, -1\);' "Rename Clip does not select the complete title"

Write-Host "Focused clip property command parity checks passed."
