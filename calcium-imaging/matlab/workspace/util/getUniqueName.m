function [uniqueName, instanceCount] = getUniqueName(className)
% getUniqueName() - generate a locally-unique name using class name, pid, and instance counter
%		>> uniqueName = getStandardName()
%		>> uniqueName = getStandardName(className)
%
%		uniqueName format is <ClassName>_<ProcessID>_<InstanceCount>
%			e.g. Task_7088_1


% INITIALIZE WITH DEFAULT CLASS-NAME
if (nargin < 1)
	className = 'Object';
end

% GET PROCESS ID
pid = feature('getpid');

% GET PROCESS-LOCAL INSTANCE COUNT
instanceCount = getSetInstanceCount(className);

% GENERATE UNIQUE ID (CHARACTER-ARRAY)
uniqueName = sprintf('%s_%d_%d', className, pid, instanceCount);

end








% 			function [uniqueName, varargout] = getStandardName(className,varargin)
% 			% getStandardName() - generate a locally-unique name using class name, pid, and instance counter
% 			%		>> uniqueName = getStandardName()
% 			%		>> uniqueName = getStandardName(className)
% 			%		>> uniqueName = getStandardName(className, pid)
% 			%		>> uniqueName = getStandardName(className, pid, labindex)
% 			%
% 			%		uniqueName format is ClassName_pid_labidx_instancenum
% 			%			e.g. Task_7088_1_12
%
% 			% mlock; todo?
% 			% 			persistent class_pid_instance_count
%
% 			% INITIALIZE WITH DEFAULTS
% 			if (nargin < 2)
% 				threadID = feature('getpid');
% 				if (nargin < 1)
% 					className = 'Object';
% 				end
% 			else
% 				threadID = [varargin{:}];
% 			end
%
% 			% 			% CHECK IF THIS CLASS ALREADY HAS STORED ID-FACTORY
% 			% 			if isempty(class_pid_instance_count)
% 			% 				class_pid_instance_count = containers.Map;
% 			% 			end
%
% 			% GET CLASS/PROCESS INSTANCE COUNTER
% 			classPidKey = sprintf('%s%s',className,sprintf('_%d',threadID));
%
% 			instanceCount = getSetInstanceCount(classPidKey);
%
% 			% 			% CHECK IF ROOT HAS BEEN ESTABLISHED
% 			% 			if ~isKey(class_pid_instance_count, classPidCntKey)
% 			% 				instanceCount = 1;
% 			% 			else
% 			% 				instanceCount = class_pid_instance_count(classPidCntKey) + 1;
% 			% 			end
%
% 			% GENERATE UNIQUE ID (CHARACTER-ARRAY)
% 			uniqueName = sprintf('%s_%d', classPidKey, instanceCount);
%
% 			if nargout > 1
% 				varargout{1} = instanceCount;
%
% 				% 			% UPDATE CLASS INSTANCE COUNT
% 				% 			class_pid_instance_count(classPidKey) = instanceCount;
%
% 			end