function writeTiffFile(data,varargin)
% ------------------------------------------------------------------------------
% WRITETIFFFILE
% 7/30/2015
% Mark Bucklin
% ------------------------------------------------------------------------------
%
% DESCRIPTION:
%   Data may be any numeric type array of 3 or 4 dimensions
%
%
% USAGE:
%   >> writeTiffFile( data)
%   >> writeTiffFile( data, fileName)
%
%
% See also:
%	READBINARYDATA, PROCESSFAST, WRITEBINARYDATA, TIFF
% ------------------------------------------------------------------------------
% ------------------------------------------------------------------------------
% ------------------------------------------------------------------------------

if nargin>1
    fileName = varargin{1};
else
    [fileName, fileDir] = uiputfile('*.tif','Please choose filename and location for TIFF file','imstack.tif');
    fileName = fullfile(fileDir,fileName);
end
t = Tiff(fileName,'w8');
try
    imFrame = data(:,:,1);
    [numRows,numCols,dim3,dim4] = size(data);
    if dim4==1
        numFrames = dim3;
        numChannels = 1;
    else
        numFrames = dim4;
        numChannels = dim3;
    end
    
    tagstruct.ImageLength = numRows;
    tagstruct.ImageWidth = numCols;
    tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
    
    switch class(data)
        case {'uint8','int8'}
            tagstruct.BitsPerSample = 8;
        case {'uint16','int16'}
            tagstruct.BitsPerSample = 16;
        otherwise
            tagstruct.BitsPerSample = 8;
    end
    tagstruct.SamplesPerPixel = numChannels;
    tagstruct.RowsPerStrip = numRows;
    tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
    tagstruct.Software = 'MATLAB';
    
    
    t.setTag(tagstruct)
    t.write(imFrame)
    tic
    for k = 2:numFrames
        if mod(k, 256) == 0
            fprintf('writing frame %g of %g\n',k,numFrames);
        end
        t.writeDirectory();
        t.setTag(tagstruct);
        if numChannels == 1
            imFrame = data(:,:,k);
        else
            imFrame = data(:,:,:,k);
        end
        t.write(imFrame);
        % 	t.nextDirectory
    end
    t.close;
    toc
    
catch me
    disp(me.message)
    t.close
    disp('failure')
end