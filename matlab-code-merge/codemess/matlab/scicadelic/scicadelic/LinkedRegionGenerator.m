classdef (CaseInsensitiveProperties = true) LinkedRegionGenerator < scicadelic.SciCaDelicSystem
	
	
	
	% USER SETTINGS
	properties (Nontunable, PositiveInteger)
		MinRoiPixArea = 25;								% previously 50
		MaxRoiPixArea = 2500;							% previously 350, then 650, then 250
	end
	
	% STATES
	properties (SetAccess = protected, Logical)
		OutputAvailable = false
	end
	properties (DiscreteState)
		CurrentFrameIdx
	end
	
	% OUTPUTS
	properties (SetAccess = protected)
		ProvisionalRegion
		ConfirmedRegion
		LastLabelMatrix
	end
	properties (Nontunable, Logical)
		ProvisionalRegionOutputPort = false;
		ConfirmedRegionOutputPort = false;
	end
	
	% INTERNAL SETTINGS
	properties (SetAccess = protected, Hidden)
		RegionStats
	end
	
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden)
		pMinRoiPixArea
		pMaxRoiPixArea
	end
	
	
	
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = LinkedRegionGenerator(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));
			setPrivateProps(obj);
			obj.RegionStats = LinkedRegion.regionStats.essential;
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj, data)
			
			% CHECK INPUT
			checkInput(obj, data);
			fillDefaults(obj)
			
			obj.CurrentFrameIdx = 0;
			setPrivateProps(obj)
			
		end
		function varargout = stepImpl(obj, data)
			
			% LOCAL VARIABLES
			n = obj.CurrentFrameIdx;
			inputNumFrames = size(data,3);
			
			% CELL-SEGMENTAION PROCESSING ON GPU
			% 			data = onGpu(obj, data);
			processData(obj, data);
			
			% UPDATE NUMBER OF FRAMES
			obj.CurrentFrameIdx = n + inputNumFrames;
			
			if nargout
				varargout{1} = obj.ProvisionalRegion;
			end
		end
		function numOutputs = getNumOutputsImpl(obj)
			numOutputs = nnz([...
				obj.ProvisionalRegionOutputPort]);
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
		function resetImpl(obj)
			obj.CurrentFrameIdx = 0;
			setPrivateProps(obj)
		end
	end
	
	% RUN-TIME HELPER METHODS
	methods %(Access = protected)
		function varargout = processData(obj, labelMatrix)
			
			% APPLY INITIAL CRITERIA
			labelMatrix = applyInitialConstraints(obj, labelMatrix);
			
			
			
			
			% GENERATE REGION STATISTICS AND LINK REGIONS
			rcell = generateLinkedRegions(obj, labelMatrix);
			
			% USE CLASS METHOD TO FIND OVERLAPPING ARRAYS
			for k=1:numel(rcell)-1
				ovmap(k) = mapOverlap(rcell{k}, rcell{k+1});
			end
			
			% PROCESS OUTPUT
			if nargout
				lrObj = obj.ProvisionalRegion(end,:);
				varargout{1} = lrObj.createLabelMatrix;
			end
		end
		function labelMatrix = applyInitialConstraints(obj, labelMatrix)
		
			% LOCAL VARIABLES
			minArea = obj.pMinRoiPixArea;
			maxArea = obj.pMaxRoiPixArea;
			
			% ENSURE UNIQUE LABELS FOR MULTI-FRAME (BATCH) INPUT
			uLabMat = uniquifyLabels(obj, labelMatrix);
			uLabArea = accumarray(nonzeros(uLabMat), 1);	
			
			
			
		end
		function uLabMat = uniquifyLabels(~, labelMatrix)
			if size(labelMatrix,3) > 1
				labelFrameMax = max(max(labelMatrix));
				uLabMat = (bsxfun(@plus, labelMatrix, cat(3, 0, labelFrameMax(1,1,1:end-1))));
				uLabMat(~logical(labelMatrix)) = 0;
			else
				uLabMat = labelMatrix;
			end
			
		end
		function ovmap = linkLabelMatrices(obj, idxMat)
			r1IdxMat = obj.LastLabelMatrix;
			r2IdxMat = idxMat;
			
			r1Idx = [min(r1IdxMat(:)):max(r1IdxMat(:))]';
			r2Idx = [min(r2IdxMat(:)):max(r2IdxMat(:))]';
			r1Area = accumarray(nonzeros(r1IdxMat), 1);
			r2Area = accumarray(nonzeros(r2IdxMat), 1);
			
			pxOverlap = logical(r1IdxMat) & logical(r2IdxMat);
			idx2idxMap = [r1IdxMat(pxOverlap) , r2IdxMat(pxOverlap)]; % could distribute here along 2nd dim
			uniqueIdxPairMap = unique(idx2idxMap, 'rows');
			
			% COUNT & SORT BY RELATIVE AREA OF OVERLAP
			overlapCount = zeros(size(uniqueIdxPairMap)); % overlapCount = zeros(size(uniqueIdxPairMap), 'single');
			for k=1:size(idx2idxMap,2)
				pxovc = accumarray(idx2idxMap(:,k),1); % pxovc = accumarray(idx2idxMap(:,k),single(1));
				overlapCount(:,k) = pxovc(uniqueIdxPairMap(:,k));
			end
			pxOverlapCount = min(overlapCount,[],2);
			
			uidxOrderedArea = [r1Area(uniqueIdxPairMap(:,1)) , r2Area(uniqueIdxPairMap(:,2))];
			fractionalOverlapArea = bsxfun(@rdivide, pxOverlapCount, uidxOrderedArea);
			[~, fracOvSortIdx] = sort(prod(fractionalOverlapArea,2), 1, 'descend');
			idx = uniqueIdxPairMap(fracOvSortIdx,:);
			
			% ALSO RETURN UNMAPPED REGIONS
			mappedR1 = false(size(r1Idx));
			mappedR2 = false(size(r2Idx));
			mappedR1(idx(:,1)) = true;
			mappedR2(idx(:,2)) = true;
			unMappedLabels = {r1Idx(~mappedR1), r2Idx(~mappedR2)};
			
			% OUTPUT IN STRUCTURE
			% ovmap.uid = uniqueUidPairMap(fracOvSortIdx,:);
			ovmap.idx = idx;
			ovmap.area = uidxOrderedArea(fracOvSortIdx,:);
			ovmap.fracovarea = fractionalOverlapArea(fracOvSortIdx,:);
			ovmap.mapped = [r1Idx(idx(:,1)) , r2Idx(idx(:,2))];
			ovmap.unmapped = unMappedLabels;
			ovmap.overlap = pxOverlap;
		end
		function rcell = generateLinkedRegions(obj, labelMatrix)
			
			% LOCAL VARIABLES CPU/MAIN-MEMORY
			lm = onCpu(obj, labelMatrix);
			[nRows,nCols,N] = size(lm);
			stats = obj.RegionStats;
			frameIdx = obj.CurrentFrameIdx;
			frameSize = [nRows, nCols];
			
			for k=1:N
				rp = regionprops(lm(:,:,k), stats);
				rcell{k} = LinkedRegion(rp, 'FrameIdx', frameIdx+k, 'FrameSize', frameSize);
			end
			
		end
		
	end
	
	% INITIALIZATION
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
	
	% TUNING
	methods (Hidden)
		function tuneInteractive(obj)
			% TODO
			
			setPrivateProps(obj)
			
			% SET UP TUNING WINDOW
			createTuningFigure(obj);			%TODO: can also use for automated tuning?
			
		end
		function tuneAutomated(obj)
			% TODO
			obj.TuningImageDataSet = [];
		end
	end
	
	
	
	
	
	
end



























