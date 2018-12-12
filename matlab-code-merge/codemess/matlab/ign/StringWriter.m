classdef StringWriter < handle
    % StringWriter Return a StringWriter object.
    %   StringWriter provides services to assemble sequences of strings
    %   into a single text buffer.
    %
    %   S=StringWriter returns an empty StringWriter object, while
    %   S=StringWriter(T) adds char(T) to the buffer during construction.
    %   T can be any object supporting the char() method.
    %   Carriage return followed by line feed (CR+LF, '\r\n') in char(T)
    %   is replaced with a single line feed.
    %
    %   StringWriter methods:
    %       add        - Concatenate string to end of string writer.
    %       addcr      - Adds string with a line feed (LF, '\n') after it.
    %       cradd      - Adds string with a line feed before it.
    %       craddcr    - Adds string with a line feed before and after.
    %       insert     - Insert a string into buffer.
    %       clear      - Clear string writer, resetting its length to zero.
    %       char       - Return buffer contents as a character string.
    %       string     - Return buffer contents as a string.
    %       chars      - Number of characters in string writer.
    %       lines      - Number of lines of text in string writer.
    %       edit       - Copy buffer contents into the MATLAB Editor.
    %       write      - Write buffer contents to a text file.
    %       readfile   - Replace string writer contents with text from a file.
    %       indentCode - Apply smart indenting to code in the string writer.
    %       cellstr    - Return buffer contents as a cell array of strings or
    %                    add strings from a cell array to the buffer
    %
    %   StringWriter public fields:
    %       Indent   - Number of spaces to indent after a line feed.
    
    %   Copyright 2007-2012 The MathWorks, Inc.
    
    properties
        % Number of spaces to indent prior to text additions made after
        % a line feed.  Indentation only occurs when using the add,
        % addcr, cradd, and craddcr methods.
        Indent = 0
    end
    
    properties (Access=private)
        % Buffer is private and should only be accessed through methods.
        Buffer = ''  % Row vector of chars
    end
    
    properties (SetAccess=protected)
        % Subclasses can change the private definition of the Line Feed
        % (LF) character.
        LF = sprintf('\n')
    end
    
    methods
        function S = StringWriter(varargin)
            % Return a StringWriter object.
            %
            % S=StringWriter returns an empty StringWriter object.
            % S=StringWriter(T) adds string T to the buffer by invoking
            %   the method add(S,T) automatically.

            if nargin>0
                S.add(varargin{:});
            end
        end
        
        function set.Indent(S,V)
            if V<0 || V~=fix(V) || isinf(V)
                error(message('siglib:stringwriter:InvalidIndentValue'));
            end
            S.Indent = V;
        end
        
        function add(S,varargin)
            % Concatenate string to end of string writer.
            %   add(S) leaves the buffer S unchanged.
            %   add(S,T) adds string T to the end of buffer S.
            %   add(S,F,V1,V2, ...) adds format string F to buffer S,
            %      using variables V1, V2, etc, as appropriate.
            verifyIsScalar(S);
            if nargin==2
                S.Buffer = [S.Buffer indentstr(S) replaceCrLf(varargin{1})];
            elseif nargin>2
                % Could fail - allow that without try/catch
                % Keeps performance high
                S.Buffer = [S.Buffer indentstr(S) replaceCrLf(sprintf(varargin{:}))];
            end
        end
        
        function addcr(S,varargin)
            % Adds string with a line feed (LF) after it.
            %   addcr(S) adds a LF to string writer S.
            %   addcr(S,T) adds string T to buffer S followed by a LF.
            %   addcr(S,F,V1,V2,...) adds format string F to buffer S,
            %      using variables V1, V2, etc, as appropriate, then adds
            %      a LF.
            verifyIsScalar(S);
            if nargin<2
                S.Buffer = [S.Buffer S.LF];
            elseif nargin==2
                S.Buffer = [S.Buffer indentstr(S) replaceCrLf(varargin{1}) S.LF];
            else
                S.Buffer = [S.Buffer indentstr(S) replaceCrLf(sprintf(varargin{:})) S.LF];
            end
        end
        
        function varargout = cellstr(S, acellstr)
            % Accept and return cell array of strings
            %   cellstr(S) returns buffer contents as a cell array of
            %      strings with one line of text in each cell. A line is
            %      defined as text ending with line feed. Number of
            %      elements in the cell array is equal to the number of
            %      lines. This enables mapping of cell array of strings
            %      back to the StringWriter object.
            %   cellstr(S, acellstr) add strings in the cell array
            %      acellstr to the string writer object.
            verifyIsScalar(S);
            if nargin < 2
                % Return a cell array of strings
                t = regexp(S.Buffer, '\n', 'split')';
                varargout = {t};
            else
                % Add strings in the given cell array to the buffer
                if ~iscellstr(acellstr)
                    error(message('siglib:stringwriter:ErrorInvalidCellStr'));
                end
                n = numel(acellstr);
                if n > 0
                    for indx = 1:n-1
                        S.addcr(acellstr{indx});
                    end
                    S.add(acellstr{end});
                end
            end
        end
        
        function t = char(S)
            % Return buffer contents as a character string.
            verifyIsScalar(S);
            t = S.Buffer;
        end
        
        function N = chars(S)
            % Number of characters in string writer.
            verifyIsScalar(S);
            N = length(S.Buffer);
        end
        
        function clear(S)
            % Clear string writer, resetting its length to zero.
            verifyIsScalar(S);
            S.Buffer = '';
        end
        
        function cradd(S,varargin)
            % Adds string with a line feed (LF) before it.
            %   cradd(S) adds a LF to string writer S.
            %   cradd(S,T) adds string T to buffer S, preceded by a LF.
            %   cradd(S,F,V1,V2,...) adds format string F to buffer S,
            %      preceded by a LF.

            % Put LF into the buffer first, so indentstr will "see" the
            % LF and do the indent for us properly.
            verifyIsScalar(S);
            S.Buffer = [S.Buffer S.LF];
            if nargin<2
                % Nothing more to do
            elseif nargin==2
                S.Buffer = [S.Buffer indentstr(S) replaceCrLf(varargin{1})];
            else
                S.Buffer = [S.Buffer indentstr(S) replaceCrLf(sprintf(varargin{:}))];
            end
        end
        
        function craddcr(S,varargin)
            % Add string with a line feeds (LF) before and after.
            %   craddcr(S) adds two LF characters to string writer S.
            %   craddcr(S,T) adds a LF, then string T, then another LF to
            %      string writer S.
            %   craddcr(S,F,V1,V2,...) adds format string F to buffer S,
            %       with a LF before and after the format text.
            
            % Put LF into the buffer first, so indentstr will "see" the
            % LF and do the indent for us properly.
            verifyIsScalar(S);
            S.Buffer = [S.Buffer S.LF];
            if nargin<2
                S.Buffer = [S.Buffer S.LF];
            elseif nargin==2
                S.Buffer = [S.Buffer indentstr(S) replaceCrLf(varargin{1}) S.LF];
            else
                S.Buffer = [S.Buffer indentstr(S) replaceCrLf(sprintf(varargin{:})) S.LF];
            end
        end
        
        function disp(S)
            % Display string writer contents.
            dash = repmat('-',[1 18]);
            if isscalar(S)
                fprintf('%s object',class(S));
                fprintf(' (chars=%d, lines=%d, indent=%d)\n', ...
                    chars(S), lines(S), S.Indent);
                fprintf('%s[ Start of buffer ]%s\n', dash, dash);
                fprintf('%s', char(S));
                fprintf('\n%s[  End of buffer  ]%s\n',dash,dash);
            else
                fprintf('Array of %s objects of size %s\n',class(S),...
                    mat2str(size(S)));
            end
        end
        
        function edit(S,varargin)
            % Copy buffer contents into the MATLAB Editor.
            %   edit(S) copies the buffer contents into the MATLAB
            %      Editor, creating a new temporary file.
            %   edit(S,NAME) uses string NAME for the MATLAB file name.
            verifyIsScalar(S);
            edit(write(S,varargin{:}));
        end
        
        function S = horzcat(S1,varargin)
            % Horizontal concatenation.
            %   S=[S1,S2,...] appends string S2 to the contents of string
            %   buffer S1, returning a newly created string writer to hold
            %   the result.  S2 and later arguments can be either text
            %   strings or string writer objects.
            verifyIsScalar(S1)
            S = StringWriter(S1.Buffer); % Create new StringWriter
            for i = 1:nargin-1
                if isa(varargin{i},'StringWriter')
                    S.add(varargin{i}.Buffer);
                elseif isa(varargin{i},'char')
                    S.add(varargin{i});
                else
                    error(message('siglib:stringwriter:ConcatenationInvalidInput'));
                end
            end
        end
        
        function append(S,T)
            % Append string to the end of buffer.
            %   append(S,T) inserts text T at end of string writer S.
            insert(S,inf,T);
        end
        
        function prepend(S,T)
            % Prepend string to the start of buffer.
            %   prepend(S,T) inserts text T at start of string writer S.
            insert(S,1,T);
        end
        
        function insert(S,POS,T)
            % Insert a string into buffer.
            %   insert(S,POS,T) inserts text T starting at location POS,
            %   where POS=1 inserts text T starting at the first character
            %   position in string writer S.  The current string writer
            %   content is shifted as needed and the buffer extended to
            %   hold the new string.
            %
            %   POS is rounded and clipped to the range 1<=POS<=1+chars(S).
            
            verifyIsScalar(S);
            Ns = length(S.Buffer);
            POS = round(POS);
            if POS > Ns+1
                POS = Ns+1; % append T to end of S
            elseif POS < 1
                POS = 1; % prepend T to the start of S
            end
            T = replaceCrLf(T); % Do before counting characters
            Nt = numel(T); % #chars in insertion text
            
            % Shift last part of string, at/after insertion point, to just
            % after the length of the string to insert
            S.Buffer(POS+Nt:end+Nt) = S.Buffer(POS:end);
            
            % Insert new string
            S.Buffer(POS:POS+Nt-1) = T;
        end
        
        function N = lines(S)
            % Number of lines of text in string writer.
            
            % Add one to the count of all LF characters
            % (The first line of text is "line 1", yet may have no LF)
            verifyIsScalar(S);
            N = 1+numel(strfind(S.Buffer,S.LF));
        end
        
        function t = string(S)
            % Return buffer contents as a string.
            % This is the same operation as char(S).
            verifyIsScalar(S);
            t = char(S);
        end
        
        function S = vertcat(S1,varargin)
            % Vertical concatenation.
            % S=[S1;S2;...] appends a line feed and string S2 to the
            % contents of string writer S1, returning a newly created
            % string writer to hold the result.  S2 and later arguments can
            % be either text strings or string writer objects.
            verifyIsScalar(S1);
            % Return a new StringWriter
            S = StringWriter(S1.Buffer);
            for i=1:nargin-1
                if isa(varargin{i},'StringWriter')
                    S.cradd(varargin{i}.Buffer);
                elseif isa(varargin{i},'char')
                    S.cradd(varargin{i});
                else
                    error(message('siglib:stringwriter:ConcatenationInvalidInput'));
                end
            end
        end
        
        function varargout = write(S,fname)
            % Write buffer contents to a text file.
            %   write(S,NAME) uses string NAME as the name of the file.
            %   write(S) writes the contents of string writer S to a
            %     temporary file.
            verifyIsScalar(S);
            if nargin<2
                fname = tempname;  % Create a temporary filename
            end

            % Only return the file name if asked.
            if nargout > 0
                varargout = {fname};
            end
            
            % Requested directory might not exist
            if ~createParentDir(fname)
                error(message('siglib:stringwriter:ErrorCreateDirectory'));
            end
            
            % Open file
            [fid, msg] = fopen(fname,'wt');  % open in "write text" mode, no append
            if fid==-1
                error(message('siglib:stringwriter:ErrorWritePermissionDenied', msg));
            end
            fprintf(fid,'%s', S.Buffer);
            fclose(fid);
        end
        
        function t = readfile(S,fname)
            % Replace string writer contents with text from a file.
            %   readfile(S,NAME) replaces the contents of string writer S
            %     with text read from file NAME. 
            
            %   T=readfile(S,NAME) optionally returns the text as a string
            %     in T, as if T=char(S) was called.
            verifyIsScalar(S);
            [fid,msg] = fopen(fname);
            if fid==-1
                error(message('siglib:stringwriter:ErrorReadPermissionDenied', msg));
            end
            S.clear;
            while 1
                tline = fgets(fid);
                if ~ischar(tline), break, end
                S.add(tline);
            end
            fclose(fid);
            if nargout>0
                t = S.Buffer;
            end
        end
        
        function indentCode(S,lang)
            % Apply smart indenting to code in the string writer.
            %   indentCode(S) replaces the contents of string
            %   buffer S with a copy reformatted according to "smart
            %   indent" rules for the MATLAB language L.
            %
            %   indentCode(S,L) specifies language L and must be one of the
            %   following:
            %     'c', 'java', 'matlab', 'plain', 'simscape', 'tlc',
            %     'verilog', 'vhdl', 'xml'.
            verifyIsScalar(S);
            if nargin<2
                lang = 'matlab';
            end
            S.Buffer = indentcode(S.Buffer,lang);
        end
    end
    
    methods (Hidden)
        function indentMATLABCode(S)
            % This method will be removed in a future release.
            % Use indentCode(S,'matlab') instead.
            
            % Apply smart indenting to MATLAB code in the string writer.
            %   indentMATLABCode(S) replaces the contents of string writer
            %   S with a copy reformatted according to "smart indent" rules
            %   used by the MATLAB Editor.
            indentCode(S,'matlab');
        end
    end
    
    methods (Access=private)
        function t = indentstr(S)
            % Only return spaces if the next buffer position is at the
            % start of a new line, e.g., the last char was a LF, or
            % we're at the start of the buffer.
            
            if (S.Indent>0) && ...
                    ( isempty(S.Buffer) || strcmp(S.Buffer(end-numel(S.LF)+1:end),S.LF) )
                t = blanks(S.Indent);
            else
                t = '';
            end
        end
        function verifyIsScalar(S)
            % Verify that the S is a scalar string writer
            if ~isscalar(S)
                error(message('siglib:stringwriter:ErrorScalarMethod'));
            end
        end
    end
end

% ----------------
% Helper functions
% ----------------

function success = createParentDir(fname)
% Returns 1 if path exists or was created
% Returns 0 otherwise

p = fileparts(fname);
% If the path doesn't exist or is empty, return 0 and make the directory.
% MKDIR warns if the path is an empty string.
success = isempty(p) || exist(p,'dir');
if ~success
    success = mkdir(p);
end

end

function s = replaceCrLf(s)
% Replace CR+LF (\r\n) with LF
% readfile method of StringWriter regress by 8% due to this preprocessing.

s = strrep(char(s),sprintf('\r\n'),sprintf('\n')); % CR + LF

end

% [EOF]
