classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible) ...
		UniquelyIdentifiable
	
	
	
	
	
	
	
	properties (SetAccess = immutable)
		Name = ''
		ID @uint64
	end
	
	properties (SetAccess = immutable, Hidden)
		ClassName
		PackagedClassName
		ProcessID
		LabIdx
	end
	
	
	
	
	methods
		function obj = UniquelyIdentifiable(varargin)
			
			% GET CLASS-NAME & PROCESS-ID -> ID ROOT
			obj.PackagedClassName = strrep(class(obj),'.','_');
			obj.ClassName = ignition.util.getClassName(obj);
			obj.ProcessID = feature('getpid');
			obj.LabIdx = labindex;
			
			% GET UNIQUE NAME (CHARACTER VECTOR) & ID (UINT64) USING STATIC METHODS
			import ignition.core.UniquelyIdentifiable
			obj.Name = UniquelyIdentifiable.getNextName(obj.ClassName,obj.ProcessID,obj.LabIdx);
			obj.ID = UniquelyIdentifiable.getNextID();
			
			
		end
	end
	
	methods (Static, Hidden)
		function uniqueName = getNextName(className,varargin)
			% getNextName() - generate a unique name using class name, pid, and instance counter
			%		>> uniqueName = getNextName()			
			%		>> uniqueName = getNextName(className)			
			%		>> uniqueName = getNextName(className, pid)
			%		>> uniqueName = getNextName(className, pid, labindex)
			%
			%		uniqueName format is ClassName_pid_labidx_instancenum
			%			e.g. Task_7088_1_12
			
			% mlock; todo?
			persistent class_pid_instance_count
			
			% INITIALIZE WITH DEFAULTS
			if (nargin < 2)
				threadID = [feature('getpid') , labindex];
				if (nargin < 1)
					className = 'Unspecified';
				end
			else
				threadID = [varargin{:}];
			end
			
			% CHECK IF THIS CLASS ALREADY HAS STORED ID-FACTORY
			if isempty(class_pid_instance_count)
				class_pid_instance_count = containers.Map;
			end
			
			% GET CLASS/PROCESS INSTANCE COUNTER
			classPidCntKey = sprintf('%s%s',className,sprintf('_%d',threadID));
			
			% CHECK IF ROOT HAS BEEN ESTABLISHED
			if ~isKey(class_pid_instance_count, classPidCntKey)
				instanceCount = 1;
			else
				instanceCount = class_pid_instance_count(classPidCntKey) + 1;
			end
			
			% GENERATE UNIQUE ID (CHARACTER-ARRAY)
			uniqueName = sprintf('%s_%d', classPidCntKey, instanceCount);
			
			% UPDATE CLASS INSTANCE COUNT
			class_pid_instance_count(classPidCntKey) = instanceCount;
			
		end
		function id64 = getNextID()
			% getNextID() - generate a unique uint64 type id
			%		>> id64 = getNextID()			
			
			persistent lastID			
			
			try
				% GENERATE AN ID FROM HEX-UUID ACQUIRED USING TEMPNAME FUNCTION (BUILTIN)
				[~, idStr] = fileparts(tempname);
				if strcmp(idStr(1:2),'tp')
					idStr = idStr(3:end);
				end								
				
				% todo idStr -> Uuid (may resemble java.util.UUID 
				%								such as in parallel.internal.pool.DataQueue
				
				idSplit = strsplit(idStr,'_');
				idHex = [idSplit{:}];
				if numel(idHex)>16
					% GREATER THAN 64-BIT ID
					id64 = uint64(hex2dec(idHex(1:16)));
					id128 = uint64(hex2dec(idHex(17:end)));					
					% todo
					
				else
					% 64-BIT OR FEWER BITS USED FOR UNIQUE ID
					id64 = uint64(hex2dec(idHex));
					
				end
				
			catch
				% GENERATE ID USING CPU-TIME DIRECTLY
				% id64 = uint64(now*60*60*24);
				id64 = uint64(cputime*10^7);
			end
			
			% CHECK IF LAST ID IS THE SAME AS THE ONE GENERATED HERE -> INCREMENT
			if ~isempty(lastID)
				if (id64 == lastID)
					id64 = id64 + 1;					
				end				
			end
			lastID = id64;
			
		end
	end
	
	
	
	
end