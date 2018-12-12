function [bw, varargout] = bwmorphn(bw, opInput)
% ------------------------------------------------------------------------------
% BWMORPHN
% 7/30/2015
% Mark Bucklin
% ------------------------------------------------------------------------------
%
% DESCRIPTION:
%		Operation input may be a cell array of ops, a string defining 1 operation, or the
%		function_handle that is returned as the optional second output argument of this function.
%
% USAGE:
%			>> bw = bwmorphn(bw,'thicken');
%			>> [bw,fcn] = bwmorphn(bw,'thicken');
%			>> [bw,fcn] = bwmorphn(bw,{'clean','majority','fill'});
%			>> [bw,fcn] = bwmorphn(bw,{'shrink',inf});
%			>> [bw,fcn] = bwmorphn(bw,{'shrink',inf, 'thicken',1});
%
% See also:
%	SCICADELIC.CELLSEGMENTER SCICADELIC.CELLDETECTOR GPUARRAY\BWMORPH BWMORPH
% ------------------------------------------------------------------------------
% ------------------------------------------------------------------------------
% ------------------------------------------------------------------------------



% GET INPUT SIZE
[numRows,numCols,dim3,dim4] = size(bw);

% CREATE FUNCTION HANDLE USING INPUT ARGUMENTS, OR REUSE IF INPUT IS A FUNCTION-HANDLE
if isa(opInput,'function_handle')
	fcn = opInput;	
elseif iscell(opInput)
	fcn = constructMorphOpFcn(opInput);
elseif ischar(opInput)
	fcn = constructMorphOpFcn({opInput});
end

% RESHAPE ND-INPUT TO 2D
bw2d = reshape(bw,numRows,[],1);

% EXECUTE FUNCTION ON MATRIX INPUT
bw2d = fcn(bw2d);

% RESHAPE OUTPUT TO ND
bw = reshape(  bw2d, numRows, numCols, dim3, dim4);


% RETURN FUNCTION HANDLE IF REQUESTED -> IMPROVES SPEED OF SECOND CALL
if nargout > 1
	varargout{1} = fcn;
end




function fcn = constructMorphOpFcn(ops)
			% CONSTRUCT ANONYMOUS FUNCTION CHAINING MULTIPLE 'BWMORPH' FUNCTION-CALLS			
			if ~isempty(ops)
				isOpName = cellfun(@ischar, ops(:));
				opNameIdx = find(isOpName);
				opNames = ops(isOpName);
				numOps = numel(opNames);
				strFcn = '@(bw) ';
				if sum(isOpName) < numel(ops)
					for k=1:numOps
						strFcn = [strFcn, 'bwmorph('];
					end
					strFcn = [strFcn, ' bw '];
					for k=1:numOps
						nextIdx = opNameIdx(k)+1;
						if nextIdx<=numel(ops) && isnumeric(ops{nextIdx})
							opNumRepeat = ops{nextIdx};
						else
							opNumRepeat = 1;
						end
						strFcn = [strFcn, sprintf(', ''%s'', %i)', opNames{k}, opNumRepeat)];
					end
					fcn = eval(strFcn);
				else
					for k=1:numOps
						strFcn = [strFcn, 'bwmorph('];
					end
					strFcn = [strFcn, ' bw '];
					for k=1:numOps
						strFcn = [strFcn, sprintf(', ''%s'')', opNames{k})];
					end
					fcn = eval(strFcn);
				end
			else
				fcn = @(bw) bw;
			end
			
			% STR2FUNC(FUNC2STR(... CLEANS THE ANONYMOUS FUNCTION HANDLE OF UNNECESSARY WORKSPACE
			fcn = str2func(func2str(fcn));
			
end		
	
	end
