%% PROPERTIES
% % CONFIGURATION
% 	properties
% 		FileInputObj @ignition.io.FileWrapper
% 		ParseFrameInfoFcn @function_handle
% 	end
% 	
% 	% CONTROL
% 	properties
% 		FirstFrameIdx
% 		NextFrameIdx
% 		LastFrameIdx
% 		NumFramesPerRead		
% 	end
% 	
% 	% STATE
% 	properties (SetAccess = ?ignition.core.Task)
% 		CurrentFrameIdx
% 		StreamFinishedFlag @logical scalar = false
% 	end


% BUFFER
streamOut = ignition.core.FrameBuffer;

%% FUNCTIONS
fcn.Config = @ignition.io.tiff.configureTiffFileStream;
fcn.Init = @ignition.io.tiff.initializeTiffFileStream;
fcn.GenNextIdx = @ignition.io.tiff.preUpdateTiffFileStream;
fcn.PullIdxFromStruct = @(control) control.NextFrameIdx;
fcn.ReadFrames = @ignition.io.tiff.readTiffFileStream;
fcn.Buffer = @(f)write(streamOut, f);
fcn.DisplayState = @(flag,idx) fprintf('CurrentFrameIdx: %d\nStreamFinishedFlag: %d\n\n',...
	idx(end), flag);


%% TASKS
fld = fields(fcn);
for k=1:numel(fld)
	tsk.(fld{k}) = ignition.core.Task( fcn.(fld{k}) );
end


%% LINK I/O
tasklink = ignition.core.tasks.TaskLink.empty();

%  CONFIG: [config] = configfcn(fname,parsefcn)   (todo -> TaskInterface)
% tsk.Config.Input(1).Data = ignition.io.FileWrapper.empty;
% tsk.Config.Input(2).Data = @ignition.io.tiff.parseHamamatsuTiffTag;
interface.prop(1) = ignition.core.tasks.TaskIO();
interface.prop(1).Data =  ignition.io.FileWrapper.empty;
interface.prop(2) = ignition.core.tasks.TaskIO();
interface.prop(2).Data = @ignition.io.tiff.parseHamamatsuTiffTag;
tasklink = [tasklink, link( interface.prop(1), tsk.Config.Input(1) )];
tasklink = [tasklink, link( interface.prop(2), tsk.Config.Input(2) )];


tasklink = [tasklink, link( tsk.Config.Output(1) , tsk.Init.Input(1) )];
% INIT: [config,control,state] = init(config)
tasklink = [tasklink, link( tsk.Init.Output(1), tsk.ReadFrames.Input(1) )];
tasklink = [tasklink, link( tsk.Init.Output(2), tsk.GenNextIdx.Input(1) )];
% link -> state
% GEN-IDX: [control] = preupdate(control)
tasklink = [tasklink, link( tsk.GenNextIdx.Output(1), tsk.PullIdxFromStruct.Input(1) )];
% PULL-IDX: [idx] = getfrom(control)
tasklink = [tasklink, link( tsk.PullIdxFromStruct.Output(1), tsk.ReadFrames.Input(2) )];
% READ-TIFF: [F, finflag, idx] = readTiffFileStream( config, idx)
tasklink = [tasklink, link( tsk.ReadFrames.Output(1) , tsk.Buffer.Input(1) )];
% BUFFER: write(F)
tasklink = [tasklink, link( tsk.ReadFrames.Output(2:3) , tsk.DisplayState.Input(1:2) )];
% DISPLAY

% LOOP BACK -> GenNextIdx
tasklink = [tasklink, link( tsk.GenNextIdx.Output(1), tsk.GenNextIdx.Input(1) )];

taskpipe = [tsk.GenNextIdx, tsk.PullIdxFromStruct, tsk.ReadFrames, tsk.Buffer, tsk.DisplayState];









% % CONFIG
% tConfig = ignition.core.Task( @ignition.io.tiff.configureTiffFileStream);
% configObj = ignition.core.TaskInterface.buildFromPropTag( obj, 'CONFIGURATION', tConfig);
% link( tConfig.Input(1), configObj.PropertyMap('FileInputObj') )
% link( tConfig.Input(2), configObj.PropertyMap('ParseFrameInfoFcn'))
% 
% stateFcn = @ignition.io.tiff.postUpdateTiffFileStream;
% 
% % import ignition.io.*
% % import ignition.io.tiff.*
% % import ignition.core.*
% 
% obj = ignition.io.tiff.TiffReaderTask;
% 
% % CONFIG
% tConfig = ignition.core.Task( @ignition.io.tiff.configureTiffFileStream);
% configObj = ignition.core.TaskInterface.buildFromPropTag( obj, 'CONFIGURATION', tConfig);
% link( tConfig.Input(1), configObj.PropertyMap('FileInputObj') )
% link( tConfig.Input(2), configObj.PropertyMap('ParseFrameInfoFcn'))
% % link( tConfig.Output, configObj)
% 
% % INIT
% tInit = ignition.core.Task( @ignition.io.tiff.initializeTiffFileStream);
% 
% % NEXT-IDX
% tNext = ignition.core.Task( @ignition.io.tiff.preUpdateTiffFileStream);
% tIdx = ignition.core.Task( @(control) control.NextFrameIdx);
% 
% 
% % STATE DISPLAY
% stateFcn = @(s) fprintf('CurrentFrameIdx: %d\nStreamFinishedFlag: %d\n\n',...
% 	s.CurrentFrameIdx(end), s.StreamFinishedFlag);
% tState = ignition.core.Task(stateFcn);
% 
% % CONTROL & STATE TASK-DATA UPDATE/STORAGE OBJECTS
% controlObj = ignition.core.TaskInterface.buildFromPropTag( obj, 'CONTROL', tNext);
% stateObj = ignition.core.TaskInterface.buildFromPropTag( obj, 'STATE', tState);
% 
% % LINK INIT
% % link( tInit.Input(1), configObj)
% link( tInit.Input(1), tConfig.Output(1) )
% link( tInit.Output(1), configObj)
% %link( tInit.Output(2), controlObj)
% %link( tInit.Output(3), stateObj)
% 
% 
% 
% link(tInit.Output(2) , tIdx.Input(1));
% 
% %link( tIdx.Output(1) , tNext.Input(
% 
% %link( tIdx.Input(1), controlObj.PropertyMap('NextFrameIdx') )
% 
% 
% 
% %link( controlObj.PropertyMap('NextFrameIdx'), tIdx.Input(1) )
% 
% % READ
% tRead = ignition.core.Task( @ignition.io.tiff.readTiffFileStream);
% %link( tRead.Input(1), configObj)
% link( tRead.Input(1), tInit.Output(1) )
% link( tRead.Input(2), tIdx.Output(1))
% link( tRead.Output(1), obj.Input(1)) % -> bufer
% 
% link( tRead.Output(2), stateObj.PropertyMap('StreamFinishedFlag') );
% link( tRead.Output(3), stateObj.PropertyMap('CurrentFrameIdx') );
% 
% %link( tRead.Input(2), tNext.Output(1))
% %link( tNext.Output(1), obj.Input(1))
% %link( tNext.Output(2), findobj(obj.State.PropertyList, 'PropertyName','StreamFinishedFlag'))
% %link( tNext.Output(3), findobj(obj.State.PropertyList, 'PropertyName','CurrentFrameIdx'))
% 
% 
% 
% 
% 
% 
% %tNext = ignition.core.Task( @ignition.shared.getNextIdx );
% % link( tNext.Input(1), findobj(obj.Control.PropertyList, 'PropertyName','NextFrameIdx'))
% % link( tNext.Input(2), findobj(obj.Control.PropertyList, 'PropertyName','NumFramesPerRead'))
% % link( tNext.Input(3), findobj(obj.Control.PropertyList, 'PropertyName','LastFrameIdx'))
% % link( tNext.Output(1), findobj(obj.Control.PropertyList, 'PropertyName','NextFrameIdx'))
% % link( tNext.Output(2), findobj(obj.State.PropertyList, 'PropertyName','StreamFinishedFlag'))
