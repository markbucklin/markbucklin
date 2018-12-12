classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskIO ...
		< ignition.core.UniquelyIdentifiable ...
		& ignition.core.CustomDisplay ...
		& ignition.core.Handle ...
		& matlab.mixin.Heterogeneous
	
	
	% todo: -> rename Endpoint or TaskEndpoint or DataEndpoint or FunctionalEndpoint
	% implement a FusedEndpoint -> combines two handles bound to two Tasks and replaces with 1
	% implement a ProtectedEndpoint that prevents overwrite
	
	% TASK I/O
	properties (SetObservable,GetObservable)
		IsLinked = false
		IsRequired = false % todo -> call __flag?
	end
	properties (SetAccess=protected)
		TaskObj @ignition.core.Task
	end
	properties (SetObservable,GetObservable)
		Data
	end	
	
	properties (SetAccess=protected)
		Source @ignition.core.tasks.TaskIO
		Target @ignition.core.tasks.TaskIO
		DependentTaskList @ignition.core.Task %todo
	end
	
	
	events
		Empty
		Full
	end
	
	
	
	methods
		% CONSTRUCTOR
		function obj = TaskIO( task )
			% TaskIO - Parent class representing input and output arguments for a Task
			
			if nargin > 0
				obj.TaskObj = task;
			end
			
		end
		
		% LINK A TASK-IO OBJECT TO ANOTHER TO DESIGNATE DATAFLOW
		function tasklink = link( ioA, ioB)
			
			% BOTH INPUTS MUST BE OBJECTS DERIVED FROM THE TASK-IO CLASS
			assert( isa(ioA,'ignition.core.tasks.TaskIO') && isa(ioB,'ignition.core.tasks.TaskIO'))
			
			% DETERMINE DIRECTION OF INTENDED DATAFLOW LINKAGE
			if isa(ioA, 'ignition.core.TaskOutput')
				ioSource = ioA;
				ioTarget = ioB;				
			elseif isa(ioA, 'ignition.core.TaskInput')
				ioTarget = ioA;
				ioSource = ioB;				
			else				
				if isa(ioB, 'ignition.core.TaskOutput')
					ioSource = ioB;
					ioTarget = ioA;
				elseif isa(ioB, 'ignition.core.TaskInput')
					ioSource = ioA;
					ioTarget = ioB;
				else
					warning('Ignition:TaskIO:link:LinkDirectionUnspecified',...
						'Task I/O link direction is unspecified, assuming direction from 1st to 2nd arg')
					ioSource = ioA;
					ioTarget = ioB;
				end				
			end
			
			% CHECK IF TARGET IS NON-SCALAR -> CALL RECURSIVELY
			if ~isscalar(ioTarget)
				assert( numel(ioSource)==numel(ioTarget) )
				for k=1:numel(ioSource)
					tasklink(k) = link( ioTarget(k) , ioSource(k) );
				end
				return
				
			else
				% ASSIGN BIDIRECTIONAL LINK BETWEEN SOURCE & TARGET
				ioSource.Target = [ioSource.Target , ioTarget];
				
				% MANAGE A SECOND SOURCE BEING LINKED TO SINGLE INPUT
				currentSource = ioTarget.Source;
				if ~isempty(currentSource)					
					%ioTarget.Source = [ioTarget.Source , ioSource];
					makeOptional(currentSource); %??? todo??
					ioTarget.Source = [currentSource , ioSource];
					
				else
					ioTarget.Source = ioSource;
					
				end
				
				% RECORD LINK
				ioSource.IsLinked = true;
				ioTarget.IsLinked = true;
				
				% CONSTRUCT TASK-LINK OBJECT TO HANDLE DATA PRODUCTION/CONSUMPTION EVENTS
				tasklink = ignition.core.tasks.TaskLink( ioSource, ioTarget );
				
				% RECORD IN CURRENT TASK GRAPH
				% todo
				
				% STORE LINK TO DOWNSTREAM/DEPENDENT TASK OBJECT
				task = [ioTarget.TaskObj , ioSource.DependentTaskList];
				try
					task = unique(task);
				catch
					id = [task.ID];
					[~,idx,~] = unique(id);
					task = task(idx);
				end
				ioSource.DependentTaskList = task;
				
				% CHANGE DESIGNATION TO REQUIRED
				makeRequired([ioSource(:)' , ioTarget(:)'])
				
			end
			
			
		end
	end
	
	methods (Sealed) % todo -> move to FunctionArgument
		function makeOptional(obj)
			[obj.IsRequired] = deal(false);
		end
		function makeRequired(obj)
			[obj.IsRequired] = deal(true);
		end
	end
	
	
	
	% todo -> implement event.hasListener(getMetaProp(obj,'Data'), 'PostSet')
	
	
	
	
	
	
	
end






