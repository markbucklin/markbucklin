classdef PlayableFigure < hgsetget

	% TODO: NOT YET IMPLEMENTED
	
	properties
		Data
		FrameSize
	end
	
	
	
	
	
	
	methods
		function obj = PlayableFigure(dataInput)
			if nargin < 1
				dataInput = [];
			end
			if ~isempty(dataInput)
				obj.Data = dataInput;
			end
		end
	end
	methods (Access = protected)
		function varargout = createFigure(obj)
			% DISPLAY CONSTANTS
			fontSize = 12;
			activeColor = [1 1 1 .8];
			inactiveColor = [.6 .6 .6 .2];
			otherColor = [.95 .95 .95 .5];
			cmap = gray(256);
			
			% INPUT IMAGE
			if isempty(obj.Data)
				tuningDataInput = zeros(obj.FrameSize, 'double');
			else
				tuningDataInput = onCpu(obj, obj.Data(:,:,1));
			end
			h.fig = figure;
			h.axInput = handle(axes('Parent',h.fig,...
				'Units','normalized',...
				'Position',[0 0 .5 1]));
			h.imInput = handle(imagesc(tuningDataInput, 'Parent', h.axInput));
			
			% OUTPUT IMAGE
			tuningDataOutput = zeros(obj.FrameSize, 'double');
			h.axOutput = handle(axes('Parent',h.fig,...
				'Units','normalized',...
				'Position',[.5 0 .5 1]));
			h.imOutput = handle(imagesc(tuningDataOutput, 'Parent',h.axOutput));
			
			% COMPOSITE IMAGE
			tuningDataComposite = cat(3,...
				scaleForComposite(obj, tuningDataOutput),...
				scaleForComposite(obj, tuningDataInput),...
				scaleForComposite(obj, tuningDataOutput));
			h.axComposite = handle(axes('Parent',h.fig,...
				'Units','normalized',...
				'Position',[0 0 1 1]));
			h.imComposite = handle(image(tuningDataComposite, 'Parent',h.axComposite));
			
			if obj.TuningFigureOverlayResult
				h.imInput.Visible = 'off';
				h.imOutput.Visible = 'off';
				h.axCurrent = h.axComposite;
			else
				h.imComposite.Visible = 'off';
				h.axCurrent = h.axOutput;
			end
			
			h.ax = [h.axInput, h.axOutput, h.axComposite];
			h.im = [h.imInput, h.imOutput, h.imComposite];
			
			% FIGURE PROPERTIES
			set(h.fig,...
				'Color',[.2 .2 .2],...
				'NextPlot','replace',...
				'Units','normalized',...
				'Color',[.25 .25 .25],...
				'MenuBar','none',...
				'Name','Tune Scicadelic',...
				'NumberTitle','off',...
				'HandleVisibility', 'callback',...
				'Clipping','on')
			h.fig.Position = [0 0 1 1];
			h.fig.Colormap = cmap;
			
			% AXES PROPERTIES
			set(h.ax,...
				'xlimmode','manual',...
				'ylimmode','manual',...
				'zlimmode','manual',...
				'climmode','manual',...
				'alimmode','manual',...
				'GridColor',[0 0 0],...
				'GridLineStyle','none',...
				'MinorGridColor',[0 0 0],...
				'TickLabelInterpreter','none',...
				'XGrid','off',...
				'YGrid','off',...
				'Visible','off',...
				'Layer','top',...
				'Clipping','on',...
				'NextPlot','replacechildren',...
				'TickDir','out',...
				'YDir','reverse',...
				'Units','normalized',...
				'DataAspectRatio',[1 1 1]);
			if isprop(h.ax, 'SortMethod')
				set(h.ax, 'SortMethod', 'childorder');
			else
				set(h.ax, 'DrawMode','fast');
			end
			% 			h.ax.Units = 'normalized'; h.ax.Position = [0 0 1 1];
			
			% TEXT FOR TUNING STEPS (PARAMETER NAMES & VALUES)
			imWidth = obj.FrameSize(1);
			imHeight = obj.FrameSize(2);
			numTuningSteps = numel(obj.TuningStep);
			textBlockInset = min(20, imWidth/numTuningSteps);
			% 			textBlockSpacing = textBlockInset; textBlockWidth = round(imWidth -
			% 			2*textBlockInset)/numTuningSteps;
			textPosition = [textBlockInset round(imHeight/20)];
			infoTextPosition = [textBlockInset, imHeight-60];
			for k=1:numTuningSteps
				initialText = sprintf('%s: %g', obj.TuningStep(k).ParameterName,999);
				h.txParameter(k) = handle(text(...
					'String', initialText,...
					'FontWeight','normal',...
					'BackgroundColor',[.1 .1 .1 .3],...
					'Color', inactiveColor,...
					'FontSize',fontSize,...
					'Margin',1,...
					'Position', textPosition,...
					'Parent', h.axCurrent));
				textPosition = textPosition + [0 h.txParameter(k).Extent(4)];%h.txParameter(k).Extent(4)+textBlockSpacing 0];
			end
			h.txParameter(1).Color = activeColor;
			
			% TEXT FOR CURRENT FRAME AND STATS
			idxText = sprintf('Frame Index: %i', obj.TuningImageIdx);%TODO
			h.txIdx = handle(text(...
				'String', idxText,...
				'FontWeight','normal',...
				'BackgroundColor',[.1 .1 .1 .3],...
				'Color', otherColor,...
				'FontSize',fontSize,...
				'Margin',1,...
				'Position', infoTextPosition,...
				'Parent', h.axCurrent));
			rtStart = tic;
			timeText = sprintf('Run-Time: %-03.4g ms', 1000*(toc(rtStart)));
			h.txTime = handle(text(...
				'String', timeText,...
				'FontWeight','normal',...
				'BackgroundColor',[.1 .1 .1 .3],...
				'Color', otherColor,...
				'FontSize',fontSize,...
				'Margin',1,...
				'Parent', h.axCurrent));
			h.txTime.Position = [infoTextPosition(1)...
				h.txIdx.Extent(2)+h.txIdx.Extent(4)/2+2];
			obj.TuningFigureInputCLim = [0 65535];
			obj.CLim = [0 65535];
			cLimText = sprintf('Contrast-Limits: [ %-d , %-d ]',...
				obj.CLim(1), obj.CLim(2));
			h.txOutputCLim = handle(text(...
				'String', cLimText,...
				'FontWeight','normal',...
				'BackgroundColor',[.1 .1 .1 .3],...
				'Color', otherColor,...
				'FontSize',fontSize,...
				'Margin',1,...
				'Parent', h.axCurrent));
			h.txOutputCLim.Position = [infoTextPosition(1)...
				h.txTime.Extent(2)+h.txTime.Extent(4)/2+2];
			h.txInputCLim = handle(text(...
				'String', cLimText,...
				'FontWeight','normal',...
				'BackgroundColor',[.1 .1 .1 .3],...
				'Color', otherColor,...
				'FontSize',fontSize,...
				'Margin',1,...
				'Parent', h.axInput));
			h.txInputCLim.Position = [infoTextPosition(1)...
				h.txTime.Extent(2)+h.txTime.Extent(4)/2+2];
			
			h.tx = [h.txParameter(:)' , h.txIdx , h.txTime , h.txOutputCLim];
			set(h.tx, 'Parent', h.axCurrent);
			assignin('base','h',h);
			
			obj.TuningCurrentStep = 1;
			h.fig.WindowKeyPressFcn = @(src,evnt)keyPressFcn(obj,src,evnt);
			h.fig.WindowKeyReleaseFcn = @(src,evnt)keyReleaseFcn(obj,src,evnt);
			obj.TuningFigureHandles = h;
			
			% DELAYED-UPDATE TIMER OBJECT
			obj.TuningDelayedUpdateTimerObj = timer(...
				'BusyMode','drop',...
				'ExecutionMode','singleShot',...
				'StartDelay',.050,...
				'TimerFcn',@(~,~)updateTuning(obj));
			start(obj.TuningDelayedUpdateTimerObj)
			% 			updateTuningText(obj) updateTuningFigure(obj)
			if nargout
				varargout{1} = h;
			end
		end
		function keyPressFcn(obj,~,evnt)
			if strcmp('on',obj.TuningDelayedUpdateTimerObj.Running)
				stop(obj.TuningDelayedUpdateTimerObj)
			end
			% NOTE THE INDEX OF CURRENTLY USED IMAGE
			if isempty(obj.TuningImageIdx)
				obj.TuningImageIdx = 1;
			end
			curStep = obj.TuningCurrentStep;
			numSteps = numel(obj.TuningStep);
			
			modKey = evnt.Modifier;
			obj.TuningFigureNeedsUpdate = true;
			switch evnt.Key;
				case 'leftarrow'
					if isempty(modKey) % LEFT: PREVIOUS FRAME
						obj.TuningImageIdx = max(obj.TuningImageIdx - 1, 1);
						stopAutoUpdateTimer(obj)
					elseif all(strcmp('control',modKey)) % CTRL-LEFT: BEGINNING OF STACK
						obj.TuningImageIdx = 1;
					end
				case 'rightarrow'
					if isempty(modKey) % RIGHT: NEXT FRAME
						obj.TuningImageIdx = min(obj.TuningImageIdx + 1,...
							size(obj.Data,3));
					elseif all(strcmp('control',modKey)) % CTRL-RIGHT: 
						if isempty(obj.TuningAutoProgressiveUpdateTimerObj)
							obj.TuningAutoProgressiveUpdateTimerObj = timer(...
								'BusyMode','drop',...
								'ExecutionMode','fixedSpacing',...
								'StartDelay',.250,...
								'TasksToExecute',inf,...
								'Period', .250,...
								'TimerFcn',@(~,~)cycleTuningIndex(obj));
							start(obj.TuningAutoProgressiveUpdateTimerObj)
						else
							stopAutoUpdateTimer(obj)
						end
					end
				case 'pageup' % PAGE-UP: PREVIOUS PARAMETER
					obj.TuningCurrentStep = min(max(obj.TuningCurrentStep - 1, 0), numSteps);
				case 'pagedown' % PAGE-DOWN: NEXT PARAMETER
					obj.TuningCurrentStep = min(max(obj.TuningCurrentStep + 1, 0), numSteps);
				case 'uparrow' % UP: INCREASE PARAMETER VALUE
					if isempty(modKey)
						if curStep >= 1
							obj.TuningStep(curStep).ParameterIdx = min(...
								obj.TuningStep(curStep).ParameterIdx + 1,...
								numel(obj.TuningStep(curStep).ParameterDomain));
						end
					elseif all(strcmp('control',modKey)) % CTRL-UP: PREVIOUS PARAMETER
						obj.TuningCurrentStep = min(max(obj.TuningCurrentStep - 1, 0), numSteps);
					end
				case 'downarrow' % DOWN: DECREASE PARAMETER VALUE
					if isempty(modKey)
						if curStep >= 1
							obj.TuningStep(curStep).ParameterIdx = max(...
								obj.TuningStep(curStep).ParameterIdx - 1, 1);
						end
					elseif all(strcmp('control',modKey)) % CTRL-RIGHT: NEXT PARAMETER
						obj.TuningCurrentStep = min(max(obj.TuningCurrentStep + 1, 0), numSteps);
					end
				case 'space'
					if isempty(modKey) % SPACE: TOGGLE AUTO-SCALE
						obj.TuningFigureAutoScale = ~obj.TuningFigureAutoScale;
					elseif all(strcmp('control',modKey)) % CTRL-SPACE: ADJUST CONTRAST (INPUT)
						obj.TuningFigureHandles.imInput.CData = double(obj.TuningFigureHandles.imInput.CData);
						imcontrast(obj.TuningFigureHandles.imInput)
					elseif all(strcmp('shift',modKey)) % SHIFT-SPACE: ADJUST CONTRAST (OUTPUT)
						obj.TuningFigureHandles.imOutput.CData = double(obj.TuningFigureHandles.imOutput.CData);
						imcontrast(obj.TuningFigureHandles.imOutput)
					end
				case 'c'
					if isempty(modKey) % C: TOGGLE COLORMAP
						hfig = obj.TuningFigureHandles.fig;
						cmap = hfig.Colormap;
						if all(cmap(:,1) == cmap(:,2)) % gray
							hfig.Colormap = parula(256);
						else
							hfig.Colormap = gray(256);
						end
					elseif all(strcmp('shift',modKey)) % SHIFT-C: TOGGLE OVERLAY
						obj.TuningFigureOverlayResult = ~obj.TuningFigureOverlayResult;
					end
				case 'o'
					obj.TuningFigureOverlayResult = ~obj.TuningFigureOverlayResult;
				case 'return'
					if isempty(modKey) % ENTER: NEXT STEP (OR FINISH)
						obj.TuningCurrentStep = curStep + 1;
						if obj.TuningCurrentStep > numel(obj.TuningStep)
							obj.TuningFigureNeedsUpdate = false;
							closeTuningFigure(obj);
							return
						end
					elseif all(strcmp('control',modKey)) % CTRL-ENTER: TOGGLE OVERLAY
						obj.TuningFigureOverlayResult = ~obj.TuningFigureOverlayResult;
					end
				case 'escape'
					obj.TuningFigureNeedsUpdate = false;
					closeTuningFigure(obj);
					return
				otherwise
					obj.TuningFigureNeedsUpdate = false;
					% 					fprintf('KEYPRESS: %s\t', evnt.Key) fprintf('(%s)\t',evnt.Modifier{:})
					% 					fprintf('[%s]\t',evnt.Character) fprintf('\n')
			end
			
			% UPDATE
			updateTuningText(obj)
			
		end
		function keyReleaseFcn(obj,~,~)
			timerIsRunning = strcmp('on',obj.TuningDelayedUpdateTimerObj.Running);
			if obj.TuningFigureNeedsUpdate && ~timerIsRunning
				start(obj.TuningDelayedUpdateTimerObj)
				obj.TuningFigureNeedsUpdate = false;
			end
		end
		function stopAutoUpdateTimer(obj)
			if ~isempty(obj.TuningAutoProgressiveUpdateTimerObj)...
					&& isvalid(obj.TuningAutoProgressiveUpdateTimerObj)				
							stop(obj.TuningAutoProgressiveUpdateTimerObj)
							delete(obj.TuningAutoProgressiveUpdateTimerObj);							
			end
			obj.TuningAutoProgressiveUpdateTimerObj = [];
		end
		function cycleTuningIndex(obj)
			% CALLED BY TUNINGAUTOPROGRESSIVEUPDATETIMER (CTRL + RIGHT-ARROW)
			idx = obj.TuningImageIdx + 1;
			if idx > size(obj.Data,3)
				idx = 1;
			end
			obj.TuningImageIdx = idx;
			updateTuning(obj)
		end
		function updateTuning(obj)
			updateTuningFigure(obj)
			updateTuningText(obj)
		end
		function updateTuningFigure(obj)
			h = obj.TuningFigureHandles;
			curStep = obj.TuningCurrentStep;
			obj.TuningImageIdx = min(max(obj.TuningImageIdx, 1), size(obj.Data,3));
			F = obj.Data(:,:,obj.TuningImageIdx);
			
			% SEND INPUT TO GPU IF NECESSARY
			if obj.UseGpu && ~isa(F, 'gpuArray')
				Fstep = gpuArray(F);
			else
				Fstep = F;
			end
			
			% CALL EACH PRECEDING FUNCTION WITH CHOSEN PARAMETERS
			
			if curStep >= 1
				k=1;
				completeStep = false;
				while (k <= curStep) || (~completeStep)
					parameterPropVal = obj.TuningStep(k).ParameterDomain(obj.TuningStep(k).ParameterIdx);
					parameterPropName = obj.TuningStep(k).ParameterName;
					
					if iscell(parameterPropVal) % NEW!!
						parameterPropVal = parameterPropVal{1};
					end
					
					obj.(parameterPropName) = parameterPropVal;
					completeStep = obj.TuningStep(k).CompleteStep;					
					if completeStep
						setPrivateProps(obj)
						fcn = obj.TuningStep(k).Function;
						rtStart = tic;
						Fstep = feval( fcn, obj, Fstep);
						obj.TuningTimeTaken = toc(rtStart);
					end
					k=k+1;
				end
			end
			% RECORD CONTRAST LIMITS (CHANGE OR KEEP)
			% 			if obj.TuningFigureAutoScale || isempty(obj.CLim)
			% 				obj.CLim = onCpu(obj, [min(Fstep(:)) , max(Fstep(:))]);
			% 			end
			
			% OVERLAY INPUT & OUTPUT OR SHOW SIDE-BY-SIDE
			if obj.TuningFigureOverlayResult
				Fin = scaleForComposite(obj, F, [0 1]);
				Fout = scaleForComposite(obj, Fstep, [0 .6]);
				h.axCurrent = h.axComposite;
				h.imComposite.CData(:,:,3) = max(0, Fin-.5*Fout); % h.imComposite.CData(:,:,2) = Fin;
				h.imComposite.CData(:,:,2) = .2*max(0, Fin - .6*Fout);%NEW
				h.imComposite.CData(:,:,1) = Fout;%abs(Fin-.5*Fout);% h.imComposite.CData(:,:,[1,3]) = repmat(Fout, 1,1,2);
				h.imComposite.Visible = 'on';
				h.imInput.Visible = 'off';
				h.imOutput.Visible = 'off';
				obj.CLim = onCpu(obj, [min(Fstep(:)) , max(Fstep(:))]);
				obj.TuningFigureInputCLim = onCpu(obj, [min(F(:)) , max(F(:))]);
			else
				% 				Fin = scaleForDisplay(obj, F); Fout = scaleForDisplay(obj, Fstep, [0 1]);
				Fin = onCpu(obj, F);
				Fout = onCpu(obj, Fstep);
				if islogical(Fstep)
					if all(h.imOutput.CData(:) < 1)
						Fout = .75.*double(Fout) + .10.*h.imOutput.CData;
					else
						Fout = .75.*double(Fout);
					end
				end
				h.axCurrent = h.axOutput;
				h.imInput.CData = Fin;
				h.imOutput.CData = Fout;
				h.imComposite.Visible = 'off';
				h.imInput.Visible = 'on';
				h.imOutput.Visible = 'on';
				if obj.TuningFigureAutoScale
					obj.TuningFigureInputCLim = onCpu(obj, [min(F(:)) , max(F(:))]);
					obj.CLim = onCpu(obj, [min(Fstep(:)) , max(Fstep(:))]);
				end
				h.axInput.CLim = double(obj.TuningFigureInputCLim);
				h.axOutput.CLim = double(obj.CLim);
			end
			obj.TuningFigureHandles = h;
			% 			h.imInput.CData(:,:,2) = scaleForDisplay(obj,F); h.imInput.CData(:,:,[1,3]) =
			% 			repmat(scaleForDisplay(obj,Fstep), 1,1,2);
		end
		function updateTuningText(obj)
			h = obj.TuningFigureHandles;
			activeColor = [1 1 1 .8];
			inactiveColor = [.6 .6 .6 .4];
			for k=1:numel(obj.TuningStep)
				paramIdx = obj.TuningStep(k).ParameterIdx;
				paramIdx = min( max( 1, paramIdx), numel(obj.TuningStep(k).ParameterDomain));
				x = obj.TuningStep(k).ParameterDomain(paramIdx);
				if iscell(x)
					x = x{1};
				end
				if isnumeric(x)
					h.txParameter(k).String = sprintf('%s: %g', obj.TuningStep(k).ParameterName,x);
				else
					h.txParameter(k).String = sprintf('%s: %s', obj.TuningStep(k).ParameterName,x);%TODO
				end
				if k == obj.TuningCurrentStep
					h.txParameter(k).Color = activeColor;
				else
					h.txParameter(k).Color = inactiveColor;
				end
			end
			h.txIdx.String = sprintf('Frame Index: %i', obj.TuningImageIdx);%TODO
			h.txTime.String = sprintf('Run-Time: %-03.4g ms', 1000*(obj.TuningTimeTaken));
			h.txInputCLim.String = sprintf('Contrast-Limits: [ %-d , %-d ]',...
				obj.TuningFigureInputCLim(1), obj.TuningFigureInputCLim(2));
			h.txOutputCLim.String = sprintf('Contrast-Limits: [ %-d , %-d ]',...
				obj.CLim(1), obj.CLim(2));
			if obj.TuningFigureAutoScale
				h.txOutputCLim.Color = [.95 .95 .95];
				h.txInputCLim.Color = [.95 .95 .95];
			else
				h.txOutputCLim.Color = [.6 .6 .6];
				h.txInputCLim.Color = [.6 .6 .6];
			end
			set(h.tx, 'Parent', h.axCurrent)
		end
		function closeTuningFigure(obj)
			stopAutoUpdateTimer(obj)
			delete(obj.TuningDelayedUpdateTimerObj)
			close(obj.TuningFigureHandles.fig);
		end
		function im = scaleForComposite(obj, im, cLim)
			if isa(im,'gpuArray')
				im = gather(im);
			end
			if nargin < 3
				cLim = obj.CLim;
				if isempty(cLim)
					cLim = double([min(im(:)) max(im(:))]);
					obj.CLim = cLim;
				end
			end
			if all(cLim <= 1) %&& (range(im(:)) > 1)
				imMax = double(max(im(:)));
				im = imadjust(double(im)./imMax,...
					double([min(im(:)), imMax])./imMax , cLim);
			else
				cLim = double(cLim);
				im = max(0,min(1,(double(im)-cLim(1))./(cLim(2)-cLim(1))));
			end
		end
		
	end
	
	
	
	
	
end