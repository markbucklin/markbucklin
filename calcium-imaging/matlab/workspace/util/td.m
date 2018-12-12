function td(varargin)


persistent dirList tidx
if isempty(dirList), dirList = {pwd}; end
if isempty(tidx), tidx = 0; end



if nargin
	if isempty(varargin{1})
		% RESET TOGGLE LIST
		dirList = {pwd};
		tidx = 1;
		fprintf('Resetting toggle-directory list\n')
		return
		
	else
		% APPEND INPUT TO TOGGLE LIST
		dirList = unique([dirList, varargin], 'stable');
	end
	
else
	% ADD PWD IF NOT IN TOGGLE LIST
	if ~any(strcmp(pwd,dirList))
		dirList{end + 1} = pwd;
	end
	
end

% INCREMENT/WRAP TOGGLE IDX
tidx = mod(tidx, numel(dirList));
tidx = tidx + 1;
cd(dirList{tidx});


fprintf('Toggling directory to idx %d:\n\t%s\n', tidx, dirList{tidx});
fprintf('\nCurrent toggle list:\n')
fprintf('\t%s\n', dirList{:})