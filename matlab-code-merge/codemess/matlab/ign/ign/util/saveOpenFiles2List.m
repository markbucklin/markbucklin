function saveOpenFiles2List(saveDir)

%% GET DIRECTORY TO SAVE TO
if nargin < 1
	saveDir = [];
end
if isempty(saveDir)
	saveDir = uigetdir(pwd);
end

%% GET OPEN FILES (INCLUDES ALL FILE TEXT)
openFiles = matlab.desktop.editor.getAll;
fileNames = {openFiles.Filename};

%% GENERATE HTML-FORMATTED TEXT OF HYPERLINKS
htmlDocTxt = makeHtmlDoc(...
	makeListHTML(...
	makeOpenFileLinkHTML(fileNames)));

%% WRITE TO FILE
saveFileName = sprintf('OpenFilesList%s',datestr(now,'dddddmmmHHMMPM'));
%saveFileName = saveFileName(~isspace(saveFileName));
saveFileName(isspace(saveFileName)) = '0';
saveHtmlFilePath = fullfile(saveDir,[saveFileName,'.html']); %[saveDir,pathsep,saveFileName]
fid = fopen(saveHtmlFilePath,'wt');
fwrite(fid, htmlDocTxt);
%fprintf(fid, '%s\n',fileNames{:});
fclose(fid);

%% SAVE DOCUMENT OBJECTS
% if strcmpi('yes',questdlg('Save opened file objects to mat file?'))
% 	saveDocobjFilePath = fullfile(saveDir,[saveFileName,'.mat']);
% 	save(saveDocobjFilePath, 'openFiles')
% end


%% OPEN BROWSER
[stat,h] = web(saveHtmlFilePath, '-new');
%[stat,h] = web('', '-new');
%h.setHtmlText(htmlDocTxt);


end


%% FUNCTIONS FOR WRITING HTML TAGS
function docTxt = makeHtmlDoc(body)
body = wrapIfNotCellStr(body);
docTxt = sprintf(['<!DOCTYPE html>\n<html>\n',...
'<head>\n<title>Open Files</title>\n</head>\n',...
'<body>\n',...
'%s',...
'</body>\n</html>'],...
	sprintf('%s\n',body{:}));
end
function ul = makeListHTML(li)
li = wrapIfNotCellStr(li);
ul = {sprintf('<ul>\n%s</ul>\n', sprintf('<li>%s</li>\n', li{:}))};
end
function lnk = makeOpenFileLinkHTML(fpath)
fpath = wrapIfNotCellStr(fpath);
lnk = cell(1,numel(fpath));
for k=1:numel(fpath)
	href = fpath{k};
	[fdir,fname] = fileparts(href);
	lnk{k} = sprintf(['<a href = "%s">%s</a> ',...		
		'%s ',...
		'(<a href="matlab: winopen(''%s'')">open</a>) ',...
		'(<a href="matlab: edit %s">edit</a>) ',...
		''], href, fname, fdir, fdir, href);
	
	% '<a href="matlab: edit filename">file</a>'
end
end
function cstr = wrapIfNotCellStr(cstr)
if ~iscellstr(cstr)
	cstr = {cstr};
end
end



%h.createBrowser

% url = 'http://www.mathworks.com';
% [stat,h] = web(url);
% fl = h.getFocusListeners
% h.getMouseListeners
% h.getMousePosition
% h.setHtmlText('http://www.google.com')
% matlab:web
% docroot

