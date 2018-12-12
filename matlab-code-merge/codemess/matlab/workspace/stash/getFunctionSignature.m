function fcnSig = getFunctionSignature( fcn, info)
% Return a structure with four fields:
%    Name: The name of the function (identical to fcnName)
%    InArgs: A cell array of input argument names
%    OutArgs: A cell array of output argument names
%    Type: The MATLAB type of the inputs and outputs
%

% OPTIONAL INFO INPUT FROM FUNCTIONS() FUNCTION
if nargin < 2
	info = functions(fcn);
end

% INITIALIZE SIGNATURE STRUCTURE
fcnSig = blankSignature();

% FUNCTION NAME
%fcnSig.Name = info.function;
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

% TODO -> FIX TYPE
% not static
% include class if classsimple


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
		fcnSig(1).InArgs = strsplit(fcnName(leftParen(1)+1:rightParen(1)-1),',');
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
		
		% 		switch info.type
		% 			case 'simple'
		%
		% 			case 'classsimple'
		%
		% 			case 'scopedfunction'
		%
		% 			case 'nested'
		%
		% 			otherwise
		%
		% 		end
		% 		%m = meta.class.fromName(fcnClass);
		% 		noSpecifiedTypeList = {'Private to '
		% 			'Local function of '
		% 			'static method or package function'
		% 			''};
		expr = '(?:(Shadowed\s)?)(?<datatype>[\w\.]*)\s(?<fcntype>(method)|(constructor))\>';
		tok = regexp(fcnDescriptionList, expr, 'names');
		
		% 		tok = regexp(fcnDescriptionList,...
		% 			'(?:(Shadowed\s)?)\s??(?(1)Shadowed\s[\w\.]*|[\w\.]*)\smethod','tokens','once');
		try
		if (numel(tok) == 1) || isempty(tok{1}) || isempty(tok{1}.datatype)
			fcnClassList = {fcnClass};
		else
			s = [tok{:}];
			isClassMethod = strcmp({s.fcntype},'method');
			fcnClassList = cell(size(fcnDescriptionList));
			[fcnClassList{isClassMethod}] = s(isClassMethod).datatype;
			%fcnClassList = [tok{:}]';
			%[fcnClassList{strcmp(fcnClassList,'static')}] = deal('');
		end
		catch me
			whos
		end
		
		% CLEAN LIST OF CLASSES (INPUT DATATYPES)
		%cleanClassList();
		%function cleanClassList()
		if numel(fcnClassList) > 1
			builtInNoFile = strcmp(fcnFilePathList, [fcnName, ' is a built-in method']);
			try
				fcnClassList = fcnClassList(~builtInNoFile);
				fcnFilePathList = fcnFilePathList(~builtInNoFile);
			catch me
				disp(getReport(me))
			end
		end
		%end
		
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
		fcnDefinitionLineIdx = find(~cellfun(@isempty, regexp(txt, '\s*function\s.*')));
		
		% EXTRACT SIGNATURE FROM FUNCTION DEFINITION IN CODE OR COMMENTS
		if ~isempty(fcnDefinitionLineIdx)
			% FROM A FUNCTION FILE (M-FILE)
			sig = argStrFromFcnDefinition();
			
		else
			% FROM COMMENTS IN A M-FILE SHADOWING A MEX-FILE
			sig = argStrFromFileComments();
			
		end
		
		% FILL SIGNATURE STRUCTURE
		if ~isempty(sig)
			[sig.Type] = deal(fcnClass);
		end
		
		% APPEND TO ARRAY OF SIGNATURE STRUCTURES
		appendFcnSignature(sig);
		
		% ----------------------------------------------------
		% NESTED FUNCTIONS FOR EXTRACTING SIGNATURES FROM TEXT
		% ----------------------------------------------------
		function sig = argStrFromFcnDefinition()
			
			sig = blankSignature();
			fcnTxt = txt(fcnDefinitionLineIdx);
			fcnStr = fcnStrNestList{end};
			
			% COMPLETE FUNCTION DEFINITIONS THAT CONTINUE ON NEXT LINE
			while true
				isFunctionContinuation = ~cellfun(@isempty, regexp(fcnTxt, '[\[\]\w\(\) ]*\.\.\.'));
				continuingFcnIdx = find(isFunctionContinuation);
				if ~isempty(continuingFcnIdx)
					for k = 1:numel(continuingFcnIdx)
						fcnIdx = continuingFcnIdx(k);
						nextLineIdx = fcnDefinitionLineIdx(fcnIdx) + 1;
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
			fcnIdx = find(~cellfun(@isempty, regexp(fcnTxt, ['function\s[\[\]\w\s, ]*[\=\s]*',fcnStr,'.*'])));
			fcnSigTxt = fcnTxt{fcnIdx};
			
			% EXTRACT INPUT & OUTPUT NAMES
			tok = regexp(fcnSigTxt, ['function \[?\s*([\w,\s]*)\s*\]?\s*\=?\s*',fcnStr,'\(?\s*([\w,\s]*)\s*\)?'], 'tokens');
			sig(1).OutArgs = strsplit( strtrim(tok{1}{1}), {',',' '}, 'CollapseDelimiters', true);
			sig(1).InArgs = strsplit( strtrim(tok{1}{2}), {',',' '}, 'CollapseDelimiters', true);
			
		end
		function sig = argStrFromFileComments()
			
			% GET FUNCTION STRING FROM LAST CELL IN NESTED CALL SEQUENCE
			sig = blankSignature();
			fcnStr = fcnStrNestList{end};
			
			% EXTRACT TOKENS -> ASSUMING 'FCN' IS ALL CAPS
			tok = regexp(txt, ...
				['[ %]*\[?\s*(?<out>[\w,\s]*)\s*\]?\s*\=\s*',...
				upper(fcnStr),...
				'\(\s*(?<in>[\w,\s\[\]]*)\s*\)\s*.*'], 'names');
			argStr = cat(1,tok{~cellfun(@isempty, tok)});
			
			% BUILD A SIGNATURE FOR EACH FUNCTION SIGNATURE FOUND IN COMMENTS
			for k=1:numel(argStr)
				sig(k).InArgs = str2ArgList(argStr(k).in);
				sig(k).OutArgs = str2ArgList(argStr(k).out);
			end
			
		end
		
	end
	function addGenericSignature()
		% 		if nargin < 1
		% 			if isfield(info,'class') && ~isempty(info.class)
		% 				fcnClass = info.class;
		% 			else
		% 				fcnClass = '';
		% 			end
		% 		end
		
		sig.Name = fcnName;
		sig.InArgs = {};
		sig.OutArgs = {};
		sig.Type = fcnClass;
		
		
		try
			numIn = nargin(fcn);
			numOut = nargout(fcn);
			if abs(numIn) > 0
				for k=1:(abs(numIn)), sig.InArgs{k} = sprintf('i%d',k); end
			else
				sig.InArgs = {};
			end
			if numIn < 0
				sig.InArgs{abs(numIn)} = 'varargin';
			end
			if abs(numOut) > 0
				for k=1:(abs(numOut)), sig.OutArgs{k} = sprintf('o%d',k); end
			else
				sig.OutArgs = {};
			end
			if numOut < 0
				sig.OutArgs{abs(numOut)} = 'varargout';
			end
			
		catch
			% SCRIPT?
			% todo -> warning
			warning('Attempt to find function signature for script: %s',fcnName)
		end
		
		appendFcnSignature(sig);
		
	end
	function appendFcnSignature(sig)
		% ASSIGN COMMON FUNCTION NAME
		[sig.Name] = deal(fcnName);
		
		% APPEND INPUT TO ANY CURRENT SIGNATURE STRUCTS
		n0 = numel(fcnSig);
		n1 = numel(sig);
		fcnSig(n0 + (1:n1)) = sig;
		
	end
end


% ----------------------------------------
% SCOPED LOCAL FUNCTIONS
% ----------------------------------------
function sig = blankSignature()
sig = struct(...
	'Name', '',...
	'InArgs', {},... %{''}
	'OutArgs', {},...
	'Type', '');
end
function argList = str2ArgList( argStr)
argList = strsplit( strtrim( argStr),...
	{',',' '}, 'CollapseDelimiters', true);
end







% 	% DEFINED IN A FILE, OR BUILT-IN
% 	if ~isempty(info.file)
% 		% SPECIFIED UNIQUE -> NESTED, SCOPED-LOCAL, OR SCOPED-PRIVATE
% 		[wloc,wtype] = which(info.function, 'in', info.file);
% 		sig = readFunctionFileSignature(info.file, wloc)
%
% 	else
% 		% MULTI-TARGET -> SIMPLE OR CLASSSIMPLE
% 		[wloc,wtype] = which(info.function, '-all');
%
% 		% GET ALL POTENTIAL TARGETS
%
%
% 		% IF CLASS
% 		if isfield(info,'class')
% 			m = meta.class.fromName(info.class);
%
%
% 		end



%pat = '@\((\w*),?(\w*)\)(.*)';
%tok = regexp(info.function, pat, 'tokens');
%sig.InArgs = tok{1}{1:abs(nargin(fcn))};

% % GET NUMBER OF DECLARED INPUT & OUTPUT ARGUMENTS
% numIn = nargin(fcn);
% numOut = nargout(fcn);



% LOCAL VARIABLES FROM STRUCTURE RETURNED BY functions(fcn)
% fname = info.function;

% GET PATH TO FUNCTION
% fpath = which(info.function,'-all')
% fpath = info.file;


%anonSplit = regexp(info.function, '@\((?<argsin>\w*)\)(?<expr>.*)','names')
%anonSplit = regexp(info.function, '@\((\W*(?<argsin>\w*)\W*,?\W*){0,31}\)(?<expr>.*)','names')

%anonSplit = regexp(info.function, '@\(((\w*),?)\)(.*)','tokens')







% switch info.type
% 		case 'simple'
% 			% 			function: 'simpleFunction'
% 			% 			type: 'simple'
% 			% 			file: 'Z:\Files\MATLAB\workspace\simpleFunction.m'
% 			% 			OR
% 			% 			file: ''
% 			if isempty(info.file)
% 				[wloc,wtype] = which(info.function, '-all');
% 			else
% 				[wloc,wtype] = which(info.file);
% 			end
%
%
% 		case 'classsimple'
% 			% 			function: 'pkg.OverriddenClass.simpleStaticMethod'
% 			% 			type: 'classsimple'
% 			% 			file: ''
% 			% 			class: 'pkg.OverriddenClass'
% 			[wcloc,wctype] = which(info.class)
% 			[wloc,wtype] = which(info.function, 'in', wcloc);
%
%
% 		case 'scopedfunction'
% 			% 			function: 'overriddenFunction'
% 			% 			type: 'scopedfunction'
% 			% 			file: 'Z:\Files\MATLAB\workspace\+pkg\OverriddenClass.m'
% 			% 			parentage: {'overriddenFunction'  'OverriddenClass.OverriddenClass'}
% 			[wloc,wtype] = which(info.function, 'in', info.file);
%
%
% 		case 'nested'
% 			% 			function: 'makeSimpleFunctionHandles/simpleNestedFunction'
% 			% 			type: 'nested'
% 			% 			file: 'Z:\Files\MATLAB\workspace\+pkg\makeSimpleFunctionHandles.m'
% 			% 			workspace: {[1x1 struct]}
% 			fcnNest = strsplit(info.function, '/');
% 			[wloc,wtype] = which(fcnNest{end}, 'in', info.file);
%
% 	end



% 	disp('=================================')
% 	disp(info)
%
% 	if isempty(fcnClass)
%
% 	end
%
% 	pkgSplit = strsplit(info.function, '.');
% 	fcnName = strsplit(pkgSplit{end},'/');
%
% 	sig = readFunctionFileSignature(fcnName,fileName,fcnClass);
%
% 	if ~iscell(fileName)
% 		fileName = {fileName};
% 	end
%
% 	fprintf('File: %s\n', fileName{:})
% 	fprintf('Function string: %s\n', fcnName{:})
% 	fprintf('Class: %s\n', fcnClass)
%
% 	%   [wloc,wtype] = which(fname, 'in', info.parentage{end},  '-all');
% 	% 	[wloc,wtype] = which(info.function, 'in', info.file);
% 	% 	sig = readFunctionFileSignature(info.file, wloc)
% 	% 	[wloc,wtype] = which(info.function, '-all');
% 	% 	% CHECK WHETHER COULD BE BUILT-IN
% 	% 	if exist(info.function,'builtin')
% 	% 		sig = builtinSignature(fcn, info);
% 	% 	end
%






%
% 	switch info.type
% 		case 'simple'
% 			% 			function: 'simpleFunction'
% 			% 			type: 'simple'
% 			% 			file: 'Z:\Files\MATLAB\workspace\simpleFunction.m'
% 			% 			OR
% 			% 			file: ''
% 			info.class = '';
%
% 		case 'classsimple'
% 			% 			function: 'pkg.OverriddenClass.simpleStaticMethod'
% 			% 			type: 'classsimple'
% 			% 			file: ''
% 			% 			class: 'pkg.OverriddenClass'
%
% 		case 'scopedfunction'
% 			% 			function: 'overriddenFunction'
% 			% 			type: 'scopedfunction'
% 			% 			file: 'Z:\Files\MATLAB\workspace\+pkg\OverriddenClass.m'
% 			% 			parentage: {'overriddenFunction'  'OverriddenClass.OverriddenClass'}
% 			info.class = '';
%
% 		case 'nested'
% 			% 			function: 'makeSimpleFunctionHandles/simpleNestedFunction'
% 			% 			type: 'nested'
% 			% 			file: 'Z:\Files\MATLAB\workspace\+pkg\makeSimpleFunctionHandles.m'
% 			% 			workspace: {[1x1 struct]}
% 			info.class = '';
%
% 	end

% classsimple -> wtype:
%		'pkg.OverriddenClass constructor'
%		'static method or package function'
%		'SimpleClass method'
%		'pkg.OverriddenClass method'
%
% simple -> wtype:wloc
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




% 	function parsePotentialFcnTargets()
%
% 		% IDENTIFY BUILT-IN FUNCTIONS FROM LOCATION-STRING RETURNED BY 'WHICH'
% 		isBuiltIn = ~cellfun(@isempty, strfind(fcnFilePathList, 'built-in ('));
%
% 		% GET ARRAY OF BUILT-IN SIGNATURES (NO M-FILE)
% 		if any(isBuiltIn)
% 			%biSig = builtinSignature(fcn,info)
% 			%biType = {biSig.type};
% 			addBuiltinFcnSignature();
% 		end
%
% 		% FILL ARRAY OF SIGNATURE STRUCTS -> 1 FOR EACH CLASS
% 		k = 0;
% 		while k < numel(fcnClassList)
% 			k = k + 1;
% 			fcnClass = fcnClassList{k};
% 			fcnFile = fcnFilePathList{k};
% 			try
% 				if isBuiltIn(k)
% 					% FILL FROM BUILT-IN
% 					fcnSig(k) = biSig(strcmp(biType,fcnClass));
% 				else
% 					% PARSE ARGS FROM FILE
% 					fcnSig(k) = readFunctionFileSignature(fcnClass);
% 				end
% 			catch
% 				% USE GENERIC SIGNATURE AS BACKUP
% 				fcnSig(k) = genericSignature(fcn, info.function, fcnClass);
% 			end
% 		end
%
% 	end






% % SEPARATE INPUT FROM OUTPUT
% argsOutStr = strsplit( strtrim(tok(:,1)),...
% 	{',',' '}, 'CollapseDelimiters', true);
% argsInStr = strsplit( strtrim(tok(:,2)),...
% 	{',',' '}, 'CollapseDelimiters', true);
% % outTok = strtrim(tok(:,1));
% % inTok = strtrim(tok(:,2));
% % argsOutStr = {};
% % argsInStr = {};
% % for k=1:numel(outTok)
% % 	argsOutStr = addIfValidName( argsOutStr, outTok{k});
% % 	argsInStr = addIfValidName( argsInStr, inTok{k});
% % end
%
% 	function cstr = addIfValidName( cstr, tokstr )
% 		pVar = strsplit( tokstr, {',',' '}, 'CollapseDelimiters', true);
% 		pValid = cellfun(@isvarname, pVar);
% 		cstr(pValid) = pVar(pValid);
% 	end


%sig.Name = fcnName;
%sig.OutArgs = argsOutStr(~cellfun(@isempty,argsOutStr));
%sig.InArgs = argsInStr(~cellfun(@isempty,argsInStr));