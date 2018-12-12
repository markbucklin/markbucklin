classdef (CaseInsensitiveProperties = true) RegionPropagator < scicadelic.SciCaDelicSystem
	
	
	
	% USER SETTINGS
	properties (Nontunable, PositiveInteger)
		MinRoiPixArea = 15;								% previously 50
		MaxRoiPixArea = 2500;							% previously 350, then 650, then 250
	end
	
	% STATES
	properties (DiscreteState)
		CurrentFrameIdx
	end
	
	% OUTPUTS
	properties (SetAccess = protected)
		ImageRegionReference @struct
		ImageRegionCurrentMatch @struct
		LabelMatrix
		GroupMotionEstimate %consensus?
		MatchMotionVector
	end
	properties (Nontunable, Logical)
		ImageRegionReferenceOutputPort = false
		LabelMatrixOutputPort = false
		ImageRegionCurrentMatchOutputPort = false
		GroupMotionEstimateOutputPort = false
		MatchMotionVectorOutputPort = false
	end
	
	% INTERNAL SETTINGS
	properties (SetAccess = immutable, Hidden)
		RegionStatNames
		FramePreallocationSize = 8188
		RegionPreallocationSize = 65535
		IsRegionStatScalar
	end
	
	% INTERNAL VARIABLES
	properties (SetAccess = protected) %Hidden
		RegionStorage
		RegionIncidence
		RegionIndex
		RegionFirstFrame
		% 		ImageRegionAll @struct
		% 		ImageRegionIdx
		% 		ImageRegionFrameIdx
	end
	
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden)
		pMinRoiPixArea
		pMaxRoiPixArea
	end
	
	
	
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = RegionPropagator(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));
			setPrivateProps(obj);
			obj.RegionStatNames = obj.selectRegionStats.all;
			allStatNames = obj.RegionStatNames(:);
			scalarStatNames = obj.selectRegionStats.scalar;
			for k=1:numel(allStatNames)
				statName = allStatNames{k};
				obj.IsRegionStatScalar(k) = any(strcmp(statName, scalarStatNames));
			end
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj, data, labelMatrix, ~)
			
			% CHECK INPUT
			checkInput(obj, data);
			fillDefaults(obj)
			
			obj.CurrentFrameIdx = 0;
			setPrivateProps(obj)
			
			% INITIALIZE ONNBOARD LABEL-MATRIX
			if isempty(obj.LabelMatrix)
				obj.LabelMatrix = labelMatrix(:,:,1);
			end
			
			% PREALLOCATE PROPAGATING REGION OUTPUT
			allStatNames = obj.RegionStatNames(:);
			scalarStatNames = obj.selectRegionStats.scalar;
			frameAlloc = obj.FramePreallocationSize;
			regionAlloc = obj.RegionPreallocationSize;
			
			
			isStatScalar = obj.IsRegionStatScalar;
			for k=1:numel(allStatNames)
				statName = allStatNames{k};
				if isStatScalar(k)
					obj.RegionStorage.(statName) = spalloc(regionAlloc, frameAlloc, floor(frameAlloc*regionAlloc/4));
				else
					obj.RegionStorage.(statName) = cell(regionAlloc, frameAlloc);
				end
			end
			obj.RegionIncidence = zeros(regionAlloc, 1);
			obj.RegionIndex = spalloc(regionAlloc*2, 1, regionAlloc);
			% 			obj.RegionFirstFrame = spalloc(regionAlloc, 1, floor(regionAlloc/2));
			
			% 			initialLabelMatrix = labelMatrix(:,:,1);
			% 			rp = regionprops(initialLabelMatrix, data(:,:,end), allStatNames{:});
			% 			numPix = numel(initialLabelMatrix);
			% 			splm = spalloc(numPix, regionAlloc, round(regionAlloc*obj.MaxRoiPixArea));
			% 			initialLabelMatrix = reshape(initialLabelMatrix, numPix,1);
			% 			for k=1:max(initialLabelMatrix(:))
			% 				px = (initialLabelMatrix == k);
			% 				splm(px,k) = 1;
			% 			end
			
			% 			rpArea = [rp.Area];
			% 			[~,maxIdx] = max(rpArea);
			% 			bigRp = rp(maxIdx);
			% 			bigRp.Image = repmat(bigRp.Image,2,2);
			% 			bigRp.PixelIdxList = repmat(bigRp.PixelIdxList,2,1);
			% 			bigRp.PixelList = repmat(bigRp.PixelList,2,1);
			% 			bigRp.PixelValues = repmat(bigRp.PixelValues,2,1);
			% 			bigRp.SubarrayIdx{1} = repmat(bigRp.SubarrayIdx{1},1,2);
			% 			bigRp.SubarrayIdx{2} = repmat(bigRp.SubarrayIdx{2},1,2);
			
			% PREALLOCATE INTERNAL VARIABLES (SPARSE)
			% 			obj.ImageRegionAll = repelem(bigRp, regionAlloc*frameAlloc);
			% 			obj.ImageRegionIdx = spalloc(regionAlloc, frameAlloc, round(regionAlloc*frameAlloc/2));
			% 			obj.ImageRegionFrameIdx = spalloc(regionAlloc, frameAlloc, round(regionAlloc*frameAlloc/2));
			
			% INITIALIZE OTHER PROPERTIES/OUTPUTS
			% 			if isempty(obj.LabelMatrix)
			% 				obj.LabelMatrix = initialLabelMatrix;
			% 			end
			
			
		end
		function varargout = stepImpl(obj, data, labelMatrix, idx)
			
			% LOCAL VARIABLES
			if isempty(idx)
				n = obj.CurrentFrameIdx;
			else
				n = idx(1)-1;
			end
			inputNumFrames = size(data,3);
			
			% CELL-SEGMENTAION PROCESSING
			processData(obj, data, labelMatrix, idx);
			
			% UPDATE NUMBER OF FRAMES
			obj.CurrentFrameIdx = n + inputNumFrames;
			
			if nargout
				% ASSIGN OUTPUT
				availableOutput = {...
					obj.ImageRegionReference,...
					obj.LabelMatrix,...
					obj.ImageRegionCurrentMatch,...
					obj.GroupMotionEstimate,...
					obj.MatchMotionVector};
				specifiedOutput = [...
					obj.ImageRegionReferenceOutputPort,...
					obj.LabelMatrixOutputPort,...
					obj.ImageRegionCurrentMatchOutputPort,...
					obj.GroupMotionEstimate,...
					obj.MatchMotionVector];
				varargout = availableOutput(specifiedOutput);
			end
		end
		function numOutputs = getNumOutputsImpl(obj)
			numOutputs = nnz([...
				obj.ImageRegionReferenceOutputPort,...
				obj.LabelMatrixOutputPort,...
				obj.ImageRegionCurrentMatchOutputPort,...
				obj.GroupMotionEstimateOutputPort,...
				obj.MatchMotionVectorOutputPort]);
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
		function varargout = processData(obj, data, labelMatrix, frameIdx)
			
			% LOCAL VARIABLES
			inputNumFrames = max(size(data,3), size(labelMatrix,3));
			roiA = obj.ImageRegionCurrentMatch;
			regionIncidence = obj.RegionIncidence;
			% 			regionFirstFrame = obj.RegionFirstFrame;
			allStatNames = obj.RegionStatNames(:);
			isStatScalar = obj.IsRegionStatScalar;
			frameSize = obj.FrameSize;
			regionAlloc = obj.RegionPreallocationSize;
			
			
			
			% INITIALIZE REFERENCE SET (IF 1ST FRAME ONLY)
			if isempty(roiA)
				
				f = data(:,:,1);
				lm = labelMatrix(:,:,1);
				roiA = applyConstraints(obj, regionprops(lm, f, allStatNames));
				m = numel(roiA);
				regionIdx = (1:m)';
				currentFrameIdx = frameIdx(1);
				for k=1:numel(allStatNames)
					statName = allStatNames{k};
					if isStatScalar(k)
						obj.RegionStorage.(statName)(regionIdx,currentFrameIdx) = cat(1, roiA.(statName));
					else
						[obj.RegionStorage.(statName){regionIdx,currentFrameIdx}] = deal(roiA.(statName));
					end
				end
				idxStart = 2;
			else
				% REMOVE RARE REGIONS OF INTEREST
				idxStart = 1;
				regionIdx = nonzeros(obj.RegionIndex);
				% 				if (numel(roiA) > 1000)%.9*regionAlloc)
				%
				%
				% 				end
			end
			% 			roiContinuous = roiA;
			
			if inputNumFrames > idxStart
				for k = idxStart:inputNumFrames
					
					% REFERENCE REGIONS FROM SET DEEMED CURRENTLY 'ACTIVE' (IDENTIFIED IN PREVIOUS FRAMES(S))
					% GET REGION-PROPS STRUCTURE FOR CURRENT FRAME
					f = data(:,:,k);
					lm = labelMatrix(:,:,k);
					roiB = applyConstraints(obj, regionprops(lm, f, allStatNames));
					currentFrameIdx = frameIdx(k);
					
					% INITIAL MAPPING FINDS ROI-PAIRS WHOSE CENTROIDS ARE MUTUALLY WITHIN EACH OTHERS BORDERS
					overlyingPairMap = (isInBoundingBox(roiA, roiB)) & (isInBoundingBox(roiB, roiA)');
					[idxA, idxB] = find(overlyingPairMap); % (all matches, single & multi?)
					
					
					
					
					%********************
					%********************
					%********************
					
					idx = [idxA, idxB];
					r1MapSum = accumarray(idx(:,1), 1, size(roiA));
					r2MapSum = accumarray(idx(:,2), 1, size(roiB));
					
					% PROPAGATE MAPPED REGIONS, ONE-TO-ONE MAPPING
					% 					roiKeep = false(size(roiA));
					isOne2One = ((r1MapSum(idx(:,1))==1)&(r2MapSum(idx(:,2))==1));
					idxOne2One = idx(isOne2One,:);
					
					
					
					aIdx = idxOne2One(:,1);
					bIdx = idxOne2One(:,2);
					roiContinuous = roiA;
					roiContinuous(idxA) = roiB(idxB);
					roiKeep = false(size(roiContinuous));
					% 					roiContinuous(aIdx) = roiB(bIdx);
					roiKeep(aIdx) = true;
					
					
					% PROPAGATE MAPPED REGIONS, COPY-SPLITTING AS NECESSARY TO HANDLE MULTI-MAP CASE
					roiSplit = struct.empty;
					idxSplit = [];
					roiFuse = struct.empty;
					idxFuse = [];
					idxMulti = idx(~isOne2One,:);
					multiPropagated = false(size(idxMulti,1),1);
					multiK = multiPropagated;
					
					multiPropArea = [cat(1, roiA(idxMulti(:,1)).Area), cat(1, roiB(idxMulti(:,2)).Area)];
					fracOv = min( multiPropArea(:,1)./multiPropArea(:,2), multiPropArea(:,2)./multiPropArea(:,1));
					fracOvSignificant = fracOv > .45;
					
					% FOR EACH MULTI-MATCHING PAIR
					idxMax = max(regionIdx(:));
					for kmulti=1:size(idxMulti,1)
						aIdx = idxMulti(kmulti,1);% scalar
						bIdx = idxMulti(kmulti,2);
						
						if multiPropagated(kmulti)
							continue
						end
						
						if (r1MapSum(aIdx)>1)
							% DIVERGING REGION --------
							multiK = (idxMulti(:,1) == aIdx);
							if (fracOvSignificant(kmulti))
								bIdx = idxMulti(multiK,2);
								numSplit = numel(bIdx);
								if isempty(roiSplit)
									roiSplit = roiB(bIdx(2:end));
								else
									roiSplit = cat(1, roiSplit(:), roiB(bIdx(2:end)));
								end
								idxSplit = cat(1, idxSplit(:), idxMax + (1:(numSplit-1))');
								% 								roiSplit = cat(1, roiSplit(:), roiB(bIdx(multiK(2:end))));
								% 								idxSplit = cat(1, idxSplit(:), aIdx);
							end
							roiContinuous(aIdx) = roiB(bIdx(1));
							
						elseif (r2MapSum(bIdx)>1)
							% CONVERGING REGION -------
							multiK = (idxMulti(:,2) == bIdx);
							if (fracOvSignificant(kmulti))
								aIdx = idxMulti(multiK,1);
								roiContinuous(aIdx(2:end)) = roiB(bIdx);
							end
							roiContinuous(aIdx(1)) = roiB(bIdx);
							numConverge = numel(aIdx);
							if isempty(roiFuse)
								roiFuse = roiA(aIdx);
							else
								roiFuse = cat(1, roiFuse(:), roiA(aIdx));
							end
							idxFuse = cat(1, idxFuse(:), idxMax + (1:(numConverge-1))');
							% 							idxFuse = cat(idxFuse(:), bIdx);
						end
						
						multiPropagated = multiPropagated | multiK;
						idxMax = max(cat(1, idxMax, idxSplit, idxFuse));
						roiKeep(aIdx) = true;
						
					end
					
					% PROPAGATE UNMAPPED REGIONS BY [COPYING] LAST FRAME-LINKED-REGION
					if any(r1MapSum==0)
						roiKeep(r1MapSum==0) = true;
					end
					
					% CREATE NEW PROPAGATING REGIONS FROM UNMAPPED INPUT
					if any(r2MapSum==0)
						roiNew = roiB(r2MapSum==0);
						numNew = numel(roiNew);
						idxNew = idxMax + (1:numNew)';
						idxMax = idxMax+numNew;
					else
						roiNew = struct.empty;
						idxNew = [];
					end
					
					
					%********************
					%********************
					%********************
					% OUTPUT
					
					roiNextRef = {roiContinuous(roiKeep(:)), roiSplit(:), roiNew(:)};
					idxNextRef = {regionIdx(roiKeep(:)), idxSplit(:), idxNew(:)};
					useNextRef = not(cellfun(@isempty, idxNextRef));
					roiA = cat(1, roiNextRef{useNextRef});
					regionIdx = cat(1, idxNextRef{useNextRef});
					
					% 					roiA = cat(1, roiContinuous(roiKeep(:)), roiSplit(:), roiNew(:));
					% 					regionIdx = cat(1, regionIdx(roiKeep(:)), idxSplit(:), idxNew(:));
					
					
					
					
					
					% UPDATE PRIVATE DATA-STORES
					% TODO: still need to update ROI Values that weren't passed to region props before
					% 					if numel(roiA)
					updateEssentialProps(roiA)
					
					for kstat=1:numel(allStatNames)
						statName = allStatNames{kstat};
						
						if isStatScalar(kstat)
							obj.RegionStorage.(statName)(regionIdx,currentFrameIdx) = cat(1, roiA.(statName));
						else
							[obj.RegionStorage.(statName){regionIdx,currentFrameIdx}] = deal(roiA.(statName));
						end
						
					end
					if (max(regionIdx) > length(regionIncidence))
						regionIncidence = cat(1, regionIncidence(:), zeros(regionAlloc,1));
					end
					regionIncidence(regionIdx) = regionIncidence(regionIdx) + 1;
					% 					regionFirstFrame(nascentIdx) = currentFrameIdx;
				end
			end
			obj.ImageRegionCurrentMatch = roiA;
			obj.RegionIndex(1:numel(regionIdx)) = regionIdx;
			obj.RegionIncidence = regionIncidence;
			% 			obj.RegionFirstFrame = regionFirstFrame;
			
			% PROCESS OUTPUT
			if nargout
				varargout{1} = roiA;
			end
			
			% *********************************************************
			% SUBFUNCTIONS
			% *********************************************************
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
				r2Xlim = single( [floor(bb(:,1)) , ceil(bb(:,1)+bb(:,3)) ]); % [LeftEdge,RightEdge] distance from left side of image
				r2Ylim = single( [floor(bb(:,2)) , ceil(bb(:,2)+bb(:,4)) ]); % [BottomEdge,TopEdge] distance from bottom of image
				bb = cat(1,r1.BoundingBox);
				r1Xlim = single( [floor(bb(:,1)) , ceil(bb(:,1)+bb(:,3)) ]);
				r1Ylim = single( [floor(bb(:,2)) , ceil(bb(:,2)+bb(:,4)) ]);
				
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
					limDist = single(cat(1, topYdist, bottomYdist, leftXdist, rightXdist));
				end
				sz = size(limDist);
				% Convert to COLUMN VECTOR for a 1xK Query
				if (sz(1) == 1) || (sz(2) == 1)
					limDist = reshape(limDist, [], 4);
					n2cOut = 1;
				else
					n2cOut = [1 2];
				end
				
				limDist = single(limDist);
				
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
		function roiOut = applyConstraints(obj, roiIn)
			minArea = 10;%TODO
			roiOut = roiIn(cat(1,roiIn.Area)>minArea);
		end
		function ovmap = linkLabelMatrices(obj, idxMat)
			r1IdxMat = obj.LabelMatrix;
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
					
					pval = obj.(pname);
					obj.(prop.Name) = pval;
					
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
					
					if isa(obj.(pn), 'gpuArray') && existsOnGPU(obj.(pn))
						obj.(pn) = gather(obj.(pn));
						obj.GpuRetrievedProps.(pn) = obj.(pn);
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
	methods (Static)
		function validStats = selectRegionStats()
			
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
			
			% 				'Perimeter'
			
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
				'Image'
				'Extrema'
				'EquivDiameter'
				'Extent'
				'PixelIdxList'
				'PixelList'};
			% 			'Perimeter'
			
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
				'Extrema'
				'EquivDiameter'
				'Extent'};
			% 			'Perimeter'
			
			validStats.scalar = {
				'Area'
				'MeanIntensity'
				'MinIntensity'
				'MaxIntensity'
				'MajorAxisLength'
				'MinorAxisLength'
				'Eccentricity'
				'Orientation'
				'EquivDiameter'
				'Extent'};
			% 			'Perimeter'
			
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























