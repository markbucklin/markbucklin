function fig2png(hFig, fileName)


persistent figDir
if nargin < 1
   hFig = gcf;
   if nargin < 2
	  fileName = get(get(gca,'Title'),'String');
	  if isempty(fileName)
		 [fileName, figDir] = uiputfile('*.png',figDir);
	  else
		 figDir = uiputdir(fileName);
	  end
   end
end

if isempty(figDir)
   figDir = pwd;
end

print(hFig,fullfile(figDir,fileName), '-dpng','-r450')