function propBlocks = getLabeledPropertyBlocks( className )
try
	propBlocks = struct.empty();
	
	% LOAD CLASS FILE -> READ TEXT
	fname = which(className);
	fid = fopen(fname);
	ftext = textscan(fid, '%s','delimiter','\n','whitespace','');
	ftext = ftext{1};
	
	% FIND COMMENT BLOCKS
	commentLabelPattern = '\s*\%\s*([\w\s\W\/\&\(\)\-]*)';
	[outStart,commentToken] = regexp(ftext, commentLabelPattern,'start','tokens');
	isCommentFirstBlock = cellfun(@(st) ~isempty(st) && (st(1)==1) , outStart);
	
	% FIND BEGINNINGS OF PROPERTY DEFINITION BLOCKS
	propertyBlockPattern = '\s*(properties)\s*';
	outStart = regexp(ftext, propertyBlockPattern,'start');
	isPropertyStartBlock = cellfun(@(st) ~isempty(st) && (st(1)==1) , outStart);
	
	% FIND PROPERTY DEFINITIONS PRECEDED BY COMMENT BLOCKS
	isCommentBeforePropertyBlock = isCommentFirstBlock(:) & [isPropertyStartBlock(2:end) ; false];
	propLabelLineIdx = find(isCommentBeforePropertyBlock);
	propLabelLineText = cellfun(@(txt)txt{1}, commentToken(isCommentBeforePropertyBlock));
	numLabels = numel(propLabelLineIdx);
	
	for kLabel=1:numLabels
		blockLabelString = strtrim(propLabelLineText{kLabel});
		blockPropNames = cell(1,10);
		kProp = 0;
		kLine = propLabelLineIdx(kLabel) + 2;
		propBlockEnd = false;
		numErr=0;
		while true
			try
				txt = ftext{kLine};
				
				if ~isempty(txt)
					lineToken = regexp(txt,'\s*(\w*)\s*', 'tokens','once');
					propToken = lineToken{1};
					
					% BREAK IF A BLOCK HAS ENDED FOLLOWED BY A SPACE
					if propBlockEnd
						if isempty(propToken) || ~isletter(propToken(1))
							break
						end
					end
					
					% CHECK IF PROPERTY-DEFINITION BLOCK IS CONTINUING OR NOT
					if strcmp(propToken,'properties')
						propBlockEnd = false;
					elseif strcmp(propToken,'end')
						propBlockEnd = true;
						
					else
						% CONCATENTATE CELL-ARRAY OF PROPERTIES UNDER CURRENT LABEL
						if ~isempty(propToken) && isletter(propToken(1))
							kProp = kProp + 1;
							blockPropNames{kProp} = propToken;
							% 								blockPropNames = [blockPropNames {propToken}];
						end
					end
				end
			catch
				numErr = numErr + 1;
				if numErr > 10
					break
				end
			end
			
			% INCREMENT TO NEXT LINE
			kLine = kLine + 1;
			
		end
		
		% FILL PROP BLOCK
		if kProp >= 1
			propBlocks(kLabel).Label = blockLabelString;
			propBlocks(kLabel).Properties = blockPropNames(1:kProp);
		end
		
	end
	
catch me
	getReport(me)
end
end