classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible)...
		VideoFrame < ignition.core.type.DataContainerBase
	% VIDEOFRAME - Base class for core stream datatype
	% Info - frame metadata such as that returned by VIDEOINPUT object
	%				Minimal (videoinput-compatible) set of structure fields include:
	%						AbsTime
	%						FrameNumber
	%						RelativeFrame
	%						TriggerIndex
	
	
	
	
	properties (SetAccess = ?ignition.core.Object)
		Timestamp
		Idx
	end
	properties (SetAccess = ?ignition.core.Object)
		NumChannels		
		FrameSize
	end
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = VideoFrame(varargin)
			% >> obj = VideoFrame(frameData)
			% >> obj = VideoFrame(frameData, frameInfo)
			% >> obj = VideoFrame(frameData, frameInfo, frameTime)
			% >> obj = VideoFrame(frameData, frameInfo, frameTime, frameIdx)
			% >> obj = VideoFrame(frameData, frameTime, frameInfo, frameIdx)
			%	(order of inputs doesn't matter if calling for single-frame construction)
			
			% ENSURE TEMPORAL (COUNTING/STACKING) DIMENSION IS SPECIFIED AS 4TH
			obj.CountDimension = 4;
			obj.OrderedInputPropNames = {'Data','Info','Timestamp','Idx'};
			
			if nargin
				argsIn = varargin;
				
				% CHECK IF FIRST INPUT IS A DATA-CONTAINER OBJECT (FOR CONVERSION)
				if isa(argsIn{1}, 'ignition.core.type.VideoFrame')					
					obj = copyProps( obj, argsIn{1});
					argsIn(1) = [];
				end
				
				% MANAGE STANDARD OR ADDITIONAL INPUT ARGUMENTS
				if ~isempty(argsIn)
					% CHECK IF INPUT IS FOR A SINGLE FRAME OR MULTIPLE FRAMES
					numElInEach = cellfun(@numel, argsIn);
					N = min(numElInEach);
					
					if (N>1)
						% CREATE MULTIPLE VIDEO-FRAME OBJECTS FROM MULTI-FRAME INPUT
						obj = parseOrderedInput(obj, argsIn{:});					
					else
						% CREATE SINGLE OBJECT WITH GIVEN SINGLE-FRAME INPUT
						obj = parseUnorderedInput(obj, argsIn{:});
					end
					
					% CALL FRAME SIZE/DATATYPE UPDATE FUNCTIONS
					obj = applyUpdates(obj);
					
				end
			end
		end
	end
	
	% CONVENIENCE METHODS - OVERLOADING METHODS SHARED FUNCTIONS
	methods
		function varargout = getFrameSize(obj)
			% >> [numRows,numCols,numChannels] = getFrameSize(obj)
			
			firstObj = obj(1);
			
			if nargout > 1				
				if ~isempty(firstObj.Data)
					numRows = firstObj.NumRows;
					numCols = firstObj.NumCols;
					numChannels = firstObj.NumChannels;
				else
					numRows = 0;
					numCols = 0;
					numChannels = 0;
				end
				varargout = {numRows,numCols,numChannels};
				
			else
				varargout{1} = firstObj(1).FrameSize;
			end
			
		end
		function numFrames = getNumFrames(obj)
			% >> numFrames = getNumFrames(obj)						
			numFrames = numel(obj);
			
			% todo
			
		end
	end
	
	% INTERNAL UPDATE OF UNDERLYING DATA
	methods (Access = protected, Hidden)
		function obj = applyUpdates(obj)
			
			% CALL PARENT METHOD (BASE DATA-CONTAINER CLASS)
			obj = applyUpdates@ignition.core.type.DataContainerBase(obj);
			
			% CALL OTHER CLASS-SPECIFIC UPDATE FUNCTIONS
			try
				% FASTER??
				numChannels = obj(1).DataSize(3);
				[obj(:).NumChannels] = deal(numChannels);
				dataSize = getDataSize(obj(1));				
				[obj(:).FrameSize] = deal(dataSize(1:3));
				
			catch
				% REDUNDANT, BUT LESS ERROR PRONE?
				obj = updateFrameSize(obj);
			end
			
		end
		function obj = parseUnorderedInput(obj, varargin)
			
			% PARSE INPUT
			if (nargin > 1) && ~isempty(varargin)
				firstArg = varargin{1};
				if isa(firstArg, class(obj))
					% -> IDENTICAL CLASS AS INPUT
					obj = copyProps(obj, firstArg);
					if (numel(varargin)==1)
						return
					else
						argsIn = varargin(2:end);
					end
				else
					argsIn = varargin;
				end
				for kArg = 1:numel(argsIn)
					arg = argsIn{kArg};
					if ~isempty(arg)
						if isstruct(arg)
							% -> FRAMEINFO
							obj.Info = arg(:);
							
						elseif isnumeric(arg)
							argSize = size(arg);
							if all(argSize(1:2) > 1)
								% -> FRAMEDATA
								obj.Data = arg;
								
							elseif isWholeNumber(arg)
								% -> FRAMEIDX
								obj.Idx = arg(:);
								
							else
								% -> FRAMETIME
								obj.Timestamp = arg(:);
								
							end
						end
					end
				end
			end
			
			% GET INFORMATION ABOUT DATA (DIMENSIONS, TYPE, ETC)
			% 			obj = applyUpdates(obj);
			% 			obj = updateFrameSize(obj);
			% 			obj = updateDataType(obj);
			
			function flag = isWholeNumber(vec)
				rvecdiff = abs( sum( vec(:) - round(vec(:)) ));
				flag = rvecdiff < .001;
			end
			
		end
		function obj = updateFrameSize(obj)
			%TODO
			for k=1:numel(obj)
				rawData = obj(k).Data;
				if ~isempty(rawData)
					% GET INFORMATION ABOUT DATA (DIMENSIONS, TYPE, ETC)
					% 					numDims = ndims(rawData);
					if ~ismatrix(rawData) %(ndims(rawData) >= 3)
						sz = size(rawData);
						numRows = sz(1);
						numCols = sz(2);
						numChannels = sz(3);
						% 						[numRows, numCols, numChannels, ~] = size(rawData);
					else
						[numRows, numCols, numChannels] = size(rawData);
						% 						numChannels = 1;
						% 					else
						% 						% issue warning? -> intended multi frame
						% 						[numRows, numCols, dim3] = size(rawData);
						% 						if (dim3 == 3)
						% 							numChannels = 3;
						% 						else
						% 							numChannels = 1;
						% 							numFrames = dim3;
						% 							obj(k).Data = reshape(rawData, numRows, numCols, numChannels, numFrames);
						% 						end
					end
					obj(k).NumRows = numRows;
					obj(k).NumCols = numCols;
					obj(k).NumChannels = numChannels;					
					obj(k).FrameSize = [numRows,numCols,numChannels];
				end
			end
		end
	end
	
	
	% STATIC METHODS FOR CLASS-CONVERSION & INSTANTIATION FROM MULTI-FRAME INPUT
	methods (Static)
		function obj = buildFromFullInput(className, allData, allInfo, allTimestamp, allIdx)
			N = numel(allIdx);
			
			% CHECK WHETHER EACH INPUT IS SPLIT IN A CELL ARRAY FOR MULTI-FRAME INPUT
			isCellData = iscell(allData);
			isCellInfo = iscell(allInfo);
			isCellTimestamp = iscell(allTimestamp);
			isCellIdx = iscell(allIdx);
			
			% 			obj(N,1) = ignition.core.type.VideoFrame();
			obj(N,1) = eval(className);
			
			if isCellData
				[obj.Data] = allData{:};
			end
			if isCellInfo
				[obj.Info] = allInfo{:};
			end
			if isCellTimestamp
				[obj.Timestamp] = allTimestamp{:};
			end
			if isCellIdx
				[obj.Idx] = allIdx{:};
			end
			
			N = numel(allIdx);
			
			% CHECK WHETHER EACH INPUT IS SPLIT IN A CELL ARRAY FOR MULTI-FRAME INPUT
			isCellData = iscell(allData);
			isCellInfo = iscell(allInfo);
			isCellTimestamp = iscell(allTimestamp);
			isCellIdx = iscell(allIdx);
			
			obj(N,1) = ignition.core.type.VideoFrame();
			
			if ~all([isCellData isCellInfo isCellTimestamp isCellIdx])
				for k = 1:N
					% DATA
					if ~isCellData
						obj(k).Data = allData(:,:,:,k);
					end
					
					% INFO-STRUCTURE
					if ~isCellInfo
						obj(k).Info = allInfo(k);
					end
					
					% TIMESTAMP
					if ~isCellTimestamp
						obj(k).Timestamp = allTimestamp(k);
					end
					
					% FRAME-INDEX
					if ~isCellIdx
						obj(k).Idx = allIdx(k);
					end
					
					obj(k).NewDataFlag = true;
					
				end
				
			else
				[obj.NewDataFlag] = deal(true);
			end
			
			% 			obj = applyUpdates(obj);
			
			% 				% PASS TO CONSTRUCTOR (IN VIDEODATA PARENT CLASS)
			% 				% 					frameObj(k) = ignition.core.type.VideoFrame( data, info, timestamp, idx);
			% 				% 							if isHandleObj
			% 				% 								lastObj = frameObj(k);
			% 				% 							end
		end			
		
	end
	
	
	
	
	
end




















% 		function obj = parseOrderedInput(obj, data, info, timestamp, idx)
% 			% TODO, allow variable input size?
% 			obj.Data = data;
% 			obj.Info = info;
% 			obj.Timestamp = timestamp;
% 			obj.Idx = idx;
% 			obj.NewDataFlag = true;
% 			
% 		end









% function obj = splitFromVideoFrame(vidObj)
% 			% TODO: remove? no longer necessary?
% 			try
% 				if ~isa(vidObj, 'ignition.core.type.VideoFrame')
% 					obj = ignition.core.type.VideoFrame();
% 					warning('non video data input');% todo
% 					return
% 				end
% 				% 						N = vidObj.NumFrames;
% 				allTimestamp = vidObj.Timestamp;
% 				allIdx = vidObj.Idx;
% 				allInfo = vidObj.Info;
% 				allData = vidObj.Data;
% 				% 						isCellData = iscell(allData);
% 				% 						isHandleObj = isa(frameObj, 'handle');
% 				
% 				obj = ignition.core.type.VideoFrame.splitFromOrderedInput(allData,allTimestamp,allInfo,allIdx);
% 				% 						N = numel(allIdx);
% 				% 						frameObj(N,1) = ignition.core.type.VideoFrame();
% 				% 						for k = 1:N %N:-1:1
% 				% 							timestamp = allTimestamp(k);
% 				% 							idx = allIdx(k);
% 				% 							info = allInfo(k);
% 				% 							if isCellData
% 				% 								data = allData{k};
% 				% 							else
% 				% 								data = allData(:,:,:,k);
% 				% 							end
% 				%
% 				% 							% PASS TO CONSTRUCTOR (IN VIDEODATA PARENT CLASS)
% 				% 							frameObj(k) = ignition.core.type.VideoFrame( data, timestamp, info, idx );
% 				%
% 				% 							% 							if isHandleObj
% 				% 								% 								lastObj = frameObj(k);
% 				% 								% 							end
% 				% 						end
% 				
% 				
% 				
% 			catch me
% 				handleError(obj, me)
% 			end
% 			
% 		end
