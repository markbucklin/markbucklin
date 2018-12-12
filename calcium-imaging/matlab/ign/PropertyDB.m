classdef PropertyDB < handle
    % Database holding multiple PropertyDef property definition objects.
    % Used by SystemObjectGenerator to define and emit property definitions
    % in System object files.
            
    % Copyright 2014 The MathWorks, Inc.
    
    properties
        AddLineBetweenProperties = true
        
        % Setting to false minimizes the number of unique property blocks,
        % based on common property attribute lists.  Order of properties is
        % preserved within each common property block.
        %
        % Set to true to respect the order of all properties in the
        % database.
        KeepPropertyOrder = true
    end
    
    properties (SetAccess=protected)
        PropertyList = sigutils.internal.emission.PropertyDef.empty
    end
    
    methods
        function obj = PropertyDB(prop)
            if nargin>0
                add(obj,prop);
            end
        end
        
        function set.KeepPropertyOrder(obj,val)
            %Only KeepPropertyOrder == true is implemented so far.
            if ~(islogical(val) && val)
                error(message('siglib:MATLABGenerator:KeepMethodOrder'));
            end
            obj.KeepPropertyOrder = val;
        end
        
        function set.AddLineBetweenProperties(obj,val)
            if ~islogical(val)
                error(message('siglib:MATLABGenerator:AddLineBetProps'));
            end
            obj.AddLineBetweenProperties = val;
        end
        
        function add(obj,prop)
            % Add a property definition object to the database.
            if ~isa(prop,'sigutils.internal.emission.PropertyDef')
                error(message('siglib:MATLABGenerator:MustBePropDef'));
            end
            
            obj.PropertyList(end+1) = prop;
        end
        
        function s = getPropertyBuffer(obj)
            % Return text buffer defining all properties within property
            % code block.
            
            s = StringWriter;
            
            % Cache last set of attributes to know when a new property
            % block must be created.
            a_last = {};
            anyBlockOpen = false;
            
            % Loop through all properties
            props = obj.PropertyList;
            N = numel(props);
            for i = 1:N
                p_this = props(i);
                a_this = p_this.Attributes;
                
                % Use setdiff so the attribute string comparison is
                % order-independent:
                if i==1 || ~isempty(setxor(a_this,a_last))
                    if anyBlockOpen
                        s.addcr('end'); % close previous property block
                        s.addcr; % and add a linefeed
                    else
                        anyBlockOpen = true; % it will be now!
                    end
                    a_last = a_this; % cache for change detection
                    s.add(getSectionHeader(obj)); % open new block
                    attr_i = getAttributeStr(p_this);
                    if ~isempty(attr_i)
                        s.add(' (%s)',attr_i);
                    end
                    s.addcr; % CR at end of property
                end
                
                % Render next property
                % Use add, not addcr, as declaration has trailing LF
                s.add(getPropertyDeclStr(p_this));
                    
                if obj.AddLineBetweenProperties && i<N
                    s.addcr; % extra CR between properties
                end
            end
            if N>0
                s.addcr('end'); % close last property block
            end
        end
    end
    
    methods(Access=protected)
        function h = getSectionHeader(~)
            h = 'properties';
        end
    end
end
