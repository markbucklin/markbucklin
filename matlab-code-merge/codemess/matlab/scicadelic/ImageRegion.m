classdef (HandleCompatible) ImageRegion
	
	
	
	
	
	
	% SHAPE STATISTICS
	properties (SetAccess = protected)
		Area @single 
		Centroid @uint32 							% [x,y] from upper left corner
		BoundingBox @uint32 
		SubarrayIdx @cell 
		MajorAxisLength @single 
		MinorAxisLength @single 
		Eccentricity @single 
		Orientation @single 
		Image @logical 
		Extrema @single 
		EquivDiameter @single 
		Extent @single 
		PixelIdxList @uint32 
		PixelList @uint32 
		Perimeter @single 
	end
	
	% PIXEL-VALUE STATISTICS
	properties (SetAccess = protected)
		WeightedCentroid @single 
		PixelValues @uint16 
		MaxIntensity @uint16 
		MinIntensity @uint16 
		MeanIntensity @single 
	end
	
	% UNIQUE IDENTIFIER & UID LINKS
	properties (SetAccess = protected, Hidden)
		UID @uint32 
	end
	
		% CONSTANTS AND SETTINGS
	properties (Constant, Hidden)	
	end
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = ImageRegion(varargin)
			
			if (nargin > 0)				
				% ADD UNIQUE IDENTIFIER TO EACH NEW OBJECT
				obj = addUid(obj);
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
		function varargout = edgeSeparation(r1, r2) % 2ms
			% Calculates the DISTANCE between ROI LIMITS, returning a single matrix 2D or 3D matrix with
			% the last dimension carrying distances ordered TOP,BOTTOM,LEFT,RIGHT. If more than one output
			% argument is given, the edge-Displacement is broken up by edge as demonstrated below.
			%
			% USAGE:
			%		>> limDist = edgeSeparation(obj(1:100))		--> returns [100x100x4] matrix
			% 	>> limDist = edgeSeparation(obj(1),obj(1:100))			-->  [100x4] matrix
			% 	>> [verticalDist, horizontalDist] = edgeSeparation(rp(1),rpRef);
			% 	>> [topDist,botDdist,leftDist,rightDist] = edgeSeparation(rp,rpRef);
			%
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
			if (sz(1) == 1) || (sz(2) == 1)
				limDist = reshape(limDist, [], 4);
				n2cOut = 1;
			else
				n2cOut = [1 2];
			end
			
			limDist = int16(limDist);
			
			switch nargout
				case 1
					varargout{1} = limDist;
				case 2
					if length(n2cOut) == 1
						varargout(1:2) = mat2cell(limDist, size(limDist,1), [2 2]);
					else
						varargout(1:2) = mat2cell(limDist, size(limDist,1), size(limDist,2), [2 2]);
					end
				case 4
					varargout = num2cell(limDist, n2cOut);
				otherwise
					varargout{1} = limDist;
			end
			
			
		end
	end
	
	% GRAPHICAL OUTPUT METHODS
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
			lastIdx = cumsum(round(cat(1, obj.Area)));
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
	
	% INITIALIZATION & STATIC HELPER METHODS
	methods (Access = protected, Hidden)
		function varargout = copyPropsFromStruct(obj, S)
			
			% COPY VALUES FROM REGION-PROPS STRUCTURE
			statFields = fields(S);
				for k=1:numel(statFields)
					statName = statFields{k};
					statVal = {S.(statName)};
					propClass = class(obj(1).(statName));
					if (isnumeric(statVal{1})) && (~isa(statVal{1}, propClass))
						statVal = cellfun(@(x) {cast(x,propClass)}, statVal);
					end
					[obj.(statName)] = deal(statVal{:});
				end
				
			% RETURN MODIFIED OBJECTS
			if nargout
				varargout{1} = obj;
			end
			
		end
		function varargout = parseConstructorInput(obj, varargin)
			
			if (nargin > 1)
				% perhaps should also use parseparams
				if (~isempty(varargin)) && (numel(varargin) >=2)
					for k = 1:2:length(varargin)
						try
							propName = varargin{k};
							propVal = varargin{k+1};
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
			end
			% RETURN MODIFIED OBJECTS
			if nargout
				varargout{1} = obj;
			end
		end
		function varargout = addUid(obj, varargin)
			
			% ASSIGN UNIQUE-IDENTIFICATION-NUMBER -> IMMUTABLE?
			global uID
			if isempty(uID)
				uID = 1;
			end
			if nargin < 2
				uid = uID;
			else
				uid = varargin{1};
			end			
			N = numel(obj);
			if length(uid) < N
				uid = uid + (0:(N-1));
			end
			for k=1:N
				obj(k).UID = uint32(uid(k));
			end
			
			% UPDATE GREATEST GLOBAL UID & RETURN OBJECT
			uID = max( uid(end)+1 , uID+N );
			if nargout
				varargout{1} = obj;
			end
		end
	end
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
				'Perimeter'
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
			
			validStats.sizeconsistent = {
				'Area'
				'BoundingBox'
				'Centroid'
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
				'Extrema'
				'EquivDiameter'
				'Extent'};
			
			validStats.scalar = {
				'Area'
				'MeanIntensity'
				'MinIntensity'
				'MaxIntensity'
				'MajorAxisLength'
				'MinorAxisLength'
				'Eccentricity'
				'Orientation'
				'Perimeter'
				'EquivDiameter'
				'Extent'};
			
			
		end
	end





end














































