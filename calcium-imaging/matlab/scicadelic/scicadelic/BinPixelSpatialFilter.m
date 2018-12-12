classdef (CaseInsensitiveProperties = true) BinPixelSpatialFilter < scicadelic.SciCaDelicSystem
	% BinPixelSpatialFilter
	%
	% INPUT:
	%
	% OUTPUT:
	%	Array of objects of the 'RegionOfInterest' class, resembling a RegionProps structure (Former
	%	Output) Returns structure array, same size as vid, with fields
	%			bwvid =
	%				RegionProps: [12x1 struct] bwMask: [1024x1024 logical]
	%
	% INTERACTIVE NOTE: This system uses morphological operations from the following list, which can
	% be applied sequentially to a thresholded logical array of pixels identified as potentially
	% active:
	% 	     'bothat'       Subtract the input image from its closing
	%        'branchpoints' Find branch points of skeleton 'bridge'       Bridge previously
	%        unconnected pixels 'clean'        Remove isolated pixels (1's surrounded by 0's) 'close'
	%        Perform binary closure (dilation followed by
	%                         erosion)
	%        'diag'         Diagonal fill to eliminate 8-connectivity of
	%                         background
	%        'endpoints'    Find end points of skeleton 'fill'         Fill isolated interior pixels
	%        (0's surrounded by
	%                         1's)
	%        'hbreak'       Remove H-connected pixels 'majority'     Set a pixel to 1 if five or more
	%        pixels in its
	%                         3-by-3 neighborhood are 1's
	%        'open'         Perform binary opening (erosion followed by
	%                         dilation)
	%        'remove'       Set a pixel to 0 if its 4-connected neighbors
	%                         are all 1's, thus leaving only boundary pixels
	%        'shrink'       With N = Inf, shrink objects to points; shrink
	%                         objects with holes to connected rings
	%        'skel'         With N = Inf, remove pixels on the boundaries
	%                         of objects without allowing objects to break apart
	%        'spur'         Remove end points of lines without removing
	%                         small objects completely
	%        'thicken'      With N = Inf, thicken objects by adding pixels
	%                         to the exterior of objects without connected previously unconnected
	%                         objects
	%        'thin'         With N = Inf, remove pixels so that an object
	%                         without holes shrinks to a minimally connected stroke, and an object
	%                         with holes shrinks to a ring halfway between the hole and outer boundary
	%        'tophat'       Subtract the opening from the input image
	%
	% See also: BWMORPH GPUARRAY/BWMORPH
	
	
	
	% USER SETTINGS
	properties (Access = public, Nontunable)
		MorphOp1 = 'close'
		MorphOp1Repeat = 1
		MorphOp1ComboOperation = 'xor'
		MorphOp2 = 'tophat'
		MorphOp2Repeat = 1
		MorphOp2ComboOperation = 'or'
		MorphOp3 = 'majority'
		MorphOp3Repeat = 1
		MorphOp3ComboOperation = 'and'
		MorphOp4 = 'fatten'
		MorphOp4Repeat = 2
	end
	
	% STATES
	properties (DiscreteState)
		CurrentFrameIdx %TODO: use N? or NFrames?, not DiscreteState?
	end
	
	% DYNAMIC FUNCTION HANDLES
	properties (SetAccess = protected, Hidden)
		MorphOpFcn
	end
	properties (Dependent, Hidden)
		MorphologicalOps % {'clean',1; 'close',1; 'majority',1}
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = BinPixelSpatialFilter(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));
			obj.CanUseInteractive = true;
			setPrivateProps(obj);
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj, data)
			fprintf('BinPixelSpatialFilter -> SETUP\n')
			
			% INITIALIZE
			fillDefaults(obj)
			checkInput(obj, data);
			obj.TuningImageDataSet = [];
			obj.CurrentFrameIdx = 0;
			setPrivateProps(obj)
			
			% FIX MORPH-OPS INPUT SETTINGS
			if ~isempty(obj.MorphologicalOps)
				constructMorphOpFcn(obj);
			end
			
			
		end
		function output = stepImpl(obj, data)
			
			% LOCAL VARIABLES
			n = obj.CurrentFrameIdx;
			inputNumFrames = size(data,3);
			
			% CELL-SEGMENTAION PROCESSING ON GPU
			data = onGpu(obj, data);
			output = processData(obj, data);
			
			% UPDATE NUMBER OF FRAMES
			obj.CurrentFrameIdx = n + inputNumFrames;
			
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
	end
	
	% RUN-TIME HELPER METHODS
	methods (Access = protected)
		function bwF = processData(obj, bwF)
			
			% APPLY MORPHOLOGICAL SPATIAL FILTERING TO FOREGROUND
			N = size(bwF,3);
			if ~isempty(obj.MorphOpFcn)
				morphOpFcn = obj.MorphOpFcn;
			else
				morphOpFcn = @(F) bwmorph(bwmorph(bwmorph( F, 'clean'), 'close'), 'majority');
				obj.MorphOpFcn = morphOpFcn;
			end
			for kp = 1:N
				bwF(:,:,kp) = morphOpFcn(bwF(:,:,kp));
			end
			
		end
		
	end
	
	% TUNING
	methods (Hidden)
		function varargout = tuneInteractive(obj)
			
			% LOCAL VARIABLES
			validMorphOps = obj.morphologicalOpsAvailable;
			validCombOps = obj.opCombinationsAvailable();
			numPreviousOps = 0;
			ops = obj.MorphologicalOps;
			numMorphOps = max(size(ops,1), 4);
			
			% FOR EACH MORPH-OP (1-4) ENABLE USER TO SELECT:
			%		1. OPERATION-NAME
			%		2. NUMBER OF REPETITIONS
			%		3. HOW TO COMBINE OUTPUT WITH THE FOLLOWING OPERATION
			for k = numPreviousOps + (1:3:numMorphOps*3)
				opNum = ceil((k-numPreviousOps)/3);
				
				% OPERATION-NAME
				prop.name = sprintf('MorphOp%i',opNum);
				obj.TuningStep(k).ParameterName = prop.name;
				obj.TuningStep(k).ParameterDomain = cat(1,validMorphOps, {'none'});
				if ~isempty(obj.(prop.name)) && ischar(obj.(prop.name))
					currentOp = obj.(prop.name);
				else
					currentOp = validMorphOps{end};
				end
				obj.TuningStep(k).ParameterIdx = find(~cellfun('isempty',strfind(validMorphOps, currentOp)));
				obj.TuningStep(k).Function = @testMorphOpFcn;
				obj.TuningStep(k).CompleteStep = false;
				
				% NUMBER OF OPERATION REPETITIONS
				prop.repnum = sprintf('MorphOp%iRepeat',opNum);
				obj.TuningStep(k+1).ParameterName = prop.repnum;
				obj.TuningStep(k+1).ParameterDomain = 0:10;
				if ~isempty(obj.(prop.repnum)) && isnumeric(obj.(prop.repnum))
					currentOpRep = obj.(prop.repnum);
				else
					currentOpRep = 1;
				end
				obj.TuningStep(k+1).ParameterIdx = currentOpRep;
				obj.TuningStep(k+1).Function = @testMorphOpFcn;
				obj.TuningStep(k+1).CompleteStep = false;
				
				% COMBINATION WITH FOLLOWING OPERATION
				prop.combinop = sprintf('MorphOp%iComboOperation',opNum);
				if (k==numMorphOps*3)
					break
				end
				obj.TuningStep(k+2).ParameterName = prop.combinop;
				obj.TuningStep(k+2).ParameterDomain = cat(1,validCombOps, {'as-input'});
				if ~isempty(obj.(prop.combinop)) && ischar(obj.(prop.combinop))
					currentOpComb = obj.(prop.combinop);
				else
					currentOpComb = validCombOps{end};
				end
				obj.TuningStep(k+2).ParameterIdx = find(~cellfun('isempty',strfind(validCombOps, currentOpComb)));
				obj.TuningStep(k+2).Function = @testMorphOpFcn;
				obj.TuningStep(k+2).CompleteStep = false;
				
			end
			
			obj.TuningStep(k+1).CompleteStep = true;
			
			% SET UP TUNING WINDOW (OR RETURN TUNING STEPS FOR PARENT SYSTEM TO CALL)
			setPrivateProps(obj)
			if nargout
				varargout{1} = obj.TuningStep;
			else
				createTuningFigure(obj);			%TODO: can also use for automated tuning?
			end
			
		end
		function tuneAutomated(obj)
			% TODO
			obj.TuningImageDataSet = [];
		end
		function bw = testMorphOpFcn(obj, bw)
			% Used by interactive tuning procedure. Will perform a single operation when each
			% morphological operation name (cell-string) input is passed, but will perform all currently
			% specified steps when user is changing the number of repetitions for the current operation.
			% 			validOps = obj.morphologicalOpsAvailable;
			% 			if iscell(opSpec)
			% 				opName = opSpec{1};
			% 			else
			% 				opName = opSpec;
			% 			end
			% 			if (nargin < 3) || isempty(opName) || ~any(strcmpi(opName, validOps))
			fcn = constructMorphOpFcn(obj);
			bw = fcn(bw);
		end
	end
	
	% INITIALIZATION HELPER METHODS
	methods (Hidden)
		function varargout = constructMorphOpFcn(obj, ops)
			% CONSTRUCT ANONYMOUS FUNCTION CHAINING MULTIPLE 'BWMORPH' FUNCTION-CALLS
			if nargin < 2
				ops = obj.MorphologicalOps;
			end
			if ~isempty(ops)
				% EACH PART MAY HAVE A STRING DESIGNATING THE OPERATION, A NUMBER, AND A TRANSITION
				opNames = ops(:,1);
				if all(cellfun(@ischar, ops(:)))
					opNumRepeat = num2cell(ones(numel(ops),1));
				else
					opNumRepeat = ops(:,2);
				end
				numOps = numel(opNames);
				
				if (size(ops,2) <= 2)
					% INITIALIZE FUNCTION IN STRING FORM THEN CHAIN SUCCEEDING FUNCTIONS AS INPUT
					strFcn = '@(bw) ';
					
					if any([opNumRepeat{:}]>1)
						% CALL BWMORPH() WITH 3 ARGUMENTS: i.e. bwmorph(bw, 'close', 3)
						for k=1:numOps
							strFcn = [strFcn, 'bwmorph('];
						end
						strFcn = [strFcn, ' bw '];
						for k=1:numOps
							strFcn = [strFcn, sprintf(', ''%s'', %i)', opNames{k}, opNumRepeat{k})];
						end
						fcn = str2func(strFcn);
						
					else
						% CALL BWMORPH() WITH 2 ARGUMENTS: i.e. bwmorph(bw, 'close')
						for k=1:numOps
							strFcn = [strFcn, 'bwmorph('];
						end
						strFcn = [strFcn, ' bw '];
						for k=1:numOps
							strFcn = [strFcn, sprintf(', ''%s'')', opNames{k})];
						end
						fcn = str2func(strFcn);
					end
					
				else
					% ALLOW FOR ALTERNATIVE COMBINATIONS OF SUCCESSIVE FUNCTIONS
					opCombinOp = ops(:,3);
					strCurrentInput = 'bw';
					strPreNext = '';
					strPostNext = '';
					for k=1:numOps
						strFcn = [...
							strPreNext,...
							'bwmorph(', strCurrentInput, ...
							sprintf(',''%s'',%i)', opNames{k}, opNumRepeat{k}),...
							strPostNext];
						if isempty(opCombinOp{k}) || (k==numOps)
							strPreNext = '';
							strPostNext = '';
							strCurrentInput = strFcn;
						else
							strCurrentInput = 'bw';
							strPreNext = [opCombinOp{k},'( ',strFcn,' , '];
							strPostNext = ')';
						end
					end
					fcn = str2func(['@(bw) ', strFcn]);%TODO: may need to go back to eval() as str2func not supported by codegen?
				end
			else
				fcn = @(bw) bw;
			end
			
			% STR2FUNC(FUNC2STR(... CLEANS THE ANONYMOUS FUNCTION HANDLE OF UNNECESSARY WORKSPACE
			fcn = str2func(func2str(fcn));
			obj.MorphOpFcn = fcn;
			if nargout
				varargout{1} = fcn;
			end
		end
	end
	methods (Access = protected, Hidden)
		function setPrivateProps(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			for k=1:numel(oProps)
				prop = oProps(k);
				if prop.Name(1) == 'p'
					pname = prop.Name(2:end);
					try
						pval = obj.(pname);
						obj.(prop.Name) = pval;
					catch me
						getReport(me)
					end
				end
			end
		end
		function fetchPropsFromGpu(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			propSettable = ~[oProps.Dependent] & ~[oProps.Constant];
			for k=1:length(propSettable)
				if propSettable(k)
					pn = oProps(k).Name;
					try
						if isa(obj.(pn), 'gpuArray') && existsOnGPU(obj.(pn))
							obj.(pn) = gather(obj.(pn));
							obj.GpuRetrievedProps.(pn) = obj.(pn);
						end
					catch me
						getReport(me)
					end
				end
			end
		end
		function pushGpuPropsBack(obj)
			fn = fields(obj.GpuRetrievedProps);
			for kf = 1:numel(fn)
				pn = fn{kf};
				if isprop(obj, pn)
					if obj.UseGpu
						obj.(pn) = gpuArray(obj.GpuRetrievedProps.(pn));
					else
						obj.(pn) = obj.GpuRetrievedProps.(pn);
					end
				end
			end
		end
	end
	
	% GET FUNCTIONS FOR VALIDATING PROPERTY INPUT
	methods
		function opList = get.MorphologicalOps(obj)
			% PULLS USER INPUT FROM PROPERTIES NAMED MORPHOP1, MORPHOP2, ETC
			opList = {};
			validMorphOps = obj.morphologicalOpsAvailable;
			validCombOps = obj.opCombinationsAvailable();
			m = 1;
			prop.combop = sprintf('MorphOp%iComboOperation',m);
			prop.name = sprintf('MorphOp%i',m);
			prop.repnum = sprintf('MorphOp%iRepeat',m);
			opNum = 0;
			
			% CHECK EACH NUMBERED PROPERTY AND ADD TO CELL ARRAY
			while isprop(obj, prop.name)
				opName = obj.(prop.name);
				if iscell(opName)
					opName = opName{1};
				end
				opRep = obj.(prop.repnum);
				if isprop(obj, prop.combop)
					opComb = obj.(prop.combop);
				else
					opComb = [];
				end
				
				% CHECK THAT OPERATION NAME IS VALID
				if ~isempty(opName) ...
						&& ischar(opName) ...
						&& any(strcmpi(opName, validMorphOps)) ...
						&& (opRep>=1)
					opNum = opNum + 1;
					opList{opNum, 1} = opName;
					opList{opNum, 2} = opRep;
					if ~isempty(opComb) ...
							&& any(strcmpi(opComb, validCombOps))
						opList{opNum, 3} = opComb;
					end
				end
				
				% MOVE ON TO NEXT PROPERTY (IF IT EXISTS)
				m = m + 1;
				prop.combop = sprintf('MorphOp%iComboOperation',m);
				prop.name = sprintf('MorphOp%i',m);
				prop.repnum = sprintf('MorphOp%iRepeat',m);
			end
		end
	end
	
	% STATIC HELPER METHODS
	methods (Static)
		function validOperations = morphologicalOpsAvailable()
			% 			validOperations = {...
			% 				     'bothat',...       Subtract the input image from its closing
			% 			       'branchpoints',... Find branch points of skeleton 'bridge',... Bridge
			% 			       previously unconnected pixels 'clean',...        Remove isolated pixels (1's
			% 			       surrounded by 0's) 'close',...        Perform binary closure (dilation followed
			% 			       by 'diag',...         Diagonal fill to eliminate 8-connectivity of
			% 			       'endpoints',...    Find end points of skeleton 'fill',...         Fill isolated
			% 			       interior pixels (0's surrounded by 'hbreak',...       Remove H-connected pixels
			% 			       'majority',...     Set a pixel to 1 if five or more pixels in its 'open',...
			% 			       Perform binary opening (erosion followed by 'remove',...       Set a pixel to 0
			% 			       if its 4-connected neighbors 'shrink',...       With N = Inf, shrink objects to
			% 			       points; shrink 'skel',...         With N = Inf, remove pixels on the boundaries
			% 			       'spur',...         Remove end points of lines without removing 'thicken',...
			% 			       'thin',... 'tophat'};
			validOperations = {...
				'bothat',...
				'branchpoints',...
				'bridge',...
				'clean',...
				'close',...
				'diag',...
				'dilate',...
				'endpoints',...
				'erode',...
				'fatten',...
				'fill',...
				'hbreak',...
				'majority',...
				'perim4',...
				'perim8',...
				'open',...
				'remove',...
				'shrink',...
				'skeleton',...
				'spur',...
				'thicken',...
				'thin',...
				'tophat'};
			validOperations = validOperations(:);
		end
		function validOperations = opCombinationsAvailable()
			validOperations = {
				'and'
				'or'
				'not'
				'xor'
				};
		end
	end
	
	
	
	
end
































