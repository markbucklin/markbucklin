function [obj, varargout] = generatePropagatingRegions(labelMatrix, F)

% INPUT MAY INCLUDE INTENSITY-IMAGE F (same size as labelMatrix)
if nargin < 2
	F = [];
	stats = LinkedRegion.regionStats.shape;
else
	stats = LinkedRegion.regionStats.faster;
end

% LOCAL VARIABLES
[nRows, nCols, N] = size(labelMatrix);
frameSize = [nRows, nCols];
frameIdx = 0;
gatherRegions = (nargout>1);
if gatherRegions
	rcell = cell(N,1);
end

% INITIALIZE WITH FIRST FRAME
k=1;
if isempty(F)
	rp = regionprops(labelMatrix(:,:,k), stats{:});
else
	rp = regionprops(labelMatrix(:,:,k), F(:,:,k), stats{:});
end
rk = FrameLinkedRegion(rp, 'FrameIdx', frameIdx+k, 'FrameSize', frameSize);
if gatherRegions
	rcell{1} = rk;
end
obj = PropagatingRegion(rk);
fprintf('Round %i  - %i PropagatingRegions\t\n',k, numel(obj))

% RUN SAME PROCEDURE ON ALL OTHER FRAMES
for k=2:N
	try
	tStart = hat;
	
	% GET REGIONPROPS STRUCTURE ARRAY FROM LABELMATRIX
	if isempty(F)
		rp = regionprops(labelMatrix(:,:,k), stats{:});
	else
		rp = regionprops(labelMatrix(:,:,k), F(:,:,k), stats{:});
	end
	
	% CONVERT INTO FRAMELINKEDREGION OBJECT
	rk = FrameLinkedRegion(rp, 'FrameIdx', frameIdx+k, 'FrameSize', frameSize);
	if gatherRegions
		rcell{k} = rk;
	end
	
	% PASS TO PROPAGATINGREGION ARRAY TO TRACK DEVELOPMENT OVER TIME
	[obj, splitPropRegion, newPropRegion] = propagate(obj, rk);
	
	% COMBINE OLD PROPAGATINGREGION OBJECTS WITH NEWLY-FOUND & NEWLY SPLIT OBJECTS
	if ~isempty(splitPropRegion);
		obj = cat(1, obj, splitPropRegion);
	end
	if ~isempty(newPropRegion)
		obj = cat(1, obj, newPropRegion);
	end

	% PRINT COMPUTATING TIME FOR SINGLE FRAME
	tFinish = hat-tStart;
	fprintf('Round %i:\t\t %i PropagatingRegions\t (%-3.4gms)\n',k, numel(obj), tFinish*1000)		
	
	catch me
		msg = getError(me);
		disp(msg);
		
	end
end

if gatherRegions
	varargout{1} = rcell;
end


updateEssentialProps(obj)
averageScalarProps(obj)

