// Set-up mission variables.
params [ ["_zoneID", 0], ["_targetPos", [0,0,0]] ];

private _centre = missionNamespace getVariable [format["ZMM_%1_Location", _zoneID], _targetPos];
private _enemySide = missionNamespace getVariable [format["ZMM_%1_EnemySide", _zoneID], EAST];
private _enemyMen = missionNamespace getVariable [format["ZMM_%1Man", _enemySide], ["O_Solider_F"]];
private _locName = missionNamespace getVariable [format["ZMM_%1_Name", _zoneID], "this Location"];
private _locType = missionNamespace getVariable [format["ZMM_%1_Type", _zoneID], "Custom"];
private _missionDesc = selectRandom [
		"The enemy has engaged a cargo transport over %2, search the crash site for nearby for <font color='#00FFFF'>%1 Crates or Boxes</font> and collect them.",
		"An enemy transporter has crashed near %2, search the area for <font color='#00FFFF'>%1 Crates or Boxes</font> and secure them.",
		"<font color='#00FFFF'>%1 Crates or Boxes</font> have been spotted near a wreck at %2, move in and recover them.",
		"Search for and collect the <font color='#00FFFF'>%1 Crates or Boxes</font> at a downed transport somewhere around %2.",
		"A transporter carrying supplies has crashed at %2. Secure the area and recover the <font color='#00FFFF'>%1 Crates or Boxes</font> before they can fall into enemy hands.",
		"A crashed transport has been spotted near %2. Find the <font color='#00FFFF'>%1 Crates or Boxes</font> before the enemy can and collect them."
	];
	
if (_centre isEqualTo _targetPos || _targetPos isEqualTo [0,0,0]) then { _targetPos = [_centre, 25, 200, 5, 0, 0.5, 0, [], [ _centre, _centre ]] call BIS_fnc_findSafePos; _targetPos set [2,0]; };

// Create Objective
private _wreck = (selectRandom [ "Land_Mi8_wreck_F", "Land_Wreck_Heli_02_Wreck_01_F"]) createVehicle _targetPos;
_wreck setVectorUp surfaceNormal position _wreck;

_wreck addEventHandler ["Explosion", {
	params ["_vehicle", "_damage"];
	for "_i" from 0 to random 3 do { private _exp = "Bo_GBU12_LGB" createVehicle (_vehicle getPos [random 3, random 360]) };
	deleteVehicle _vehicle;
	_vehicle removeEventHandler ["Explosion", _thisEventhandler];
}];

missionNamespace setVariable [format["ZMM_%1_OBJ_WRECK", _zoneID], _wreck];

private _wreckTask = [[format["ZMM_%1_SUB_WRECK", _zoneID], format['ZMM_%1_TSK', _zoneID]], true, [format["Locate the wreck somewhere within the marked area.<br/><br/>Target: <font color='#00FFFF'>%1</font><br/><br/><img width='300' image='%2'/>", getText (configFile >> "CfgVehicles" >> typeOf _wreck >> "displayName"), getText (configFile >> "CfgVehicles" >> typeOf _wreck >> "editorPreview")], "Destroy Wreck", format["MKR_%1_LOC", _zoneID]], objNull, "CREATED", 1, false, true, "destroy"] call BIS_fnc_setTask;
private _wreckTrigger = createTrigger ["EmptyDetector", _targetPos, false];
_wreckTrigger setTriggerArea [5, 5, 0, false];
_wreckTrigger setTriggerStatements [ "{_x inArea thisTrigger} count allMissionObjects '#explosion' > 0",
	format["deleteVehicle ZMM_%1_OBJ_WRECK; ['ZMM_%1_SUB_WRECK', 'Succeeded', true] spawn BIS_fnc_taskSetState;", _zoneID, _i],
	"" ];

private _crateActivation = [format["!alive ZMM_%1_OBJ_WRECK", _zoneID]];

private _smoke = createVehicle ["test_EmptyObjectForSmoke",position _wreck, [], 0, "CAN_COLLIDE"];
private _crater = createSimpleObject ["CraterLong", AGLToASL position _wreck];
_crater setVectorUp surfaceNormal position _wreck;

// Generate the crates.
for "_i" from 1 to (missionNamespace getVariable ["ZZM_ObjectiveCount", 3]) do {
	private _ammoType = selectRandom ["Box_Syndicate_Ammo_F","Box_Syndicate_WpsLaunch_F","Land_PaperBox_01_small_closed_white_med_F","Land_PaperBox_01_small_closed_brown_food_F","Box_East_Ammo_F","Box_EAF_AmmoOrd_F","Box_IND_Grenades_F"];
	private _ammoPos = [_centre, 100 + random 50, 200, 2, 0, 0.5, 0, [], [ _targetPos, _targetPos ]] call BIS_fnc_findSafePos;
	_ammoPos = _ammoPos findEmptyPosition [1, 25, _ammoType];

	if (count _ammoPos > 0) then { 
		private _ammoObj = createVehicle [_ammoType, _ammoPos, [], 0, "NONE"];
		_ammoObj allowDamage false;
		_ammoObj setDir random 90;
		
		missionNamespace setVariable [format["ZMM_%1_OBJ_%2", _zoneID, _i], _ammoObj];
		
		_crateActivation pushBack format["!alive ZMM_%1_OBJ_%2", _zoneID, _i];
		
		clearWeaponCargoGlobal _ammoObj;
		clearMagazineCargoGlobal _ammoObj;
		clearItemCargoGlobal _ammoObj;
		clearBackpackCargoGlobal _ammoObj;
				
		private _mrkr = createMarker [format["MKR_%1_OBJ_%2", _zoneID, _i], _ammoPos getPos [random 50, random 360]];
		_mrkr setMarkerShape "ELLIPSE";
		_mrkr setMarkerBrush "SolidBorder";
		_mrkr setMarkerSize [50,50];
		_mrkr setMarkerAlpha 0.4;
		_mrkr setMarkerColor format["Color%1",_enemySide];
		
		[_ammoObj, 
				format["<t color='#00FF80'>Take %1</t>", getText (configFile >> "CfgVehicles" >> _ammoType >> "displayName")], 
				"\a3\ui_f\data\IGUI\Cfg\holdActions\holdAction_Search_ca.paa", 
				"\a3\ui_f\data\IGUI\Cfg\holdActions\holdAction_Search_ca.paa", 
				"_this distance2d _target < 3", 
				"_caller distance2d _target < 3", 
				{}, 
				{}, 
				{
					_caller playAction "PutDown"; 
					sleep 1;
					deleteVehicle _target;
					(parseText format["<t size='1.5' color='#72E500'>Crate Collected:</t><br/><t size='1.25'>%2</t><br/><br/><img size='2' image='\a3\ui_f\data\IGUI\Cfg\simpleTasks\types\search_ca.paa'/><br/><br/>Found By: <t color='#0080FF'>%1</t><br/>", name _caller, getText (configFile >> "CfgVehicles" >> typeOf _target >> "displayName")]) remoteExec ["hintSilent"];
				}, 
				{}, 
				[], 
				2, 
				10 
			] remoteExec ["bis_fnc_holdActionAdd", 0, _ammoObj];
						
		// Child task
		private _childTask = [[format["ZMM_%1_SUB_%2", _zoneID, _i], format['ZMM_%1_TSK', _zoneID]], true, [format["Locate the crate somewhere within the marked area.<br/><br/>Target Object: <font color='#00FFFF'>%1</font><br/><br/><img width='300' image='%2'/>", getText (configFile >> "CfgVehicles" >> _ammoType >> "displayName"), getText (configFile >> "CfgVehicles" >> _ammoType >> "editorPreview")], format["Crate #%1", _i], format["MKR_%1_OBJ_%2", _zoneID, _i]], getMarkerPos _mrkr, "CREATED", 1, false, true, format["move%1", _i]] call BIS_fnc_setTask;
		private _childTrigger = createTrigger ["EmptyDetector", _ammoPos, false];
		_childTrigger setTriggerStatements [ format["!alive ZMM_%1_OBJ_%2", _zoneID, _i],
			format["['ZMM_%1_SUB_%2', 'Succeeded', true] spawn BIS_fnc_taskSetState; deleteMarker 'MKR_%1_OBJ_%2';", _zoneID, _i],
			"" ];

		// Create enemy Team
		private _enemyTeam = [];
		for "_j" from 0 to (3 * (missionNamespace getVariable ["ZZM_Diff", 1])) do { _enemyTeam set [_j, selectRandom _enemyMen] };
			
		private _milGroup = [_ammoObj getPos [random 2, random 360], _enemySide, _enemyTeam] call BIS_fnc_spawnGroup;
		{ _x setUnitPos "MIDDLE" } forEach units _milGroup;
		{ _x addCuratorEditableObjects [[_ammoObj] + units _milGroup, true] } forEach allCurators;
	};
};

// Create Completion Trigger
private _objTrigger = createTrigger ["EmptyDetector", _targetPos, false];
_objTrigger setTriggerStatements [  (_crateActivation joinString " && "),
	format["['ZMM_%1_TSK', 'Succeeded', true] spawn BIS_fnc_taskSetState; missionNamespace setVariable ['ZMM_DONE', true, true]; { _x setMarkerColor 'Color%2' } forEach ['MKR_%1_LOC','MKR_%1_MIN']", _zoneID, ZMM_playerSide],
	"" ];

missionNamespace setVariable [format['TR_%1_TASK_DONE', _zoneID], _objTrigger, true];
[_objTrigger, format['TR_%1_TASK_DONE', _zoneID]] remoteExec ["setVehicleVarName", 0, _objTrigger];

// Create Task
_missionTask = [format["ZMM_%1_TSK", _zoneID], true, [format["<font color='#00FF80'>Mission (#ID%1)</font><br/>", _zoneID] + format[_missionDesc, (count _crateActivation) + 1, _locName], ["Crash"] call zmm_fnc_nameGen, format["MKR_%1_LOC", _zoneID]], _centre, "CREATED", 1, false, true, "plane"] call BIS_fnc_setTask;

true