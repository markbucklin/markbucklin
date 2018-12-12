classdef vectorMCOS < matlab.mixin.SetGet & matlab.mixin.Copyable
  %sigutils.vector class
  %    sigutils.vector properties:
  %
  %    sigutils.vector methods:
  %       addelement - Add the element to the vector
  %       addelementat - Add the element at the vector index
  %       array - Convert the vector to an array
  %       cell - Convert the vector to a cell array
  %       chkindx - Check the index to make sure it is valid.
  %       clear - Removes all of the elements from the vector
  %       disp - Displays the object.
  %       elementat - Returns the component at the specified index
  %       exportdata - Extract data to export.
  %       exportinfo - Export information.
  %       isempty - Returns true if the vector is empty
  %       isfull - Returns true if the stack is full.
  %       length - Returns the length of the vector
  %       removeelementat - Removes the element at the vector index
  %       replaceelementat - Replace the element at the indx
  %       sendchange - Send the vector changed event
  
  
  properties (Access=protected, AbortSet, SetObservable, GetObservable)
    %DATA Property is of type 'MATLAB array'
    Data = {};
    %LIMIT Property is of type 'int32'
    Limit
  end
  
  
  events
    VectorChanged
  end  % events
  
  methods  % constructor block
    function h = vectorMCOS(limit, varargin)
      %VECTOR Construct a vector
      
      %   Author(s): J. Schickler
      
      % h = sigutils.vector;
      
      if nargin > 0,
        set(h, 'Limit', limit);
      end
      
      for i = 1:length(varargin)
        h.addelement(varargin{i});
      end
      
      
    end  % vector
    
  end  % constructor block
  
  methods
    function set.Limit(obj,value)
      % DataType = 'int32'
      validateattributes(value,{'int32'}, {'scalar'},'','Limit')
      obj.Limit = value;
    end
    
  end   % set and get functions
  
  methods  %% public methods
    
    function addelement(this, input)
      %ADDELEMENT Add the element to the vector
      %   H.ADDELEMENT(INPUT) Add INPUT to the end of the vector
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      narginchk(2,2);
      
      data = this.Data;
      
      % Add the input to the end of the vector
      this.Data = {data{:}, input};
      
      % Send the NewElement event with the index of the new element (the end).
      sendchange(this, 'NewElement', length(this));
      
    end
    
    
    function addelementat(this, input, indx)
      %ADDELEMENTAT Add the element at the vector index
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      narginchk(3,3);
      chkindx(this, indx, 'nolength');
      
      % Add the element in the requested index.  Special case the first and last
      % indices.
      switch indx
        case 1
          this.Data = {input, this.Data{:}};
        case length(this)+1
          this.Data = {this.Data{:}, input};
        otherwise
          if indx > length(this) + 1,
            
            % Allow elements beyond the length and fill with []'s
            filler    = repmat({[]}, 1, indx-length(this)-1);
            data      = this.Data;
            this.Data = {data{:}, filler{:}, input};
          else
            this.Data = {this.Data{1:indx-1}, input, this.Data{indx:end}};
          end
      end
      
      sendchange(this, 'NewElement', indx);
      
    end
    
    
    function a = array(this)
      %ARRAY Convert the vector to an array
      %   H.ARRAY Converts the vector to an array, if possible.  If we have mixed
      %   numbers and characters, the numbers will be converted to characters.
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      try,
        a = [this.Data{:}];
      catch
        error(message('signal:sigutils:vector:array:ValuesNotSameType'));
      end
      
      
    end
    
    function c = cell(this)
      %CELL Convert the vector to a cell array
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      c = get(this, 'Data');
      
    end
    
    function msg = chkindx(this, indx, nolength)
      %CHKINDX Check the index to make sure it is valid.
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      % This should be private
      
      narginchk(2,3);
      
      msg = '';
      
      % Make sure that the index is real and positive.
      if ~isnumeric(indx) || indx < 1 || ~isreal(indx),
        msg = getString(message('signal:sigtools:sigutils:assignment_VectorIndicesMustEitherBeRealPositiveIntegers'));
        if nargout == 0
          error(message('signal:sigutils:vector:chkindx:IndexNotRealPositiveInt'))
        end
      end
      
      % Make sure that the index is inside the vector.
      if indx > length(this) && nargin == 2,
        msg = getString(message('signal:sigtools:sigutils:assignment_IndexExceedsVectorLength'));
        if nargout == 0
          error(message('signal:sigutils:vector:chkindx:IndexTooLarge'))
        end
      end
      
    end
    
    function clear(h)
      %CLEAR Removes all of the elements from the vector
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      % Clear out the vector.
      h.Data = {};
      
      sendchange(h, 'VectorCleared', []);
      
    end
    
    function disp(this)
      %DISP Displays the object.
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      % Display the cell array.
      disp(cell(this));
      
    end
    
    function data = elementat(this, indx)
      %ELEMENTAT Returns the component at the specified index
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      narginchk(2,2);
      chkindx(this, indx);
      
      % Return the data at the requested index.
      data = this.Data{indx};
      
    end
    
    function data2xp = exportdata(h)
      %EXPORTDATA Extract data to export.
      
      %   Author(s): P. Costa
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      data2xp = {};
      
      [r, c] = size(h);
      for rndx = 1:r
        for cndx = 1:c
          for n = 1:length(h(rndx, cndx)),
            newdata  = elementat(h(rndx, cndx),n);
            data2xp =  {data2xp{:},newdata};
          end
        end
      end
      
    end
    
    function s = exportinfo(this)
      %EXPORTINFO Export information.
      
      % This should be a private method.
      
      %   Author(s): P. Costa
      %   Copyright 1988-2004 The MathWorks, Inc.
      
      data = elementat(this,1);
      if isa(data,'sigutils.vector') || isa(data,'sigutils.vectorMCOS'),
        % Default Variable Labels and Names
        s = defaultvarsinfo(length(this));
      elseif isa(data,'handle')
        % Call the object specific information
        s = exportinfo(data);
      else
        s = defaultvarsinfo(length(this));
      end
      
    end
    
    function boolflag = isempty(this)
      %ISEMPTY Returns true if the vector is empty
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      boolflag = isempty(this.Data);
      
    end
    
    function boolflag = isfull(this)
      %ISFULL Returns true if the stack is full.
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      % Return true if the amount of data is = or > the stack limit
      % The > should not be necessary, but it is included as a precaution
      % against careless subclass method adding above the limit.
      boolflag = length(this) >= this.Limit;
      
    end
    
    function l = length(this)
      %LENGTH Returns the length of the vector
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      l = length(this.Data);
      
    end
    
    function removeelementat(this, indx)
      %REMOVEELEMENTAT Removes the element at the vector index
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      narginchk(2,2);
      chkindx(this, indx);
      
      % Cache the old data at the index to delete.
      olddata = this.Data{indx};
      this.Data(indx) = [];
      
      sendchange(this, 'ElementRemoved', olddata);
      
    end
    
    
    function replaceelementat(this, newvalue, indx)
      %REPLACEELEMENTAT Replace the element at the indx
      %   REPLACEELEMENTAT(H, DATA, INDEX)
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      narginchk(3,3);
      chkindx(this, indx);
      
      % Replace the element at the specified index.
      this.Data{indx} = newvalue;
      
      sendchange(this, 'ElementReplaced', indx);
      
    end
    
    function sendchange(this, message, indx)
      %SENDCHANGE Send the vector changed event
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2003 The MathWorks, Inc.
      
      % This should be private
      
      s.msg  = message;
      s.indx = indx;
      
      notify(this, 'VectorChanged', sigdatatypes.sigeventdataMCOS(this, 'VectorChanged', s));
      
    end
    
  end  %% public methods
  
end  % classdef


% -------------------------------------------------------------------------
function s = defaultvarsinfo(le)
% Default Variable Labels and Names

s.variablelabel = repmat({'Variable'}, le, 1);
s.variablename  = repmat({'var'}, le, 1);

end

