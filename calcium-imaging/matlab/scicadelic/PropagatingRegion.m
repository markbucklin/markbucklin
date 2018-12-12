classdef PropagatingRegion  <  ImageRegion  &  matlab.mixin.Copyable
	
	
	
	
	% USER SETTINGS
	properties (Access = public)
		
	end
	properties (SetAccess = immutable)
		PreallocationSize = 64
	end
	
	
	% ARRAY OF FRAME-LINKED-REGIONS
	properties (Dependent)
		FrameLink
	end
	properties (SetAccess = protected, Hidden)
		pFrameLink @cell %@FrameLinkedRegion vector
		pFrameLinkLast @FrameLinkedRegion scalar
		pFrameLinkIdx @uint32 vector
	end
	
	
	% HANDLES TO CONVERGING/DIVERGING/INTERSECTING SISTER REGIONS
	properties (SetAccess = protected)
		IntersectingRegion @PropagatingRegion vector
		DivergenceFrameIdx
		ConvergenceFrameIdx
	end
	
	% CONSUMER CONFIDENCE
	properties (SetAccess = protected)
		NumPropagation = 0
		NumCopagation = 0		
		Confidence @double scalar
	end
	
	% FRAME-LINKED-SUMMARY
	properties (Dependent)
		FilledFramesIdx
		TemporalDensity
		ElbowRoom
		RangeOfMotion
		DivergenceCount
		ConvergenceCount
	end
	
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = PropagatingRegion(frameLinkedRegions, varargin)
			if (nargin>0)
				if isnumeric(frameLinkedRegions)
					N = frameLinkedRegions;
					for k=N:-1:1
						obj(k,1) = copyElement(obj(1));
					end
				elseif isa(frameLinkedRegions, 'FrameLinkedRegion')
					N = numel(frameLinkedRegions);
					% 					initFrameLink(obj(1), frameLinkedRegions(1));
					% 					if (N>1)
					% 						for k=N:-1:2
					% 							obj(k,1) = copyElement(obj(1));
					% 							initFrameLink(obj(k), frameLinkedRegions(k));
					% 						end
					if (N>1)
						for k=2:N
							obj(k,1) = copyElement(obj(1));
						end
					end
					initFrameLink(obj, frameLinkedRegions);
				end
				if (nargin>1)
					parseConstructorInput(obj, varargin{:});
				end
			end
		end
	end
	
	% DISPLAY METHODS
	methods
	end
	
	% LINKING METHODS
	methods
		function varargout = propagate(obj, r2)
			% 			[obj, splitPropRegion, newPropRegion] = propagate(obj, varargin)
			minFracOv = .5;
			%minArea?
			
			% CHECK FOR UNINITIALIZED OBJECTS
			r1 = getLastFrameLink(obj);
			% 			flEmpty = false(size(r1));
			% 			for k=1:numel(r1)
			% 				flEmpty(k) = isempty(r1(k));
			% 			end
			
			if ~isempty(r1)
				% 				obj = obj(~flEmpty);
				
				% CONSTRUCT MAP BETWEEN ALL OVERLAPPING UIDS
				r1IdxMat = r1.createLabelMatrix;
				r2IdxMat = r2.createLabelMatrix;
				try
					pxOverlap = logical(r1IdxMat) & logical(r2IdxMat);
				% 				uid2uidMap = [uint16(r1UidMat(pxOverlap)) , uint16(r2UidMat(pxOverlap))];
				idx2idxMap = [uint16(r1IdxMat(pxOverlap)) , uint16(r2IdxMat(pxOverlap))];
				uniqueIdxPairMap = unique(idx2idxMap, 'rows');
				% 				[uniqueUidPairMap, uIdx, ~] = unique(uid2uidMap, 'rows');
				% 				uniqueIdxPairMap = idx2idxMap(uIdx,:);
				
				% COUNT & SORT BY RELATIVE AREA OF OVERLAP
				pxOverlapCount = sum( all( bsxfun(@eq,...
					reshape(idx2idxMap, size(idx2idxMap,1), 1, size(idx2idxMap,2)),...
					shiftdim(uniqueIdxPairMap, -1)), 3), 1)';
				uidxOrderedArea = [cat(1,r1(uniqueIdxPairMap(:,1)).Area) ,...
					cat(1,r2(uniqueIdxPairMap(:,2)).Area)];
				fractionalOverlapArea = bsxfun(@rdivide, pxOverlapCount, uidxOrderedArea);
				[~, fracOvSortIdx] = sort(prod(fractionalOverlapArea,2), 1, 'descend');
				fractionalOverlapArea = fractionalOverlapArea(fracOvSortIdx,:);
				idx = uniqueIdxPairMap(fracOvSortIdx,:);
				r1MapSum = accumarray(idx(:,1), 1, size(r1));
				r2MapSum = accumarray(idx(:,2), 1, size(r2));
				
				% PROPAGATE MAPPED REGIONS, ONE-TO-ONE MAPPING
				objKeep = false(size(obj));
				isOne2One = ((r1MapSum(idx(:,1))==1)&(r2MapSum(idx(:,2))==1));
				idxOne2One = idx(isOne2One,:);
				for k=1:nnz(isOne2One)
					oIdx = idxOne2One(k,1);
					rIdx = idxOne2One(k,2);
					omr = obj(oIdx);
					rmr = r2(rIdx);
					addFrameLink(omr, rmr);
					% 					omr.NumPropagation = omr.NumPropagation + 1;
					objKeep(oIdx) = true;
				end
				
				% PROPAGATE MAPPED REGIONS, COPY-SPLITTING AS NECESSARY TO HANDLE MULTI-MAP CASE
				splitPropRegion = PropagatingRegion.empty;
				idxMulti = idx(~isOne2One,:);
				multiPropagated = false(size(idxMulti,1),1);
				multiK = multiPropagated;
				fracOvMulti = fractionalOverlapArea(~isOne2One,:);
				for k=1:size(idxMulti,1)
					oIdx = idxMulti(k,1);
					rIdx = idxMulti(k,2);
					
					if multiPropagated(k)
						continue
					end
					
					if (r1MapSum(oIdx)>1) % DIVERGING REGION --------
						multiK = (idxMulti(:,1) == oIdx);
						fracOvSum = sum(fracOvMulti(multiK,1));
						if (fracOvSum > minFracOv)
							omr = obj(oIdx); % original
							rIdx = idxMulti(multiK,2);
							rmr = r2(rIdx);
							omr.DivergenceFrameIdx = cat(1, omr.DivergenceFrameIdx, rmr.FrameIdx);
							for km = 2:numel(rmr)
								newSplitRegion = copyElement(omr); % copy 
								newSplitRegion.IntersectingRegion = cat(1,newSplitRegion.IntersectingRegion, omr); % link with handle to original
								addFrameLink(newSplitRegion, rmr(km)); % add secondary region to copy
								splitPropRegion = cat(1, splitPropRegion, newSplitRegion); % add with any other split-off region-copies
								omr.IntersectingRegion = cat(1, omr.IntersectingRegion, newSplitRegion); % link original with handle to split
							end							
						else
							omr = obj(oIdx);
							rmr = r2(rIdx);
						end						
						addFrameLink(omr, rmr(1)); % add region to original
						
					elseif (r2MapSum(rIdx)>1) % CONVERGING REGION -------
						multiK = (idxMulti(:,2) == rIdx);
						fracOvSum = sum(fracOvMulti(multiK,2));
						if (fracOvSum > minFracOv)
							oIdx = idxMulti(multiK,1);
							omr = obj(oIdx);
							rmr = r2(rIdx);
							frameIdx = rmr.FrameIdx;
							for km = 2:numel(omr)
								omrkm = omr(km);
								omrkm.ConvergenceFrameIdx = cat(1, omrkm.ConvergenceFrameIdx, frameIdx);
								addFrameLink(omrkm, rmr);
							end
						else
							omr = obj(oIdx);
							rmr = r2(rIdx);
						end												
						addFrameLink(omr(1), rmr);% add copy of frame-linked-region to each handle (propagating region)
						numConverge = numel(omr);						
						for kc = 1:numConverge %link handles to each other
							convergeGrp = false(numConverge,1);
							convergeGrp(kc) = true;
							omr(convergeGrp).IntersectingRegion = cat(1,...
								omr(convergeGrp).IntersectingRegion, omr(~convergeGrp));
						end
					end
					multiPropagated = multiPropagated | multiK;
					objKeep(oIdx) = true;
				end
				
				% PROPAGATE UNMAPPED REGIONS BY [COPYING] LAST FRAME-LINKED-REGION
				% 				t = hat;%TODO
				% 				propCopIdx = find(r1MapSum==0);
				% 				opc = obj(propCopIdx);
				if any(r1MapSum==0)
					objKeep(r1MapSum==0) = true;
				end
				% 				flcop = getLastFrameLink(obj(propCopIdx));
				% 				for k=1:numel(propCopIdx)
				% 					pcIdx = propCopIdx(k);
				% 					opc = obj(pcIdx);
				% 				flcop = getLastFrameLink(opc);
				% 					addFrameLink(opc, flcop(k));
				% 					opc(k).NumCopagation = opc(k).NumCopagation + 1;
				
				% 					objKeep(pcIdx) = true;
				% 				end
				% 				fprintf('prop by copy time: %-03.4gms\n',(hat-t).*1000)%TODO
				
				% CREATE NEW PROPAGATING REGIONS FROM UNMAPPED INPUT
				if any(r2MapSum==0)					
					newPropRegion = PropagatingRegion(r2(r2MapSum==0));
				else
					newPropRegion = PropagatingRegion.empty;
				end
				
				% OUTPUT
				obj = obj(objKeep);
				
				catch me
					msg = getError(me);
					disp(msg)					
					newPropRegion = PropagatingRegion.empty;
					splitPropRegion = PropagatingRegion.empty;					
				end
				
			else
				% PREALLOCATE/DEFINE BLANK OUTPUT TYPE WITH INITIALIZED OBJECTS
				newPropRegion = PropagatingRegion.empty;
				splitPropRegion = PropagatingRegion.empty;
				obj = PropagatingRegion(r2);
				
			end
			if nargout == 1
				varargout{1} = {obj, splitPropRegion, newPropRegion};
			else
				argsOut = {obj, splitPropRegion, newPropRegion};
				varargout = argsOut(1:nargout);
			end
			
		end
	end
	
	% PROPERTY UPDATE
	methods
		function updateEssentialProps(obj)
			% Updates AREA, CENTROID, BOUNDINGBOX, & PIXELIDXLIST by summarizing FRAMELINK array
			N = numel(obj);
			for k=1:N
				flr = obj(k).FrameLink(:);
				M = numel(flr);				
				
				% AREA
				obj(k).Area = mean(cat(1,flr.Area),1,'native');
				
				% CENTROID
				cxy = cat(1,flr.Centroid);
				obj(k).Centroid = round(mean(cxy,1,'native'));
				
				% BOUNDINGBOX (from top-left corner)
				bb = cat(1, flr.BoundingBox);
				fxlim = [min(bb(:,1)) , max(bb(:,1)+bb(:,3))];
				fylim = [min(bb(:,2)) , max(bb(:,2)+bb(:,4))];				
				leftEdge = fxlim(1);
				topEdge = fylim(1);				
				width = fxlim(2)-fxlim(1);
				height = fylim(2)-fylim(1);
				obj(k).BoundingBox = [leftEdge, topEdge, width, height];
				
				% PIXELIDXLIST
				obj(k).PixelIdxList = unique(cat(1,flr.PixelIdxList));
				
				% PIXELLIST (SubScripts)
				if ~isempty(flr(1).PixelList)
					obj(k).PixelList = unique(cat(1,flr.PixelList),'rows');
				end
			end
		end
		function averageScalarProps(obj)
			N = numel(obj);
			scalarProps = obj.regionStats.scalar;			
			for k=1:N			
				flr = obj(k).FrameLink(:);
				for m = 1:numel(scalarProps)
					propName = scalarProps{m};
					propVal = mean(cat(1, flr.(propName)),1,'native');
					obj(k).(propName) = propVal;
					% 					obj(k).(propName) = cast(propVal, 'like', obj(k).(propName));
				end					
			end
		end
		function S = getIntensity(obj)
			N = numel(obj);
			allIdx = {obj.FilledFramesIdx}';
			minIdx = cellfun(@min, allIdx);
			maxIdx = cellfun(@max, allIdx);
			universalIdx = (min(minIdx):max(maxIdx))';
			M = length(universalIdx);
			S(N) = struct(...
				'Idx',universalIdx,...
				'MaxIntensity',zeros(M,1),...
				'MinIntensity',zeros(M,1),...
				'MeanIntensity',zeros(M,1));
			for k=N:-1:1
				flr = obj(k).FrameLink(:);
				S(k).Idx = allIdx{k};
				S(k).MaxIntensity = cat(1, flr.MaxIntensity);
				S(k).MinIntensity = cat(1, flr.MinIntensity);
				S(k).MeanIntensity = cat(1, flr.MeanIntensity);				
			end
		end
	end
	
	% FRAME-LINK MANAGMENT
	methods (Access = protected, Hidden)
		function initFrameLink(obj, link)
			initSize = obj(1).PreallocationSize;
			linkFrameIdx = [link.FrameIdx];
			nLink = numel(link);
			nObj = numel(obj);
			if nLink < nObj
				linkFrameIdx = repelem(linkFrameIdx, nObj);
				link = repelem(link, nObj);
			end
			for k=1:nObj				
				% CHECK PREALLOCATION				
				% 				obj(k).pFrameLink = repelem({link(k)}, initSize);
				obj(k).pFrameLink = cell(initSize,1);
				obj(k).pFrameLink{1} = link(k);
				obj(k).pFrameLinkIdx = zeros([initSize,1],'like',linkFrameIdx);
				obj(k).pFrameLinkIdx(1) = linkFrameIdx(k);
				obj(k).pFrameLinkLast = link(k);
			end
		end
		function addFrameLink(obj, link)
			initSize = obj.PreallocationSize;
			linkFrameIdx = link.FrameIdx;
			
			pidx = obj.pFrameLinkIdx;
			idx = pidx(pidx>0);
			nIdx = length(idx);
			curLength = length(pidx);
			
			% ALLOCATE MORE SPACE IF NECESSARY
			if ((nIdx+1) > curLength)
				obj.pFrameLink = cat(1, obj.pFrameLink, cell(initSize,1));
				obj.pFrameLinkIdx(curLength+(1:initSize)) = 0;
			end
			
			% ADD FRAME-LINKED-REGION & FRAME-IDX
			obj.pFrameLinkIdx(nIdx+1) = linkFrameIdx;			
			obj.pFrameLink{nIdx+1} = link;
			obj.pFrameLinkLast = link;
		end
		function link = getLastFrameLink(obj)
			link = cat(1, obj.pFrameLinkLast);
		end
	end
	methods
		function fl = get.FrameLink(obj)
			pidx = obj.pFrameLinkIdx;
			idx = pidx(pidx>0);
			% 			idx = pidx(~isnan(pidx));
			nIdx = numel(idx);
			fl(1,idx) = [obj.pFrameLink{1:nIdx}];
			% 			fl(1,idx) = obj.pFrameLink(1:nIdx);
		end
		function idx = get.FilledFramesIdx(obj)
			idx = cat(1, obj.FrameLink.FrameIdx);
			% 			pidx = obj.pFrameLinkIdx;
			% 			idx = pidx(pidx>0);
		end
	end
	
	
	
	
	
end
















% ADDFRAMELINK - FOR MULTIPLE INPUT (NOT USED)
% 			for k=1:numel(obj)
% 				pidx = obj(k).pFrameLinkIdx;
% 				idx = pidx(pidx>0);				
% 				nIdx = numel(idx);
% 				curLength = length(pidx);
% 				
% 				% ALLOCATE MORE SPACE IF NECESSARY
% 				if ((nIdx+nLink) > curLength)					
% 					obj(k).pFrameLink = cat(1, obj.pFrameLink, cell(initSize,1));
% 					obj(k).pFrameLinkIdx(curLength+(1:initSize)) = 0;
% 				end
% 				
% 				% ADD FRAME-LINKED-REGION & FRAME-IDX
% 				obj(k).pFrameLinkIdx(nIdx+(1:nLink)) = linkFrameIdx;
% 				for m=1:nLink
% 					obj(k).pFrameLink{nIdx+m} = link(m);
% 				end
% 				obj(k).pFrameLinkLast = link(m);
% 			end






