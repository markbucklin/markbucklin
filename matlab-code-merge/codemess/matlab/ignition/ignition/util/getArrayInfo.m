function info = getArrayInfo(t)
%getArrayInfo Retrieve information about tall array.
%   S = getArrayInfo(T) returns in S a struct describing what is known and what
%   is not known about tall array T. (It is an error if T is not tall).
%
%   The fields of S are:
%   'Class'    - the underlying type of T, or '' if not known
%   'Ndims'    - the number of dimensions of T, or NaN if not known
%   'Size'     - the underlying size of T. If 'Ndims' is NaN, this will be empty,
%                otherwise it is a vector of length Ndims. Some elements will be
%                NaN if they are not known.
%   'Gathered' - logical scalar indicating whether the value has already been
%                gathered. When 'Gathered' is TRUE, this implies that calling
%                GATHER is "free".
%   'Error'    - if an error was encountered attempting to gather information, the
%                relevant MException is here. This error might well indicate that an
%                error would be thrown during GATHER.

% Copyright 2016 The MathWorks, Inc.

assert(istall(t), 'getArrayInfo is valid only for tall arrays.');

s = struct('Class', '', ...
           'Ndims', NaN, ...
           'Size', [], ...
           'Gathered', false, ...
           'Error', MException.empty());
try
    info = iGatherInfo(s, t);
catch E
    info = s;
    info.Error = E;
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to actually gather the information
function s = iGatherInfo(s, t)

partitionedArray = hGetValueImpl(t);
s.Gathered = matlab.bigdata.internal.util.isGathered(partitionedArray);

if s.Gathered
    % The Adaptor doesn't get updated when things are gathered, but we can simply
    % query the underlying value.
    value   = partitionedArray.ValueFuture.Value;
    s.Class = class(value);
    s.Ndims = ndims(value);
    s.Size  = size(value);
else
    adaptor = hGetAdaptor(t);
    s.Class = adaptor.Class;
    s.Ndims = adaptor.NDims;
    s.Size  = adaptor.Size;
end
end
