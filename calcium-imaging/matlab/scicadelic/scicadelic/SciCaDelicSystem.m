classdef SciCaDelicSystem < matlab.System
%	
% The System object� interface
% 
% System objects are MATLAB classes that derive from matlab.System. As a result, System objects all
% inherit a common public interface, which includes the following standard methods:
% 
% setup - to initialize the object, typically at the beginning of a simulation reset - to clear the
% internal state of the object, bringing it back to its default post-initialization status step - to
% execute the core functionality of the object, optionally accepting some input and/or returning
% some output release - to release any resources (e.g. memory, hardware, or OS-specific) used
% internally by the object When you create new kinds of System objects, you provide specific
% implementations for all the preceding methods to determine its behavior.
	
	% USER SETTINGS
	properties (Access = public)
		UseGpu logical % scalar: can now set size as propname(1,1)
		UsePct logical % scalar: can now set size as propname(1,1)
		UseBuffer logical = false % scalar: can now set size as propname(1,1)
		UseInteractive logical = false % scalar: can now set size as propname(1,1)
		CheckCapabilities logical = true % scalar: can now set size as propname(1,1)
	end
	
	% COMPUTER CAPABILITIES & DEFAULTS
	properties (SetAccess = protected)
		CanUseGpu logical % scalar: can now set size as propname(1,1)
		CanUsePct logical % scalar: can now set size as propname(1,1)
		CanUseBuffer logical % scalar: can now set size as propname(1,1)
		CanUseInteractive logical % scalar: can now set size as propname(1,1)
	end
	properties (SetAccess = protected)
		Default
	end
	properties (SetAccess = protected, Hidden)
		ChildSystem cell % vector
		GpuRetrievedProps struct % scalar: can now set size as propname(1,1)
		SettableProps
		GpuDevice
	end
	
	% STATUS
	properties (Access = protected, Transient, Hidden)
		StatusHandle
		StatusString char
		StatusNumber
	end
	properties (Constant, Access = protected, Hidden)
		StatusUpdateInterval = .15
	end
	
	% INPUT/OUTPUT DESCRIPTION
	properties (SetAccess = protected )%, Hidden)
		NFrames%TODO
		InputScale
		InputOffset
		OutputScale
		OutputOffset
		InputRange
		OutputRange
		GaussianFilterFcn
	end
	properties (SetAccess = protected)%, Hidden)  % TODO: NonTunable... caused fatal errors?? cant remember
		FrameSize
		InputDataType char
		OutputDataType char
	end
	
	% TUNING
	properties (SetAccess = protected, Hidden)
		TuningImageDataSet
		TuningImageIdx
		TuningStep struct % vector
		TuningCurrentStep
		Tuning
		TuningFigureHandles
		TuningFigureOverlayResult = false
		TuningFigureAutoScale = true
		TuningFigureInputCLim
		TuningFigureOutputCLim
		TuningTimeTaken
	end
	properties (SetAccess = protected, Hidden, Transient)
		TuningDelayedUpdateTimerObj
		TuningAutoProgressiveUpdateTimerObj
		TuningFigureNeedsUpdate = false;
	end
	
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden)
		pUseGpu logical
		pUsePct logical
		pUseBuffer logical
	end
	
	
	
	
	
	methods
		function obj = SciCaDelicSystem(varargin)
			if obj.CheckCapabilities
				checkCapabilitiesAndPreferences(obj); % TODO: find proper place to check options
			end
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
			parseConstructorInput(obj,varargin(:))
			getSettableProperties(obj);
		end
		function parseConstructorInput(obj,args)
			if nargin < 2
				args = {};
			end
			propSpec = {};
			nArgs = numel(args);
			if nArgs >= 1
				% EXAMINE FIRST INPUT -> SUBCLASS, STRUCT, DATA, PROPS
				firstArg = args{1};
				firstArgType = find([...
					isa( firstArg, 'SciCaDelicSystem') ; ...
					isstruct( firstArg ) ; ...
					isnumeric( firstArg ) ; ...
					isa( firstArg, 'char') ],...
					1, 'first');
				switch firstArgType
					case 1 % FLUOPROFUNCTION SUBCLASS
						obj = copyProps(obj,firstArg);
					case 2 % STRUCTURE REPRESENTATION OF OBJECT
						fillPropsFromStruct(obj,firstArg);
					case 3 % RAW DATA INPUT
						obj.data = firstArg;
					case 4 % 'PROPERTY',VALUE PAIRS
						propSpec = args(:);
					otherwise
						% 						keyboard %TODO
				end
				if isempty(propSpec) && nArgs >=2
					propSpec = args(2:end);
				end
			end
			if ~isempty(propSpec)
				if numel(propSpec) >=2
					for k = 1:2:length(propSpec)
						obj.(propSpec{k}) = propSpec{k+1};
					end
				end
			end
		end
		function fillPropsFromStruct(obj, structSpec)
			fn = fields(structSpec);
			for kf = 1:numel(fn)
				try
					obj.(fn{kf}) = structSpec.(fn{kf});
				catch me
					getReport(me)
					% 				  warning('SciCaDelicSystem:parseConstructorInput', me.message)
				end
			end
		end
		function fillDefaults(obj)
			if isstruct(obj.Default)
				props = fields(obj.Default);
				for k=1:numel(props)
					if isprop(obj,props{k}) && isempty(obj.(props{k}))
						obj.(props{k}) = obj.Default.(props{k});
					end
				end
			end
			setPrivateProps(obj)
		end
		function checkCapabilitiesAndPreferences(obj)
			
			% CHECK STATE/EXISTENCE OF TOOLBOX PREFERENCES -> ADDPREFS
			tlbx = 'scicadelic';
			if ~ispref(tlbx)
				addpref(tlbx, 'UseGpu',true)
				addpref(tlbx, 'UsePct',true)
				addpref(tlbx, 'UseInteractive', true)
				% 				uigetpref(tlbx, 'UseGpu',...
				% 					'GPU Computation',...
				% 					'Would you like to use the GPU for Computation where available?',...
				% 					{true,false});
				% 				addpref(tlbx, 'UsePct', 'Parallel Processing',...
				% 					'Would you like to use parallel processing procedures from PCT (e.g. parfor, spmd, parfeval) where available?',...
				% 					{'yes','no'});
				% 				addpref(tlbx, 'UseInteractive', 'Interactive Tuning',...
				% 					'Would you like to use interactive tuning procedures to set parameter values where available?',...
				% 					{'yes','no'});
			end
			gpref = getpref(tlbx);
			
			% INITIALIZE GLOBAL VARIABLES
			global COMPUTERCAPABILITY
			% 			global GLOBALPREFERENCE
			if isempty(COMPUTERCAPABILITY)
				COMPUTERCAPABILITY = struct('CanUseGpu',[],'CanUsePct',[],'CanUseBuffer',[],'CanUseInteractive',[]);
			end
			% 			if isempty(GLOBALPREFERENCE)
			% 				GLOBALPREFERENCE = struct('UseGpu',[],'UsePct',[]);
			% 			end
			thiscomputer = COMPUTERCAPABILITY;
			% 			gpref = GLOBALPREFERENCE;
			
			
			% CHECK GPU-PROCESSING ABILITY
			if isempty(thiscomputer.CanUseGpu)
				try
					dev = gpuDevice;
					if dev.DeviceSupported
						thiscomputer.CanUseGpu = true;
						fprintf('GPU detected: \n\t%s \n\t%d multiprocessors \n\tCompute Capability %s\n\n',...
							dev.Name, dev.MultiprocessorCount, dev.ComputeCapability);
					else
						thiscomputer.CanUseGpu = false;
					end
				catch
					thiscomputer.CanUseGpu = false;
				end
			end
			
			% ASSIGN CUDA-DEVICE OBJECT TO GPUDEVICE PROPERTY
			if thiscomputer.CanUseGpu
				obj.GpuDevice = gpuDevice;
			end
			
			% SET MEMBER OPTION TO GLOBAL PREFERENCE IF EMPTY, OR PREF IS TO NOT USE GPU
			if thiscomputer.CanUseGpu
				obj.CanUseGpu = true;
				if isempty(gpref.UseGpu)
					if strcmp('Yes', questdlg('Would you like to use the GPU for Computation where available?'))
						gpref.UseGpu = true;
					else
						gpref.UseGpu = false;
					end
					setpref(tlbx, 'UseGpu',gpref.UseGpu);
				end
			else
				gpref.UseGpu = false;
			end
			% 			if isempty(obj.UseGpu)
			obj.UseGpu = gpref.UseGpu;
			% 			end
			
			
			% CHECK PARALLEL-PROCESSING ABILITY (USING PARALLEL COMPUTING TOOLBOX)
			if isempty(thiscomputer.CanUsePct)
				versionInfo = ver;
				if any(strcmpi({versionInfo.Name},'Parallel Computing Toolbox'))
					% [isPoolRunning, pool] = distcomp.remoteparfor.tryRemoteParfor();
					thiscomputer.CanUsePct = true;
				else
					thiscomputer.CanUsePct = false;
				end
			end
						
			if thiscomputer.CanUsePct
				obj.CanUsePct = true;
				if isempty(gpref.UsePct)
					% Query user to use PCT
					if strcmp('Yes', questdlg('Would you like to use the Parallel Computing Toolbox (PCT) where available?'))
						gpref.UsePct = true;
					else
						gpref.UsePct = false;
					end
				end
				setpref(tlbx, 'UsePct',gpref.UsePct);
			else
				gpref.UsePct = false;
			end
			% 			if isempty(obj.UsePct)
			obj.UsePct = gpref.UsePct;
			% 			end
 			
			fn = fields(gpref);
			for k=1:numel(fn)
				if isempty(gpref.(fn{k}))
					gpref.(fn{k}) = false;
				end
				if isempty(obj.(fn{k}))
					obj.(fn{k}) = gpref.(fn{k});
				end
			end
			
			fn = fields(thiscomputer);
			for k=1:numel(fn)
				if isempty(thiscomputer.(fn{k}))
					thiscomputer.(fn{k}) = false;
				end
				obj.(fn{k}) = thiscomputer.(fn{k});
			end
			
			try
				parallel.gpu.rng(7301986,'Philox4x32-10');
			catch me
				getReport(me)
			end
			
			% 			GLOBALPREFERENCE = gpref;
			COMPUTERCAPABILITY = thiscomputer;
		end
		function setStatus(obj,statusNum, statusStr)
			% SciCaDelicFunctions use the method >> obj.setStatus(n, 'function status') in a similar
			% manner to how they would use the MATLAB builtin waitbar function. This method will create a
			% waitbar for functions that update their status in this manner, but may be easily modified to
			% convey status updates to the user in some other by some other means. Whatever the means,
			% this method keeps the avenue of interaction consistent and easily modifiable.
			persistent setTime
			if isempty(setTime)
				setTime = cputime;
			end
			% 			localTimeElapsed = cputime - setTime;
			if nargin < 3
				if isempty(obj.StatusString)
					statusStr = 'Awaiting status update';
				else
					statusStr = obj.StatusString;
				end
				if nargin < 2 % NO ARGUMENTS -> Closes
					closeStatus(obj);
					setTime = cputime;
					return
				end
			end
			obj.StatusString = statusStr;
			obj.StatusNumber = statusNum;
			if isinf(statusNum) % INF -> Closes
				closeStatus(obj);
				return
			end
			% OPEN OR CLOSE STATUS INTERFACE (WAITBAR) IF REQUESTED
			%      0 -> open          inf -> close
			if (cputime - setTime) > obj.StatusUpdateInterval
				if isempty(obj.StatusHandle) || ~isvalid(obj.StatusHandle)
					openStatus(obj);
					return
				else
					updateStatus(obj);
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
				% 			obj.data = objInput.data;  %TODO?
			end
		end
		function getSettableProperties(obj)
			oMeta = metaclass(obj);
			oPropsAll = oMeta.PropertyList(:);
			oProps = oPropsAll([oPropsAll.DefiningClass] == oMeta);
			propSettable = ~strcmp('private',{oProps.SetAccess}) ...
				& ~strcmp('protected',{oProps.SetAccess}) ...
				& ~[oProps.Constant] ...
				& ~[oProps.Transient];
			obj.SettableProps = oProps(propSettable);
		end
		function varargout = constructLowPassFilter(obj, imSize, sigma, hSize)
			% DEFINE FILTER PROPERTIES
			if nargin < 2
				imSize = obj.FrameSize;
			end
			maxFilterSize = min(imSize);
			maxSigma = floor((maxFilterSize -1)/4);
			if nargin < 3
				sigma = floor(1/8 * maxSigma);
			end
			if numel(imSize) == 1
				imSize = [imSize imSize];
			end
			if nargin < 4
				hSize = 2*ceil(2 * sigma)+1;
			end
			
			% CALCULATE COEFFICIENTS
			H = rot90(fspecial('gaussian', hSize, sigma),2);
			[sepcoeff, hcol, hrow] = isfilterseparable(H);
			hCenter = floor((size(H)+1)/2);
			hPad = hSize - hCenter;
			
			% CREATE SUBREFERENCE STRUCTURE FOR DEPADDING
			imCenter = floor((imSize+1)/2) + hPad;
			if obj.UseGpu
				subsCenteredOn = @(csub,n) gpuArray.colon(floor(csub-n/2+1),floor(csub+n/2))';%NEW
			else
				subsCenteredOn = @(csub,n) (floor(csub-n/2+1):floor(csub+n/2))';
			end
			subrefDePad.type = '()';
			subrefDePad.subs = {...
				subsCenteredOn(imCenter(2),imSize(2)),...
				subsCenteredOn(imCenter(1),imSize(1))};
			
			% CONSTRUCT FILTER FUNCTION ->  CONV2 - GPU
			if obj.UseGpu
				if sepcoeff
					ghrow = gpuArray(hrow);
					ghcol = gpuArray(hcol);
					gfcn = @(F)...
						subsref(...
						conv2(ghrow, ghcol, ...
						padarray(F, hPad, 'replicate', 'both'),'same'),...
						subrefDePad); % gputimeit -> .0040
				else
					gH = gpuArray(H);
					gfcn = @(F)...
						subsref(...
						conv2(padarray(F, hPad, 'replicate', 'both'), gH, 'same'),...
						subrefDePad);
				end
				filterFcn = gfcn;
			else
				if sepcoeff
					cfcn = @(F)...
						subsref(...
						conv2(hrow, hcol, ...
						padarray(F, hPad, 'replicate', 'both'),'same'),...
						subrefDePad); % timeit -> .0480
				else
					cfcn = @(F)...
						subsref(...
						conv2(padarray(F, hPad, 'replicate', 'both'), H, 'same'),...
						subrefDePad); % timeit -> .720
				end
				filterFcn = cfcn;
			end
			
			% CLEAN ANONYMOUS FUNCTION WORKSPACE
			% 			filterFcn = str2func(func2str(filterFcn)); % Recently uncommented (was commented out because imcompatible with codegen)
			
			if nargout
				varargout{1} = filterFcn;
				if nargout > 1
					varargout{2} = H;
				end
			else
				obj.GaussianFilterFcn = filterFcn;
			end
		end
		function addChildSystem(obj, child)
			n = numel(obj.ChildSystem);
			obj.ChildSystem{n+1} = child;
		end
	end
	
	% TUNING
	methods
		function tune(obj, tuningData)
			% CHECK IF LOCKED
			if isLocked(obj)
				release(obj)
			end
			
			% INITIALIZATION
			checkInput(obj, tuningData)
			fillDefaults(obj)
			tuneLimitScalingFactors(obj, tuningData)
			obj.TuningImageDataSet = tuningData;
			obj.TuningImageIdx = 1;
			
			% RUN SUB-CLASS-DEFINED TUNING FUNCTIONS
			setPrivateProps(obj)
			if obj.UseInteractive
				tuneInteractive(obj)
			else
				tuneAutomated(obj)
			end
			setPrivateProps(obj)
		end
		function checkInput(obj, data)
			if isempty(obj.FrameSize)
				obj.FrameSize = [size(data,1), size(data,2)];
			end
			obj.InputDataType = getClass(obj, data);
			% 			if ismethod(obj, 'processData')
			% 				fprintf('superclass processdata call from checkInput\n')
			% 				output = processData(obj, data);
			% 				obj.OutputDataType = getClass(obj, output);
			
			if isempty(obj.OutputDataType)
				obj.OutputDataType = obj.InputDataType;
			end
			if isa(data,'gpuArray')
				obj.UseGpu = true;
			end
			tuneLimitScalingFactors(obj, data);
		end
		function tuneLimitScalingFactors(obj, data)
			try
				if islogical(data)
					obj.InputRange = [false true];
				else
					if isempty(obj.InputRange)
						obj.InputRange = double([min(data(:))  max(data(:))]);
					else
						obj.InputRange = double([...
							min(cast(obj.InputRange(1),'like',data), min(data(:))),...
							max(cast(obj.InputRange(2),'like',data), max(data(:)))]);
					end
					dataStd = std(double(data(:)));
					% 				if isinteger(data) % TODO
					
					if isinteger(data)
					A = intmin(obj.OutputDataType);
					Z = intmax(obj.OutputDataType);
										
					if isempty(obj.OutputRange)
						obj.OutputRange = double([A , Z-dataStd]);
					else
						obj.OutputRange = [ max(obj.OutputRange(1), A) ,  min(obj.OutputRange(2),Z-dataStd) ];
					end
					else
						obj.OutputRange = [0 1];
					end
					
					obj.InputScale = double(obj.InputRange(2) - obj.InputRange(1));
					obj.InputOffset = double(obj.InputRange(1));
					obj.OutputScale = double(obj.OutputRange(2) - obj.OutputRange(1));
					obj.OutputOffset = double(obj.OutputRange(1));
				end
			catch me
				getReport(me);
			end
		end
		function data = getProcessedTuningData(obj)
			numSteps = numel(obj.TuningStep);
			N = size(obj.TuningImageDataSet,3);
			F = obj.TuningImageDataSet;
			k=1;
			while (k <= numSteps)
				parameterPropVal = obj.TuningStep(k).ParameterDomain(obj.TuningStep(k).ParameterIdx);
				parameterPropName = obj.TuningStep(k).ParameterName;
				if iscell(parameterPropVal)
					parameterPropVal = parameterPropVal{1};
				end
				obj.(parameterPropName) = parameterPropVal;
				if obj.TuningStep(k).CompleteStep;
					fcn = obj.TuningStep(k).Function;
					for n=1:N
						Fout = feval( fcn, obj, F(:,:,n));
						Fstep(:,:,n) = onCpu(obj, Fout);
					end
					F = Fstep;
				end
				k = k+1;
			end
			data = F;
			obj.TuningImageDataSet = [];
		end
		function clearTuningData(obj)
			obj.TuningImageDataSet = [];
		end
	end
	methods (Abstract)
		tuneInteractive(obj)
		tuneAutomated(obj)
	end
	methods (Abstract, Access = protected, Hidden)
		setPrivateProps(obj)
	end
	
	% INITIALIZATION HELPER METHODS
	methods (Access = protected)			
		function fetchPropsFromGpu(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			propSettable = ~[oProps.Dependent] & ~[oProps.Constant];
			for k=1:length(propSettable)
				if propSettable(k)
					pn = oProps(k).Name;
					try
						if isa(obj.(pn), 'gpuArray') && existsOnGPU(obj.(pn))
							obj.(pn) = gather(obj.(pn));
							obj.GpuRetrievedProps.(pn) = obj.(pn);
						end
					catch me
						getReport(me)
					end
				end
			end
		end
		function pushGpuPropsBack(obj)
			fn = fields(obj.GpuRetrievedProps);
			for kf = 1:numel(fn)
				pn = fn{kf};
				if isprop(obj, pn)
					if obj.UseGpu
						obj.(pn) = gpuArray(obj.GpuRetrievedProps.(pn));
					else
						obj.(pn) = obj.GpuRetrievedProps.(pn);
					end
				end
			end
		end
		function setInitialState(obj)
			% INITIALIZE/RESET ALL DESCRETE-STATE PROPERTIES
			dStates = obj.getDiscreteState;
			if ~isempty(dStates)
				fn = fields(dStates);
				for m = 1:numel(fn)
					dStates.(fn{m}) = [];
				end
			end
			fillDefaults(obj)
			% 		 checkCapabilitiesAndPreferences(obj) setPrivateProps(obj)
		end
	end
	methods (Access = protected)
		function varargout = createTuningFigure(obj)
			% DISPLAY CONSTANTS
			fontSize = 12;
			activeColor = [1 1 1 .8];
			inactiveColor = [.6 .6 .6 .2];
			otherColor = [.95 .95 .95 .5];
			cmap = gray(256);
			
			% INPUT IMAGE
			if isempty(obj.TuningImageDataSet)
				tuningDataInput = zeros(obj.FrameSize, 'double');
			else
				tuningDataInput = onCpu(obj, obj.TuningImageDataSet(:,:,1));
			end
			h.fig = figure;
			h.axInput = handle(axes('Parent',h.fig,...
				'Units','normalized',...
				'Position',[0 0 .5 1]));
			h.imInput = handle(imagesc(tuningDataInput, 'Parent', h.axInput));
			
			% OUTPUT IMAGE
			tuningDataOutput = zeros(obj.FrameSize, 'double');
			h.axOutput = handle(axes('Parent',h.fig,...
				'Units','normalized',...
				'Position',[.5 0 .5 1]));
			h.imOutput = handle(imagesc(tuningDataOutput, 'Parent',h.axOutput));
			
			% COMPOSITE IMAGE
			tuningDataComposite = cat(3,...
				scaleForComposite(obj, tuningDataOutput),...
				scaleForComposite(obj, tuningDataInput),...
				scaleForComposite(obj, tuningDataOutput));
			h.axComposite = handle(axes('Parent',h.fig,...
				'Units','normalized',...
				'Position',[0 0 1 1]));
			h.imComposite = handle(image(tuningDataComposite, 'Parent',h.axComposite));
			
			if obj.TuningFigureOverlayResult
				h.imInput.Visible = 'off';
				h.imOutput.Visible = 'off';
				h.axCurrent = h.axComposite;
			else
				h.imComposite.Visible = 'off';
				h.axCurrent = h.axOutput;
			end
			
			h.ax = [h.axInput, h.axOutput, h.axComposite];
			h.im = [h.imInput, h.imOutput, h.imComposite];
			
			% FIGURE PROPERTIES
			set(h.fig,...
				'Color',[.2 .2 .2],...
				'NextPlot','replace',...
				'Units','normalized',...
				'Color',[.25 .25 .25],...
				'MenuBar','none',...
				'Name','Tune Scicadelic',...
				'NumberTitle','off',...
				'HandleVisibility', 'callback',...
				'Clipping','on')
			h.fig.Position = [0 0 1 1];
			h.fig.Colormap = cmap;
			
			% AXES PROPERTIES
			set(h.ax,...
				'xlimmode','manual',...
				'ylimmode','manual',...
				'zlimmode','manual',...
				'climmode','manual',...
				'alimmode','manual',...
				'GridColor',[0 0 0],...
				'GridLineStyle','none',...
				'MinorGridColor',[0 0 0],...
				'TickLabelInterpreter','none',...
				'XGrid','off',...
				'YGrid','off',...
				'Visible','off',...
				'Layer','top',...
				'Clipping','on',...
				'NextPlot','replacechildren',...
				'TickDir','out',...
				'YDir','reverse',...
				'Units','normalized',...
				'DataAspectRatio',[1 1 1]);
			if isprop(h.ax, 'SortMethod')
				set(h.ax, 'SortMethod', 'childorder');
			else
				set(h.ax, 'DrawMode','fast');
			end
			% 			h.ax.Units = 'normalized'; h.ax.Position = [0 0 1 1];
			
			% TEXT FOR TUNING STEPS (PARAMETER NAMES & VALUES)
			imWidth = obj.FrameSize(1);
			imHeight = obj.FrameSize(2);
			numTuningSteps = numel(obj.TuningStep);
			textBlockInset = min(20, imWidth/numTuningSteps);
			% 			textBlockSpacing = textBlockInset; textBlockWidth = round(imWidth -
			% 			2*textBlockInset)/numTuningSteps;
			textPosition = [textBlockInset round(imHeight/20)];
			infoTextPosition = [textBlockInset, imHeight-60];
			for k=1:numTuningSteps
				initialText = sprintf('%s: %g', obj.TuningStep(k).ParameterName,999);
				h.txParameter(k) = handle(text(...
					'String', initialText,...
					'FontWeight','normal',...
					'BackgroundColor',[.1 .1 .1 .3],...
					'Color', inactiveColor,...
					'FontSize',fontSize,...
					'Margin',1,...
					'Position', textPosition,...
					'Parent', h.axCurrent));
				textPosition = textPosition + [0 h.txParameter(k).Extent(4)];%h.txParameter(k).Extent(4)+textBlockSpacing 0];
			end
			h.txParameter(1).Color = activeColor;
			
			% TEXT FOR CURRENT FRAME AND STATS
			idxText = sprintf('Frame Index: %i', obj.TuningImageIdx);%TODO
			h.txIdx = handle(text(...
				'String', idxText,...
				'FontWeight','normal',...
				'BackgroundColor',[.1 .1 .1 .3],...
				'Color', otherColor,...
				'FontSize',fontSize,...
				'Margin',1,...
				'Position', infoTextPosition,...
				'Parent', h.axCurrent));
			rtStart = tic;
			timeText = sprintf('Run-Time: %-03.4g ms', 1000*(toc(rtStart)));
			h.txTime = handle(text(...
				'String', timeText,...
				'FontWeight','normal',...
				'BackgroundColor',[.1 .1 .1 .3],...
				'Color', otherColor,...
				'FontSize',fontSize,...
				'Margin',1,...
				'Parent', h.axCurrent));
			h.txTime.Position = [infoTextPosition(1)...
				h.txIdx.Extent(2)+h.txIdx.Extent(4)/2+2];
			obj.TuningFigureInputCLim = [0 65535];
			obj.TuningFigureOutputCLim = [0 65535];
			cLimText = sprintf('Contrast-Limits: [ %-d , %-d ]',...
				obj.TuningFigureOutputCLim(1), obj.TuningFigureOutputCLim(2));
			h.txOutputCLim = handle(text(...
				'String', cLimText,...
				'FontWeight','normal',...
				'BackgroundColor',[.1 .1 .1 .3],...
				'Color', otherColor,...
				'FontSize',fontSize,...
				'Margin',1,...
				'Parent', h.axCurrent));
			h.txOutputCLim.Position = [infoTextPosition(1)...
				h.txTime.Extent(2)+h.txTime.Extent(4)/2+2];
			h.txInputCLim = handle(text(...
				'String', cLimText,...
				'FontWeight','normal',...
				'BackgroundColor',[.1 .1 .1 .3],...
				'Color', otherColor,...
				'FontSize',fontSize,...
				'Margin',1,...
				'Parent', h.axInput));
			h.txInputCLim.Position = [infoTextPosition(1)...
				h.txTime.Extent(2)+h.txTime.Extent(4)/2+2];
			
			h.tx = [h.txParameter(:)' , h.txIdx , h.txTime , h.txOutputCLim];
			set(h.tx, 'Parent', h.axCurrent);
			assignin('base','h',h);
			
			obj.TuningCurrentStep = 1;
			h.fig.WindowKeyPressFcn = @(src,evnt)keyPressFcn(obj,src,evnt);
			h.fig.WindowKeyReleaseFcn = @(src,evnt)keyReleaseFcn(obj,src,evnt);
			obj.TuningFigureHandles = h;
			
			% DELAYED-UPDATE TIMER OBJECT
			obj.TuningDelayedUpdateTimerObj = timer(...
				'BusyMode','drop',...
				'ExecutionMode','singleShot',...
				'StartDelay',.050,...
				'TimerFcn',@(~,~)updateTuning(obj));
			start(obj.TuningDelayedUpdateTimerObj)
			% 			updateTuningText(obj) updateTuningFigure(obj)
			if nargout
				varargout{1} = h;
			end
		end
		function keyPressFcn(obj,~,evnt)
			if strcmp('on',obj.TuningDelayedUpdateTimerObj.Running)
				stop(obj.TuningDelayedUpdateTimerObj)
			end
			% NOTE THE INDEX OF CURRENTLY USED IMAGE
			if isempty(obj.TuningImageIdx)
				obj.TuningImageIdx = 1;
			end
			curStep = obj.TuningCurrentStep;
			numSteps = numel(obj.TuningStep);
			
			modKey = evnt.Modifier;
			obj.TuningFigureNeedsUpdate = true;
			switch evnt.Key;
				case 'leftarrow'
					if isempty(modKey) % LEFT: PREVIOUS FRAME
						obj.TuningImageIdx = max(obj.TuningImageIdx - 1, 1);
						stopAutoUpdateTimer(obj)
					elseif all(strcmp('control',modKey)) % CTRL-LEFT: BEGINNING OF STACK
						obj.TuningImageIdx = 1;
					end
				case 'rightarrow'
					if isempty(modKey) % RIGHT: NEXT FRAME
						obj.TuningImageIdx = min(obj.TuningImageIdx + 1,...
							size(obj.TuningImageDataSet,3));
					elseif all(strcmp('control',modKey)) % CTRL-RIGHT: 
						if isempty(obj.TuningAutoProgressiveUpdateTimerObj)
							obj.TuningAutoProgressiveUpdateTimerObj = timer(...
								'BusyMode','drop',...
								'ExecutionMode','fixedSpacing',...
								'StartDelay',.250,...
								'TasksToExecute',inf,...
								'Period', .250,...
								'TimerFcn',@(~,~)cycleTuningIndex(obj));
							start(obj.TuningAutoProgressiveUpdateTimerObj)
						else
							stopAutoUpdateTimer(obj)
						end
					end
				case 'pageup' % PAGE-UP: PREVIOUS PARAMETER
					obj.TuningCurrentStep = min(max(obj.TuningCurrentStep - 1, 0), numSteps);
				case 'pagedown' % PAGE-DOWN: NEXT PARAMETER
					obj.TuningCurrentStep = min(max(obj.TuningCurrentStep + 1, 0), numSteps);
				case 'uparrow' % UP: INCREASE PARAMETER VALUE
					if isempty(modKey)
						if curStep >= 1
							obj.TuningStep(curStep).ParameterIdx = min(...
								obj.TuningStep(curStep).ParameterIdx + 1,...
								numel(obj.TuningStep(curStep).ParameterDomain));
						end
					elseif all(strcmp('control',modKey)) % CTRL-UP: PREVIOUS PARAMETER
						obj.TuningCurrentStep = min(max(obj.TuningCurrentStep - 1, 0), numSteps);
					end
				case 'downarrow' % DOWN: DECREASE PARAMETER VALUE
					if isempty(modKey)
						if curStep >= 1
							obj.TuningStep(curStep).ParameterIdx = max(...
								obj.TuningStep(curStep).ParameterIdx - 1, 1);
						end
					elseif all(strcmp('control',modKey)) % CTRL-RIGHT: NEXT PARAMETER
						obj.TuningCurrentStep = min(max(obj.TuningCurrentStep + 1, 0), numSteps);
					end
				case 'space'
					if isempty(modKey) % SPACE: TOGGLE AUTO-SCALE
						obj.TuningFigureAutoScale = ~obj.TuningFigureAutoScale;
					elseif all(strcmp('control',modKey)) % CTRL-SPACE: ADJUST CONTRAST (INPUT)
						obj.TuningFigureHandles.imInput.CData = double(obj.TuningFigureHandles.imInput.CData);
						imcontrast(obj.TuningFigureHandles.imInput)
					elseif all(strcmp('shift',modKey)) % SHIFT-SPACE: ADJUST CONTRAST (OUTPUT)
						obj.TuningFigureHandles.imOutput.CData = double(obj.TuningFigureHandles.imOutput.CData);
						imcontrast(obj.TuningFigureHandles.imOutput)
					end
				case 'c'
					if isempty(modKey) % C: TOGGLE COLORMAP
						hfig = obj.TuningFigureHandles.fig;
						cmap = hfig.Colormap;
						if all(cmap(:,1) == cmap(:,2)) % gray
							hfig.Colormap = parula(256);
						else
							hfig.Colormap = gray(256);
						end
					elseif all(strcmp('shift',modKey)) % SHIFT-C: TOGGLE OVERLAY
						obj.TuningFigureOverlayResult = ~obj.TuningFigureOverlayResult;
					end
				case 'o'
					obj.TuningFigureOverlayResult = ~obj.TuningFigureOverlayResult;
				case 'return'
					if isempty(modKey) % ENTER: NEXT STEP (OR FINISH)
						obj.TuningCurrentStep = curStep + 1;
						if obj.TuningCurrentStep > numel(obj.TuningStep)
							obj.TuningFigureNeedsUpdate = false;
							closeTuningFigure(obj);
							return
						end
					elseif all(strcmp('control',modKey)) % CTRL-ENTER: TOGGLE OVERLAY
						obj.TuningFigureOverlayResult = ~obj.TuningFigureOverlayResult;
					end
				case 'escape'
					obj.TuningFigureNeedsUpdate = false;
					closeTuningFigure(obj);
					return
				otherwise
					obj.TuningFigureNeedsUpdate = false;
					% 					fprintf('KEYPRESS: %s\t', evnt.Key) fprintf('(%s)\t',evnt.Modifier{:})
					% 					fprintf('[%s]\t',evnt.Character) fprintf('\n')
			end
			
			% UPDATE
			updateTuningText(obj)
			
		end
		function keyReleaseFcn(obj,~,~)
			timerIsRunning = strcmp('on',obj.TuningDelayedUpdateTimerObj.Running);
			if obj.TuningFigureNeedsUpdate && ~timerIsRunning
				start(obj.TuningDelayedUpdateTimerObj)
				obj.TuningFigureNeedsUpdate = false;
			end
		end
		function stopAutoUpdateTimer(obj)
			if ~isempty(obj.TuningAutoProgressiveUpdateTimerObj)...
					&& isvalid(obj.TuningAutoProgressiveUpdateTimerObj)				
							stop(obj.TuningAutoProgressiveUpdateTimerObj)
							delete(obj.TuningAutoProgressiveUpdateTimerObj);							
			end
			obj.TuningAutoProgressiveUpdateTimerObj = [];
		end
		function cycleTuningIndex(obj)
			% CALLED BY TUNINGAUTOPROGRESSIVEUPDATETIMER (CTRL + RIGHT-ARROW)
			idx = obj.TuningImageIdx + 1;
			if idx > size(obj.TuningImageDataSet,3)
				idx = 1;
			end
			obj.TuningImageIdx = idx;
			updateTuning(obj)
		end
		function updateTuning(obj)
			updateTuningFigure(obj)
			updateTuningText(obj)
		end
		function updateTuningFigure(obj)
			h = obj.TuningFigureHandles;
			curStep = obj.TuningCurrentStep;
			obj.TuningImageIdx = min(max(obj.TuningImageIdx, 1), size(obj.TuningImageDataSet,3));
			F = obj.TuningImageDataSet(:,:,obj.TuningImageIdx);
			
			% SEND INPUT TO GPU IF NECESSARY
			if obj.UseGpu && ~isa(F, 'gpuArray')
				Fstep = gpuArray(F);
			else
				Fstep = F;
			end
			
			% CALL EACH PRECEDING FUNCTION WITH CHOSEN PARAMETERS
			
			if curStep >= 1
				k=1;
				completeStep = false;
				while (k <= curStep) || (~completeStep)
					parameterPropVal = obj.TuningStep(k).ParameterDomain(obj.TuningStep(k).ParameterIdx);
					parameterPropName = obj.TuningStep(k).ParameterName;
					
					if iscell(parameterPropVal) % NEW!!
						parameterPropVal = parameterPropVal{1};
					end
					
					obj.(parameterPropName) = parameterPropVal;
					completeStep = obj.TuningStep(k).CompleteStep;					
					if completeStep
						setPrivateProps(obj)
						fcn = obj.TuningStep(k).Function;
						rtStart = tic;
						Fstep = feval( fcn, obj, Fstep);
						obj.TuningTimeTaken = toc(rtStart);
					end
					k=k+1;
				end
			end
			% RECORD CONTRAST LIMITS (CHANGE OR KEEP)
			% 			if obj.TuningFigureAutoScale || isempty(obj.TuningFigureOutputCLim)
			% 				obj.TuningFigureOutputCLim = onCpu(obj, [min(Fstep(:)) , max(Fstep(:))]);
			% 			end
			
			% OVERLAY INPUT & OUTPUT OR SHOW SIDE-BY-SIDE
			if obj.TuningFigureOverlayResult
				Fin = scaleForComposite(obj, F, [0 1]);
				Fout = scaleForComposite(obj, Fstep, [0 .6]);
				h.axCurrent = h.axComposite;
				h.imComposite.CData(:,:,3) = max(0, Fin-.5*Fout); % h.imComposite.CData(:,:,2) = Fin;
				h.imComposite.CData(:,:,2) = .2*max(0, Fin - .6*Fout);%NEW
				h.imComposite.CData(:,:,1) = Fout;%abs(Fin-.5*Fout);% h.imComposite.CData(:,:,[1,3]) = repmat(Fout, 1,1,2);
				h.imComposite.Visible = 'on';
				h.imInput.Visible = 'off';
				h.imOutput.Visible = 'off';
				obj.TuningFigureOutputCLim = onCpu(obj, [min(Fstep(:)) , max(Fstep(:))]);
				obj.TuningFigureInputCLim = onCpu(obj, [min(F(:)) , max(F(:))]);
				checkCLim(obj)
			else
				% 				Fin = scaleForDisplay(obj, F); Fout = scaleForDisplay(obj, Fstep, [0 1]);
				Fin = onCpu(obj, F);
				Fout = onCpu(obj, Fstep);
				if islogical(Fstep)
					if all(h.imOutput.CData(:) < 1)
						Fout = .75.*double(Fout) + .10.*h.imOutput.CData;
					else
						Fout = .75.*double(Fout);
					end
				end
				h.axCurrent = h.axOutput;
				h.imInput.CData = Fin;
				h.imOutput.CData = Fout;
				h.imComposite.Visible = 'off';
				h.imInput.Visible = 'on';
				h.imOutput.Visible = 'on';
				if obj.TuningFigureAutoScale
					obj.TuningFigureInputCLim = onCpu(obj, [min(F(:)) , max(F(:))]);
					obj.TuningFigureOutputCLim = onCpu(obj, [min(Fstep(:)) , max(Fstep(:))]);
					checkCLim(obj)
				end
				h.axInput.CLim = double(obj.TuningFigureInputCLim);
				h.axOutput.CLim = double(obj.TuningFigureOutputCLim);
			end
			obj.TuningFigureHandles = h;
			% 			h.imInput.CData(:,:,2) = scaleForDisplay(obj,F); h.imInput.CData(:,:,[1,3]) =
			% 			repmat(scaleForDisplay(obj,Fstep), 1,1,2);
		end
		function checkCLim(obj)
			if ~(obj.TuningFigureOutputCLim(2) > obj.TuningFigureOutputCLim(1))
				obj.TuningFigureOutputCLim(2) = obj.TuningFigureOutputCLim(2) + 1;
			end
			if ~(obj.TuningFigureInputCLim(2) > obj.TuningFigureInputCLim(1))
				obj.TuningFigureInputCLim(2) = obj.TuningFigureInputCLim(2) + 1;
			end
		end
		function updateTuningText(obj)
			h = obj.TuningFigureHandles;
			activeColor = [1 1 1 .8];
			inactiveColor = [.6 .6 .6 .4];
			for k=1:numel(obj.TuningStep)
				paramIdx = obj.TuningStep(k).ParameterIdx;
				paramIdx = min( max( 1, paramIdx), numel(obj.TuningStep(k).ParameterDomain));
				x = obj.TuningStep(k).ParameterDomain(paramIdx);
				if iscell(x)
					x = x{1};
				end
				if isnumeric(x)
					h.txParameter(k).String = sprintf('%s: %g', obj.TuningStep(k).ParameterName,x);
				else
					h.txParameter(k).String = sprintf('%s: %s', obj.TuningStep(k).ParameterName,x);%TODO
				end
				if k == obj.TuningCurrentStep
					h.txParameter(k).Color = activeColor;
				else
					h.txParameter(k).Color = inactiveColor;
				end
			end
			h.txIdx.String = sprintf('Frame Index: %i', obj.TuningImageIdx);%TODO
			h.txTime.String = sprintf('Run-Time: %-03.4g ms', 1000*(obj.TuningTimeTaken));
			h.txInputCLim.String = sprintf('Contrast-Limits: [ %-d , %-d ]',...
				obj.TuningFigureInputCLim(1), obj.TuningFigureInputCLim(2));
			h.txOutputCLim.String = sprintf('Contrast-Limits: [ %-d , %-d ]',...
				obj.TuningFigureOutputCLim(1), obj.TuningFigureOutputCLim(2));
			if obj.TuningFigureAutoScale
				h.txOutputCLim.Color = [.95 .95 .95];
				h.txInputCLim.Color = [.95 .95 .95];
			else
				h.txOutputCLim.Color = [.6 .6 .6];
				h.txInputCLim.Color = [.6 .6 .6];
			end
			set(h.tx, 'Parent', h.axCurrent)
		end
		function closeTuningFigure(obj)
			stopAutoUpdateTimer(obj)
			delete(obj.TuningDelayedUpdateTimerObj)
			close(obj.TuningFigureHandles.fig);
		end
	end
	
	% DATA MANIPULATION
	methods (Access = protected)
		function F = onCpu(~, F)
			if isa(F, 'gpuArray')
				F = gather(F);
				
			elseif isa(F, 'struct')
				sFields = fields(F);
				for k=1:numel(sFields)
					fn = sFields{k};
					if isa([F.(fn)], 'gpuArray')
						F.(fn) = gather(F.(fn)); %TODO: FOR STRUCTARRAYS
					end					
				end
				
			end
		end
		function F = onGpu(obj, F)
			if obj.pUseGpu
				if ~isa(F, 'gpuArray')
					F = gpuArray(F);
				
				elseif isa(F, 'struct')
					sFields = fields(F);
					for k=1:numel(sFields)
						fn = sFields{k};
						if ~isa([F.(fn)], 'gpuArray')
							F.(fn) = gpuArray(F.(fn)); %TODO: FOR STRUCTARRAYS
						end
						
					end					
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
		function openStatus(obj)
			obj.StatusHandle = waitbar(0,obj.StatusString);
		end
		function updateStatus(obj)
			% IMPLEMENT WAITBAR UPDATES  (todo: or make a updateStatus method?)
			if isnumeric(obj.StatusNumber) && ischar(obj.StatusString)
				if ~isempty(obj.StatusHandle) && isvalid(obj.StatusHandle)
					waitbar(obj.StatusNumber, obj.StatusHandle,obj.StatusString);
				end
			end
		end
		function closeStatus(obj)
			if ~isempty(obj.StatusHandle)
				if isvalid(obj.StatusHandle)
					close(obj.StatusHandle)
				end
				obj.StatusHandle = [];
			end
		end
		function im = scaleForComposite(obj, im, cLim)
			if isa(im,'gpuArray')
				im = gather(im);
			end
			if nargin < 3
				cLim = obj.TuningFigureOutputCLim;
				if isempty(cLim)
					cLim = double([min(im(:)) max(im(:))]);
					obj.TuningFigureOutputCLim = cLim;
				end
			end
			if all(cLim <= 1) %&& (range(im(:)) > 1)
				imMax = double(max(im(:)));
				im = imadjust(double(im)./imMax,...
					double([min(im(:)), imMax])./imMax , cLim);
			else
				cLim = double(cLim);
				im = max(0,min(1,(double(im)-cLim(1))./(cLim(2)-cLim(1))));
			end
		end
		
	end
	
	
	
	methods (Access = protected)
		
	end
	
	
	
	
	
	
end













% 	NET.addAssembly('System.Speech');
% ss = System.Speech.Synthesis.SpeechSynthesizer; 
% ss.Volume = 100 
% Speak(ss,'You can use .NET Libraries in MATLAB')
	