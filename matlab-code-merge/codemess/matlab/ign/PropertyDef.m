classdef PropertyDef < handle
    %PropertyDef Property definition object
    %
    % PropertyDef(Name,H1Line,Attr,InitVal,Desc) creates a property
    % definition object for a MATLAB class filed.  PropertyDef objects are
    % intended for use by SystemObjectGenerator to define property
    % definitions in System object files.
    %
    % See also: PropertyDB, MatlabClassGenerator, SystemObjectGenerator.
    
    % ADVANCED USE:
    %
    % - Help-only properties
    %
    % A help-only property can be created to add annotations within
    % a property block.
    %
    % For this use, set the name to an empty string.  Attributes must match
    % the attributes of the property block for which the comment is
    % intended to be rendered.  Ordering of help-only properties follows
    % the usual property ordering process.
    %
    % Example:
    %    PropertyDef('','','Access=private','', ...
    %         'Comment in property block')
    % Alternative:
    %    PropertyComment('Comment in a property block','Access=private')
    
    % Copyright 2014 The MathWorks, Inc.
    
    properties
        Name = 'Prop'
        H1Line = ''      % One-line summary of property use
        Attributes = {}  % String or cell-string of attributes, such as Access=private or Logical
        InitValue = ''   % MATLAB expression for initializing property value
        Help = '' % Detailed description of property use
    end
    
    %{
    properties
        % Pre-defined attributes
        Access = 'public' % Public, Protected, Private
        Nontunable = false
        Sealed = false
        Hidden = false
        Logical = false
        PositiveInteger = false
    end
    %}
    
    methods
        function obj = PropertyDef(name,h1line,attr,initVal,desc)
            % Create a new property definition object.
            % PropertyDef(Name,H1Line,Attr,InitVal,desc) defines a new
            % property with Name and single-line summary H1Line as strings.
            % Attributes of the property, such as 'Access=private' or
            % 'Logical', may be passed as either a string or a cell-string
            % using Attr.  An initializer for the property is InitVal.
            
            if nargin>0
                obj.Name = name;
            end
            if nargin>1
                obj.H1Line = h1line;
            end
            if nargin>2
                obj.Attributes = attr;
            end
            if nargin>3
                obj.InitValue = initVal;
            end
            if nargin>4
                obj.Help = desc;
            end
        end
        
        function set.Name(obj,val)
            if ~ischar(val)
                error(message('siglib:MATLABGenerator:PropMustBeStr'));
            end
            % Leave property name exactly as the user wrote it.
            % Processing of the name is done at the point of use.
            obj.Name = val;
        end
        
        function set.H1Line(obj,val)
            if ~ischar(val)
                error(message('siglib:MATLABGenerator:H1String'));
            end
            obj.H1Line = val;
        end
        
        function set.Help(obj,val)
            if ischar(val)
                val = {val};
            end
            if ~iscell(val)
                error(message('siglib:MATLABGenerator:HelpStr'));
            end
            obj.Help = val;
        end
        
        function set.Attributes(obj,val)
            if ischar(val)
                val = {val};
            end
            if ~iscell(val)
                error(message('siglib:MATLABGenerator:AttribStr'));
            end
            obj.Attributes = val;
        end
        
        function set.InitValue(obj,val)
            if ~ischar(val)
                error(message('siglib:MATLABGenerator:InitValueStr'));
            end
            obj.InitValue = val;
        end
        
        function y = isComment(obj)
            % A Help-only property may be created to add annotations
            % within a property block.
            %
            % For this use, the name is an empty string.  Attributes
            % must match the attributes of the property block for which the
            % comment is intended to be rendered.
            
            y = isempty(strtrim(obj.Name));
        end
        
        function str = getPropertyDeclStr(obj)
            % Return property declaration, including H1 line, help,
            % name and initial value.
            %
            % Example:
            %  %PropName H1Line
            %  %    help line 1
            %  %    help line 2
            %  Name = InitValue
            %
            % Example: if no help is defined
            %  Name = InitValue % H1Line
            %
            %  A final carriage-return is included.
            %
            % Properties with an empty string as the name are interpreted
            % as comments and only the help text is rendered in the
            % property declaration text.
            
            if isComment(obj)
                str = renderComment(obj);
            else
                str = renderPropertyDecl(obj);
            end
        end
        
        function str = getAttributeStr(obj)
            % Return comma-separated list of attribute strings.
            str = strjoin(obj.Attributes, ', ');
        end
    end
    
    methods (Access=private)
        function str = renderComment(obj)
            % Return string representing a comment in a property block.
            % Only the help is returned.
            %
            % Comments only have a comment character at the start of
            % non-blank lines, so that blank lines can be embedded
            % within property blocks as desired.
            %
            % Example 1: help={'','comment',''}
            %       1|
            %       2|% comment
            %       3|
            % Example 2: help={'',' ','comment',' '}
            %       1|
            %       2|% 
            %       3|% comment
            %       4|% 
            %
            %   Note that a SPACE was used in Example 2 to force leading
            %   comment characters to render on lines 2 and 4.
            
            d = obj.Help; % cell-string
            str = '';
            Nd = numel(d);
            if Nd>0
                for i = 1:Nd
                    d_i = d{i};
                    if isempty(d_i)
                        % Append carriage return
                        str = sprintf('%s\n',str);
                    else
                        % Append comment with leading comment char
                        str = sprintf('%s%% %s\n',str,d_i);
                    end
                end
            end
        end
        
        function str = renderHelp(obj)
            % Return string for the property help.
            %
            % This transforms a cell-string into a string with carriage
            % return characters after each line.
            %
            % Help has a comment character at the start of every
            % line, even for blank help lines.
            
            d = obj.Help; % cell-string
            str = '';
            Nd = numel(d);
            if Nd>0
                for i = 1:Nd
                    if i==1
                        str = sprintf('%%   %s\n',d{i});
                    else
                        str = sprintf('%s%%   %s\n',str,d{i});
                    end
                end
            end
        end
        
        function newName = renderName(obj)
            % Transform property name as needed to meet 
            
            origName = obj.Name;
            newName = genvarname(origName);
            if ~strcmpi(origName,newName)
                warning('PropertyDef:PropertyNameModified', ...
                    'Name "%s" modified to be a valid property.',origName);
            end
        end
    end
    
    methods(Access=protected)
        function str = renderPropertyDecl(obj)
            % Return string representing the declaration of a property,
            % including name, H1Line, help, initial value, etc.
            %
            % The property name is not added as a comment if both the
            % h1line and the help are empty.
            
            pName = renderName(obj);
            
            % Create preceding comment lines, ending with a CR.
            %
            % No space is introduced between the initial comment character
            % and the name of a property.
            %
            h1line = obj.H1Line;
            d = renderHelp(obj);
            
            str = ''; % preceding comment
            inlineStr = ''; % end of line comment
            
            if isempty(h1line) && isempty(d)
                % No Help, no H1Line
                % Don't render prop name or anything
                
            elseif ~isempty(h1line) && isempty(d)
                % No Help, just H1Line
                % Put comment inline with property
                inlineStr = h1line;
                
            else
                % Both H1Line and Help
                % Put both on preceding lines.
                str = ['%' pName]; % property name as a comment
                if ~isempty(h1line)
                    str = [str ' ' h1line];
                end
                str = sprintf('%s\n', str); % CR after "name h1line" line
                if ~isempty(d)
                    str = [str d];
                end
            end
            
            % Define property var on new line, followed by initializer:
            %
            str = [str pName];
            if ~isempty(obj.InitValue)
                str = sprintf('%s = %s',str,obj.InitValue);
            end
            
            % Inline comment, if present
            if ~isempty(inlineStr)
                str = [str ' % ' inlineStr];
            end
            
            % Final blank line:
            str = sprintf('%s\n', str);
        end
    end
end
