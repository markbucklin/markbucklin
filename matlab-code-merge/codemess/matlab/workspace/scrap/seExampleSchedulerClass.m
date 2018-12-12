classdef seExampleSchedulerClass < matlab.DiscreteEventSystem & ...
        matlab.system.mixin.Propagates & ...
        matlab.system.mixin.CustomIcon & ...
        matlab.system.mixin.SampleTime    
    %seExampleSchedulerClass Simulate scheduler of a multi-core real-time operating system
    %
    
    properties (Nontunable)
        % Number of cores
        NumCores = 1;
        % Scheduling policy
        Policy = 'Priority-based';
        % Number of tasks
        NumTasks = 2;
        % Task periods
        Periods = [1 1];
        % Task priorities
        Priorities = [1 2];
        % Number of segments in each task
        NumSegments = [3 2];
        % Execution durations of each segment
        ExecTimes = {[0.1 0.2 0.1] [0.2 0.1]};
        % Number of mutually exclusive resources
        NumMutex = 0;
        % Use of resources by each task
        UseMutex = {[], []};
    end
    
    properties (DiscreteState)
        CoreStates;
        MutexStates;
        MutexLockedT; % For logging
    end
    
    properties(Constant, Hidden)
        PolicySet = matlab.system.StringSet({'Round robin','Priority-based'});
    end
    
    methods
        function this = seExampleSchedulerClass(varargin)
            setProperties(this, nargin, varargin{:});
        end
    end
    
    methods(Static, Access=protected)        
        function header = getHeaderImpl
            header = matlab.system.display.Header(...
                'seExampleSchedulerClass', ...
                'Title', 'Multicore Scheduler');
        end
        
        function groups = getPropertyGroupsImpl
            firstGroup = matlab.system.display.SectionGroup(...
                'Title', 'General', ...
                'PropertyList', {'NumCores', 'Policy', 'NumTasks', 'Periods', ...
                'Priorities', 'NumSegments', 'ExecTimes', 'NumMutex', 'UseMutex'});
            groups = firstGroup;
        end        
    end
    
    methods (Access=protected)        
        function icon = getIconImpl(~)
            icon = sprintf('Multicore Scheduler');
        end
        
        function num = getNumInputsImpl(obj)
            num = 1;
        end
        
        function num = getNumOutputsImpl(obj)
            num = 1;
        end
        
        function validatePropertiesImpl(obj)
            % Validate 'Number of cores'
            if (obj.NumCores<=0 || floor(obj.NumCores) ~= obj.NumCores)
                error('Parameter ''Number of cores'' must be a positive number with integral value.');
            end
            % Validate 'Number of tasks'
            if (obj.NumTasks<=0 || floor(obj.NumTasks) ~= obj.NumTasks)
                error('Parameter ''Number of tasks'' must be a positive number with integral value.');
            end
        end
        
        function sz = getOutputSizeImpl(obj)
            sz = [1 1];
        end
        
        function dt = getOutputDataTypeImpl(obj)
            dt = 'task';
        end
        
        function cp = isOutputComplexImpl(obj)
            cp = false;
        end
        
        function [sz, dt, cp] = getDiscreteStateSpecificationImpl(obj, name)
            switch name
                case 'CoreStates'
                    sz = [1, max(1, obj.NumCores)];
                case {'MutexStates', 'MutexLockedT'}
                    sz = [1, max(1, obj.NumMutex)];
            end
            dt = 'double';
            cp = false;
        end
        
        function setupImpl(obj)
            % Cross-validate 'Task periods'
            if (obj.NumTasks ~= length(obj.Periods))
                error('Parameter ''Task periods'' must be a vector with its length same as number of tasks.');
            elseif (any(obj.Periods<=0))
                error('Parameter ''Task periods'' must be a vector with positive values.');
            end
            % Cross-validate 'Task priorities'
            if (obj.NumTasks ~= length(obj.Priorities))
                error('Parameter ''Task priorities'' must be a vector with its length same as number of tasks.');
            elseif (any(obj.Priorities<=0) || any(floor(obj.Priorities)~=obj.Priorities))
                error('Parameter ''Task priorities'' must be a vector with positive integral values.');
            end            
            % Cross-validate 'Number of segments in each task'
            if (obj.NumTasks ~= length(obj.NumSegments))
                error('Parameter ''Number of segments in each task'' must be a vector with its length same as number of tasks.');
            elseif (any(obj.NumSegments<=0) || any(floor(obj.NumSegments)~=obj.NumSegments))
                error('Parameter ''Number of segments in each task'' must be a vector with positive integral values.');
            end
            % Cross-validate 'Execution durations of each segment'
            if (~iscell(obj.ExecTimes) || obj.NumTasks~=length(obj.ExecTimes))
                error('Parameter ''Execution durations of each segment'' must be a cell vector with its length same as number of tasks.');
            end
            for i = 1:obj.NumTasks
                ets = obj.ExecTimes{i};
                if obj.NumSegments(i) ~= length(ets)
                    error(['Execution durations for task ' num2str(i) ' must be a vector with the same length as the task''s number of segments']);
                elseif (any(ets)<=0)
                    error(['Execution durations for task ' num2str(i) ' must be a vector with positive values.']);
                end
            end           
            % Cross-validate 'Number of mutually exclusive resources'
            if (obj.NumMutex<0 || floor(obj.NumMutex) ~= obj.NumMutex)
                error('Parameter ''Number of mutually exclusive resources'' must be positive or zero with integral value.');
            end
            % Cross-validate 'Use of resources by each task'
            if (~iscell(obj.UseMutex) || obj.NumTasks~=length(obj.UseMutex))
                error('Parameter ''Use of resources by each task'' must be a cell vector with its length same as number of tasks.');
            end
            for i = 1:obj.NumTasks
                mtx = obj.UseMutex{i};
                if isempty(mtx)
                    continue;
                end
                if any(mtx<=0) || any(mtx>obj.NumMutex) || any(floor(mtx)~=mtx) 
                    error(['In parameter ''Use of resources by each task'', resource use of task ' num2str(i) ' must be a vector with its elements indicating resource indices.']);
                elseif length(mtx) ~= length(unique(mtx))
                    error(['In parameter ''Use of resources by each task'', resource use of task ' num2str(i) ' must be a vector with unique elements']);
                end
            end
            
            % Initialize states
            obj.CoreStates = zeros(1, obj.NumCores);
            obj.MutexStates = zeros(1, max(1, obj.NumMutex));
            obj.MutexLockedT = zeros(1, max(1, obj.NumMutex));
            
            % Initialize figures
            evalin('base', ['seExampleSchedulerLog(1, 15, ' num2str(obj.NumTasks) ...
                ', ' num2str(obj.NumMutex) ', ''' obj.Policy ''', ' num2str(obj.NumCores) ');']);
            for i = 1:obj.NumTasks
                evalin('base', ['seExampleSchedulerLog(2, 0, ' num2str(i) ...
                    ', ' num2str(obj.NumSegments(i)) ', [' num2str(obj.ExecTimes{i}) '], 0);']);
            end
        end
        
        function releaseImpl(obj)
            % Finalize figures
            evalin('base', 'seExampleSchedulerLog(5, 0, 0, 0, 0, 0);');
        end
        
        function [entityTypes] = getEntityTypesImpl(obj)
            entityTypes = obj.entityType('task','task');
        end
        
        function [iTypes, oTypes] = getEntityPortsImpl(obj)
            iTypes = {'task'};
            oTypes = {'task'};
        end
        
        function [storage, I, O] = getEntityStorageImpl(obj)
            switch obj.Policy
                case 'Round robin'
                    storage = obj.queueFIFO('task', 100);
                case 'Priority-based'
                    storage = obj.queuePriority('task', 100, 'priority', 'ascending');
            end
            I = 1;
            O = 1;
        end
        
        function events = setupEventsImpl(obj)
            for id = 1:obj.NumTasks
                events(id) = obj.eventGenerate(1, num2str(id), 0, obj.Priorities(id)); %#ok<*AGROW>
            end
        end
        
        function [entity, events] = generateImpl(obj, storage, entity, tag)
            id = str2double(tag);
            entity.data.id = id;
            entity.data.priority = obj.Priorities(id);
            entity.data.nextSegment = 1;
            entity.data.execTime = obj.ExecTimes{id}(1);
            entity.data.currentCoreID = 0;
            events = obj.eventGenerate(1, num2str(id), obj.Periods(id), obj.Priorities(id));
            if obj.hasFreeCore()
                events = [events obj.eventIterate(1, 'dispatch')];
            end
        end
        
        function [entity, events] = entryImpl(obj, storage, entity, src)
            assert(entity.data.currentCoreID ~= 0);
            events = [];
            obj.releaseCore(entity.data.currentCoreID);
            
            id = entity.data.id;
            if entity.data.nextSegment < obj.NumSegments(id)
                entity.data.nextSegment = entity.data.nextSegment+1;
                entity.data.execTime = obj.ExecTimes{id}(entity.data.nextSegment);
            else
                obj.releaseMutex(id);
                entity.data.nextSegment = -1;
                entity.data.execTime = 0;
                events = obj.eventDestroy();
            end
            
            events = [events obj.eventIterate(storage, 'dispatch')];
        end
        
        function [entity, events, next] = iterateImpl(obj, storage, entity, tag, status)
            events = [];
            if obj.hasFreeCore() && entity.data.nextSegment ~= -1
                if entity.data.nextSegment == 1
                    hasResource = obj.acquireMutex(entity.data.id);
                else
                    hasResource = true;
                end
                if hasResource
                    entity.data.currentCoreID = obj.acquireCore();
                    events = obj.eventForward('output', 1, 0); % Dispatch to a core
                end
            end
            next = obj.hasFreeCore();
        end
    end
    
    methods (Access=private)
        function flag = hasFreeCore(obj)
            flag = any(obj.CoreStates == 0);
        end
        
        function coreID = acquireCore(obj)
            coreID = 0;
            for i = 1:obj.NumCores
                if obj.CoreStates(i) == 0 % Idle
                    coreID = i;
                    obj.CoreStates(i) = 1; % Set to busy
                    break;
                end
            end
            assert(coreID > 0);
        end
        
        function releaseCore(obj, coreID)
            assert(obj.CoreStates(coreID) == 1);
            obj.CoreStates(coreID) = 0;
        end
        
        function flag = acquireMutex(obj, taskId)
            assert(taskId<=obj.NumTasks && taskId>0);
            flag = 1;
            for i = 1:length(obj.UseMutex{taskId})
                if obj.MutexStates(obj.UseMutex{taskId}(i)) == 1
                    flag = 0;
                end
            end
            if flag == 1 % OK to acquire
                for i = 1:length(obj.UseMutex{taskId})
                    mId = obj.UseMutex{taskId}(i);
                    obj.MutexStates(mId) = 1;
                    obj.MutexLockedT(mId) = obj.getCurrentTime();
                end
            end
        end
        
        function releaseMutex(obj, taskId)
            assert(taskId<=obj.NumTasks && taskId>0);
            for i = 1:length(obj.UseMutex{taskId})
                mId = obj.UseMutex{taskId}(i);
                obj.MutexStates(mId) = 0;
                evalin('base', ['seExampleSchedulerLog(4, ' num2str(obj.getCurrentTime()) ', ' num2str(taskId) ...
                    ', 0, ' num2str(obj.MutexLockedT(mId)) ', ' num2str(mId+obj.NumCores) ');']);
            end
        end
    end
end
