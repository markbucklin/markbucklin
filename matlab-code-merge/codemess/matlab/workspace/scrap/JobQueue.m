
%   Copyright 2014 The MathWorks, Inc.

classdef JobQueue < handle
    %JOBQUEUE A class to manage a queue of jobs and process them one after
    %the other.
    %
    % A JOBQUEUE is best used when a collection of jobs needs to be
    % processed asynchronously as part of an UI application. Using a
    % JOBQUEUE can provide better structuring of code than inserting
    % drawnow calls into the processing logic. 
    
    % The assumption made by JOBQUEUE is that an individual job is 
    % uninterruptible. In between processing jobs, other tasks will get an 
    % opportunity to execute. In particular, UI callbacks, and UI refresh 
    % calls. Each job is expected to preserve the invariants of the system.
    % A job may break the system invariant internally, but it should ensure
    % that the invariants hold before it terminates.
    
    % A job should be exception-safe, and should handle all exceptions
    % internally. If an exception escapes from a job, it will be caught by
    % the job-queue and reported as a warning.
    
    % A job can invoke job-queue control methods as part of its execution.
    % In particular, a job can enqueue additional jobs, flush the queue or
    % stop the queue.
    
    properties
        queue = {}
        isLocked = false
        
        jobTimer = []
    end
    
    methods
        function delete(obj)
            obj.stop;
        end
        
        function enqueue(obj, job, front)
            if front
                obj.queue = [{job} obj.queue];
            else
                obj.queue{end+1} = job;
            end
        end
        
        % process a single job. A job is any structure with a run field
        % that can be invoked as a function.
        % If the run method raises an exception, the error is reported 
        % using the Simulink message viewer API as a warning. Job
        % processing continues with the next job in the queue.
        function processOne(obj,~,~)
            if ~obj.isLocked && ~isempty(obj.queue)
                % lock the queue. This will ensure that 
                % jobs are executed one after another, and
                % take care of interrupts by commands like
                % drawnow.
                obj.isLocked = true;
                
                job = obj.queue{1};
                obj.queue = obj.queue(2:end);
                
                try
                    job.run();
                catch err
                    obj.isLocked = false;
                    % Generate a warning message and continue
                    Simulink.output.warning(err);
                end
                obj.isLocked = false;
            end
        end
        
        function start(obj)
            if isempty(obj.jobTimer)
                obj.jobTimer = timer('Name', 'JobQueueTimer',...
                                     'ExecutionMode', 'fixedSpacing',...
                                     'Period', 0.5,...
                                     'ObjectVisibility', 'off',...
                                     'TimerFcn', @obj.processOne);
                                 
                start(obj.jobTimer);
            end
        end
        % Check only for empty timer and not isLocked. Even while a job is
        % processing (queue is locked) a stop request may be picked up due to 
        %drawnows in the sldvrun code. These requests should be processed.
        function stop(obj)
            if ~isempty(obj.jobTimer)
                stop(obj.jobTimer);
                delete(obj.jobTimer);
                obj.jobTimer = [];
            end
        end
        
        function flush(obj)
            obj.queue = {};
        end
    end
end

