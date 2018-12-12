classdef VideoNavigator < vision.VideoPlayer
	
	
	properties
		SaturationLimits = [5 99.99]
	end
	properties (SetAccess = protected)
		CurrentFrameIdx
		Data
		Mask
		NFrames
		FrameSize
		Handle
		FigureNeedsUpdate
		UseMask @logical scalar
	end
	properties (SetAccess = protected, Hidden)
		MaskCmap
		UpdateTimerObject
		IsUpdating = false
	end
	
	
	
	methods
		function obj = VideoNavigator(data, varargin)
			% CALL PARENT
			obj = obj@vision.VideoPlayer();
			
			% CONVERT DATA TO UINT8
			% 			if ~isa(data,'uint8')
				% 				if any(data(:)<0)
				% 					set(gcf(parula(256))
				% 				end
					data = single((data-min(data(:)))./range(data(:)));					
					% 			end
			
			obj.Data = data;
			obj.CurrentFrameIdx = 1;
			sz = size(data);
			obj.FrameSize = sz(1:(ndims(data)-1));
			obj.NFrames = sz(ndims(data));
			
			if nargin > 1
				obj.Mask = varargin(:);
				obj.UseMask = true;
			end
			% 			if nargin > 1
			% 				mask = varargin(:);
			% 				numMask = numel(mask);
			% 				cmap = distinguishable_colors(numMask,[1 1 1;0 0 0]);
			% 				if islogical(mask{1})
			% 					for m=1:numMask
			% 						bw = mask{m};
			% 						if ndims(bw) == 3
			% 							bw = permute(shiftdim(bw,-1),[2 3 1 4]);
			% 						end
			% 						F = bsxfun(@times, bw, shiftdim(cmap(m,:),-1));
			% 						F(F<eps) = nan;
			% 						% 				axMask(k,m) = handle(axes
			% 						h.mask(k,m) = handle(image(F, 'Parent', h.ax(k), 'AlphaData', bw.*(.5./sqrt(numMask))));
			%
			% 					end
			% 				else
			%
			% 				end
			%
			% 			end
			
			
			
			% GET FIGURE HANDLE
			show(obj);
			switch ndims(data)
				case 4
					step(obj, data(:,:,:,1));
				case 3
					step(obj, data(:,:,1));
			end
			set(0,'ShowHiddenHandles','on')
			h.fig = handle(gcf);
			h.ax = handle(h.fig.CurrentAxes);
			h.im = findobj(h.ax.Children, 'Type', 'image');
			% 			h.im = handle(h.fig.CurrentObject);
			
			% SETUP BINARY MASK OVERLAY
			if obj.UseMask
				set(h.ax, 'NextPlot','add')
				numMask = numel(obj.Mask);
				cmap = single(distinguishable_colors(numMask,[1 1 1;0 0 0]));
				obj.MaskCmap = cmap;
				for m=1:numMask
					bw = single(obj.Mask{m}(:,:,1));
					F = bsxfun(@times, bw, shiftdim(cmap(m,:),-1));
					h.mask(m) = handle(image(F, 'Parent', h.ax, 'AlphaData', bw.*(.5./sqrt(numMask))));
				end
			end
			
			
			
			% TEXT FOR CURRENT FRAME AND STATS
			idxText = sprintf('Frame Index: %i', obj.CurrentFrameIdx);
			h.text = handle(text(...
				'tag','index',...
				'String', idxText,...
				'FontWeight','normal',...
				'BackgroundColor',[.1 .1 .1 .3],...
				'Color', [.95 .95 .95],...
				'FontSize',12,...
				'Margin',1,...
				'Position', [15 sz(1)-20],...
				'Parent', h.ax));
			
			% UPDATE TIMER OBJECT
			obj.UpdateTimerObject = timer(...
				'BusyMode','drop',...
				'ExecutionMode','singleShot',...
				'StartDelay',.025,...
				'TimerFcn' ,@(~,~)updateFigure(obj),...
				'StopFcn', @(~,~)updateFinished(obj));% unused stopfcn
			
			% SET WINDOW KEY-PRESS FUNCTIONS
			h.fig.WindowKeyPressFcn = @(src,evnt)keyPressFcn(obj,src,evnt);
			h.fig.WindowKeyReleaseFcn = @(src,evnt)keyReleaseFcn(obj,src,evnt);
			obj.Handle = h;
			
			set(0,'ShowHiddenHandles','off')
			
		end
	end
	methods (Access = protected)
		function keyPressFcn(obj,~,evnt)
			
			idx = obj.CurrentFrameIdx;
			modKey = evnt.Modifier;
			switch evnt.Key;
				case 'leftarrow'
					if isempty(modKey) % LEFT: PREVIOUS FRAME (SMOOTH UPDATE)
						if ~obj.FigureNeedsUpdate
							obj.CurrentFrameIdx = max(obj.CurrentFrameIdx - 1, 1);
						end
					elseif all(strcmp('control',modKey)) % CTRL-LEFT: JUMP BACKWARD 10
						obj.CurrentFrameIdx = max(obj.CurrentFrameIdx - 10, 1);
					elseif all(strcmp('shift',modKey)) % SHIFT-LEFT: JUMP BACKWARD 1
						obj.CurrentFrameIdx = max(obj.CurrentFrameIdx - 1, 1);
					end
				case 'rightarrow'
					if isempty(modKey) % RIGHT: NEXT FRAME (SMOOTH UPDATE)
						if ~obj.FigureNeedsUpdate
							obj.CurrentFrameIdx = min(obj.CurrentFrameIdx + 1, obj.NFrames);
						end
					elseif all(strcmp('control',modKey)) % CTRL-RIGHT: JUMP FORWARD 10
						obj.CurrentFrameIdx = min(obj.CurrentFrameIdx + 10, obj.NFrames);
					elseif all(strcmp('shift',modKey)) % SHIFT-RIGHT: JUMP FORWARD 1
						obj.CurrentFrameIdx = min(obj.CurrentFrameIdx + 1, obj.NFrames);
					end
				case 'uparrow' % UP:
					
				case 'downarrow' % DOWN:
					
				case 'space'
					if isempty(modKey) % SPACE:
						hImage = findobj(obj.Handle.fig.CurrentAxes.Children, 'type', 'image');
						set(hImage,'CDataMapping','scaled')
						currFrame = hImage.CData;
						cLim = prctile(double(currFrame(:)), obj.SaturationLimits);
						if cLim(1)>=cLim(2)
							cLim(1) = 0;
						end
						if cLim(1)>=cLim(2)
							cLim(2) = 1;
						end
						obj.Handle.fig.CurrentAxes.CLim = cLim;
					elseif all(strcmp('control',modKey)) % CTRL-SPACE:
						
					elseif all(strcmp('shift',modKey)) % SHIFT-SPACE:
						
					end
				case 'c'
					if isempty(modKey) % C:
						
						
					elseif all(strcmp('shift',modKey)) % SHIFT-C:
						
					end
				case 'return'
					if isempty(modKey) % ENTER:
						
					elseif all(strcmp('control',modKey)) % CTRL-ENTER:
						
					end
				case 'escape'
					obj.FigureNeedsUpdate = false;
					release(obj)
					close(obj.Handle.fig)
					return
				otherwise
					obj.FigureNeedsUpdate = false;
			end
			
			% UPDATE
			if obj.CurrentFrameIdx ~= idx
				obj.FigureNeedsUpdate = true;
				if strcmp(obj.UpdateTimerObject.Running, 'off')
					start(obj.UpdateTimerObject)
					% 					pause(.01)
				else
					updateText(obj)
				end
			end
			
			
			% 			updateText(obj)
			% 			if strcmp(obj.UpdateTimerObject.Running, 'off')
			% 				start(obj.UpdateTimerObject)
			% 			end
			
		end
		function keyReleaseFcn(obj,~,~)
			
			if strcmp(obj.UpdateTimerObject.Running, 'on')
				stop(obj.UpdateTimerObject)
				updateFigure(obj)
				% 				else
				% 					updateText(obj)
			end
			
			% 			updateFigure(obj)
			
			% 			timerIsRunning = strcmp('on',obj.TuningDelayedUpdateTimerObj.Running);
			% 			if obj.TuningFigureNeedsUpdate && ~timerIsRunning
			% 				start(obj.TuningDelayedUpdateTimerObj)
			% 				obj.TuningFigureNeedsUpdate = false;
			% 			end
		end
		function updateFigure(obj)
			if ~obj.FigureNeedsUpdate
				return
			end
			obj.IsUpdating = true;
			h = obj.Handle;
			h.ax.NextPlot = 'replace';
			idx = obj.CurrentFrameIdx;
			
			% 			if obj.FigureNeedsUpdate
			switch ndims(obj.Data)
				case 3
					step(obj, obj.Data(:,:, idx));
				case 4
					step(obj, obj.Data(:, :, :, idx));
			end
			% 			end
			
			if obj.UseMask
				h.ax.NextPlot = 'add';
				numMask = numel(obj.Mask);
				cmap = obj.MaskCmap;
				for m=1:numMask
					bw = single(obj.Mask{m}(:,:,idx));
					F = bsxfun(@times, bw, shiftdim(cmap(m,:),-1));
					h.mask(m).CData = F;
					h.mask(m).AlphaData = bw.*(.5./sqrt(numMask));
				end
			end
			
			obj.FigureNeedsUpdate = false;
			updateText(obj)
			obj.IsUpdating = false;
		end
		function updateText(obj)
			hIndex = findobj(obj.Handle.text,'tag','index');
			hIndex.String = sprintf('Frame Index: %i', obj.CurrentFrameIdx);
		end
		function updateFinished(obj)
			obj.IsUpdating = false;
		end
	end
	
	
	
	
	
	
	
	
end