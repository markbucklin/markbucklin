ptxas application ptx input, line 987; error   : Arguments mismatch for instruction 'mov'
ptxas application ptx input, line 1040; error   : Arguments mismatch for instruction 'mov'
ptxas fatal   : Ptx assembly aborted due to error
The CUDA error code was: CUDA_ERROR_NO_BINARY_FOR_GPU.



%% STACKS
In Z:\Files\MATLAB\R2016a\toolbox\matlab\codetools\@mtree\mtree.m>mtree.mtree (line 99)
  In Z:\Files\MATLAB\R2016a\toolbox\distcomp\gpu\+parallel\+internal\+tree\getTreeForFile.p>getTreeForFile
  In Z:\Files\MATLAB\R2016a\toolbox\distcomp\gpu\+parallel\+internal\+gpu\getPTXForOperation.p>@(IS)parallel.internal.tree.getTreeForFile(fcnInfoStruct.file,fcnInfoStruct.type,IS)
  In Z:\Files\MATLAB\R2016a\toolbox\distcomp\gpu\+parallel\+internal\+gpu\getPTXForOperation.p>getPTXForOperation
  In Z:\Files\MATLAB\toolbox\ignition\findPeakParallelMomentRunGpuKernel.m>findPeakParallelMomentRunGpuKernel (line 36)

	
	In Z:\Files\MATLAB\R2016a\toolbox\matlab\codetools\@mtree\mtfind.m>mtfind (line 32)
  In Z:\Files\MATLAB\R2016a\toolbox\distcomp\gpu\+parallel\+internal\+gpu\IR.p>IR.buildBoundFcnInfo
  In Z:\Files\MATLAB\R2016a\toolbox\distcomp\gpu\+parallel\+internal\+gpu\IR.p>IR.IR
  In Z:\Files\MATLAB\R2016a\toolbox\distcomp\gpu\+parallel\+internal\+gpu\ptxFactory.p>ptxFactory
  In Z:\Files\MATLAB\R2016a\toolbox\distcomp\gpu\+parallel\+internal\+gpu\getPTXForOperation.p>getPTXForOperation
  In Z:\Files\MATLAB\toolbox\ignition\findPeakParallelMomentRunGpuKernel.m>findPeakParallelMomentRunGpuKernel (line 36)

	
	%% mtree
	           T: [513x15 double]
           S: [73x5 double]
           C: {262x1 cell}
          IX: [1x503 logical]
           n: 503
           m: 1
        lnos: [99x1 double]
         str: 'function [uy, ux] = findPeakParallelMomentRunGpuKernel(XC, subPix)…'
    FileType: FunctionFile
           N: {100x1 cell}
           K: [1x1 struct]
          KK: {100x1 cell}
         Uop: [1x100 logical]
         Bop: [1x100 logical]
        Stmt: [1x100 logical]
      Linkno: [1x1 struct]
        Lmap: {1x17 cell}
      Linkok: [17x100 logical]
       PTval: [1x100 logical]
           V: {'2.50'  '2.50'}