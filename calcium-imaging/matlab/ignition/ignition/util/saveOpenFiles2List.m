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
saveFileName = sprintf('OpenFilesList%s.html',datestr(now,'dddddmmmHHMMPM'));
saveFileName = saveFileName(~isspace(saveFileName));
saveFilePath = fullfile(saveDir,saveFileName); %[saveDir,pathsep,saveFileName]
fid = fopen(saveFilePath,'a');
fprintf(fid, htmlDocTxt);
%fprintf(fid, '%s\n',fileNames{:});
fclose(fid);

%% OPEN BROWSER
[stat,h] = web('', '-new');
h.setHtmlText(htmlDocTxt);


end


%% FUNCTIONS FOR WRITING HTML TAGS
function docTxt = makeHtmlDoc(body)
body = wrapIfNotCellStr(body);
docTxt = sprintf('<html>\n%s</html>\n',sprintf('%s\n',body{:}));
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
	[,~,fname] = fileparts(href);	
	lnk{k} = sprintf('<a href="file://%s">%s</a>', href, fname);
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

