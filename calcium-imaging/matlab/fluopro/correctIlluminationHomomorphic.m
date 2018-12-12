function [data, varargout] = correctIlluminationHomomorphic(datainput, fcnparam)
% Implemented by Mark Bucklin 6/12/2014
%
% FROM WIKIPEDIA ENTRY ON HOMOMORPHIC FILTERING
% Homomorphic filtering is a generalized technique for signal and image
% processing, involving a nonlinear mapping to a different domain in which
% linear filter techniques are applied, followed by mapping back to the
% original domain. This concept was developed in the 1960s by Thomas
% Stockham, Alan V. Oppenheim, and Ronald W. Schafer at MIT.
%
% Homomorphic filter is sometimes used for image enhancement. It
% simultaneously normalizes the brightness across an image and increases
% contrast. Here homomorphic filtering is used to remove multiplicative
% noise. Illumination and reflectance are not separable, but their
% approximate locations in the frequency domain may be located. Since
% illumination and reflectance combine multiplicatively, the components are
% made additive by taking the logarithm of the image intensity, so that
% these multiplicative components of the image can be separated linearly in
% the frequency domain. Illumination variations can be thought of as a
% multiplicative noise, and can be reduced by filtering in the log domain.
%
% To make the illumination of an image more even, the high-frequency
% components are increased and low-frequency components are decreased,
% because the high-frequency components are assumed to represent mostly the
% reflectance in the scene (the amount of light reflected off the object in
% the scene), whereas the low-frequency components are assumed to represent
% mostly the illumination in the scene. That is, high-pass filtering is
% used to suppress low frequencies and amplify high frequencies, in the
% log-intensity domain.[1]
%
% More info HERE: http://www.cs.sfu.ca/~stella/papers/blairthesis/main/node35.html
%% DEFINE PARAMETERS and PROCESS INPUT
% gpu = gpuDevice(1);
% CONSTRUCT HIGH-PASS (or Low-Pass) FILTER

global FPOPTION
checkFluoProOptions();

% ------------------------------------------------------------------------------------------
% CHECK INPUT - CONVERT DATA TO NUMERIC 3D-ARRAY
% ------------------------------------------------------------------------------------------
if isstruct(datainput)
   data = cat(3, datainput.cdata);
else
   data = datainput;
end

% ------------------------------------------------------------------------------------------
% CHECK GPU-PROCESSING ABILITY
% ------------------------------------------------------------------------------------------
if isempty(FPOPTION) || isempty(FPOPTION.useGpu)
   try
	  gpu = gpuDevice;
	  if gpu.isCurrent() && gpu.DeviceSupported
		 FPOPTION.useGpu = true;
	  else
		 FPOPTION.useGpu = false;
	  end
   catch
	  FPOPTION.useGpu = false;
   end
end

% ------------------------------------------------------------------------------------------
% DATA-DESCRIPTION VARIABLES
% ------------------------------------------------------------------------------------------
sz = size(data);
N = sz(3);
nPixPerFrame = sz(1) * sz(2);
inputDataType = class(data);

% ------------------------------------------------------------------------------------------
% FUNCTION PARAMETERS (AUTO-GENERATED IF NOT PROVIDED AS INPUT)
% ------------------------------------------------------------------------------------------
if nargin < 2
   fcnparam.sigma = (1/20) * min(sz(1:2));
   fcnparam.filtSize = ceil(2 * fcnparam.sigma + 1);      
   fcnparam.outputDataType = inputDataType;   
   fcnparam.consistent.dmax = double(max(data(:)));
   fcnparam.consistent.dmin = double(min(data(:)));
   fcnparam.consistent.outputRange = double([0 intmax(fcnparam.outputDataType)]);
end

% ------------------------------------------------------------------------------------------
% GET CONSISTENT RANGE FOR CONVERSION TO FLOATING POINT INTENSITY IMAGE
% ------------------------------------------------------------------------------------------
inputScale = single(fcnparam.consistent.dmax - fcnparam.consistent.dmin);
inputOffset = single(fcnparam.consistent.dmin);
outputScale = fcnparam.consistent.outputRange(2) - fcnparam.consistent.outputRange(1);
outputOffset = fcnparam.consistent.outputRange(1);

% ------------------------------------------------------------------------------------------
% CONSTRUCT LOW-PASS GAUSSIAN FILTER
% ------------------------------------------------------------------------------------------
if FPOPTION.useGpu
   hLP = gpuArray(fspecial('gaussian',fcnparam.filtSize,fcnparam.sigma));
else
   hLP = fspecial('gaussian',fcnparam.filtSize,fcnparam.sigma);
end

% ------------------------------------------------------------------------------------------
% USE A CONSISTENT ILLUMINATION BASELINE
% ------------------------------------------------------------------------------------------
if ~isfield(fcnparam.consistent, 'logIlluminationBaseline')
   io = [];
else
   io = fcnparam.consistent.logIlluminationBaseline;
end

% ------------------------------------------------------------------------------------------
% FILTER TO EACH FRAME INDIVIDUALLY
% ------------------------------------------------------------------------------------------
hWaitBar = waitbar(0, 'Correcting Illumination using Homomorphic Filter');
for k=1:N
   waitbar(k/N, hWaitBar);
   data(:,:,k) = homFiltSingleFrame(data(:,:,k));
end
close(hWaitBar)

% ------------------------------------------------------------------------------------------
% SAVE ILLUMINATION BASELINE
% ------------------------------------------------------------------------------------------
fcnparam.consistent.logIlluminationBaseline = io;


% TODO: alternative function for applying same filter to all frames simultaneously


% ------------------------------------------------------------------------------------------
% PASS FUNCTION PARAMETERS AS OUTPUT FOR USE WITH REST OF SET
% ------------------------------------------------------------------------------------------
if nargout > 1
   varargout{1} = fcnparam;
end






% ################################################################
% GENERATE & APPLY FILTER TO EACH FRAME INDIVIDUALLY
% ################################################################
   function im = homFiltSingleFrame( im)
	  % 	  persistent ioLast
	  % ------------------------------------------------------------------------------------------
	  % CONVERT TO INTENSITY IMAGE (& TRANSFER TO GPU IF OPTION SELECTED)
	  % ------------------------------------------------------------------------------------------
	  if FPOPTION.useGpu
		 imGray =  (single(gpuArray(im))-inputOffset)./inputScale;
	  else
		 imGray =  (double(im)-inputOffset)./inputScale;
	  end
	  % 	  % USE MEAN TO DETERMINE A SCALAR BASELINE ILLUMINATION INTENSITY IN LOG DOMAIN
	  % 	  io = log( mean(imGray(imGray<median(imGray(:))))); % mean of lower 50% of pixels		% {0..0.69}
	  % 	  if isnan(io)
	  % 		 if ~isempty(ioLast)
	  % 			io = ioLast;
	  % 		 else
	  % 			io = .1;
	  % 		 end
	  % 	  end
	  % ------------------------------------------------------------------------------------------
	  % LOWPASS-FILTERED IMAGE (IN LOG-DOMAIN) REPRESENTS UNEVEN ILLUMINATION
	  % ------------------------------------------------------------------------------------------
	  imGray = log1p(imGray); % log(imGray + 1);
	  imLp = imfilter( imGray, hLP, 'replicate');
	  if isempty(io)
		 io = mean(imLp(imLp<median(imLp(:))));
	  end
		
	  % ------------------------------------------------------------------------------------------
	  % SUBTRACT LOW-FREQUENCY "ILLUMINATION" COMPONENT
	  % ------------------------------------------------------------------------------------------
	  
	  imGray = expm1( imGray - imLp + io); % exp( imGray - imLp + io) - 1;
	  
	  % ------------------------------------------------------------------------------------------
	  % RESCALE AND CONVERT BACK TO ORIGINAL DATATYPE
	  % ------------------------------------------------------------------------------------------
	  imGray = imGray .* outputScale  + outputOffset;
	  if FPOPTION.useGpu
		 im = gather(cast(imGray, fcnparam.outputDataType));
	  else
		 im = cast(imGray, fcnparam.outputDataType);
	  end
	  % 	  ioLast = io;
	  
   end
end



























% CLEAN UP LOW-END (SATURATE TO ZERO OR 100)
% 	  im(im<fcnparam.consistent.outputRange(1)) = fcnparam.consistent.outputRange(1);
% fcnParameterNames = {...
%    'sigma',...
%    'filtSize',...
%    'outputDataType',...
%    'consistent'};