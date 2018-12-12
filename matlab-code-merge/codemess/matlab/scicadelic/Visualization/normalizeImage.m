function im = normalizeImage(im)
if isa(im, 'gpuArray')
	im = gather(im);
end
im = double(im);

% 				im = imadjust( (im-min(im(:)))./range(im(:)), stretchlim(im, [.05 .995]));




im = max( im, .5*(mean(min(im,[],1)) + mean(min(im,[],2),1)));
im = min( im, .5*(mean(max(im,[],1)) + median(max(im,[],2),1)));
im = imadjust( (im-min(im(:)))./range(im(:)), stretchlim(im, [.10 .9999]));
im = mcclurenormfcn(im);

	function f = mcclurenormfcn(f)
		% Akin to Geman-McClure function
		f = bsxfun(@minus, f, min(min(f,[],1),[],2));
		f = bsxfun(@rdivide, f, max(max(f,[],1),[],2));
		a = .5*(mean(max(f,[],1),2) + mean(max(f,[],2),1));
		f = exp(1) * f.^2 ./ (1 + bsxfun(@rdivide, f.^2 , a.^2));
		
	end

end