function [dy, dx] = findCorrPeakSubpixelOffset(c, method)

if nargin < 2
	method = 'moment';
end

[cNumRows, cNumCols, cNumFrames] = size(c);
d = cNumRows;
r = floor(d/2);
centerIdx = r+1;
peakDomain = -r:r;

[xg,yg] = meshgrid(peakDomain, peakDomain);





switch lower(method)
	case 'moment'
		cSum = sum(sum(c));
		dx = .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (1:d), c))), cSum) - (r + 1)) ...
			+ .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (-d:-1), c))), cSum) + (r + 1));
		dy = .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (1:d)', c))), cSum) - (r + 1)) ...
			+ .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (-d:-1)', c))), cSum) + (r + 1));
		
	case 'poly'
		% POLYNOMIAL FIT, c = Xb
		x=xg(:);
		y=yg(:);
		err = ones(size(x),'like',x);
		X = [err, x , y , x.*y , x.^2, y.^2];
		b = X\reshape(c, cNumRows*cNumCols, cNumFrames);
		dx = reshape(...
			(-b(3,:).*b(4,:) + 2*b(6,:).*b(2,:))...
			./ (b(4,:).^2 - 4*b(5,:).*b(6,:)), ...
			1, 1, cNumFrames);
		dy = reshape(...
			-1 ./ ...
			( b(4,:).^2 - 4*b(5,:).*b(6,:)) ...
			.* (b(4,:).*b(2,:) - 2*b(5,:).*b(3,:)), ...
			1, 1, cNumFrames);
		
	case 'gauss'
		x=xg(:);
		y=yg(:);
		err = ones(size(x),'like',x);
		X = [err ,  x.^2 , y.^2 , x , y];
		b = X\reshape(log(max(eps(c), c)), cNumRows*cNumCols, cNumFrames);
		w2 = -1./(2*b(2,:).*b(3,:));
		x0 = w2 .* b(4,:);
		y0 = w2 .* b(5,:);
		dx = reshape(x0, 1, 1, cNumFrames);
		dy = reshape(y0, 1, 1, cNumFrames);
		
	case 'closedgauss'
		x0 = centerIdx;
		y0 = centerIdx;
		if cNumFrames == 1
		dx = (c(x0+1,y0) - c(x0-1,y0)) ./ (2*c(x0,y0) - c(x0+1,y0) - c(x0-1,y0));
		dy = (c(x0,y0+1) - c(x0,y0-1)) ./ (2*c(x0,y0) - c(x0,y0+1) - c(x0,y0-1));
		else
			dx = (c(x0+1,y0,:) - c(x0-1,y0,:)) ./ (2*c(x0,y0,:) - c(x0+1,y0,:) - c(x0-1,y0,:));
			dy = (c(x0,y0+1,:) - c(x0,y0-1,:)) ./ (2*c(x0,y0,:) - c(x0,y0+1,:) - c(x0,y0-1,:));
		end
	case 'esinc'
		x = double(oncpu(xg));
		y = double(oncpu(yg));
		cIn = double(oncpu(c));
		eSinc = @(a1,a2,x0,y0) ...
			a1*exp(-a2*((x-x0).^2 + (y-y0).^2)) ...
			.* .5*(sin(pi*(x-x0))./(pi*(x-x0)) + sin(pi*(y-y0))./(pi*(y-y0)));
		eSincP = @(p) eSinc(p(1),p(2),p(3),p(4));
		opfcn = @(p) sum(sum(bsxfun(@minus, cIn, eSincP(p)).^2));
		pInit = [max(cIn(:)), .5, .1, .1] ;
		% 		options.Algorithm = 'levenberg-marquardt';
		% 		options = optimoptions('levenberg-marquardt','UseParallel',true);
		pOut = lsqnonlin(opfcn,pInit);
		% 		[pOut,resnorm,residual,exitflag,output,lambda,jacobian]
		dx = cast(pOut(3), 'like',c);
		dy = cast(pOut(4), 'like',c);
		
	case 'esinc2' % TODO: check that this function is appropriate (2D function extended from 1D argyriou et.al.)
		% 		esinc1 = @(a1,a2,x0) a1*exp(-a2*((x-x0).^2)) .* (sin(pi*(x-x0))./(pi*(x-x0)));
		
		eSinc = @(a1,a2,a3,x0,y0) ...
			a1*exp(-a2*((xg-x0).^2 + (yg-y0).^2)) ...
			.* (.5*sin(pi*(xg-x0)).*cos(pi*(yg-y0))./(pi*(xg-x0))...
			+ .5*sin(pi*(yg-y0)).*cos(pi*(xg-x0))./(pi*(yg-y0))) ...
			+ a3;
		eSincP = @(p) eSinc(p(1),p(2),p(3),p(4),p(5));
		opfcn = @(p) sum(sum(bsxfun(@minus, c, eSincP(p)).^2));
		pInit = [max(c(:)), d/3, min(c(:)), 0, 0] + eps;
		pOut = lsqnonlin(opfcn,pInit);		
		dx = pOut(4);%3
		dy = pOut(5);%4
		
	case 'gaussellip'		
		c = double(oncpu(c));
		ellipGaussPeakFcn = @(a1,x0,y0,wx,wy) ...
			(log(a1) - x0^2/(2*wx^2) - y0^2/(2*wy^2)) ...
			+ (-.5/wx^2) * xg.^2 ...
			+ (x0/wx^2) * xg ...
			+ (-.5/wy^2) * yg.^2 ...
			+ (y0/wy^2) * yg ;
		pInit = [.5, 0, 0, 1, 1] + eps; % ub = [1, 1, 1, 1.5, 1.5]; lb = [.01, -1, -1, 0.1, 0.1];		 		
		opfcn = @(p) sum(sum(exp(bsxfun(@minus, log(c), ellipGaussPeakFcn(p(1),p(2),p(3),p(4),p(5))).^2)));		
		pOut = lsqnonlin(opfcn, pInit);		
		dx = pOut(2);
		dy = pOut(3);			
		
	
		
		
end






% eSinc = @(a1,a2,x0,y0) ...
% 			a1*exp(-a2*((x-x0).^2 + (y-y0).^2)) ...
% 			.* .5*(sin(pi*(x-x0))./(pi*(x-x0)) + sin(pi*(y-y0))./(pi*(y-y0)));



% c = double(oncpu(c));
% ellipGaussPeakFcn = @(a1,x0,y0,wx,wy) ...
% 			(log(a1) - x0^2/(2*wx^2) - y0^2/(2*wy^2)) ...
% 			+ (-.5/wx^2) * x.^2 ...
% 			+ (x0/wx^2) * x ...
% 			+ (-.5/wy^2) * y.^2 ...
% 			+ (y0/wy^2) * y ;
% 		pInit = [.5, 0, 0, 1, 1] + eps; % ub = [1, 1, 1, 1.5, 1.5]; lb = [.01, -1, -1, 0.1, 0.1];		 		
% 		opfcn = @(p) sum(sum(exp(bsxfun(@minus, log(c), ellipGaussPeakFcn(p(1),p(2),p(3),p(4),p(5))).^2)));		
% 		pOut = lsqnonlin(opfcn, pInit);		
% 		dx = pOut(2);
% 		dy = pOut(3);			
% 		

% esincFitType = fittype(@(a1,a2,x0,y0,x,y) a1*exp(-a2*((x-x0).^2 + (y-y0).^2)) .* (sin(pi*(x-x0))./(pi*(x-x0)) + sin(pi*(y-y0))./(pi*(y-y0))),...
% 	'coefficients',{'a1','a2','x0','y0'},'independent',{'x','y'}, 'dependent','z');
