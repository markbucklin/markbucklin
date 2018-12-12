classdef (CaseInsensitiveProperties, TruncatedProperties) ...
	TiffFileSource ...
	< ignition.dataflow.DataflowProcessor




% CONFIGURATION
	properties
		FileInputObj @ignition.io.FileWrapper
		ParseFrameInfoFcn @function_handle
	end
	
	% CONTROL
	properties
		FirstFrameIdx		
		LastFrameIdx
		NumFramesPerRead
		NextFrameIdx
	end
	
	% STATE
	properties (SetAccess = ?ignition.core.Handle)
		StreamFinishedFlag @logical scalar = false
		CurrentFrameIdx
	end
	



	methods
		function obj = TiffFileSource(varargin)
			
			obj = obj@ignition.dataflow.DataflowProcessor(varargin{:});
			
			
			configFcn = @ignition.io.tiff.configureTiffFileStream;
			initFcn = @ignition.io.tiff.initializeTiffFileStream;
			
			% TODO -> move to DataFlowProcessor constructor
			obj.ConfigureTask = ignition.core.Task(configFcn);
			obj.LinkList = [obj.LinkList,...
				link(obj.ConfigurationInterface.PropertyList , obj.ConfigureTask.Input)];
			
			obj.InitializeTask = ignition.core.Task(initFcn);
			obj.LinkList = [obj.LinkList,...
				link(obj.ConfigureTask.Output , obj.InitializeTask.Input)];
			
			
			
			fcn.GenNextIdx = @ignition.io.tiff.preUpdateTiffFileStream;
			fcn.PullIdxFromStruct = @(control) control.NextFrameIdx;
			fcn.ReadFrames = @ignition.io.tiff.readTiffFileStream;
			fcn.Buffer = @(f)write(obj.OutputStream, f);
			
			fld = fields(fcn);
			for k=1:numel(fld)
				tsk.(fld{k}) = ignition.core.Task( fcn.(fld{k}) );
			end
			
			tasklink = obj.LinkList;
			tasklink = [tasklink, link( obj.InitializeTask.Output(1), tsk.ReadFrames.Input(1) )];
			tasklink = [tasklink, link( obj.InitializeTask.Output(2), tsk.GenNextIdx.Input(1) )];
			% link -> state
			% GEN-IDX: [control] = preupdate(control)
			tasklink = [tasklink, link( tsk.GenNextIdx.Output(1), tsk.PullIdxFromStruct.Input(1) )];
			% PULL-IDX: [idx] = getfrom(control)
			tasklink = [tasklink, link( tsk.PullIdxFromStruct.Output(1), tsk.ReadFrames.Input(2) )];
			% READ-TIFF: [F, finflag, idx] = readTiffFileStream( config, idx)
			tasklink = [tasklink, link( tsk.ReadFrames.Output(1) , tsk.Buffer.Input(1) )];
			% LOOP BACK -> GenNextIdx
			%tasklink = [tasklink, link( tsk.GenNextIdx.Output(1), tsk.GenNextIdx.Input(1) )];
			obj.LinkList = tasklink;
			
			obj.TaskList = [tsk.GenNextIdx, tsk.PullIdxFromStruct, tsk.ReadFrames, tsk.Buffer];
			
			
		end
	end






end

















