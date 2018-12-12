classdef TypeDescription < handle
    %TypeDescription   Define the TypeDescription class.
    
    %   Copyright 2012 The MathWorks, Inc.
    
    properties (SetAccess = protected)
        
        Type;
        
        % Enable Constraint
        Constraint;
        
        % Priority order of this extension type
        Order = 0;
        
        % Label used for dialogs.
        Label;
    end
    
    methods
        
        function this = TypeDescription(type, constraint, order, label)
            %TypeDescription   Construct the TypeDescription class.
            mlock;
            this.Type = type;
            
            if nargin < 2
                
                % If we are not passed an enable constraint, create the default
                % EnableAny object.
                constraint = extmgr.EnableAny(type);
            elseif ischar(constraint) || isa(constraint, 'function_handle')
                
                % If we are passed a string for the constraint, assume it is the
                % constructor and create it.
                constraint = feval(constraint, type);
            end
            
            this.Constraint = constraint;
            if nargin > 2
                this.Order = order;
                if nargin > 3
                    this.Label = label;
                end
            end
        end
        
        function label = get.Label(this)
            label = this.Label;
            if isempty(label)
                label = this.Type;
            end
        end
    end
    
    methods (Hidden)
        function nodeInfo = getNodeInfo(this)
            %GETNODEINFO Get the nodeInfo.
            
            nodeInfo.Title = getString(message('Spcuilib:scopes:TextRegistrationTypeNodeInfo'));
            nodeInfo.Widgets = { ...
                'Type'        this.Type; ...
                'Constraints' class(this.Constraint)};
        end
        
        function node = getTreeNode(this)
            %GETTREENODE Get the treeNode.
            
            node = this.Type;
        end
    end
end

% These subfunctions allow callers to specify shorter constraint strings,
% e.g. 'EnableAll' or 'EnableOne' instead of 'extmgr.EnableAll' or
% 'extmgr.EnableOne'.  We don't want to just assuming that strings without
% '.' are class names in the extmgr package because people may want to
% write their own EnableConstraint objects without needing a package.

% -------------------------------------------------------------------------
function h = EnableAll(varargin) %#ok

h = extmgr.EnableAll(varargin{:});
end

% -------------------------------------------------------------------------
function h = EnableAny(varargin) %#ok

h = extmgr.EnableAny(varargin{:});
end

% -------------------------------------------------------------------------
function h = EnableOne(varargin) %#ok

h = extmgr.EnableOne(varargin{:});
end

% -------------------------------------------------------------------------
function h = EnableAtLeastOne(varargin) %#ok

h = extmgr.EnableAtLeastOne(varargin{:});
end

% -------------------------------------------------------------------------
function h = EnableZeroOrOne(varargin) %#ok

h = extmgr.EnableZeroOrOne(varargin{:});
end

% [EOF]
