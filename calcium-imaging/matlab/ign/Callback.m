classdef Callback
    %CALLBACK Utilities to work with Callback-like properties
    %
    % This undocumented class may be removed in a future release.
    %
    % This class contains only static methods and is not intended to be
    % instantiated.
    %
    % internal.Callback methods:
    %
    %   validate    Checks if a value is a valid callback data type
    %   execute     Evaluates a callback data type
    
    % Copyright 2011-2015 The MathWorks, Inc.
    % $Revision: 1.1.6.1.12.1 $  $Date: 2013/09/20 15:10:45 $  
    
    methods(Static)
        function passed = validate(callback)
            % VALIDATE Checks a value is a valid callback data type
            %
            % PASSED = VALIDATE(CALLBACK) returns true if CALLBACK is a
            % valid type for a callback.
            %
            % Valid callback types are:
            %   * a function handle
            %
            %   * a string
            %
            %   * a 1xN cell array where the first element is either a
            %     function handle or a string
            %
            %   * [], representing no callback
            %
            %  Example: Using validate() in a setter.
            %
            %    function obj = set.MyCallbackProperty(obj, newValue)
            %
            %       if(~Callback.validate(newValue))
            %           error( . . . )
            %       end
            %
            %       obj.MyCallbackProperty = newValue;
            %    end
            
            % Check for it being one of:
            % - []
            % - string
            % - fcn Handle
            % - cell array
            if ~isempty(callback) &&...
                    ~ischar(callback) &&...
                    ~isa(callback, 'function_handle') &&...
                    ~iscell(callback)
                
                passed = false;
                return;
            end
            
            % Extra validation is required for cell arrays.
            % The first element must be either:
            % - a function handle
            % - a string
            
            if iscell(callback) && ...
                    (isempty(callback) || ...
                    ~isrow(callback) || ...
                    ~isa(callback{1}, 'function_handle') && ...
                    ~ischar(callback{1}))
                
                passed = false;
                return;
            end
            
            % All checks have passed
            passed = true;
        end
        
        function execute(callback, src, event)
            % EXECUTE Evaluates a callback data type
            %
            % EXECUTE(CALLBACK, SRC) evaluates the given CALLBACK data type
            % from the given SRC.  [] will be used for EVENT.
            %
            % EXECUTE(CALLBACK, SRC, EVENT) evaluates the given CALLBACK
            % data type from the given SRC with the given EVENT.
            %
            % * If CALLBACK is a string, then it will be evaluated in the
            %   base work space.  SRC and EVENT will not be passed in.
            %
            % * If CALLBACK is a function handle, then it will be evaluated
            %   by passing SRC and EVENT to the function handle.
            %
            % * If CALLBACK is a cell array, then it will be evaluated by
            %   passing in SRC, EVENT, and any additional arguments
            %   specified in the cell array.
            %
            %
            %  Example: Using execute() to dispatch a callback
            %
            %    function triggerMyCallback(obj)
            %
            %       % Get the inputs ready
            %       callback = obj.MyCallbackProperty;
            %       src = obj;
            %       event = MyEventData;
            %
            %       % Kick off the callback
            %       Callback.execute(callback, src, event);
            %
            %    end
            
            narginchk(2,3)
            
            % event is [] when not specified
            if(nargin == 2)
                event = [];
            end
            
            try
                if ischar(callback)

                    % Eval the string to execute it.
                    evalin('base', callback);

                elseif isa(callback, 'function_handle')

                    % Call the function directly.
                    feval(callback, src, event);

                elseif iscell(callback)

                    % First element is the function handle or function string
                    funcHandle = callback{1};

                    % Remaining elements in the cell array are user specified
                    % the first element, which was the function handle.
                    args = {src event};
                    args = [args callback(2:end)];

                    % Invoke the callback function passing any extra arguments
                    % along with the call.
                    feval(funcHandle, args{:});
                end
                
            catch ex

                % Create a new error 
                exception.identifier = ex.identifier;
                exception.message = ex.message;
                
                % Only keep the top-most stack that tells the user where
                % the error is in his code.
                % The stacks below it only show internal code that is not
                % useful to the user
                exception.stack = ex.stack(1);
                
                % Throw the new error
                error(exception);
                
            end
        end
    end
end