function f = gemanmcclure(fIn, n)


% CONVERT TO FLOATING POINT
if ~isfloat(fIn)
	f = single(fIn);
else
	f = fIn;
end

if nargin < 2
	n = 1;
end

% CALL (SEMI-)RECURSIVELY IF SECOND ARGUMENT SPECIFIES MULTIPLE OPS
k = n;
while k > 0
	f = mcclurenormfcn(f);
	k=k-1;
end

end



function f = mcclurenormfcn(f)
% RECURSIVE(ABLE) SUBFUNCTION

a = var(f, [], 3);
f2 = f.^2;
f = bsxfun(@rdivide, f2, bsxfun(@plus, f2, a));

% f = bsxfun(@minus, f, mean(min(min(f,[],1),[],2),3));
% f = bsxfun(@rdivide, f, mean(max(max(f,[],1),[],2),3));
% a = (mean(max(f,[],1),2) + mean(max(f,[],2),1)); %*.5
% % a = mean(.5*(mean(max(f,[],1),2) + mean(max(f,[],2),1)), 3);
% f = exp(1) * f.^2 ./ (1 + bsxfun(@rdivide, f.^2 , a.^2));



end





% fMin = min(min(f,[],1),[],2);
% fMax = max(max(f,[],1),[],2);
% fRange = fMax - fMin;

% if nargin <2
% 	a = mean(max(f,[],1),2) + mean(max(f,[],2),1);
% 	a = mean(max(fRange,[],1),2) + mean(max(fRange,[],2),1);
% end





