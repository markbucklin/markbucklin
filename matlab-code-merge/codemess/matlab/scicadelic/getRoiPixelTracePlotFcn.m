function plotFcn = getRoiPixelTracePlotFcn(roi)
%	>> plotFcn = getRoiPixelTracePlotFcn(roi)
%	>> idx = 10; signal = 'red';
%	>> group = plotFcn(idx,signal)

signalNames = fields(roi(1).trace);

plotFcn = @(varargin) plotRoiPixelTrace( varargin{:});


	function pixelTraceGroup = plotRoiPixelTrace(plotIdx, plotName, plotApplyFcn, plotApplySubtractFcn)
		
		plotTransparency = .15;
		hAx = gca;
		cla;
		if nargin < 2
			plotName = signalNames{1};
		end
		getPixelMat = @(idx) roi(idx).trace.(plotName);
		if nargin > 2
			processPixelMat = @(idx) plotApplyFcn(getPixelMat(idx));
		else
			processPixelMat = getPixelMat;
		end
		if nargin > 3
			getLineData = @(idx) bsxfun( @minus, processPixelMat(idx), plotApplySubtractFcn(processPixelMat(idx)));
		else
			getLineData = processPixelMat;
		end
		numPlotIdx = numel(plotIdx);
		plotColorMap = [distinguishable_colors(numPlotIdx) , repelem(plotTransparency,numPlotIdx,1)];
		kPlot = 0;
		groupSet = cell(size(plotIdx));
		xOffset = 0;
		while kPlot < numPlotIdx
			kPlot = kPlot + 1;
			group = hggroup('Parent',hAx);
			try
				x = getLineData(plotIdx(kPlot));
			catch me
				getReport(me)
			end
			if isempty(x)
				continue
			end
			x = x + xOffset;
			groupSet{kPlot} = group;
			hLine = plot( x, 'Parent', group, 'Color', plotColorMap(kPlot,:));
			xOffset = mean(max(x,[],1));
			% 			xOffset = xOffset + mean(x(:)) +
		end
		pixelTraceGroup = [groupSet{:}];
	end


end