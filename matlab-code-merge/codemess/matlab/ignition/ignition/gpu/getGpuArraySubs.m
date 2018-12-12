function [rowSubs,colSubs,varargout] = getGpuArraySubs(F)

%			>> [rowSubs,colSubs,frameSubs,chanSubs] = getGpuArraySubs(F)


g1 = gpuArray.ones(1,'int32');

gSize = gpuArray(int32(size(F)));
rowSubs = reshape(gpuArray.colon(g1,gSize(1)), gSize(1), 1);
colSubs = reshape(gpuArray.colon(g1,gSize(2)), 1, gSize(2));
try
	frameSubs = reshape(gpuArray.colon(g1,gSize(3)), 1, 1, gSize(3));
catch
	frameSubs = g1;
end
try
	chanSubs = reshape(gpuArray.colon(g1,gSize(4)), 1, 1, 1, gSize(4));
catch
	chanSubs = g1;
end

if nargout>2
	higherDims = {frameSubs,chanSubs};
	varargout = higherDims(1:(nargout-2));
end




% sz = size(F);
% r = num2cell(ones(1,numel(sz)));
% for k=1:numel(sz)
% rshape=r;
% rshape{k} = sz(k);
% subs{k} = int32(reshape(1:sz(k), rshape{:}));
% end





% [n1,n2,n3,n4] = size(F);
% numRows = gpuArray(int32(n1));
% numCols = gpuArray(int32(n2));
% numFrames = gpuArray(int32(n3));
% if nargout>3
% 	varargout{1} = gpuArray(int32(n4));
% end
