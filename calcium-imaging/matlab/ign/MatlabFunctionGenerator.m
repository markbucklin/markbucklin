classdef MatlabFunctionGenerator < handle
    % Generate a MATLAB function.
            
    % Copyright 2014 The MathWorks, Inc.
    
    properties
        % Name of the function and the corresponding file name.
        Name = 'myFunc'
        Path = ''
        
        % Cell-string of input variable names.
        % Special names include: 'varargin', '~'.
        InputArgs = {}
        
        % Cell-string of output variable names, with several reserved
        % words.
        % Special names include: 'varargin'.
        OutputArgs = {}
        
        % One-line summary of function operation when help is obtained. The
        % function name is automatically prepended to this line of text
        % when code is generated.
        H1Line = ''
        
        % Help text for the function.
        % Can be a string or a cell-string.
        Help = ''
        
        % Cell-string defining the names of related functions.
        SeeAlso = {}
        
        Copyright = ''
        
        RCSRevisionAndDate = true
        TimeStampInHeader = true
        CoderCompatible = false
        EndOfFileMarker = true
        
        % Holds MLint warning suppression strings, rendered on the same
        % line as the function interface definition.
        CodeAnalyzerSuppression = ''

        %Optionally have all end of line comments in the CodeBuffer section be
        %vertically aligned
        AlignEndOfLineComments = true
    end
    
    properties (Access=protected)
        % Set to false when local functions are not to be generated
        % immediately following the primary function.
        %
        % This is useful for class generation where local functions are
        % generated after all methods have been generated.
        GenerateLocalFcnWithPrimaryFcn = true
    end
    
    properties (SetAccess=private,Dependent)
        HasBodyCode
        HasPrePersistentCode
        HasPersistentInitCode
        NumLocalFcns
        NumNestedFcns
        NumPersistentVars
    end
    
    properties (Access=private)
        CodeBuffer % StringWriter used to capture parts of complete program
        
        % Complete program returned as a StringWriter.
        % Use getFileBuffer to assemble complete program.
        FileBuffer
        
        LocalFcnList
        NestedFcnList
        
        PersistentVars = {}
        PersistentInitCode
        PrePersistentCodeBuffer
    end
    
    methods
        function obj = MatlabFunctionGenerator(Name,In,Out)
            if nargin>0
                obj.Name = Name;
            end
            if nargin>1
                obj.InputArgs = In;
            end
            if nargin>2
                obj.OutputArgs = Out;
            end
            
            % Initialize
            obj.CodeBuffer = StringWriter;
            obj.PersistentInitCode = StringWriter;
            obj.PrePersistentCodeBuffer = StringWriter;
        end
        
        function set.Name(obj,str)
            if ~ischar(str)
                error(message('siglib:MATLABGenerator:FunctionNameString'));
            end
            
            % Need to allow for "set.PropName" as a method name.
            % genvarname is too strict.
            %str = genvarname(str);
            
            obj.Name = str;
        end
        
        function set.Path(obj,str)
            if ~ischar(str)
                error(message('siglib:MATLABGenerator:PathMustBeString'));
            end
            obj.Path = str;
        end
        
        function set.InputArgs(obj,strs)
            if ~iscellstr(strs) && ~ischar(strs)
                error(message('siglib:MATLABGenerator:InArgsStr'));
            end
            if ischar(strs)
                if isempty(strs)
                    % Map empty strings to empty cells.
                    % Also makes sure we hold {} and not {''}, so empty
                    % detection is much simpler.
                    strs = {};
                else
                    strs = {strs};
                end
            end
            obj.InputArgs = strs;
        end
        
        function set.OutputArgs(obj,strs)
            if ~iscellstr(strs) && ~ischar(strs)
                error(message('siglib:MATLABGenerator:OutArgsStr'));
            end
            if ischar(strs)
                if isempty(strs)
                    % Map empty strings to empty cells.
                    % Also makes sure we hold {} and not {''}, so empty
                    % detection is much simpler.
                    strs = {};
                else
                    strs = {strs};
                end
            end
            obj.OutputArgs = strs;
        end
        
        function set.H1Line(obj,str)
            if ~ischar(str)
                error(message('siglib:MATLABGenerator:H1String'));
            end
            obj.H1Line = str;
        end
        
        function set.Help(obj,strs)
            if ~ischar(strs) && ~iscellstr(strs)
                error(message('siglib:MATLABGenerator:HelpStr'));
            end
            if ischar(strs)
                strs = {strs};
            end
            obj.Help = strs;
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
        
        function tf = get.HasBodyCode(obj)
            tf = ~isempty(char(obj.CodeBuffer));
        end
        
        function N = get.NumLocalFcns(obj)
            N = numel(obj.LocalFcnList);
        end
        
        function N = get.NumNestedFcns(obj)
            N = numel(obj.NestedFcnList);
        end
        
        function N = get.NumPersistentVars(obj)
            N = numel(obj.PersistentVars);
        end
        
        function tf = get.HasPersistentInitCode(obj)
            tf = ~isempty(char(obj.PersistentInitCode));
        end
        
        function tf = get.HasPrePersistentCode(obj)
            tf = ~isempty(char(obj.PrePersistentCodeBuffer));
        end
        
        function y = isComment(obj)
            % A Help-only method may be created to add annotations
            % within a method block.
            %
            % For this use, the name is an empty string, no input or output
            % arguments, no body code, local, or nested functions are
            % defined.
            %
            % Attributes must match the attributes of the method block
            % for which the comment is intended to be rendered.
            y = isempty(obj.Name) && ...
                isempty(obj.InputArgs) && ...
                isempty(obj.OutputArgs) && ...
                ~obj.HasBodyCode && ...
                ~obj.HasPrePersistentCode && ...
                ~obj.HasPersistentInitCode && ...
                obj.NumLocalFcns==0 && ...
                obj.NumNestedFcns==0 && ...
                obj.NumPersistentVars==0;
        end
    end
    
    methods
        function addCode(obj,code,varargin)
            % Add code to body of MATLAB function.
            %
            % Supports string, sprintf syntax, and StringWriter input.
            % Allow no additional arg to create blank lines.
            if nargin>1
                if ischar(code)
                    if nargin>2
                        % if additional args, assume code is a format string
                        % for sprintf, and the remaining args are passed to
                        % sprintf.
                        code = sprintf(code,varargin{:});
                    end
                elseif isa(code,'StringWriter')
                    narginchk(2,2);
                else
                    error(message('siglib:MATLABGenerator:StringOrWriter'));
                end
                addcr(obj.CodeBuffer,code);
            else
                % Blank line
                addcr(obj.CodeBuffer);
            end
        end
        
        function addPrePersistentCode(obj,code,varargin)
            % Add code that is to appear before any persistent variables
            % are declared.  If persistent variables do not appear, this
            % code will still appear generally at the top of the body of
            % the function.
            %
            % Supports string, sprintf syntax, and StringWriter input.
            % Allow no additional arg to create blank lines.
            if nargin>1
                if ischar(code)
                    if nargin>2
                        % if additional args, assume code is a format string
                        % for sprintf, and the remaining args are passed to
                        % sprintf.
                        code = sprintf(code,varargin{:});
                    end
                elseif isa(code,'StringWriter')
                    narginchk(2,2);
                else
                    error(message('siglib:MATLABGenerator:StringOrWriter'));
                end
                addcr(obj.PrePersistentCodeBuffer,code);
            else
                % Blank line
                addcr(obj.PrePersistentCodeBuffer);
            end
        end
        
        function addPersistentVariables(obj,vars,varargin)
            % Add one or more persistent variables.
            % Supports string, cell-string, and sprintf syntax.
            if ~ischar(vars) && ~iscellstr(vars)
                error(message('siglib:MATLABGenerator:MustBeString'));
            end
            
            % String defines a single variable, cellstr can define
            % multiple variables.  Unify to use cellstr.
            if ischar(vars)
                if nargin>2
                    % using sprintf syntax
                    vars = sprintf(vars,varargin{:});
                end
                vars = {vars};
            end
            
            % Add persistent variable names to list:
            obj.PersistentVars = [obj.PersistentVars;vars(:)];
        end
        
        function addPersistentInitCode(obj,var,varargin)
            % Code that goes within "isempty(firstPersistentVar)"
            % conditional code block.
            %
            % Supports string, sprintf syntax, and StringWriter input.
            % Allow no additional arg to create blank lines.
            
            if nargin>1
                if nargin>2 && ischar(var)
                    var = sprintf(var,varargin{:});
                end
                addcr(obj.PersistentInitCode,var);
            else
                addcr(obj.PersistentInitCode);
            end
        end
        
        function addNestedFunction(obj,nestedFcn)
            % Adds a nested function described by a MatlabFunctionGenerator
            % object.  The nested function is defined in the context of the
            % parent MatlabFunctionGenerator object.
            
            if ~isa(nestedFcn,'sigutils.internal.emission.MatlabFunctionGenerator')
                error(message('siglib:MATLABGenerator:MustBeFcnGen'));
            end
            obj.NestedFcnList = [obj.NestedFcnList nestedFcn];
        end
        
        function addLocalFunction(obj,localFcn)
            % Adds a local function described by a MatlabFunctionGenerator
            % object.  The local function is defined in the context of the
            % parent MatlabFunctionGenerator object.
            
            if ~isa(localFcn,'sigutils.internal.emission.MatlabFunctionGenerator')
                error(message('siglib:MATLABGenerator:MustBeFcnGen'));
            end
            obj.LocalFcnList = [obj.LocalFcnList localFcn];
        end
        
        function buff = getFcnInterface(obj)
            % Create method comment and interface line as a StringWriter.
            % Use this to create a main class file and methods in separate
            % files
            buff = StringWriter;
            obj.FileBuffer = buff; % record in property
            renderMethodComment(obj);
            functionBody = false;
            createFcnInterface(obj, functionBody);
        end
        
        function buff = getFileBuffer(obj)
            % Create complete program and return it as a StringWriter.
            % Also made available as obj.FileBuffer.
            buff = updateProgramBuffer(obj);
        end
        
        function editFile(obj)
            % Generate the MATLAB file and place content in a new, unsaved
            % file in the MATLAB Editor.
            
            edit(getFileBuffer(obj));
        end
        
        function full_name = writeFile(obj,editFlag)
            % Write the MATLAB file to a folder.
            % Optionally open the file in the MATLAB Editor.
            
            % Name can differ due to our use of genvarnames called on the
            % file name
            full_name = fullfile(obj.Path,[obj.Name '.m']);
            
            buff = getFileBuffer(obj);
            write(buff,full_name);
            
            if nargin>1 && editFlag
                edit(full_name);
            end
        end
        
        function buffers = getLocalFunctionBuffer(obj, separateBuffers)
            % Return code for any local functions in a separate buffer.
            
            % Try to safeguard an unwary user:
            if obj.GenerateLocalFcnWithPrimaryFcn
                warning('MatlabFunctionGenerator:DuplicateLocalFcns', ...
                    ['Explicit return of local functions is not typical when ' ...
                    'GenerateLocalFcnWithPrimaryFcn=true due to potential for ' ...
                    'duplicate generation of local functions.']);
            end
            if nargin < 2
                separateBuffers = false;
            end
            buffers = createLocalFunctions(obj,separateBuffers);
        end
    end
    
    methods (Access=private)
        function buff = updateProgramBuffer(obj,isLocal)
            % Generate function from user-defined parts.
            
            if nargin<2
                isLocal = false;
            end
            
            % Create a new file buffer.
            buff = StringWriter;
            obj.FileBuffer = buff; % record in property

            if isComment(obj)
                renderMethodComment(obj);
            else
                renderMethodImpl(obj,isLocal);
            end
            
            indentMATLABCode(buff);
        end
        
        function renderMethodComment(obj)
            % Update buffer to represent a comment in a method block.
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
            
            buff = obj.FileBuffer;
            d = obj.Help; % cell-string
            Nd = numel(d);
            if Nd>0
                for i = 1:Nd
                    d_i = d{i};
                    if isempty(d_i)
                        % Append carriage return, no leading comment char
                        buff.addcr;
                    else
                        % Append comment with leading comment char
                        buff.addcr('%% %s',d_i);
                    end
                end
            end
        end
        
        function renderMethodImpl(obj,isLocal)
            % Generate all code for a function implementation.
            
            functionBody = true;
            createFcnInterface(obj, functionBody);
            createCommentBlock(obj,isLocal);
            createBody(obj);
            
            if obj.GenerateLocalFcnWithPrimaryFcn
                separateBuffers = false;
                buffer = createLocalFunctions(obj, separateBuffers);
                obj.FileBuffer.add(buffer);
            end
            
            createFcnEnd(obj,isLocal);
        end
        
        function createNestedFunctions(obj)
            mainbuff = obj.FileBuffer;

            nestedFcns = obj.NestedFcnList;
            N = numel(nestedFcns);
            for i = 1:N
                nestedFcn_i = nestedFcns(i);
                
                updateProgramBuffer(nestedFcn_i,true);
                localbuff = char(nestedFcn_i.FileBuffer);
                
                % One blank line before each nested fcn
                mainbuff.addcr;
                mainbuff.add(localbuff);
            end
        end
        
        function out = createLocalFunctions(obj,separateBuffers)
            % Generate to the FileBuffer by default, but allow generation
            % to an alternate buffer as an option.
            if nargin<2 || ~separateBuffers
                out = StringWriter;
            else
                out = struct;
            end

            localFcns = obj.LocalFcnList;
            N = numel(localFcns);
            
            % Generate linefeed before local fcns
            if N>0 && obj.HasBodyCode && ~separateBuffers
                addcr(out);
            end

            for i = 1:N
                localFcn_i = localFcns(i);
                
                updateProgramBuffer(localFcn_i,true);
                localbuff = char(localFcn_i.FileBuffer);
                if separateBuffers
                    out.(localFcn_i.Name) = localbuff;
                else
                    out.add(localbuff);
                end
                
                % One blank line between each local fcn, but not at end of
                % last function.
                %
                % xxx option to control this?
                if i<N && ~separateBuffers
                    out.addcr;
                end
            end
        end
        
        function createPersistentVars(obj)
            createPrePersistentCode(obj);
            createPersistentVarDecl(obj);
            createPersistentVarInit(obj);
        end
        
        function createPrePersistentCode(obj)
            % Render code before persistent variable declarations.
            
            % Assume code already has trailing CR, if user wanted that.
            code = string(obj.PrePersistentCodeBuffer);
            if ~isempty(code)
                add(obj.FileBuffer,code);
            end
        end
        
        function createPersistentVarDecl(obj)
            % Declare persistent variables
            
            buff = obj.FileBuffer;
            p = obj.PersistentVars;
            MaxNumPersistentPerLine = 5;
            
            N = numel(p);
            if N>0
                cnt = 0;
                buff.add('persistent');
                for i = 1:N
                    buff.add(' %s',p{i});
                    cnt=cnt+1;
                    if i<N && cnt==MaxNumPersistentPerLine
                        cnt = 0;
                        buff.addcr;
                        buff.add('persistent');
                    end
                end
                buff.addcr;
            end
        end
        
        function createPersistentVarInit(obj)
            % Initialize persistent variables.
            
            buff = obj.FileBuffer;
            p = obj.PersistentVars;
            initBuff = obj.PersistentInitCode;
            
            N = numel(p);
            if N==0 && isempty(initBuff)
                % No variables declared, but init code exists.
                error(message('siglib:MATLABGenerator:ExpectedPersistentVars'));
            end
            if N>0 && chars(initBuff)>0
                buff.addcr('if isempty(%s)',p{1})
                
                % Don't add a CR when rendering the initBuff.
                % It's expected that the user has formatted the code as
                % they want it.
                buff.add(initBuff);
                
                buff.addcr('end');
                buff.addcr;
            end
        end
        
        function createBody(obj)
            
            buff = obj.FileBuffer;
            
            createPersistentVars(obj);
            
            % Assume code already has trailing CR, if user wanted that.
            s = string(obj.CodeBuffer);
            if obj.AlignEndOfLineComments 
              s = sigutils.internal.emission.retabEOLComments(s); 
            end
            add(buff, s);
            
            createNestedFunctions(obj);

            % Always close the main function with an "end"
            buff.addcr('end');
        end
        
        function createFcnEnd(obj,isLocal)
            if nargin<2
                isLocal = false;
            end
            
            if ~isLocal && obj.EndOfFileMarker
                buff = obj.FileBuffer;
                buff.addcr;
                buff.addcr('% [EOF]');
            end
        end
        
        function createCommentBlock(obj,isLocal)
            % Add function help, See Also, Copyright, and Time stamp.
            
            if nargin<2
                isLocal = false;
            end
            
            buff = obj.FileBuffer;
            
            if ~isempty(obj.H1Line) || ~isempty(obj.Help)
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
            end
            
            if ~isLocal
                % See Also
                s = obj.SeeAlso;
                N = numel(s);
                if N>0
                    buff.addcr('%');
                    buff.add('%   See also ');
                    if isa(s,'StringWriter') || ischar(s)
                        buff.addcr(s);
                    else % cell-str
                        buff.add(strjoin(s,','));
                        buff.addcr('.');
                    end
                    
                    % Leave one blank line if "see also" rendered
                    buff.addcr;
                end
                
                extra=false;
                
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
                    extra=true;
                end

                if obj.CoderCompatible
                    if extra
                        buff.addcr('%');
                    end
                    buff.addcr('%#codegen');
                    extra=true;
                end
                
                if extra
                    % leave a blank line after trailing comments
                    buff.addcr;
                end
            end
        end
        
        function createFcnInterface(obj, forFcnBody)
            % Add function interface line to FileBuffer.
            %
            % If forFcnBody is false, an interface line without 'function'
            % is created for use in classdef method declarations.  This allows
            % a function body to be generated in separate file, or prototyped in
            % the classdef and generated to a separate file.
            
            buff = obj.FileBuffer;
            
            % InArgs
            inArgs = strjoin(obj.InputArgs, ', ');
            if ~isempty(inArgs)
                inArgs = ['(' inArgs ')'];
            end
            
            % OutArgs
            N = numel(obj.OutputArgs);
            outArgs = strjoin(obj.OutputArgs, ', ');

            if N>0
                if N>1
                    outArgs = ['[' outArgs ']'];
                end
                outArgs = [outArgs ' = '];
            end
            
            msgs = obj.CodeAnalyzerSuppression;
            if ~isempty(msgs)
                msgs = [' %#ok<' msgs '>'];
            end
            
            if forFcnBody
                addcr(buff,'function %s%s%s%s', ...
                  outArgs,obj.Name,inArgs,msgs);
            else
                addcr(buff,'%s%s%s%s', ...
                  outArgs,obj.Name,inArgs,msgs);
            end
        end
    end
end
