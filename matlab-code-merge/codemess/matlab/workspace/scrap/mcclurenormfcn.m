function f = mcclurenormfcn(f)
warning('mcclurenormfcn.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% Akin to Geman-McClure function
f = bsxfun(@minus, f, min(min(f,[],1),[],2));
f = bsxfun(@rdivide, f, max(max(f,[],1),[],2));
a = .5*(mean(max(f,[],1),2) + mean(max(f,[],2),1));
f = exp(1) * f.^2 ./ (1 + bsxfun(@rdivide, f.^2 , a.^2));

end
