classdef Video < hgsetget
  
  
  properties % IDENTICAL TO 'VID' STRUCTURE FIELDS
	 cdata
	 frame
	 subframe
	 info
	 colormap
	 timestamp
	 backgroundMean
	 issmoothed
  end
  properties (Dependent)
	 
  end
  properties
	 FrameSize
  end
  properties
	 Frames
  end
  
  
  
  events
  end
  
  
  
  
  methods % CONSTRUCTOR & SETUP
	 function obj = Video(varargin)
		if nargin > 1	% Input is property-value pairs
		  for k = 1:2:length(varargin)
			 obj.(varargin{k}) = varargin{k+1};
		  end
		elseif nargin == 1 % Input is a multi-ROI BWFRAME structure with fields 'RegionProps' and 'bwMask'
		  vidInput = varargin{1};
		  if isa(vidInput, 'Video')
			 obj = vidInput;
		  elseif isa(vidInput, 'struct')
			 % PROCESS INPUT
			 vidFields = fields(vid);
			 for kField = 1:numel(vidFields)
				fn = vidFields{kField};
				obj.(fn) = vidInput.(fn);
			 end
		  end
		end
	 end
  end
  methods % GET DEPENDENT PROPERTIES
	 
	 
  end
  
  
  
end















