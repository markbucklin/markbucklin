classdef (CaseInsensitiveProperties, TruncatedProperties) ...
	TiffReaderTask ...
	< ignition.core.Task
% 	& ignition.core.tasks.Configurable ...
% 	& ignition.core.tasks.Controllable ...
% 	& ignition.core.tasks.Stateful




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
	
	properties
		SubTaskObj @ignition.core.Task
		OutputStream @ignition.core.FrameBuffer
	end



	methods
		function obj = TiffReaderTask(varargin)
			
			streamOut = ignition.core.FrameBuffer;
			fcn = @(f)write(streamOut, f);
			taskArgs = [ {fcn} , varargin];			
			obj = obj@ignition.core.Task(taskArgs{:});
			
			
			configFcn = @ignition.io.tiff.configureTiffFileStream;
			controlFcn = @ignition.io.tiff.preUpdateTiffFileStream;
			stateFcn = @ignition.io.tiff.postUpdateTiffFileStream;
			
			% 			obj = obj@ignition.core.tasks.Configurable(configFcn);
			% 			obj = obj@ignition.core.tasks.Controllable(controlFcn);
			% 			obj = obj@ignition.core.tasks.Stateful(stateFcn);
			
			
					%tBuffer = Task(streamOut)
			% IMPORTS
			% 			import ignition.io.*
			% 			import ignition.io.tiff.*
			% 			import ignition.core.*
			% 			import ignition.dataflow.*
			% 			import ignition.core.type.*
			
			
			obj.OutputStream = streamOut;
			
			
			% CONFIGURATION PROPERTIES (CONFIG-TASK SOURCE)
% 			configProps = {'FileInputObj','ParseFrameInfoFcn'};
% 			%propGrps = getPropertyGroups(obj);
% 			%configProps = propGrps.Configuration;
% 						
% 			%  --> taskObj = Task( @fcn, numIn, numOut);
% 			tConfig = Task( @configureTiffFileStream);% , 2, 1);
% 			tInit = Task( @initializeTiffFileStream);% , 1, 1);
% 			
% 			tPre = Task( @preUpdateTiffFileStream);% , 1, 1); % preupdate
% 			tRead = Task( @readTiffFileStream);% , 1, 4); % read
% 			tPost = Task( @postUpdateTiffFileStream);
% 			tFrame = Task( @buildVideoFrame );
% 			
% 			% DEPENDENCIES
% 			tConfig.bindSourceFromProp(obj, configProps, 1:2);
% 			tInit.bindSource(tConfig); % iInit.requireOutputFrom(tConfig);
% 			
% 			tPre.bindSourceFromLatestOutput( [tInit,tPost]); % ,{1 , 1}, 1)			
% 			tRead.bindSource( tPre );
% 			tPost.bindSource( tPre );
% 			tFrame.bindSource( tRead, 1:4 );
% 			
% 			obj.bindSource(tFrame);
% 
% 			obj.SubTaskObj = [tConfig, tInit, tPre, tRead, tPost, tFrame];
% 			
% 			
			
		end
	end






end

















