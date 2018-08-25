// Set-up mission variables.
// Set-up mission variables.
params [ ["_zoneID", 0] ];

_centre = missionNamespace getVariable [format["ZMM_%1_Location", _zoneID], [0,0,0]];
_playerSide = missionNamespace getVariable [ "ZMM_playerSide", WEST ];
_radius = (getMarkerSize format["MKR_%1_MIN", _zoneID]) select 0; // Area of Zone.

_missionDesc = [
		"A cargo transport flying over the area is due to make a drop, search the area for nearby for one <font color='#00FFFF'>%1</font> and mark its location.",
		"An enemy air transport is due to fly through this area, locate one <font color='#00FFFF'>%1</font> and upload the coordinates of its location.",
		"One <font color='#00FFFF'>%1</font> is due to be dropped into the area, locate it and upload the coordinates.",
		"Search for one <font color='#00FFFF'>%1</font>, due to be dropped into this area.",
		"An air transport carrying supplies will be dropping one <font color='#00FFFF'>%1</font> into this area, locate it and upload the coordinates of its landing point.",
		"A transport has been spotted near this location. It is due to drop one <font color='#00FFFF'>%1</font> locate it and upload its location to allied forces."
	];	

// Create Objective
_dropPos = [[_centre, random 150, random 360] call BIS_fnc_relPos, 1, _radius, 1, 0, 0.5, 0, [], [ _centre, _centre ]] call BIS_fnc_findSafePos;
_dropType = selectRandom ["CargoNet_01_barrels_F","CargoNet_01_box_F","I_CargoNet_01_ammo_F","O_CargoNet_01_ammo_F","C_IDAP_CargoNet_01_supplies_F","B_CargoNet_01_ammo_F"];
_dropName = [getText (configFile >> "CfgVehicles" >> _dropType >> "displayName"),"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_- "] call BIS_fnc_filterString;

_dropObj = _dropType createVehicle [0,0,0];
_dropObj allowDamage false; 

clearMagazineCargoGlobal _dropObj;
clearWeaponCargoGlobal _dropObj; 
clearItemCargoGlobal _dropObj;
clearBackpackCargoGlobal _dropObj; 

_lightObj = "PortableHelipadLight_01_white_F" createVehicle [0,0,0]; 
_lightObj attachTo [_dropObj,[0, 0, ((boundingBoxReal _dropObj) select 1) select 2]];

// Add Action to upload coordinates.
[_dropObj, 
	 "<t color='#00FF80'>Upload Coordinates</t>", 
	 "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_connect_ca.paa",  
	 "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_connect_ca.paa",  
	 "(_target getVariable ['var_canUse', TRUE])", 
	 "(_target getVariable ['var_canUse', TRUE])", 
	 {}, 
	 {}, 
	 {_target setVariable ["var_canUse", FALSE, TRUE]}, 
	 {}, 
	 [], 
	 1, 
	 10 
] remoteExec ["bis_fnc_holdActionAdd"];

missionNamespace setVariable [format["ZMM_%1_OBJ", _zoneID], _dropObj];

// Create Drop Trigger
_dropTrigger = createTrigger ["EmptyDetector", _centre, FALSE];
_dropTrigger setTriggerArea [_radius, _radius, 0, FALSE];
_dropTrigger setTriggerActivation ["ANYPLAYER", "PRESENT", FALSE];
_dropTrigger setTriggerStatements ["this", 
								 format["ZMM_%1_OBJ setPos [%2, %3, 250]; [objNull, ZMM_%1_OBJ] call BIS_fnc_curatorobjectedited;", _zoneID, _dropPos select 0, _dropPos select 1],
								 ""];


// Create Completion Trigger
_objTrigger = createTrigger ["EmptyDetector", [0,0,0], FALSE];
_objTrigger setTriggerStatements [  format["!(ZMM_%1_OBJ getVariable ['var_canUse', TRUE])", _zoneID], 
									format["['ZMM_%1_TSK', 'Succeeded', TRUE] spawn BIS_fnc_taskSetState; missionNamespace setVariable ['ZMM_DONE', TRUE, TRUE]; { _x setMarkerColor 'Color%2' } forEach ['MKR_%1_LOC','MKR_%1_MIN']", _zoneID, _playerSide],
									"" ];

// Create Task
_missionTask = [format["ZMM_%1_TSK", _zoneID], TRUE, [format["<font color='#00FF80'>Mission (#ID%1)</font><br/>", _zoneID] + format[selectRandom _missionDesc, _dropName], ["Drop"] call zmm_fnc_nameGen, format["MKR_%1_LOC", _zoneID]], _centre, "CREATED", 1, FALSE, TRUE, "airdrop"] call BIS_fnc_setTask;

TRUE