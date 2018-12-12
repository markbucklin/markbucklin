classdef  (CaseInsensitiveProperties = true) BackgroundRemover ...
		<  scicadelic.SciCaDelicSystem
	% BackgroundRemover
	
	
	
	
	
	properties (Nontunable)
		PreSubtractionOffset = 128
		BackgroundSource = 'Min'
		BackgroundFrameSpan = inf
	end
	properties (DiscreteState)
		CurrentFrameIdx
		CurrentNumBufferedFrames
	end
	properties (SetAccess = protected)
		Background
	end
	properties (SetAccess = protected, Logical)
		BackgroundLocked
	end
	properties (SetAccess = protected, Hidden)
		BackgroundSourceSet = matlab.system.StringSet({'Min','Avg','Median','Prctile'})
		BufferedFrames
		BufferIdx
		BackgroundFcn
	end
	
	
	
	
	
	
	
	
	% ------------------------------------------------------------------------------------------
	% CONSTRUCTOR
	% ------------------------------------------------------------------------------------------
	methods
		function obj = BackgroundRemover(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));
		end
	end
	% ------------------------------------------------------------------------------------------
	% INITIALIZATION HELPER FUNCTIONS
	% ------------------------------------------------------------------------------------------
	methods
		
	end
	
	% ------------------------------------------------------------------------------------------
	% BASIC INTERNAL SYSTEM METHODS
	% ------------------------------------------------------------------------------------------
	methods (Access = protected)
		function setupImpl(obj, data)
			% INITIALIZATION
			obj.FrameSize = [size(data,1), size(data,2)];
			if isa(data, 'gpuArray')
				obj.InputDataType = classUnderlying(data);
			else
				obj.InputDataType = class(data);
			end
			if isempty(obj.OutputDataType)
				obj.OutputDataType = obj.InputDataType;
			end
			if isempty(obj.BackgroundFrameSpan)
				obj.BackgroundFrameSpan = inf;
			end
			if ~isinf(obj.BackgroundFrameSpan)
				if obj.UseGpu
					obj.BufferedFrames = gpuArray.zeros([obj.FrameSize obj.BackgroundFrameSpan],'like',data);
				else
					obj.BufferedFrames = zeros([obj.FrameSize obj.BackgroundFrameSpan],'like',data);
				end
			end
			obj.CurrentNumBufferedFrames = 0;
			obj.BufferIdx = 0;
			obj.CurrentFrameIdx = 0;
			obj.BackgroundLocked = false;
			obj.Background = data;
			% 			if obj.UseGpu
			% 				obj.Background = data;%gpuArray.zeros(obj.FrameSize, obj.InputDataType);
			% 			else
			% 				obj.Background = data%zeros(obj.FrameSize, obj.InputDataType);
			% 			end
			% CONSTRUCT BACKGROUND-GENERATING FUNCTION
			if isinf(obj.BackgroundFrameSpan)
				switch getIndex(obj.BackgroundSourceSet, obj.BackgroundSource) % UPDATE FUNCTION
					case 1 % Min
						fcn = @(bgNew,bgOld) min(bgNew, bgOld);
					case 2 % Avg
						% 						fcn = @(bgNew,bgOld) bgNew, bgOld);
					case 3 % Median
						
					case 4 % Prctile
						
				end
			else
				switch getIndex(obj.BackgroundSourceSet) % CALCULATE FROM BUFFER FUNCTION
					case 1 % Min
						fcn = @(bgBuf) min(bgBuf,[],3);
					case 2 % Avg
						fcn = @(bgBuf) mean(bgBuf,3,'native');
					case 3 % Median
						
					case 4 % Prctile
						
				end
				
			end
			obj.BackgroundFcn = fcn;
		end
		function data = stepImpl(obj,data)
			obj.CurrentFrameIdx = obj.CurrentFrameIdx + 1;
			if ~obj.BackgroundLocked
				bg = cast(updateBackground(obj, data), 'like', data);
			else
				bg = cast(obj.Background, 'like', data);
			end
			offset = obj.PreSubtractionOffset;
			data = bsxfun(@minus, bsxfun(@max, data, bg-offset)+offset, bg);
		end
		function bg = updateBackground(obj, data)
			k = size(data,3);
			currentIdx = obj.CurrentFrameIdx + 0:(k-1);
			if currentIdx <= 1
				obj.Background = data;
				obj.CurrentNumBufferedFrames = 1;
			else
				bgFcn = obj.BackgroundFcn;
				nbf = obj.CurrentNumBufferedFrames;
				if (nbf <1) % FIRST FRAME TO NASCENT SYSTEM
					bg = data;
				else % TEMPORAL SMOOTHING OF BACKGROUND
					bg = obj.Background;
					if isinf(obj.BackgroundFrameSpan)
						bg = bsxfun(bgFcn, data, bg);
					else
						idx = rem(currentIdx-1, obj.BackgroundFrameSpan);
						obj.BufferedFrames(:,:,idx) = data;
						obj.BufferIdx = idx(end);
						bg = bgFcn(obj.BufferedFrames);
					end
				end
				obj.CurrentNumBufferedFrames = min(nbf + 1, obj.BackgroundFrameSpan);
			end
		end
		function resetImpl(obj)
			preBufferedFrames = obj.CurrentNumBufferedFrames;
			% INITIALIZE/RESET ALL DESCRETE-STATE PROPERTIES
			dStates = obj.getDiscreteState;
			fn = fields(dStates);
			for m = 1:numel(fn)
				dStates.(fn{m}) = [];
			end
			if ~isempty(preBufferedFrames)
				obj.CurrentNumBufferedFrames = min(preBufferedFrames, obj.BackgroundFrameSpan);
			end
		end
		function releaseImpl(obj)
			obj.BackgroundLocked = false;
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
	
	% ------------------------------------------------------------------------------------------
	% RUN-TIME HELPER FUNCTIONS
	% ------------------------------------------------------------------------------------------
	methods (Access = protected)
	end
	methods
		function lockBackground(obj)
			obj.BackgroundLocked = true;
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end