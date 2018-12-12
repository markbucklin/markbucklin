function [objGC, objTD, R] = runfp_withalignment()
%		>> [objGC, objTD, R] = runfp_withalignment()

R = [];

try
	% TD-TOMATO (STATIC)
	uiwait(msgbox('Load TD-Tomato (cholinergic) data first','modal'))
	objTD = TiffLoaderFP;
	objTD = checkInput(objTD);
	objTD = loadInput(objTD);
	
	objTD = cast(objTD, @HomomorphicLocalContrastEnhancerFP);
	objTD.backgroundFrameSpan = 1;
	objTD = initialize(objTD);
	objTD = run(objTD);
	
	% 	[objTD, ~, ~] = motionCorrectFluoProObjData(objTD);
	
	
	% GCAMP (DYNAMIC)
	uiwait(msgbox('Now load Gcamp Data','modal'))
	objGC = TiffLoaderFP;
	objGC = checkInput(objGC);
	objGC = loadInput(objGC);
	
	objGC = cast(objGC, @HomomorphicLocalContrastEnhancerFP);
	objGC.backgroundFrameSpan = 1;
	objGC = initialize(objGC);
	objGC = run(objGC);
	
	% MOTION CORRRECTION (SCICADELIC PATCH)
	objGC = motionCorrectFluoProObjData(objGC);
	objGC= hybridMedianFiltFluoProObjData(objGC);
	
	
	
	
	
	objGC = cast(objGC, @BackgroundRemover);
	objGC = initialize(objGC);
	objGC = run(objGC);
	
	objGC = cast(objGC, @VideoRescaler);
	objGC.outputDataType = 'uint8';
	objGC = initialize(objGC);
	objGC = run(objGC);
	
	
	
	
% 	% CORRECT ANY GCAMP-TDTOMATO MISALIGNMENT (TODO)
	try
% 		% REGISTER TOMATO
		moving = mean(objTD.data(:,:,1:90),3);
		moving = expnormalized(moving);
		fixed = mean(objGC.data(:,:,1:20:end),3);
		fixed = expnormalized(fixed);
		[movingPoints,fixedPoints] = cpselect(moving, fixed, 'wait', true);
        tform = fitgeotrans(movingPoints,fixedPoints, 'similarity');
        tdImage = imwarp(moving,tform.T, 'OutputView',imref2d(size(fixed)));
        %         tform = cp2tform(movingPoints,fixedPoints, 'nonreflective similarity');
        %         tdImage = imtransform(moving,tform, 'bicubic', 'size',size(fixed));
        
	catch

	end
% 	
% 	% WRITE TO MP4 TODO
% 	frameSplitFactor = ceil(GB(objGC.data) / 10);
% 	% 	k = 1;
% 	% 	while k<=frameSplitFactor
% 	if frameSplitFactor > 1
% 		firstFrame2Write = 1;		
% 		lastFrame2Write = floor(size(objGC.data,3)/frameSplitFactor);
% 		videoData = objGC.data(:,:, firstFrame2Write:lastFrame2Write);
% 		saveData2Mp4(videoData);
% 	else
% 		saveData2Mp4(objGC.data)
% 	end
% 	
	
	
	% COME BACK TO TD-TOMATO MISALIGNMENT CORRECTION
% 	tform = fitgeotrans(movingPoints, fixedPoints, 'similarity');
	
	
	
	
	% ROI GENERATION
	objGC = cast(objGC, @RoiGenerator);
	objGC = initialize(objGC);
	objGC = run(objGC);
	[objGC,R] = finalize(objGC);
	set(R,'FrameSize',objGC.frameSize);
	R = reduceSuperRegions(R);
	
	expName = objGC.dataSetName;
	save(['ROI-NoTrace ',expName,' .mat'],'R')
	Fbg = expnormalized(single(stackMax(objGC.postSample)));
	
	makeTraceFromVid(R,objGC.data);
	save(['ROI ',expName,' .mat'],'R','Fbg');
	set(R,'transparency',.9)
	R.showAsOverlay(Fbg);
	brighten(h.fig, .9)
	ch = objGC.classHistory;
	save(['ClassHistory ',expName,' .mat'],'ch', '-v6');
	
	if nargout < 3
		assignin('base','R',R)
		if nargout < 2
			assignin('base','objTD',objTD)
			if nargout < 1
				assignin('base','objGC',objGC)
			end
		end
	end
	
catch me
	err = getReport(me);
	assignin('base','err',err);
	%    assignin('base','obj_err',obj);
end