function F = meansub(F, timeDim)
warning('meansub.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

if nargin < 2
	timeDim = ndims(F);
end

if ~isfloat(F)
	switch class(F)
		case 'uint16'
			F = int16(F/2);
			Fmean = int16(mean(F, timeDim));
			F = bsxfun(@minus, F, Fmean).*2;
		case 'uint8'
			F = int8(F/2);
			Fmean = int8(mean(F, timeDim));
			F = bsxfun(@minus, F, Fmean).*2;
		case {'int8','int16'}
			Fmean = cast(mean(F, timeDim), 'like', F);
			F = bsxfun(@minus, F, Fmean);
		otherwise
			Fmean = single(mean(F, timeDim));
			F = single(F);
			F = bsxfun(@minus, F, Fmean);
	end
end
