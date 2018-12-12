classdef RoiSet < hgsetget
  
  
  
  properties
	 minArea = 200;
	 superRegionThreshold = 5000;
  end
  properties
	 maskAll
	 maskSuperRegion
	 maskSubRegion
	 potentialRegion
	 steadyRegion
	 superRegion
	 subRegion
  end
  properties
	 centroid
	 area
	 boundingBox
	 shape
	 labelMatrix
  end
  properties
	 frames
	 frameSize
	 frameClass
  end
  properties (Hidden)
	 rpFields
	 
  end
  
  
  events
  end
  
  
  
  methods
	 function obj = RoiSet(varargin)
		if nargin > 1
		  for k = 1:2:length(varargin)
			 obj.(varargin{k}) = varargin{k+1};
		  end
		end
		obj.rpFields = {'Area', 'Centroid', 'BoundingBox', 'PixelIdxList'};
	 end
  end
  methods
	 function addRegion(obj, regionDef)
		% Add Regions of Interest.
		% 'REGIONDEF' input may take one of several forms describing potential regions of interest.
		% Format will be handled by calling other methods and eventually calling addRegion recursively.
		if ~isa(regionDef, 'RegionOfInterest')
		  obj.addVariablyDefinedRegion(regionDef);
		  return
		end
		roi = regionDef;
		if isempty(obj.potentialRegion)
		  obj.potentialRegion = roi;
		  return
		else
		  Npr = numel(obj.potentialRegion);
		  Nnr = numel(roi);
		  overlapMat = zeros(Nnr,Npr);
		  for kmreg = 1:Npr
			 pRoi = obj.potentialRegion(kmreg); % Potential ROI
			 for knreg = 1:Nnr
				nRoi = roi(knreg); % New ROI
				overlapMat(knreg,kmreg) = fractionalOverlap(nRoi, pRoi);
			 end
		  end
		  % MANAGE/MERGE OVERLAPPING ROIS IN POTENTIAL POOL (>95% overlap)		  
		  [subNew,subPot] = find(overlapMat > .90);
		  for kOv=1:numel(subNew)
			 pRoi = obj.potentialRegion(subPot(kOv));
			 nRoi = roi(subNew(kOv));
			 [newOverlap, potOverlap] = fractionalOverlap(nRoi, pRoi);
			 if abs(newOverlap - potOverlap) < .05
				pRoi = merge(pRoi, nRoi);
			 else
% 				keyboard
				pRoi.addSubRoi(nRoi);
				% TODO: Handle Sub-regions and Super-Regions
			 end
		  end
		  
		  nonMergedRoi = roi(~[roi.isMerged]);
		  mergedRoi = roi([roi.isMerged]);
		  obj.potentialRegion = cat(1,obj.potentialRegion(:), nonMergedRoi(:));
		  
		  % EXTRACT SUPER-REGIONS (LARGE AREA OR MULTIPLE SUB-REGION)
		  prLargeArea = [obj.potentialRegion.Area] > obj.superRegionThreshold;
		  obj.superRegion = obj.potentialRegion(prLargeArea);
		  obj.potentialRegion = obj.potentialRegion(~prLargeArea);
		  
		  % DELETE REFERENCES TO ROIS THAT HAVE BEEN MERGED INTO ANOTHER
		  delete(mergedRoi);
		end
		
	 end
	 function addVariablyDefinedRegion(obj,regionDef)
		switch class(regionDef)
		  case 'RegionOfInterest' % Custom-Defined Class
			 obj.addRegion(regionDef);
		  case 'struct'
			 if all(isfield(regionDef, obj.rpFields)) % RP - RegionProps
				RP = regionDef;
				obj.addRP(RP);
			 elseif isfield(regionDef,'Connectivity') % CC - ConnectedComponents
				CC = regionDef;
				if isempty(obj.frameSize)
				  obj.frameSize = CC.ImageSize;
				end
				obj.addCC(CC);
			 else
				warning('RoiSet:addRegion:UnknownInput','Region definition format is unkown')
			 end
		  case 'logical'	% Binary Thresholded "BLOB" Frame
			 BW = regionDef;
			 if isempty(obj.frameSize)
				obj.frameSize = size(BW);
			 end
			 CC = bwconncomp(BW);
			 obj.addCC(CC);
		  case {'uint8','double'} % LABEL-Matrix
			 if isempty(obj.frameSize)
				obj.frameSize = size(regionDef);
			 end
			 % TODO
		  otherwise
			 warning('RoiSet:addRegion:UnknownInput','Region definition format is unkown')
		end
		return
	 end
	 function addCC(obj, CC)
		% Remove components that don't meet minimum area requirement
		if ~isempty(obj.minArea)
		  numPixels = cellfun(@numel,CC.PixelIdxList);
		  ccOverMin = numPixels >= obj.minArea;
		  CC.NumObjects = sum(ccOverMin);
		  CC.PixelIdxList = CC.PixelIdxList(ccOverMin);
		  numPixels = numPixels(ccOverMin);
		  % Sort by CCs by size;
		  [nPixSorted,idx] = sort(numPixels);
		  CC.PixelIdxList = CC.PixelIdxList(fliplr(idx));
		  % Get RegionProps
		  RP = regionprops(CC,obj.rpFields{:});
		  % PASS CC TO RP-ADDITION-METHOD
		  obj.addRP(obj, RP);
		end
	 end
	 function addRP(obj,RP, varargin)
		% Eventually calls the class method 'addregion()' with RegionOfInterest array as input (perhaps recursively)
		if nargin > 2
		  BW = varargin{1};
		else
		  BW = obj.rp2bw(RP);
		end
		bwFrame.bwMask = BW;
		bwFrame.RegionProps = RP;
		roiArray = RegionOfInterest(bwFrame);
		obj.addRegion(roiArray);
	 end
  end
  methods
	 % RANDOM SUBFUNCTION (MOVE)
	 function BW = cc2bw(obj, CC)
		% Make Binary image
		BW = false(CC.ImageSize);
		BW(cat(1,CC.PixelIdxList{:})) = true;
	 end
	 function BW = rp2bw(obj, RP)
		pxIdx = cat(1,RP.PixelIdxList);
		if isempty(obj.frameSize)
		  % assume square & power-of-2 frame size based on pixel indices
		  maxidx = max(pxIdx);
		  sqsize = 2.^(1:12);
		  framePow2 = find(sqsize > sqrt(maxidx),1,'first');
		  obj.frameSize = [2^framePow2 2^framePow2];
		  warning('Assuming frame size')
		end
		BW = false(obj.frameSize);
		BW(pxIdx) = true;
	 end
  end
  methods % CLEANUP
	 function delete(obj)
      % 		try
      % 		  if ~isempty(obj.potentialRegion)
      % 			 delete(obj.potentialRegion);
      % 		  end
      % 		  if ~isempty(obj.superRegion)
      % 			 delete(obj.superRegion);
      % 		  end
      % 		  if~isempty(obj.subRegion) && isvalid(obj.subRegion)
      % 			 delete(obj.subRegion);
      % 		  end
      % 		catch
      % 		  clear obj
      % 		end
	 end
  end
  
end














