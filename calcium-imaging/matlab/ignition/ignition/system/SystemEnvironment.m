classdef (CaseInsensitiveProperties, TruncatedProperties, ConstructOnLoad) SystemEnvironment < handle
	%ENVIRONMENT Reference to properties of current computational environment
	%   TODO:Details
	
	
	
	% SETTINGS & PREFERENCES
	properties
		ComputerName
		UserName
		GpuDeviceIdx
		PackageName = 'ignition'
		VersionNumber = 0.1
	end
	properties
		UseGpuPreference
		UseParallelPreference
		UseBufferPreference
		UseInteractivePreference
	end %todo:add setDefaultPrefs method
	
	% COMPUTER CAPABILITIES
	properties (SetAccess = protected)
		CanUseGpu
		CanUseParallel
		CanUseBuffer
		CanUseInteractive
	end
	
	% COMPUTE RESOURCE HANDLES/REFERENCES
	properties (SetAccess = protected)
		GpuDeviceObj
		ParallelPoolObj
	end
	
	% OTHER STATE INFO & PRIVATE VARIABLES
	properties (SetAccess = protected)
		NumCpuCores
		IsMainProcess
		WorkerIdx % thread LabIdx
		MatlabProcessIdx % 0 if main, increments 1...n if started in parallel (TODO)
		ProcessID
		DriveMap
	end
	properties (SetAccess = protected, Hidden)
		PreferenceStructure
		NumRefs
		IsConnected
		IsInitialized
	end
	
	
	
	
	
	
	
	methods
		function obj = SystemEnvironment()
			%TODO add varargin
			fprintf('SystemEnvironment: Constructor\n')
			
			global ENVIRONMENTOBJ
			
			if isempty(ENVIRONMENTOBJ) || ~isvalid(ENVIRONMENTOBJ) %|| isempty(obj.NumRefs)
				
				ENVIRONMENTOBJ = obj;
				obj.NumRefs = 1;
				
				% INITIALIZE OR UPDATE
				initialize(obj)
				
			else
				% ASSIGN GLOBAL INSTANCE
				obj = ENVIRONMENTOBJ;
				
				% INCREMENT REGISTERED SYSTEM COUNTER				
				obj.NumRefs = obj.NumRefs + 1;
				
			end
			
			% INITIALIZE OR UPDATE
			update(obj)			
			
		end
		function initialize(obj)						
			% Called from constructor
			fprintf('SystemEnvironment: Initialize\n')									
			try
				
				% CALL UPDATE & RETURN IF OBJECT ALREADY INITIALIZED
				if defaultfalse(obj.IsInitialized)
					update(obj)
					return
				end				
				
				% SET CURRENT PACKAGE & IMPORT TO WORKSPACE
				if isempty(obj.PackageName)
					pkg = inputdlg('Type the package to use','SystemEnvironment - Current Package', 'ignition');
					% todo: enumeration class with multiple selectable packages (i.e. alpha, beta, release)
					obj.PackageName = pkg{1};
				end
				% 				utilImportCmd = sprintf('import %s.util.*', obj.PackageName);
				% 				evalin('base', utilImportCmd)
				
				% RECORD ENVIRONMENT VARIABLES & OPERATING SYSTEM DESCRIPTION
				if isempty(obj.UserName)
					obj.UserName = getenv('USERNAME');
				end
				if isempty(obj.ComputerName)
					obj.ComputerName = getenv('COMPUTERNAME');
				end
				obj.NumCpuCores = str2double(getenv('NUMBER_OF_PROCESSORS'));
				
				% PROCESS-ID
				obj.ProcessID = feature('getpid');
				
				% STORAGE
				obj.DriveMap = getDriveMappings();
				
				% ASSIGN PROPERTY VALUES FROM MATLAB PREFERENCES
				getComputeCapabilities(obj)				
				setPreferences(obj)
				getPreferences(obj)
				
				% TODO: SCHEDULE CONNECT
				
				
			catch me
				rethrow(me)
			end
			
			obj.IsInitialized = true;
			
		end
		function update(obj)
			fprintf('SystemEnvironment: Update\n')
			try
				
				% GPU MANAGEMENT
				% 				anySel = parallel.internal.gpu.isAnyDeviceSelected
				% 				idxByMode =  parallel.internal.gpu.sortDevicesByComputeMode;
				% 				curdev =  parallel.internal.gpu.currentDeviceIndex;
				% 				canSel =  parallel.internal.gpu.canSelectDevice(1);
				% 				canSel =  parallel.internal.gpu.canSelectDevice(2);
				% 				defaultIdx =  parallel.internal.gpu.defaultGPUIndex;
				% 				numGpu =  parallel.internal.gpu.deviceCount;
				% 				parallel.internal.gpu.selectDevice( numGpu);
				
				
				
				
				% RECORD ENVIRONMENT VARIABLES & OPERATING SYSTEM DESCRIPTION
				
				
			catch
				
			end
			
		end
		function getComputeCapabilities(obj)
			getGpuCapability(obj)
			getParallelCapability(obj)
			obj.CanUseBuffer = true; %todo
			obj.CanUseInteractive = true;
		end
		function getGpuCapability(obj)
			% CHECK GPU-PROCESSING ABILITY
			
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
					obj.CanUseGpu = anyGpuSupported;
					
					% todo: pick best gpu
					% GPU MANAGEMENT
					% 				anySel = parallel.internal.gpu.isAnyDeviceSelected
					% 				idxByMode =  parallel.internal.gpu.sortDevicesByComputeMode;
					% 				curdev =  parallel.internal.gpu.currentDeviceIndex;
					% 				canSel =  parallel.internal.gpu.canSelectDevice(1);
					% 				canSel =  parallel.internal.gpu.canSelectDevice(2);
					% 				defaultIdx =  parallel.internal.gpu.defaultGPUIndex;
					% 				numGpu =  parallel.internal.gpu.deviceCount;
					% 				parallel.internal.gpu.selectDevice( numGpu);
					if isempty(obj.GpuDeviceIdx)
						obj.GpuDeviceIdx = numGpuDev;
					end
					
					
				catch
					obj.CanUseGpu = false;
				end
			
		end
		function getParallelCapability(obj)
				% CHECK PARALLEL-PROCESSING ABILITY (USING PARALLEL COMPUTING TOOLBOX)
			if isempty(obj.CanUseParallel)
				versionInfo = ver;
				if any(strcmpi({versionInfo.Name},'Parallel Computing Toolbox'))
					% [isPoolRunning, pool] = distcomp.remoteparfor.tryRemoteParfor();					
					obj.CanUseParallel = true;
					
				else
					obj.CanUseParallel = false;
				end
				
				% NEW
				obj.CanUseParallel = obj.CanUseParallel | ignition.internal.isPCTInstalled();
				
			end
		end
		function setPreferences(obj)
			
			tlbx = obj.PackageName;
			
			% SET MEMBER OPTION TO GLOBAL PREFERENCE IF EMPTY, OR PREF IS TO NOT USE GPU
			if obj.CanUseGpu
				if ~ispref(tlbx, 'UseGpuPreference')
					obj.UseGpuPreference = strcmp('Yes', questdlg('Use the GPU for Computation where available?'));
					setpref(tlbx, 'UseGpuPreference',obj.UseGpuPreference);
				end
			else
				obj.UseGpuPreference = false;
			end
			
			% QUERY USER TO USE PCT
			if obj.CanUseParallel
				if ~ispref(tlbx, 'UseParallelPreference')
					if strcmp('Yes', questdlg(...
							['Use multi-core/SPMD parallel processing procedures from PCT ',...
							'(e.g. parfor, spmd, parfeval) where available?']))
						obj.UseParallelPreference = true;
					else
						obj.UseParallelPreference = false;
					end
					setpref(tlbx, 'UseParallelPreference',obj.UseParallelPreference);
				end				
			else
				obj.UseParallelPreference = false;
			end
			
		end
		function getPreferences(obj)
			% Manage default preferences for current toolbox:
			%			UseGpuPreference, UseParallelPreference, UseBufferPreference, UseInteractivePreference
			
			% GET PREFERENCES FROM PROPERTIES FITTING NAME CONVENTION 'UsePrefname'
			% 			userPrefNames = {'UseGpuPreference', 'UseParallelPreference', 'UseBufferPreference', 'UseInteractivePreference'};
			mc = metaclass(obj);
			mp = mc.PropertyList;
			propNames = {mp.Name};
			usePrefPropIdx = regexp( propNames, 'Use[A-Z]\w*');
			usePrefPropMatch = ~cellfun(@isempty, usePrefPropIdx);
			usePropNames = propNames(usePrefPropMatch);
			usePropIdx = [usePrefPropIdx{usePrefPropMatch}];
			userPrefNames = usePropNames( usePropIdx == 1);
			
			
			% CHECK STATE/EXISTENCE OF TOOLBOX PREFERENCES -> ADDPREFS
			tlbx = obj.PackageName;			
			if isempty(getpref('ignition'))
				setPreferences(obj)
			end
			% 			defaulttrue = @(b) isempty(b) || logical(b);
			% 			defaultfalse = @(b) ~isempty(b) && logical(b(1));
			for kPref = 1:numel(userPrefNames)
				prefName = userPrefNames{kPref};
				
				% PREFERENCE NAMES WILL MATCH PROPERTIES
				if isprop(obj, prefName)
					
					% INITIALIZE PREFERENCE IF NOT DEFINED IN CURRENT MATLAB ENVIRONMENT
					if ~ispref(tlbx, prefName)
						
						% IF NOT SPECIFIED IN CURRENT ENVIRONMENT OBJECT -> DEFAULT TRUE
						prefVal = defaulttrue(obj.(prefName));
						% 						prefVal = defaultfalse(obj.(prefName)); % -> DEFAULT FALSE
						addpref(tlbx, prefName, prefVal)
					end
					
					% UPDATE PROPERTIES OF CURRENT ENVIRONMENT OBJECT FROM PREFERENCES
					obj.(prefName) = getpref(tlbx, prefName, true);
					
				end
			end
			
			% ALTERNATIVELY -> QUERY USER TO SET PREFERENCES
			% 				uigetpref(tlbx, 'UseGpuPreference',...
			% 					'GPU Computation',...
			% 					'Would you like to use the GPU for Computation where available?',...
			% 					{true,false});
			% 				addpref(tlbx, 'UseParallelPreference', 'Parallel Processing',...
			% 					'Would you like to use multi-core/SPMD parallel processing procedures from PCT (e.g. parfor, spmd, parfeval) where available?',...
			% 					{'yes','no'});
			% 				addpref(tlbx, 'UseInteractivePreference', 'Interactive Tuning',...
			% 					'Would you like to use interactive tuning procedures to set parameter values where available?',...
			% 					{'yes','no'});
			% 			end
			obj.PreferenceStructure = getpref(tlbx);
			
		end		
		function connect(obj)
			% todo: connectGpu & connectParallel
						% TODO: needs work, cleaning up, notification, extension
			% 			if isempty(obj.IsConnected)
			% 				obj.IsConnected = false;
			% 			end
			
			if defaultfalse(obj.IsConnected)
				return
			end
			fprintf('SystemEnvironment: Connect\n')
			
			% ----------------------------------------------
			% GPU CONNECTIONS
			% ----------------------------------------------
			if obj.UseGpuPreference
				
				% ASSIGN CUDA-DEVICE OBJECT TO GPUDEVICE PROPERTY
				% 				anySel = parallel.internal.gpu.isAnyDeviceSelected
				% 				idxByMode =  parallel.internal.gpu.sortDevicesByComputeMode;
				% 				curdev =  parallel.internal.gpu.currentDeviceIndex;
				% 				canSel =  parallel.internal.gpu.canSelectDevice(1);
				% 				canSel =  parallel.internal.gpu.canSelectDevice(2);
				% 				defaultIdx =  parallel.internal.gpu.defaultGPUIndex;
				% 				numGpu =  parallel.internal.gpu.deviceCount;
				% 				parallel.internal.gpu.selectDevice( numGpu);
				obj.GpuDeviceObj = gpuDevice(obj.GpuDeviceIdx);
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
			if obj.UseParallelPreference
				% PARALLEL POOL
				curpool = gcp('nocreate');
				numCores = str2double(getenv('NUMBER_OF_PROCESSORS'));
				if isempty(curpool)
					curpool = parpool(numCores);
				end
				obj.ParallelPoolObj = curpool;
			end
			
			
			% 			% START PARALLEL POOL
			% 			if obj.UseParallelPreference
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
			
			obj.IsConnected = true;
			
		end
		function disconnect(obj)
			
			fprintf('SystemEnvironment: Disconnect\n')
			
			% TODO -> release resources
			obj.IsConnected = false;
		end
	end
	methods (Static)
		function reset()
			global ENVIRONMENTOBJ
			fprintf('SystemEnvironment: Reset\n')
			
			try
				if ~isempty(ENVIRONMENTOBJ)
					ENVIRONMENTOBJ.NumRefs = 0;
				end
				delete(ENVIRONMENTOBJ);
				
			catch
				ENVIRONMENTOBJ = [];
			end
			
		end		
	end
	methods
		function delete(obj)
			global ENVIRONMENTOBJ
			fprintf('SystemEnvironment: Delete\n')
			
			% DECREMENT REFERENCE/CALL COUNTER
			obj.NumRefs = obj.NumRefs - 1;
			if obj.NumRefs < 1
				ENVIRONMENTOBJ = ignition.system.SystemEnvironment.empty;
			end
		end
	end
	
	
	
	
	
	
end







% CLASS-FILE FUNCTIONS
function bOut = defaulttrue(bIn)
bOut = isempty(bIn) || logical(bIn);
end
function bOut = defaultfalse(bIn)
bOut = ~isempty(bIn) && logical(bIn);
end









