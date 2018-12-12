function saveOpenFiles2List()

openFiles = matlab.desktop.editor.getAll;
fileNames = {openFiles.Filename};
fileStr = sprintf('Opened M-Files (%s).txt',datestr(now,'dddd mmmmdd HHMMPM'));
fid = fopen(fileStr,'a');

fprintf(fid, '%s\n',fileNames{:});

fclose(fid);


