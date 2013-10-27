--SpiderMod Addon clientside code
--Author: ancientevil
--Contact: facepunch.com
--Date: 16th May 2009
--Purpose: The clientside magic of Spidermod.

--the server runs this file (in shared) just to send it out to everyone
if SERVER then
  AddCSLuaFile("sm_client.lua")
  return
end

--hooks

--draw the jump charge indicator at the top right
function SpiderHUDPaint()
  draw.SimpleText("Spider Jump: " .. tostring(LocalPlayer():GetNetworkedInt(JumpInfo.ChargeNWIntName)) .. "%", "ChatFont", ScrW()-100, 20, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
end

--motion blur if you are falling fast (gets worse the faster you fall)
--so low attachments after falling from a height are a challenge
function SpiderRenderScreenspaceEffects()
  local fallingvelocity = GetFallingVelocity(LocalPlayer())
  if (fallingvelocity > DamageInfo.MinFallVelocity) then
    DrawMotionBlur( 0.05, math.min(((fallingvelocity - DamageInfo.MinFallVelocity)/DamageInfo.MaxFallScale),0.8), 0.0005)
  end
end

--for the swep opmode - whenever a player picks up (spawns) the spiderweb,
--this flags them as a spider and gives them the power
function SpiderWeaponPickedUp(weap)
  if (weap:GetClass() == "weapon_spiderweb") then
    sm_debug:print(tostring(LocalPlayer()).." picked up the spiderweb weapon")
    LocalPlayer():ConCommand("sm_select_power smpSpider") 
  end
end
--always hook this
hook.Add("HUDWeaponPickedUp", "SpiderWeaponPickedUp", SpiderWeaponPickedUp)

--enabling/disabling functions

--adds the client side hooks when a player is a spider only
function AddSpiderHooks()
  hook.Add("HUDPaint", "SpiderHUDPaint", SpiderHUDPaint)
  hook.Add("RenderScreenspaceEffects", "SpiderRenderScreenspaceEffects", SpiderRenderScreenspaceEffects)
  sm_debug:print('Client hooks added')
end

--removes clientside hooks
function RemoveSpiderHooks()
  hook.Remove("HUDPaint", "SpiderHUDPaint")
  hook.Remove("RenderScreenspaceEffects", "SpiderRenderScreenspaceEffects")
  sm_debug:print('Client hooks removed')
end

--called when a choice has been made from the choice vgui
local function FinaliseChooser(frame, ply)
  frame:Remove()
  if ply:GetNWBool("sm_remember_power_choice") then
    ply:PrintMessage(HUD_PRINTTALK, "Choice saved for this game - use sm_forget_power_choice in the console to reset")
  end
end

--displays the power scheme selection GUI
--includes a little hack due to the delayed definition of LocalPlayer()
function PowerSelectGUI(ply)
  --delay running this section of code until localplayer is defined
  if (ply == NULL) or (ply == nil) then
    timer.Simple(0.5, function() PowerSelectGUI(LocalPlayer()) end)
    return
  end
  --don't show the GUI if spidermod is not enabled
  --or if the player it is being shown to has asked us to remember
  --their last choice
  if not SpidermodEnabled() 
  or ply:GetNWBool("sm_remember_power_choice") then return end

  local Frame = vgui.Create( "Frame" ); //Create a frame
  Frame:SetSize(490, 590)
  Frame:Center()
  Frame:SetVisible(true)
  Frame:MakePopup(); 
  Frame:PostMessage("SetTitle", "text", "Spidermod - Choose your Power Scheme");  

  local picSpider = vgui.Create( "DImageButton", Frame )
  picSpider:SetImage("vgui/sil_spider")
  picSpider:SizeToContents()
  picSpider:SetKeepAspect(true)
  picSpider:SetWide(200)
  picSpider:SetPos(30, 35)
  picSpider.DoClick = function()
    local ply = LocalPlayer() 
    ply:EmitSound("WebFire1.mp3", 40.0) 
    ply:ConCommand("sm_select_power smpSpider")
    ply:PrintMessage(HUD_PRINTTALK, 'Using spider abilities')
    FinaliseChooser(Frame, ply)
  end

  local picHuman = vgui.Create( "DImageButton", Frame )
  picHuman:SetImage("vgui/sil_human")
  picHuman:SizeToContents()
  picHuman:SetKeepAspect(true)
  picHuman:SetWide(200)
  picHuman:SetPos(260, 35)
  picHuman.DoClick = function()
    ply:EmitSound("Weapon_Shotgun.Special1", 40.0) 
    ply:ConCommand("sm_select_power smpHuman") 
    ply:PrintMessage(HUD_PRINTTALK, 'Using regular abilities')
    FinaliseChooser(Frame, ply)
  end

  local cbRemember = vgui.Create("DCheckBoxLabel", Frame)
  cbRemember:SetPos(30, 559)
  cbRemember:SetText("Remember my choice for this game")
  cbRemember:SetValue(ply:GetNWBool("sm_remember_power_choice"))
  cbRemember:SizeToContents()
  function cbRemember:OnChange()
    ply:SetNWBool("sm_remember_power_choice", cbRemember:GetChecked())
  end

  Frame:DoModal()
end

--console command for sm_forget_power_choice
--just forget it so they can choose next time
function ForgetPowerChoice(ply, cmd, args)
  ply:SetNWBool("sm_remember_power_choice", false)
end

--UMSG RECEIVER
--launches the power select gui when asked by the server
function LaunchPowerSelectGUI(usrmsg)
  PowerSelectGUI(LocalPlayer())
end
--always add this hook
usermessage.Hook("sm_launch_power_select_gui", LaunchPowerSelectGUI)

--UMSG RECEIVER
--adds relevant hooks if the spider state for this player has changed
function PlayerSpiderStateChanged(usrmsg)
  if (usrmsg:ReadBool()) then
    AddSpiderHooks()
  else
    RemoveSpiderHooks()
  end
end
--always add this hook
usermessage.Hook("sm_player_spider_state_changed", PlayerSpiderStateChanged)


--UMSG RECEIVER
--adds or removes hooks, informs player etc if spidermod has been enabled/disabled
function SpidermodStatusChanged(usrmsg)
  local bEnabled = usrmsg:ReadBool()  

  if (bEnabled)
  and PlayerIsSpider(LocalPlayer()) then
    AddSpiderHooks()
  else
    RemoveSpiderHooks()
  end

  if bEnabled then
    LocalPlayer():PrintMessage(HUD_PRINTTALK, 'Spidermod has been enabled')
  else
    LocalPlayer():PrintMessage(HUD_PRINTTALK, 'Spidermod has been disabled')
  end
end
--always add this hook
usermessage.Hook("sm_spidermod_status_changed", SpidermodStatusChanged)

--concommands

concommand.Add(SpiderConCmd.ForgetPowerChoice, ForgetPowerChoice, SpiderAutoComplete);
concommand.Add(SpiderConCmd.SelectGUIClient, PowerSelectGUI, SpiderAutoComplete);
