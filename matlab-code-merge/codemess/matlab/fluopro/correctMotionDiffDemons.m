function [data, varargout] = correctMotionDiffDemons(data,options)

% ------------------------------------------------------------------------------------------
% INPUT OPTIONS
% ------------------------------------------------------------------------------------------
if nargin < 3
   % For IMREGDEMONS
   options.AccumulatedFieldSmoothing = 5;
   options.PyramidLevels = 4;
   options.NumIterations = [30 20 10 5] ;
   % FOR STABILITY
   options.CorrelationMinTolerance = .50;
end


% ------------------------------------------------------------------------------------------
% CONSTANTS & TRANSFORMATION FUNCTION HANDLES
% ------------------------------------------------------------------------------------------
% m = 10;
N = size(data,3);
if nargout > 1
   getDeformationStats = true;
   U.meanxy = zeros(N,2);
   U.runmeancorr = zeros(N,1);
   ustruct = @() struct('max',zeros(N,1),'median',zeros(N,1),'range',zeros(N,1),'iqr',zeros(N,1));
   U.x = ustruct();
   U.y = ustruct();
else
   getDeformationStats = false;
end

dMax = max(data(:));
dClass = class(data);
toLogDomain = @(X) log1p(double(gpuArray(X))./double(dMax));
fromLogDomain = @(X) gather(cast(expm1(X).*double(dMax), dClass));


% ------------------------------------------------------------------------------------------
% INITIALIZATION
% ------------------------------------------------------------------------------------------
fixedFrame = toLogDomain(data(:,:,1));
fixedRunningMean = fixedFrame;
nf=0;
sizeFixed = size(fixedFrame);
xIntrinsicFixed = 1:sizeFixed(2);
yIntrinsicFixed = 1:sizeFixed(1);
[xIntrinsicFixed,yIntrinsicFixed] = meshgrid(xIntrinsicFixed,yIntrinsicFixed);
Ux = gpuArray.zeros(size(fixedFrame));
Uy = gpuArray.zeros(size(fixedFrame));
Crm = gpuArray.nan(N,1);
uxLast = Ux;
uyLast = Uy;


% ------------------------------------------------------------------------------------------
% RUN ON SEQUENTIAL FRAMES
% ------------------------------------------------------------------------------------------
hWaitbar = waitbar(0, 'Correcting motion via Diffeomorphic-Demons algorithm');
for k=2:size(data,3)
   
   % LOAD NEW MOVING FRAME AND APPLY LAST CORRECTION
   movingFrame = toLogDomain(data(:,:,k));
   preFixedFrame = resampleDisplacedFrame(movingFrame,Ux,Uy);
   
   % GET UPDATE - TODO: Try using PageFun here
   dxyField = imregdemons(preFixedFrame, fixedFrame,...
	  options.NumIterations,...
	  'AccumulatedFieldSmoothing',options.AccumulatedFieldSmoothing,...
	  'PyramidLevels', options.PyramidLevels);   % NOTE: made change to imregdemons at line 172
   Ux = dxyField(:,:,1);
   Uy = dxyField(:,:,2);
   fixedFrame =	resampleDisplacedFrame(preFixedFrame,Ux,Uy);		%movReg/m + (m-1)*fixedFrame/m;
   
   % RECORD A RUNNING MEAN OF STABLE FRAMES
   Crm(k) = corr2(fixedFrame, fixedRunningMean);
   if Crm(k) >= options.CorrelationMinTolerance
	  nt = nf / (nf + 1);
	  na = 1/(nf + 1);
	  fixedRunningMean = fixedRunningMean*nt + fixedFrame*na;
	  nf = nf + 1;
   else
	  % 	  keyboard
	  % 	  fixedFrame = preFixedFrame;
	  % 	  Ux = uxLast;
	  % 	  Uy = uyLast;
   end
   
   % EXTRACT REGISTERED FRAME AND MEAN-DISPLACEMENT
   data(:,:,k) = fromLogDomain(fixedFrame);
   if getDeformationStats
	  U.meanxy(k,:) = gather([mean2(Ux) , mean2(Uy)]); % [dx dy]
	  fillUstats(Ux,Uy,k)
	  
   end
   uxLast = Ux;
   uyLast = Uy;
   waitbar(k/N, hWaitbar)
end
close(hWaitbar)




% ------------------------------------------------------------------------------------------
% OUTPUT
% ------------------------------------------------------------------------------------------
if nargout > 1
   U.runmeancorr = gather(Crm);
   U.runningmean = gather(fixedRunningMean);
   varargout{1} = U;
end



% ################################################################
% RESAMPLING SUBFUNCTION
% ################################################################
   function smoothedOutputImage = resampleDisplacedFrame(moving,Da_x,Da_y)
	  % From builtin function gpuArray\imregdemons resampleMovingWithEdgeSmoothing()
	  % sizeFixed = size(Da_x);
	  % xIntrinsicFixed = 1:sizeFixed(2);
	  % yIntrinsicFixed = 1:sizeFixed(1);
	  % [xIntrinsicFixed,yIntrinsicFixed] = meshgrid(xIntrinsicFixed,yIntrinsicFixed);
	  
	  Uintrinsic = xIntrinsicFixed + Da_x;
	  Vintrinsic = yIntrinsicFixed + Da_y;
	  smoothedOutputImage = interp2(padarray(moving,[1 1]),Uintrinsic+1,Vintrinsic+1,'linear',0);
	  
   end
   function fillUstats(ux,uy,n)
	  fn = fields(U.x);
	  for fk=1:numel(fn)
		 ff = fn{fk};
		 fcn = str2func(ff);
		 U.x.(ff)(n) = gather(fcn(ux(:)));
		 U.y.(ff)(n) = gather(fcn(uy(:)));
	  end
   end



end











% for k=1:19, imshow(cat(1, imfuse(data(:,:,k),data(:,:,k+1),'Scaling','joint'), imfuse(regData(:,:,k),regData(:,:,k+1),'Scaling','joint'))), pause, end