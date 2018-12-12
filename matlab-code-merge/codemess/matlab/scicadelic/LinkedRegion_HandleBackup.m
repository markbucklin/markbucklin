classdef (CaseInsensitiveProperties = true) LinkedRegion < handle
	
	
	
	
	
	
	% SHAPE STATISTICS
	properties (SetAccess = protected)
		Area
		BoundingBox
		Centroid							% [x,y] from upper left corner
		Eccentricity
		Extrema
		Extent
		EquivDiameter
		Image
		PixelIdxList
		PixelList
		SubarrayIdx
		MajorAxisLength
		MinorAxisLength
		Orientation
	end
	
	% PIXEL-VALUE STATISTICS
	properties (SetAccess = protected)
		MaxIntensity
		MeanIntensity
		MinIntensity
		PixelValues
		WeightedCentroid
	end
	
	% OTHER DESCRIPTIVE PROPERTIES
	properties
		FrameIdx
	end
	
	% CONSTANTS AND SETTINGS
	properties (Constant, Hidden)
		MinSufficientOverlap = .75;
	end
	
	% HANDLES TO OTHER LINKED-REGIONS
	properties (SetAccess = protected)
		NextRegion
		PrecedingRegion
		SuperRegion
	end
	
	% NUMERIC INDICES FOR SAVING
	properties (SetAccess = protected, Hidden)
		Idx
		NextRegionIdx
		PrecedingRegionIdx
		SuperRegionIdx
	end
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = LinkedRegion(RP, varargin)
			
			% PROCESS INPUT FOR ALL REGIONS
			if nargin > 1
				args = varargin(:);
			else
				args = [];
			end
			
			% CALL RECURSIVELY FOR STRUCT ARRAY DEFINING MULTIPLE LINKED REGIONS
			if numel(RP) > 1
				for nr = 1:size(RP,1)
					for nc = 1:size(RP,2)
						obj(nr,nc) = LinkedRegion(RP(nr,nc), args);
					end
				end
			else
				
				% COPY VALUES FROM REGION-PROPS STRUCTURE
				statFields = fields(RP);
				for k=1:numel(statFields)
					statName = statFields{k};
					% 					if isprop(obj, statName)
					statVal = RP.(statName);
					if isa(statVal, 'gpuArray')
						obj.(statName) = gather(statVal);
					else
						obj.(statName)  = statVal; %cast?
					end
					% 					end
				end
				
				% ASSIGN "PROP-VAL" COMMA-SEPARATED INPUT ARGUMENTS
				if ~isempty(args) && (numel(args) >=2)
					for k = 1:2:length(args)
						if isprop(obj, args{k})
							obj.(args{k}) = args{k+1};
						end
					end
				end
				
				% CALCULATE OTHER PROPERTIES
				
			end
		end
	end
	
	% COMPARISON METHODS
	methods
		function doesOverlap = overlaps(r1, r2) % 300ms
			% Returns a logical scalar, vector, or matrix, depending on number of arguments (objects of
			% the ROI class) passed to the method. Calls can take any of the following forms for scalar
			% (1x1) ROI "a" and an array (e.g. 5x1) of ROI objects "b": >> overlaps(a,b)      --> [5x1] >>
			% overlaps(b,a)      --> [5x1] >> overlaps(b)        --> [5x5] Note: the syntax:  >>
			% overlaps(a,b) is equivalent to:  >> a.overlaps(b)
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
				for kRoi=1:numel(r2)
					rpix = r2(kRoi).PixelIdxList;
					for kObj=1:numel(r1)
						idxOverlap{kObj,kRoi} = fast_intersect_sorted(...
							r1(kObj).PixelIdxList, rpix)';
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
		function oFracOverlap = fractionalOverlap(r1, r2) % 280ms
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
			oFracOverlap = zeros(numel(r1), numel(r2));
			r1PixIdxCell = {r1.PixelIdxList};
			if numel(r1) > 32
				parfor k=1:numel(r1)
					r1PixIdx = uint32(r1PixIdxCell{k});
					pixeq1 = any(bsxfun(@eq, r1PixIdx, r2PixIdx'), 1)';
					if any(pixeq1)
						pxSum = cumsum(pixeq1);
						oFracOverlap(k,:) = diff([0 ; pxSum(r2IdxIdx)])./ r2Area;
					end
				end
			else
				for k=1:numel(r1)
					r1PixIdx = uint32(r1PixIdxCell{k});
					pixeq1 = any(bsxfun(@eq, r1PixIdx, r2PixIdx'), 1)';
					if any(pixeq1)
						pxSum = cumsum(pixeq1);
						oFracOverlap(k,:) = diff([0 ; pxSum(r2IdxIdx)])./ r2Area;
					end
				end
			end
			sz = size(oFracOverlap);
			% Or convert to COLUMN VECTOR for a 1xK Query
			if (sz(1) == 1)
				oFracOverlap = oFracOverlap(:);
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
				xdist = bsxfun(@minus, oCxy(:,1), rCxy(1,:));
				ydist = bsxfun(@minus, oCxy(:,2), rCxy(2,:));
				if nargout <= 1
					pixDist = bsxfun(@hypot, xdist, ydist);
				end
			else
				if isempty(r1.Centroid) || isempty(r2.Centroid)
					varargout{1:nargout} = inf;
					return
				end
				xdist = r1.Centroid(1) - r2.Centroid(1);
				ydist = r1.Centroid(2) - r2.Centroid(2);
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
			
			% CALCULATE XLIM & YLIM
			bb = cat(1,r2.BoundingBox);
			rXlim = int16( [floor(bb(:,1)) , ceil(bb(:,1)+bb(:,3)) ]);
			rYlim = int16( [floor(bb(:,2)) , ceil(bb(:,2)+bb(:,4)) ]);
			bb = cat(1,r1.BoundingBox);
			oXlim = int16( [floor(bb(:,1)) , ceil(bb(:,1)+bb(:,3)) ]);
			oYlim = int16( [floor(bb(:,2)) , ceil(bb(:,2)+bb(:,4)) ]);
			
			% FOR LARGE INPUT
			if numel(r1) > 1 || numel(r2) > 1
				oxlim = int16( cat(1, oXlim));
				oylim = int16( cat(1, oYlim));
				rxlim = int16( cat(1, rXlim));
				rylim = int16( cat(1, rYlim));
				rxlim = rxlim';
				rylim = rylim';
				% Order in 3rd dimension is Top,Bottom,Left,Right
				oLim = cat(3,oylim(:,1),oylim(:,2),oxlim(:,1),oxlim(:,2));
				rLim = cat(3,rylim(1,:),rylim(2,:),rxlim(1,:),rxlim(2,:));
				limDist = bsxfun(@minus, oLim, rLim);
			else
				topYdist = oYlim(1) - rYlim(1);
				bottomYdist = oYlim(2) - rYlim(2);
				leftXdist = oXlim(1) - rXlim(1);
				rightXdist = oXlim(2) - rXlim(2);
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
		function isSmlr = sufficientlySimilar(obj, roi)
			% Loose predictor of similarity between ROIs. Will return a logical scalar, vector, or matrix
			% depending on the number and dimensions of the input.
			if isempty([obj.MinSufficientOverlap])
				minOverlap = .75;
			else
				minOverlap = obj.MinSufficientOverlap;
			end
			if nargin < 2
				roi = obj;
			end
			nObj = numel(obj);
			nRoi = numel(roi);
			isSmlr = false([nObj nRoi]);
			for kRoi = 1:nRoi
				R2 = roi(kRoi);
				for kObj = kRoi:nObj
					R1 = obj(kObj);
					% Check whether there is ANY OVERLAP
					minProfile = min([R1.BoundingBox(3:4) R2.BoundingBox(3:4)]);
					if centroidSeparation(R1,R2) < minProfile/2
						% Check whether overlap is SUBSTANTIAL AND EXCLUSIVE
						rfo = fractionalOverlap([R1 R2]);
						if all(rfo > minOverlap)
							isSmlr(kObj,kRoi) = true;
						end
					end
				end
			end
			sz = size(isSmlr);
			% Construct TRUTH-TABLE using symmetry for INTRAGROUP KxK Query
			if (sz(1) > 1) && (sz(2) > 1) && (sz(1) == sz(2))
				isSmlr = isSmlr | isSmlr';
				% Or convert to COLUMN VECTOR for a 1xK Query
			elseif (sz(1) == 1)
				isSmlr = isSmlr(:);
			end
		end
	end
	
	% DISPLAY METHODS
	methods
		function mask = createMask(obj, imSize) % 2ms
			% Will return BINARY IMAGE from a single ROI or Array of ROI objects			
			pxIdx = cat(1,obj.PixelIdxList);			
			if nargin < 2
				imSize = 2^nextpow2(sqrt(max(pxIdx(:))));
			end
			mask = false(imSize);
			mask(pxIdx) = true;
		end
		function lm = createLabelMatrix(obj, imSize) % 3ms
			% Will return INTEGER LABELED IMAGE from a single ROI or Array of ROI objects
						
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
			pxLabel = zeros(size(pxIdx), outClass);
			pxLabel(lastIdx(1:end-1)+1) = 1;
			pxLabel = cumsum(pxLabel) + 1;						
						
			% ASSIGN LABELS IN THE ORDER OBJECTS WERE PASSED TO THE FUNCTION
			if nargin < 2
				imSize = 2^nextpow2(sqrt(max(pxIdx(:))));
			end		
			lm = zeros(imSize, outClass);
			lm(pxIdx) = pxLabel;
		
		end
	end
	
	% LINKING METHODS
	methods
		function linkToNext(obj, roi)
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
end








































