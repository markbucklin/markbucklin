function [frameTime, frameInfo] = parseHamamatsuTiffTag(tiffObj, numFrames)
% parseHamamatsuTiffTag()
%
%			>> [frameTime, frameInfo] = parseHamamatsuTiffTag(tiffObj)
%			>> [frameTime, frameInfo] = parseHamamatsuTiffTag(tiffObj, numFrames)
%
% Second argument specifies BOTH how many frames are read AND how many times tiffObj is advanced to
% the next directory. If numFrames is not provided or given as empty [], 1 frame (tiff-directory)
% will be parsed and the TIFF object will be left at the same 'currentDirectory' as when passed as
% input.
%
% Mark Bucklin
% 2016
%

% DEFAULT TO NUMFRAMES = 1
if nargin < 2
	numFrames = [];
end

% TIFF-TAG ID FOR IMAGE-DESCRIPTION TAG (MISCELLANEOUS INFO)
persistent imageDescriptionTagID
persistent pageNumberTagID
if isempty(imageDescriptionTagID)
	imageDescriptionTagID = Tiff.TagID.ImageDescription;
end
if isempty(pageNumberTagID)
	pageNumberTagID = Tiff.TagID.PageNumber;
end

% VIDEO-INPUT COMPATIBLE FRAME INFO (metadata)
% frameInfo.AbsTime = [];
% frameInfo.FrameNumber = [];
% frameInfo.RelativeFrame = [];
% frameInfo.TriggerIndex = [];


if isempty(numFrames)
	
	% ----------------------------------------------
	% UNSPECIFIED NUMBER-OF-FRAMES -> SINGLE-FRAME
	% ----------------------------------------------
	% GET IMAGE DESCRIPTION TEXT
	imageDescriptionTagText = tiffObj.getTag(imageDescriptionTagID);
	
	% PAGE NUMBER TO FRAME-RELATIVE IDX ?
	tiffPageNum = getTag(tiffObj, pageNumberTagID);
	pageNum = tiffPageNum(1) + 1;
	
	% NUMBER OF FRAMES SUCCESSFULLY READ (1)
	numFramesRead = 1;
	
	% ABSOLUTE TIME (LOW-PRECISION)
	absDateVec = getVecFromSingleText(imageDescriptionTagText);
	
	% PARSE IMAGE DESCRIPTION TEXT -> FRAME-TIME
	hmsTokens = regexp( imageDescriptionTagText,...
		' Time_From_Start = (\d*):(\d*):(\d*.\d*)', 'tokens');
	tfsNum = str2double(hmsTokens{:});
	
	% ADD HOURS:MINUTES:SECONDS TO GET FRAME-TIME
	frameTime = tfsNum(1)*3600 + tfsNum(2)*60 + tfsNum(3);
	
	% FILL FRAME-INFO
	frameInfo.AbsTime = absDateVec;
	frameInfo.FrameNumber = [];
	frameInfo.RelativeFrame = pageNum;
	frameInfo.TriggerIndex = [];
	
else
	
	% ----------------------------------------------
	% MULTI-FRAME READ (FOR EFFICIENCY/SPEED)
	% ----------------------------------------------
	txtCell = cell(numFrames,1);
	pageNumCell = cell(numFrames,1);
	k = 0;
	while (k < numFrames)
		k = k + 1;
		
		% GET IMAGE DESCRIPTION TEXT
		txtCell{k} = tiffObj.getTag(imageDescriptionTagID);
		
		% PAGE NUMBER TO FRAME-RELATIVE IDX ?
		tiffPageNum = getTag(tiffObj, pageNumberTagID);
		pageNumCell{k,1} = tiffPageNum(1) + 1;
		
		% CHECK FILE-ID NOT LAST-DIRECTORY
		if ~lastDirectory(tiffObj)
			
			% INCREMENT FILE-ID CURRENT-DIRECTORY
			nextDirectory(tiffObj);
		else
			pageNumCell = pageNumCell(1:k);
			break
		end
	end
	
	% INDICATE NUMBER OF FRAMES SUCCESSFULLY READ
	numFramesRead = k;
	imageDescriptionTagText = cat(2, txtCell{:});
	
	% ABSOLUTE TIME (LOW-PRECISION)
	absDateVec = getVecFromMultiText(imageDescriptionTagText);
	
	% PARSE IMAGE DESCRIPTION TEXT -> FRAME-TIME
	hmsTokens = regexp( imageDescriptionTagText,...
		' Time_From_Start = (\d*):(\d*):(\d*.\d*)', 'tokens');
	tfsNum = str2double(cat(1,hmsTokens{:}));
	
	% ADD HOURS:MINUTES:SECONDS TO GET FRAME-TIME
	frameTime = sum( bsxfun(@times, tfsNum, [3600 60 1]), 2);
	
	% FILL FRAME-INFO
	n = numFramesRead;
	frameInfo = struct(...
		'AbsTime', num2cell(absDateVec, 2), ...
		'FrameNumber', cell(n,1), ...
		'RelativeFrame', pageNumCell, ...
		'TriggerIndex', cell(n,1) );
	
	
end








	function vec = getVecFromSingleText(txt)	
		% 'Sun, 08 Nov 2015 15:12:59 Eastern Standard Time'
		absDateToken = regexp(txt,'[SMTWF]\w*, (\d* \w* \d* \d*:\d*:\d*)', 'tokens')';
		absDateStr = absDateToken{1};
		% 		absDateNum = datenum(absDateStr, 'ddmmmyyyyHHMMSS');
		vec = datevec(absDateStr, 'dd mmm yyyy HH:MM:SS');
		
	end
	function vec = getVecFromMultiText(txt)		
		% 'Sun, 08 Nov 2015 15:12:59 Eastern Standard Time'
		absDateToken = regexp(txt,'[SMTWF]\w*, (\d* \w* \d* \d*:\d*:\d*)', 'tokens')';		
		absDateStr = cat(1, absDateToken{:});
		% 		absDateNum = datenum(absDateStr, 'ddmmmyyyyHHMMSS');
		vec = datevec(absDateStr, 'dd mmm yyyy HH:MM:SS');
				
	end



end





















