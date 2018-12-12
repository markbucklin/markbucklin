classdef dyproputil < dynamicprops & matlab.mixin.SetGet & matlab.mixin.Copyable
  % DYPROPUTIL is a interface class to use the methods in dynamicprops class.
  
  properties
  end
  
  methods
    
    function varargout = addprops(hParent, hChild, varargin)
      %ADDPROPS Method to dynamically add properties to the parent
      %object.
      %   ADDPROPS(H, HC) Method to dynamically add properties from HC
      %   to H.  HC is assumed to have the method PROPSTOADD, which should
      %   return a cell array of strings.
      %
      %   ADDPROPS(H, HC, PROP1, PROP2, etc.) Adds PROP1, PROP2, etc.
      %   from HC to H.  These should be specified with strings.
      %
      %   ADDPROPS(H, HC, '-not', PROP1, '-not', PROP2) Adds all
      %   properties returned from HC's PROPSTOADD method except PROP1 and
      %   PROP2.
      %
      %   ADDPROPS(H, HC, {}) If an empty cell is passed as the third
      %   input, no properties will be added to H.
      
      % If we have an extra non '-not' input, it must be the properties to
      % add.
      if nargin < 3
        props = propstoadd(hChild);
      else
        if strcmpi(varargin{1}, '-not')
          % Eliminate all properties that are referenced to be a '-not'
          indx = 1;
          props = propstoadd(hChild);
          
          while indx < length(varargin)
            if strcmpi(varargin{indx}, '-not')
              idx = strcmpi(varargin{indx+1}, props);
              varargin([indx indx+1]) = [];
              props(find(idx)) = [];
            else
              indx = indx + 1;
            end
          end
        elseif isempty(varargin{1}),
          props = {};
        else
          if iscell(varargin{1}),
            props = varargin{1};
          else
            props = varargin;
          end
        end
      end
      
      % Make sure that there are no duplicate properties.
      [props i] = unique(props);
      [i newi]  = sort(i);
      props = props(newi);
      
      if isempty(props),
        if nargout == 1, varargout = {[]}; end
        return;
      end
      
      newp = {};
      for indx = 1:length(props),
        
        hindxc = findprop(hChild, props{indx});
        
        h = hParent.addprop(hindxc.Name);
        h.NonCopyable = false;
        newp{end+1} = h;
        
        h.SetMethod = @(hParent,value)set_prop(hParent,value,hChild,hindxc.Name);
        h.GetMethod = @(hParent,value)get_prop(hParent,hChild,hindxc.Name);
        
        h.SetObservable = true;
        h.GetObservable = true;
        
      end
      
      if nargout, varargout = {[newp{:}]}; end
      
    end
    
    
    
    function varargout = adddynprop(h, name, datatype, setfcn, getfcn)
      %ADDDYNPROP   Add a dynamic property
      %   ADDDYNPROP(H, NAME, TYPE)  Add the dynamic property with NAME and
      %   datatype TYPE to the object H.
      %
      %   ADDDYNPROP(H, NAME, TYPE, SETFCN, GETFCN)  Add the dynamic property and
      %   setup PostSet and PreGet listeners with the functions SETFCN and GETFCN.
      
      %   Author(s): J. Schickler
      %   Copyright 1988-2004 The MathWorks, Inc.
      
      narginchk(3,5);
      
      if nargin < 5
        getfcn = [];
        if nargin < 4
          setfcn = [];
        end
      end
      
      % Add the dynamic property.
      hp = h.addprop(name);
      
      hp.SetMethod = setfcn;
     	hp.GetMethod = getfcn;
      
      %       hp.SetMethod = str2func(['@(s,e)',func2str(setfcn),'(h,e)']);
      %      	hp.GetMethod = str2func(['@(s,e)',func2str(getfcn),'(h,e)']);
      
      if nargout
        varargout = {hp};
      end
      
    end
    
    function enabdynprop(h,propname,enabstate)
      %ENABDYNPROP Enable/disable dynamic properties.
      %   ENABDYNPROP(H, PROP, ENAB) Set the enable state of the dynamic property
      %   PROP in the object H to ENAB.
      %
      %   We enable/disable the set/get accessflags of dynamic properties
      %   in order to enable/disable the properties.
      
      %   Author(s): R. Losada
      %   Copyright 1988-2003 The MathWorks, Inc.
      if ~iscell(propname)
        propname = {propname};
      end
      
      if strcmpi(enabstate,'on')
        enabstate = 'public';
      else
        enabstate = 'private';
      end
      
      for i=1:length(propname)
        p = findprop(h,propname{i});
        if ~strcmpi(propname{i},p.Name),
          error(message('signal:enabdynprop:NotSupported'));
        end
        p.GetAccess = enabstate;
        p.SetAccess = enabstate;
      end
      
    end
    
    
    
    function rmprops(hParent, varargin)
      %RMPROPS Remove dynamic props from an object
      %   RMPROPS(H, PROPNAME1, PROPNAME2, etc) Remove the dynamic
      %   property PROPNAME1, PROPNAME2, etc from the object H.
      %
      %   RMPROPS(H, HCHILD) Remove the dynamic properties that are
      %   defined by the PROPSTOADD method.
      
      % If the first input is an object, use its PROPSTOADD method to
      % determine which properties should be removed.
      if isobject(varargin{1}),
        props = propstoadd(varargin{1});
      else
        
        % If the first input is not an object assume they are strings.
        props = varargin;
        if length(props) == 1 && isempty(props{1}),
          props = {};
        end
      end
      
      if isempty(props), return; end
      
      % Loop over all the properties
      for indx = 1:length(props)
        
        % Find the property to remove.
        p = hParent.findprop(props{indx});
        
        if ~isempty(p)
          % Remove the property.
          delete(p);
        end
        
      end
      
    end
    
  end
  
end


% -----------------------------------------------------------------
function value = get_prop(hParent, hChild, prop)

% Get the value from the child.
value = get(hChild, prop);

end

% -----------------------------------------------------------------
function value = set_prop(hParent, value, hChild, prop)

% Set the value in the child.
set(hChild, prop, value);
end

