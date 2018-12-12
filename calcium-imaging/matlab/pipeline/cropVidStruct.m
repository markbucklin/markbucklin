function vid = cropVidStruct(vid, varargin)

if nargin > 1
  rpos = varargin{1};
else
  try
	 stat = getVidStats(vid);
	 hIm = handle(imshow(stat.Mean, 'DisplayRange', [min(stat.Mean(:)) max(stat.Mean(:))] ));
	 waitfor(msgbox('Please select a region to crop'))
	 hIm = imhandles(gcf);
	 hAx = ancestor(hIm,'axes');	 
	 hRect = iptui.imcropRect(hAx, [], hIm);
	 % Constrain to Square
	 pos = hRect.getPosition();
	 shorterSide = min(pos(3:4));
	 hRect.setPosition([pos(1) pos(2) shorterSide shorterSide])
	 hRect.setFixedAspectRatioMode([1 1])
	 waitfor(msgbox('Select OK when satisfied with the cropped region'))
	 % Constrain Rectangle Def to ODD so SIZE is EVEN
	 rpos = hRect.getPosition;
	 rpos(3:4) = 2*floor(rpos(3:4)/2) + 1;
  catch me
	 imshow(stat.Mean, 'DisplayRange', [min(stat.Mean(:)) max(stat.Mean(:))] );
	 waitfor(msgbox('Please select a region to crop'))
	 r = imrect;
	 rpos = round(r.getPosition);
  end
end

close(gcf)
for k=1:numel(vid)
  vid(k).cdata = imcrop(vid(k).cdata, rpos);
end