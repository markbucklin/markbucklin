classdef TimeoutTimer < handle
    %TimeoutTimer Execute callback when time duration expires.
    %  TimeoutTimer executes a callback function when a specific time
    %  duration elapses.  The counter may be started, restarted and
    %  stopped, or the time duration changed, at any time.
    %
    %  TimeoutTimer(@fcn) sets the TimeoutFcn property to the specified
    %  function named fcn.  The function is called with two arguments: a
    %  handle to the TimeoutTimer object, and an event structure.
    %
    %  TimeoutTimer(@fcn,D) specifies the value of the Duration property.
    %
    %  TimeoutTimer properties
    %    Duration   - Time duration in seconds.
    %    TimeoutFcn - Callback function executed when time duration expires.
    %
    %  TimeoutTimer methods
    %    start     - Start timer counting down, or restart timer.
    %    stop      - Stop timer; prevents callback from executing.
    %    delete    - Destroy TimeoutTimer explicitly when done.
    %    isRunning - True if timer is running.
    %
    %  Example uses
    %    Watchdog Timer
    %      The timer counts down, with the intent that start gets called
    %      again prior to the time duration expiring.  If start fails to
    %      get called in time, the timeout callback executes.
    
    properties
        Duration = 1.0  % Timeout duration in seconds
        TimeoutFcn = [] % Function handle with syntax fcn(obj,event)
    end
    
    properties (Hidden) % (Access = private)
        hTimer
    end
    
    properties (Access = private)
        pShowAfterTic
    end
    
    methods
        function w = TimeoutTimer(varargin)
            createTimer(w);
            setProps(w,varargin{:});
        end
        
        function delete(w)
            % Destroy timer object
            
            ht = w.hTimer;
            if ~isempty(ht) && isvalid(ht)
                delete(ht);
            end
            w.hTimer = [];
        end
        
        function start(w,delta)
            % Begin timer countdown, or restart timer if running.
            %
            % Optionally pass a delta-time to ADD to current timer.  Used
            % to incorprate an elapsed time offsets into timer period.
            
            % If Duration is infinite, don't start timer
            if isinf(w.Duration)
                w.pShowAfterTic = tic;
            else
                if nargin > 1
                    updateDuration(w,delta); % stops timer
                else
                    updateDuration(w); % stops timer
                end
                w.pShowAfterTic = tic;
                if ~isRunning(w)
                    start(w.hTimer);
                end
            end
        end
        
        function e = elapsed(w)
            % Elapsed time since start called.
            
            t = w.pShowAfterTic;
            if isempty(t)
                e = [];
            else
                e = toc(t);
            end
        end
        
        function y = isRunning(w)
            % True if TimeoutTimer is running.
            
            ht = w.hTimer;
            if ~isempty(ht) && isvalid(ht)
                y = strcmpi(ht.Running,'on');
            else
                y = false;
            end
        end
        
        function wasRunning = stop(w)
            % Requests timer to stop, but does not wait for it to halt.
            
            wasRunning = isRunning(w);
            if wasRunning
                stop(w.hTimer);
            end
        end
        
        function wasRunning = stopAndWait(w)
            % Requests timer to stop, and waits for timer to halt.
            
            wasRunning = stop(w);
            if wasRunning
                waitfor(w.hTimer);
            end
        end
        
        function set.Duration(w,val)
            validateattributes(val,{'double'}, ...
                {'scalar','real','>=',0}, ...
                'TimeoutTimer','Duration');
            w.Duration = val;
            updateDuration(w);
        end
        
        function set.TimeoutFcn(w,val)
            % Can update timeout function while timer is running
            w.TimeoutFcn = val;
        end
    end
    
    methods (Access = private)
        function setProps(w,fcn,d)
            % Set TimeoutFcn and Duration, if specified
            if nargin > 1
                w.TimeoutFcn = fcn;
            end
            if nargin > 2
                w.Duration = d;
            end
        end
        
        function createTimer(w)
            % Create timer instance
            
            ht = timer;
            w.hTimer = ht;
            ht.Name = 'TimeoutTimer';
            ht.BusyMode = 'drop';
            ht.ExecutionMode = 'singleShot';
            ht.ObjectVisibility = 'off';
            
            % Embedding of the object "w" into these anonymous fcns prevents
            % the delete method from firing.
            ht.TimerFcn = @(t,ev)localTimeoutFcn(w,ev);
            ht.ErrorFcn = @(t,ev)localErrorFcn(w,ev);
            
            updateDuration(w);
        end
        
        function updateDuration(w,delta)
            % Change period of underlying timer.
            % Stops timer first.
            %
            % Optionally add delta time to Duration, typically used to
            % correct for elapsed time offsets.
            
            stopAndWait(w);
            ht = w.hTimer;
            if ~isempty(ht) && isvalid(ht)
                if isinf(w.Duration)
                    ht.StartDelay = 0; % set to something simple
                else
                    if nargin > 1
                        % Add delta time to timer
                        dly = max(0,round((w.Duration+delta)*1000)/1000);
                        ht.StartDelay = dly;
                    else
                        ht.StartDelay = round(w.Duration*1000)/1000;
                    end
                end
            end
        end
        
        function localTimeoutFcn(w,ev)
            
            % Even though callback fired, underlying timer may be running
            % and that may interfere with subsequent operations from caller
            % during their callback, such as reconfiguring this
            % TimeoutTimer Duration, which ultimately tries to reconfigure
            % the underlying timer.  That will fail if underlying timer is
            % running.  So we stop it here.
            %stopAndWait(w);
            
            fcn = w.TimeoutFcn;
            if isempty(fcn)
                fcn = @defaultTimeoutFcn;
            end
            feval(fcn,w,ev);
        end
        
        function localErrorFcn(w,~)
            
            stopAndWait(w);
            fprintf('Error while executing TimeoutFcn function.\n');
            rethrow(lasterror); %#ok<LERR>
        end
    end
end

function defaultTimeoutFcn(~,~)
% Default callback.
disp('TimeoutTimer expired with no callback function specified.');
end
