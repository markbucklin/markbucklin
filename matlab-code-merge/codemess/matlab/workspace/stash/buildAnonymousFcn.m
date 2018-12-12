function fcn = buildAnonymousFcn( inputVarList, sequentialCmdList, workspaceVarList, outputVarList )

% TODO: WORK IN PROGRESS
% for construction of multi-line functions from the command-line

if nargin < 3, workspaceVarList = {}; end
if nargin < 4, outputVarList = {}; end

% if ~isempty(workspaceVarList)
% 	for kWsvar = 1:numel(workspaceVarList)
% 		name = workspaceVarList{kWsvar};
% 		eval( sprintf('%s = evalin(''caller'', %s );' , name, name));
% 	end
% end

allVarsList = [inputVarList , workspaceVarList];
allVarParenStr = ['(', sprintf('%s,',allVarsList{1:(end-1)}, allVarsList{end}, ')'];
lineExpression = sequentialCmdList{kLine};


% function fcnLine = buildLineFcn( kLine , varargin)
% 
% 	lineExpression = sequentialCmdList{kLine};
% 	lineFcnStr = ['(', 
% 	
% end


	






end