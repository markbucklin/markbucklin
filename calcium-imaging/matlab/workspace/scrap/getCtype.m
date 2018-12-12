function  ctype = getCtype(A) %#codegen
warning('getCtype.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
%GETCTYPE Get the C data type string
%
if(isa(A,'logical'))
    ctype = 'boolean';
elseif(isa(A,'single'))
    ctype = 'real32';
elseif(isa(A,'double'))
    ctype = 'real64';    
else
    % default
    ctype = class(A);
end

