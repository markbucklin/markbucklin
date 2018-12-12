classdef (CaseInsensitiveProperties, TruncatedProperties) System < matlab.System
%	
% 
% ---------------->>>>> in progress
% 
% when changing parent package, edit the property: PackageName = 'ignition'
%

	% ##################################################
	% SETTINGS
	% ##################################################
	properties (Access = public, Logical, Nontunable)
		UseGpu = true
		UseParallel = true
		UseBuffer = false
		UseInteractive = false
	end
	properties (Access = public, Nontunable)
		PreferredGpuNum % todo: make static or global?
	end
	properties (Hidden, Nontunable)
		CheckCapabilities = true		
	end
	
	
	% ##################################################
	% COMPUTER CAPABILITIES & DEFAULTS (ENVIRONMENT)
	% ##################################################
	properties (SetAccess = protected, Hidden, Nontunable, Logical)
		CanUseGpu
		CanUseParallel
		CanUseBuffer
		CanUseInteractive
	end
	properties (SetAccess = protected, Hidden)
		SettableProps
		GpuDeviceObj
		ParallelPoolObj
		BufferedOutputObj % todo
		PackageName = 'ignition'
		SubPackageName = ''
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
	
	
	
	events (NotifyAccess = ?ignition.System)
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
		function obj = System(varargin)
warning('System.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
			
			% CHECK COMPUTER CAPABILITIES & ASSIGN DEFAULT PREFERENCES
			if obj.CheckCapabilities
				checkCapabilitiesAndPreferences(obj); % TODO: find proper place to check options
			end
			
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
			
			% PARSE INPUT
			parseConstructorInput(obj,varargin(:))
			
			% CONNECT ENVIRONMENT
			makeEnvironmentConnections(obj)
			
		end
	end
		
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################
	% INPUT MANAGEMENT
	methods	(Access = protected)
		function checkCapabilitiesAndPreferences(obj) %TODO: separate/distinguish computer can** from object can** 
			% Manage default preferences for current toolbox: 
			%			UseGpu, UseParallel, UseBuffer, UseInteractive
			
			defaultlogicalprop = @(b) ~isempty(b) && logical(b(1));
			
			userPrefNames = {'UseGpu', 'UseParallel', 'UseBuffer', 'UseInteractive'};
			
			% CHECK STATE/EXISTENCE OF TOOLBOX PREFERENCES -> ADDPREFS
			tlbx = obj.PackageName;
			for kPref = 1:numel(userPrefNames)
				prefName = userPrefNames{kPref};
				if ~ispref(tlbx, prefName)
					if isprop(obj, prefName)
						addpref(tlbx, prefName, defaultlogicalprop(obj.(prefName)))
					end										
				end
			end
				
				% 				addpref(tlbx, 'UseGpu', defaultlogicalprop(obj.UseGpu))
				% 				addpref(tlbx, 'UseParallel', defaultlogicalprop(obj.UseParallel))
				% 				addpref(tlbx, 'UseBuffer', defaultlogicalprop(obj.UseBuffer))
				% 				addpref(tlbx, 'UseInteractive', defaultlogicalprop(obj.UseInteractive))
				
				% 				uigetpref(tlbx, 'UseGpu',...
				% 					'GPU Computation',...
				% 					'Would you like to use the GPU for Computation where available?',...
				% 					{true,false});
				% 				addpref(tlbx, 'UseParallel', 'Parallel Processing',...
				% 					'Would you like to use multi-core/SPMD parallel processing procedures from PCT (e.g. parfor, spmd, parfeval) where available?',...
				% 					{'yes','no'});
				% 				addpref(tlbx, 'UseInteractive', 'Interactive Tuning',...
				% 					'Would you like to use interactive tuning procedures to set parameter values where available?',...
				% 					{'yes','no'});
				% 			end
			gpref = getpref(tlbx);
			
			% INITIALIZE GLOBAL VARIABLE TO CHECK COMPUTER CAPABILITY
			global COMPUTERCAPABILITY
			if isempty(COMPUTERCAPABILITY)
				COMPUTERCAPABILITY = struct(...
					'CanUseGpu',[],...
					'CanUseParallel',[],...
					'CanUseBuffer',[],...
					'CanUseInteractive',[]);
			end
			thiscomputer = COMPUTERCAPABILITY;
						
			% CHECK GPU-PROCESSING ABILITY
			if isempty(thiscomputer.CanUseGpu)
				try
					numGpuDev = gpuDeviceCount;
					anyGpuSupported = false;
					for kGpu = 1:numGpuDev
						dev = gpuDevice(kGpu);
						if dev.DeviceSupported
							anyGpuSupported = true;
							fprintf('GPU detected: \n\t%s \n\t%d multiprocessors \n\tCompute Capability %s\n\n',...
								dev.Name, dev.MultiprocessorCount, dev.ComputeCapability);
						end
					end
					thiscomputer.CanUseGpu = anyGpuSupported;
					
					% todo: pick best gpu
					if isempty(obj.PreferredGpuNum)
						obj.PreferredGpuNum = numGpuDev;
					end
					
					
					
				catch
					thiscomputer.CanUseGpu = false;
				end
			end
			
			% CHECK PARALLEL-PROCESSING ABILITY (USING PARALLEL COMPUTING TOOLBOX)
			if isempty(thiscomputer.CanUseParallel)
				versionInfo = ver;
				if any(strcmpi({versionInfo.Name},'Parallel Computing Toolbox'))
					% [isPoolRunning, pool] = distcomp.remoteparfor.tryRemoteParfor();
					thiscomputer.CanUseParallel = true;
				else
					thiscomputer.CanUseParallel = false;
				end
			end
			
			% CAN-USE-BUFFER & CAN-USE-INTERACTIVE -> DEFAULT TRUE (todo)
			if isempty(thiscomputer.CanUseBuffer)
				thiscomputer.CanUseBuffer = true;
			end
			if isempty(thiscomputer.CanUseInteractive)
				thiscomputer.CanUseInteractive = true;
			end
			
			% SET MEMBER OPTION TO GLOBAL PREFERENCE IF EMPTY, OR PREF IS TO NOT USE GPU
			if thiscomputer.CanUseGpu
				obj.CanUseGpu = true;
				if isempty(gpref.UseGpu)
					gpref.UseGpu = strcmp('Yes', questdlg('Use the GPU for Computation where available?'));
					setpref(tlbx, 'UseGpu',gpref.UseGpu);
				end
				obj.UseGpu = gpref.UseGpu;
			else
				obj.UseGpu = false;
			end
						
			% QUERY USER TO USE PCT
			if thiscomputer.CanUseParallel
				obj.CanUseParallel = true;
				if isempty(gpref.UseParallel)
					if strcmp('Yes', questdlg(...
							['Use multi-core/SPMD parallel processing procedures from PCT ',...
							'(e.g. parfor, spmd, parfeval) where available?']))
						gpref.UseParallel = true;
					else
						gpref.UseParallel = false;
					end
				end
				setpref(tlbx, 'UseParallel',gpref.UseParallel);
				obj.UseParallel = gpref.UseParallel;
			else
				obj.UseParallel = false;
			end
 			
			% ALL OTHER PREFERENCES -> INITIALIZE EMPTY PREFS TO FALSE (todo->remove?)
			fn = fields(gpref);
			for k=1:numel(fn)
				if isempty(gpref.(fn{k}))
					gpref.(fn{k}) = false;
				end
				if isprop(obj, fn{k}) && isempty(obj.(fn{k}))
					obj.(fn{k}) = gpref.(fn{k});
				end
			end
			
			fn = fields(thiscomputer);
			for k=1:numel(fn)
				if isempty(thiscomputer.(fn{k}))
					thiscomputer.(fn{k}) = true;
				end
				if isprop(obj, fn{k}) && isempty(obj.(fn{k}))
					obj.(fn{k}) = thiscomputer.(fn{k});
				end
			end
						
			COMPUTERCAPABILITY = thiscomputer;
			
		end
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
		function makeEnvironmentConnections(obj) %TODO: use global structure??
			
			
			% ----------------------------------------------
			% GPU CONNECTIONS
			% ----------------------------------------------
			if obj.UseGpu
								
				% ASSIGN CUDA-DEVICE OBJECT TO GPUDEVICE PROPERTY
				obj.GpuDeviceObj = gpuDevice();
				% todo: preference for gpu-device index
				% 				numGpuDev = gpuDeviceCount;
				% 				anyGpuSupported = false;
				% 				for kGpu = 1:numGpuDev
				% 					dev = gpuDevice(kGpu);
				% 					if dev.DeviceSupported
				% 						anyGpuSupported = true;
				% 						fprintf('GPU detected: \n\t%s \n\t%d multiprocessors \n\tCompute Capability %s\n\n',...
				% 							dev.Name, dev.MultiprocessorCount, dev.ComputeCapability);
				% 					end
				% 				end
				
				% SET RANDOM-NUMBER-STREAM GENERATOR ON GPU							
				rngCurrent = parallel.gpu.rng();
				rngPreferred = 'Philox4x32-10'; % todo
				if ~strcmpi(rngCurrent.Type, rngPreferred)
					parallel.gpu.rng(7301986, rngPreferred);
				end
			end
			
			% ----------------------------------------------
			% PARALLEL MULTIPROCESSOR/MULTICORE (SPMD)
			% ----------------------------------------------
			if obj.UseParallel
				% PARALLEL POOL
				curpool = gcp('nocreate');
				numCores = str2double(getenv('NUMBER_OF_PROCESSORS'));
				if isempty(curpool)
					curpool = parpool(numCores);
				end
				obj.ParallelPoolObj = curpool;
			end
			
			
			% 			% START PARALLEL POOL
			% 			if obj.UseParallel
			% 				numCores = str2double(getenv('NUMBER_OF_PROCESSORS'));
			% 				% CHECK IF THERE IS A CURRENT POOL (CREATE IF FALSE)
			% 				if isempty(obj.ParallelPoolObj)
			% 					curpool = gcp('nocreate');
			% 					if isempty(curpool)
			% 						curpool = parpool(numCores);
			% 					end
			% 					% CHECK IF PARALLEL POOL IS DISCONNECTED AFTER IDLE TIME (RECREATE IF FALSE)
			% 				elseif ~obj.ParallelPoolObj.Connected
			% 				end
			% 				obj.ParallelPoolObj = curpool;
			% 				addlistener(curpool, 'ObjectBeingDestroyed', @(varargin) setPreInitializedState(obj));
			% 			end
			
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
		function initialize(obj)
			% CALLED DURING SETUP
			
			if obj.IsInitialized
				return
			end
			
			makeEnvironmentConnections(obj)
			
			
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









