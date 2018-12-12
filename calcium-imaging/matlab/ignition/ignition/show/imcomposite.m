function imcomposite(data1,data2, varargin)

vd(1).cdata = oncpu(data1);
vd(2).cdata = oncpu(data2);

% GATHER EXTRA INPUTS (IF MORE THAN 2 GIVEN)
if nargin > 2
	for k=3:nargin
		vd(k).cdata = oncpu(varargin{k-2});
	end
end

% PICK APART MULTI-FRAME INPUTS
numVid = numel(vd);
k=0;
while k < numVid
	k = k + 1;
	sz = size(vd(k).cdata);
	if ~ismatrix(vd(k).cdata)
		nFrames = sz(end);
		if nFrames > 8
			switch ndims(vd(k).cdata)
				case 3
					vd(k).cdata = vd(k).cdata(:,:, randi([1 nFrames]));
				case 4
					vd(k).cdata = vd(k).cdata(:,:,:, randi([1 nFrames]));
				otherwise
					error('invalid dimensions')
			end
		elseif nFrames > 1
			switch ndims(vd(k).cdata)
				case 3
					F = vd(k).cdata(:,:,2:end);
					vd(k).cdata = vd(k).cdata(:,:,1);
				case 4
					F = squeeze(vd(k).cdata(:,:,1,2:end));
					vd(k).cdata = squeeze(vd(k).cdata(:,:,1,1));
				otherwise
					error('invalid dimensions')
			end
			newNumVid = numVid + nFrames-1;
			
			% NEW
			if numVid >= k
				% 				numOldVid = numVid-k;
				vdOld = vd((k+1):end); % vd((end-numOldVid):end)
				vd((k+nFrames):newNumVid) = vdOld;
			end
			for knew = 1:nFrames-1
				vd(knew+k).cdata = oncpu(F(:,:,knew));
			end
			% 			for knew = 1:nFrames-1
			% 				vd(knew+numVid).cdata = oncpu(F(:,:,knew));
			% 			end
			numVid = newNumVid;
		end
	end
	vd(k).imSize = sz(1:2);
end
%% RESCALE & CLASSIFY (LOGICAL/INTENSITY)

for k=1:numel(vd)
	F = vd(k).cdata;
	vd(k).islogical = islogical(F);
	if ~islogical(F)
		low_high = prctile(double(F(:)), [.1 99.995]);
		imin = low_high(1);
		imax = low_high(2);
		F = min(max( (double(F)-imin)./(imax-imin), 0), 1);
	else
		F = double(F);
	end
	vd(k).cdata = F;
	
end

%% DISPLAY
hGRoot = handle(groot);
if ~isempty(hGRoot.CurrentFigure)
	curFig = handle(gcf);
	if strcmpi(curFig.Name,'imcomposite-fig')
		h.fig = curFig;
		figure(h.fig)
		clf;
	else
		h.fig = handle(figure);
	end
else
	h.fig = handle(figure);
end
h.fig.Name = 'imcomposite-fig';
h.fig.Units = 'normalized';
numBaseFrames = nnz(~[vd.islogical]);
numMask = nnz([vd.islogical]);
if (numBaseFrames>=1) && (numMask>=1)
	vBase = vd(~[vd.islogical]);
	vMask = vd([vd.islogical]);
	
	cmap = distinguishable_colors(numMask,[0 0 0]); % blue, red, green
	if (numBaseFrames > 3)
		axNumRows = floor(sqrt(numBaseFrames));
		axNumCols = ceil(numBaseFrames/axNumRows);
		axWidth = 1/axNumCols;
		axHeight = 1/axNumRows;
		axLeftEdge = mod(axWidth * (0:numBaseFrames-1), 1);
		axBottomEdge = fliplr(floor(...
			((0:numBaseFrames-1) / (axNumRows*axNumCols))...
			./axHeight).*axHeight);%PHEW
	else		
		axWidth = 1/numBaseFrames;
		axHeight = 1;
		axLeftEdge = axWidth .* (0:numBaseFrames-1);
		axBottomEdge = zeros(numBaseFrames,1);
	end
	for k=1:numBaseFrames
		h.ax(k) = handle(axes(...
			'parent',h.fig,...
			'position', [axLeftEdge(k) axBottomEdge(k) axWidth axHeight],...
			'NextPlot','add'));
		h.im(k) = handle(imshow(vBase(k).cdata,...
			'Parent',h.ax(k)));
		set(h.ax(k),'PlotBoxAspectRatio', [1 1 1])
		for m=1:numMask
			bw = vMask(m).cdata;
			F = bsxfun(@times, bw, shiftdim(cmap(m,:),-1));
			F(F<eps) = nan;
			% 				axMask(k,m) = handle(axes
			h.mask(k,m) = handle(image(F, 'Parent', h.ax(k), 'AlphaData', bw.*(.75./sqrt(numMask))));
			
		end
	end
	linkaxes(h.ax)
% elseif numBase >= 1
		
% elseif numMask >= 1
else
	switch numel(vd)
		case 2
			h.ax = handle(axes('parent',h.fig,'position', [0 0 1 1]));
			R = vd(1).cdata;
			G = R;
			B = vd(2).cdata;
			h.im = handle(imshow(cat(3, R,G,B),...
				'Parent',h.ax));
		case 3
			h.ax = handle(axes('parent',h.fig,'position', [0 0 1 1]));
			R = vd(1).cdata;
			G = vd(2).cdata;
			B = vd(3).cdata;
			h.im = handle(imshow(cat(3, R,G,B),...
				'Parent',h.ax));
		otherwise
	end
end
whitebg('k')
assignin('base','h',h)

%% MOVIE
% for k=1:N
%    if ~isvalid(h.fig)
% 	  break
%    end
% 	for kd=1:numel(vd)
% 	   try
% 		h.im(kd).CData = vd(kd).cdata(:,:,k);
% 		hText(kd).String = sprintf('frame %i',k);
% 	   catch me
% 	   end
% 	end
% 	drawnow
% end
