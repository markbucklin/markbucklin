function TF = useSingleThread() %#codegen
warning('useSingleThread.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
%USESINGLETHREAD Flag indicating if codegen solution needs to use single thread.
%

% Copyright 2014 The MathWorks, Inc.

% Query the number of threads used at compile time
myfun      = 'feature';
coder.extrinsic('eml_try_catch');
[errid, errmsg, numThreads] = eml_const(eml_try_catch(myfun, 'numthreads'));
eml_lib_assert(isempty(errmsg), errid, errmsg);

TF = (numThreads==1);
