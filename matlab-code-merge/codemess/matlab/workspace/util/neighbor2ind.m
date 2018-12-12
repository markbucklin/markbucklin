function ind = neighbor2ind(sz,conn)
%NEIGHBOR2IND Get pairs of indices for neighboring elements in an array.
%   IND = NEIGHBOR2IND(SZ,CONN) returns a P-by-2 array of paired indices
%   representing neighboring elements in an array. The inputs are the size
%   of the array, given as [rows cols], and the neighborhood connectivity. 
%   Valid options for connectivity are 4 (default) or 8.
%
%   Notes:
%   1) For 4-connectivity, the order is [N,E,S,W].
%
%   2) For 8-connectivity, the order is [N,NE,E,SE,S,SW,W,NW]. 
%
%   Examples:
%   1) Get the neighboring pairs for a 3-by-4 matrix with 4-connectivity:
%
%       ind = neighbor2ind([3 4]);
%
%   2) Get the neighboring pairs for a 600-by-800 matrix with 8-connectivity:
%
%       ind = neighbor2ind([600 800],8);
%
%   MRE 10/9/15

%% Parse inputs
if nargin<2 || isempty(conn)
    conn = 4;
end
m = sz(1);
n = sz(2);
idx = 1:m*n;

%% Set up neighbor offsets based on connectivity
if isequal(conn,4)
    %[N,E,S,W]
    offsets = [-1, m, 1, -m];
elseif isequal(conn,8)
    %[N,NE,E,SE,S,SW,W,NW]
    offsets = [-1, m-1, m, m+1, 1, -m+1, -m, -m-1];
end

%% Get indices of neighboring pairs
ii = repmat(idx,conn,1);
jj = bsxfun(@plus,idx,offsets');

%% Create mask to remove invalid pairs (border pixels do not have certain neighbors)
mask = true(size(ii));
if isequal(conn,4)
    mask(1,1:m:end) = false; %N
    mask(2,end-m+1:end) = false; %E
    mask(3,m:m:end) = false; %S
    mask(4,1:m) = false; %W
elseif isequal(conn,8)
    mask(1,1:m:end) = false; %N
    mask(2,[1:m:end,end-m+1:end]) = false; %NE
    mask(3,end-m+1:end) = false; %E
    mask(4,[end-m+1:end,m:m:end]) = false; %SE
    mask(5,m:m:end) = false; %S
    mask(6,[m:m:end,1:m]) = false; %SW
    mask(7,1:m) = false; %W
    mask(8,[1:m:end,1:m]) = false; %NW
end

%% Set output
ind = [ii(mask),jj(mask)];

end

