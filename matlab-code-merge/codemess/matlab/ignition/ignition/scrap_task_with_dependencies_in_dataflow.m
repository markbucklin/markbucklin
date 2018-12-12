
import ignition.io.*
import ignition.io.tiff.*
import ignition.core.*
import ignition.dataflow.*
import ignition.core.type.*



%  --> taskObj = Task( @fcn, numIn, numOut);
tConfig = Task( @configureTiffFileStream);% , 2, 1);
tInit = Task( @initializeTiffFileStream);% , 1, 1);

tPre = Task( @preUpdateTiffFileStream);% , 1, 1); % preupdate
tRead = Task( @readTiffFileStream);% , 1, 4); % read
tPost = Task( @postUpdateTiffFileStream);
tFrame = Task( @buildVideoFrame );









%  --> taskObj = Task( @fcn, numIn, numOut);
% tConfig = Task( @configureTiffFileStream);% , 2, 1);
% tInit = Task( @initializeTiffFileStream);% , 1, 1);
% 
% tGetIdx = Task( @preUpdateTiffFileStream);% , 1, 1); % preupdate
% tRead = Task( @readTiffFileStream);% , 1, 4); % read
% tFrame = Task( @buildVideoFrame );


% 
% stream = FrameBuffer(128, true); % initialcapacity , usefixedcapacity
% 
% % Operation( fcn, numInputs, numOutputs )
% configOp = Operation( @configureTiffFileStream, 2, 1); % could also make this a task with property dependencies
% initOp = Operation( @initializeTiffFileStream, 1, 1);
% 
% O(1) = Operation( @preUpdateTiffFileStream , 1, 1); % preupdate
% O(2) = Operation( @readTiffFileStream , 1, 4); % read
% 
% c2sarray = @(infc) [infc{:}];
% getIdxcaaray = @(infsa) {infsa.FrameNumber};
% % getIdxcaaray(c2sarray(info))
% toVidFrameFcn = @(f,t,info) VideoFrameReference( f, info, t, getIdxcaaray(c2sarray(info)));
% 
% 
% O(3) = Operation( toVidFrameFcn , 3, 1); % To structured/referenced video frame data
% %or T(3) = Operation( @(f,t,info,cache) VideoFrameReference( f, info, t,cache.PriorFrameIdx), 4, 1);
% O3alternative = Operation( @(f,t,info,cache) VideoFrameReference( f, info, t,cache.PriorFrameIdx), 4, 1);
% 
% 
% O(4) = Operation( @(f) write(stream, f) , 1); % preupdate
% 
% 
% for k=1:4
% 	T(k) = Task(O(k));
% end
% 
% 
% T(4).requireOutputFrom(T(3), 1, 1);
% T(3).requireOutputFrom(T(2), 1:3, 1:3);
% T(2).requireOutputFrom(T(1), 1, 1);
% T(1).requireOutputFrom(T(2), 4, 1);
% % need to add requireAnyInput() block
% 
% 
% % TODO: TaskGraph

% TaskGraph
% TaskGraph
% TaskGraph
% TaskGraph
% TaskGraph

% opeval = @(evalargs) feval(evalargs{:});
% opeval(configOp.getFevalArgs);
% T(4).InputDependency.RequiredTaskObj

% T(1).InputDependency.RequiredTaskObj.OperationHandle.getFevalArgs;
% TODO: 'getFevalArgs' function should be coming from the TASK class/object

% need to finish the dependency define above as well -> more options


% fcn = configOp.getEval;










