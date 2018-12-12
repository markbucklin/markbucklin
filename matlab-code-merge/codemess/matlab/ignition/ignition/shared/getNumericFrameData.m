function dataFrame = getNumericFrameData( dataInput, useFirstFrameOnly)

% DEFAULT -> RETURN FIRST FRAME ONLY
if nargin<2
	useFirstFrameOnly = true;
end

% DETERIMINE WHICH OF THE VARIOUS FORMS OF IMAGE FRAME CONTAINERS F IS
if isnumeric(dataInput)
	% NUMERIC (SIMPLEST CASE)
	dataFrame = dataInput;
	
else
	%  CONTAINER -> OBJECT, STRUCTURE, or CELL
	if useFirstFrameOnly
		dataContainer=dataInput(1);
	else
		dataContainer = dataInput;
	end
	
	if isobject(dataContainer)
		% CLASS OBJECT (DATA CONTAINER)		
		if ismethod(dataContainer,'getData')
			% CALL GETDATA METHOD
			dataFrame = getData(dataContainer);
		elseif isprop(dataContainer,'Data')
			% DATA PROPERTY
			dataFrame = dataContainer.Data;
		else
			% TRY RECURSIVE CALL WITH STRUCT
			try
			dataFrame = ignition.shared.getNumericFrameData(...
				struct(dataContainer),useFirstFrameOnly);
			catch me
				me = addCause( me, ...
					MException('Ignition:GetNumericFrameData:ObjectAsStruct',...
					['Attempted conversion to struct and recursive call after '], ...
					['no getData method or Data property found from input '], ....
					['of class -> %s'],class(dataContainer)));
				rethrow(me)
			end
		end
		
	elseif isstruct(dataContainer)
		% STRUCTURE ARRAY OF FRAMES (e.g. from getframe(gca))
		validDataFieldNames = {'data','Data','Value','CData','cdata'};
		frameStructFields = fields(Finput);
		% DETERMINE IF ANY FIELDS MATCH A KNOWN LIST OF COMMON FIELD NAMES FOR DATA
		for k=1:numel(frameStructFields)
			dataFieldRecognized = strcmp(frameStructFields{k},validDataFieldNames);
			if any(dataFieldRecognized)
				% CALL SUBFUNCTION WITH EXTRACTED DATA
				dataFrame = dataContainer.(frameStructFields{k});				
			end
		end
		
	elseif iscell(dataContainer)
		% CELL -> USE FIRST CELL CONTENTS
		dataFrame = cat(4,dataContainer{:});
		
	else
		% UNKNOWN
		error(message('Ignition:GetDataType:UnknownInputType'),mfilename)
	end
	
end



end

