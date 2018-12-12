classdef (CaseInsensitiveProperties, TruncatedProperties) StatusMonitor < handle
	% StatusMonitor
	
	
	
	properties (SetAccess = protected)
		MonitoredObjHandle		
	end
	properties (SetAccess = protected, Transient, Hidden)
		StatusHandle
		StatusString = ''
		StatusNumber = 0
		StatusTic
		StatusUpdateInterval = .15
	end
	
	
	
	methods
		function obj = StatusMonitor(varargin)
			if nargin == 0
				% TODO
			else
				obj2monitor = varargin{1};
				obj.MonitoredObjHandle = handle(obj2monitor);
				
				% 				for kObj = 1:numel(obj2monitor)
				% 				obj(kObj) = MonitoredObjHandle
				
			end
		end
	end
	
	% STATUS UPDATE METHODS
	methods (Access = protected)%, Hidden)
		function setStatus(obj, statusNum, statusStr) %TODO: implement with visual class
			% Derived classes use the method >> obj.setStatus(n, 'function status') in a similar
			% manner to how they would use the MATLAB builtin waitbar function. This method will create a
			% waitbar for functions that update their status in this manner, but may be easily modified to
			% convey status updates to the user in some other by some other means. Whatever the means,
			% this method keeps the avenue of interaction consistent and easily modifiable.
			
			% RETRIEVE TIME SINCE LAST UPDATE
			if isempty(obj.StatusTic)
				obj.StatusTic = tic;
				timeSinceUpdate = inf;
			else
				timeSinceUpdate = toc(obj.StatusTic);
			end
			
			% CHECK FOR EMPTY INPUTS
			if nargin < 3
				if isempty(obj.StatusString)
					statusStr = 'Awaiting status update';
				else
					statusStr = obj.StatusString;
				end
				if nargin < 2 % NO ARGUMENTS -> Closes
					closeStatus(obj);
					return
				end
			elseif isempty(statusNum)
				statusNum = obj.StatusNumber;
			end
			
			% UPDATE PROPERTIES USING INPUT
			obj.StatusString = statusStr;
			obj.StatusNumber = statusNum; % todo: statusNum??
			if isinf(statusNum) % INF -> Closes
				closeStatus(obj);
				return
			end
			
			% OPEN OR CLOSE STATUS ENVIRONMENTINTERFACE (WAITBAR) IF REQUESTED
			%      0 -> open          inf -> close
			if timeSinceUpdate > obj.StatusUpdateInterval
				if isempty(obj.StatusHandle) || ~isvalid(obj.StatusHandle)
					openStatus(obj);
					return
				else
					updateStatus(obj);
				end
			end
			
		end
		function openStatus(obj)
			% TODO
			obj.StatusHandle = waitbar(0,obj.StatusString);
			obj.StatusTic = tic;
			
		end
		function updateStatus(obj) %TODO:redirect
			% IMPLEMENT WAITBAR UPDATES  (todo: or make a updateStatus method?)
			if isnumeric(obj.StatusNumber) && ischar(obj.StatusString)
				if ~isempty(obj.StatusHandle) && isvalid(obj.StatusHandle)
					waitbar(obj.StatusNumber, obj.StatusHandle, obj.StatusString);
				end
			end
			obj.StatusTic = tic;
		end
		function closeStatus(obj)
			if ~isempty(obj.StatusHandle)
				if isvalid(obj.StatusHandle)
					close(obj.StatusHandle)
				end
				obj.StatusHandle = [];
			end
		end				
	end
	
	
	
end
