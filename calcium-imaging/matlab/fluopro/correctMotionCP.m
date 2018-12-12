function correctMotionCP(data)

global FPOPTION

sz = size(data);
N = sz(ndims(data));
























% ################################################################
   function cp = selectControlPointsAutomatic(F, winSize)
	  if numel(winSize) <2
		 winSize = [winSize winSize];
	  end	  
	  winSize = ceil(winSize);	  
	  w = max(winSize);
	  gaussfilt = @(X) imfilter(X,fspecial('gaussian', w, 1.5));
	  winfilt = @(X) imfilter(X, fspecial('average', w));
	  
	  % GET GRADIENT
	  [Fx, Fy, Ft] = gradient(single(gaussfilt(F)));
	  cornFcn = @(Ix,Iy) (gaussfilt(abs(Ix)).*gaussfilt(abs(Iy))) - .5*(gaussfilt(Ix.^2) + gaussfilt(Iy.^2));
	  fxmedt = median(Fx,3);
	  fymedt = median(Fy,3);
	  ftmedt = median(Ft,3);
	  
	  fxctrl = (fxmedt.^2)./std(Fx,1,3);
	  fyctrl = (fymedt.^2)./std(Fy,1,3);
	  fxctrl(fxctrl<0) = 0;
	  fxctrl(fxctrl>1000) = 1000;
	  fyctrl(fyctrl<0) = 0;
	  fyctrl(fyctrl>1000) = 1000;
	  [Fxmx,Fxmy] = gradient(fxctrl);
	  [Fymx,Fymy] = gradient(fxctrl);
	  
	  
	  Fs = log(abs(bsxfun(@rdivide,...
		 bsxfun(@minus, winfilt(abs(Fxmx)), winfilt(Fx)) ,...
		 bsxfun(@minus, winfilt(abs(Fymy)), winfilt(Fy))))+1);
	  
	  
	  
	  
   end


end






