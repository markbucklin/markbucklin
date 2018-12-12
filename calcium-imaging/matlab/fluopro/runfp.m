function [obj,R] = runfp()

R = [];

try
	% TD-TOMATO (STATIC)
	msgbox('Load TD-Tomato (cholinergic) data first','modal')
	objTD = TiffLoaderFP;
	objTD = checkInput(objTD);
	obTD = loadInput(objTD);
	
	objTD = cast(obj, @HomomorphicLocalContrastEnhancerFP);
	objTD = initialize(objTD);
	objTD = run(objTD);		
	
	[objTD, UxyTD, scTD] = motionCorrectFluoProObjData(objTD);
	
	 
	 % GCAMP (DYNAMIC)
	msgbox('Now load Gcamp Data','modal')
   obj = TiffLoaderFP;
   obj = checkInput(obj);
   obj = loadInput(obj);
   
   obj = cast(obj, @HomomorphicLocalContrastEnhancerFP);
	 obj = initialize(obj);
	 obj = run(obj);	 	
	 
	 
	 % CORRECT ANY GCAMP-TDTOMATO MISALIGNMENT (TODO)
	 % REGISTER TOMATO
	 % fixed = scTD.Mean;
	 % fixed = expnormalized(fixed);
	 % 	 % fixed = fixed./ max(fixed(:));
	 % 	 % fixed = fixed + mean(Fgcexp,3);
	 % moving = obj.;
	 % % [optimizer, metric] = imregconfig('multimodal');
	 % % tform = imregtform(moving, fixed, 'similarity', optimizer, metric);
	 % % FtdFixed = imwarp(moving,tform,'OutputView',imref2d(size(fixed)));
	 % [moving_out,fixed_out] = cpselect(moving, fixed, 'wait', true);
	 % cp = cpselect(moving, fixed)
	 
	 % MOTION CORRRECTION (SCICADELIC PATCH)
	 [obj, Uxy, scGcamp] = motionCorrectFluoProObjData(obj);
	 obj= hybridMedianFiltFluoProObjData(obj);	 	 	
    
	 
	 
	 
	 
   obj = cast(obj, @BackgroundRemover);
   obj = initialize(obj);
   obj = run(obj);
   
   obj = cast(obj, @VideoRescaler);
   obj.outputDataType = 'uint8';
   obj = initialize(obj);
   obj = run(obj);
   
	 % TODO
	 % 	 saveData2Mp4(obj.data)
	 
   obj = cast(obj, @RoiGenerator);
   obj = initialize(obj);
   obj = run(obj);
   [obj,R] = finalize(obj);
	 set(R,'FrameSize',obj.frameSize);
   R = reduceSuperRegions(R);
	 
	 expName = obj.dataSetName;
	 save(['ROI-NoTrace ',expName,' .mat'],'R')
	 Fbg = gemanmcclure(stackMax(obj.postSample));
   
   makeTraceFromVid(R,obj.data);
   save(['ROI ',expName,' .mat'],'R')
	 set(R,'transparency',.9)
	 h = R.showAsOverlay(Fbg);
	 brighten(h.fig, .8)
   ch = obj.classHistory;
   save(['ClassHistory ',expName,' .mat'],'ch', '-v6');
   
   if nargout < 2
	  assignin('base','R',R)
	  if nargout < 1
		 assignin('base','obj',obj)
	  end
   end
   
catch me
   err = getReport(me);
	 assignin('base','err',err);
	 %    assignin('base','obj_err',obj);
end