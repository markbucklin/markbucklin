function displayStructure(s)

% CLEAR SCREEN
clc

% SUPPRESS WARNINGS
warning('off','MATLAB:structOnObject')

% SET RECURSION LIMIT
numIndent = 1;
% recursLim = 20;

% DECLARE DISPLAY FUNCTION
% show = @datatipinfo;

% INITIALIZE ARRAY TO RECORD SHOWN HANDLES
displayedObj = {};

% SHOW INITIAL SIZE (IF NON-SCALAR)
if ~isscalar(s)
	datatipinfo(s)
	fprintf('\n')
end


% TOP LEVEL CHECK IF INPUT IS AN OBJECT
if isobject(s)
	% GET TOP STRUCTURE NAME FROM CLASS
	topStructName = class(s);
	try
		if isa(s, 'handle')
			displayedObj = [displayedObj, {s}];
		end
		s = struct(s);
	catch
	end
else
	% GET TOP STRUCTURE NAME FROM INPUT VARIABLE NAME
	topStructName = inputname(1);
	if isempty(topStructName)
		topStructName = 'S';
	end
end
fieldNameList = {topStructName};
fprintf('%s\n\n', topStructName)

% ENABLE PAGED OUTPUT & CALL SUBFUNCTION
more on
showStructVals(s);
% showStructVals(s, show, displayedObj);
more off








% 	function displayedObj = showStructVals(s, show, displayedObj)
	function showStructVals(s)
		% 		persistent numIndent
		% 		persistent lastFld
		% 		if isempty(numIndent)
		% 			numIndent = 1;
		% 		end
		% 		if isempty(lastFld)
		% 			lastFld = '';
		% 		end
		
		N = numel(s);
		if (N > 8), N=1; end
		n=1;
		
		fld = fieldnames(s,'-full');
		
		
		% 		if ~isscalar(s)
		% 			datatipinfo(s)
		% 			numIndent = numIndent + 1;
		% 			fprintf('\n')
		% 		end
		if N>1
			numIndent = numIndent + 1;
		end
		
		more off
		fprintf('\n')
		more on
		
		while(n<=N)
			
			more(numel(fld)+1)
			disp(s(n))
			
			for k=1:numel(fld)
				try
					sval = s(n).(fld{k});
				catch
					break
				end
				
				% BREAK IF EMPTY
				if isempty(sval)
					continue
				end
				
				% CONVERT OBJECT TO STRUCT
				if isobject(sval)
					try
						% AVOID REPEAT DISPLAY OF HANDLES
						if isa(sval,'handle')
							% CHECK MATCHES TO PREVIOUS
							try
								objMatch = cellfun(@eq, displayedObj,...
									repelem({sval},numel(displayedObj)));
							catch
								objMatch = cellfun(@any, ...
									cellfun(@eq, displayedObj, ...
									repelem({sval},numel(displayedObj)),'UniformOutput',false));
							end
							
							% BREAK ON ANY MATCHES
							if any(objMatch)
								continue %break
							else
								displayedObj = [displayedObj, {sval}];
							end
							
						end
						
						% CONVERT OBJECT TO STRUCT
						sobj = sval;
						if isa(sobj, 'containers.Map')
							if strcmp(sobj.KeyType,'char')
								sval = cell2struct( sobj.values, sobj.keys, 2);
							else
								sval = [];
							end
							
						elseif ~isscalar(sobj)
							sval = struct.empty();
							sval(numel(sobj)) = struct(sobj(end));
							for ko=1:(numel(sobj)-1)
								sval(ko) = struct(sobj(ko));
							end
							
						else
							sval = struct(sobj);
						end
						
					catch me
						sval = [];
						disp(getReport(me))
					end
				end
				
				% RECURSIVE CALL TO SHOW STRUCTURE CONTAINED IN STRUCTURE FIELD
				if isstruct(sval)
					% 					numIndent = numIndent + 1;
					% 					fprintf([indentString{:},'%s:\n'],fld{k})
					
					more off
					fprintf('\n')					
					indentString = repelem({'\t'},1,max(0,numIndent));
					fieldListString = [ sprintf('%s.',fieldNameList{:}), fld{k}];
					fprintf([indentString{:},'%s:\n'], fieldListString)
					
					fieldNameList = [fieldNameList, fld(k)];
					showStructVals(sval)
					fprintf('\n\n')
					more on
					fieldNameList(end) = [];
					
					
					% 					numIndent = numIndent - 1;
					
				end
			end
			
			n=n+1;
			%
			% 			more off
			% 			fprintf('\n\n')
			% 			more on
			%
		end
		
		more off
		fprintf('\n')
		% 		more on
		
		% 		if ~isscalar(s)
		if N>1
			numIndent = numIndent - 1;
		end
		
	end


end












% 	function recursLim = showStructVals(s, show, recursLim)
%
%
% 		if recursLim<1
% 			return
% 		else
% 			recursLim = recursLim-1;
% 		end
%
% 		N = numel(s);
% 		if (N > 8), N=1; end
% 		n=1;
%
% 		fld = fieldnames(s,'-full');
%
% 		while(n<=N)
% 			show(s(n))
% 			for k=1:numel(fld)
% 				try
% 					sval = s(n).(fld{k});
% 				catch
% 					break
% 				end
% 				if isstruct(sval) || isobject(sval)
% 					if isobject(sval)
% 						try
% 							sval = struct(sval);
% 						catch
% 						end
% 					end
% 					fprintf('%s:\n',fld{k})
% 					recursLim = showStructVals(sval,show,recursLim);
% 					fprintf('\n')
% 					if (recursLim<1)
% 						break
% 					end
% 					% 				elseif isjava(sval)
% 					% 					try get(sval), catch, end
% 				end
% 				% 				if recursLim<1
% 				% 					break
% 				% 				end
% 			end
% 			n=n+1;
% 		end
% 	end

