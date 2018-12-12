classdef UUID %< ignition.core.Object
	
	
	properties (SetAccess = immutable)
		Value
	end
	properties (SetAccess = immutable, Hidden)
		Hex
		Bytes
		HashCode
		NumericFull
	end
	properties (Constant, Hidden)
		SCALAR_NUMERIC_TYPE = 'uint64' % Hash code datatype
	end
	
	
	
	methods
		function obj = UUID()
			
			try
				% TRY JAVA IMPLEMENTATION
				juuid = java.util.UUID.randomUUID();
				hexcanonical = char(juuid.toString);
				
			catch
				% GENERATE UUID STRING USING TEMPNAME FUNCTION (OS-DEPENDENT?)
				[~, tempfileid] = fileparts(tempname);
				if strcmp(tempfileid(1:2),'tp')
					tempfileid = tempfileid(3:end);
				end
				
				% CONVERT HEXADECIMAL CHARACTER ARRAY
				hexcanonical = strrep(tempfileid, '_', '-');
			end
			
			% FORM ARRAY OF HEX CHARS FOR CONVERSION
			hexarray = strrep(hexcanonical,'-','');
			
			% UINT8 ARRAY -> UUID	[1x16 = 16 Bytes]
			bytelist = hex2byte( hexarray );
			
			% STORE A BYTE-REDUCED SCALAR VERSION AS A VALID (HASHABLE) MATLAB NUMERIC TYPE
			hashtype = ignition.core.UUID.SCALAR_NUMERIC_TYPE;
			numericfull = typecast(bytelist, hashtype);
			
			% SET IMMUTABLE PROPERTIES FROM VARIOUS FORMS
			obj.Value = hexcanonical;
			obj.Hex = hexarray;
			obj.Bytes = bytelist;
			obj.HashCode = numericfull(1);
			obj.NumericFull = numericfull;
			
		end
		function bool = eq( uuidA, uuidB )
			
			if numel(uuidA)==1 && numel(uuidB)==1
				bool = all( uuidA.Bytes == uuidB.Bytes );
				
			else
				a = reshape(cat(3,uuidA.Bytes), 16,[]);
				b = reshape(cat(4,uuidB.Bytes), 16,1,[]);
				
				bool = squeeze(all( bsxfun( @eq, a, b), 1));
				
			end
			
		end
	end
	
	
	
	
end


function b = hex2byte( h )
% CONVERSION INTO SERIAL BYTE (UINT8) ARRAY
b = uint8(hex2dec(reshape(h,2,[])')');

end
function d = hex2dec( h )
% LOCAL VERSION OF HEX2DEC (FEWER CHECK -> FASTER)
h = upper(h);

[m,n]=size(h);

% Check for out of range values
% if any(any(~((h>='0' & h<='9') | (h>='A'&h<='F'))))
%    error(message('MATLAB:hex2dec:IllegalHexadecimal'));
% end

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

end





