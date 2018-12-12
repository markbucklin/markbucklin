classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		FunctionInfo < ign.core.Handle
	%
	%
	% Note:
	%		The SIGNATURE struct resembles that returned by matlab.depfun.internal.builtinSignature(),
	%		rather than that returned by matlab.depfun.internal.getSig()
	%		
	
	
	% COMMON FUNCTION INFO
	properties (SetAccess = protected)
		Function = ''
		Type = ''
		File = ''		
		Signature
	end
	
	% ARGUMENT INFO
	properties (SetAccess = protected)		
		InputArgNames = {}
		OutputArgNames = {}
		MinArgsIn = 0
		MinArgsOut = 0
	end
	
	% TYPE-DEPENDENT
	properties (SetAccess = protected)
		Workspace = {}
		Parentage = {}
		Class = ''
		WithinFilePath = ''
	end
	
	
	methods
		function obj = FunctionInfo(fcn)
			
			if nargin
				
				% ASSERT FUNCTION_HANDLE INPUT
				assert(isa(fcn, 'function_handle'))
				
				% GET INFO FROM 'FUNCTIONS' FUNCTION
				info = functions(fcn);
				
				% FILL EQUIVALENT PROPERTIES FROM INFO-STRUCTURE
				field2Prop = obj.FunctionsInfoField2Prop; %getField2PropertyMap();
				fld = fields(info);
				for k=1:numel(fld)
					obj.(field2Prop.(fld{k})) = info.(fld{k});
				end
				
				% GET SIGNATURE
				sigList = ign.core.FunctionInfo.getFunctionSignature( fcn, info);
								
				% GET NUMBER OF DECLARED INPUT & OUTPUT ARGUMENTS
				if numel(sigList) > 1
					numIn = cellfun( @numel, {sigList.InArgs});
					numOut = cellfun( @numel, {sigList.OutArgs});
					isVarArgIn = cellfun( @(c) any(strcmpi('varargin',c)), {sigList.InArgs});
					isVarArgOut = cellfun( @(c) any(strcmpi('varargout',c)), {sigList.OutArgs});
					isValidName = cellfun( @(c) all(cellfun(@isvarname, c)), {sigList.InArgs});
					
					% INPUT NAMES
					score = (numIn - isVarArgIn).*(isValidName);
					[~,idx] = max(score);
					argsInList = sigList(idx).InArgs;
					
					% OUTPUT NAMES
					score = (numOut - isVarArgOut);
					[~,idx] = max(score);
					argsOutList = sigList(idx).OutArgs;
					
					% MAX/MIN IN/OUT	% todo -> look in file for defaultSignatures, i.e. 'if nargin < n'
					minNumIn = min(numIn);
					minNumOut = min(numOut);
					%maxNumIn = max(numIn);
					%maxNumOut = max(numOut);
										
				else
					% INPUT NAMES
					argsInList = sigList.InArgs;
					
					% OUTPUT NAMES
					argsOutList = sigList.OutArgs;
					
					% MAX/MIN IN/OUT
					minNumIn = numel(sigList.InArgs);					
					minNumOut = numel(sigList.OutArgs);
					%maxNumIn = minNumIn;
					%maxNumOut = minNumOut; %todo
					
				end
								
				% STORE INPUT/OUTPUT ARGUMENT INFO
				obj.InputArgNames = argsInList;
				obj.OutputArgNames = argsOutList;
				obj.MinArgsIn = minNumIn;
				obj.MinArgsOut = minNumOut;
				
				% ASSIGN SIGNATURE LIST
				obj.Signature = sigList;
				
			end
			
		end
	end
	methods (Static)
		function fcnSig = getFunctionSignature( fcn, info)
			% Return a structure with four fields:
			%    Name: The name of the function (identical to fcnName)
			%    InArgs: A cell array of input argument names
			%    OutArgs: A cell array of output argument names
			%    Type: The MATLAB type of the inputs and outputs
			%
			
			% INITIALIZE SIGNATURE STRUCTURE
			fcnSig = blankSignature();
			
			% MANAGE VARIABLE INPUT
			if (nargin < 2)
				% GET OPTIONAL INFO INPUT FROM FUNCTIONS() FUNCTION
				info = functions(fcn);
			end
						
			% FUNCTION NAME
			fcnName = info.function;
			
			% DEFAULT FUNCTION CLASS
			if isfield(info,'class') && ~isempty(info.class)
				fcnClass = info.class;
			else
				fcnClass = '';
			end
			
			% PARSE FUNCTION SIGNATURE INFO ACCORDING TO TYPE
			if strcmpi( info.type, 'anonymous' )
				% FUNCTION-HANDLE TYPE: ANONYMOUS
				parseAnonymousFcn();
				
			else
				% FUNCTION-HANDLE TYPE: SIMPLE, CLASSSIMPLE, SCOPEDFUNCTION, NESTED
				[fcnFilePathList, fcnDescriptionList, fcnStrNestList] = getFcnTarget();
				
				% EXTRACT CLASS LIST FROM FCN-DESCRIPTION
				fcnClassList = getFcnInputType();
				
				% EXTRACT SIGNATURE FROM FILE (OR BUILTIN DATABASE)
				parseFcnTargets();
				
			end
			
			% ----------------------------------------
			% NESTED FUNCTIONS
			% ----------------------------------------
			function parseAnonymousFcn()
				% 	function: '@(a)pkg.OverriddenClass.simpleStaticMethod'
				% 	type: 'anonymous'
				% 	file: 'Z:\Files\MATLAB\workspace\+pkg\OverriddenClass.m'
				% 	workspace: {[1x1 struct]}
				% 	within_file_path: ''
				
				% INPUT & OUTPUT ARGUMENT NAMES
				leftParen = strfind(fcnName,'(');
				rightParen = strfind(fcnName,')');
				fcnSig(1).Name = fcnName;
				fcnSig(1).InArgs = str2ArgList( fcnName(leftParen(1)+1:rightParen(1)-1) );
				fcnSig(1).OutArgs = {'varargout'};
				fcnSig(1).Type = fcnClass;
				
			end
			function [fcnFilePathList, fcnDescriptionList, fcnStrNestList] = getFcnTarget()
				
				% DETERMINE LOCATION & DESCRIPTION OF FILES THAT FCN MAY REFER TOO
				if isempty(info.file)
					[wloc,wtype] = which(fcnName, '-all');
					fcnFilePathList = wloc;
				else
					% exist(info.file, 'file')
					fcnFilePathList = info.file; % todo: fcnFilePathList = {info.file};??
					[~,wtype] = which(fcnName, 'in', info.file);
				end
				fcnDescriptionList = wtype;
				
				% FORMAT AS CELL-ARRAY OF STRINGS TO ALLOW FOR MULTIPLE FILES
				if ~iscell(fcnDescriptionList), fcnDescriptionList = {fcnDescriptionList}; end
				if ~iscell(fcnFilePathList), fcnFilePathList = {fcnFilePathList}; end
				
				% FORMAT FUNCTION NAME AS SEQUENCE OF NESTED FUNCTIONS
				pkgSplit = strsplit(fcnName, '.');
				fcnStrNestList = strsplit(pkgSplit{end},'/');
				
				% EXTRACT CLASS
				if ~isempty(fcnClass) && (numel(fcnFilePathList) > 1) %if isfield(info, 'class')
					% APPLY FILTER IF CLASS IS SPECIFIED
					if numel(fcnFilePathList) > 1
						%classMatch = ~cellfun(@isempty, strfind(fcnDescriptionList, info.class));
						classMatch = strcmp(fcnDescriptionList, fcnClass);
						if any(classMatch)
							fcnFilePathList = fcnFilePathList(classMatch);
							fcnDescriptionList = fcnDescriptionList(classMatch);
						end
					end
				end
			end
			function fcnClassList = getFcnInputType()
				%'static method or package function'
				% classsimple -> wtype:
				%		'pkg.OverriddenClass constructor'
				%		'static method or package function'
				%		'SimpleClass method'
				%		'pkg.OverriddenClass method'
				%
				% simple -> wtype:wloc
				%		'IntervalTimer constructor'
				%		'logical method':'built-in (Z:\Files\MATLAB\R2016a\toolbox\matlab\datafun\@logical\fft)'
				%		'uint8 method':'Z:\Files\MATLAB\R2016a\toolbox\matlab\datafun\@uint8\fft.m'
				%		'gpuArray method':'fft is a built-in method'
				%		'gpuArray method':'Z:\Files\MATLAB\R2016a\toolbox\distcomp\gpu\@gpuArray\fft.m'
				%		'static method or package function':'Z:\Files\MATLAB\workspace\+pkg\simpleScript.m'
				%		'':'Z:\Files\MATLAB\workspace\simpleFunction.m'
				%
				% scopedfunction
				%		'Private to +pkg':'Z:\Files\MATLAB\workspace\+pkg\private\simplePrivateFunction.m'
				%		'Local function of makeSimpleFunctionHandles':'Z:\Files\MATLAB\workspace\+pkg\makeSimpleFunctionHandles.m'
				
				if all( cellfun( @isempty, fcnDescriptionList))
					fcnClassList = {fcnClass};
					return
				end
				expr = '(?:(Shadowed\s)?)(?<datatype>[\w\.]*)\s(?<fcntype>(method)|(constructor))\>';
				tok = regexp(fcnDescriptionList, expr, 'names');
				
				if (numel(tok) == 1) || isempty(tok{1}) || isempty(tok{1}.datatype)
					fcnClassList = {fcnClass};
				else
					s = [tok{:}];
					isClassMethod = strcmp({s.fcntype},'method');
					fcnClassList = cell(size(fcnDescriptionList));
					[fcnClassList{isClassMethod}] = s(isClassMethod).datatype;
				end
				
				% CLEAN LIST OF CLASSES (INPUT DATATYPES)
				if numel(fcnClassList) > 1
					builtInNoFile = strcmp(fcnFilePathList, [fcnName, ' is a built-in method']);
					try
						fcnClassList = fcnClassList(~builtInNoFile);
						fcnFilePathList = fcnFilePathList(~builtInNoFile);
					catch me
						disp(getReport(me))
					end
				end
				
			end
			function parseFcnTargets()
				
				% IDENTIFY BUILT-IN FUNCTIONS FROM LOCATION-STRING RETURNED BY 'WHICH'
				isBuiltIn = ~cellfun(@isempty, strfind(fcnFilePathList, 'built-in ('));
				
				% GET ARRAY OF BUILT-IN SIGNATURES (NO M-FILE)
				if any(isBuiltIn)
					addBuiltinFcnSignature();
				end
				
				% FILL ARRAY OF SIGNATURE STRUCTS -> 1 FOR EACH CLASS
				k = 0;
				while k < numel(fcnClassList)
					k = k + 1;
					fcnClass = fcnClassList{k};
					fcnFile = fcnFilePathList{k};
					try
						if ~isBuiltIn(k)
							% PARSE ARGS FROM FILE
							addFunctionFileSignature( fcnClass, fcnFile);
						end
					catch
						% USE GENERIC SIGNATURE AS BACKUP
						addGenericSignature();
					end
				end
				
			end
			function addBuiltinFcnSignature()
				
				% DEPFUN INTERNAL CALL
				biSig = matlab.depfun.internal.builtinSignature(info.function);
				appendFcnSignature(biSig);
				
			end
			function addFunctionFileSignature( fcnClass, fcnFile)
				
				% READ LINES OF TEXT FROM M-FILE INTO CELL ARRAY
				txt = ign.util.readFileText(fcnFile);
				
				% GET FUNCTION DEFINITION LINES
				isFcnDefLine = ~cellfun(@isempty, regexp(txt, '\s*function\s.*'));
				
				% EXTRACT SIGNATURE FROM FUNCTION DEFINITION IN CODE AND/OR COMMENTS				
				%fileSig = cat(1, argStrFromFcnDefinition(), argStrFromFileComments());
				defSig = argStrFromFcnDefinition();
				commentSig = argStrFromFileComments();
				
				% todo move to appendFcnSignature
				sigMatch = compareStruct(defSig,commentSig);
				fileSig = cat(1, defSig, commentSig(~sigMatch));
				
				% FILL SIGNATURE STRUCTURE
				if ~isempty(fileSig)
					[fileSig.Type] = deal(fcnClass);
				end
				
				% APPEND TO ARRAY OF SIGNATURE STRUCTURES
				appendFcnSignature(fileSig);
				
				% ----------------------------------------------------
				% NESTED FUNCTIONS FOR EXTRACTING SIGNATURES FROM TEXT
				% ----------------------------------------------------
				function sig = argStrFromFcnDefinition()
					
					sig = blankSignature();
					if ~any(isFcnDefLine)
						return
					end
					%fcnTxt = txt(fcnDefinitionLineIdx);
					fcnTxt = txt(isFcnDefLine);
					fcnStr = fcnStrNestList{end};
					fcnDefLineIdx = find(isFcnDefLine);
					
					% COMPLETE FUNCTION DEFINITIONS THAT CONTINUE ON NEXT LINE
					while true
						isFunctionContinuation = ~cellfun(@isempty, regexp(fcnTxt, '[\[\]\w\(\) ]*\.\.\.'));
						continuingFcnIdx = find(isFunctionContinuation);
						if ~isempty(continuingFcnIdx)
							for kidx = 1:numel(continuingFcnIdx)
								fcnIdx = continuingFcnIdx(kidx);
								nextLineIdx = fcnDefLineIdx(fcnIdx) + 1;
								while ~isempty(strfind(fcnTxt{fcnIdx},'...'))
									fcnTxt{fcnIdx} = strrep(fcnTxt{fcnIdx}, '...', [' ',strtrim(txt{nextLineIdx})]);
									nextLineIdx = nextLineIdx + 1;
								end
							end
						else
							break
						end
					end
					
					% TRIM WHITE SPACE FROM BEFORE AND AFTER
					fcnTxt = strtrim(fcnTxt);
					
					% SELECT OUTER FUNCTION (IF NESTED)
					k = 1;
					while k < numel(fcnStrNestList)
						nestFcnStr = fcnStrNestList{k};
						nestFcnIdx = find(~cellfun(@isempty, regexp(fcnTxt, sprintf('[\\[\\]\\w\\(\\) ]*%s\\>',nestFcnStr))),1,'first');
						fcnTxt = fcnTxt(nestFcnIdx:end);
						k = k + 1;
					end
					
					% GET SPECIFIED FUNCTION STRING
					isFcnDefMatch = ~cellfun(@isempty, regexp(fcnTxt, ['function\s[\[\]\w\s, ]*[\=\s]*',fcnStr,'.*']));
					fcnSigTxt = fcnTxt{find(isFcnDefMatch,1,'first')};
					
					% EXTRACT INPUT & OUTPUT NAMES
					tok = regexp(fcnSigTxt, ['function \[?\s*(?<out>[\w,\s]*)\s*\]?\s*\=?\s*',fcnStr,'\(?\s*(?<in>[\w,\s]*)\s*\)?'], 'names');
					sig(1).OutArgs = validateArgList( str2ArgList(tok.out), 'out');
					sig(1).InArgs = validateArgList( str2ArgList(tok.in), 'in');
					
					
				end
				function sig = argStrFromFileComments()
					
					% GET FUNCTION STRING FROM LAST CELL IN NESTED CALL SEQUENCE
					sig = blankSignature();
					fcnStr = fcnStrNestList{end};
					
					% EXTRACT TOKENS -> ASSUMING 'FCN' IS CASE-INSENSITIVE (ALL CAPS OK)
					tok = regexpi(txt, ...
						['%[\s>-\=]* \[?\s*(?<out>[\w,\s]*)\s*\]?\s*\=?\s*',...
						'(?<funcname>',fcnStr,')',...
						'\(+\s*(?<in>[\w,.''\s]*)\s*\)+'], 'names');
					isCommentLineMatch = ~cellfun(@isempty, tok);
					fcnTxt = txt(isCommentLineMatch);
					isAllUpper = cellfun(...
						@(ctxt) isempty(strfind( ctxt, fcnStr)) ...
						&& ~isempty(strfind( ctxt, upper(fcnStr))), fcnTxt);
					sigStr = cat(1,tok{isCommentLineMatch});
					
					% BUILD A SIGNATURE FOR EACH FUNCTION SIGNATURE FOUND IN COMMENTS
					for karg=1:numel(sigStr)
						if isAllUpper(karg)
							sig(karg).InArgs = validateArgList( str2ArgList(lower(sigStr(karg).in)), 'in');
							sig(karg).OutArgs = validateArgList( str2ArgList(lower(sigStr(karg).out)), 'out');
						else
							sig(karg).InArgs = validateArgList( str2ArgList(sigStr(karg).in), 'in');
							sig(karg).OutArgs = validateArgList( str2ArgList(sigStr(karg).out), 'out');
						end
					end					
					sig = sig(:);
				
				end
				
			end
			function addGenericSignature()
				
				genSig.Name = fcnName;
				genSig.InArgs = {};
				genSig.OutArgs = {};
				genSig.Type = fcnClass;
				
				try
					numIn = nargin(fcn);
					numOut = nargout(fcn);
					if abs(numIn) > 0
						%for karg=1:(abs(numIn)), genSig.InArgs{karg} = sprintf('i%d',karg); end
						genSig.InArgs = strseq('i', a:abs(numIn));
						% todo: alternative for coder compatibility?
						% genSig.InArgs = strseq('u', a:abs(numIn));
					else
						genSig.InArgs = {};
					end
					if numIn < 0
						genSig.InArgs{abs(numIn)} = 'varargin';
					end
					if abs(numOut) > 0
						%for karg=1:(abs(numOut)), genSig.OutArgs{karg} = sprintf('o%d',karg); end
						genSig.OutArgs = strseq('o', a:abs(numOut));
					else
						genSig.OutArgs = {};
					end
					if numOut < 0
						genSig.OutArgs{abs(numOut)} = 'varargout';
					end
					
				catch
					% SCRIPT?
					% todo -> warning
					warning('Attempt to find function signature for script: %s',fcnName)
				end
				
				appendFcnSignature(genSig);
				
			end			
			function appendFcnSignature(sig)
				% ASSIGN COMMON FUNCTION NAME
				[sig.Name] = deal(fcnName);
				
				if isempty(fcnSig)
					fcnSig = sig(:);
				else
					fcnSig = [fcnSig(:) ; sig(:)];
				end
				
				% todo: sigMatch = compareStruct(defSig,commentSig);
				%
				% 				% APPEND INPUT TO ANY CURRENT SIGNATURE STRUCTS
				% 				n0 = numel(fcnSig);
				% 				n1 = numel(sig);
				% 				fcnSig(n0 + (1:n1)) = sig;
				
			end
		end
	end
	
	
	
	
	% HIDDEN/CONSTANT PROPERTIES
	properties (Constant, Hidden)
		FunctionsInfoField2Prop = struct(...
			'class', 'Class', ...
			'file', 'File', ...
			'function', 'Function', ...
			'parentage', 'Parentage', ...
			'type',  'Type', ...
			'within_file_path', 'WithinFilePath', ...
			'workspace', 'Workspace');
% 		UseSignatureCache = true;
	end
	
	
end






function sig = blankSignature()
sig = struct(...
	'Name', '',...
	'InArgs', {},... %{''}
	'OutArgs', {},...
	'Type', '');
end
function argList = str2ArgList( argStr)
if ~isempty(argStr)
	argList = strsplit( strtrim( argStr),...
		{',',' '}, 'CollapseDelimiters', true);
	
	
	% todo -> cellfun( @isvarname, argList)
	%isStatement = ~cellfun(@isempty, strfind(argList, ''''));
	%		if any(isStatement), eval(str)...
else
	argList = {};
end
end
function argList = validateArgList(argList,argDir)
%argDir = 'in' or 'out'
					isValidArgStr = cellfun(@isvarname, argList) & ~strcmpi('true', argList) & ~strcmpi('false',argList);
	if any(~isValidArgStr)
		k = 0;
		while k < numel(argList)
			k = k + 1;
			if ~isValidArgStr(k)
				invalidStr = argList{k};				
				if isstrprop(invalidStr(1),'digit')
					validStr = sprintf('numeric_arg%s_%d', argDir, k);
				elseif any(strcmpi( invalidStr, {'true','false'}))
					validStr = sprintf('logical_arg%s_%d', argDir, k);										
				elseif strcmp(invalidStr,'[]') % todo: add support for '[]' empty arg
					validStr = sprintf('blank_arg%s_%d', argDir, k);					
				else
					validStr = matlab.lang.makeValidName(invalidStr);
				end
				argList{k} = validStr;
			end
		end
	end
end


	
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\requirements.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\realpath.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\qualifyName.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\qualifiedName.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\msg2why.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\matlabFileExists.m'
% 
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\isprivate.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\isfunction.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\isfullpath.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\isbuiltin.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\isMcode.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\isClassdef.m'
% 'Z:\Files\MATLAB\R2016a\toolbox\matlab\depfun\+matlab\+depfun\+internal\private\hasext.m'







% 
% if any(isFcnDefLine)
% 	defSig = argStrFromFcnDefinition();
% 	fcnCommentExampleSig = argStrFromFileComments();
% 	fileSig = cat(1, defSig, fcnCommentExampleSig(:));
% 	
% else
% 	% USE COMMENTS IN A M-FILE SHADOWING A MEX-FILE
% 	fileSig = argStrFromFileComments();
% 	
% end


% % FROM A FUNCTION FILE (M-FILE)
% defSig = argStrFromFcnDefinition();
% isVarArgIn = ~isempty(defSig.InArgs) && strcmp(defSig.InArgs{end},'varargin');
% isVarArgOut = ~isempty(defSig.OutArgs) && strcmp(defSig.OutArgs{end},'varargout');
% 
% % USE SYNTAX EXAMPLES IN COMMENTS BLOCK UNDER FUNCTION DEFINITION
% fcnCommentExampleSig = argStrFromFileComments();
% 
% if isVarArgIn || isVarArgOut
% 	fcnCommentExampleSig = argStrFromFileComments();
% 	if ~isempty(fcnCommentExampleSig)
% 		numCommentArgs.in = cellfun(@numel,{fcnCommentExampleSig.InArgs})
% 		numCommentArgs.out = cellfun(@numel,{fcnCommentExampleSig.OutArgs})
% 		if isVarArgIn
% 			varargidx = numel(defSig.InArgs);
% 			if any(numCommentArgs.in >= varargidx)
% 				[num,idx] = max(numCommentArgs.in);
% 				fileSig.InArgs(varargidx:num) = fcnCommentExampleSig(idx).InArgs(varargidx:num);
% 				% todo
% 				
% 				
% 			end
% 		end
% 		if isVarArgOut & any(numCommentArgs.out >= numel(defSig.OutArgs))
% 			
% 		end
% 	end
% end
% if isempty(fileSig)
% 	% USE FUNCTION-DEFINITION LINE
% 	fileSig = argStrFromFcnDefinition();
% end


% function varargout = getSetCache(str,varargin)
% % can remove
% persistent sigCache
% sigCache = ign.util.persistentMapVariable(sigCache);
% sig = [];
% switch nargin
% 	case 0
% 		sigCache = containers.Map();
% 	case 1
% 		if isKey(sigCache,str)
% 			sig = sigCache(str);
% 		end
% 	case 2
% 		sigCache(str) = varargin{1};
% end
% if nargout
% 	varargout{1} = sig;
% 	
% end
% end





% function types = getTypes()
% 			types = {
% 				'simple'
% 				'classsimple'
% 				'scopedfunction'
% 				'nested'
% 				'anonymous'
% 				}
% 		end

% function functionsFieldProp = getField2PropertyMap()
% persistent sfmap
% if isempty(sfmap)
% 	sfmap = containers.Map();
% end
% if sfmap.Count < 7
% 	sfmap('function') = 'Function';
% 	sfmap('type') = 'Type';
% 	sfmap('file') = 'File';
% 	sfmap('workspace') = 'Workspace';
% 	sfmap('parentage') = 'Parentage';
% 	sfmap('class') = 'Class';
% 	sfmap('within_file_path') = 'WithinFilePath';
% end
% functionsFieldProp = sfmap;
% end

% matlab.depfun.internal.getSig
% matlab.depfun.internal.builtinSignature
% nr = matlab.internal.language.introspective.NameResolver(info.function)
% clc
% key = fcnMap.keys
% for k=1:numel(key),
% fprintf('\n\n========================\n')
% disp(key{k})
% fcn = fcnMap(key{k});
% info = infoMap(key{k}),
% try, sig = matlab.depfun.internal.getSig(info.function), catch me, getReport(me), end
% try, sigStruct = matlab.depfun.internal.builtinSignature(info.function), catch me, getReport(me), end
% try, callInfo = getcallinfo( info.function ), catch me, getReport(me), end
% try, classNames = functionhintsfunc( info.function ), catch me, getReport(me), end
% try, functionInfo = getcallinfo( info.file , 'flat'), catch me, getReport(me), end
% end
