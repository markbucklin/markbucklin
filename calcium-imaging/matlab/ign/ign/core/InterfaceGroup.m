classdef InterfaceGroup ......
		< ign.core.Unique ...
		& ign.core.CustomDisplay ...
		& ign.core.Handle ...
		& matlab.mixin.Heterogeneous
	% a group of 'channels' that may be indexed or named or both
	
	
	% STANDARD NAME & STATUS
	properties (SetAccess = protected)
		NameRoot = 'interface'
	end
	properties (SetAccess = private, Hidden)
		Count = 0
		CurrentRootCount = 0
	end
	
	properties (SetAccess = protected)
		All = ign.core.Interface.empty()
		Names = {}
		HashMap = containers.Map();
	end
	
		
	
	methods
		function obj = InterfaceGroup(varargin)			
			% >> obj = ign.core.InterfaceGroup()
			% >> obj = ign.core.InterfaceGroup( 'common_interface_name')
			% >> obj = ign.core.InterfaceGroup( 'com_name', interfaceObjArray)
			% >> obj = ign.core.InterfaceGroup(interfaceObjArray)
			% >> obj = ign.core.InterfaceGroup(interfaceObjArray, interfaceObjNames)
			% >> obj = ign.core.InterfaceGroup(interfaceObjArray, {'trigger','enable'})
			
			if nargin												
				args = varargin;
				if ischar(args{1})
					name = args{1};
					setNameRoot(obj, name);
					args(1) = [];				
				end
				if ~isempty(args) && isa(args{1},'ign.core.Interface')
					addInterface(obj, args{:} );
				end								
			end
			
		end
		function setNameRoot(obj, name)
			
			% ASSIGN GIVEN CHARACTER VECTOR
			assert(ischar(name) && isvarname(name), 'must use a valid variable name?? todo')
			obj.NameRoot = name;
			
			% RESET CURRENT-ROOT-COUNT TO COUNT CHANNELS ADDED UNDER EACH HEADING
			obj.CurrentRootCount = 0;
			
		end
		function addInterface( obj, chans, names)
			
			%	GET CURRENT NUMBER & ADDITIONAL NUMBER OF CHANNELS
			num = numel(chans);
			assert(num >= 1, 'Attempt to add empty interface');
			idx = obj.Count + (1:num);
			
			% GENERATE STANDARD NAMES ('interface_1','interface_2', etc...)
			standardNames = generateStandardNames(obj, num);
			
			% CHECK NAMES
			if (nargin < 2), names = cell(size(chans)); end
			checkNames();
			
			% FILL HETEROGENEOUS ARRAY (INDEXED) OF INTERFACES
			ifcArray = obj.All;
			ifcMap = obj.HashMap
			for k = 1:numel(chans)
				ifcArray(idx(k)) = chans(k);
				ifcMap(names{k}) = chans(k);
				ifcMap(standardNames{k}) = chans(k);
			end
			
			% REASSIGN (todo -> better to concatenate??)
			obj.All = ifcArray;
			obj.Names = [obj.Names names{:}];
			obj.HashMap = ifcMap;
			
			% UPDATE COUNTS
			obj.Count = idx(end);
			
			
			% ------- NESTED SUB-FUNCTION  --------
			function checkNames()
				
				% ALLOW SINGLE CHANNEL ADDITION WITH CHARACTER ARRAY FOR NAME
				if (ischar(names) && (num==1))
					names = {names};
				end
				
				% FILL EMPTY CELL ARRAY -> AUTONUMBER
				if isempty(names)
					names = standardNames;
				else
					isEmptyName = cellfun(@isempty, names);
					if any(isEmptyName)
						names(isEmptyName) = standardNames(isEmptyName);
					end
				end
				
				% NAMES -> NOW A CELL ARRAY OF STRINGS (1 FOR EACH NEW CHANNEL)
				assert( iscellstr(names), 'names must be string format')
				
			end
			
		end
		function names = generateStandardNames(obj, num, nameRoot)
			
			% CHECK NAME ROOT -> USE TO GENERATE STANDARD NAMES
			if (nargin < 2) || isempty(nameRoot)
				nameRoot = obj.NameRoot;
			end			
			
			% RESET IF A NEW ROOT IS PROVIDED
			if ~strcmp( nameRoot, obj.NameRoot)
				setNameRoot(obj, nameRoot);
			end
			
			% GENERATE LIST OF NAMES WITH NUMBER APPENDED
			idx = obj.CurrentRootCount + (1:num);			
			cIdx = num2cell(idx);
			names = cellfun( @(n) sprintf('%s_%d', nameRoot, n),...
				cIdx, 'UniformOutput',false);			
			obj.CurrentRootCount = obj.CurrentRootCount + num;
			
		end
	end
	
	
	
	
	
end






