function pxNearNeighborDominance = nearNeighborDominanceElementWise(f, fu, fr, fd, fl, su, sr, sd, sl)

	Gu = min(min(min( f, fl), fd), fr) > max(max( sl, su), sr);
	Gr = min(min(min( f, fu), fl), fd) > max(max( su, sr), sd);
	Gd = min(min(min( f, fl), fu), fr) > max(max( sl, sd), sr);
	Gl = min(min(min( f, fu), fr), fd) > max(max( su, sl), sd);

pxNearNeighborDominance = ...
	(Gu & Gr & Gd) |...
	(Gu & Gl & Gd) |...
	(Gl & Gu & Gr) |...
	(Gl & Gd & Gr);




% SUBFUNCTION: CALLED FOR EACH DIAMETER TESTED
			% 			function bw = findFg(F,ds)
			% 				if isa(F, 'gpuArray')
			% 					% RUNNING USING ARRAYFUN ON GPU
			% 					[nrows,ncols,~] = size(F);
			% 					Fu = F([1, 1:nrows-1], :, :);
			% 					Fd = F([2:nrows, nrows], :,:);
			% 					Fl = F(:, [1, 1:ncols-1],:);
			% 					Fr = F(:, [2:ncols, ncols], :);
			% 					Su = F([ones(1,ds), 1:nrows-ds], :, :);
			% 					Sd = F([ds+1:nrows, nrows.*ones(1,ds)], :, :);
			% 					Sl = F(:, [ones(1,ds), 1:ncols-ds], :);
			% 					Sr = F(:, [ds+1:ncols, ncols.*ones(1,ds)], :);
			% 					bw = arrayfun(@findPixelForegroundElementWise, F, Fu, Fr, Fd, Fl, Su, Sr, Sd, Sl);
			% 				else
			% 					% OR BSXFUN ON CPU
			% 					bw = findPixelForegroundArrayWise(F,ds);
			% 				end
			% 			end