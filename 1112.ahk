; -------------------------------
;          配置初始化 (UTF-8 with BOM)
; -------------------------------
#NoEnv
#KeyHistory 0
#Persistent
#SingleInstance force

SetBatchLines -1
Process, Priority,, High
SetMouseDelay, -1
SetDefaultMouseSpeed, 0

configFile := A_ScriptDir "\AutoFire.ini"

; 检查是否以管理员身份运行
if not A_IsAdmin {
    MsgBox, 需要以管理员身份运行以启用完整功能。
    ExitApp
}

; 读取或创建配置文件
IfNotExist, %configFile% 
{
    CreateDefaultConfig()
}
LoadConfigFromFile()

; -------------------------------
;          GUI 界面
; -------------------------------
Gui, Font, s10, Microsoft Sans Serif
Gui, Add, Text, xm ym+3 w80, 热键：
Gui, Add, Hotkey, x+5 yp-3 vHotkeyC w200, % HotkeyCC
Hotkey, %HotkeyCC%, ToggleAssistant

Gui, Add, Text, xm y+15 w80, 射速(RPM)：
Gui, Add, Edit, x+5 yp-3 vFireRate w200 Number, %defaultFireRate%
Gui, Add, Text, x+5 yp+3, (100-2000)

Gui, Add, Text, xm y+15 w80, 垂直压枪：
Gui, Add, Edit, x+5 yp-3 vRecoilForce w200 Number, %defaultRecoil%
Gui, Add, Text, x+5 yp+3, (1-15)

Gui, Add, Text, xm y+15 w80, 水平随机：
Gui, Add, Edit, x+5 yp-3 vHorizontalRandom w200 Number, %defaultHorizontalRandom%
Gui, Add, Text, x+5 yp+3, (0-5)

Gui, Add, CheckBox, xm y+15 vBreathHold Checked%breathHold%, 启用屏息
Gui, Add, CheckBox, xm y+15 vSemiAutoMode Checked%semiAutoMode%, 半自动模式
Gui, Add, CheckBox, xm y+20 vED gToggleAssistant Checked%ED%, 启用辅助

Gui, Add, Text, xm y+15 w80, 已存配置：
Gui, Add, DropDownList, x+5 yp-3 vConfigList gLoadSelectedConfig w120
Gui, Add, Button, x+5 yp w70 gRefreshConfigs, 刷新列表

Gui, Add, Text, xm y+15 w80, 配置名称：
Gui, Add, Edit, x+5 yp-3 vConfigName w120
Gui, Add, Button, x+5 yp w70 gSaveConfig, 保存配置
Gui, Add, Button, x+5 yp w70 gDeleteConfig, 删除配置

Gui, Add, Button, xm y+15 w100 gButtonApplyChanges, 应用设置
Gui, Add, Button, x+5 yp w100 gRestoreDefaults, 恢复默认
Gui, Add, Button, x+5 yp w70 gHelpButton, 帮助
Gui, Show, w420 h480, 智能辅助助手

; 初始化时刷新配置列表
GoSub, RefreshConfigs
return

; -------------------------------
;        屏息功能模块
; -------------------------------
~RButton::
    if (BreathHold && ED) {
        SendInput {Shift Down}
        KeyWait, RButton
        SendInput {Shift Up}
    }
return

; -------------------------------
;        双模式核心逻辑
; -------------------------------
#If ED
~RButton & LButton::
    Gui, Submit, NoHide
    FireInterval := CalcFireInterval(FireRate)
    baseRecoil := RecoilForce
    lastFireTime := A_TickCount - FireInterval
    shotCount := 0
    
    if (SemiAutoMode) {
        While (GetKeyState("RButton", "P") && GetKeyState("LButton", "P") && ED) {
            currentTime := A_TickCount
            if (currentTime - lastFireTime >= FireInterval) {
                SendInput {Blind}{LButton Down}
                Sleep 15
                SendInput {Blind}{LButton Up}
                
                shotCount++
                dynamicRecoil := baseRecoil * (0.9 + (shotCount * 0.01))
                dynamicRecoil := dynamicRecoil > (baseRecoil * 1.5) ? baseRecoil * 1.5 : dynamicRecoil
                
                Random, randRecoilV, -0.8, 0.8
                Random, randRecoilH, -HorizontalRandom, HorizontalRandom
                
                DllCall("mouse_event", "UInt", 0x01, "UInt", randRecoilH, "UInt", dynamicRecoil + randRecoilV, "UInt", 0, "UPtr", 0)
                lastFireTime := currentTime
            }
            Sleep 5
        }
        SendInput {Blind}{LButton Up}
    } else {
        SendInput {Blind}{LButton Down}
        While (GetKeyState("RButton", "P") && GetKeyState("LButton", "P") && ED) {
            currentTime := A_TickCount
            if (currentTime - lastFireTime >= FireInterval) {
                shotCount++
                dynamicRecoil := baseRecoil * (0.8 + (shotCount * 0.02))
                dynamicRecoil := dynamicRecoil > baseRecoil ? baseRecoil : dynamicRecoil
                
                Random, randRecoilV, -1.2, 1.2
                Random, randRecoilH, -HorizontalRandom, HorizontalRandom
                
                DllCall("mouse_event", "UInt", 0x01, "UInt", randRecoilH, "UInt", dynamicRecoil + randRecoilV, "UInt", 0, "UPtr", 0)
                lastFireTime := currentTime
            }
            Sleep 5
        }
        SendInput {Blind}{LButton Up}
    }
return
#If

; -------------------------------
;        功能控制模块
; -------------------------------
ToggleAssistant:
    Gui, Submit, NoHide
    ED := !ED
    GuiControl,, ED, %ED%
    SaveSettings()
return

ButtonApplyChanges:
    Gui, Submit, NoHide
    
    FireRate := (FireRate < 100) ? 100 : (FireRate > 2000) ? 2000 : FireRate
    RecoilForce := (RecoilForce < 1) ? 1 : (RecoilForce > 15) ? 15 : RecoilForce
    HorizontalRandom := (HorizontalRandom < 0) ? 0 : (HorizontalRandom > 5) ? 5 : HorizontalRandom
    
    if (HotkeyC != HotkeyCC) {
        Hotkey, %HotkeyCC%, ToggleAssistant, Off
        Hotkey, % (HotkeyCC := HotkeyC), ToggleAssistant, On
    }
    
    SaveSettings()
    GuiControl,, FireRate, %FireRate%
    GuiControl,, RecoilForce, %RecoilForce%
    GuiControl,, HorizontalRandom, %HorizontalRandom%
return

SaveSettings() {
    global
    IniWrite, %FireRate%, %configFile%, Settings, FireRate
    IniWrite, %RecoilForce%, %configFile%, Settings, RecoilForce
    IniWrite, %HorizontalRandom%, %configFile%, Settings, HorizontalRandom
    IniWrite, %HotkeyCC%, %configFile%, Settings, Hotkey
    IniWrite, %BreathHold%, %configFile%, Settings, BreathHold
    IniWrite, %SemiAutoMode%, %configFile%, Settings, SemiAutoMode
    IniWrite, %ED%, %configFile%, Settings, Enabled
}

CreateDefaultConfig() {
    global
    IniWrite, PgDn, %configFile%, Settings, Hotkey
    IniWrite, 600, %configFile%, Settings, FireRate
    IniWrite, 5, %configFile%, Settings, RecoilForce
    IniWrite, 1, %configFile%, Settings, HorizontalRandom
    IniWrite, 0, %configFile%, Settings, BreathHold
    IniWrite, 0, %configFile%, Settings, SemiAutoMode
    IniWrite, 1, %configFile%, Settings, Enabled
}

LoadConfigFromFile() {
    global
    IniRead, HotkeyCC, %configFile%, Settings, Hotkey, PgDn
    IniRead, defaultFireRate, %configFile%, Settings, FireRate, 600
    IniRead, defaultRecoil, %configFile%, Settings, RecoilForce, 5
    IniRead, defaultHorizontalRandom, %configFile%, Settings, HorizontalRandom, 1
    IniRead, breathHold, %configFile%, Settings, BreathHold, 0
    IniRead, semiAutoMode, %configFile%, Settings, SemiAutoMode, 0
    IniRead, ED, %configFile%, Settings, Enabled, 1
}

SaveConfig:
    Gui, Submit, NoHide
    if (ConfigName = "") {
        MsgBox, 请输入配置名称！
        return
    }
    
    IniWrite, %FireRate%, %configFile%, Config_%ConfigName%, FireRate
    IniWrite, %RecoilForce%, %configFile%, Config_%ConfigName%, RecoilForce
    IniWrite, %HorizontalRandom%, %configFile%, Config_%ConfigName%, HorizontalRandom
    IniWrite, %HotkeyCC%, %configFile%, Config_%ConfigName%, Hotkey
    IniWrite, %BreathHold%, %configFile%, Config_%ConfigName%, BreathHold
    IniWrite, %SemiAutoMode%, %configFile%, Config_%ConfigName%, SemiAutoMode
    
    GoSub, RefreshConfigs
    MsgBox, 配置 %ConfigName% 已保存！
return

LoadConfig:
    Gui, Submit, NoHide
    if (ConfigName = "") {
        MsgBox, 请输入配置名称！
        return
    }
    
    IniRead, tempFireRate, %configFile%, Config_%ConfigName%, FireRate, %defaultFireRate%
    IniRead, tempRecoil, %configFile%, Config_%ConfigName%, RecoilForce, %defaultRecoil%
    IniRead, tempHorizontal, %configFile%, Config_%ConfigName%, HorizontalRandom, %defaultHorizontalRandom%
    IniRead, tempHotkey, %configFile%, Config_%ConfigName%, Hotkey, %HotkeyCC%
    IniRead, tempBreathHold, %configFile%, Config_%ConfigName%, BreathHold, 0
    IniRead, tempSemiAutoMode, %configFile%, Config_%ConfigName%, SemiAutoMode, 0
    
    if (tempFireRate = "ERROR") {
        MsgBox, 未找到配置 %ConfigName%！
        return
    }
    
    GuiControl,, FireRate, %tempFireRate%
    GuiControl,, RecoilForce, %tempRecoil%
    GuiControl,, HorizontalRandom, %tempHorizontal%
    GuiControl,, HotkeyC, %tempHotkey%
    GuiControl,, BreathHold, %tempBreathHold%
    GuiControl,, SemiAutoMode, %tempSemiAutoMode%
    
    if (tempHotkey != HotkeyCC) {
        Hotkey, %HotkeyCC%, ToggleAssistant, Off
        Hotkey, % (HotkeyCC := tempHotkey), ToggleAssistant, On
    }
    
    GuiControl, Choose, ConfigList, %ConfigName%
    
    MsgBox, 配置 %ConfigName% 已加载！
return

RefreshConfigs:
    configs := ""
    IniRead, sections, %configFile%
    Loop, Parse, sections, `n
    {
        if (InStr(A_LoopField, "Config_") = 1) {
            configName := SubStr(A_LoopField, 8)
            configs .= configName . "|"
        }
    }
    GuiControl,, ConfigList, |%configs%
return

LoadSelectedConfig:
    Gui, Submit, NoHide
    if (ConfigList != "") {
        GuiControl,, ConfigName, %ConfigList%
        GoSub, LoadConfig
    }
return

DeleteConfig:
    Gui, Submit, NoHide
    if (ConfigName = "") {
        MsgBox, 请输入要删除的配置名称！
        return
    }
    
    MsgBox, 4, 确认删除, 是否确定删除配置 %ConfigName%？
    IfMsgBox Yes 
    {
        IniDelete, %configFile%, Config_%ConfigName%
        GuiControl,, ConfigName, 
        GoSub, RefreshConfigs
        MsgBox, 配置 %ConfigName% 已删除！
    }
return

RestoreDefaults:
    CreateDefaultConfig()
    LoadConfigFromFile()
    GuiControl,, FireRate, %defaultFireRate%
    GuiControl,, RecoilForce, %defaultRecoil%
    GuiControl,, HorizontalRandom, %defaultHorizontalRandom%
    GuiControl,, HotkeyC, %HotkeyCC%
    GuiControl,, BreathHold, %breathHold%
    GuiControl,, SemiAutoMode, %semiAutoMode%
    GuiControl,, ED, %ED%
    MsgBox, 默认设置已恢复！
return

HelpButton:
    MsgBox, 0, 使用说明,
    (LTrim
    1. 热键：开关压枪辅助的快捷键
    2. 射速(RPM)：武器每分钟射速（100-2000）
    3. 垂直压枪：控制垂直后坐力补偿力度（1-15）
    4. 水平随机：增加水平随机偏移防检测（0-5）
    5. 屏息模式：右键瞄准时自动屏息
    6. 半自动模式：适用于单发/点射武器
    7. 配置管理：保存/加载不同武器配置
    
核心功能：
- 动态压枪：
   根据设定的压枪力度，自动抵消武器后坐力，并添加随机偏移模拟人工操作。
- 射速控制：
   按指定 RPM（每分钟射速）自动调整开火间隔。
- 屏息辅助：
   启用后，按住右键（瞄准）时自动触发屏息（模拟按下 Shift 键）。
- 参数配置：
   射速(RPM)：通过游戏内武器属性面板获取，匹配武器理论射速。
   压枪力度：根据以下步骤校准：
      1. 前往训练场，对墙面连续射击，观察垂直弹道分布。
      2. 初始设为5，逐步增减数值，直到弹道呈点状。

此项目为开源项目，仅供交流学习。开发者不对因使用此脚本导致的账号封禁负责。

    使用方法：
    - 启用辅助后，按住右键瞄准+左键射击触发
    - 推荐设置：M4步枪 射速700-900 压枪6-8
    - AK步枪 射速600 压枪10-12
    )

return

GuiClose:
ExitApp

; -------------------------------
;          函数部分
; -------------------------------
CalcFireInterval(rpm) {
    return 60000 / rpm
}