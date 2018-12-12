function dataType = getDataType(F)
% rename to getNumericDataType ??


% dataType = getNumericDataType( ignition.shared.getNumericFrameData(F) );


if isnumeric(F)
	% NUMERIC
	dataType = getNumericDataType(F);
	
elseif isobject(F)
	% CLASS OBJECT (DATA CONTAINER)
	if ismethod(F,'getDataType')
		% CALL GETDATATYPE METHOD
		dataType = getDataType(F);
	elseif ismethod(F,'getData')
		% CALL GETDATA METHOD
		dataType = getNumericDataType(getData(F(1)));
	elseif isprop(F,'Data')
		% DATA PROPERTY
		dataType = getNumericDataType(F(1).Data);
	else
		% TRY RECURSIVE CALL WITH STRUCT
		dataType = ignition.shared.getDataType(struct(F(1)));
	end
	
elseif isstruct(F)
	% STRUCTURE ARRAY OF FRAMES (e.g. from getframe(gca))
	validDataFieldNames = {'data','Data','Value','CData','cdata'};
	frameStructFields = fields(Finput);
	% DETERMINE IF ANY FIELDS MATCH A KNOWN LIST OF COMMON FIELD NAMES FOR DATA
	for k=1:numel(frameStructFields)
		dataFieldRecognized = strcmp(frameStructFields{k},validDataFieldNames);
		if any(dataFieldRecognized)
			% CALL SUBFUNCTION WITH EXTRACTED DATA
			dataType = getNumericDataType( F(1).(frameStructFields{k}) );
			
		end
	end
	
elseif iscell(F)
	% CELL -> USE FIRST CELL CONTENTS
	dataType = getNumericDataType( F{1} );
	
else
	% UNKNOWN
	error(message('Ignition:GetDataType:UnknownInputType'),mfilename)
end




end

% FUNCTION THAT QUICKLY RETURNS CLASS-NAME (TYPE) OF NUMERIC DATA
function type = getNumericDataType(data)


if isa(data, 'gpuArray')
	type = classUnderlying(data);
else
	type = class(data);
end


end










% CELL -> CHECK TYPE OF ALL (POTENTIAL CELLULAR OUTPUT)
% 	if numel(F) > 1
% 		allTypes = cellfun(@getNumericDataType, F,...
% 			'UniformOutput', false);
% 		if strcmp(allTypes{1}, allTypes(2:end))
% 			dataType = allTypes{1};
% 		else
% 			dataType = allTypes;
% 		end
% 	else
% 		dataType = getNumericDataType( F{1} );
% 	end





