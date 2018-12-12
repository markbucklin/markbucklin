classdef (CaseInsensitiveProperties=true, TruncatedProperties=true) transactionMCOS < handle & hgsetget
  %sigdatatypes.transaction class
  %   sigdatatypes.transaction extends handle
  %
  %    sigdatatypes.transaction properties:
  %       Name - Property is of type 'string'
  %       Parent - Property is of type 'handle'
  %       OperationStore - Property is of type 'on/off'
  %       InverseOperationStore - Property is of type 'on/off'
  %       Compression - Property is of type 'on/off'
  %       Operations - Property is of type 'UDInterfaceArray' (read only)
  %       Object - Property is of type 'handle'
  %       Property - Property is of type 'MATLAB array'
  %       OldValue - Property is of type 'MATLAB array'
  %       NewValue - Property is of type 'MATLAB array'
  %
  %    sigdatatypes.transaction methods:
  %       cancel - Undo the current operation
  %       undo -   Undo the transaction.
  
  
  properties (AbortSet, SetObservable, GetObservable)
    %OBJECT Property is of type 'handle'
    Object = [];
    %PROPERTY Property is of type 'MATLAB array'
    Property = {};
    %OLDVALUE Property is of type 'MATLAB array'
    OldValue = {};
    %NEWVALUE Property is of type 'MATLAB array'
    NewValue = {};
  end
  
  properties (Access=protected, Transient, AbortSet, SetObservable, GetObservable)
    %PROPERTYLISTENERS Property is of type 'handle vector'
    PropertyListeners = [];
  end
  
  
  methods  % constructor block
    function h = transactionMCOS(hObj, varargin)
      %TRANSACTION Set up a transaction that listens to a single object

      narginchk(1,inf);
      
      mobj = metaclass(hObj);
      allProps = mobj.PropertyList;
      
      for i = 1:length(varargin)
        allProps = findobj(allProps, '-not', 'Name', varargin{i});
      end
      
      allProps = findobj(allProps, 'SetAccess', 'public');
      
      % Set up the pre and post set listener to capture the transaction
      for i = 1:length(allProps)
        plistener(2*i-1) = event.proplistener(hObj, hObj.findprop(allProps(i).Name), 'PreSet', @(s,e)captureSetOp(h,e)); %#ok<AGROW>
        plistener(2*i) = event.proplistener(hObj, hObj.findprop(allProps(i).Name), 'PostSet', @(s,e)captureSetOp2(h,e)); %#ok<AGROW>
      end
           
      h.PropertyListeners = plistener;
      h.Object = hObj;
    end  % transaction
    
    
    % ---------------------------------------------------------------
    
  end  % constructor block
  
  methods
    function set.PropertyListeners(obj,value)
      % DataType = 'handle vector'
      validateattributes(value,{'handle'}, {'vector'},'','PropertyListeners')
      obj.PropertyListeners = value;
    end
    
    function set.Object(obj,value)
      % DataType = 'handle'
      validateattributes(value,{'handle'}, {'scalar'},'','Object');
      obj.Object = value;
    end
    
  end   % set and get functions
  
  methods  %% public methods
    function cancel(h)
      %CANCEL Undo the current operation

      % Loop to allow for the cancel of multiple transactions.
      for i = 1:length(h)
        
        for j = 1:length(h(i))
          h(i).PropertyListeners(j).Enabled = 0;
        end
        
        % Undo the operation
        h(i).undo;
      end
      
    end
    
    function undo(h)
      %UNDO   Undo the transaction.

      if ~isempty(h.Property),
        try
          set(h.Object, fliplr(h.Property), fliplr(h.OldValue));
        catch ME
          if ~strcmp(ME.identifier, 'MATLAB:class:SetDenied')
            throwAsCaller(ME);
          end
        end
      end
      
    end
    
  end  %% public methods
  
  
  methods (Hidden) %% possibly private or hidden
    function redo(h)

      set(h.Object, h.Property, h.NewValue);
      
    end
  end  %% possibly private or hidden
  
end  % classdef

function captureSetOp(hT, hEvent)
% Capture the set operation through a transaction
if hT.isvalid
  hT.Property{end+1} = hEvent.Source.Name;
  hT.OldValue{end+1} = get(hT.Object, hT.Property{end});
end

end  % captureSetOp

function captureSetOp2(hT, hEvent) %#ok<INUSD>
% Capture the set operation through a transaction

if hT.isvalid
  hT.NewValue{end+1} = get(hT.Object, hT.Property{end});
end

end  % captureSetOp

