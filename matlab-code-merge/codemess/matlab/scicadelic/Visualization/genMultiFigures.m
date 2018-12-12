% function genMultiFigures()
genMultiMouseDir = pwd;
% expDir = dir('Ali*');
% expDir = expDir([expDir.isdir]);
% prevProc = false(numel(expDir),1);
expDir = getExperimentDirectories();
close all
for kDir = 1:numel(expDir)
   try
	  fullExpDir = [genMultiMouseDir,filesep,expDir(kDir).name];
	  fprintf('Generating Figures in \n\t%s\n',fullExpDir);
	  cd(expDir(kDir).name)
   catch me
	  cd ..
	  genMultiMouseDir = pwd;
	  cd(expDir(kDir).name)
   end
   genfigures;
   close all
   showLickResponse;
   close all
   cd(genMultiMouseDir)
end