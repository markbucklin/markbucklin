classdef FrameBuffer
   
   
   
   properties
	  nFrames = 128
   end
   properties ( SetAccess = protected)
	  frameSize
	  dataType
   end
   properties (Transient)
	  isEmpty = true
	  isFull = false
	  isDepleted = false
   end
   properties % (SetAccess = protected)
	  data
	  info = struct.empty(1,0)
	  frameIdx
   end
   properties
	  nextLocalWriteIdx = 1
	  nextLocalReadIdx = 0
   end
   
   
   
   methods
	  function obj = FrameBuffer(varargin)
warning('FrameBuffer.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
		 if nargin >1
			propSpec = varargin(:);
			if ischar(propSpec{1})
			   fillPropsFromPropValPair(propSpec)
			end
		 elseif nargin == 1
			structSpec = varargin{1};
			if isstruct(structSpec)
			   fillPropsFromStruct(structSpec)
			end
		 end
		 function fillPropsFromPropValPair(propSpec)
			if ~isempty(propSpec)
			   if numel(propSpec) >=2
				  for k = 1:2:length(propSpec)
					 obj.(propSpec{k}) = propSpec{k+1};
				  end
			   end
			end
		 end
		 function fillPropsFromStruct(structSpec)
			fn = fields(structSpec);
			for kf = 1:numel(fn)
			   try
				  obj.(fn{kf}) = structSpec.(fn{kf});
			   catch me
				  warning('FluoProFunction:parseConstructorInput', me.message)
			   end
			end
		 end
	  end
	  function obj = loadFramesFromSystem(obj,sys)		 
		 [firstData, firstInfo] = step(sys);
		 if isempty(obj.frameSize)
			obj.frameSize = size(firstData);
		 end
		 if isempty(obj.nFrames)
			obj.nFrames = 128;
		 end
		 N = obj.nFrames;
		 if isempty(obj.data)
			obj.data = zeros([obj.frameSize N], 'like', firstData);
		 end
		 if isempty(obj.info)
			obj.info(N,1) = firstInfo;
		 end		 
		 k=obj.nextLocalWriteIdx;
		 thisData = firstData;
		 thisInfo = firstInfo;
		 while ~isDone(sys)
			obj.data(:,:,k) = thisData;
			obj.info(k,1) = thisInfo;
			k=k+1;
			if k <= N
			   [thisData, thisInfo] = step(sys);
			else
			   obj.nextLocalReadIdx = 1;
			   break
			end			
		 end
	  end	 
   end
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
end
