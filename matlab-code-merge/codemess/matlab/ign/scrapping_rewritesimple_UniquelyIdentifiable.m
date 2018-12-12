classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible) ...
		UniquelyIdentifiable
	
	
	
	
	
	
	
	properties (SetAccess = immutable)
		StandardName = '' % todo -> UniqueName??
		ID
	end
	
	properties (SetAccess = immutable, Hidden)
		ClassName
		PackagedClassName
		ProcessID
		UniqueInstanceCount
		UUID
		%UUID = zeros(1,16,'uint8')
	end
	properties (Constant, Hidden)
		%ID_NUMERIC_TYPE = 'uint32'
	end
	
	
	
	methods
		function obj = UniquelyIdentifiable(varargin)
			
			% GET CLASS-NAME & PROCESS-ID -> ID ROOT
			obj.PackagedClassName = strrep(class(obj),'.','_');
			obj.ClassName = ign.util.getClassName(obj);
			obj.ProcessID = feature('getpid');
			
			
			% GET UNIQUE NAME (CHARACTER VECTOR) & ID (UINT64) USING STATIC METHODS
			import ign.core.UniquelyIdentifiable
			[obj.StandardName, obj.UniqueInstanceCount] = UniquelyIdentifiable.getStandardName(obj.ClassName,obj.ProcessID);
			
			% USE UUID CLASS TO EXPRESS UNIQUE ID
			obj.UUID = ign.core.UUID();
			obj.ID = obj.UUID.Value; % todo: toString?
			
			%[obj.ID,obj.UUID] = UniquelyIdentifiable.getNextID();
			
			
		end
		% todo: add methods for getClass, [classCnt, allCnt] = getInstanceCount, getID
	end
	
	methods (Static, Hidden)
		function [uniqueName, varargout] = getStandardName(className,varargin)
			% getStandardName() - generate a locally-unique name using class name, pid, and instance counter
			%		>> uniqueName = getStandardName()
			%		>> uniqueName = getStandardName(className)
			%		>> uniqueName = getStandardName(className, pid)
			%		>> uniqueName = getStandardName(className, pid, labindex)
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
	end
	
	
	
	
end



function cnt = getSetInstanceCount(key)

mlock;
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

