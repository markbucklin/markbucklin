classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible) ...
		UniquelyIdentifiable
	
	
	
	
	
	
	
	properties (SetAccess = immutable)
		Name = ''
		UUID
	end
	
	properties (SetAccess = immutable, Hidden)
		ClassName
		PackagedClassName
		ProcessID
		Count
		ID
		%UUID = zeros(1,16,'uint8')
	end
	properties (Constant, Hidden)
		%ID_NUMERIC_TYPE = 'uint32'
	end
	
	
	
	methods
		function obj = UniquelyIdentifiable(varargin)
			
			% GET CLASS-NAME & PROCESS-ID -> ID ROOT
			obj.PackagedClassName = strrep(class(obj),'.','_');
			obj.ClassName = ignition.util.getClassName(obj);
			obj.ProcessID = feature('getpid');
			
			
			% GET UNIQUE NAME (CHARACTER VECTOR) & ID (UINT64) USING STATIC METHODS
			import ignition.core.UniquelyIdentifiable
			[obj.Name, obj.Count] = UniquelyIdentifiable.getNextName(obj.ClassName,obj.ProcessID);
			
			% USE UUID CLASS TO EXPRESS UNIQUE ID
			obj.UUID = ignition.core.UUID();
			obj.ID = obj.UUID.HashCode;
			
			%[obj.ID,obj.UUID] = UniquelyIdentifiable.getNextID();
			
			
		end
	end
	
	methods (Static, Hidden)
		function [uniqueName, varargout] = getNextName(className,varargin)
			% getNextName() - generate a locally-unique name using class name, pid, and instance counter
			%		>> uniqueName = getNextName()
			%		>> uniqueName = getNextName(className)
			%		>> uniqueName = getNextName(className, pid)
			%		>> uniqueName = getNextName(className, pid, labindex)
			%
			%		uniqueName format is ClassName_pid_labidx_instancenum
			%			e.g. Task_7088_1_12
			
			% mlock; todo?
			% 			persistent class_pid_instance_count
			
			% INITIALIZE WITH DEFAULTS
			if (nargin < 2)
				threadID = feature('getpid');
				if (nargin < 1)
					className = 'Object';
				end
			else
				threadID = [varargin{:}];
			end
			
			% 			% CHECK IF THIS CLASS ALREADY HAS STORED ID-FACTORY
			% 			if isempty(class_pid_instance_count)
			% 				class_pid_instance_count = containers.Map;
			% 			end
			
			% GET CLASS/PROCESS INSTANCE COUNTER
			classPidKey = sprintf('%s%s',className,sprintf('_%d',threadID));
			
			instanceCount = getSetInstanceCount(classPidKey);
			
			% 			% CHECK IF ROOT HAS BEEN ESTABLISHED
			% 			if ~isKey(class_pid_instance_count, classPidCntKey)
			% 				instanceCount = 1;
			% 			else
			% 				instanceCount = class_pid_instance_count(classPidCntKey) + 1;
			% 			end
			
			% GENERATE UNIQUE ID (CHARACTER-ARRAY)
			uniqueName = sprintf('%s_%d', classPidKey, instanceCount);
			
			if nargout > 1
				varargout{1} = instanceCount;
				
				% 			% UPDATE CLASS INSTANCE COUNT
				% 			class_pid_instance_count(classPidKey) = instanceCount;
				
			end
		end
% 		function [id , varargout] = getNextID()
% 			% getNextID() - generate a unique uint64 type id
% 			%		>> id64 = getNextID()
% 			
% 			% INITIALIZE ARRAY OF USED IDS TO ENSURE THE LOWER BIT RANGE IDS ARE UNIQUE
% 			persistent usedIDStore
% 			idNumericType = ignition.core.UniquelyIdentifiable.ID_NUMERIC_TYPE;
% 			if isempty(usedIDStore)
% 				usedIDStore = struct('idx',1,'vals',zeros(1024,1,idNumericType));
% 			end
% 			uuid = zeros(1,16,'uint8');
% 			
% 			try
% 				% GENERATE AN ID FROM HEX-UUID ACQUIRED USING TEMPNAME FUNCTION (BUILTIN)
% 				[~, idStr] = fileparts(tempname);
% 				if strcmp(idStr(1:2),'tp')
% 					idStr = idStr(3:end);
% 				end
% 				% java.util.UUID.randomUUID()
% 				
% 				% CONVERT HEXADECIMAL CHARACTER ARRAY TO INTEGER (32-CHAR HEX -> 128 BIT)
% 				idSplit = strsplit(idStr,'_');
% 				idHex = [idSplit{:}];
% 				% todo -> make uuid = idHex
% 				
% 				% UINT8 ARRAY -> UUID	[1x16 = 16 Bytes]
% 				id8 = hex2dec(reshape(idHex,2,[])');
% 				uuid = uint8(id8(:)');
% 				
% 				% SCALAR ID USING LARGER DATA-TYPE -> ID UINT32 [4 Bytes]
% 				switch idNumericType
% 					case {'uint32','int32'}
% 						idOps = cast(hex2dec(reshape(idHex,8,[])'),idNumericType);
% 					case {'uint64','int64'}
% 						idOps = cast(hex2dec(reshape(idHex,16,[])'),idNumericType);
% 					case 'double'
% 						idOps = hex2num(idHex(1:16));
% 						%idOps = hex2num(reshape(idHex,16,[])');
% 					case 'single'
% 						idOps = single(hex2num(idHex(1:16)));
% 						%idOps = single(hex2num(reshape(idHex,8,[])'));
% 				end
% 				
% 				
% 				nextIdx = usedIDStore.idx;
% 				usedVals = usedIDStore.vals;
% 				k = 1;
% 				while true
% 					id = idOps(k);
% 					if any(id == usedVals)
% 						% CHECK IF GENERATED ID MATCHES ANYTHING STORED (NON-UNIQUE)
% 						k = k + 1;
% 					else
% 						% STORE NEW UNIQUE ID & INCREMENT IDX
% 						usedVals(nextIdx) = id;
% 						nextIdx = nextIdx + 1;
% 						if nextIdx > numel(usedVals)
% 							usedVals = [usedVals ; zeros(1024,1,idNumericType)];
% 						end
% 						usedIDStore.idx = nextIdx ;
% 						usedIDStore.vals = usedVals ;
% 						break
% 					end
% 					if k > numel(idOps)
% 						% TAIL-END RECURSIVE CALL TO TRY ID GENERATION AGAIN
% 						[id,uuid] = ignition.core.UniquelyIdentifiable.getNextID();
% 						break
% 					end
% 				end
% 				%id64 = uint64(hex2dec(idHex(1:16)));
% 				%id128 = uint64(hex2dec(idHex(17:end)));
% 				% todo
% 				
% 				
% 			catch me
% 				% GENERATE ID USING CPU-TIME DIRECTLY
% 				% id64 = uint64(now*60*60*24);
% 				%id64 = uint64(cputime*10^7);
% 				id = cast(cputime*2^15,idNumericType);
% 			end
% 			
% 			if nargout > 1
% 				varargout{1} = uuid;
% 			end
% 			
% 			% 			% CHECK IF LAST ID IS THE SAME AS THE ONE GENERATED HERE -> INCREMENT
% 			% 			if ~isempty(lastID)
% 			% 				if (id64 == lastID)
% 			% 					id64 = id64 + 1;
% 			% 				end
% 			% 			end
% 			% 			lastID = id64;
% 			
% 		end
	end
	
	
	
	
end



function cnt = getSetInstanceCount(key)

% mlock; todo?
persistent class_pid_instance_count

% CHECK IF THIS CLASS ALREADY HAS STORED ID-FACTORY
if isempty(class_pid_instance_count)
	class_pid_instance_count = containers.Map;
end

% CHECK IF ROOT HAS BEEN ESTABLISHED
if ~isKey(class_pid_instance_count, key)
	cnt = 1;
else
	cnt = class_pid_instance_count(key) + 1;
end

% UPDATE CLASS INSTANCE COUNT
class_pid_instance_count(key) = cnt;


end

