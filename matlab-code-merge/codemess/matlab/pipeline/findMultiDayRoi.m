md = loadMultiDayRoi;
% fld = fields(md(1).vidstats);
% vstat = cat(2,md.vidstats);
% for fln = 1:numel(fld)
%    fn = fld{fln};
%    for k=1:numel(md)
% 	  vday(k).(fn) = mean(cat(3,md(k).vidstats.(fn) ), 3);
%    end
%    data = cat(3,vday.(fn));
%    vmouse.(fn).data = data;
%    parfor k=1:size(data,3)
% 	  [dcdata(:,:,k), psf(:,:,k)] = deconvblind(data(:,:,k),ones(5));
%    end
%    vmouse.(fn).dcdata = dcdata;
%    vmouse.(fn).psf = psf;
% end