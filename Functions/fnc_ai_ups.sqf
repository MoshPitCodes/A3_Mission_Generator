//
//  Urban Patrol Script Zeus Edition
//  Version: 1.0
//  Author: 2600K & Kronzky (www.kronzky.info / kronzky@gmail.com)
//  BIS Forum: http://forums.bistudio.com/showthread.php?147904-Urban-Patrol-Script&highlight=Urban+Patrol+Script
//
//  Required parameters:
//    unit          = Unit to patrol zone
//    markername    = Name of marker/trigger that covers the active zone
//
//  Optional parameters: 
//    RANDOM        = Start unit at random position in zone
//    NOWP        	= Unit will hold position until enemy is spotted
//    NOFOLLOW      = Unit will only follow an enemy within the marker zone.
//    NOSLOW        = Keep default behaviour of unit (don't change to "safe" and "limited").
//    NOAI          = Don't use enhanced AI for evasive and flanking maneuvers.
//    SHOWMARKER    = Display the zone marker.
//    TRACK         = Display a position and destination marker for each unit.
//
//	  _nul = [this,"UPSZ","RANDOM"] execVM "scripts\UPS\UPS_Lite.sqf";
//
if !isServer exitWith {};

// Global Script Variables
_cycle = 5; 		// Script Cycle Time (seconds)
_safeDist = 200; 	// How far to move when under attack in meters
_closeEnough = 50; 	// WP Completion Radius
_shareDist = 500; 	// AI Comms Range in meters
_alertTime = 60; 	// AI Alert after spotting enemy
_artyTime = 120;	// Arty delay between firing
_artyRural = 250;	// Arty dispersion in rural areas
_artyUrban = 150;	// Arty dispersion in urban areas

// Disable debug mode if not set
if (isNil "ZAI_Debug") then { ZAI_Debug = FALSE };

// Message Logging Function
_ZAI_LogMsg = {
	params [["_lev", ""], ["_msg", ""]];
	if (ZAI_Debug || _lev != "DEBUG") then { 
		systemChat format["UPS %1: %2",_lev, _msg];
		diag_log text format["[UPS] %1: %2",_lev, _msg];
	};
};

// We need a group and marker as minimum
if (count _this < 2) exitWith {
	if (format["%1",_this]!="INIT") then {
		["ERROR", "Unit and marker name have to be defined!"] call _ZAI_LogMsg;
	};
};

// Convert params to UPPER CASE
_params = [];
{ if ( _x isEqualType "" ) then { _params pushBack (toUpper _x) } } forEach _this;

params ["_grp", "_areaMarker"];

if (isNil "_areaMarker") exitWith { ["ERROR", "Area marker not defined. Typo, or name not enclosed in quotation marks?"] call _ZAI_LogMsg };	

private ["_areaName","_areaSize"];

if (_areaMarker isEqualType "") then {
	_areaName = _areaMarker;
	_areaSize = getMarkerSize _areaMarker;
	if !("SHOWMARKER" in _params) then { _areaMarker setMarkerAlpha 0; };
} else {
	_areaName = vehicleVarName _areaMarker;
	_areaSize = triggerArea _areaMarker;
};

if (_areaSize#0 == 0 || count _areaSize == 0) exitWith { ["ERROR", format["Invalid Marker/Trigger: %1",_areaName]] call _ZAI_LogMsg };

// Minimum WP distance
_minDist = (_areaSize#0 + _areaSize#1) / 4;

// Wait until mission start to continue
sleep 3 + random 3;

// Update instance counter.
missionNamespace setVariable ["ZAI_ID", (missionNamespace getVariable ["ZAI_ID", 0]) + 1];

if (isNil "_grp") exitWith { ["ERROR", format["Invalid Object %1", _grp]] call _ZAI_LogMsg };
if (_grp isEqualType objNull) then { _grp = group _grp };
if ({alive _x} count units _grp == 0) then { ["ERROR", format["No living units in %1", _grp]] call _ZAI_LogMsg };

if ((_grp getVariable ["ZAI_ID", -1]) > 0) exitWith { ["ERROR", format["UPS Already Active on %1", _grp]] call _ZAI_LogMsg };

// give this group a unique index
_grpIDx = str ZAI_ID;
_grp setGroupId [format["ZAI_%1_%2", side _grp, _grpIDx]];
_grp setVariable ["ZAI_ID", ZAI_ID];
missionNamespace setVariable [format ["ZAI_%1_%2", side _grp, _grpIDx], _grp];

// What type of "vehicle" is unit ?
_isAir = {assignedVehicle _x isKindOf "air"} count units _grp > 0;
_isBoat = {assignedVehicle _x isKindOf "ship"} count units _grp > 0;
_isCar = {assignedVehicle _x isKindOf "car"} count units _grp > 0 || {assignedVehicle _x isKindOf "tank"} count units _grp > 0 || {assignedVehicle _x isKindOf "armored"} count units _grp > 0;
_isArty = {assignedVehicle _x isKindOf "StaticMortar"} count units _grp > 0;
_isStatic = {assignedVehicle _x isKindOf "staticWeapon"} count units _grp > 0 || {assignedVehicle _x isKindOf "static"} count units _grp > 0;

_isMan = !_isAir && !_isBoat && !_isCar && !_isStatic && !_isArty;

// Make the leader the driver since RHS hates
_grpVehicle = objNull;
{ 
	if (!isNull assignedVehicle _x) then { _grpVehicle = vehicle _x };
} forEach units _grp;

if (!isNull _grpVehicle) then { _grp selectLeader driver _grpVehicle };

_upsType = ([(["","Man"] select _isMan), (["","Air"] select _isAir), (["","Ship"] select _isBoat), (["","Vehicle"] select _isCar), (["","Static"] select _isStatic), (["","Artillery"] select _isArty) ] - [""]) joinString ", ";
["DEBUG", format["[%1] was detected as %2", groupID _grp, _upsType]] call _ZAI_LogMsg;

// Tolerance high for choppers & planes
if _isAir then { _closeEnough = 5000 };

// check to see whether group is neutral (for attack and avoidance manoeuvres)
_isSoldier = FALSE;
{
	if (side _grp getFriend _x < 0.6) exitWith { _isSoldier = TRUE };
} forEach [EAST, WEST, INDEPENDENT, CIVILIAN];

_alliedUnitList = [];

if _isSoldier then {
	{
		if ([side _x, side _grp] call BIS_fnc_areFriendly) then { _alliedUnitList pushBack _x };
	} forEach allUnits;
};

_alliedUnitList = _alliedUnitList - (switchableUnits + playableUnits) - (units _grp);

// Remember the original group members
_grpUnits = units _grp;

_noFollow = ("NOFOLLOW" in _params);
_noShare = ("NOSHARE" in _params);
_holdMove = ("NOMOVE" in _params || "NOWP" in _params);
if ("NOAI" in _params) then {_isSoldier = FALSE }; // suppress fight behaviour

if (!_holdMove && !("NOSLOW" in _params)) then {
	_grp setBehaviour "SAFE"; 
	_grp setSpeedMode "LIMITED";
};

// Set random pos if required.
_unitPos = getPos leader _grp;
if ("RANDOM" in _params) then {
	if (dynamicSimulationEnabled _grp) then { ["WARNING", format["%1 at %2 has DS Enabled", _grp, getPos leader _grp]] call _ZAI_LogMsg };
	
	// Find a random position (try a max of 20 positions)
	_randPos = _unitPos;
	for "_i" from 1 to 20 do {
		_randPos = [_areaMarker] call BIS_fnc_randomPosTrigger;
		
		if (_isAir) exitWith {};
		if (_isBoat && surfaceIsWater _randPos) exitWith {};
		if (!surfaceIsWater _randPos) exitWith {};
	};
	
	// Put vehicle to a random spot
	if (!isNull _grpVehicle) then {
		_tempPos = _randPos findEmptyPosition [0, 25, typeOf _grpVehicle];
		if (count _tempPos > 0) then { _grpVehicle setPos _tempPos } else { _grpVehicle setPos _randPos };
	};
	
	// Move anyone over 150m away to the area.
	_randPos = [_randPos, 1, 50, 2, 0, 0, 0, [], [_unitPos,_unitPos]] call BIS_fnc_findSafePos;
	{
		if (getPos _x distance2D _randPos > 150) then { _x setPos _randPos };
	} forEach units _grp;
};

// track unit
_trackGrp = ("TRACK" in _params || ZAI_Debug);
if (_trackGrp) then {
	_trakMarker = createMarkerLocal [format["trk_%1",_grpIDx], [0,0]];
	_trakMarker setMarkerShapeLocal "ICON";
	_trakMarker setMarkerTypeLocal "MIL_DOT";
	_trakMarker setMarkerColorLocal format["Color%1", side _grp];
	_trakMarker setMarkerTextLocal format["%1", _grpIDx];
	_trakMarker setMarkerPosLocal (getPos leader _grp); 
	_trakMarker setMarkerSizeLocal [.5,.5];
};	

// UPS Loop Common Variables
_lastDamage = 0;
_lastCount = 0;
_lastPos = _unitPos;
_timeOnTarget = 0;

if _isMan then { { _x disableAI "AUTOCOMBAT" } forEach units _grp };
_grp deleteGroupWhenEmpty TRUE; // Don't keep the group when empty.

// ************************************************ MAIN LOOP ************************************************
_currCycle = _cycle;

while {TRUE} do {
	if (isNil "_grp") exitWith {}; // Group was deleted?
	if (units _grp select { alive _x } isEqualTo []) exitWith {}; // No-one is alive.
	if ({isPlayer _x} count units _grp > 0) exitWith { { if (isPlayer _x) exitWith { _grp selectLeader _x } } forEach units _grp }; // Player is in the group, make them lead and exit.

	//_timeOnTarget = _timeOnTarget + _currCycle; // Track duration moving towards a destination
	//_react = _react + _currCycle;
	_wasHit = FALSE;

	// Check for damage to group
	_newDamage = 0; 
	{
		if (damage _x > 0.2) then {
			_newDamage = _newDamage + (damage _x); 
			// Increased since last check
			if (_newDamage > _lastDamage) then {
				["DEBUG", format["[%1] Taken Damage (%2/%3)", _grpIDx, _newDamage, _lastDamage]] call _ZAI_LogMsg;
				_lastDamage = _newDamage; 
				_wasHit = TRUE;
				_currCycle = 1;
			};
			if (!alive _x) then {
				_grpUnits = _grpUnits - [_x]; 
				_alliedUnitList = _alliedUnitList - [_x];
			};
		};
	} forEach _grpUnits;
	
	// groups current position
	_unitPos = getPos leader _grp;
	if (_trackGrp) then { format["trk_%1",_grpIDx] setMarkerPos _unitPos; };
	
	// if the AI is a civilian we don't have to bother checking for enemy encounters
	_foundEnemy = leader _grp findNearestEnemy _unitPos;
	
	// Enemy was detected plan attack route
	if (leader _grp distance2D _foundEnemy < 1500) then {		
		// If we're in safe, go aware.
		if (behaviour leader _grp == "SAFE") then { leader _grp setBehaviour (["COMBAT", "AWARE"] select _isMan) };

		// Send to other allies.
		if (!_noShare) then {			
			{
				if (_x knowsAbout _foundEnemy < _grp knowsAbout _foundEnemy) then { 
					["DEBUG", format["[%1] Revealed [%2] to [%3] (%4/%5)", _grpIDx, _foundEnemy, group _x, _x knowsAbout _foundEnemy, _grp knowsAbout _foundEnemy]] call _ZAI_LogMsg;
					(group _x) reveal _foundEnemy;
				};
			} forEach (_alliedUnitList select {(_x distance2D _foundEnemy < _shareDist || _isStatic) && leader _x isEqualTo _x});
		};
		
		// Recently reacted, enemy going too fast or too far
		if (_timeOnTarget > time || speed _foundEnemy > 100 || leader _grp distance2D _foundEnemy > _shareDist) exitWith {};
		
		["DEBUG", format["[%1] Attacking (%2 %3m)", _grpIDx, name _foundEnemy, leader _grp distance2D _foundEnemy]] call _ZAI_LogMsg;
		
		// Final location depends of knowsAbout of enemy.
		_enemyOffset = (21 - ((_grp knowsAbout _foundEnemy) * 5)) * 5;
		_attackPos = _foundEnemy getPos [random _enemyOffset, random 360];
		
		// In contact with target so request a fire mission at target position.
		if (_wasHit) then {
			 missionNamespace setVariable ["ZAI_ArtyRequest", _attackPos];
			 
			// If infantry were shot, return fire
			if (_isMan) then {
				{ _x enableAI "AUTOCOMBAT"; _x setUnitPosWeak "DOWN" } forEach units _grp;
				{ 
					_x doWatch _foundEnemy; 
					if (random 1 > 0.5) then { sleep 1; _x selectWeapon "throw"; _x forceWeaponFire ["SmokeShellMuzzle","SmokeShellMuzzle"] };
				} forEach units _grp;
				
				(selectRandom units _grp) suppressFor (10 + random 10);
			};
		};
			
		if _isStatic exitWith {};
		
		_timeOnTarget = time + _alertTime;
		_holdMove = FALSE;
		
		_upsUnit = leader _grp;
		_avoidPos = _upsUnit getRelPos [_safeDist,(_upsUnit getRelDir _foundEnemy) - (90 + random 25 - random 25)]; // Left of Unit
		_flankPos = _foundEnemy getRelPos [_safeDist,(_foundEnemy getRelDir _upsUnit) + (90 + random 25 - random 25)]; // Left of Target
		
		_avoidPosR = _upsUnit getRelPos [_safeDist,(_upsUnit getRelDir _foundEnemy) + (90 + random 25 - random 25)]; // Right of Unit
		_flankPosR = _foundEnemy getRelPos [_safeDist,(_foundEnemy getRelDir _upsUnit) - (90 + random 25 - random 25)]; // Right of Target
		
		// If one side is closer than the other, go that way.
		if (_upsUnit distance2D _flankPosR < _upsUnit distance2D _flankPos) then { _avoidPos = _avoidPosR; _flankPos = _flankPosR };	
		
		// Find a suitable road nearby
		_roads = (_flankPos nearRoads 100) select { count (roadsConnectedTo _x) > 0};
		if (_isCar && !(_roads isEqualTo [])) then { _flankPos = getPos (_roads#0) };
		
		// Add evade position if on food and close to target.
		_evadeWPs = if (_isMan && (_unitPos distance2D _attackPos < _safeDist || _wasHit)) then { [_avoidPos, _flankPos, _attackPos] } else { [_flankPos, _attackPos] };
		
		// Clear wayPoints	
		while {count wayPoints _grp > 0} do { deleteWaypoint ((wayPoints _grp)#0) };
		//_grp addWaypoint [getPos leader _grp,0];
		
		{
			_wp = _grp addWaypoint [_x, 0];
			_wp setWaypointPosition [_x, 0];
			_wp setWaypointType "MOVE";
			_wp setWaypointFormation selectRandom ["LINE", "WEDGE", "DIAMOND"];		
			_wp setWaypointSpeed (["NORMAL", "FULL"] select _isCar);
			_wp setWaypointBehaviour (["AWARE", "COMBAT"] select _isCar);
			_wp setWaypointCompletionRadius (_closeEnough / 2);
			
			if (_x isEqualTo _flankPos && !canFire (vehicle leader _grp)) then { _wp setWaypointType "GETOUT" };
			if (_x isEqualTo _attackPos) then { _wp setWaypointType "SAD" };
			if (_forEachIndex == 0) then { _grp setCurrentWaypoint _wp };
		} forEach _evadeWPs;

		// If marker isn't in the area, don't move out of it (TODO: Map to nearest location?)
		if (_noFollow) then {
			if !(_avoidPos inArea _areaName) then { _avoidPos = _unitPos };
			if !(_flankPos inArea _areaName) then { _flankPos = _unitPos };
			if !(_attackPos inArea _areaName) then { _attackPos = _unitPos };
			if !(_targetPos inArea _areaName) then { _targetPos = _unitPos };
		};
		
		if ZAI_Debug then {
			_grpName = format["UPS_%1_%2",side _grp, _grpIDx];
			{
				_x params ["_type","_pos","_color"];
				if (_pos in _evadeWPs && isNil format ["Marker_%1_%2",_grpName,_type]) then {
					private _tempMarker = createMarkerLocal [format ["Marker_%1_%2",_grpName,_type],_pos];
					_tempMarker setMarkerTypeLocal "mil_objective";
					_tempMarker setMarkerColorLocal _color;
					_tempMarker setMarkerTextLocal format["%1:%2",_type,_grpIDx];
					_tempMarker setMarkerSizeLocal [.5,.5];
				};
				format ["Marker_%1_%2",_grpName,_type] setMarkerPosLocal _pos;
				format ["Marker_%1_%2",_grpName,_type] setMarkerAlphaLocal 1;
			} forEach [["Evade",_avoidPos,"ColorOrange"],["Flank",_flankPos,"ColorGreen"],["Target",_attackPos,"ColorYellow"]];
		};
	} else {
		// Reset combat mode to aware to keep units moving
		if (_isMan && behaviour leader _grp == "COMBAT") then { {_x disableAI "AUTOCOMBAT"; _x setBehaviour "AWARE" } forEach units _grp };
	};
				
	// Find new WP if we don't have one
	if (!_isStatic && !_holdMove && (count wayPoints _grp) - (currentWaypoint _grp) isEqualTo 0) then {	
		// find a new target that's not too close to the current position
		_newGrpPos = getPos leader _grp;				
		
		_tries = 0;
				
		while {(_unitPos distance2D _newGrpPos) < _minDist} do {
			_tries = _tries + 1;
			_tempPos = [_areaMarker] call BIS_fnc_randomPosTrigger;					
			_roads = (_tempPos nearRoads 100) select { count (roadsConnectedTo _x) > 0};
			_water = surfaceIsWater _tempPos;
			
			// Air takes any location.
			if _isAir exitWith { _newGrpPos = _tempPos };
			
			// Boats need water.
			if (_water && _isBoat) exitWith { _newGrpPos = _tempPos };
			
			// Cars need a road
			if (!_water && _isCar && !(_roads isEqualTo [])) exitWith { _newGrpPos = getPos (_roads#0) };
			
			// Infantry
			if (!_water && _isMan && !(_roads isEqualTo []) && random 1 > 0.5) exitWith { _newGrpPos = getPos (_roads#0) };
			if (!_water && _isMan) exitWith { _newGrpPos = _tempPos; };
			
			if (_tries > 10) exitWith { 
				["WARNING", format["[%1] Tried %2 times to find WP [%3]",_grpIDx, _tries, _upsType]] call _ZAI_LogMsg;
				_newGrpPos = _tempPos
			};
			
			sleep 0.1;
		};
		["DEBUG", format["[%1] Found WP %2m after %3 tries",_grpIDx, round (_unitPos distance2D _newGrpPos), _tries]] call _ZAI_LogMsg;
				
		_wp = _grp addWaypoint [_newGrpPos, 0];
		_wp setWaypointPosition [_newGrpPos, 0];
		_wp setWaypointType (["MOVE", "SAD"] select (_isMan && random 1 < 0.1));
		_wp setWaypointFormation selectRandom ["FILE", "COLUMN", "DIAMOND"];
		_wp setWaypointSpeed "LIMITED";
		_wp setWaypointBehaviour (["AWARE", "SAFE"] select (missionNamespace getVariable ["ZAI_ArtyRequest", []] isEqualTo []));
		_wp setWaypointCompletionRadius (_closeEnough / 2);
		_grp setCurrentWaypoint _wp;
	};
	
	// Artillery Support
	if _isArty then {	
		_artyTarget = missionNamespace getVariable ["ZAI_ArtyRequest", []];
		if (_artyTarget isEqualTo []) exitWith {};
		
		if (_timeOnTarget > time) exitWith {
			["DEBUG", format["[%1] Artillery Aborted (%2s until ready)", _grpIDx, _timeOnTarget - time]] call _ZAI_LogMsg;
		};
		
		_artyRadius = if ((count (nearestObjects [_artyTarget, ["building"], 50]) > 8)) then { _artyUrban } else { _artyRural }; // 150 urban, 250 otherwise
		
		// Wait 30s before rechecking
		if (!canFire (vehicle leader _grp) || {alive _x && !isAgent teamMember _x && side _x in [side _grp, CIVILIAN]} count (_artyTarget nearEntities [["Man"], (_artyRadius - 50)]) > 0) exitWith {
			_timeOnTarget = time + 5;
			["DEBUG", format["[%1] Artillery Aborted (%2)", _grpIDx, [format["Allies within %1m", _artyRadius],"Gun Disabled"] select (!canFire (vehicle leader _grp))]] call _ZAI_LogMsg;
			
		};

		["DEBUG", format["[%1] Artillery Mission (%2)", _grpIDx, _artyTarget]] call _ZAI_LogMsg;
		
		for "_i" from 1 to 8 do {
			leader _grp commandArtilleryFire [(_artyTarget getPos [random _artyRadius, random 360]), (getArtilleryAmmo [vehicle leader _grp] select 0), 1];
			sleep 2 + random 2;
		};
		
		(vehicle leader _grp) setVehicleAmmo 1;
		missionNamespace setVariable ["ZAI_ArtyRequest", []];
		_timeOnTarget = time + _artyTime;
	};

	// Check for any AI Issues!
	if (!_isStatic && !_holdMove && !dynamicSimulationEnabled _grp && !dynamicSimulationEnabled _grpVehicle) then {
		if ((_lastPos distance2D getPos leader _grp) == 0) then {
			_lastCount = _lastCount + 1;
			
			// Vehicles
			if (!_isMan) then {
				if (_lastCount == 10) then { 
					while {count wayPoints _grp > 0} do { deleteWaypoint ((wayPoints _grp)#0) };
					_wp = _grp addWaypoint [getPos leader _grp, 0];
					["WARNING", format["[%1] Vehicle has not moved for %2 cycles", _grpIDx, _lastCount]] call _ZAI_LogMsg;
				};
				if (_lastCount == 20) then {
					vehicle leader _grp setFuel 0.05;
					_grp leaveVehicle vehicle leader _grp;
					["WARNING", format["[%1] Vehicle has not moved for %2 cycles", _grpIDx, _lastCount]] call _ZAI_LogMsg;
				};
			};
			
			// Infantry
			if (_isMan) then {
				if (_lastCount MOD 5 == 0) then {
					(leader _grp) selectWeapon primaryWeapon (leader _grp);
					["WARNING", format["[%1] Leader has not moved for %2 cycles", _grpIDx, _lastCount]] call _ZAI_LogMsg;
				};
				if (_lastCount == 15) then {
					{
						_x setPos ([getPos _x, 1, 25, 2, 0, 0, 0, [], [getPos _x, getPos _x]] call BIS_fnc_findSafePos);
					} forEach units _grp;
					["WARNING", format["[%1] Leader has not moved for %2 cycles", _grpIDx, _lastCount]] call _ZAI_LogMsg;
				};
			};
		} else {
			_lastCount = 0;
		};
	};
	
	_lastPos = getPos leader _grp;
	
	// slowly increase the cycle duration after an incident
	if (_currCycle < _cycle) then { _currCycle = _currCycle + 0.5};
	sleep _currCycle;
};

["DEBUG", format["[%1] Loop Aborted!", _grpIDx]] call _ZAI_LogMsg;