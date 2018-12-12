function savefig2jpeg(varargin)


im = getframe;

if nargin
	fname = varargin{1};
	if ~strcmp(fname((end-2):end), 'jpg')
		fname = [fname,'.jpg'];
	end
else
	fname = get(get(gca,'Title'),'String');
	if isempty(fname)
		[filename,pathname] = uiputfile({'*.jpg;','jpg'}, 'savefig2jpeg',...
			['savedfig_',datestr(now,'yyyymmmdd_HHMMPM'),'.jpg']);
		fname = [pathname,filename];
	else
		fname = [fname, '_', datestr(now,'yyyymmmdd_HHMMPM') , '.jpg'];
	end
end

if exist(fname,'file')
	k=1;
	fname = [fname(1:end-4), '(',num2str(k),')','.jpg'];
	while exist(fname,'file')
		k=k+1;
		numidx = regexp(fname, '\(\d+\).jpg')-1;
		fname = [fname(1:numidx), '(',num2str(k),')','.jpg'];
		% 		fname = [fname(1:end-4), '(',num2str(k),')','.jpg'];
	end
end
imwrite(im.cdata, fname)