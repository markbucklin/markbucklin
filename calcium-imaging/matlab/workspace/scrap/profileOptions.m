warning('profileOptions.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')





!echo %processor_architecture%
!echo %processor_identifier%
!echo %processor_level%
!echo %processor_revision%













mem.infobefore = evalc(' feature dumpMem ');
profile on -detail 'builtin' -timer 'real'

mem.infoafter = evalc(' feature dumpMem ');
