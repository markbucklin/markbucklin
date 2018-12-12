function [D,movingReg] = imregdemonsFP(moving,fixed,varargin)
%IMREGDEMONS Estimate displacement field that aligns two 2-D images.
%
%   [D,MOVING_REG] = IMREGDEMONS(MOVING,FIXED) estimates the displacement
%   field gpuArray D that aligns the moving image in gpuArray MOVING with the fixed
%   image in gpuArray FIXED. MOVING and FIXED are 2-D intensity images. For
%   a 2-D registration problem with a FIXED image of size MxN, the output
%   displacement field D is a double matrix of size MxNx2 in which D(:,:,1)
%   contains X displacements and D(:,:,2) contains Y displacements with
%   magnitude values in units of pixels.  The displacement vectors at each
%   pixel location map locations from the FIXED image grid to a
%   corresponding location in the MOVING image. MOVING_REG is a gpuArray
%   which contains a warped version of the MOVING image that is warped by D
%   and resampled using linear interpolation.
%
%   [___] = IMREGDEMONS(MOVING,FIXED,N) estimates the displacement field D
%   that aligns the moving image, MOVING, with the fixed image, FIXED. The
%   optional third input argument, N, controls the number of iterations
%   that will be computed. If N is not specified, a default value of 100
%   iterations is used at each pyramid level. This function does not use a
%   convergence criterion and therefore is always guaranteed to run for the
%   specified or default number of iterations, N. N must be integer valued
%   and greater than 0.
%
%   D = IMREGDEMONS(___,NAME,VALUE) registers the
%   moving image using name-value pairs to control aspects of the
%   registration.
%
%   Parameters include:
%
%      'AccumulatedFieldSmoothing'  -   Standard deviation of the Gaussian
%                                       smoothing applied to regularize the
%                                       accumulated field at each
%                                       iteration. This parameter controls
%                                       the amount of diffusion-like
%                                       regularization. Larger values will
%                                       result in more smooth output
%                                       displacement fields. Smaller values
%                                       will result in more localized
%                                       deformation in the output
%                                       displacement field.
%                                       AccumulatedFieldSmoothing is
%                                       typically in the range [0.5, 3.0].
%                                       When multiple PyramidLevels are
%                                       used, the standard deviation used
%                                       in Gaussian smoothing remains the
%                                       same at each pyramid level.
%
%                                           Default: 1.0.
%
% Example
% ---------
% This example solves a registration problem in which the same hand has
% been photographed in two different poses. The misalignment of the images
% varies locally throughout each image. This is therefore a non-rigid
% registration problem.
%
% fixed  = imread('hands1.jpg');
% moving = imread('hands2.jpg');
%
% % Observe initial misalignment. Fingers are in different poses.
% figure
% imshowpair(fixed,moving,'montage')
% figure
% imshowpair(fixed,moving)
%
% fixedGPU  = gpuArray(fixed);
% movingGPU = gpuArray(moving);
%
% fixedGPU  = rgb2gray(fixedGPU);
% movingGPU = rgb2gray(movingGPU);
%
% % Use histogram matching to correct illumination differences between
% % moving and fixed. This is a common pre-processing step.
% fixedHist = imhist(fixedGPU);
% movingGPU = histeq(movingGPU,fixedHist);
%
% [~,movingReg] = imregdemons(movingGPU,fixedGPU,[500 400 200],'AccumulatedFieldSmoothing',1.3);
%
% % Bring movingReg back to CPU
% movingReg = gather(movingReg);
%
% figure
% imshowpair(fixed,movingReg)
% figure
% imshowpair(fixed,movingReg,'montage')
%
% See also IMREGCORR, IMREGISTER, IMREGTFORM, IMSHOWPAIR, IMWARP.

%   Copyright 2014 The MathWorks, Inc.

%   References:
%   -----------
%   [1] J.-P. Thirion, "Image matching as a diffusion process: an analogy
%   with Maxwell's demons", Medical Image Analysis, VOL. 2, NO. 3, 1998
%
%   [2] T. Vercauteren, X. Pennec, A. Perchant, N. Ayache, "Diffeomorphic
%   Demons: Efficient Non-parametric Image Registration", NeuroImage, VOL.
%   45, ISSUE 1, SUPPLEMENT 1, MARCH 2009

narginchk(2,inf);

[moving,fixed] = validateInputImages(moving,fixed);

% varargin = gatherIfNecessary(varargin{:});

options = images.registration.internal.parseOptionalDemonsInputs(varargin{:});

images.registration.internal.validatePyramiding(moving,fixed,options.PyramidLevels);

classMoving = classUnderlying(moving);

% Do intermediate math in double precision floating point.
fixed  = double(fixed);
moving = double(moving);

% Initialize accumulated field
sizeFixed = size(fixed);
Da_x = gpuArray.zeros(sizeFixed);
Da_y = gpuArray.zeros(sizeFixed);

if (options.PyramidLevels > 1)
	
	[fixed,padVec]  = images.registration.internal.padForPyramiding(fixed,options.PyramidLevels);
	moving = images.registration.internal.padForPyramiding(moving,options.PyramidLevels);
	Da_x = images.registration.internal.padForPyramiding(Da_x,options.PyramidLevels);
	Da_y = images.registration.internal.padForPyramiding(Da_y,options.PyramidLevels);
	
	% As an initialization, we have to move the initial condition of the
	% accumulated field to the resolution of the lowest resolution section
	% of the pyramid.
	Da_x = resampleFieldComponentByScaleFactor(Da_x,0.5^(options.PyramidLevels-1));
	Da_y = resampleFieldComponentByScaleFactor(Da_y,0.5^(options.PyramidLevels-1));
	
	for p = 1:options.PyramidLevels
		
		% Form the downsampled image grids for the current resolution
		% level.
		movingAtLevel = downsampleFromFullResToPyramidLevel(moving,p,options.PyramidLevels);
		fixedAtLevel  = downsampleFromFullResToPyramidLevel(fixed,p,options.PyramidLevels);
		
		if p > 1
			% Upsample the displacement field estimate for use in the next
			% resolution level.
			Da_x = resampleFieldComponentByScaleFactor(Da_x,2);
			Da_y = resampleFieldComponentByScaleFactor(Da_y,2);
		end
		
		% Solve displacement field at current resolution level.
		[Da_x,Da_y] = demons2d(movingAtLevel,fixedAtLevel,options.NumIterations(p),...
			options.AccumulatedFieldSmoothing,Da_x,Da_y);
		
	end
	
	% Trim accumulated field pixels that are artifacts of padding used in
	% pyramiding.
	Da_x = trimPaddingFromOutputFieldComponent(Da_x,padVec);
	Da_y = trimPaddingFromOutputFieldComponent(Da_y,padVec);
	
else
	
	[Da_x,Da_y] = demons2d(moving,fixed,options.NumIterations,...
		options.AccumulatedFieldSmoothing,Da_x,Da_y);
	
end

D = cat(3,Da_x,Da_y);

if nargout > 1
	movingReg = resampleMovingWithEdgeSmoothing(moving,Da_x,Da_y);
	% Return output resampled image in a datatype consistent with the input moving image.
	movingReg = cast(movingReg,classMoving);
end


end
function smoothedOutputImage = resampleMovingWithEdgeSmoothing(moving,Da_x,Da_y)

sizeFixed = size(Da_x);
xIntrinsicFixed = 1:sizeFixed(2);
yIntrinsicFixed = 1:sizeFixed(1);
[xIntrinsicFixed,yIntrinsicFixed] = meshgrid(xIntrinsicFixed,yIntrinsicFixed);

Uintrinsic = xIntrinsicFixed + Da_x;
Vintrinsic = yIntrinsicFixed + Da_y;
smoothedOutputImage = interp2(padarray(moving,[1 1]),Uintrinsic+1,Vintrinsic+1,'linear',0);

end
function out = trimPaddingFromOutputFieldComponent(in,padVec)

%out = in(1:end-padVec(1),1:end-padVec(2));
out = subsref(in,substruct('()',{1:size(in,1)-padVec(1),1:size(in,2)-padVec(2)}));

end
function B = downsampleFromFullResToPyramidLevel(A,level,numLevels)

imageScaleFactor = 0.5 .^ (numLevels-level);
B = imresize(A,imageScaleFactor,'cubic');

end
function Dout = resampleFieldComponentByScaleFactor(Din,scaleFactor)

Dout = imresize(Din,scaleFactor,'cubic');

% Now adjust for relative scale difference in displacement
% magnitudes
Dout = Dout .* scaleFactor;

end
function [Da_x,Da_y] = demons2d(moving,fixed,N,sigma,Da_x,Da_y)

% Cache plaid representation of fixed image grid.
sizeFixed = size(fixed);
xIntrinsicFixed = gpuArray(1:sizeFixed(2));
yIntrinsicFixed = gpuArray(1:sizeFixed(1));
[xIntrinsicFixed,yIntrinsicFixed] = meshgrid(xIntrinsicFixed,yIntrinsicFixed);

% Initialize Gaussian filtering kernel
r = ceil(3*sigma);
d = 2*r+1;
hGaussian = gpuArray(fspecial('gaussian',[d d],sigma));

% Initialize gradient of F for passive force Thirion Demons
[FgradX,FgradY] = imgradientxy(fixed,'CentralDifference');
FgradMagSquared = FgradX.^2+FgradY.^2;

% Function scoped broadcast variables for use in zeroUpdateThresholding
IntensityDifferenceThreshold = 0.001;
DenominatorThreshold = 1e-9;

for i = 1:N
	
	movingWarped = interp2(moving,...
		xIntrinsicFixed + Da_x,...
		yIntrinsicFixed + Da_y,...
		'linear',...
		NaN);
	
	[Da_x,Da_y] = arrayfun(@computeUpdateFieldAndComposeWithAccumulatedField,fixed,FgradX, FgradY, FgradMagSquared, movingWarped,Da_x,Da_y);
	
	% Regularize vector field by gaussian smoothing.
	Da_x = imfilterFP(Da_x, hGaussian,'replicate');
	Da_y = imfilterFP(Da_y, hGaussian,'replicate');
	
end

	function [Da_x, Da_y] = computeUpdateFieldAndComposeWithAccumulatedField(fixed,FgradX, FgradY, FgradMagSquared, movingWarped,Da_x,Da_y)
		
		FixedMinusMovingWarped = fixed-movingWarped;
		denominator =  (FgradMagSquared + FixedMinusMovingWarped.^2);
		
		% Compute additional displacement field - Thirion
		directionallyConstFactor = FixedMinusMovingWarped ./ denominator;
		Du_x = directionallyConstFactor .* FgradX;
		Du_y = directionallyConstFactor .* FgradY;
		
		
		if (denominator < DenominatorThreshold) |...
				(abs(FixedMinusMovingWarped) < IntensityDifferenceThreshold) |...
				isnan(FixedMinusMovingWarped) %#ok<OR2>
			
			Du_x = 0;
			Du_y = 0;
			
		end
		
		% Compute total displacement vector - additive update
		Da_x = Da_x + Du_x;
		Da_y = Da_y + Du_y;
		
	end


end
function [moving,fixed] = validateInputImages(moving,fixed)

supportedImageClasses = {'uint8','uint16','uint32','int8','int16','int32','single','double','logical'};
supportedImageAttributes = {'real','finite','nonempty','2d'};

moving = gpuArray(moving);
fixed  = gpuArray(fixed);

hValidateAttributes(moving,supportedImageClasses,supportedImageAttributes,...
	mfilename,'MOVING',1);

hValidateAttributes(fixed,supportedImageClasses,supportedImageAttributes,...
	mfilename,'FIXED',2);

end

function b = imfilterFP(varargin)
%IMFILTER N-D filtering of multidimensional images.
%   B = IMFILTER(A,H) filters the multidimensional array A with the
%   filter H.  A can be logical or it can be a nonsparse numeric
%   array of any class and dimension.  The result, B, has the same
%   size and class as A.  When A is a gpuArray object, H must be a
%   vector or 2-D matrix.
%
%   Each element of the output, B, is computed using either single-
%   or double-precision floating point, depending on the data type
%   of A.  When A contains double-precision or UINT32 values, the
%   computations are performed using double-precision values.  All
%   other data types use single-precision.  If A is an integer or
%   logical array, then output elements that exceed the range of
%   the given type are truncated, and fractional values are rounded.
%
%   B = IMFILTER(A,H,OPTION1,OPTION2,...) performs multidimensional
%   filtering according to the specified options.  Option arguments can
%   have the following values:
%
%   - Boundary options
%
%       X            Input array values outside the bounds of the array
%                    are implicitly assumed to have the value X.  When no
%                    boundary option is specified, IMFILTER uses X = 0.
%
%       'symmetric'  Input array values outside the bounds of the array
%                    are computed by mirror-reflecting the array across
%                    the array border.
%
%       'replicate'  Input array values outside the bounds of the array
%                    are assumed to equal the nearest array border
%                    value.
%
%       'circular'   Input array values outside the bounds of the array
%                    are computed by implicitly assuming the input array
%                    is periodic.
%
%   - Output size options
%     (Output size options for IMFILTER are analogous to the SHAPE option
%     in the functions CONV2 and FILTER2.)
%
%       'same'       The output array is the same size as the input
%                    array.  This is the default behavior when no output
%                    size options are specified.
%
%       'full'       The output array is the full filtered result, and so
%                    is larger than the input array.
%
%   - Correlation and convolution
%
%       'corr'       IMFILTER performs multidimensional filtering using
%                    correlation, which is the same way that FILTER2
%                    performs filtering.  When no correlation or
%                    convolution option is specified, IMFILTER uses
%                    correlation.
%
%       'conv'       IMFILTER performs multidimensional filtering using
%                    convolution.
%
%   Example
%   -------------
%       originalRGB = gpuArray(imread('peppers.png'));
%       h = fspecial('motion',50,45);
%       filteredRGB = imfilter(originalRGB,h);
%       figure, imshow(originalRGB)
%       figure, imshow(filteredRGB)
%       boundaryReplicateRGB = imfilter(originalRGB,h,'replicate');
%       figure, imshow(boundaryReplicateRGB)
%
%   See also FSPECIAL, GPUARRAY/CONV2, GPUARRAY/CONVN, GPUARRAY/FILTER2,
%            GPUARRAY.

%   Copyright 1993-2014 The MathWorks, Inc.
persistent separableFlag
persistent u
persistent s
persistent v
persistent finalSizeLast

[a, h, boundary, sameSize] = parse_inputs(varargin{:});

[finalSize, pad] = computeSizes(a, h, sameSize);

if ~isempty(finalSizeLast) && finalSize(1) == finalSizeLast(1)
	separableFlag = [];
end
finalSizeLast = finalSize;
%Empty Inputs
% 'Same' output then size(b) = size(a)
% 'Full' output then size(b) = size(h)+size(a)-1
if isempty(a)
	
	b = handleEmptyImage(a, sameSize, finalSize);
	return
	
elseif isempty(h)
	
	b = handleEmptyFilter(a, sameSize, finalSize);
	return
	
end

boundaryStr = boundary;
padVal      = 0;
if(~ischar(boundary))
	boundaryStr = 'constant';
	padVal      = boundary;
end

%Special case
% If the filter kernel is 3x3 and same size output is requested.
if(ismatrix(a) && isequal(size(h),[3 3]) && sameSize...
		&& isreal(a) && isreal(h) && ~strcmp(boundaryStr,'circular'))
	
	h      = gpuArray(double(h));
	padVal = cast(gather(padVal), classUnderlying(a));
	b      = imfiltergpumex(a, h, boundaryStr, padVal);
	return;
	
end

if isempty(separableFlag)
	[separableFlag, u, s, v] = isSeparable(a, h);
end
%Special case
% If the filter kernel is separable, input is to be zero-padded and output
% is requested at the same size, use conv2 instead of convn.
useConv2 = separableFlag && padVal==0 && strcmp(boundaryStr,'constant') && sameSize;
if useConv2
	
	% extract the components of the separable filter
	hcol = u(:,1) * sqrt(s(1));
	hrow = v(:,1)' * sqrt(s(1));
	
	origClass = classUnderlying(a);
	[a,sameClass] = convertToFloat(a,origClass);
	
	% perform convolution plane-by-plane
	sub.type = '()';
	sub.subs = {':',':',1};
	for zInd = 1:size(a,3)
		
		% handle planes one at a time
		sub.subs{3} = zInd;
		
		a = subsasgn(a, sub, ...
			conv2(hrow, hcol, subsref(a,sub), 'same'));
	end
	
	if ~sameClass
		b = cast(a, origClass);
	else
		b = a;
	end
	
	return;
end

% zero-pad input based on dimensions of filter kernel.
a = padarray(a,pad,boundaryStr,'both');


if (separableFlag)
	
	% extract the components of the separable filter
	hcol = u(:,1) * sqrt(s(1));
	hrow = v(:,1)' * sqrt(s(1));
	
	% cast data to appropriate floating point type
	origClass = classUnderlying(a);
	[a,sameClass] = convertToFloat(a,origClass);
	
	% apply the first component of the separable filter (hrow)
	out_size_row = [size(a,1) finalSize(2:end)];
	start = [0 pad(2:end)];
	b_tmp = filterPartOrWhole(a, out_size_row, hrow, start+1, sameSize);
	
	% apply the other component of the separable filter (hcol)
	start = [pad(1) 0 pad(3:end)];
	b = filterPartOrWhole(b_tmp, finalSize, hcol, start+1, sameSize);
	
	% cast back to input datatype
	if ~sameClass
		b = cast(b, origClass);
	end
	
else % non-separable filter case
	
	% cast data to appropriate floating point type
	origClass = classUnderlying(a);
	[a,sameClass] = convertToFloat(a,origClass);
	
	b = filterPartOrWhole(a, finalSize, h, pad+1, sameSize);
	
	% cast back to input datatype
	if (~sameClass)
		b = castData(b, origClass);
	end
end
end

%--------------------------------------------------------------
function [a, h, boundary, sameSize] = parse_inputs(a, h, varargin)

narginchk(2,5);

if ~isa(a, 'gpuArray')
	error(message('images:imfilter:gpuImageType'))
end

if (~ismatrix(h))
	error(message('images:imfilter:gpuFilterKernelDims'))
end

%Assign defaults
boundary = 0;  %Scalar value of zero
output = 'same';
do_fcn = 'corr';

allStrings = {'replicate', 'symmetric', 'circular', 'conv', 'corr', ...
	'full','same'};

for k = 1:length(varargin)
	if ischar(varargin{k})
		string = validatestring(varargin{k}, allStrings,...
			mfilename, 'OPTION',k+2);
		switch string
			case {'replicate', 'symmetric', 'circular'}
				boundary = string;
			case {'full','same'}
				output = string;
			case {'conv','corr'}
				do_fcn = string;
		end
	else
		validateattributes(varargin{k},{'numeric'},{'nonsparse'},mfilename,'OPTION',k+2);
		boundary = varargin{k};
	end %else
end

sameSize = strcmp(output,'same');

convMode = strcmp(do_fcn,'conv');

% Rotate kernel for correlation
if isa(h, 'gpuArray')
	if ~convMode
		h = rot90(h,2);
	end
else
	if convMode
		h = gpuArray(h);
	else
		% For convMode, filter must be rotated. Do this on the CPU for
		% small sizes, as it is likely to be slow.
		if numel(h) < 100000
			h = gpuArray(rot90(h,2));
		else
			h = rot90(gpuArray(h),2);
		end
	end
end
end
%--------------------------------------------------------------
function [separable, u, s, v] = isSeparable(a, h)

% check for filter separability
if strcmp(classUnderlying(a),'double')
	sep_threshold = 150;
else
	sep_threshold = 900;
end
subs.type = '()';
subs.subs = {':'};

if ((numel(h) >= sep_threshold) && ...
		ndims(a)<=3 &&...
		ismatrix(h) && ...
		all(size(h) ~= 1) && ...
		all(isfinite(subsref(h,subs))))
	
	[u, s, v] = svd(gather(h));
	s = diag(s);
	tol = length(h) * s(1) * eps;
	rank = sum(s > tol);
	
	if (rank == 1)
		separable = true;
	else
		separable = false;
	end
	
else
	
	separable = false;
	u = [];
	s = [];
	v = [];
	
end
end
%--------------------------------------------------------------
function b = handleEmptyImage(a, sameSize, im_size)

if (sameSize)
	
	b = a;
	
else
	
	if all(im_size >= 0)
		
		b = zeros(im_size, 'like', a);
		
	else
		
		error(message('images:imfilter:negativeDimensionBadSizeB'))
		
	end
	
end
end
%--------------------------------------------------------------
function b = handleEmptyFilter(a, sameSize, im_size)

if (sameSize)
	
	b = zeros(size(a), 'like', a);
	
else
	
	if all(im_size>=0)
		
		b = zeros(im_size, 'like', a);
		
	else
		
		error(message('images:imfilter:negativeDimensionBadSizeB'))
		
	end
	
end
end
%--------------------------------------------------------------
function [finalSize, pad] = computeSizes(a, h, sameSize)

rank_a = ndims(a);
rank_h = ndims(h);

% Pad dimensions with ones if filter and image rank are different
size_h = [size(h) ones(1,rank_a-rank_h)];
size_a = [size(a) ones(1,rank_h-rank_a)];

if (sameSize)
	%Same output
	finalSize = size_a;
	
	%Calculate the number of pad pixels
	filter_center = floor((size_h + 1)/2);
	pad = size_h - filter_center;
else
	%Full output
	finalSize = size_a+size_h-1;
	pad = size_h - 1;
end
end
%--------------------------------------------------------------
function a = filterPartOrWhole(a, outSize, h1, outputStartIdx, sameSize)

if (sameSize)
	sizeFlag = 'same';
else
	sizeFlag = 'full';
end

a = convn(a, h1, sizeFlag);

% Retrieve the part of the image that's required.
sRHS.type = '()';
sRHS.subs = {outputStartIdx(1):(outputStartIdx(1) + outSize(1) - 1), ...
	outputStartIdx(2):(outputStartIdx(2) + outSize(2) - 1)};
for ind = 3:ndims(a)
	sRHS.subs{ind} = ':';
end

a = subsref(a, sRHS);
end
%--------------------------------------------------------------
function [a,sameClass] = convertToFloat(a,origClass)
% Convert input matrix to double if datatype is uint32, else convert to
% single.

switch (origClass)
	case {'double','uint32'}
		sameClass = strcmp(origClass,'double');
		
		if ~sameClass
			a = double(a);
		end
		
	otherwise
		sameClass = strcmp(origClass,'single');
		
		if ~sameClass
			a = single(a);
		end
end
end
%--------------------------------------------------------------
function result = castData(result, origClass)

if (strcmp(origClass, 'logical'))
	result = result >= 0.5;
else
	result = cast(result, origClass);
end
end

