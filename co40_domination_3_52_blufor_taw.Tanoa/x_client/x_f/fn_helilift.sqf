// by Xeno
//#define __DEBUG__
#define THIS_FILE "fn_helilift.sqf"
#include "..\..\x_setup.sqf"

if (isDedicated) exitWith {};

params ["_chopper"];

private _menu_lift_shown = false;
private _liftobj = objNull;
private _id = -1212;
private _release_id = -1212;

_chopper setVariable ["d_vec_attached", false];
_chopper setVariable ["d_vec_released", false];
_chopper setVariable ["d_Attached_Vec", objNull];

sleep 10.123;

_possible_types = _chopper getVariable ["d_lift_types", []];

while {alive _chopper && {alive player} && {player in _chopper}} do {
	if (driver _chopper == player) then {
		private _pos = getPosATLVisual _chopper;
		
		if (!(_chopper getVariable ["d_vec_attached", false]) && {_pos select 2 > 2.5} && {_pos select 2 < 11}) then {
			_liftobj = objNull;
			private _nobjects = nearestObjects [_chopper, ["LandVehicle","Air"], 50];
			if !(_nobjects isEqualTo []) then {
				private _dummy = _nobjects select 0;
				if (_dummy == _chopper) then {
					if (count _nobjects > 1) then {_liftobj = _nobjects select 1};
				} else {
					_liftobj = _dummy;
				};
			};
			if (!isNull _liftobj) then {
				if (_liftobj isKindOf "CAManBase") then {
					_liftobj = objNull;
				} else {
#ifndef __TT__
					if ((speed _liftobj > 10) || {((getPosATLVisual _liftobj) select 2 > 5)} || {!((toUpper (typeof _liftobj)) in _possible_types)}) then {_liftobj = objNull};
#else
					if ((speed _liftobj > 10) || {((getPosATLVisual _liftobj) select 2 > 5)} || {!((toUpper (typeof _liftobj)) in _possible_types)} || {_liftobj getVariable ["d_side", d_player_side] != d_player_side}) then {_liftobj = objNull};
#endif
				};
			};
			sleep 0.1;
			if (!isNull _liftobj && {_liftobj != _chopper getVariable ["d_Attached_Vec", false]}) then {
				if !(_liftobj getVariable ["d_MHQ_Deployed", false]) then {
					_liftobj_pos = getPosATLVisual _liftobj;
					private _nx = _liftobj_pos select 0;private _ny = _liftobj_pos select 1;private _px = _pos select 0;private _py = _pos select 1;
					if ((_px <= _nx + 10 && {_px >= _nx - 10}) && {(_py <= _ny + 10 && {_py >= _ny - 10})}) then {
						if (!_menu_lift_shown) then {
							_id = _chopper addAction [format ["<t color='#AAD9EF'>%1</t>", localize "STR_DOM_MISSIONSTRING_250"], {_this call d_fnc_heli_action}, -1, 100000];
							_menu_lift_shown = true;
						};
					} else {
						_liftobj = objNull;
						if (_menu_lift_shown) then {
							_chopper removeAction _id;
							_id = -1212;
							_menu_lift_shown = false;
						};
					};
				};
			};
		} else {
			if (_menu_lift_shown) then {
				_chopper removeAction _id;
				_id = -1212;
				_menu_lift_shown = false;
			};
			
			sleep 0.1;
			
			if (isNull _liftobj) then {
				_chopper setVariable ["d_vec_attached", false];
				_chopper setVariable ["d_vec_released", false];
			} else {
				if (_chopper getVariable ["d_vec_attached", false]) then {
					_release_id = _chopper addAction [format ["<t color='#FF0000'>%1</t>", localize "STR_DOM_MISSIONSTRING_251"], {_this call d_fnc_heli_release}, -1, 100000];
					_chopper vehicleChat (localize "STR_DOM_MISSIONSTRING_252");
					_chopper setVariable ["d_Attached_Vec", _liftobj];
					
					_mhqfuel = _liftobj getVariable "d_vecfuelmhq";
					if (!isNil "_mhqfuel") then {
						[_liftobj, _mhqfuel] remoteExecCall ["setFuel", _liftobj];
						_liftobj setVariable ["d_vecfuelmhq", nil, true];
					};
					
					if (_liftobj getVariable ["d_vec_type", ""] == "MHQ") then {
						_liftobj setVariable ["d_in_air", true, true];
						_lon = _liftobj getVariable "d_vec_name";
						_chopper setVariable ["d_mhq_lift_obj", [_liftobj, _lon], true];
#ifndef __TT__
						player kbTell [d_kb_logic1,d_kb_topic_side,"Dmr_in_air",["1","",_lon,[]],"SIDE"];
#else
						if (d_player_side == blufor) then {
							player kbTell [d_hq_logic_blufor1,"HQ_W","Dmr_in_air",["1","",_lon,[]],"SIDE"];
						} else {
							player kbTell [d_hq_logic_opfor1,"HQ_E","Dmr_in_air",["1","",_lon,[]],"SIDE"];
						};
#endif
					};
					
					[_liftobj, false] remoteExecCall ["engineOn", _liftobj];
					
					private _maxload = getNumber(configFile>>"CfgVehicles">>(typeOf _chopper)>>"maximumLoad");
					private _slipos = [[0,0,1], _chopper selectionPosition "slingload0"] select !(_chopper selectionPosition "slingload0" isEqualTo [0,0,0]);
					__TRACE_2("","_maxload","_slipos")
					//_chopper addEventhandler ["RopeAttach", {player sideChat str(_this);player sideChat "bla"}];
					
					private _ropes = [];
					private _slcmp = getArray(configFile>>"CfgVehicles">>(typeOf _liftobj)>>"slingLoadCargoMemoryPoints");
					if (_slcmp isEqualTo []) then {
						{
							_ropes pushBack (ropeCreate [_chopper, _slipos, _liftobj, _x, 20]);
						} forEach ([_liftobj] call d_fnc_getcorners);
					} else {
						{
							_ropes pushBack (ropeCreate [_chopper, _slipos, _liftobj, _liftobj selectionPosition _x, 20]);
						} forEach _slcmp;
					};
					
					__TRACE_1("","_ropes")
					
					private _oldmass = getMass _liftobj;
					__TRACE_2("1","_liftobj","_oldmass")
					if (_oldmass > _maxload) then {
						// *sigh* yet another MP inconsistency... setMass is not a command with global effects but only local...
						// means, if we want to cheat and reduce the mass of an object it needs to be set everywhere (or at least where the object is local, not tested)
						[_liftobj, (_maxload - 1500) max 100] remoteExecCall ["setMass"];
						
						_chopper setVariable ["d_lobm", [_liftobj, _oldmass], true];
						
						sleep 0.1;
						[_liftobj, (_maxload - 1500) max 100] remoteExecCall ["setMass"];
					} else {
						_oldmass = -1;
					};
					
					__TRACE_1("","_oldmass")
					//#ifdef __DEBUG__
					//_lobmm = getMass _liftobj;
					//__TRACE_1("","_lobmm")
					//#endif
					
					_chopper setVariable ["d_ropes", _ropes, true];

					// ropeBreak event?
					// player in chopper? What if switch to copilot happens... Needs check and handling, because only the pilot has the actions, etc
					while {alive _chopper && {alive _liftobj} && {alive player} && {{alive _x} count _ropes > 0} && {!(_chopper getVariable ["d_vec_released", false])} && {player in _chopper}} do {
						sleep 0.312;
					};
					
					{
						if (!isNull _x) then {
							ropeDestroy _x;
						};
					} forEach _ropes;
					if (_oldmass > -1) then {
						[_liftobj, _oldmass] remoteExecCall ["setMass"];
						_chopper setVariable ["d_lobm", nil, true];
					};
					[_liftobj, [0,0,0]] remoteExecCall ["setVelocity", _liftobj];

					[_liftobj, false] remoteExecCall ["engineOn", _liftobj];
					if ((getPosATLVisual _liftobj) select 2 > 5) then {
						_liftobj spawn {
							while {(getPosATLVisual _this) select 2 > 5} do {
								_this setDamage ((damage _this) + 0.01);
								sleep 0.1;
								if (!alive _this) exitWith {};
							};
						};
					};
					_chopper setVariable ["d_ropes", nil, true];
					
					_chopper setVariable ["d_vec_attached", false];
					_chopper setVariable ["d_vec_released", false];
					
					if (_liftobj getVariable ["d_vec_type", ""] == "MHQ") then {
						_liftobj setVariable ["d_in_air", false, true];
						_chopper setVariable ["d_mhq_lift_obj", nil, true];
#ifndef __TT__
						player kbTell [d_kb_logic1,d_kb_topic_side,"Dmr_available",["1","",_liftobj getVariable "d_vec_name",[]],"SIDE"];
#else
						if (d_player_side == blufor) then {
							player kbTell [d_hq_logic_blufor1,"HQ_W","Dmr_available",["1","",_liftobj getVariable "d_vec_name",[]],"SIDE"];
						} else {
							player kbTell [d_hq_logic_opfor1,"HQ_E","Dmr_available",["1","",_liftobj getVariable "d_vec_name",[]],"SIDE"];
						};
#endif
					};
					
					_chopper setVariable ["d_Attached_Vec", objNull];
					
					if (!alive _chopper) then {
						_chopper removeAction _release_id;
					} else {
						if (alive _chopper && {alive player}) then {_chopper vehicleChat (localize "STR_DOM_MISSIONSTRING_253")};
					};
					
					if (!(_liftobj isKindOf "StaticWeapon") && {(getPosATLVisual _liftobj) select 2 < 200}) then {
						waitUntil {sleep 0.222;(getPosATLVisual _liftobj) select 2 < 10};
					} else {
						private _npos = getPosATLVisual _liftobj;
						_liftobj setPos [_npos select 0, _npos select 1, 0];
					};
					[_liftobj, [0,0,0]] remoteExecCall ["setVelocity", _liftobj];
					
					sleep 1.012;
				};
			};
		};
	};
	sleep 0.51;
};

if (alive _chopper) then {
	if (_id != -1212) then {_chopper removeAction _id};
	if (_release_id != -1212) then {_chopper removeAction _release_id};
};