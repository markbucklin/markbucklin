function saveStructImages2Png(f,fdir)

if nargin < 2
   fdir = uigetdir(pwd,'Select a folder for saving images');
end

scaleTo8 = @(X) uint8( double(X-min(X(:))) ./ (double(range(X(:)))/255));
scaleTo16 = @(X) uint16( double(X-min(X(:))) ./ (double(range(X(:)))/65535));

fn = fields(f);
for k=1:numel(fn)
   imTitle = fn{k};
   imRaw = f.(imTitle);
   imwrite(imRaw, fullfile(fdir, [imTitle,'.png']), 'png')
   switch class(imRaw)
	  case 'uint8'
		 imwrite(scaleTo8(imRaw), fullfile(fdir, [imTitle,'_scaled','.png']), 'png')
	  case 'uint16'
		 imwrite(scaleTo16(imRaw), fullfile(fdir, [imTitle,'_scaled','.png']), 'png')
	  otherwise
		 imwrite(scaleTo16(imRaw), fullfile(fdir, [imTitle,'_scaled','.png']), 'png')
   end
end

% inRgbChannel = @(X, ch) scaleTo8(shiftdim(cat(3, zeros([size(X,1) size(X,2) 2], 'like',X),X), ch));


%     PNG-specific parameters
%     -----------------------
%     'Author'       A string
%
%     'Description'  A string
%
%     'Copyright'    A string
%
%     'CreationTime' A string
%
%     'ImageModTime' A MATLAB datenum or a string convertible to a
%                    date vector via the DATEVEC function.  Values
%                    should be in UTC time.
%
%     'Software'     A string
%
%     'Disclaimer'   A string
%
%     'Warning'      A string
%
%     'Source'       A string
%
%     'Comment'      A string
%
%     'InterlaceType' Either 'none' or 'adam7'
%
%     'BitDepth'     A scalar value indicating desired bitdepth;
%                    for grayscale images this can be 1, 2, 4,
%                    8, or 16; for grayscale images with an
%                    alpha channel this can be 8 or 16; for
%                    indexed images this can be 1, 2, 4, or 8;
%                    for truecolor images with or without an
%                    alpha channel this can be 8 or 16
%
%     'Transparency' This value is used to indicate transparency
%                    information when no alpha channel is used.
%
%                    For indexed images: a Q-element vector in
%                      the range [0,1]; Q is no larger than the
%                      colormap length; each value indicates the
%                      transparency associated with the
%                      corresponding colormap entry
%                    For grayscale images: a scalar in the range
%                      [0,1]; the value indicates the grayscale
%                      color to be considered transparent
%                    For truecolor images: a 3-element vector in
%                      the range [0,1]; the value indicates the
%                      truecolor color to be considered
%                      transparent
%
%                    You cannot specify 'Transparency' and
%                    'Alpha' at the same time.
%
%     'Background'   The value specifies background color to be
%                    used when compositing transparent pixels.
%
%                    For indexed images: an integer in the range
%                      [1,P], where P is the colormap length
%                    For grayscale images: a scalar in the range
%                      [0,1]
%                    For truecolor images: a 3-element vector in
%                      the range [0,1]
%
%     'Gamma'        A nonnegative scalar indicating the file
%                    gamma
%
%     'Chromaticities' An 8-element vector [wx wy rx ry gx gy bx
%                    by] that specifies the reference white
%                    point and the primary chromaticities
%
%     'XResolution'  A scalar indicating the number of
%                    pixels/unit in the horizontal direction
%
%     'YResolution'  A scalar indicating the number of
%                    pixels/unit in the vertical direction
%
%     'ResolutionUnit' Either 'unknown' or 'meter'
%
%     'Alpha'        A matrix specifying the transparency of
%                    each pixel individually; the row and column
%                    dimensions must be the same as the data
%                    array; may be uint8, uint16, or double, in
%                    which case the values should be in the
%                    range [0,1]
%
%     'SignificantBits' A scalar or vector indicating how many
%                    bits in the data array should be regarded
%                    as significant; values must be in the range
%                    [1,bitdepth]
%
%                    For indexed images: a 3-element vector
%                    For grayscale images: a scalar
%                    For grayscale images with an alpha channel:
%                      a 2-element vector
%                    For truecolor images: a 3-element vector
%                    For truecolor images with an alpha channel:
%                      a 4-element vector
%
%     In addition to these PNG parameters, you can use any
%     parameter name that satisfies the PNG specification for
%     keywords: only printable characters, 80 characters or
%     fewer, and no leading or trailing spaces.  The value
%     corresponding to these user-specified parameters must be a
%     string that contains no control characters except for
%     linefeed.