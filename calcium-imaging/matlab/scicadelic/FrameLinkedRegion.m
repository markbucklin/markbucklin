classdef FrameLinkedRegion < ImageRegion
	
	
	
	

	% FRAME-LINKED PROPERTIES
	properties (SetAccess = protected)
		FrameIdx @uint32
		FrameSize
	end		
	
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = FrameLinkedRegion(S, varargin)			
			if (nargin > 0)				
				% REPMAT FOR STRUCT ARRAY DEFINING MULTIPLE LINKED REGIONS
				obj = repmat(obj, size(S,1), size(S,2));
				
				% COPY VALUES FROM REGION-PROPS STRUCTURE
				if isstruct(S)
					obj = copyPropsFromStruct(obj, S);
				end
				
				% ASSIGN "PROP-VAL" COMMA-SEPARATED INPUT ARGUMENTS
				if (nargin>1)
					obj = parseConstructorInput(obj, varargin{:});
				end
				
				% ADD UNIQUE IDENTIFIER TO EACH NEW OBJECT
				obj = addUid(obj);
			end			
		end
	end
	
	% COMPARISON METHODS
	methods
	end
	
	% DISPLAY METHODS
	methods
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
				fractionalOverlapArea = bsxfun(@rdivide, single(pxOverlapCount), single(uidxOrderedArea));
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
	end
	
	% INITIALIZATION HELPER METHODS
	methods (Access = protected)
		function varargout = parseConstructorInput(obj, varargin)
			
			if (nargin > 1)
				% perhaps should also use parseparams
				if (~isempty(varargin)) && (numel(varargin) >=2)
					for k = 1:2:length(varargin)
						propName = varargin{k};
						propVal = varargin{k+1};
						propClass = class(obj(1).(propName));
						if (isnumeric(propVal)) && (~isa(propVal, propClass))
							propVal = cast(propVal, propClass);
						end
						[obj.(propName)] = deal(propVal);
					end
				end
			end
			% RETURN MODIFIED OBJECTS
			if nargout
				varargout{1} = obj;
			end
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























