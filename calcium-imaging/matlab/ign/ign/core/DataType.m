classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible) ...
		DataType
	
	
	
	
	
	
	enumeration
		Byte
		Char
		Bool
		String
		Uint8
		Int8
		Uint16
		Int16
		Uint32
		Int32
		Uint64
		Int64
		Float32
		Float64
		Complex64
		Complex128
	end
	
	
	
	methods (Static)
		function fcn = getConversionFunction(type)
			persistent conversion_fcn_list
			if isempty(conversion_fcn_list)
				defineConversionFcn()
			end
			if nargin
				fcn = conversion_fcn_list.(lower(type));
			else
				fcn = conversion_fcn_list;
			end
			
			function defineConversionFcn()
				conversion_fcn_list = struct(...
					'char', @(varargin)char([varargin{:},'']),...
					'bool', @(varargin)logical([varargin{:},[]]),...
					'string', @(varargin) wrapCharArray(varargin{:}),...
					'float', @(varargin)single([varargin{:},[]]),...
					'double', @(varargin)double([varargin{:},[]]),...
					'byte', @(varargin)uint8([varargin{:},[]]),...
					'uint8', @(varargin)uint8([varargin{:},[]]),...
					'int8', @(varargin)uint8([varargin{:},[]]),...
					'uint16', @(varargin)uint16([varargin{:},[]]),...
					'int16', @(varargin)int16([varargin{:},[]]),...
					'uint32', @(varargin)uint32([varargin{:},[]]),...
					'int32', @(varargin)int32([varargin{:},[]]),...
					'uint64', @(varargin)uint64([varargin{:},[]]),...
					'int64', @(varargin)int64([varargin{:},[]]),...
					'complex64',@(varargin)single(complex([varargin{:},[]])),...
					'complex128',@(varargin)double(complex([varargin{:},[]])));
			end
		end
	end
	
	
	
	
	
	
	
end







function s = wrapCharArray(c)
if iscell(c)
	if ~iscellstr(c)
		s = cellfun(@char, c, 'UniformOutput', false);
		return
	end
else
	if ischar(c)
		s = {c};
	else
		s = {char(c)};
	end
end
end




% 	properties (Constant)
% 		To = struct(...
% 		'Float', @(varargin)single([varargin{:},[]]),...
% 		'Double', @(varargin)double([varargin{:},[]]),...
% 		'Byte', @(varargin)uint8([varargin{:},[]]),...
% 		'Uint8', @(varargin)uint8([varargin{:},[]]),...
% 		'Int8', @(varargin)uint8([varargin{:},[]]),...
% 		'Uint16', @(varargin)uint16([varargin{:},[]]),...
% 		'Int16', @(varargin)int16([varargin{:},[]]),...
% 		'Uint32', @(varargin)uint32([varargin{:},[]]),...
% 		'Int32', @(varargin)int32([varargin{:},[]]),...
% 		'Uint64', @(varargin)uint64([varargin{:},[]]),...
% 		'Int64', @(varargin)int64([varargin{:},[]]),...
% 		'Char', @(varargin)char([varargin{:},'']),...
% 		'Bool', @(varargin)logical([varargin{:},[]]),...
% 		'String', @(varargin) wrapCharArray(varargin{:}))
% 	end
% 	% todo

% Float = @(varargin)single([varargin{:},[]])
% Double = @(varargin)double([varargin{:},[]])
% Byte = @(varargin)uint8([varargin{:},[]])
% Uint8 = @(varargin)uint8([varargin{:},[]])
% Int8 = @(varargin)uint8([varargin{:},[]])
% Uint16 = @(varargin)uint16([varargin{:},[]])
% Int16 = @(varargin)int16([varargin{:},[]])
% Uint32 = @(varargin)uint32([varargin{:},[]])
% Int32 = @(varargin)int32([varargin{:},[]])
% Uint64 = @(varargin)uint64([varargin{:},[]])
% Int64 = @(varargin)int64([varargin{:},[]])
% Char = @(varargin)char([varargin{:},''])
% Bool = @(varargin)logical([varargin{:},[]])
% %String = @(varargin) iscellstr([varargin{:},[]])