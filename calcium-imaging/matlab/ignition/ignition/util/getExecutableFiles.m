function execFile = getExecutableFiles(dirStr)



execFile = {};

% todo -> needs testing (not very important though)


% CUSTOM ADDITIONS
if ispc
	executableExt = {'.exe','.bat','.cmd','.ahk','.py','.vb'};
else
	executableExt = {'.bat','.ahk','.py'};
end

% LOOK FOR ENVIRONMENT VARIABLE = 'PATHEXT'
environmentPathExtStr = getenv('PATHEXT');
if ~isempty(environmentPathExtStr)
	envPathExt = strsplit(lower(environmentPathExtStr),';');
	executableExt = union(executableExt, envPathExt);
end





if isdir(dirStr)
	dirContents = dir(dirStr);
	dirFiles = {dirContents(~[dirContents.isdir]).name};
	
	for k=1:numel(dirFiles)
		fName = dirFiles{k};
		
		[~,~, fExt] = fileparts(fName);
		if any(strcmpi(fExt,executableExt))
			execFile = [execFile ; {fName}];
		end
		
		
	end
	
	
	
	
	
end
end



% MATLAB EXECUTABLE (I.E. MEX)
% 		if ignition.util.isExecutable(fName);
% 			execFile = [execFile ; {fName}];
% 		end