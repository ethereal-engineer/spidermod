--SpiderMod Addon clientside code
--Author: ancientevil
--Contact: facepunch.com
--Date: 16th May 2009
--Purpose: Shared code for Spidermod.

--global debug table

sm_debug = {}
sm_debug.Enabled = false
function sm_debug:print(text)
  if self.Enabled then
    if CLIENT then
      LocalPlayer():PrintMessage(HUD_PRINTTALK, text)
    else
      PrintMessage(HUD_PRINTTALK, text)
    end
  end
end

--give this file to all clients
if ( SERVER ) then
  AddCSLuaFile( "sm_shared.lua" )
end 

--all the resources we need
resource.AddFile("materials/vgui/sil_human.vtf");
resource.AddFile("materials/vgui/sil_spider.vtf");
resource.AddFile("materials/vgui/sil_human.vmt");
resource.AddFile("materials/vgui/sil_spider.vmt");
resource.AddFile("materials/vgui/entities/weapon_spiderweb.vtf")
resource.AddFile("materials/vgui/entities/weapon_spiderweb.vmt")
resource.AddFile("materials/models/weapons/v_hand/v_hand_sheet.vmt")
resource.AddFile("materials/models/weapons/v_hand/v_hand_sheet.vtf")
resource.AddFile("sound/WebFire1.mp3")
resource.AddFile("sound/WebFire2.mp3")
resource.AddFile("sound/WebFire3.mp3")
resource.AddFile("models/weapons/v_spiderweb.dx80.vtx")
resource.AddFile("models/weapons/v_spiderweb.dx90.vtx")
resource.AddFile("models/weapons/v_spiderweb.mdl")
resource.AddFile("models/weapons/v_spiderweb.sw.vtx")
resource.AddFile("models/weapons/v_spiderweb.vvd")

--general constants for the addon
SpiderModConst = {}
SpiderModConst.OpModeVarName = "sm_opmode"
SpiderModConst.EnabledVarName = "spidermod_enabled"

--SpeedInfo - constants for player speed
SpeedInfo = {}
SpeedInfo.PlayerWalkSpeed          = 500  --Spidermod walk speed
SpeedInfo.PlayerSprintSpeed        = 750  --Spidermod sprint speed
SpeedInfo.PlayerCrouchedWalkSpeed  = 250  --Spidermod crouched walk speed
SpeedInfo.DefaultWalkSpeed         = 250  --Default walk speed
SpeedInfo.DefaultSprintSpeed       = 750  --Default sprint speed
SpeedInfo.DefaultCrouchedWalkSpeed = 0.5  --Default crouched walk multiplier (will check on this weirdness later)

--JumpInfo - constants for player jumping
JumpInfo = {}
JumpInfo.ChargeNWIntName   = "spider_jump_charge" --networked integer name for jump charge percent
JumpInfo.KeyStateNWIntName = "spiderjumpkeystate" --networked integer name for the jump key pressed state
JumpInfo.Multiplier        = 11.5                 --spider-jump power multiplier
JumpInfo.LongMultiplier    = 6.5                  --spider-long-jump power multiplier 
JumpInfo.MaxPower          = 100                  --max power a charge can reach
JumpInfo.ChargeDelta       = 2                    --how much the charge goes up at each delta while holding the charge key
JumpInfo.UpVector          = Vector(0, 0, 1)      --upwards unit vector
JumpInfo.OrdinaryPower     = 160                  --ordinary jump power (non-spidermod)

--DamageInfo - constants for player damage
DamageInfo = {}
DamageInfo.MinFallVelocity = 1800                 --how fast you have to be falling to start to take damage from a fall
DamageInfo.MaxFallScale    = 1300                 --how faster you have to be falling than the minimum before you will certainly die
DamageInfo.FallMultiplier  = 100                  --multiplier applied to the fall damage
DamageInfo.FallModeVarName = "sm_falldamage_mode" --the varname for the falldamage mode

--PowerScheme choices
PowerScheme = {}
PowerScheme.Spider = "smpSpider" --spider powers
PowerScheme.Human = "smpHuman"   --human powers

--OpModes (pretty self-evident)
OpMode = {}
OpMode.SWEP = "opmSWEP"         
OpMode.Choice = "opmChoice"
OpMode.Team = "opmTeam"
OpMode.AlwaysOn = "opmAlwaysOn"

--Fall damage modes
FallDamageMode = {}
FallDamageMode.SpiderOnly = "fdmSpiderOnly"
FallDamageMode.AllPlayers = "fdmAllPlayers"
FallDamageMode.Disabled = "fdmDisabled"

--Teams (for future use)
SpiderTeams = {}

--all the console commands
SpiderConCmd = {}
SpiderConCmd.SelectPower = "sm_select_power"
SpiderConCmd.FallDamageMode = "sm_falldamagemode"
SpiderConCmd.SetTeams = "sm_setspiderteams"
SpiderConCmd.OpMode = "sm_opmode"
SpiderConCmd.Enable = "sm_enabled"
SpiderConCmd.SelectGUIClient = "sm_show_powerscheme_gui_cl"
SpiderConCmd.ForgetPowerChoice = "sm_forget_power_choice"

--all the autocompletes for the console commands
SpiderCmdAutoComplete = {}
SpiderCmdAutoComplete[SpiderConCmd.SelectPower] = {"smpSpider", "smpHuman"}
SpiderCmdAutoComplete[SpiderConCmd.FallDamageMode] = FallDamageMode
SpiderCmdAutoComplete[SpiderConCmd.OpMode] = OpMode
SpiderCmdAutoComplete[SpiderConCmd.Enable] = {"1", "0"}

--jump key states
--TODO: Replace with enum
sjkDown = 1
sjkUp = -1
sjkNone = 0

--returns a positive integer describing the falling velocity of an entity (straight down)
function GetFallingVelocity(ent)
  local upVelocity = ent:GetVelocity():DotProduct(JumpInfo.UpVector)
  if (upVelocity < 0) then
    return math.abs(upVelocity)
  else
    return 0
  end
end

--how much damage would spidey take from this fall impact? returns that damage figure
function GetSpiderScaledFallDamage(ent)
  local vFall = GetFallingVelocity(ent)
  if (vFall > DamageInfo.MinFallVelocity) then
    return (((vFall-DamageInfo.MinFallVelocity)/DamageInfo.MaxFallScale)*DamageInfo.FallMultiplier)
  else
    return 0
  end
end

--returns true if spidermod is enabled
function SpidermodEnabled()
  return GetGlobalBool(SpiderModConst.EnabledVarName)
end

--returns true if a player is in a spider-enabled team
function PlayerInSpiderTeam(ply)
  return table.HasValue(SpiderTeams, ply:Team())
end

--returns true if the player is spidermod-enhanced
function PlayerIsSpider(ply)
  local opmode = GetSpiderOpMode()
  return (opmode == OpMode.AlwaysOn)
      or (ply:GetNWBool("sm_player_is_spider"))
      or ((opmode == OpMode.Team) and (PlayerInSpiderTeam(ply)))
end

--returns the current spidermod opmode
function GetSpiderOpMode()
  return GetGlobalString(SpiderModConst.OpModeVarName)
end

--returns the current fall damage mode
function GetFallDamageMode()
  return GetGlobalString(DamageInfo.FallModeVarName)
end

--autocomplete routine
--uses the autocomplete table and the table of 
--concommands to return the correct autocomplete text
function SpiderAutoComplete(cmd, args)
  if table.HasValue(SpiderConCmd, cmd) then
    if cmd == SpiderConCmd.SetTeams then
      local tblAuto = team.GetAllTeams()
      for k,v in pairs(tblAuto) do tblAuto[k] = cmd.." "..args.." "..v:GetName() end --TODO: also allow space seperated team list
      return tblAuto
    else
      local tblAuto = table.ClearKeys(SpiderCmdAutoComplete[cmd])
      for k,v in pairs(tblAuto) do tblAuto[k] = cmd.." "..v end
      return tblAuto
    end
  else
    return {}
  end
end

