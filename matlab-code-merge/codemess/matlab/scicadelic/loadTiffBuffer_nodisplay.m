function [frameData, frameTime, frameInfo] = loadTiffBuffer( bufferRef, frameIdx)

buf = bufferRef.Value;

% GRAB ALL CONSTANT (ANONYMOUS) FUNCTIONS
parseinfo = buf.stackInfo.parseFrameInfoFcn;
isvalididx = buf.stackInfo.isValidIdx;
getvalididx = buf.stackInfo.getValidIdx;
lookfileidx = buf.stackInfo.lookupFileIdx;
lookrelidx = buf.stackInfo.lookupRelIdx;

% RETRIEVE VALID FRAME INDICES & RELATIVE & MAP IDX
valididx = isvalididx(frameIdx);
frameidx = getvalididx(frameIdx);
fileidx = lookfileidx(frameIdx);
relidx = lookrelidx(frameIdx);

% LOAD FRAMES ONE AT A TIME
k=0;
while k < numel(frameidx)
	k = k + 1;
	idx = relidx(k);
	tiffobj = buf.tiffObj(fileidx(k));
	if (currentDirectory(tiffObj) ~= idx)
		setDirectory(tiffObj, idx);
	end
	
	% READ A FRAME OF DATA
	datacell{k} = read(tiffObj);
	
	% READ TIMESTAMP & FRAMEINFO
	[t, info] = parse(tiffObj);
	
	% FILL IN ANY MISSING INFO
	info.FrameNumber = frameidx(k);
	info.TriggerIndex = fileidx(k);
	
	frameTime(k,1) = t;
	infocell{k} = info;
		
	if ~lastDirectory(tiffObj)		
		nextDirectory(tiffObj);
	end	

end
	
frameData = cat(4, datacell{:});
frameInfo = cat(1, info{:});


end