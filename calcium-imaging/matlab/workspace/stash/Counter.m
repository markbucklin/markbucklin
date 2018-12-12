classdef Counter < handle
% COUNTER A simple counter with a next() method that advances the counter
%   and returns the incremented value.

%   Copyright 2012 The MathWorks, Inc.
 
  properties
    Value
    RowStretch
    LayoutGrid
  end
  
  methods
    function this = Counter(initVal)
      this.Value = initVal;
    end

    function nextValue = next(this, varargin)
      nextValue = this.Value + 1;
      this.Value = nextValue;
      if nargin > 1
        dims = [varargin{:}];
        if isscalar(dims)
          dims = [1 dims];
        end
        nextValue = repmat(nextValue, dims);
      end
    end
    
    function rowStretch = get.RowStretch(this)
      rowStretch = [zeros(1, this.Value) 1];
    end
    
    function layoutGrid = get.LayoutGrid(this)
      layoutGrid = [this.Value+1 2];
    end
  end
end

% [EOF]
