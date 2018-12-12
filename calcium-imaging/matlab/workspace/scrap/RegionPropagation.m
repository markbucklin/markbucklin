classdef RegionPropagation  <  ImageRegion  &  matlab.mixin.Copyable
	
	
	
	
	

	% ARRAY OF LINKED-REGIONS
	properties (SetAccess = protected)
		LinkedRegions
	end
	
	% UNIQUE IDENTIFIER & UID LINKS
	properties (SetAccess = protected, Hidden)
		UID @uint32 scalar		
	end
	
	
	
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = RegionPropagation(RP, varargin)
warning('RegionPropagation.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
			persistent uid
			
			% PROCESS INPUT FOR ALL REGIONS
			if nargin > 1
				args = varargin(:);
			elseif nargin == 1
				args = [];
			else
				return
			end
			
			% REPMAT FOR STRUCT ARRAY DEFINING MULTIPLE LINKED REGIONS
			obj = repmat(obj, size(RP,1), size(RP,2));
			
			% COPY VALUES FROM REGION-PROPS STRUCTURE
			statFields = fields(RP);
			for k=1:numel(statFields)
				statName = statFields{k};
				statVal = {RP.(statName)};
				propClass = class(obj(1).(statName));
				if (isnumeric(statVal{1})) && (~isa(statVal{1}, propClass))
					statVal = cellfun(@(x) {cast(x,propClass)}, statVal);
				end
				[obj.(statName)] = deal(statVal{:});
			end
			
			% ASSIGN "PROP-VAL" COMMA-SEPARATED INPUT ARGUMENTS
			if (~isempty(args)) && (numel(args) >=2)
				for k = 1:2:length(args)
					try
						propName = args{k};
						propVal = args{k+1};
						propClass = class(obj(1).(propName));
						if (isnumeric(propVal)) && (~isa(propVal, propClass))
							propVal = cast(propVal, propClass);
						end
						[obj.(propName)] = deal(propVal);
					catch me
						showError(me)
					end
				end
			end
			
			% ASSIGN UNIQUE-IDENTIFICATION-NUMBER -> IMMUTABLE?
			if isempty(obj(1).UID)
				if isempty(uid)
					uid = 0;
				end
				N = numel(obj);
				for k=1:N
					obj(k).UID = uid+k;
				end
				uid = uid + N;
			end
		end
	end
	
	% DISPLAY METHODS
	methods
		function mask = createMask(obj, imSize) % 2ms
			% Will return BINARY IMAGE from a single ROI or Array of ROI objects
			pxIdx = cat(1,obj.PixelIdxList);
			% 			bBox = cat(1, obj.BoundingBox); % TODO: can use max (min(bbox)+max(subarray),
			% 			max(bbox)+min(subarrayidx))
			if nargin < 2
				imSize = 2^nextpow2(sqrt(double(max(pxIdx(:)))));%TODO: can improve this using centroid and boundingbox max or subscripts
			end
			mask = false(imSize);
			mask(pxIdx) = true;
		end
		function [labelMatrix, varargout] = createLabelMatrix(obj, imSize) % 3ms
			% Will return INTEGER LABELED IMAGE from a single ROI or Array of ROI objects with labels
			% assigned based on the order in which RegionPropagation objects are passed in (by index). A second
			% output can be specified, providing a second label matrix where the labels assigned are the
			% unique ID number for each respective object passed as input.
			
			% WILL ALLOCATE IMAGE WITH MOST EFFICIENT DATA-TYPE POSSIBLE
			N = numel(obj);
			if N <= intmax('uint8')
				outClass = 'uint8';
			elseif N <= intmax('uint16')
				outClass = 'uint16';
			elseif N <= intmax('uint32')
				outClass = 'uint32';
			else
				outClass = 'double';
			end
			
			% CONSTRUCT INDICES FOR EFFICIENT LABEL ASSIGMENT
			pxIdx = cat(1, obj.PixelIdxList);
			lastIdx = cumsum(cat(1, obj.Area));
			roiIdxPxLabel = zeros(size(pxIdx), outClass);
			roiIdxPxLabel(lastIdx(1:end-1)+1) = 1;
			roiIdxPxLabel = cumsum(roiIdxPxLabel) + 1;
			
			% ASSIGN LABELS IN THE ORDER OBJECTS WERE PASSED TO THE FUNCTION
			if nargin < 2
				imSize = 2^nextpow2(sqrt(double(max(pxIdx(:)))));
			end
			labelMatrix = zeros(imSize, outClass);
			labelMatrix(pxIdx) = roiIdxPxLabel;
			
			if nargout > 1
				roiUid = cat(1, obj.UID);
				roiUidPxLabel = roiUid(roiIdxPxLabel);
				uidLabelMatrix = zeros(imSize, 'like', roiUid);
				uidLabelMatrix(pxIdx) = roiUidPxLabel;
				varargout{1} = uidLabelMatrix;
			end
		end
	end
	
	% LINKING METHODS
	methods
		function ovmap = mapOverlap(obj, varargin) % 50ms
			if nargin > 1
				r1 = obj;
				r2 = varargin{1};
				% CONSTRUCT MAP BETWEEN ALL OVERLAPPING UIDS
				[r1IdxMat, r1UidMat] = r1.createLabelMatrix;
				[r2IdxMat, r2UidMat] = r2.createLabelMatrix;
				pxOverlap = logical(r1IdxMat) & logical(r2IdxMat);
				uid2uidMap = [r1UidMat(pxOverlap) , r2UidMat(pxOverlap)];
				idx2idxMap = [r1IdxMat(pxOverlap) , r2IdxMat(pxOverlap)];
				[uniqueUidPairMap, uIdx, ~] = unique(uid2uidMap, 'rows');
				uniqueIdxPairMap = idx2idxMap(uIdx,:);
				
				% COUNT & SORT BY RELATIVE AREA OF OVERLAP
				pxOverlapCount = sum( all( bsxfun(@eq,...
					reshape(uid2uidMap, size(uid2uidMap,1), 1, size(uid2uidMap,2)),...
					shiftdim(uniqueUidPairMap, -1)), 3), 1)';
				uidxOrderedArea = [cat(1,r1(uniqueIdxPairMap(:,1)).Area) ,...
					cat(1,r2(uniqueIdxPairMap(:,2)).Area)];
				fractionalOverlapArea = bsxfun(@rdivide, pxOverlapCount, uidxOrderedArea);
				[~, fracOvSortIdx] = sort(prod(fractionalOverlapArea,2), 1, 'descend');
				idx = uniqueIdxPairMap(fracOvSortIdx,:);
				
				% ALSO RETURN UNMAPPED REGIONS
				mappedR1 = false(numel(r1),1);
				mappedR2 = false(numel(r2),1);
				mappedR1(idx(:,1)) = true;
				mappedR2(idx(:,2)) = true;
				unMappedRegion = {r1(~mappedR1), r2(~mappedR2)};
				
				% OUTPUT IN STRUCTURE
				ovmap.uid = uniqueUidPairMap(fracOvSortIdx,:);
				ovmap.idx = idx;
				ovmap.area = uidxOrderedArea(fracOvSortIdx,:);
				ovmap.fracovarea = fractionalOverlapArea(fracOvSortIdx,:);
				ovmap.region = [r1(idx(:,1)) , r2(idx(:,2))];
				ovmap.unmapped = unMappedRegion;
				
			else
				
				% CONSTRUCT MAP BETWEEN ALL OVERLAPPING UIDS
				frameIdx = cat(1,obj.FrameIdx);
				frameIdx = frameIdx - min(frameIdx) + 1;
				N = max(frameIdx);
				rcell = cell(1,N);
				for k = 1:N
					r = obj([frameIdx == k]);
					rcell{k} = r;
					[idxMat(:,:,k), uidMat(:,:,k)] = r.createLabelMatrix;
				end
				pxOverlap = all( logical(idxMat), 3);
				numPixOverlap = nnz(pxOverlap);
				uid2uidMap = reshape(uidMat(repmat(pxOverlap, 1,1,N)), numPixOverlap, N);
				idx2idxMap = reshape(idxMat(repmat(pxOverlap, 1,1,N)), numPixOverlap, N);
				[uniqueUidPairMap, uIdx, ~] = unique(uid2uidMap, 'rows');
				uniqueIdxPairMap = idx2idxMap(uIdx,:);
				
				% COUNT & SORT BY RELATIVE AREA OF OVERLAP
				uidxOrderedArea = zeros(size(uniqueIdxPairMap), 'single');
				numMatches = size(uniqueIdxPairMap,1);
				overlapCount = zeros(size(uniqueIdxPairMap), 'uint16');
				for k=1:N
					r = rcell{k};
					pxovc = accumarray(idx2idxMap(:,k),1);
					overlapCount(:,k) = pxovc(uniqueIdxPairMap(:,k));
					isMapped = false(numel(r),1);
					isMapped(uniqueIdxPairMap(:,k)) = true;
					rMapped(1:numMatches,k) = r(uniqueIdxPairMap(:,k));
					unMappedRegion{k} = r(~isMapped);
					uidxOrderedArea(:,k) = cat(1, rMapped(:,k).Area);
				end
				pxOverlapCount = min(overlapCount,[],2);
				% 				pxOverlapCount = pxovc(uniqueIdxPairMap(:,k));
				fractionalOverlapArea = bsxfun(@rdivide, pxOverlapCount, uidxOrderedArea);
				[ ~ , fracOvSortIdx] = sort(sum(fractionalOverlapArea,2), 1, 'descend');% SUM RATHER THAN PRODUCT
				idx = uniqueIdxPairMap(fracOvSortIdx,:);
				
				% OUTPUT IN STRUCTURE
				ovmap.uid = uniqueUidPairMap(fracOvSortIdx,:);
				ovmap.idx = idx;
				ovmap.area = uidxOrderedArea(fracOvSortIdx,:);
				ovmap.fracovarea = fractionalOverlapArea(fracOvSortIdx,:);
				ovmap.region = rMapped;
				ovmap.unmapped = unMappedRegion;
				
			end
		end
		function obj = linkToNext(obj, roi)
			obj.NextRegion = cat(1,obj.NextRegion(:), roi(:));
			for k=1:numel(roi)
				roi(k).PrecedingRegion = cat(1, roi(k).PrecedingRegion, obj);
			end
			
			% 			nObj = numel(obj); nRoi = numel(roi); for kObj = 1:nObj
			% 				R1 = obj(kObj); R1.NextRegion = roi; for kRoi = kObj:nRoi
			% 					R2 = roi(kRoi);
			%
			% 				end
			% 			end
			%
		end
		function R = getChainForward(obj)
			R = {};
			for n=1:numel(obj)
				r = obj(n);
				if isempty(r(end).NextRegion)
					continue
				else
					while ~isempty(r(end).NextRegion)
						if numel(r(end).NextRegion) == 1
							r = cat(1, r, r(end).NextRegion);
						else
							r = cat(1, r, r(end).NextRegion(1));
						end
					end
				end
				R{n} = r;
			end
		end
	end
	
	
	% STATIC HELPER METHODS
	methods (Static)
		function validStats = regionStats()
			
			validStats.basic = {
				'Area'
				'BoundingBox'
				'Centroid'};
			
			validStats.essential = {
				'Area'
				'BoundingBox'
				'Centroid'
				'PixelIdxList'};
			
			validStats.shape = {
				'Area'
				'BoundingBox'
				'Centroid'
				'SubarrayIdx'
				'MajorAxisLength'
				'MinorAxisLength'
				'Eccentricity'
				'Orientation'
				'Image'
				'Extrema'
				'EquivDiameter'
				'Extent'
				'PixelIdxList'
				'PixelList'};
			
			validStats.pixel = {
				'PixelValues'
				'WeightedCentroid'
				'MeanIntensity'
				'MinIntensity'
				'MaxIntensity'};
			
			validStats.faster = {
				'Area'
				'BoundingBox'
				'Centroid'
				'PixelValues'
				'WeightedCentroid'
				'MeanIntensity'
				'MinIntensity'
				'MaxIntensity'
				'MajorAxisLength'
				'MinorAxisLength'
				'Eccentricity'
				'Orientation'
				'EquivDiameter'
				'Extent'
				'PixelIdxList'
				'PixelList'};
			
			validStats.all = {
				'Area'
				'BoundingBox'
				'Centroid'
				'PixelValues'
				'WeightedCentroid'
				'MeanIntensity'
				'MinIntensity'
				'MaxIntensity'
				'SubarrayIdx'
				'MajorAxisLength'
				'MinorAxisLength'
				'Eccentricity'
				'Orientation'
				'Perimeter'
				'Image'
				'Extrema'
				'EquivDiameter'
				'Extent'
				'PixelIdxList'
				'PixelList'};
			
		end


	end





end



