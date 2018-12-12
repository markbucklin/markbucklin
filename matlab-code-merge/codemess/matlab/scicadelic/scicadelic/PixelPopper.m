classdef (CaseInsensitiveProperties = true) PixelPopper < scicadelic.SciCaDelicSystem
	% PixelPopper
	%
	% INPUT:
	%
	% OUTPUT:
	%	Array of objects of the 'RegionOfInterest' class, resembling a RegionProps structure (Former
	%	Output) Returns structure array, same size as vid, with fields
	%			bwvid =
	%				RegionProps: [12x1 struct] bwMask: [1024x1024 logical]
	%
	% INTERACTIVE NOTE: todo:
	%	
	%
	% See also: BWMORPH GPUARRAY/BWMORPH
	
	
	
	% USER SETTINGS
	properties (Access = public, Nontunable)
		MinExpectedDiameter = 3;
		MaxExpectedDiameter = 10;					% Determines search space for determining foreground & activity	
	end
	properties (Access = public, Logical, Nontunable)
		RandomizeSurroundSelection = false
	end
	
	% STATES
	properties (DiscreteState)
		CurrentFrameIdx		
	end
	
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden, Nontunable)
		pMinExpectedDiameter
		pMaxExpectedDiameter
		pRandomizeSurroundSelection
	end
	
	
	
	
	
	

	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = PixelPopper(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));			
			obj.CanUseInteractive = true;
			setPrivateProps(obj);
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj, data)
			fprintf('PixelPopper -> SETUP\n')
			
			% INITIALIZE
			fillDefaults(obj)			
			checkInput(obj, data);
			obj.TuningImageDataSet = [];			
			obj.CurrentFrameIdx = 0;
			setPrivateProps(obj)
						
			% OUTPUT DATA-TYPE (TODO: DONE ELSEWHERE?)
			% 			bwF = findCellSizeDominantPixels(obj, data, obj.MaxExpectedDiameter);
			% 			obj.OutputDataType = getClass(obj, bwF);
			
		end
		function output = stepImpl(obj, data)
			
			% LOCAL VARIABLES
			n = obj.CurrentFrameIdx;
			inputNumFrames = size(data,3);
						
			% CELL-SEGMENTAION PROCESSING ON GPU
			data = onGpu(obj, data);
			output = processData(obj, data);
						
			% UPDATE NUMBER OF FRAMES
			obj.CurrentFrameIdx = n + inputNumFrames;
			
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
	end
	
	% RUN-TIME HELPER METHODS
	methods (Access = protected)
		function bwF = processData(obj, F, maxExpectedDiameter)
			% Returns potential foreground pixels as logical array
			
			% RUN AN EFFICIENT NEIGHBORHOOD-SURROUND COMPARISON ALGORITHM TO IDENTIFY PLATEAUS								
			if nargin < 3
				maxExpectedDiameter = obj.pMaxExpectedDiameter;				
			end
			
			% EACH PIXEL WILL SAMPLE SURROUD AT DISTANCE MAX-EXPECTED DIAMETER AND SMALLER POWERS-OF-2
			if maxExpectedDiameter > 8
				dsVec = [2.^(2:nextpow2(maxExpectedDiameter)-1), maxExpectedDiameter];
			else
				dsVec = maxExpectedDiameter;
			end			
			
			% CALL EXTERNAL FUNCTION ==> NEAR-NEIGHBOR-DOMINANCE-[ELEMENTWISE/ARRAYWISE]
			if isa(F, 'gpuArray')
				% ELEMENTWISE (using arrayfun()) ON GPU
				bwF = runElementWiseSubFcn();
				
			else
				% ARRAYWISE/VECTORIZED (using bsxfun()) ON CPU OR GPU
				bwF = runArrayWiseSubFcn();
			end
			
			function bwF = runElementWiseSubFcn()
				bwF = false(size(F), class(F));
				[nRows,nCols,~] = size(F);
				
				% IMMEDIATE NEIGHBORS: SINGLE-PIXEL-SHIFTED ARRAYS (4-CONNECTED)
				Fu = F([1, 1:nRows-1], :, :);
				Fd = F([2:nRows, nRows], :,:);
				Fl = F(:, [1, 1:nCols-1],:);
				Fr = F(:, [2:nCols, nCols], :);
				
				% SPACED SURROUNDING PIXELS: MULTI-PIXEL-SHIFTED ARRAYS
				if obj.pRandomizeSurroundSelection
					
					% GENERATE RANDOM NUMBERS FOR SURROUND RANDOMIZATION
					dsRand = round(bsxfun(@minus, bsxfun(@times, dsVec./2,...
						rand(4,length(dsVec),'like',dsVec)), dsVec./4));
					for k=1:length(dsVec)
						ds = max(2, dsVec(k) + dsRand(:,k));
						Su = F([ones(1,ds(1)), colon(1,nRows-ds(1))], :, :);
						Sd = F([colon(ds(2)+1,nRows), nRows.*ones(1,ds(2))], :, :);
						Sl = F(:, [ones(1,ds(3)), colon(1,nCols-ds(3))], :);
						Sr = F(:, [colon(ds(4)+1,nCols), nCols.*ones(1,ds(4))], :);
						bwF = bwF | arrayfun(@nearNeighborDominanceElementWise, F, Fu, Fr, Fd, Fl, Su, Sr, Sd, Sl);
					end
				else
					% OR DON'T RANDOMIZE SURROUND
					for k=1:length(dsVec)
						ds = dsVec(k);
						Su = F([ones(1,ds), 1:nRows-ds], :, :);
						Sd = F([ds+1:nRows, nRows.*ones(1,ds)], :, :);
						Sl = F(:, [ones(1,ds), 1:nCols-ds], :);
						Sr = F(:, [ds+1:nCols, nCols.*ones(1,ds)], :);
						bwF = bwF | arrayfun(@nearNeighborDominanceElementWise, F, Fu, Fr, Fd, Fl, Su, Sr, Sd, Sl);
					end
				end
			end
			function bwF = runArrayWiseSubFcn()
				bwF = false(size(F), class(F));%TODO use SPMD if no graphics card
				for k=1:length(dsVec)
					bwF = bwF | nearNeighborDominanceArrayWise(F,dsVec(k));
				end
			end
		end		
	end
	
	% TUNING
	methods (Hidden)
		function tuneInteractive(obj)
			% TODO
			
			% STEP 1: EXPECTED CELL DIAMETER (in pixels) -> findCellSizeDominantPixels
			kstep = 1;
			obj.TuningStep(1).ParameterName = 'MaxExpectedDiameter';
			x = obj.MaxExpectedDiameter;
			if isempty(x)
				x = round(max(obj.FrameSize)/20);
			end
			obj.TuningStep(kstep).ParameterDomain = [1:x, x+1:10*x];
			obj.TuningStep(kstep).ParameterIdx = ceil(x);
			obj.TuningStep(kstep).Function = @processData;
			obj.TuningStep(kstep).CompleteStep = true;
			
			% SET UP TUNING WINDOW
			setPrivateProps(obj)
			createTuningFigure(obj);			%TODO: can also use for automated tuning?
			
		end
		function tuneAutomated(obj)
			% TODO
			obj.TuningImageDataSet = [];
		end		
	end
	
	% INITIALIZATION HELPER METHODS	
	methods (Access = protected, Hidden)
		function setPrivateProps(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			for k=1:numel(oProps)
				prop = oProps(k);
				if prop.Name(1) == 'p'
					pname = prop.Name(2:end);
					try
						pval = obj.(pname);
						obj.(prop.Name) = pval;
					catch me
						getReport(me)
					end
				end
			end
		end
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
	end
	
	
	
end




















