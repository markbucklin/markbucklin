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
			NewDataFlag = false
			DataSize
			DataType
		end		
		properties (SetAccess = ?ignition.core.Object, Hidden)
			NumElements
		end
		properties (Abstract, SetAccess = immutable, Hidden)
			CountDimension % = 4		% Dimension used to concatenate Multi-Column arrays of data containers
			ConcurrentDimension % = 3		% Channel
			AdditionalInputPropNames % = {'Data'}
		end
		
		
		
		
		
		% CONSTRUCTOR
		methods
			function obj = DataArray(data, varargin)
				% >> obj = DataArray( data )
				
				% todo -> implement this setting stuff in DataArrayReference & DataArrayValue
				
				% ALLOW EMPTY-INPUT CONSTRUCTION FROM DERIVED CLASSES & ARRAY INITIALIZATION
				if nargin										
					
					% CHECK TYPE OF INPUT
					if isa(data, 'ignition.core.type.DataArray')
						% DATA-ARRAY -> COPY (method from ignition.core.Object)
						obj = copyProps( obj, data);
						
					else
						
						% DETERMINE NUMBER OF CONTAINER INTENDED TO BE CREATED
						if ~isnumeric(data)							
							% SINGLE- OR MULTI-CONTAINER -> DEPENDING ON NUM-INPUTS
							numObj = numel(data);
							if numObj>1
								if isa(obj, 'handle')
									constructorFcn = ignition.util.getClassConstructor(obj);
									obj(numObj) = constructorFcn();
								else
									obj(numObj) = obj(1);
								end
							end
						end
						
						% ASSIGN DATA
						argsIn = [{data} , varargin];
						obj = parseOrderedInput(obj, argsIn{:});
						% 						if nargin > 1
						% 							obj = setData(obj, data, varargin{:});
						% 						else
						% 							obj = setData(obj, data);
						% 						end
						
					
					% ADD SPECIFIED DATA TO INTERNAL PROPS BY CALLING GENERALIZABLE CLASS METHOD
					% 					obj = parseOrderedInput(obj, varargin{:});
				
					end
					
					% UPDATE DATA-DESCRIPTORS FOR FASTER ACCESS
					% 					if any([obj.NewDataFlag])
					% 						obj = applyUpdates(obj);
					% 					end
					
				end								
				
			end
			function obj = setData(obj, data, varargin)
				
				% CREATE DEFERRED TASK OBJECT FOR ASYNCHRONOUS ASSIGNMENT
				% 				persistent deferredTaskSchedulerObj
				% 				if isempty(deferredTaskSchedulerObj)
				% 					deferredTaskSchedulerObj = ignition.stream.DeferredTask();
				% 				end
				
				% EXPAND OBJECT ARRAY TO FIT NUMBER OF DATA TOKENS
				% todo!
				
				% GROUP ARGUMENTS (ALLOW FOR ADDITIONAL ORDERED INPUT)
				argsIn = [ {data} , varargin];
				
% 				if isa(obj, 'handle')
% 					% SCHEDULE DEFERRED TASK OBJECT
% 					accessFcn = @setDataAccessFcn;
% 					schedule(deferredTaskSchedulerObj, accessFcn, 0, argsIn);
% 					
% 				else
					% CALL CONSTRUCTION HELPER METHOD TO ASSIGN DATA SYNCHRONOUSLY
					obj = parseOrderedInput(obj, argsIn{:});
					obj = applyUpdates(obj);
					
% 				end
				
				% SUBFUNCTION CALLED BY TASK SCHEDULER (WORKS WITH HANDLE-TYPE ONLY)
% 				function setDataAccessFcn(queuedArgs)
% 					parseOrderedInput(obj, queuedArgs{:});
% 					applyUpdates(obj);
% 				end
				
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
			function propCopy = getPropsInCellArray(obj, inputNames)
				% can be passed
				if nargin < 2
					inputNames = [{'Data'} , obj(1).AdditionalInputPropNames];
				end
				numInputNames = numel(inputNames);
				
				for kInput = 1:numInputNames
					propCopy{kInput} = { obj.(inputNames{kInput}) };
				end
			end
			function newObj = copyWithNewData(obj, newData)
				inputPropNames = [{'Data'} , obj(1).AdditionalInputPropNames];
				isDataProp = ~strcmpi(inputPropNames, 'Data'); % todo: no longer necessary
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
					data = varargin{1};
					orderedInputNames = [{'Data'} , obj(1).AdditionalInputPropNames];
					numInputs = nargin - 1;
										
					% GET FORMAT OF ORDERED INPUT ARGUMENTS (CELL -> MULTIOBJ)										
					numObj = numel(obj);					
					
					% ASSIGN INPUTS TO EACH OBJECTS PROPERTIES
					for kInput = 1:numInputs
						inputName = orderedInputNames{kInput};
						inputArg = varargin{kInput};
						
						if iscell(inputArg)
							% CELL-PARTITIONED INPUT
							[obj(1:numObj).(inputName)] = inputArg{:};													
							
						else
							% NON-CELL INPUT
							for kObj = 1:numObj
								switch numel(inputArg) % todo -> size(inputArg,2)
									case 1
										% SCALAR INPUT (REPLICATE)
										obj(kObj).(inputName) = inputArg;
										
									case numObj
										% VECTOR OF NUMERIC OR STRUCTURED
										obj(kObj).(inputName) = inputArg(kObj);
										
									otherwise
										% MULTIDIM ARRAY -> NUMERIC DATA ARRAY ?
										obj(kObj).(inputName) = inputArg;
										
								end
							end
						end
												
					end
					
					% SET NEW DATA FLAG -> TRUE
					[obj(1:numObj).NewDataFlag] = deal(true);
					%newDataFlagArray = num2cell(true(1,numObjOut));
					%[obj(1:numObjOut).NewDataFlag] = newDataFlagArray{:};
					
					% new (moved)
					if ~isnumeric(data)
						obj = reshape(obj(1:numObj), size(data) );
					end
					
					
					% (NEW) REPLACE APPLYUPDATES
					if (numObj > 1)	
						% ASSUME CELL -> todo
						cSize = cellfun( @ignition.shared.getPaddedDataSize, data,...
							'UniformOutput',false);
						dimArray = cat(1,cSize{:});
						cDimArray = num2cell(dimArray);
						[obj.DataSize] = cSize{:};
						[obj.NumRows] = cDimArray{:,1};
						[obj.NumCols] = cDimArray{:,2};
						[obj.DataType] = deal(ignition.shared.getDataType(data));
					else
						sz = ignition.shared.getPaddedDataSize(data);
						obj.DataSize = sz;
						obj.NumRows = sz(1);
						obj.NumCols = sz(2);
						obj.DataType = ignition.shared.getDataType;
					end
					
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












% 
% 
% 
% 
% 
% 
% function obj = parseOrderedInput(obj, varargin)
% 
% if (nargin > 1)
% 	
% 	% CONSTANT LIST OF ORDERED INPUT NAMES
% 	orderedInputNames = obj(1).AdditionalInputPropNames;
% 	numInputs = nargin - 1;
% 	
% 	
% 	% GET FORMAT OF ORDERED INPUT ARGUMENTS (CELL -> MULTIOBJ)
% 	numInputElements = min(cellfun(@numel, varargin));
% 	numObjIn = numel(obj);
% 	firstArg = varargin{1};
% 	
% 	if iscell(firstArg) || isobject(firstArg) || isstruct(firstArg)
% 		
% 		% EXPAND/RESHAPE OBJECTS TO FIT DATA
% 		if (numObjIn < numInputElements)
% 			numObjOut = numInputElements;
% 			% 							constructorFcn = ignition.util.getClassConstructor(obj);
% 			% 							obj(numObjOut) = constructorFcn();
% 			% 							obj(numObjOut) = feval(obj.BlankConstructor);
% 			
% 		else
% 			numObjOut = min(numObjIn, numInputElements);
% 		end
% 		% 						obj = reshape(obj(1:numObjOut), size(firstArg) );
% 		
% 		
% 		
% 	else
% 		numObjOut = numObjIn;
% 		
% 	end
% 	
% 	for kInput = 1:numInputs
% 		inputName = orderedInputNames{kInput};
% 		inputArg = varargin{kInput};
% 		
% 		if iscell(inputArg)
% 			% CELL-PARTITIONED INPUT
% 			[obj(1:numObjOut).(inputName)] = inputArg{:};
% 			% 							obj = reshape(obj(1:numObjOut), size(inputArg));
% 			
% 		else
% 			% NON-CELL INPUT
% 			for kObj = 1:numObjOut
% 				switch numel(inputArg)
% 					case 1
% 						% SCALAR INPUT (REPLICATE)
% 						obj(kObj).(inputName) = inputArg;
% 						
% 					case numObjOut
% 						% VECTOR OF NUMERIC OR STRUCTURED
% 						obj(kObj).(inputName) = inputArg(kObj);
% 						
% 					otherwise
% 						% MULTIDIM ARRAY -> ASSUME DATA
% 						obj(kObj).(inputName) = inputArg(:,:,:,kObj);
% 						% todo: generic slice through count dimension
% 						
% 				end
% 			end
% 		end
% 	end
% 	
% 	
% 	% SET NEW DATA FLAG -> TRUE
% 	[obj(1:numObjOut).NewDataFlag] = deal(true);
% 	%newDataFlagArray = num2cell(true(1,numObjOut));
% 	%[obj(1:numObjOut).NewDataFlag] = newDataFlagArray{:};
% 	
% 	% new (moved)
% 	obj = reshape(obj(1:numObjOut), size(firstArg) );
% 	
% end
% 
% 
% end


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
