function bench = comparePeakFitFcn(c)


fast.fcn = @getPeakSubpixelOffset_MomentMethod;
precise.fcn = @getPeakSubpixelOffset_PolyFit;

fast.t = gputimeit(@() fast.fcn(c), 2);
precise.t = gputimeit(@() precise.fcn(c), 2);

fast.dydx = fast.fcn(c);
precise.dydx = precise.fcn(c);

bench.fast = fast;
bench.precise = precise;
bench.sse = sum((bench.precise.dydx(:) - bench.fast.dydx(:)).^2);
bench.dt = (bench.precise.t - bench.fast.t) / bench.fast.t;



	function [spdy, spdx] = getPeakSubpixelOffset_MomentMethod(c)
		cSum = sum(sum(c));
		d = size(c,1);
		r = floor(d/2);
		spdx = .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (1:d), c))), cSum) - r ) ...
			+ .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (-d:-1), c))), cSum) + r );
		spdy = .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (1:d)', c))), cSum) - r ) ...
			+ .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (-d:-1)', c))), cSum) + r );
		
	end


	function [spdy, spdx] = getPeakSubpixelOffset_PolyFit(c)
		% POLYNOMIAL FIT, c = Xb
		[cNumRows, cNumCols, cNumFrames] = size(c);
		d = cNumRows;
		r = floor(d/2);
		[xg,yg] = meshgrid(-r:r, -r:r);
		x=xg(:);
		y=yg(:);
		X = [ones(size(x),'like',x) , x , y , x.*y , x.^2, y.^2];
		b = X \ reshape(c, cNumRows*cNumCols, cNumFrames);
		if (cNumFrames == 1)
			spdx = (-b(3)*b(4)+2*b(6)*b(2)) / (b(4)^2-4*b(5)*b(6));
			spdy = -1 / ( b(4)^2-4*b(5)*b(6))*(b(4)*b(2)-2*b(5)*b(3));
		else
			spdx = reshape(...
				(-b(3,:).*b(4,:) + 2*b(6,:).*b(2,:))...
				./ (b(4,:).^2 - 4*b(5,:).*b(6,:)), ...
				1, 1, cNumFrames);
			spdy = reshape(...
				-1 ./ ...
				( b(4,:).^2 - 4*b(5,:).*b(6,:)) ...
				.* (b(4,:).*b(2,:) - 2*b(5,:).*b(3,:)), ...
				1, 1, cNumFrames);
		end
	end

end
