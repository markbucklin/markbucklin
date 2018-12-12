classdef (CaseInsensitiveProperties, TruncatedProperties) SystemInterface < matlab.System
%	
% 
% ---------------->>>>> in progress
% 
%

	
	% SETTINGS
	properties (Access = public, Logical, Nontunable)
		UseGpu
		UseParallel
		UseBuffer
		UseInteractive
	end
	properties (Access = public, Nontunable)
		PreferredGpuNum % todo: make static or global?
	end
	
	% COMPUTER CAPABILITIES & DEFAULTS (ENVIRONMENT)	
	properties (SetAccess = protected, Hidden)
		SettableProps				
		BufferedOutputObj % todo		
		% 		SubPackageName = ''
	end
	properties (SetAccess = protected, Nontunable)
		EnvironmentObj
	end
	
	
	% ##################################################
	% STATUS
	% ##################################################
	properties (SetAccess = protected, Transient, Hidden)
		StatusHandle
		StatusString = ''
		StatusNumber = 0
		StatusTic
	end
	properties (SetAccess = protected, Transient)
		IsInitialized @logical scalar = false
	end
	properties (Hidden, SetAccess = protected)
		StatusUpdateInterval = .15
	end	
	properties (SetAccess = protected, Hidden, Nontunable)
		GpuRetrievedProps = struct.empty
		OpenResources = {} % Array of locked resources (e.g. file handles) that should be closed in RELEASEIMPL() method
	end
	
	
	
	events (NotifyAccess = ?ignition.system.SystemInterface)
		Setup
		Step
		Release
		Reset
		Error
	end
	
	
	
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = SystemInterface(varargin)
			
			fprintf('SystemInterface: Constructor\n')
			
			% CHECK COMPUTER CAPABILITIES & ASSIGN DEFAULT PREFERENCES
			% 			if obj.CheckCapabilities
			% 				checkCapabilitiesAndPreferences(obj); % TODO: find proper place to check options
			% 			end
			
			% COPY FROM SUB-OBJECT INPUT IF CLONING?? (todo)
			if nargin
				subObj = varargin{1};
				for n=numel(subObj):-1:1
					oMeta = metaclass(obj);
					oProps = oMeta.PropertyList(:);
					oProps = oProps(~strcmp({oProps.GetAccess},'private'));
					for k=1:numel(oProps)
						if strcmp(oProps(k).GetAccess,'private') || oProps(k).Constant
							continue
						else
							obj.(oProps(k).Name) = subObj.(oProps(k).Name);
						end
					end
				end
			end
			
			% FILL IN SETTABLE PROPERTIES ?? todo
			getSettableProperties(obj);
			
			% CONNECT ENVIRONMENT
			obj.EnvironmentObj = ignition.system.SystemEnvironment;
			defaultfalse = @(b) ~isempty(b) && logical(b);
			obj.UseGpu = (defaultfalse(obj.UseGpu) | obj.EnvironmentObj.UseGpuPreference) & (obj.EnvironmentObj.CanUseGpu);
			obj.UseParallel = (defaultfalse(obj.UseParallel) | obj.EnvironmentObj.UseParallelPreference) & obj.EnvironmentObj.CanUseParallel;
			obj.UseBuffer = (defaultfalse(obj.UseBuffer) | obj.EnvironmentObj.UseBufferPreference) & obj.EnvironmentObj.CanUseBuffer;
			obj.UseInteractive = (defaultfalse(obj.UseInteractive) | obj.EnvironmentObj.UseInteractivePreference) & obj.EnvironmentObj.CanUseInteractive;
			% 			initialize(obj.EnvironmentObj)
			
			% PARSE INPUT
			parseConstructorInput(obj,varargin(:))
			
		end
		function delete(obj)
			try
				delete(obj.EnvironmentObj)
			catch
			end
		end
	end
		
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################
	% INPUT MANAGEMENT
	methods	(Access = protected)		
		function parseConstructorInput(obj,args)
			% TODO: use parseInputs from parent class?
			if nargin < 2
				args = {};
			end
			mobj = metaclass(obj);  % TODO
			propSpec = {};
			nArgs = numel(args);
			if nArgs >= 1
				% EXAMINE FIRST INPUT -> SUBCLASS, STRUCT, DATA, PROPS
				firstArg = args{1};
				firstArgType = find([...
					isa( firstArg, class(obj)) ; ...
					isstruct( firstArg ) ; ...
					isa( firstArg, 'char') ;...
					isnumeric( firstArg ) ],...
					1, 'first');
				switch firstArgType
					case 1 % SYSTEM TYPE INPUT -> CLONE
						obj = copyProps(obj,firstArg);
					case 2 % STRUCTURE REPRESENTATION OF OBJECT
						fillPropsFromStruct(obj,firstArg);					
					case 3 % 'PROPERTY',VALUE PAIRS
						propSpec = args(:);
					case 4 % NUMERIC INPUT -> SERIALIZED OBJECT (todo)
						if isa(firstArg, 'uint8');
							firstArgDeser = distcompdeserialize(firstArg);
							if ~isa(firstArgDeser, 'uint8')
								args{1} = firstArgDeser;
								parseConstructorInput(obj, args);
								return
							end
						end				
						% byteobj = parallel.internal.pool.serialize(obj);
						% isa(firstArg,'com.mathworks.toolbox.distcomp.util.ByteBufferHandle[]')
					otherwise
						% 						keyboard %TODO
				end
				if isempty(propSpec) && nArgs >=2
					propSpec = args(2:end);
				end
			end
			% 			setProperties(obj,nargin,varargin{:}); works? todo
			if ~isempty(propSpec)
				if numel(propSpec) >=2
					for k = 1:2:length(propSpec)
						obj.(propSpec{k}) = propSpec{k+1};
					end
				end
			end
		end
		function fillPropsFromStruct(obj, structSpec)
			
			% TODO: can't assign protected props
			
			fn = fields(structSpec);
			for kf = 1:numel(fn)
				try
					obj.(fn{kf}) = structSpec.(fn{kf});
				catch 
				end
			end
		end		
		function copyProps(obj,objInput)
			oMetaIn = metaclass(objInput);
			oPropsIn = oMetaIn.PropertyList(:);
			for n=numel(obj):-1:1
				oMetaOut = metaclass(obj);
				oPropsOut = oMetaOut.PropertyList(:);
				% 				oProps = oPropsAll([oPropsAll.DefiningClass] == oMeta);
				for k=1:numel(oPropsOut)
					if any(strcmp({oPropsIn.Name},oPropsOut(k).Name))
						if ~strcmp(oPropsOut(k).GetAccess,'private') ...
								&& ~oPropsOut(k).Constant ...
								&& ~oPropsOut(k).Transient
							obj.(oPropsOut(k).Name) = objInput.(oPropsOut(k).Name);
						end
					end
				end
			end
		end
		function getSettableProperties(obj) %TODO:remove??
			oMeta = metaclass(obj);
			oPropsAll = oMeta.PropertyList(:);
			oProps = oPropsAll([oPropsAll.DefiningClass] == oMeta);
			propSettable = ~strcmp('private',{oProps.SetAccess}) ...
				& ~strcmp('protected',{oProps.SetAccess}) ...
				& ~[oProps.Constant] ...
				& ~[oProps.Transient];
			obj.SettableProps = oProps(propSettable);
		end		
	end		
	% GPU DATA MANAGEMENT
	methods (Access = protected)			
		function fetchPropsFromGpu(obj) %TODO: manage when this is called??
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			propSettable = ~[oProps.Dependent] & ~[oProps.Constant];
			for k=1:length(propSettable)
				if propSettable(k)
					pn = oProps(k).Name;
					
					% todo
					try
						if isa(obj.(pn), 'gpuArray') && existsOnGPU(obj.(pn))
							obj.(pn) = onCpu(obj, obj.(pn));
							obj.GpuRetrievedProps.(pn) = obj.(pn);
						end
						% 							obj.(pn) = gather(obj.(pn));
						% 							obj.GpuRetrievedProps.(pn) = obj.(pn);
						% 						end
					catch me
						getReport(me)
					end
				end
			end
		end
		function pushGpuPropsBack(obj) %TODO: ditto??
			if isstruct(obj.GpuRetrievedProps)
				fn = fields(obj.GpuRetrievedProps);
				if ~isempty(fn)
					for kf = 1:numel(fn)
						pn = fn{kf};
						if isprop(obj, pn)
							obj.(pn) = onGpu(obj, obj.(pn));
							% todo: check that this functions properly
							% 						if obj.UseGpu
							% 							obj.(pn) = gpuArray(obj.GpuRetrievedProps.(pn));
							% 						else
							% 							obj.(pn) = obj.GpuRetrievedProps.(pn);
							% 						end
						end
					end
				end
				obj.GpuRetrievedProps = struct.empty();
			end
		end		
	end
	% HIDDEN PROPERTY MANAGEMENT
	methods (Hidden)
		function systemInit(obj)
			% Called by subclasses during setupImpl() Performs common/shared initialization tasks.
			% (currently the only task is calling connect(obj.EnvironmentObj))
			
			fprintf('SystemInterface: SystemInit\n')
			
			if obj.IsInitialized
				return
			end
			
			% TRIGGER GPU DEVICE SELECTION & PARALLEL POOL CREATION
			% todo: check if obj.UseGpu || obj.UseParallel			
			if obj.UseGpu || obj.UseParallel
				connect(obj.EnvironmentObj)
			end
			
			% 			obj.initialize@ignition.system.SystemInterface();
			
			
		end
		function initialize(obj)
			fprintf('SystemInterface: Initialize\n')
			obj.IsInitialized = true;
		end
		function setHiddenProp(obj, propName, propVal) %TODO:remove??
			% TODO: is this necessary?
			try
				obj.(propName) = propVal;
			catch me
				msg = getReport(me);
				% disp(msg)
			end
		end
	end
		
	
	% ##################################################
	% RUNTIME HELPER METHODS
	% ##################################################		
	% DATA MANIPULATION
	methods (Access = protected) %TODO:make static??
		function F = onCpu(~, F)
			% Transfer input to system memory from gpu-device memory
			
			if isnumeric(F)
				% NUMERIC INPUT
				F = gatherifongpu(F);				
			elseif isstruct(F)
				% STRUCTURED INPUT
				sFields = fields(F);
				sNum = numel(F);
				for kField=1:numel(sFields)
					fieldName = sFields{kField};
					for kIdx = 1:sNum						
						F(kIdx).(fieldName) = gatherifongpu(F(kIdx).(fieldName));
					end
				end
			elseif iscell(F)
				% CELL ARRAY INPUT
				for kIdx = 1:numel(F)
					F{kIdx} = gatherifongpu(F{kIdx});
				end
			end
			
			% GATHER-IF-ON-GPU SUBFUNCTION FOR NUMERIC DATA
			function fcpu = gatherifongpu(fgpu)
				if isnumeric(fgpu)
					if isa(fgpu, 'gpuArray') && existsOnGPU(fgpu)
						fcpu = gather(fgpu);
					else
						fcpu = fgpu;
					end
				else
					% TODO: recursive calls?
					fcpu = fgpu;
				end
			end
			
		end	
		function F = onGpu(obj, F)
			% Transfer input to system memory from gpu-device memory
			% TODO: replace with onPreferredDevice() or xferDataToDevice
			isGpuPref = obj.UseGpu;
			if ~isGpuPref
				return
			end
			
			if isnumeric(F)
				% NUMERIC INPUT
				F = xfergpuifoncpu(F);				
			elseif isstruct(F)
				% STRUCTURED INPUT
				sFields = fields(F);
				sNum = numel(F);
				for kField=1:numel(sFields)
					fieldName = sFields{kField};
					for kIdx = 1:sNum						
						F(kIdx).(fieldName) = xfergpuifoncpu(F(kIdx).(fieldName));
					end
				end
			elseif iscell(F)
				% CELL ARRAY INPUT
				for kIdx = 1:numel(F)
					F{kIdx} = xfergpuifoncpu(F{kIdx});
				end
			end
			
			% GATHER-IF-ON-GPU SUBFUNCTION FOR NUMERIC DATA
			function fgpumem = xfergpuifoncpu(fval)				
				if isnumeric(fval)
					if ~isa(fval, 'gpuArray')
						fgpumem = gpuArray(fval);
					else
						fgpumem = fval;
					end
				else
					% TODO: recursive calls?
					fgpumem = fval;
				end
			end
			
		end
		function className = getClass(~, F)
			if isa(F, 'gpuArray')
				className = classUnderlying(F);
			else
				className = class(F);
			end
		end
		function dataType = getPixelDataType(~, F)
			if isa(F, 'gpuArray')
				dataType = classUnderlying(F);
			elseif (isa(F, 'VideoSegment'))
				dataType = getClass(obj, F.FrameData);%TODO
			else
				dataType = class(F);
			end
		end
		function flag = isOnGpu(~, F)
			flag = false;
			if (isa(F, 'VideoSegment'))
				f = F.FrameData;
			else
				f = F;
			end
			if isa(f, 'gpuArray') && existsOnGPU(f)
				flag = true;			
			end
		end
	end	
	methods (Static)
		function numFrames = getNumFrames(F)
			if isnumeric(F)
				numDims = ndims(F);
				if numDims <= 2
					numFrames = 1;
				else
					numFrames = size(F, numDims);
				end
			else
				%TODO
			end
		end
	end
	
	% STATUS UPDATE METHODS
	methods (Access = protected)
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
			
			% OPEN OR CLOSE STATUS INTERFACE (WAITBAR) IF REQUESTED
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
	
	
	
	methods (Access = protected)
		% TODO: check that these are functional
		function s = saveObjectImpl(obj)
			s = saveObjectImpl@matlab.System(obj);
			if isLocked(obj)
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				for k=1:numel(oProps)
					if strcmp(oProps(k).Name,'ChildSystem')
						continue
					else
						s.(oProps(k).Name) = obj.(oProps(k).Name);
					end
				end
			end
			if ~isempty(obj.ChildSystem)
				for k=1:numel(obj.ChildSystem)
					s.ChildSystem{k} = matlab.System.saveObject(obj.ChildSystem{k});
				end
			end
		end
		function loadObjectImpl(obj,s,wasLocked)
			if wasLocked
				% Load child System objects
				if ~isempty(s.ChildSystem)
					for k=1:numel(s.ChildSystem)
						obj.ChildSystem{k} = matlab.System.loadObject(s.ChildSystem{k});
					end
				end
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				% 		 oProps = oProps(~strcmp({oProps.GetAccess},'private'));
				for k=1:numel(oProps)
					if strcmp(oProps(k).Name,'ChildSystem')
						continue
					else
						s.(oProps(k).Name) = obj.(oProps(k).Name);
					end
				end
			end
			% Call base class method to load public properties
			loadObjectImpl@matlab.System(obj,s,[]);
		end
	end
	
	% TODO METHODS: IMPLEMENT ALL
	methods (Access = protected)
		function me = handleError(obj, me)
			try setStatus(obj, [], 'error'), catch, end
			rethrow(me); %TODO
		end
		% 		function bench = runBenchmark(obj)
		% 		end
	end
	
	
	
	
end









