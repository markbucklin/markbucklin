function out = forEach( fcn, in, numOut, dim)


if nargin < 4
    dim = max(cellfun(@ndims, in));
end
if nargin < 3
    numOut = 1;
end
N = size(in{1},dim);

for k = 1:N
    
end