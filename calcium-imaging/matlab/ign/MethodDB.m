classdef MethodDB < handle
    % Database holding multiple MatlabMethodGenerator definition objects.
    % Used by MatlabClassGenerator to define and emit method definitions
    % in class files.
        
    % Copyright 2014 The MathWorks, Inc.
    
    properties
        % Name of the class
        ClassName

        AddLineBetweenMethods = true
        
        % Setting to false minimizes the number of unique method blocks,
        % based on common method attribute lists.  Order of methods is
        % preserved within each common method block.
        %
        % Set to true to respect the order of all methods in the
        % database.
        KeepMethodOrder = true
        
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
        MethodList = sigutils.internal.emission.MatlabMethodGenerator.empty
    end
    
    methods
        function obj = MethodDB(method)
            if nargin>0
                add(obj,method);
            end
        end
        
        function set.KeepMethodOrder(obj,val)
            %Only KeepMethodOrder == true is implemented so far.
            if ~(islogical(val) && val)
                error(message('siglib:MATLABGenerator:KeepMethodOrder'));
            end
            obj.KeepMethodOrder = val;
        end
        
        function add(obj,method)
            % Add a method definition object to the database.
            if ~isa(method,'sigutils.internal.emission.MatlabMethodGenerator')
                error(message('siglib:MATLABGenerator:MustBeMethodGen'));
            end
            
            obj.MethodList(end+1) = method;
        end
        
        function out = getMethodBuffer(obj)
            % Return struct defining all methods within method
            % code block. struct has two fields ClassMethods and
            % MethodBuffers. If GenerateSeparateFiles is false,
            % ClassMethods contains all code for all methods. If
            % GenerateSeparateFiles is true, MethodBuffers contains all
            % methods that can be written as a separte file. Those methods
            % which cannot be in a separte file and the signature of
            % methods that can be written in a separate file are present in
            % ClassMethods.
            %
            % No local functions are captured in this process, since
            % MatlabMethodGenerator objects separate the local function
            % generation from the primary function generation.  We
            % generate local functions explicitly elsewhere in the class
            % generation process.
            
            MethodBuffers = struct;
            s = StringWriter;
            
            % Cache last set of attributes to know when a new method
            % block must be created.
            a_last = {};
            anyBlockOpen = false;
            
            methodsInThisMethodBlock = 0;
            
            % suppresses an undesirable initial linefeed before first
            % method if we set this to true:
            lastWasComment = false;
            
            % Loop through all methods
            meths = obj.MethodList;
            N = numel(meths);
            for i = 1:N
                m_this = meths(i);
                a_this = m_this.Attributes;
                
                % Use setxor so the attribute string comparison is
                % order-independent:
                if i==1 || ~isempty(setxor(a_this,a_last))
                    if anyBlockOpen
                        s.addcr('end'); % close previous method block
                        s.addcr; % and add a linefeed
                    else
                        anyBlockOpen = true; % it will be now!
                    end
                    a_last = a_this; % cache for change detection
                    s.add('methods'); % open new block
                    attr_i = getAttributeStr(m_this);
                    if ~isempty(attr_i)
                        s.add(' (%s)',attr_i);
                    end
                    s.addcr; % CR at end of 'methods' definition line
                    methodsInThisMethodBlock = 0;
                end
                
                needCrBeforeMethod = false;
                if ~lastWasComment && ...
                        methodsInThisMethodBlock>0 && ...
                        obj.AddLineBetweenMethods
                    % Prepend a linefeed before emitting code for 2nd or
                    % subsequent consecutive method in this method block.
                    needCrBeforeMethod = true;
                end
                
                % Render next method (implementation or comment).
                % Use add, not addcr, as declaration has trailing LF.
                
                % If GenerateSeparateFiles is true, generate methods other
                % than constructor and get/set methods in separate buffers
                if isFunctionInSeparateFile(obj, m_this)
                    % Add code to separate buffer for methods
                    if ~isempty([a_this{:}])
                        % Need to generate interface in main buffer only
                        % for methods with non-default attributes
                        if needCrBeforeMethod
                            s.addcr;
                        end
                        s.add(getFcnInterface(m_this));
                    end
                    methodBuffer = StringWriter;
                    methodBuffer.add(getFileBuffer(m_this));
                    MethodBuffers.(m_this.Name) = methodBuffer;
                else
                    if needCrBeforeMethod
                        s.addcr;
                    end
                    if isAbstract(m_this)
                        % Only function interface for Abstract methods
                        s.add(getFcnInterface(m_this));
                    else
                        % Add to main buffer
                        s.add(getFileBuffer(m_this));
                    end
                end
                methodsInThisMethodBlock = methodsInThisMethodBlock + 1;
                lastWasComment = isComment(m_this);
            end
            if N>0
                s.addcr('end'); % close last method code block
            end
            out.ClassMethods = s;
            out.MethodBuffers = MethodBuffers;
        end
        
        function s = getLocalFunctionBuffer(obj)
            % Return text buffer defining all local functions.

            s = StringWriter;
            
            % Loop through all methods, retrieving any local functions that
            % method may have defined.
            renderedAnyLocalFcns = false;
            meths = obj.MethodList;
            N = numel(meths);
            for i = 1:N
                m_this = meths(i);
                
                % Propagate setting from MethodDB to individual methods
                % m_this.AddLineBetweenMethods = obj.AddLineBetweenMethods;
                
                Nlocal = m_this.NumLocalFcns;
                if Nlocal>0
                    if renderedAnyLocalFcns
                        if obj.AddLineBetweenMethods
                            s.addcr; % CR between groups of local fcns
                        end
                    else
                        % Prepend CR before the first local function.
                        s.addcr;
                        renderedAnyLocalFcns = true;
                    end
                    
                    s.addcr('%% Local functions called from %s()', m_this.Name);
                    s.addcr('%');
                    
                    % Render next local function.
                    localBuffer = getLocalFunctionBuffer(m_this);
                    % Use add, not addcr, as declaration has trailing LF.
                    s.add(localBuffer);
                end
            end
        end
        
        function out = getSeparateLocalFunctionBuffers(obj)
            % Return struct with text buffer fields defining each local function.

            out = struct;
            
            % Loop through all methods, retrieving any local functions that
            % method may have defined.
            meths = obj.MethodList;
            N = numel(meths);
            for i = 1:N
                m_this = meths(i);
                
                % Propagate setting from MethodDB to individual methods
                % m_this.AddLineBetweenMethods = obj.AddLineBetweenMethods;
                
                Nlocal = m_this.NumLocalFcns;
                if Nlocal>0
                    % Render next local function.
                    localBuffers = getLocalFunctionBuffer(m_this, obj.GenerateSeparateFiles);
                    fn = fieldnames(localBuffers);
                    for ii=1:numel(fn)
                        s = StringWriter;
                        s.addcr('%% Local functions called from %s()', m_this.Name);
                        s.addcr('%');
                        s.add(localBuffers.(fn{ii}));
                        out.(fn{ii}) = s;
                    end
                end
            end
        end
    end
    
    methods (Access=private)
        function y = isFunctionInSeparateFile(obj, m)
            y = obj.GenerateSeparateFiles && ...
                ~strcmp(m.Name, obj.ClassName) && ... % constructor
                isempty(find(m.Name=='.',1)) && ...   % getter/setter
                ~strcmp(m.Name, 'delete') && ...      % delete
                ~isComment(m) && ...
                ~isAbstract(m);
        end
    end
end
%--------------------------------------------------------------------------
%   Local functions
%--------------------------------------------------------------------------
function y = isAbstract(m)
% Return true if Abstract is found in the method attributes
    y = ~isempty(strfind([m.Attributes{:}], 'Abstract'));
end
