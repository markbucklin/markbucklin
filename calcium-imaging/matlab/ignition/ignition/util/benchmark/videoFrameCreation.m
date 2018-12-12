function [benchTimeMillis,obj,objRef,objVal] = videoFrameCreation(f,info,t,idx)
%{
         valindividual: 0.7363
              valbatch: 0.3726
    valbatchcellcatmix: 0.4251
       valbatchcatonly: 1.7085
         refindividual: 0.5439
              refbatch: 0.0937 ***
    refbatchcellcatmix: 0.1490
       refbatchcatonly: 1.4165
            valfromref: 0.5523
            reffromval: 0.0882 ***


         valindividual: 1.0051
              valbatch: 0.7155
    valbatchcellcatmix: 0.8303
       valbatchcatonly: 2.5992
         refindividual: 0.6021
              refbatch: 0.2775 ***
    refbatchcellcatmix: 0.3679
       refbatchcatonly: 1.8478
            valfromref: 0.5736
            reffromval: 0.0924 ***

%}


% bestTime = inf;

N = 1000;
arg.data = cell(1,N);
arg.info = cell(1,N);
arg.timestamp = cell(1,N);
arg.idx = cell(1,N);


for k=1:N
	arg.data{k} = f(:,:,1,1)+k; 
end
for k=1:N
	arg.info{k} = info(1); arg.info{k}.FrameNumber=k; 
end
for k=1:N
	arg.timestamp{k} = t(1)+.02;
end
for k=1:N
	arg.idx{k} = idx(1)+k;
end

argsInCell = {arg.data,arg.info,arg.timestamp,arg.idx};
argsInCat = {cat(4,arg.data{:}),cat(1,arg.info{:}),cat(1,arg.timestamp{:}),cat(1,arg.idx{:}) };


% VIDEO-FRAME VALUE CLASS
tic, 
for k=1:N
	obj(k) = ignition.core.type.VideoFrame(arg.data{k},arg.info{k},arg.timestamp{k},arg.idx{k});
end
benchTimeMillis.valindividual = 1000*toc/N;
disp(class(obj))
clear obj
fprintf('VideoFrame Creation (individual-construction):\n\t%03.4g ms\n', benchTimeMillis.valindividual)

tic
obj = ignition.core.type.VideoFrame(arg.data,arg.info,arg.timestamp,arg.idx);
benchTimeMillis.valbatch = 1000*toc/N;
clear obj
fprintf('VideoFrame Creation (batch-construction):\n\t%03.4g ms\n',benchTimeMillis.valbatch)

tic
obj = ignition.core.type.VideoFrame(argsInCell{1}, argsInCat{2:end});
benchTimeMillis.valbatchcellcatmix = 1000*toc/N;
clear obj
fprintf('VideoFrame Creation (cell-concatenated mix):\n\t%03.4g ms\n',benchTimeMillis.valbatchcellcatmix)

tic
obj = ignition.core.type.VideoFrame(argsInCat{:});
benchTimeMillis.valbatchcatonly = 1000*toc/N;
clear obj
fprintf('VideoFrame Creation (concatenated inputs only):\n\t%03.4g ms\n',benchTimeMillis.valbatchcatonly)



% VIDEO-FRAME REFERENCE (HANDLE)
tic, 
for k=1:N
	obj(k) = ignition.core.type.VideoFrameReference(arg.data{k},arg.info{k},arg.timestamp{k},arg.idx{k});
end
benchTimeMillis.refindividual = 1000*toc/N;
clear obj
fprintf('VideoFrameReference Creation (individual-construction):\n\t%03.4g ms\n',benchTimeMillis.refindividual)

tic
obj = ignition.core.type.VideoFrameReference(arg.data,arg.info,arg.timestamp,arg.idx);
benchTimeMillis.refbatch = 1000*toc/N;
clear obj
fprintf('VideoFrameReference Creation (batch-construction):\n\t%03.4g ms\n',benchTimeMillis.refbatch)

tic
obj = ignition.core.type.VideoFrameReference(argsInCell{1}, argsInCat{2:end});
benchTimeMillis.refbatchcellcatmix = 1000*toc/N;
clear obj
fprintf('VideoFrameReference Creation (cell-concatenated mix):\n\t%03.4g ms\n',benchTimeMillis.refbatchcellcatmix)

tic
obj = ignition.core.type.VideoFrameReference(argsInCat{:});
benchTimeMillis.refbatchcatonly = 1000*toc/N;

fprintf('VideoFrameReference Creation (concatenated inputs only):\n\t%03.4g ms\n',benchTimeMillis.refbatchcatonly)



tic
objRef = obj;
objVal = ignition.core.type.VideoFrame(objRef);
benchTimeMillis.valfromref = 1000*toc/N;
fprintf('VideoFrame Creation (copied from video frame reference input):\n\t%03.4g ms\n',benchTimeMillis.valfromref)

tic
objRef = ignition.core.type.VideoFrameReference(objVal);
benchTimeMillis.reffromval = 1000*toc/N;
fprintf('VideoFrameReference Creation (copied from video frame value-type input):\n\t%03.4g ms\n',benchTimeMillis.reffromval)





disp(benchTimeMillis)






















