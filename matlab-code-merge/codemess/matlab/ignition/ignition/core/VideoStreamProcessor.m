classdef (CaseInsensitiveProperties, TruncatedProperties) VideoStreamProcessor < ignition.core.Object & matlab.System
% VideoStreamProcessor - Interface to 'matlab.System' type module
	
	
	% ##################################################
	% SETTINGS
	% ##################################################	
	properties (SetAccess = immutable)
		Name = ''
	end
	properties (Logical)
		Enabled = true % todo
	end
	
	
	% ##################################################
	% INPUT/OUTPUT PORTS & CHARACTERISTICS
	% ##################################################
	properties
		MainInput
		MainOutput
	end	
	properties (SetAccess = ?ignition.core.Object, Nontunable)		
		InputDataType
		NumInputPorts
		InputPortProps
		OutputDataType		
		NumOutputPorts		
		OutputPortProps		
	end
	properties (SetAccess = ?ignition.core.Object, Nontunable)
		InputTransferFcn		
		PreMainTaskFcn @function_handle
		MainTaskFcn @function_handle
		PostMainTaskFcn @function_handle		
		OutputTransferFcn
	end
	properties (SetAccess = ?ignition.core.Object)
		NumFramesInputCount = 0
		NumFramesOutputCount = 0
	end
	properties (SetAccess = ?ignition.core.Object, Nontunable)
		FrameSize
		FrameDimension = 4
		MaxFramesPerStep = 32
	end
	
	
	
	
	
	
	methods 
		function obj = VideoStreamProcessor()
			
		end
	end
	
	% ##################################################
	% SHARED ROUTINE: INPUT -> MAINTASK -> OUTPUT
	% ##################################################
	methods (Access = ?ignition.core.Object)
		function varargout = runMainTask(obj, varargin)
			% Default method for running main task. Can be used if system defines main task property with
			% function handle, or cell array of function handles.
			
			try
				numOut = getNumOutputs(obj);
				
				preFcn = obj.PreMainTaskFcn;
				mainFcn = obj.MainTaskFcn;
				postFcn = obj.PostMainTaskFcn;
				
				in = varargin;
				% 				in = [{F}, varargin{:}];
				
				if ~isempty(mainFcn)
					if isa(mainFcn, 'function_handle')
						% 					fcnInfo = getcallinfo(fcn); functions(fcn)
						out = feval(mainFcn, in{:});%[F, varargin{:}]
						
					elseif iscell(mainFcn)
						%TODO
					else
						
					end
					varargout = out(1:numOut);
					%TODO
				end
				
			catch me
				handleError(me)
			end
		end	
	end
	
	% ##################################################
	% MATLAB SYSTEM METHODS (IMPLEMENTATIONS)
	% ##################################################
	methods (Access = protected)		
		function setupImpl(obj, varargin)
			% setupImpl - Called by setup(obj, F) or on first call to step(obj, F)
			
			% FIRE EVENT -> INITIALIZING
			notify(obj, 'Initializing')
			
			try				
				% INITIALIZATION (STANDARD)
				
				initialize(obj) % defined in core Module class or derived class				
				getNumOutputs(obj);
				
			catch me
				handleError(obj, me)
			end
			
			% FIRE EVENT -> READY
			notify(obj, 'Ready')
			
		end
		function validateInputsImpl(obj, varargin)
			
			% CHECK FOR EMPTY INPUT & EXPECT FIRST ARGUMENT IS VIDEO SEGMENT DATA
			if nargin
				F = varargin{1};
			else
				return
			end
			
			% INPUT DATA-TYPE
			obj.InputDataType = ignition.shared.getDataType(F);
			
			% CHECK IF INPUT IS ALREADY ON GPU
			if isempty(obj.UseGpu)
				obj.UseGpu = isOnGpu(F);
			end
			
			% CHECK IF INPUT NEEDS TRANSFER TO GPU
			
			% INPUT DATA SIZE/DIMENSIONS
			[numRows,numCols,numChannels] = getFrameSize(F);
			obj.FrameSize = [numRows,numCols,numChannels];
			
			% GET NUMBER OF FRAMES IN INPUT -> MAX FRAMES-PER-STEP
			% 			numFrames = ignition.shared.getNumFrames(F);
			% 			obj.MaxFramesPerStep = ignition.shared.initOrUpdate( @max, obj.MaxFramesPerStep, numFrames);
									
		end
		function numOutputs = getNumOutputsImpl(obj)
			% Returns the number of '__OutputPort' properties set to true -> max number of outputs returned
			if isempty(obj.NumOutputPorts) || isempty(obj.OutputPortProps)
				mobj = metaclass(obj);
				mprop = mobj.PropertyList;
				propNames = {mprop.Name};
				isOutProp = ~cellfun(@isempty, regexp(propNames, '(\w*)OutputPort\>') );
				obj.OutputPortProps = mprop(isOutProp);
				obj.NumOutputPorts = nnz(isOutProp);
			end
			outPortPropNames = {obj.OutputPortProps(:).Name};
			numOutputs = 0;
			k = 0;
			while (k < numel(outPortPropNames))
				k = k + 1;
				if obj.(outPortPropNames{k})
					numOutputs = numOutputs + 1;
				end
			end
		end
		function streamOut = stepImpl(obj, streamIn)
			
			% FIRE EVENT -> PROCESSING
			notify(obj, 'Processing')
			
			try							
				% ------------------------------
				% PRE-PROCEDURE TASKS
				% ------------------------------								
				% GET NUMBER OF FRAMES IN INPUT
				numFrames = ignition.shared.getNumFrames(streamIn);				
				
				% UPDATE FRAME INPUT COUNTER (PREINCREMENTED)				
				obj.NumFramesInputCount = obj.NumFramesInputCount + numFrames;				
				
				% ------------------------------
				% RUN MAIN PROCEDURE
				% ------------------------------
				startTic = tic;
				streamOut = runMainTask(obj, streamIn);
				addBenchmark(obj.PerformanceMonitorObj, toc(startTic), numFrames);
				
				% ------------------------------
				% POST-PROCEDURE TASKS
				% ------------------------------
				% UPDATE FRAME OUTPUT COUNTER (POSTINCREMENTED)
				obj.NumFramesOutputCount = obj.NumFramesOutputCount + numFrames;
				
			catch me
				handleError(obj, me)
			end
			
			% FIRE EVENT -> READY
			notify(obj, 'Ready')
			
		end
		function resetImpl(obj)
			% resetImpl - Called by reset() only if object is locked, and by setup() after call to
			% setupImpl() method.
			
			% TODO 			notify(obj, 'Reset');
			try
				if obj.UseGpu
					pushGpuPropsBack(obj)
				end
			catch me
				handleError(obj, me)
			end				
			
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end		
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
	
	
	
	
	
	
end































