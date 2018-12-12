classdef UUID < ign.core.Object
	
	
	properties (SetAccess = immutable)
		Value
	end
	properties (SetAccess = immutable, Hidden)		
		Bytes		
	end	
	
	
	
	methods
		function obj = UUID(hexcanonical)
			
			if nargin < 1
				try
					% MEX IMPLEMENTATION (FASTER, FROM LEV MUCHNIK)
					mexguid = mexCreateGUID();
					hexcanonical = lower(mexguid(2:end-1));
					
				catch
						try
							% TRY JAVA IMPLEMENTATION
							juuid = java.util.UUID.randomUUID();
							hexcanonical = char(juuid.toString);
							% .getLeastSignificantBits
							% .getMostSignificantBits
							
						catch
							% GENERATE UUID STRING USING TEMPNAME FUNCTION (OS-DEPENDENT?)
							[~, tempfileid] = fileparts(tempname);
							if strcmp(tempfileid(1:2),'tp')
								tempfileid = tempfileid(3:end);
							end
							
							% CONVERT HEXADECIMAL CHARACTER ARRAY
							hexcanonical = strrep(tempfileid, '_', '-');
						end
				end
			end
			obj.Value = hexcanonical;
			
			% UINT8 ARRAY -> UUID	[1x16 = 16 Bytes]
			obj.Bytes = canonical2byte(hexcanonical);
			
			
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
	methods (Static)
		function uuid = nil()
			uuid = ign.core.UUID('00000000-0000-0000-0000-000000000000');
		end
	end
	
	
	
	
end

function b = canonical2byte(h)
b = hex2byte( h([1:8, 10:13, 15:18, 20:23, 25:end]));
% ALTERNATIVE
% FORM ARRAY OF HEX CHARS FOR CONVERSION
%		hexarray = strrep(hexcanonical,'-','');
% 	bytelist = hex2byte( hexarray );	
end
function b = hex2byte(h)
% CONVERSION INTO SERIAL BYTE (UINT8) ARRAY
b = uint8(hex2dec(reshape(h,2,[])')');

end
function d = hex2dec(h)
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





