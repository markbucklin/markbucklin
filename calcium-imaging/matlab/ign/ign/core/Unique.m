classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible) ...
		Unique
	
	
	
	
	
	
	
	properties (SetAccess = private)
		UniqueID
	end
	properties (SetAccess = private, Hidden)
		StringID = '00000000-0000-0000-0000-000000000000'
		NumericID = 0+0*1i
		UniqueName = ''
	end
	properties (Constant, Hidden)
		IDType = 'string'
	end
	
	
	
	
	methods
		function obj = Unique(uid)
			
			% GENERATE OR ASSIGN GLOBALLY-UNIQUE-IDENTIFICATION: 128-BIT HEX STRING
			if nargin < 1
				switch obj.IDType
					case 'string'
						uid = generateGUID();
					case 'integer'
						uid = getSharedCounter('UniqueInstanceCount');
				end
			end
			
			% ASSIGN UNIQUE UniqueID
			obj = setUniqueID(obj, uid);
			
			% GET UNIQUE NAME: <CLASS>_<PID>_<INSTANCECOUNT>
			obj.UniqueName = getUniqueName(class(obj));
			
			
		end
		function obj = setUniqueID(obj, uid)
			
			if ischar(uid)
				assert( nnz(isstrprop(uid,'xdigit')) == 32)
				obj.StringID = uid;
				obj.NumericID = str2NumID(uid);
				
			elseif isnumeric(uid)
				obj.NumericID = uid;
				obj.StringID = num2str(uid);
				
			else
				% todo
			end
			obj.UniqueID = uid;
			
		end
	end
	methods
		function bool = eq( elA, elB )
			% Custom/overloaded equality definition that only compares UniqueID
			%todo: may not have same instance count or PID if UniqueID was passed to constructor, such as would
			% happen during serialization for saving/loading or inter-process transfer
			
			% 			if isa(elA, 'handle') && isa(elB, 'handle')
			% BUILTIN HANDLE COMPARISON
			% 				bool = builtin('eq', elA, elB);
			% 				bool = eq@handle(elA,elB);
			
			% 			else
			% CONVERT 128-BIT HEXADECIMAL STRING TO 128-BIT COMPLEX DOUBLE
			%idA = char2numID(cat(1,elA.UniqueID)); idB = char2numID(cat(1,elB.UniqueID));
			
			% RESHAPE TO MATCH SIZE OF INPUT
			%idA = reshape(idA, size(elA)); idB = reshape(idB, size(elB));
			
			idA = reshape([elA.NumericID], size(elA));
			idB = reshape([elB.NumericID], size(elB));
			
			% USE BUILTIN DOUBLE COMPARISON
			bool = eq(idA,idB);
			
			% 			end
		end
	end
	
	
	
end




function numID = str2NumID(strID)

% GET HEX CHARACTERS
try
	hexMask = isstrprop(strID(1,:), 'xdigit');
catch
	hexMask = [1:8, 10:13, 15:18, 20:23, 25:size(strID,2)];
end

% CONVERT -> 32 HEX CHARS -> 16 BYTES -> 2 REAL DOUBLES -> 1 COMPLEX DOUBLE
hexID = strID(:,hexMask);
decID = hex2byte(reshape( hexID', 2, [])')';
tupleID = reshape( typecast(decID, 'double'), 2, [])';
numID = tupleID(:,1) + tupleID(:,2).*1i;

end
function b = hex2byte(h)
% LOCAL VERSION OF HEX2DEC (FEWER CHECK -> FASTER)
h = upper(h);
[m,n]=size(h);
sixteen = 16;
p = fliplr(cumprod([1 sixteen(ones(1,n-1))]));
p = p(ones(m,1),:);

% NUMBERS
d = h <= 64;
h(d) = h(d) - 48;

% LETTERS
d =  h > 64;
h(d) = h(d) - 55;
d = sum(h.*p,2);

% CONVERT TO UINT8
b = uint8(d);

end


