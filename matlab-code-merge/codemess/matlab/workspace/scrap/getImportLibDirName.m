function ldir = getImportLibDirName(context)
warning('getImportLibDirName.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% GETIMPORTLIBNAME returns the compiler specific import library name on
%
% Windows specific
%
%

% Copyright 2013 The MathWorks, Inc.


cc = context.getToolchainInfo();

if strncmp(cc.Name, 'Microsoft',9)
    ldir = 'microsoft';
elseif strncmp(cc.Name,'lcc', 3)
    ldir = 'lcc';
else
    assert(false, sprintf('Image Processing Toolbox does not support %s compiler. Run mex -setup to select a supported compiler',cc.Name));
end
