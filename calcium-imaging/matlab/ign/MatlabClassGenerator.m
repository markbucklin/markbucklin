classdef MatlabClassGenerator < handle
    % Generate a MATLAB class.
    
    % Copyright 2014 The MathWorks, Inc.
    
    properties
        % Name of the class and the corresponding file name.
        Name = 'myClass'
        Path = ''
        
        % Class attributes
        ClassAttributes = {}
        
        % Name of super class to inherit from
        SuperClasses = {'handle'}
        
        % One-line summary of function operation when help is obtained. The
        % function name is automatically prepended to this line of text
        % when code is generated.
        H1Line = ''
        
        % Help text for the class.
        % Can be a string, cell-string, or a StringWriter.
        Help = ''
        
        % Cell-string defining the names of related functions.
        SeeAlso = {}
        Copyright = ''
        
        RCSRevisionAndDate = true
        TimeStampInHeader = true
        CoderCompatible = false
        EndOfFileMarker = true
        
        AddLineBetweenProperties = false
        
        AddLineBetweenMethods = true
        
        % Set to true to produce multiple files for the class, within a new
        % folder named specifically for the new class.
        %
        % Files:
        %   - one file containing the constructor and all property
        %     definitions
        %   - one file for each method, together with any nested and local
        %     functions specified for use with that file.
        GenerateSeparateFiles = false
    end
    
    properties (SetAccess=private)
        % Database of property definition objects
        PropertyDB
        
        % Database of property definition objects
        EventDB
        
        % Database of method definition objects
        MethodDB

        % When GenerateSeparateFiles is true contains a cell array of
        % buffers for method code
        MethodBuffers

        % When GenerateSeparateFiles is true contains a cell array of
        % buffers for local functions
        LocalFunctionBuffers
    end
    
    properties (Access=private)
        % Complete program returned as a StringWriter. Use getFileBuffer to
        % assemble complete program.
        FileBuffer
    end
    
    methods
        function obj = MatlabClassGenerator(Name)
            if nargin>0
                obj.Name = Name;
            end
            
            % Initialize
            obj.FileBuffer = StringWriter;
            
            obj.PropertyDB = sigutils.internal.emission.PropertyDB;
            
            obj.EventDB = sigutils.internal.emission.EventDB;
            
            % Configure MethodDB to suppress local function generation
            obj.MethodDB = sigutils.internal.emission.MethodDB;
        end
        
        function set.Name(obj,str)
            if ~ischar(str)
                error(message('siglib:MATLABGenerator:NameMustBeString'));
            end
            str = matlab.lang.makeValidName(str);
            obj.Name = str;
        end
        
        function set.Path(obj,str)
            if ~ischar(str)
                error(message('siglib:MATLABGenerator:PathMustBeString'));
            end
            obj.Path = str;
        end
        
        function set.ClassAttributes(obj,strs)
            if ~iscellstr(strs) && ~ischar(strs)
                error(message('siglib:MATLABGenerator:AttribStr'));
            end
            if ischar(strs)
                strs = {strs};
            end
            obj.ClassAttributes = strs;
        end
        
        function set.SuperClasses(obj,strs)
            if ~iscellstr(strs) && ~ischar(strs)
                error(message('siglib:MATLABGenerator:SuperClassStr'));
            end
            if ischar(strs)
                strs = {strs};
            end
            obj.SuperClasses = strs;
        end
        
        function set.GenerateSeparateFiles(obj,val)
            if ~islogical(val)
                error(message('siglib:MATLABGenerator:GenerateSeparateFilesLogical'));
            end
            obj.GenerateSeparateFiles = val;
        end
        
        function set.H1Line(obj,str)
            if ~ischar(str)
                error(message('siglib:MATLABGenerator:H1String'));
            end
            obj.H1Line = str;
        end
        
        function set.SeeAlso(obj,strs)
            if ~iscellstr(strs) && ~ischar(strs)
                error(message('siglib:MATLABGenerator:SeeAlsoString'));
            end
            if ischar(strs)
                strs = {strs};
            end
            obj.SeeAlso = strs;
        end
        
        function set.Copyright(obj,str)
            if ~ischar(str)
                error(message('siglib:MATLABGenerator:CopyrightString'));
            end
            obj.Copyright = str;
        end
        
        function buff = getFileBuffer(obj)
            % Create complete program and return it as a StringWriter. Also
            % made available as obj.FileBuffer.
            buff = updateProgramBuffer(obj);
        end
        
        function editFile(obj)
            % Generate the MATLAB file and place content in a new, unsaved
            % file in the MATLAB Editor.
            
            edit(getFileBuffer(obj));
        end
        
        function editMethods(obj)
            % Generate the MATLAB file and place content in a new, unsaved
            % file in the MATLAB Editor.
            fn = fieldnames(obj.MethodBuffers);
            for ii=1:numel(fn)
                edit(obj.MethodBuffers.(fn{ii}));
            end
        end
        
        function full_name = writeFile(obj,editFlag)
            % Write the MATLAB file to a folder. Optionally open the file
            % in the MATLAB Editor.
            
            % Name can differ due to our use of genvarnames called on the
            % file name
            if obj.GenerateSeparateFiles
                objFolder = ['@' obj.Name];
            else
                objFolder = '';
            end
            fullpath = fullfile(obj.Path,objFolder);
            full_name = fullfile(fullpath,[obj.Name '.m']);
            
            buff = getFileBuffer(obj);
            write(buff,full_name);
            
            editFiles = nargin>1 && editFlag;
            
            % Write methods and local functions
            if obj.GenerateSeparateFiles
                obj.generateFilesAndEdit(obj.MethodBuffers, fullpath, editFiles);
                localFcnPath = fullfile(fullpath, 'private');
                obj.generateFilesAndEdit(obj.LocalFunctionBuffers, localFcnPath, editFiles);
            end
            
            if editFiles
                edit(full_name);
            end
        end
    end
    
    % Property management
    %
    methods
        function prop = addProperty(obj,varargin)
            % addProperty(obj,name,descr,attribs,initValue) constructs a
            % new property object using property name propName. Optional
            % property description and attributes may be passed using a
            % string or a cell-string.  An initial value initValue may be
            % specified as a single string expression.
            %
            % prop = addProperty(...) returns the PropertyDef object
            % created for the newly added property description.
            %
            % addProperty(obj,prop) adds a preconstructed PropertyDef
            % object directly to the property database.
            
            if nargin==2 && isa(varargin{1},'sigutils.internal.emission.PropertyDef')
                prop = varargin{1};
            else
                prop = sigutils.internal.emission.PropertyDef(varargin{:});
            end
            add(obj.PropertyDB,prop);
        end
        
        function evt = addEvent(obj,varargin)
            % addEvent(obj,name,descr,attribs) constructs a
            % new event object using event name name. Optional
            % event description and attributes may be passed using a
            % string or a cell-string.
            %
            % evt = addEvent(...) returns the EventDef object
            % created for the newly added event description.
            %
            % addEvent(obj,evt) adds a preconstructed EventDef
            % object directly to the event database.
            
            if nargin==2 && isa(varargin{1},'sigutils.internal.emission.EventDef')
                evt = varargin{1};
            else
                evt = sigutils.internal.emission.EventDef(varargin{:});
            end
            add(obj.EventDB,evt);
        end
        
        function prop = addPropertyComment(obj,text,attributes)
            %Create a comment for a property code block.
            %  When used with a MatlabClassGenerator,
            %  addPropertyComment(obj,T) creates a PropertyDef object that
            %  is formatted to define a comment that will be incorporated
            %  into a property code block within a MATLAB class.  Text T
            %  can be a string or a cell-string.
            %
            %  addPropertyComment(obj,T,A) specifies property block
            %  attributes A as a string or a cell-string.
            
            if nargin<3
                attributes = '';
            end
            if nargin<2
                text = ''; % blank line
            end
            prop = sigutils.internal.emission.PropertyDef('','',attributes,'',text);
            add(obj.PropertyDB,prop);
        end
    end
    
    % Method management
    %
    methods
        function addMethod(obj,fcn)
            % addMethod(obj,fcn) adds a MatlabMethodGenerator object fcn to
            % the class.
            add(obj.MethodDB,fcn);
        end
        
        function addMethodComment(obj,text,attributes)
            %Create a comment for a method code block.
            %  When used with a MatlabClassGenerator,
            %  addMethodComment(obj,T) creates a MatlabMethodGenerator
            %  object that is formatted to define a comment that will be
            %  incorporated into a method code block within a MATLAB class.
            %  Text T can be a string or a cell-string.
            %
            %  addMethodComment(obj,T,A) specifies method block attributes
            %  A as a string or a cell-string.
            
            if nargin<3
                attributes = '';
            end
            fcn = sigutils.internal.emission.MatlabMethodGenerator('','','');
            fcn.Attributes = attributes;
            fcn.Help = text;
            add(obj.MethodDB,fcn);
        end
    end
    
    methods (Access=private)
        function buff = updateProgramBuffer(obj)
            % Generate class from user-defined parts.
            
            % Create (single/scalar) file buffer
            buff = StringWriter;
            obj.FileBuffer = buff; % record in property
            obj.MethodDB.GenerateSeparateFiles = obj.GenerateSeparateFiles;
            obj.MethodDB.ClassName = obj.Name;
            
            createClassdef(obj);
            createCommentBlock(obj);
            createProperties(obj);
            createEvents(obj);
            createMethods(obj);
            createClassdefEnd(obj);
            createLocalFunctions(obj);
            createFileEnd(obj);
            
            indentCode(buff);
        end
        
        function createLocalFunctions(obj)
            % Local functions are aggregrated across all methods and
            % rendered at the bottom of the file, after the classdef block
            % has been closed.
            
            if obj.GenerateSeparateFiles
                obj.LocalFunctionBuffers = getSeparateLocalFunctionBuffers(obj.MethodDB);
            else
                add(obj.FileBuffer,getLocalFunctionBuffer(obj.MethodDB));
            end
        end
        
        function createMethods(obj)
            % Add methods code blocks to class text buffer.
            obj.MethodDB.AddLineBetweenMethods = obj.AddLineBetweenMethods;
            b = getMethodBuffer(obj.MethodDB);
            m = b.ClassMethods;
            obj.MethodBuffers = b.MethodBuffers;
            if ~isempty(char(m))
                % linefeed before first method code block
                addcr(obj.FileBuffer);
                
                add(obj.FileBuffer,m);
            end
        end
        
        function createProperties(obj)
            % Add property code blocks to class text buffer.
            
            % In case option has changed:
            pdb = obj.PropertyDB;
            pdb.AddLineBetweenProperties = obj.AddLineBetweenProperties;
            
            p = getPropertyBuffer(pdb);
            if ~isempty(char(p))
                % getPropertyBuffer includes a trailing CR, but no additional
                % blank line after it.  Use "add" to add this without
                % additional blank lines.
                
                % linefeed before first property code block
                addcr(obj.FileBuffer);
                
                add(obj.FileBuffer,p);
            end
        end
        
        function createEvents(obj)
            % Add event code blocks to class text buffer.
            
            % In case option has changed:
            edb = obj.EventDB;
            edb.AddLineBetweenProperties = obj.AddLineBetweenProperties;
            
            e = getPropertyBuffer(edb);
            if ~isempty(char(e))
                % getEventBuffer includes a trailing CR, but no additional
                % blank line after it.  Use "add" to add this without
                % additional blank lines.
                
                % linefeed before first event code block
                addcr(obj.FileBuffer);
                
                add(obj.FileBuffer,e);
            end
        end
        
        function createClassdefEnd(obj)
            buff = obj.FileBuffer;
            buff.addcr('end'); % close classdef
        end
        
        function createFileEnd(obj)
            if obj.EndOfFileMarker
                buff = obj.FileBuffer;
                buff.addcr;
                buff.addcr('% [EOF]');
            end
        end
        
        function createCommentBlock(obj)
            % Add function help, See Also, Copyright, and Time stamp.
            
            buff = obj.FileBuffer;
            
            % H1-line of comments for function definition
            if isempty(obj.H1Line)
                buff.addcr('%%%s',obj.Name);
            else
                buff.addcr('%%%s %s',obj.Name,obj.H1Line);
            end
            
            % General body of Help text
            s = obj.Help;
            if ~isempty(s)
                if isa(s,'StringWriter') || ischar(s)
                    buff.addcr('%%   %s',s);
                else % cell-str
                    N = numel(s);
                    for i = 1:N
                        buff.addcr('%%   %s',s{i});
                    end
                end
            end
            
            % See Also
            s = obj.SeeAlso;
            N = numel(s);
            if N>0
                buff.addcr('%');
                buff.add('%   See also ');
                if isa(s,'StringWriter') || ischar(s)
                    buff.addcr(s);
                else % cell-str
                    for i = 1:N
                        buff.add('%s',s{i});
                        if i<N
                            buff.add(', ');
                        end
                    end
                    buff.addcr('.');
                end
            end
            
            % Leave one blank line after H1line, or anything thereafter
            buff.addcr;
            extra = false;
            
            s = obj.Copyright;
            if ~isempty(s)
                extra=true;
                buff.addcr('%%   %s',s);
            end
            
            if obj.RCSRevisionAndDate
                extra=true;
                buff.addcr('%   $Revision: $ $Date: $');
            end
            
            if obj.TimeStampInHeader
                if extra
                    buff.addcr('%');
                end
                buff.addcr('%%   Generated on %s',datestr(now,0));
                %extra=true;
            end
            
            if obj.CoderCompatible
                buff.addcr;
                buff.addcr('%#codegen');
                
                % To suppress warning for codegen of MATLAB objects:
                buff.addcr('%#ok<*EMCLS>');
                
                buff.addcr;
            end
        end
        
        function createClassdef(obj)
            % Add classdef line to buffer, including mixins.
            
            buff = obj.FileBuffer;
            
            % Classdef line
            %
            classAttr = strjoin(obj.ClassAttributes, ', ');
            if ~isempty(obj.ClassAttributes)
                classAttr = ['(' classAttr ') '];
            end
            add(buff,'classdef %s%s',classAttr,obj.Name);
            superStr = strjoin(obj.SuperClasses,' & ');
            if ~isempty(superStr)
                add(buff,' < %s',superStr);
            end
            addcr(buff); % end classdef line
        end
    end
    
    methods(Access=private, Static)
        function generateFilesAndEdit(buffers, fullpath, editFiles)
            fn = fieldnames(buffers);
            for ii=1:numel(fn)
              method_file_name = fullfile(fullpath, [fn{ii} '.m']);
              write(buffers.(fn{ii}),method_file_name);
              if editFiles
                  edit(method_file_name);
              end
            end
        end
    end

end
