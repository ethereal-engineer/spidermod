--SpiderMod Addon serverside code
--Author: ancientevil
--Contact: facepunch.com
--Date: 16th May 2009
--Purpose: The serverside magic of Spidermod.

--helper routines

--tells everyone about something (in their chat space)
function TellAll(message)
  PrintMessage(HUD_PRINTTALK, message)
end

--tells a player a message (chat space)
function TellPly(ply, message)
  if (ply != nil)
  and (ply != NULL)
  and (ply:IsValid()) then
    ply:PrintMessage(HUD_PRINTTALK, message)
  else
    print(message) --most likely this is the server, a nil player, just print it for reference
  end
end

--creates the wallcrawling entity
function CreateWCEntity(ply)
  sm_debug:print("Creating WC Ent for "..tostring(ply))
  if (ply:GetNWEntity("wcam") == NULL) then
    local ent = ents.Create("wcam")
    ent:SetOwner(ply)
    ent:Spawn()
    ply:SetNWEntity("wcam", ent) 
  end
end

--destroys the wallcrawling entity
function DestroyWCEntity(ply)
  sm_debug:print("Destroying WC Ent for "..tostring(ply))
  local wcam = ply:GetNWEntity("wcam")
  if (wcam != NULL) then
    wcam:FinishWallCrawling()
    wcam:Remove()
    ply:SetNWEntity("wcam", NULL)
  end
end

--resets the spider jump charge
function ResetCharge(ply)
  ply:SetNetworkedInt(JumpInfo.ChargeNWIntName,0)
end

--returns the charge percentage of the spider jump
function GetChargePercent(ply)
  return ply:GetNetworkedInt(JumpInfo.ChargeNWIntName) 
end

--sets the charge percentage of the spider jump for a player
function SetChargePercent(ply,val)
  --network intensive - use infrequently as possible
  ply:SetNetworkedInt(JumpInfo.ChargeNWIntName,val)
end

--causes a player to perform a HIGH spider jump
--note that the jump vector is simply straight up - in future
--this will change depending on which way is "down" relative to the
--player
function DoSpiderHighJump(ply,mv)
  jumpVector = Vector(0,0,GetChargePercent(ply) * JumpInfo.Multiplier)
  jumpVector = jumpVector + (JumpInfo.UpVector * JumpInfo.OrdinaryPower)
  mv:SetVelocity(mv:GetVelocity() + jumpVector)  
end

--jump in the direction we are looking - for wallcrawling
function DoSpiderWCJump(ply, mv, wcam)
  jumpLen = GetChargePercent(ply) * JumpInfo.Multiplier
  wcamVelLen = wcam:GetPhysicsObject():GetVelocity():Length()
  jumpVector = ply:GetAimVector() * math.max(jumpLen, wcamVelLen)
  --terminate crawling if any then take off!
  wcam:FinishWallCrawling()
  mv:SetVelocity(jumpVector)
end

--causes a player to perform a LONG spider jump
function DoSpiderLongJump(ply,mv)
  jumpVector = Vector(0,0,math.Round(GetChargePercent(ply)*JumpInfo.LongMultiplier))
  jumpVector = jumpVector + (JumpInfo.UpVector * JumpInfo.OrdinaryPower)
  mv:SetVelocity((ply:GetVelocity() * (1 + GetChargePercent(ply)/100))  + jumpVector)
end

--returns true if a player is in motion
function PlayerInMotion(ply)
  return ply:GetVelocity() != Vector(0,0,0)
end

--causes a player to perform a spider jump (which one depends on the shift key state)
function DoSpiderJump(ply,mv)
  local wcam = ply:GetNWEntity("wcam")
  if wcam:IsActivated() then
    DoSpiderWCJump(ply, mv, wcam)
  elseif ply:KeyDown(IN_SPEED) and PlayerInMotion(ply) then
    DoSpiderLongJump(ply,mv)
  else
    DoSpiderHighJump(ply,mv)
  end
  ResetCharge(ply)
end

--while the charge key is down, charge the spider jump up
function ChargeJump(ply)
  if (GetChargePercent(ply) < JumpInfo.MaxPower) then
    SetChargePercent(ply,math.min(GetChargePercent(ply) + JumpInfo.ChargeDelta,JumpInfo.MaxPower))
  end
end 

--the spiderjump charging starts when this variable is set
function SpiderJumpKeyDown(ply)
  ply:SetVar(JumpInfo.KeyStateNWIntName,sjkDown)
end

--once the jump key is released, this is triggered
function SpiderJumpKeyReleased(ply)
  ply:SetVar(JumpInfo.KeyStateNWIntName,sjkUp)
end

--set the player walk and sprint speeds to spidermod speeds
function DoPlayerSpeedSet(ply)
  GAMEMODE:SetPlayerSpeed(ply,SpeedInfo.PlayerWalkSpeed,SpeedInfo.PlayerSprintSpeed)  
end

--set the player speeds, jumps etc to spidermod speeds
--this includes a timer hack to fix an issue with sandbox
function SetSpiderPlayerSpeeds(ply)
  sm_debug:print("Setting spider speeds for "..tostring(ply))
  ply:SetJumpPower(0)
  ply:SetVar(JumpInfo.KeyStateNWIntName,sjkNone)
  ply:SetCrouchedWalkSpeed(SpeedInfo.PlayerCrouchedWalkSpeed)
  DoPlayerSpeedSet(ply)
  --sandbox gamemode sets the player's speed immediately after hooked PlayerSpawn calls
  --so we have to (yuk) hack a timer to set them again for us (nothing else is called
  --after spawning) - I don't want to override the method completely so we can coexist
  timer.Simple(1, function() DoPlayerSpeedSet(ply) end)
end

--set the player walk, sprint, crouch and jump powers to defaults
function SetNormalPlayerSpeeds(ply)
  sm_debug:print("Setting normal speeds for "..tostring(ply))
  ply:SetJumpPower(JumpInfo.OrdinaryPower)
  ply:SetVar(JumpInfo.KeyStateNWIntName, sjkNone)
  ply:SetCrouchedWalkSpeed(SpeedInfo.DefaultCrouchedWalkSpeed)
  GAMEMODE:SetPlayerSpeed(ply, SpeedInfo.DefaultWalkSpeed, SpeedInfo.DefaultSprintSpeed)
end

--gives the spiderweb SWEP to a player and selects it
function GiveSpiderSWEP(ply)
  ply:Give("weapon_spiderweb")
  ply:SelectWeapon("weapon_spiderweb")
end

--a little text summary of where spidermod is at
function ShowSpiderModStatus(ply)
  if !SpidermodEnabled() then return end
  TellPly(ply, "This server runs Spidermod!")
  TellPly(ply, "Op Mode: "..GetSpiderOpMode())
  TellPly(ply, "Fall Dmg: "..GetFallDamageMode())
end

--hooks

--only those flagged as a spider can pickup the swep unless we
--are in swep mode
function CanPickupWeb(ply, weap)
  if (weap:GetClass() != "weapon_spiderweb") then return end
  if SpidermodEnabled()
  and ((GetSpiderOpMode() == OpMode.SWEP) or PlayerIsSpider(ply)) then
    return true
  else
    return false
  end
end
hook.Add("PlayerCanPickupWeapon", "CanPickupWeb", CanPickupWeb)

--reset and initialise speeds and jump charges
--and create the wallcrawling entity, wcam
function SpiderPlayerInitialSpawn(ply)
  ShowSpiderModStatus(ply)
  if !PlayerIsSpider(ply) then return end
  SetSpiderPlayerSpeeds(ply)
end

--setup the player walk and sprint speeds, altered to match those of the PS2 game
--also set the jump power to 0 so that our jump will not be interrupted (this still plays the sound though...)
function SpiderPlayerSpawn(ply)
  if !PlayerIsSpider(ply) then return end
  --creates a wcam entity for each player if they don't already have one
  --this was moved from initial spawn because the wcam entity is presently able
  --to be destroyed by the strider cannon
  CreateWCEntity(ply)
  SetSpiderPlayerSpeeds(ply)
end

--always spawn the player with the web in his/her hand (and the usual weapons as well)
function SpiderLoadout(ply)
  if PlayerIsSpider(ply) then
    GiveSpiderSWEP(ply)
  end
end

--handle JUMP key releases specially - let the rest go through
--releasing the JUMP key will terminate any wallcrawling
function SpiderKeyRelease(ply, key)
  if !PlayerIsSpider(ply) then return end
  if (key == IN_JUMP) then
    SpiderJumpKeyReleased(ply)
    return false
  end  
end

--handle JUMP key and USE presses specially - let the rest go through
--if JUMP is held then we charge the spider jump
--if USE is pressed then we check if we are elegible for a wall crawl
function SpiderKeyPress(ply, key)
  if !PlayerIsSpider(ply) then return end
  if (key == IN_JUMP) then
    SpiderJumpKeyDown(ply)  
    return false  
  elseif (key == IN_USE) then --TODO: must fix this
    local ent = ply:GetNWEntity("wcam")
    if ent:IsValid() then
      ent:GetTable():Toggle()
    end
    return false
  end
end

--alter the way a player moves to behave more like Spiderman
--TODO: this bobs a little too much in addon mode
function SpiderSetupMove(ply, mv)
  if !PlayerIsSpider(ply) then return end
  local currentJumpKeyState = ply:GetVar(JumpInfo.KeyStateNWIntName)
  local activeWeapon = ply:GetActiveWeapon()
  local webAttached = (activeWeapon != NULL) and (activeWeapon.WebIsAttached)
  local wcam = ply:GetNWEntity("wcam")
  if (wcam == NULL) then return end
  local wallCrawling = wcam:GetTable():IsActivated()
  if (currentJumpKeyState == sjkDown) then
    ChargeJump(ply)
  elseif (currentJumpKeyState == sjkUp) then 
    if (ply:OnGround() or webAttached or wallCrawling) then
      if (webAttached) then
        activeWeapon:GetTable():RemoveWeb()
      end    
      DoSpiderJump(ply,mv)
    else
      ResetCharge(ply)
    end
    ply:SetVar(JumpInfo.KeyStateNWIntName, sjkNone)
  end
end

--take damage like Spiderman - don't fall too far
function SpiderEntityTakeDamage( ent, inflictor, attacker, amount, dmginfo )  
  if ( ent:IsPlayer() and dmginfo:IsFallDamage()) then
    local fdm = GetFallDamageMode()
    if (fdm == FallDamageMode.AllPlayers)
    or ((fdm == FallDamageMode.SpiderOnly) and PlayerIsSpider(ent)) then
      dmginfo:SetDamage(GetSpiderScaledFallDamage(ent))
      GAMEMODE:EntityTakeDamage(ent,inflictor,attacker,amount,dmginfo)
      return false
    end
  end
end

--when a player dies, shut down the wallcrawling entity so that respawning is as normal
function SpiderPlayerDeath(victim, inflictor, killer)
  if PlayerIsSpider(victim) then 
    local wcent = victim:GetNWEntity("wcam")
    wcent:FinishWallCrawling()
    --if a player dies in swep mode, the flag must be reset
    if (GetSpiderOpMode() == OpMode.SWEP) then
      FlagAsSpider(victim, false)
    end
  end
end

--modified version of SetPlayerAnimation so that we run on walls instead of glide
--this section will be used later on to change the animations at any given stage
--(swinging, climbing etc)
--TODO:tidy
function SpiderSetPlayerAnimation( pl, anim )
	local act = ACT_HL2MP_IDLE
	local Speed = pl:GetVelocity():Length()
	local OnGround = pl:OnGround()
  local wcent = pl:GetNWEntity("wcam")

  if (wcent == NULL) or (pl:InVehicle()) or (pl:OnGround()) or !PlayerIsSpider(pl) then 
    GAMEMODE:SetPlayerAnimation(pl, anim)
    return false 
  end --don't handle it if we dont have a cam
--don't handle vehicle stuff
--don't handle onground stuff

  local wcspeed = wcent:GetVelocity():Length()
	
	-- Always play the jump anim if we're in the air - except if we are wallcrawling!
	if ( !OnGround ) then
		
    if wcent:IsActivated() then
      act = ACT_HL2MP_IDLE_CROUCH --we crouch when idle on the wall

      if (wcspeed > 0) then
        act = ACT_HL2MP_WALK_CROUCH --slow speeds are crouch walks
      end

      if (wcspeed > 210) then
        act = ACT_HL2MP_RUN --faster speeds are runs
      end
    else
		  act = ACT_HL2MP_JUMP
    end
	end
	
	// Ask the weapon to translate the animation and get the sequence
	// ( ACT_HL2MP_JUMP becomes ACT_HL2MP_JUMP_AR2 for example)
	local seq = pl:SelectWeightedSequence( pl:Weapon_TranslateActivity( act ) )
		
	// If the weapon didn't return a translated sequence just set 
	//	the activity directly.
	if (seq == -1) then 
	
		// Hack.. If we don't have a weapon and we're jumping we
		// use the SLAM animation (prevents the reference anim from showing)
		if (act == ACT_HL2MP_JUMP) then
	
			act = ACT_HL2MP_JUMP_SLAM
		
		end
	
		seq = pl:SelectWeightedSequence( act ) 
		
	end
	
	// Don't keep switching sequences if we're already playing the one we want.
	if (pl:GetSequence() != seq) then
  	// Set and reset the sequence
	  pl:SetPlaybackRate( 1.0 )
  	pl:ResetSequence( seq )
  	pl:SetCycle( 0 )
  end
  return false
end

--tells the client via umsg to launch the power select screen
function RemoteLaunchPowerSelectGUI(pl)
  umsg.Start("sm_launch_power_select_gui", pl)
  umsg.End()
end

--offer players a sadistic choice...
function SpiderPlayerSelectSpawn(pl)
  if (GetSpiderOpMode() == OpMode.Choice) then
    RemoteLaunchPowerSelectGUI(pl)
  end
end

--enabling/disabling

--adds serverside spidermod hooks
function AddSpiderHooks()
  hook.Add("PlayerLoadout", "SpiderLoadout", SpiderLoadout)
  hook.Add("KeyPress", "SpiderKeyPress", SpiderKeyPress)
  hook.Add("KeyRelease", "SpiderKeyRelease", SpiderKeyRelease)
  hook.Add("PlayerSpawn", "SpiderPlayerSpawn", SpiderPlayerSpawn)
  hook.Add("PlayerInitialSpawn", "SpiderPlayerInitialSpawn", SpiderPlayerInitialSpawn)
  hook.Add("SetupMove", "SpiderSetupMove", SpiderSetupMove)
  hook.Add("EntityTakeDamage", "SpiderEntityTakeDamage", SpiderEntityTakeDamage)
  hook.Add("PlayerDeath", "SpiderPlayerDeath", SpiderPlayerDeath)
  hook.Add("SetPlayerAnimation", "SpiderSetPlayerAnimation", SpiderSetPlayerAnimation)
  hook.Add("PlayerSelectSpawn", "SpiderPlayerSelectSpawn", SpiderPlayerSelectSpawn)
  print('Server hooks added') 
end

--removes serverside spidermod hooks
function RemoveSpiderHooks()
  hook.Remove("PlayerLoadout", "SpiderLoadout")
  hook.Remove("KeyPress", "SpiderKeyPress")
  hook.Remove("KeyRelease", "SpiderKeyRelease")
  hook.Remove("PlayerSpawn", "SpiderPlayerSpawn")
  hook.Remove("PlayerInitialSpawn", "SpiderPlayerInitialSpawn")
  hook.Remove("SetupMove", "SpiderSetupMove")
  hook.Remove("EntityTakeDamage", "SpiderEntityTakeDamage")
  hook.Remove("PlayerDeath", "SpiderPlayerDeath")
  hook.Remove("SetPlayerAnimation", "SpiderSetPlayerAnimation")
  hook.Remove("PlayerSelectSpawn", "SpiderPlayerSelectSpawn")
  print('Server hooks removed')
end

--gives spider powers to all those who are already flagged as spiders
--or in the case that the opmode says that everyone is a spider,
--gives spider powers to all
function BestowGifts()
  for k,v in pairs(player.GetAll()) do 
    FlagAsSpider(v, PlayerIsSpider(v), true)
  end
end

--removes spider powers from everyone
function TakethAwayGifts()
  for k,v in pairs(player.GetAll()) do
    FlagAsSpider(v, false)
  end
end

--flags the player as a spider and if this isn't what he/she was before
--or if we want to force it, the "changed" routine is run to update everything
function FlagAsSpider(ply, flag, forcerefresh)
  if !SpidermodEnabled() then
    --if spidermod is not enabled this will always cause the player to be 
    --refreshed as a human
    flag = false
    forcerefresh = true
  end
  if (ply:GetNWBool("sm_player_is_spider") != flag) then
    ply:SetNWBool("sm_player_is_spider", flag)
    PlayerSpiderStateChanged(ply, flag)
  elseif forcerefesh then
    PlayerSpiderStateChanged(ply, flag)
  end
end

--tell the given player via UMSG to update their spider status and
--do all the actions required of that status
function UpdateClientSpiderState(ply, is_spider)
  umsg.Start("sm_player_spider_state_changed", ply)
  umsg.Bool(is_spider)
  umsg.End()
end

--the state for a given player has changed to what is in "is_spider"
--do all actions required of the new state on the server then pass
--a umsg notification to do the same on the client
function PlayerSpiderStateChanged(ply, is_spider)
  if (is_spider) then
    sm_debug:print("Becoming spider "..tostring(ply))
    if !ply:HasWeapon("weapon_spiderweb") then
      GiveSpiderSWEP(ply)
    end
    SetSpiderPlayerSpeeds(ply)
    CreateWCEntity(ply)
  else
    sm_debug:print("Becoming human "..tostring(ply))
    ply:StripWeapon("weapon_spiderweb")
    DestroyWCEntity(ply)
    SetNormalPlayerSpeeds(ply)
  end
  --whenever a player's spider state changes, do the server stuff first then
  --let the client themselves know
  UpdateClientSpiderState(ply, is_spider)
end

--sets the operation mode of the addon, triggering changes where needed
--this can only be run by the admin or server itself
function SetSpiderOpMode(opmode, ply)
  if (ply != NULL)
  and (ply != nil)
  and not ply:IsAdmin() then
    TellPly(ply, SpiderConCmd.OpMode..' can only be invoked by the server admin')
    return
  end
  --team mode bug out
  if (opmode == OpMode.Team) then
    TellPly(ply, 'Sorry. The "team" opmode is not yet implemented.')
    return
  end
  if table.HasValue(OpMode, opmode) then
    local oldOpMode = GetSpiderOpMode()
    SetGlobalString(SpiderModConst.OpModeVarName, opmode)
    OpModeChanged(oldOpMode, opmode)
  else
    TellPly(ply, 'Invalid opmode '..opmode)
  end
end

--console command sm_opmode
function GetSetOpMode(ply, cmd, args)
  if (table.Count(args) == 0) then
    print(GetSpiderOpMode())
  else
    SetSpiderOpMode(args[1], ply)
  end
end

--console command sm_setspiderteams
function SetSpiderTeams(ply, cmd, args)
  table.Empty(SpiderTeams)
  for k,v in pairs(args) do 
    for x,y in pairs(team.GetAllTeams()) do
      if table.HasValue(args, y:GetName()) then
        table.insert(SpiderTeams, y)
      end
    end 
  end
end

--console command sm_falldamagemode
function GetSetFallDamageMode(ply, cmd, args)
  if (table.Count(args) == 0) then
    print(GetFallDamageMode())
  else
    SetFallDamageMode(args[1], ply)
  end  
end

--sets the fall damage mode and tells everyone about it
function SetFallDamageMode(fdm, ply)
  if table.HasValue(FallDamageMode, fdm) then
    SetGlobalString(DamageInfo.FallModeVarName, fdm)
    TellAll('Spidermod falldamage mode is set to '..fdm)
  else
    TellPly(ply, 'Invalid falldamage mode '..fdm)
  end
end

--console command sm_enable
function GetSetSpidermodEnable(ply, cmd, args)
  if (table.Count(args) == 0) then
    print(SpidermodEnabled())
  else
    EnableSpidermod(ply, cmd, args)
  end  
end

--depending on what mode we are in, this will be used to turn the SWEP's ability to be
--spawned from the weapons menu on and off (doesn't affect the admin)
function SpawnSWEPFromMenu(show)
  if (weapons.GetStored("weapon_spiderweb") == nil) then return end
  weapons.GetStored("weapon_spiderweb").Spawnable = show  
end

--the opmode has changed - tell everyone and give out gifts if needed
--also restricts the spawn ability of the web swep
function OpModeChanged(oldOpMode, newOpMode)
  TellAll('Spidermod OpMode is set to '..newOpMode)
  SpawnSWEPFromMenu(newOpMode == OpMode.SWEP)
  BestowGifts()
end

--console command sm_select_power
function PlayerSelectPower(ply, cmd, args)
  FlagAsSpider(ply, args[1] == PowerScheme.Spider)
end

--sends a UMSG to the client to update them of the
--enabled status of spidermod
function UpdateClientSpidermodStatus(is_enabled)
  umsg.Start("sm_spidermod_status_changed")
  umsg.Bool(is_enabled)
  umsg.End()
end

--enables or disables spidermod
--adds/removes hooks, informs clients etc
function EnableSpidermod(ply, cmd, args)
  if (ply != NULL)
  and (ply != nil)
  and not ply:IsAdmin() then
    TellPly(ply, SpiderConCmd.Enable..' can only be invoked by the server admin')
    return
  end

  local argOne = args[1]:lower():Trim()

  local is_enabled = (argOne == "1") or (argOne == "true")

  if (is_enabled) == SpidermodEnabled() then return end

  if (is_enabled) then
    TellPly(ply, 'Enabling Spidermod...')
    BestowGifts(false)
    AddSpiderHooks()
    SetGlobalBool(SpiderModConst.EnabledVarName, true)
  else
    TellPly(ply, 'Disabling Spidermod...')
    TakethAwayGifts()
    RemoveSpiderHooks()
    SetGlobalBool(SpiderModConst.EnabledVarName, false)
  end
  UpdateClientSpidermodStatus(is_enabled)
end

--defaults
SetFallDamageMode(FallDamageMode.SpiderOnly)
SetSpiderOpMode(OpMode.SWEP)

--concommands
concommand.Add(SpiderConCmd.FallDamageMode, GetSetFallDamageMode, SpiderAutoComplete)
--concommand.Add(SpiderConCmd.SetTeams, SetSpiderTeams, SpiderAutoComplete)
concommand.Add(SpiderConCmd.OpMode, GetSetOpMode, SpiderAutoComplete)
concommand.Add(SpiderConCmd.Enable, GetSetSpidermodEnable, SpiderAutoComplete)
concommand.Add(SpiderConCmd.SelectPower, PlayerSelectPower, SpiderAutoComplete)
