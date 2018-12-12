classdef LinkedRegion
	
	
	
	
	
	
	% SHAPE STATISTICS
	properties (SetAccess = protected)
		Area @single scalar
		Centroid @uint32 vector							% [x,y] from upper left corner
		BoundingBox @uint32 vector
		SubarrayIdx @cell vector
		MajorAxisLength @single scalar
		MinorAxisLength @single scalar
		Eccentricity @single scalar
		Orientation @single scalar
		Image @logical matrix
		Extrema @single matrix
		EquivDiameter @single scalar
		Extent @single scalar
		PixelIdxList @uint32 vector
		PixelList @uint32 matrix
		Perimeter @single scalar
	end
	
	% PIXEL-VALUE STATISTICS
	properties (SetAccess = protected)
		WeightedCentroid @single vector
		PixelValues @uint16 vector
		MaxIntensity @uint16 scalar
		MinIntensity @uint16 scalar
		MeanIntensity @single scalar
	end
	
	% OTHER DESCRIPTIVE PROPERTIES
	properties (SetAccess = protected)
		FrameIdx @uint32 scalar
	end
	
	% CONSTANTS AND SETTINGS
	properties (Constant, Hidden)
		
	end
	
	% HANDLES TO OTHER LINKED-REGIONS
	properties (SetAccess = protected)
		% 		NextRegion
		% 		PrecedingRegion
		% 		SuperRegion
	end
	
	% UNIQUE IDENTIFIER & UID LINKS
	properties (SetAccess = protected, Hidden)
		UID @uint32 scalar
		NextRegionUID @uint32 scalar
		PrecedingRegionUID @uint32 scalar
	end
	
	
	
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = LinkedRegion(RP, varargin)
warning('LinkedRegion.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
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
						% 						showError(me)
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
	
	% COMPARISON METHODS
	methods
		function doesOverlap = overlaps(r1, r2) % 300ms
			% Returns a logical scalar, vector, or matrix, depending on number of arguments (objects of
			% the ROI class) passed to the method. Calls can take any of the following forms for scalar
			% (1x1) ROI "a" and an array (e.g. 5x1) of ROI objects "b":
			%
			%		>> overlaps(a,b)      --> [5x1]
			%		>> overlaps(b,a)      --> [5x1]
			%		>> overlaps(b)        --> [5x5]
			% Note: the syntax:
			%		>> overlaps(a,b)
			% is equivalent to:
			%		>> a.overlaps(b)
			if nargin < 2
				r2 = r1;
			elseif (numel(r1) == 1) && (numel(r2) == 1)
				doesOverlap = any(any( bsxfun(@eq, r1.PixelIdxList, r2.PixelIdxList')));
				return
			end
			
			r2Area = uint32(cat(1,r2.Area));
			r2IdxIdx = cumsum(r2Area);
			r2PixIdx = uint32(cat(1, r2.PixelIdxList));
			doesOverlap = false(numel(r1), numel(r2));
			r1PixIdxCell = {r1.PixelIdxList};
			if numel(r1) > 32
				parfor k=1:numel(r1)
					r1PixIdx = uint32(r1PixIdxCell{k});
					pixeq1 = any(bsxfun(@eq, r1PixIdx, r2PixIdx'), 1)';
					if any(pixeq1)
						pxSum = cumsum(pixeq1);
						doesOverlap(k,:) = logical(diff([0 ; pxSum(r2IdxIdx)]))';
					end
				end
			else
				for k=1:numel(r1)
					r1PixIdx = uint32(r1PixIdxCell{k});
					pixeq1 = any(bsxfun(@eq, r1PixIdx, r2PixIdx'), 1)';
					if any(pixeq1)
						pxSum = cumsum(pixeq1);
						doesOverlap(k,:) = logical(diff([0 ; pxSum(r2IdxIdx)]))';
					end
				end
			end
			sz = size(doesOverlap);
			% Or convert to COLUMN VECTOR for a 1xK Query
			if (sz(1) == 1)
				doesOverlap = doesOverlap(:);
			end
		end
		function idxOverlap = spatialOverlap(r1, r2) % 1200ms
			% Returns all INDICES of OVERLAPPING PIXELS in Vector If multiple ROIs are used as INPUT, a
			% CELL array  is return with the size: [nObj x nRoi]
			if nargin < 2
				r2 = r1;
			end
			if numel(r1) > 1 || numel(r2) > 1
				idxOverlap = cell(numel(r1),numel(r2));
				for k2=1:numel(r2)
					rpix = r2(k2).PixelIdxList;
					parfor k1=1:numel(r1)
						idxOverlap{k1,k2} = fast_intersect_sorted(...
							r1(k1).PixelIdxList, rpix)';
					end
				end
				sz = size(idxOverlap);
				% Convert to COLUMN VECTOR for a 1xK Query
				if (sz(1) == 1)
					idxOverlap = idxOverlap(:);
				end
			else
				idxOverlap = fast_intersect_sorted(r1.PixelIdxList, r2.PixelIdxList);
			end
		end
		function fracOverlap = fractionalOverlap(r1, r2) % 280ms
			% >> ovr = fractionalOverlap(obj, roi) >> ovr = fractionalOverlap(roi) used to be --> [ovr,
			% rvo] = fractionalOverlap(obj, roi) returns a fractional number (or matrix) indicating
			%	0:			'no-overlap' ovr:	'fraction of OBJ that overlaps with ROI relative to total OBJ area
			%	rvo:   'fraction of ROI that overlaps with OBJ relative to total ROI area
			%
			%  --> Previously using FastStacks!
			%TODO: Check a flag to make sure indices are sorted
			if nargin < 2
				r2 = r1;
			end
			r2Area = double(cat(1,r2.Area));
			r2IdxIdx = cumsum(r2Area);
			r2PixIdx = uint32(cat(1, r2.PixelIdxList));
			fracOverlap = zeros(numel(r1), numel(r2));
			r1PixIdxCell = {r1.PixelIdxList};
			if numel(r1) > 32
				parfor k=1:numel(r1)
					r1PixIdx = uint32(r1PixIdxCell{k});
					pixeq1 = any(bsxfun(@eq, r1PixIdx, r2PixIdx'), 1)';
					if any(pixeq1)
						pxSum = cumsum(pixeq1);
						fracOverlap(k,:) = diff([0 ; pxSum(r2IdxIdx)])./ r2Area;
					end
				end
			else
				for k=1:numel(r1)
					r1PixIdx = uint32(r1PixIdxCell{k});
					pixeq1 = any(bsxfun(@eq, r1PixIdx, r2PixIdx'), 1)';
					if any(pixeq1)
						pxSum = cumsum(pixeq1);
						fracOverlap(k,:) = diff([0 ; pxSum(r2IdxIdx)])./ r2Area;
					end
				end
			end
			sz = size(fracOverlap);
			% Or convert to COLUMN VECTOR for a 1xK Query
			if (sz(1) == 1)
				fracOverlap = fracOverlap(:);
			end
		end
		function isWithin = isInBoundingBox(r1, r2) % 4ms
			% Returns logical vector/array (digraph) that is true at all edges where the centroid of OBJ
			% is within the rectangular box surrounding ROI (input 2, or all others in OBJ array )
			if nargin < 2
				r2 = r1;
			end
			if (numel(r1) > 1) || (numel(r2) > 1)
				r1Cxy = uint16(cat(1,r1.Centroid));
				r2BBox = cat(1,r2.BoundingBox);
				r2Xlim = uint16( [floor(r2BBox(:,1)) , ceil(r2BBox(:,1) + r2BBox(:,3)) ])';
				r2Ylim = uint16( [floor(r2BBox(:,2)) , ceil(r2BBox(:,2) + r2BBox(:,4)) ])';
				isWithin = bsxfun(@and,...
					bsxfun(@and,...
					bsxfun(@ge,r1Cxy(:,1),r2Xlim(1,:)),...
					bsxfun(@le,r1Cxy(:,1),r2Xlim(2,:))) , ...
					bsxfun(@and,...
					bsxfun(@ge,r1Cxy(:,2),r2Ylim(1,:)),...
					bsxfun(@le,r1Cxy(:,2),r2Ylim(2,:))));
			else
				if isempty(r1.BoundingBox) || isempty(r2.BoundingBox)
					isWithin = false;
					return
				end
				xc = r1.Centroid(1);
				yc = r1.Centroid(2);
				xbL = r2.BoundingBox(1);
				xbR = xbL + r2.BoundingBox(3);
				ybB = r2.BoundingBox(2);
				ybT = ybB + r2.BoundingBox(4);
				isWithin =  (xc >= xbL) & (xc <= xbR) & (yc >= ybB) & (yc <= ybT);
			end
			sz = size(isWithin);
			% Convert to COLUMN VECTOR for a 1xK Query
			if (sz(1) == 1)
				isWithin = isWithin(:);
			end
		end
		function varargout = centroidSeparation(r1, r2) % 2ms
			% Calculates the EUCLIDEAN DISTANCE between ROIs. Output depends on number of arguments. For
			% one output argument the hypotenuse between centroids is returned, while for two output
			% arguments the y-distance and x-distance are returned in two separate matrices. Usage
			% examples are below: >> csep = centroidSeparation( roi(1:100) )			--> returns [100x100]
			% matrix >> [simmat.cy,simmat.cx] = centroidSeparation(roi(1:100),roi(1:100)) --> 2
			% [100x100]matrices >> csep = centroidSeparation(roi(1), roi(2:101)) --> returns [100x1]
			% vector
			if nargin < 2
				r2 = r1;
			end
			if numel(r1) > 1 || numel(r2) > 1
				oCxy = cat(1,r1.Centroid);
				rCxy = cat(1,r2.Centroid);
				rCxy = rCxy';
				xdist = single(bsxfun(@minus, oCxy(:,1), rCxy(1,:)));
				ydist = single(bsxfun(@minus, oCxy(:,2), rCxy(2,:)));
				if nargout <= 1
					pixDist = bsxfun(@hypot, xdist, ydist);
				end
			else
				if isempty(r1.Centroid) || isempty(r2.Centroid)
					varargout{1:nargout} = inf;
					return
				end
				xdist = single(r1.Centroid(1) - r2.Centroid(1));
				ydist = single(r1.Centroid(2) - r2.Centroid(2));
				if nargout <= 1
					pixDist = hypot( xdist, ydist);
				end
			end
			if nargout <= 1
				sz = size(pixDist);
				% Convert to COLUMN VECTOR for a 1xK Query
				if (sz(1) == 1)
					pixDist = pixDist(:);
				end
				varargout{1} = pixDist;
			elseif nargout == 2
				if (size(xdist,1) == 1) || (size(ydist,1) == 1)
					xdist = xdist(:);
					ydist = ydist(:);
				end
				varargout{1} = ydist;
				varargout{2} = xdist;
			end
		end
		function limDist = limitSeparation(r1, r2) % 2ms
			% Calculates the DISTANCE between ROI LIMITS, returning a single matrix 2D or 3D matrix with
			% the last dimension carrying distances ordered TOP,BOTTOM,LEFT,RIGHT. USAGE:
			%		>> limDist = limitSeparation(obj(1:100)) --> returns [100x100x4] matrix
			% 	>> limDist = limitSeparation(obj(1),obj(1:100)) -->  [100x4] matrix
			if nargin < 2
				r2 = r1;
			end
			
			% CALCULATE XLIM & YLIM (distance from bottom left corner)
			bb = cat(1,r2.BoundingBox);
			r2Xlim = int16( [floor(bb(:,1)) , ceil(bb(:,1)+bb(:,3)) ]); % [LeftEdge,RightEdge] distance from left side of image
			r2Ylim = int16( [floor(bb(:,2)) , ceil(bb(:,2)+bb(:,4)) ]); % [BottomEdge,TopEdge] distance from bottom of image
			bb = cat(1,r1.BoundingBox);
			r1Xlim = int16( [floor(bb(:,1)) , ceil(bb(:,1)+bb(:,3)) ]);
			r1Ylim = int16( [floor(bb(:,2)) , ceil(bb(:,2)+bb(:,4)) ]);
			
			% FOR LARGE INPUT
			if numel(r1) > 1 || numel(r2) > 1
				% Order in 3rd dimension is Top,Bottom,Left,Right
				r1Lim = cat(3, r1Ylim(:,2), r1Ylim(:,1), r1Xlim(:,1), r1Xlim(:,2));
				r2Lim = cat(3, r2Ylim(:,2), r2Ylim(:,1), r2Xlim(:,1), r2Xlim(:,2));
				limDist = bsxfun(@minus, r1Lim, permute(r2Lim, [2 1 3]));
			else
				bottomYdist = r1Ylim(1) - r2Ylim(1);
				topYdist = r1Ylim(2) - r2Ylim(2);
				leftXdist = r1Xlim(1) - r2Xlim(1);
				rightXdist = r1Xlim(2) - r2Xlim(2);
				limDist = int16(cat(1, topYdist, bottomYdist, leftXdist, rightXdist));
			end
			sz = size(limDist);
			% Convert to COLUMN VECTOR for a 1xK Query
			if (sz(1) == 1)
				limDist = permute(limDist, [2 3 1]);
			elseif (sz(2) == 1)
				limDist = permute(limDist, [1 3 2]);
			end
			limDist = int16(limDist);
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
				if ~isempty(obj(1).BoundingBox)
					bb = cat(1,obj.BoundingBox);
					extentFromZeroColMax = max(bb(:,1) + bb(:,3), [], 1);
					extentFromZeroRowMax = max(bb(:,2) + bb(:,4), [], 1);
					maxExtentFromZero = [extentFromZeroRowMax  , extentFromZeroColMax];
					imSize = 2.^nextpow2(double(maxExtentFromZero));
				elseif ~isempty(obj(1).Centroid)
					imSize = 2.^nextpow2(double(max(cat(1,obj.Centroid))));
				else
					pxIdx = cat(1,obj.PixelIdxList);
					imSize = max(imSize,  2.^nextpow2(sqrt(double(max(pxIdx(:))))));
					imSize = [imSize imSize];
				end				
			end
			%OLD
			% 			if nargin < 2
			% 				imSize = 2^nextpow2(sqrt(double(max(pxIdx(:)))));%TODO: can improve this using centroid and boundingbox max or subscripts
			% 			end
			%ENDOLD
			
			
			mask = false(imSize);
			mask(pxIdx) = true;
		end
		function [labelMatrix, varargout] = createLabelMatrix(obj, imSize) % 3ms
			% Will return INTEGER LABELED IMAGE from a single ROI or Array of ROI objects with labels
			% assigned based on the order in which LinkedRegion objects are passed in (by index). A second
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
			
			% TIMING INFO FOR INDIVIDUAL COMPUTATION ON GPU
			% 			    'Area'                [0.3722]
			% 					'BoundingBox'         [0.4054]
			% 					'Centroid'						[0.3740]
			% 					'PixelValues'         [0.5653]*
			% 			    'WeightedCentroid'    [0.6156]*
			% 					'MeanIntensity'       [0.4260]
			% 					'MinIntensity'				[0.4151]
			% 					'MaxIntensity'        [0.4025]
			% 					'SubarrayIdx'         [1.3362]***
			% 			    'MajorAxisLength'     [0.5396]*
			% 					'MinorAxisLength'     [0.5589]*
			% 					'Eccentricity'				[0.5327]*
			% 					'Orientation'         [0.5506]*
			% 					'Image'               [1.3364]***
			% 					'Extrema'							[2.2523]*****
			% 					'EquivDiameter'       [0.3637]
			% 					'Extent'              [0.3860]
			% 			    'PixelIdxList'        [0.4331]=
			% 					'PixelList'           [0.4447]
		end
	end
	
	
end
















% DEFINE CLASS (INLINED FOR SPEED)
% 			propClass = struct(...
% 			              'Area', 'single',...
%                 'Centroid', 'uint32',...
%              'BoundingBox', 'uint32',...
%              'SubarrayIdx', 'cell',...
%          'MajorAxisLength', 'single',...
%          'MinorAxisLength', 'single',...
%             'Eccentricity', 'single',...
%              'Orientation', 'single',...
%                    'Image', 'logical',...
%                  'Extrema', 'single',...
%            'EquivDiameter', 'single',...
%                   'Extent', 'single',...
%             'PixelIdxList', 'uint32',...
%                'PixelList', 'uint32',...
%                'Perimeter', 'single',...
%         'WeightedCentroid', 'single',...
%              'PixelValues', 'uint16',...
%             'MaxIntensity', 'uint16',...
%             'MinIntensity', 'uint16',...
%            'MeanIntensity', 'single',...
%                 'FrameIdx', 'uint32',...
%                      'UID', 'uint32',...
%            'NextRegionUID', 'uint32',...
%       'PrecedingRegionUID', 'uint32',...
%           'SuperRegionUID', 'uint32');























