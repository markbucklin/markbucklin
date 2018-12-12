function suppressTiffWarnings()

% SUPPRESS TIFFLIB WARNINGS
warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
warning('off','MATLAB:tifflib:TIFFReadDirectory:libraryWarning')
warning('off','MATLAB:imagesci:Tiff:closingFileHandle')

end
