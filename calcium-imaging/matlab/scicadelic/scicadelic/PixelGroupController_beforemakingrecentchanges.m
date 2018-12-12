classdef (CaseInsensitiveProperties = true) PixelGroupController < scicadelic.SciCaDelicSystem
	% PixelGroupController
	
	
	
	
	
	
	% USER SETTINGS
	properties (Nontunable)		
		MinPersistentSize = 32		
		LayerDiminishCoefficient = .75 %.5
		LabelLockMinCount = 255
		FgMinProbability = .75
		MinExpectedDiameter = 3;
		MaxExpectedDiameter = 10;	
		NumRegionalSamples = 4;
	end
	
	% STATES
	properties (DiscreteState)
	end
	properties (SetAccess = protected, Logical)
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = protected)%, Hidden)		
		PixelLabel
		PixelLayer
		PixelLabelLocked
		LabelIncidence
		InputSize
		RowSubs
		ColSubs
		FrameSubs
		NumPastLabels
		SignificantDifferenceThreshold
		RadiusSample
	end
	properties (SetAccess = protected)
		
	end
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = PixelGroupController(varargin)
			setProperties(obj,nargin,varargin{:});
			obj.CanUseInteractive = true;
		end		
	end
	
	% BASIC INTERNAL SYSTEM METHODS	
	methods (Access = protected)
		function setupImpl(obj, F)			
			
			% INITIALIZE
			fillDefaults(obj)
			checkInput(obj, F);
			obj.TuningImageDataSet = [];
			setPrivateProps(obj)		
			if ~isempty(obj.GpuRetrievedProps)
				pushGpuPropsBack(obj)
			end
			
			% STORE UPDATABLE PIXEL SUBSCRIPTS INTO STACK/CHUNK OF FRAMES
			[numRows, numCols, ~] = size(F);
			numPixels = numRows*numCols;			
			updateFrameChunkSubscripts(obj, F);
			rowSubs = obj.RowSubs;
			colSubs = obj.ColSubs;
			
			
			% INITIAL CALL WITH NO OTHER INPUT
			% 			[pixelLabel, pixelLayer, labelAccumStats, labelSize, pixelLabelLocked, labelIncidence, pixelLabelSteady] = labelPixels(F);
			
			% INITIAL LABEL DESCRIPTOR MATRICES
			obj.PixelLabelLocked = gpuArray.zeros(numRows,numCols,'uint32');
			obj.LabelIncidence = gpuArray.zeros(numPixels,1,'uint16');
			
			% INITIALIZE PIXEL LAYER PARAMETERS
			obj.SignificantDifferenceThreshold = max(fix(min(range(F,1),[],2) / 4), [], 3);
			radiusRange = (ceil(obj.MaxExpectedDiameter/2)+1) .* [1 3];
			numRegionalSamples = obj.NumRegionalSamples;
			maxNumSamples = radiusRange(end)-radiusRange(1)+1;
			if (maxNumSamples) > numRegionalSamples
				obj.RadiusSample = uint16(reshape(linspace(radiusRange(1),...
					radiusRange(end), numRegionalSamples), 1,1,1,numRegionalSamples));				
			else
				obj.RadiusSample = uint16(reshape(radiusRange(1):radiusRange(end), 1,1,1,maxNumSamples));				
			end			
			updatePixelLayer(obj, F);
			
			% INITIALIZE PIXEL LABEL
			[Qcol, Qrow] = meshgrid(colSubs, rowSubs);
			Qpack = bitor(uint32(Qrow(:)) , bitshift(uint32(Qcol(:)), 16));
			pixelLabelInitial = reshape(Qpack, numRows, numCols);
			obj.PixelLabel = pixelLabelInitial;
			
		end
		function [labelGroupSignal, pixelLabel] = stepImpl(obj,F) % [labelGroupSignal, labelGroupIdx] = stepImpl(obj,F)
			
			% UPDATE ROW,COL,FRAME SUBSCRIPTS
			updateFrameChunkSubscripts(obj, F);
			
			% LAYER PROBABILITY MATRIX
			pixelLayerUpdate = updatePixelLayer(obj, F);
			
			% INITIALIZE PIXEL LABELS WITH LOCKED-LABELS & LAYER INFO
			pixelLabelInitial = initializePixelLabel(obj, F, pixelLayerUpdate);
			% 			pixelLabelInitial = initializePixelLabel(obj, pixelLayerUpdate);
			
			% PROPAGATE PIXEL LABEL
			pixelLabel = propagatePixelLabel(obj, pixelLabelInitial, pixelLayerUpdate);
			
			% REFINE PIXEL LABEL
			% 			pixelLabel = refinePixelLabel(obj, pixelLabel, pixelLayerUpdate);
			
			% ACCUMULATE LABEL VALUES -> COUNT, MIN, MAX, & MEAN (19.04)
			[labelGroupSignal, labelGroupSize] = encodePixelGroupOutput(obj, F, pixelLabel);
			% 			[labelGroupSignal, labelGroupIdx, labelGroupSize] = encodePixelGroupOutput(obj, F, pixelLabel);
			
			% UPDATE LABEL INCIDENCE
			obj.LabelIncidence = obj.LabelIncidence + uint16(sum(labelGroupSize>=obj.MinPersistentSize, 2));
			
			
			% TODO: ALLOW MULTIPLE OUTPUT-PORTS (e.g. pixelLayerUpdate, pixelLabelInitial...)
		end
		function resetImpl(obj)
			dStates = obj.getDiscreteState;
			fn = fields(dStates);
			for m = 1:numel(fn)
				dStates.(fn{m}) = 0;
			end
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
	end
	
	% RUN-TIME HELPER FUNCTIONS
	methods (Access = protected, Hidden)
		function updateFrameChunkSubscripts(obj, F)
			
			% UPDATE ROW,COL,FRAME SUBSCRIPTS
			[numRows, numCols, numFrames] = size(F);
			rowSubs = obj.RowSubs;
			colSubs = obj.ColSubs;
			frameSubs = obj.FrameSubs;
			if (numRows~=numel(rowSubs)) || (numCols~=numel(colSubs)) || (numFrames~=numel(frameSubs))
				rowSubs = gpuArray.colon(1,numRows)';
				colSubs = gpuArray.colon(1,numCols);
				frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
				obj.RowSubs = rowSubs;
				obj.ColSubs = colSubs;
				obj.FrameSubs = frameSubs;
			end
			
			obj.InputSize = [numRows, numCols, numFrames]; % TODO: unnecessary?
			
		end
		function varargout = updatePixelLayer(obj, F)
			
			
			% CALL EXTERNAL FUNCTION TO EXECUTE GPU KERNEL
			pixelLayerUpdate = samplePixelRegionRunGpuKernel(F,...
				obj.SignificantDifferenceThreshold, obj.RadiusSample,false,...
				obj.RowSubs, obj.ColSubs, obj.FrameSubs);
			
			% INTEGRATE UPDATE WITH TEMPORALLY-STABLE PIXEL LAYER (TODO)
			pixelLayer = obj.PixelLayer;
			if ~isempty(pixelLayer)
				pixelLayerUpdate = bsxfun(@plus, pixelLayer, pixelLayerUpdate)./2;
				pixelLayerSign = sign(pixelLayerUpdate);
				pixelLayerUpdate = bsxfun(@max,...
					abs(pixelLayer)*obj.LayerDiminishCoefficient,...
					abs(pixelLayerUpdate))...
					.* single(pixelLayerSign);%TODO: find good coefficient
			end
			
			% UPDATE STABLE LAYER
			obj.PixelLayer = mean(pixelLayerUpdate,3); %TODO: ?
			% 			obj.PixelLayer = max(pixelLayerUpdate, [], 3);
			
			% OUTPUT
			if nargout
				varargout{1} = pixelLayerUpdate;
			end
			
		end
		function varargout = initializePixelLabel(obj, F, pixelLayerUpdate)
			
			% CALL EXTERNAL FUNCTION TO EXECUTE GPU KERNEL
			lastLabel = obj.PixelLabel;
			[pixelLabelInitial, pixelLabelLocked] = initializePixelLabelRunGpuKernel(F,...
				pixelLayerUpdate, lastLabel, obj.LabelIncidence,...
				obj.PixelLabelLocked, obj.RowSubs, obj.ColSubs);
			
			% UPDATE TEMPORALLY-STABLE PIXEL LABEL
			obj.PixelLabelLocked = pixelLabelLocked;
			
			
			% OUTPUT
			if nargout
				varargout{1} = pixelLabelInitial;
			end
			
		end
		function varargout = propagatePixelLabel(obj, pixelLabelInitial, pixelLayerUpdate)
			
			% 			[pixelLabel, pixelLabelSteady] = propagatePixelLabelRunGpuKernel(...
			pixelLabel = propagatePixelLabelRunGpuKernel(...
				pixelLabelInitial, pixelLayerUpdate, obj.RowSubs, obj.ColSubs, obj.FrameSubs);
			obj.PixelLabel = pixelLabel;
			% 			obj.PixelLabelSteady = pixelLabelSteady;
			
			% OUTPUT
			if nargout
				varargout{1} = pixelLabel;
			end
			
		end
		function [labelGroupSignal, varargout] = encodePixelGroupOutput(obj, F, pixelLabel)
			% 			[labelGroupSignal, labelGroupIdx, varargout] = encodePixelGroupOutput(obj, F, pixelLabel)
			
			[numRows, numCols, numFrames] = size(F);
			numPixels = numRows*numCols;
			
			labelMask = logical(pixelLabel);
			frameInChunk = bsxfun(@times, uint16(labelMask), obj.FrameSubs);
			labelRow = bitand( pixelLabel , uint32(65535));
			labelCol = bitand( bitshift(pixelLabel, -16), uint32(65535));
			labelIdx = labelRow(:) + numRows*(labelCol(:)-1);
			
			labelSize = accumarray([labelIdx(labelMask) , frameInChunk(labelMask)],...
				1, [numPixels, numFrames], @sum, 0, false);
			labelSum = accumarray([labelIdx(labelMask) , frameInChunk(labelMask)],...
				single(F(labelMask)), [numPixels, numFrames], @sum, single(0), false);
			labelMax = accumarray([labelIdx(labelMask) , frameInChunk(labelMask)],...
				single(F(labelMask)), [numPixels, numFrames], @max, single(0), false);
			labelMin = accumarray([labelIdx(labelMask) , frameInChunk(labelMask)],...
				single(F(labelMask)), [numPixels, numFrames], @min, single(0), false);
			
			labelMaskConfirmed = (labelSum>0); %??
			
			[lsRow, lsCol] = find(labelMaskConfirmed);
			groupSignalMix = [...
				uint16(labelSize(labelMaskConfirmed)) ,...
				uint16(labelSum(labelMaskConfirmed)./labelSize(labelMaskConfirmed)) ,...
				uint16(labelMax(labelMaskConfirmed)) ,...
				uint16(labelMin(labelMaskConfirmed)) ]';
			groupSignalMixTypeCasted = typecast(groupSignalMix(:), 'double');
			
			labelGroupSignal = accumarray([lsRow, lsCol], groupSignalMixTypeCasted, [numPixels, numFrames], [],  0, true);
			% 			labelGroupIdx = labelIdx(labelMaskConfirmed);
			% 			szL = uint16(labelSize);
			
			if nargout > 1 % 2
				varargout{1} = uint16(labelSize);
			end
			
		end
	end
	
% TUNING
methods (Hidden)
		function tuneInteractive(~)
		end			
		function tuneAutomated(~)
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

















% 
% 
% 
% 
% [numRows, numCols, numFrames] = size(F);
% numPixels = numRows*numCols;
% obj.InputSize = [numRows, numCols, numFrames];
% rowSubs = gpuArray.colon(1,numRows)';
% colSubs = gpuArray.colon(1,numCols);
% frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
% obj.RowSubs = rowSubs;
% obj.ColSubs = colSubs;
% obj.FrameSubs = frameSubs;