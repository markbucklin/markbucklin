classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible)...
		DataArray < ignition.core.Object
	%{
	DATAARRAY - Base class for core referenceable datatype
	
		%}
		
		
		
		properties (SetAccess = protected)%?ignition.core.Object)
			Data
		end
		properties (SetAccess = protected)%?ignition.core.Object)
			NumRows
			NumCols
			NumDimensions
			NewDataFlag @logical = false
			DataSize
			DataType
		end
		properties (SetAccess = ?ignition.core.Object, Hidden)
			CountDimension = 4		% Dimension used to concatenate Multi-Column arrays of data containers
			ConcurrentDimension = 3		% Channel
			OrderedInputPropNames = {'Data'}
		end
		properties (SetAccess = ?ignition.core.Object, Hidden)
			NumElements
		end
% 		properties (SetAccess = immutable, Hidden)
% 			BlankConstructor @function_handle % todo -> implement in Object class (uncomment)
% 		end
		
		
		
		
		% CONSTRUCTOR
		methods
			function obj = DataArray(varargin)
				% >> obj = DataArray( data )
				
				% BUILD CONSTRUCTOR FUNCTION HANDLE (todo -> remove, function moved to object copyProps?)
% 				obj.BlankConstructor = str2func(class(obj));
				
				% ALLOW EMPTY-INPUT CONSTRUCTION FROM DERIVED CLASSES & ARRAY INITIALIZATION
				if nargin										
					% FIRST CHECK IF INPUT IS A DATA-ARRAY -> COPY
					if isa(varargin{1}, 'ignition.core.type.DataArray')
						obj = copyProps( obj, varargin{1});
						if nargin > 1
							obj = parseConstructorInput(obj, varargin{2:end});
						end
					
					else
					
						% 					% OTHERWISE ASSUME INPUT COMPLIANT WITH 'ORDERED-INPUT-PROP-NAMES' (DATA,INFO)
						% 					data = varargin{1};
						%
						% 					% GET NUMBER OF NODES INTENDED TO BE CREATED & LINKED WITH THIS CONSTRUCTION
						% 					numElements = numel(data);
						%
						% 					% PROCEED WITH MULTI- OR SINGLE-ELEMENT CONSTRUCTION
						% 					if (numElements > 1) && ~isnumeric(data)
						% 						% INITIALIZE EMPTY OBJECT ARRAY
						% 						obj(numElements) = feval(obj.BlankConstructor);
						%
						% 					end
					
					% ADD SPECIFIED DATA TO INTERNAL PROPS BY CALLING GENERALIZABLE CLASS METHOD
					obj = parseOrderedInput(obj, varargin{:});
				
					end
					
					% UPDATE DATA-DESCRIPTORS FOR FASTER ACCESS
					if any([obj.NewDataFlag])
						obj = applyUpdates(obj);
					end
					
				end								
				
			end
		end
		
		% CONVENIENCE METHODS - OVERLOADING METHODS SHARED FUNCTIONS
		methods
			function dataSize = getDataSize(obj)
				% RETURNS UNIVERSAL DATA SIZE
				countDim = obj(1).CountDimension;
				singleContainerSize = cat(1, obj.DataSize); %todo -> multichannel
				dataSize = max(singleContainerSize,[],1);
				dataSize(countDim) = sum(singleContainerSize(:,countDim));
			end
			function dataType = getDataType(obj)
				dataType = obj(1).DataType;
			end
			function varargout = getData(obj)
				% 			data = cat(obj(1).CountDimension, obj.Data);
				countDim = obj(1).CountDimension;
				concurrentDim = obj(1).ConcurrentDimension;
				[numConcurrentOut, ~] = size(obj); % [numConcurrentOut, numSequentialOut]
				nargoutchk(1, numConcurrentOut);
				
				if (numel(obj) == 1)
					% SIMPLE DIRECT OUTPUT
					data = obj.Data;
					varargout{1} = data;
					
				elseif ismatrix(obj)
					if (nargout == 1)
						% OUTPUT AS SINGLE LARGE N-D ARRAY
						dataSize = getDataSize(obj);
						catDim = min(concurrentDim, countDim);
						data = reshape( cat( catDim, obj.Data), dataSize);
						varargout{1} = data;
						
					else
						% OUTPUT WITH CONCURRENT STREAMS (CHANNELS) SEPARATED
						argsOut = cell(1,nargout);
						for k=1:nargout
							sequentialObj = obj(k,:);
							argsOut{k} = cat(countDim, sequentialObj.Data);
						end
						varargout = argsOut;
					end
					
				else
					% ASSUME 1-D LIST OF CONTAINERS IS SEQUENTIAL
					varargout{1} = cat(countDim, obj.Data);
					
				end
				
			end
			function obj = setData(obj, F)
				
				% CREATE DEFERRED TASK OBJECT FOR ASYNCHRONOUS ASSIGNMENT
				persistent deferredTaskSchedulerObj
				if isempty(deferredTaskSchedulerObj)
					deferredTaskSchedulerObj = ignition.stream.DeferredTask();
				end
				
				if isa(obj, 'handle')
					% SCHEDULE DEFERRED TASK OBJECT
					accessFcn = @setDataAccessFcn;
					schedule(deferredTaskSchedulerObj, accessFcn, 0, F);
					
				else
					% CALL CONSTRUCTION HELPER METHOD TO ASSIGN DATA SYNCHRONOUSLY
					obj = parseOrderedInput(obj, F);
					% todo -> applyUpdates
					
				end
				
				function setDataAccessFcn(f)
					parseOrderedInput(obj, f);
					applyUpdates(obj);
				end
				
			end
			function propCopy = getPropsInCellArray(obj, inputNames)
				% can be passed
				if nargin < 2
					inputNames = obj(1).OrderedInputPropNames;
				end
				numInputNames = numel(inputNames);
				
				for kInput = 1:numInputNames
					propCopy{kInput} = { obj.(inputNames{kInput}) };
				end
			end
			function newObj = copyWithNewData(obj, newData)
				inputPropNames = obj(1).OrderedInputPropNames;
				isDataProp = ~strcmpi(inputPropNames, 'Data');
				nonDataPropNames = inputPropNames(~isDataProp);
				infoEtc = getPropsInCellArray( obj, nonDataPropNames);
				
				args = cell(size(inputPropNames));
				args(~isDataProp) = infoEtc;
				args(isDataProp) = newData;
				
				%objClassName = class(obj);
				% newObjConstructor = obj.BlankConstructor;
				constructorFcn = ignition.util.getClassConstructor(obj);
				
				newObj = feval(constructorFcn, args{:});
				
				
				% OR CONSTRUCT BLANK & COPY PROPERTIES todo
				
			end
			function flag = isOnGpu(obj)
				flag = true(size(obj));
				try
					for k=1:numel(obj)
						F = obj(k).Data;
						if isempty(F) || ~isa(F,'gpuArray')
							flag(k) = false;
						elseif existsOnGPU(F)
							flag(k) = false;
						end
					end
				catch
					flag = false;
				end
			end
		end
		
		% INTERNAL UPDATE OF UNDERLYING DATA
		methods (Access = protected, Hidden)
			function obj = parseOrderedInput(obj, varargin)
				
				if (nargin > 1)					
					
					% CONSTANT LIST OF ORDERED INPUT NAMES
					orderedInputNames = obj(1).OrderedInputPropNames;
					numInputs = nargin - 1;
					
					
					% GET FORMAT OF ORDERED INPUT ARGUMENTS (CELL -> MULTIOBJ)					
					numInputElements = min(cellfun(@numel, varargin));
					numObjIn = numel(obj);
					firstArg = varargin{1};
					
					if iscell(firstArg) || isobject(firstArg) || isstruct(firstArg)
						
						% EXPAND/RESHAPE OBJECTS TO FIT DATA
						if (numObjIn < numInputElements)							
							numObjOut = numInputElements;
% 							constructorFcn = ignition.util.getClassConstructor(obj);
% 							obj(numObjOut) = constructorFcn();
% 							obj(numObjOut) = feval(obj.BlankConstructor);

						else
							numObjOut = min(numObjIn, numInputElements);
						end
% 						obj = reshape(obj(1:numObjOut), size(firstArg) );
						
						
						
					else
						numObjOut = numObjIn;
						
					end
					
					for kInput = 1:numInputs
						inputName = orderedInputNames{kInput};
						inputArg = varargin{kInput};
						
						if iscell(inputArg)
							% CELL-PARTITIONED INPUT
							[obj(1:numObjOut).(inputName)] = inputArg{:};
% 							obj = reshape(obj(1:numObjOut), size(inputArg));
							
						else
							% NON-CELL INPUT
							for kObj = 1:numObjOut
								switch numel(inputArg)
									case 1
										% SCALAR INPUT (REPLICATE)
										obj(kObj).(inputName) = inputArg;
										
									case numObjOut
										% VECTOR OF NUMERIC OR STRUCTURED
										obj(kObj).(inputName) = inputArg(kObj);
										
									otherwise
										% MULTIDIM ARRAY -> ASSUME DATA
										obj(kObj).(inputName) = inputArg(:,:,:,kObj);
										% todo: generic slice through count dimension
										
								end
							end
						end
					end
					
					
					% SET NEW DATA FLAG -> TRUE
					[obj(1:numObjOut).NewDataFlag] = deal(true);
					%newDataFlagArray = num2cell(true(1,numObjOut));
					%[obj(1:numObjOut).NewDataFlag] = newDataFlagArray{:};
					
					% new (moved)
					obj = reshape(obj(1:numObjOut), size(firstArg) );
					
				end
				
				
			end
			function obj = applyUpdates(obj)% horrendous
				% applyUpdates() - update DataSize & DataType if Data is available
				
				if any([obj.NewDataFlag])
					% RUN UPDATE METHODS
					% 				obj = updateDataSize(obj);
					% 				obj = updateDataType(obj);
					
					% RESET NEW-DATA FLAG
					% 				[obj.NewDataFlag] = deal(false);
					
					% INLINE UPDATE (FASTER THAN SEPARATE METHOD CALLS FOR VALUE CLASSES)
					countDim = obj(1).CountDimension;
					for k=1:numel(obj)
						rawData = obj(k).Data;
						if ~isempty(rawData)
							
							% UPDATE DATA SIZE
							rawSize = size(rawData);
							rawDim = numel(rawSize);
							numRows = rawSize(1);
							numCols = rawSize(2);
							stackableSize = ones(1,countDim);
							stackableSize(1:rawDim) = rawSize;
							obj(k).NumRows = numRows;
							obj(k).NumCols = numCols;
							obj(k).DataSize = stackableSize;
							obj(k).NumDimensions = ndims(rawData);
							
							% UPDATE DATA-TYPE
							if isa(rawData, 'gpuArray')
								obj(k).DataType = classUnderlying(rawData);
							else
								obj(k).DataType = class(rawData);
							end
							
							% RESET NEW-DATA FLAG
							obj(k).NewDataFlag = false;
							
						else
							obj(k).DataType = '';
							
						end
					end
					
					
				end
				
				
			end
			function obj = updateDataSize(obj)
				countDim = obj(1).CountDimension;
				for k=1:numel(obj)
					rawData = obj(k).Data;
					if ~isempty(rawData)
						% GET INFORMATION ABOUT DATA (DIMENSIONS, TYPE, ETC)
						rawSize = size(rawData);
						rawDim = numel(rawSize);
						numRows = rawSize(1);
						numCols = rawSize(2);
						stackableSize = ones(1,countDim);
						stackableSize(1:rawDim) = rawSize;
						obj(k).NumRows = numRows;
						obj(k).NumCols = numCols;
						obj(k).DataSize = stackableSize;
					end
				end
			end
			function obj = updateDataType(obj)
				for k=1:numel(obj)
					rawData = obj(k).Data;
					if ~isempty(rawData)
						% UPDATE DATA-TYPE
						if isa(rawData, 'gpuArray')
							obj(k).DataType = classUnderlying(rawData);
						else
							obj(k).DataType = class(rawData);
						end
					else
						obj(k).DataType = '';
					end
				end
			end
		end
		
		% OVERLOAD BUILT-IN MATLAB FUNCTIONS
		methods
			function obj = gpuArray(obj)
				gpuFlag = isOnGpu(obj);
				if ~all(gpuFlag)
					for k = 1:numel(obj)
						if ~gpuFlag(k)
							obj(k).Data = gpuArray(obj(k).Data);
						end
					end
				end
			end
		end
		
		
		
		
		
		
		
		
		
end





















% % SET DEFAULT CONTAINER-STACKING (COUNT) DIMENSION
% 			if isempty(obj.CountDimension)
% 				obj.CountDimension = 4;
% 			end


%
% 	methods
% 		function obj = updateFrameData(obj)
% 			% frameData = reshape(frameData, numRows, numCols, numChannels, numFrames);
% 		end
% 		function obj = updateIdx(obj)
% 			% todo
% 		end
% 		function obj = updateTimestamp(obj)
% 			% todo
% 		end
% 		function obj = updateInfo(obj)
% 			% todo
% 		end
% 	end
