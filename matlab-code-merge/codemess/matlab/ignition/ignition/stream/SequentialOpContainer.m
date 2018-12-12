classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible) SequentialOpContainer
% NOT YET IMPLEMENTED (TODO) -> copying from SystemSynchronizer from FrameSynx toolbox	
	
	
	properties (SetAccess = protected)
		FrameData
		FrameTime
		FrameInfo
		FrameIdx
	end
	
	
	
	
	
	
	methods % USER FUNCTIONS
		function register(obj,subSystemObj,varargin)
			switch class(subSystemObj)
				case 'BehaviorSystem'
					if ~any(obj.behaviorSystemObjects == subSystemObj)
						obj.behaviorSystemObjects(numel(obj.behaviorSystemObjects )+1) = subSystemObj;
						obj.allSubSystemObjects{numel(obj.allSubSystemObjects)+1} = subSystemObj;
					end
				case 'CameraSystem'
					if ~any(obj.cameraSystemObjects == subSystemObj)
						obj.cameraSystemObjects(numel(obj.cameraSystemObjects)+1) = subSystemObj;
						obj.allSubSystemObjects{numel(obj.allSubSystemObjects)+1} = subSystemObj;
					end
			end
			if nargin > 2 % (sync arguments)
				for n = 1:numel(varargin)
					switch lower(varargin{n})
						case 'experiment'
							obj.experimentSyncObj =  subSystemObj;
						case 'trial'
							obj.trialSyncObj = subSystemObj;
						case 'frame'
							obj.frameSyncObj = subSystemObj;
						otherwise
							warning('SystemSynchronizer:register:InvalidSyncArgument',...
								'Synchronization argument (%s) invalid: use ''experiment'' ''trial'' or ''frame''.\n',...
								varargin{n});
					end
				end
			else
				switch class(subSystemObj)
					case 'BehaviorSystem'
						if isempty(obj.experimentSyncObj)
							qstring = sprintf('Do you want to synchronize Experiment-Starts with this BehaviorSystem: %s',...
								subSystemObj.systemName);
							if strcmpi('yes',questdlg(qstring,'Experiment-Start Synchronization'))
								obj.experimentSyncObj = subSystemObj;
							end
						end
						if isempty(obj.trialSyncObj)
							qstring = sprintf('Do you want to synchronize Trial-Starts with this BehaviorSystem: %s',...
								subSystemObj.systemName);
							if strcmpi('yes',questdlg(qstring,'Trial-Start Synchronization'))
								obj.trialSyncObj = subSystemObj;
							end
						end
					case 'CameraSystem'
						if isempty(obj.frameSyncObj)
							qstring = sprintf('Do you want to synchronize Frames with this CameraSystem: %s',...
								subSystemObj.systemName);
							if strcmpi('yes',questdlg(qstring,'Frame Synchronization'))
								obj.frameSyncObj = subSystemObj;
							end
						end
				end
			end
			obj.updateSystemList();
		end
		function synchronize(obj)
			obj.updateSavePath();
			obj.behaviorSystemObjects = obj.behaviorSystemObjects(isvalid(obj.behaviorSystemObjects));
			obj.cameraSystemObjects = obj.cameraSystemObjects(isvalid(obj.cameraSystemObjects));
			% Synchronize Behavior System Objects with Primary Camera Frames
			if ~isempty(obj.behaviorSystemObjects)
				set(obj.behaviorSystemObjects,'frameSyncObj',obj.frameSyncObj);
			end
			% Synchronize any Extra Behavior System Objects with Master
			if any(obj.behaviorSystemObjects ~= obj.experimentSyncObj)
				slave_behave = obj.behaviorSystemObjects(...
					obj.behaviorSystemObjects ~= obj.experimentSyncObj);
				set(slave_behave,'experimentSyncObj',obj.experimentSyncObj);
			end
			if any(obj.behaviorSystemObjects ~= obj.trialSyncObj)
				slave_behave = obj.behaviorSystemObjects(...
					obj.behaviorSystemObjects ~= obj.trialSyncObj);
				set(slave_behave,'trialSyncObj',obj.experimentSyncObj);
			end
			% Synchronize Cameras with Experiment start/stop and Trial Start
			if ~isempty(obj.cameraSystemObjects)
				set(obj.cameraSystemObjects,'experimentSyncObj',obj.experimentSyncObj);
				set(obj.cameraSystemObjects,'trialSyncObj',obj.trialSyncObj);
			end
			if any(obj.cameraSystemObjects ~= obj.frameSyncObj)
				slave_cam = obj.cameraSystemObjects(...
					obj.cameraSystemObjects ~= obj.frameSyncObj);
				set(slave_cam,'frameSyncObj',obj.frameSyncObj);
			end
			obj.updateSystemList();
			obj.updateListeners();
		end
		function start(obj)
			% Create Default Systems if Empty and Synchronize
			obj.updateSystemList();
			if isempty(obj.frameSyncObj)
				if isempty(obj.cameraSystemObjects)
					obj.cameraSystemObjects = CameraSystem;
				end
				obj.register(obj.cameraSystemObjects(1),'frame');
			end
			if isempty(obj.experimentSyncObj) || isempty(obj.trialSyncObj)
				if isempty(obj.behaviorSystemObjects)
					obj.behaviorSystemObjects = BehaviorSystem;
				end
				obj.register(obj.behaviorSystemObjects(1),'experiment','trial');
			end
			obj.updateSystemList();
			% Update Properties and Synchronize
			if isempty(obj.savePath)
				obj.updateSavePath();
			end
			if ~isdir(obj.savePath)
				mkdir(obj.savePath);
			end
			for n = 1:numel(obj.allSubSystemObjects)
				subsys = obj.allSubSystemObjects{n};
				subsys.savePath = obj.savePath;
				start(obj.allSubSystemObjects{n})
			end
			obj.synchronize();
			% Check if SubSystems are Ready -> Change Experiment Status
			if ~obj.areSystemsReady();
				notify(obj,'SystemSyncError');
			end
		end
		function stop(obj)
			obj.updateSystemList();
			for n = 1:numel(obj.allSubSystemObjects)
				subsys = obj.allSubSystemObjects{n};				
				stop(subsys)
			end
			notify(obj,'SystemSyncStop');
		end
	end
	methods
		function updateSystemList(obj)
			if ~isempty(obj.behaviorSystemObjects)
				obj.behaviorSystemObjects = obj.behaviorSystemObjects(isvalid(obj.behaviorSystemObjects));
			end
			if ~isempty(obj.cameraSystemObjects)
				obj.cameraSystemObjects = obj.cameraSystemObjects(isvalid(obj.cameraSystemObjects));
			end
			nvalid = 0;
			validsystems = cell.empty;
			validnames = cell.empty;
			for n = 1:numel(obj.allSubSystemObjects)
				if isvalid(obj.allSubSystemObjects{n})
					nvalid = nvalid+1;
					validsystems{nvalid} = obj.allSubSystemObjects{n};
					validnames{nvalid} = get(validsystems{nvalid},'systemName');
				end
			end
			obj.allSubSystemObjects = validsystems;
			obj.systemNames = validnames;
		end
		function updateListeners(obj) % could be useful for this class and systems in an abstract class
			if ~isempty(obj.experimentSyncObj)
				if ~isempty(obj.experimentStateListener)
					obj.experimentStateListener.Enabled = false;
				end
				if ~isempty(obj.trialStateListener)
					obj.trialStateListener.Enabled = false;
				end
				obj.trialStateListener = addlistener(obj.trialSyncObj,...
					'NewTrial',@(src,evnt)trialStateChangeFcn(obj,src,evnt));
				obj.trialStateListener.Enabled = true;
				obj.experimentStateListener = addlistener(obj.experimentSyncObj,...
					'ExperimentStart',@(src,evnt)experimentStateChangeFcn(obj,src,evnt));
				addlistener(obj.experimentSyncObj,...
					'ExperimentStop',@(src,evnt)experimentStateChangeFcn(obj,src,evnt));
				obj.experimentStateListener.Enabled = true;
			end
			if ~isempty(obj.frameSyncObj)
				obj.frameSyncListener = addlistener(obj.frameSyncObj,...
					'FrameAcquired',@(src,evnt)frameAcquiredFcn(obj,src,evnt));
				obj.frameSyncListener.Enabled = true;
			end
		end
	end
	methods (Hidden) % SYNC-FUNCTIONS
		function experimentStateChangeFcn(obj,~,~)
			switch evnt.EventName
				case 'ExperimentStart'
					obj.experimentStatus = 'Recording';
				case 'ExperimentStop'
					obj.experimentStatus = 'Stopped';
			end
		end
		function trialStateChangeFcn(obj,~,~)
			try
				obj.trialNumber = obj.trialSyncObj.stimulusPresentationObj.currentTrialNumber;
			catch
				obj.trialNumber = obj.trialSyncObj.currentTrialNumber;
			end
		end
		function frameAcquiredFcn(obj,~,~)
			persistent tlastframe
			obj.framesAcquired = obj.framesAcquired+1;
			if isempty(tlastframe)
				tlastframe = tic;
				return
			end
			obj.frameRate = 1/toc(tlastframe);
		end
	end
	
	
end
