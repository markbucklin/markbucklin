function ty = typeof(x)
% TYPEOF  Extract the underlying data-type of an array
%
%   TY = TYPEOF(X) returns the underlying data-type for an array X. This is
%   classUnderlying(X) for array types that support it, otherwise is
%   class(X).
%
%   Examples:
%   parallel.internal.array.typeof(gpuArray(uint8(1))) % = 'uint8'
%   parallel.internal.array.typeof(single(1))          % = 'single'
%
%   See also: class, classUnderlying.

%   Copyright 2015 The MathWorks, Inc.

% It turns out that querying the existence of the classUnderlying method is
% slow. Just trying it is *much* faster.
try
    ty = classUnderlying(x);
catch err %#ok<NASGU>
    ty = class(x);
end
