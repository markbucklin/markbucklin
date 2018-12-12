function [gfile, allfile] = exploredir()

root = pwd;
cd(root);
%% get files and folders recursively
d = dir(['**',filesep,'*']);
d = d(~strcmp({d.name},'.'));
d = d(~strcmp({d.name},'..'));

%% split into files and folders
files = d(~[d.isdir]);
folders.abspath = unique({files.folder})';
folders.relpath = extractAfter(folders.abspath,root)

%%

for k=numel(files):-1:1
	fprintf('Processing %s\n',files(k).name)
	allfile(k).name = files(k).name;
	allfile(k).reldir = extractAfter(files(k).folder,root);
	allfile(k).fullpath = fullfile(files(k).folder,files(k).name);
	[allfile(k).fulldir,allfile(k).base,allfile(k).ext] = fileparts(allfile(k).fullpath);
	if any(contains(allfile(k).reldir,'+'))
		allfile(k).packagePrefix = [strrep(extractAfter(allfile(k).reldir,find(allfile(k).reldir=='+',1,'first')),'\+','.'),'.'];
	else
		allfile(k).packagePrefix = '';
	end
	if strcmp(allfile(k).ext,'.m')
		allfile(k).ismcode = true;
		allfile(k).content = matlab.internal.getCode(allfile(k).fullpath);
		% 		codeAsCell = strsplit(codeAsChar, {'\r\n','\n', '\r'}, 'CollapseDelimiters', false)';
		allfile(k).ismathworks = contains(allfile(k).content,'The MathWorks, Inc.');
	else
		allfile(k).ismcode = false;
		allfile(k).content = '';
		allfile(k).ismathworks = false;
	end
	
end

%%



allnames = {allfile.name};
for k=1:numel(allnames)
	namematch = find(strcmp(allnames{k},allnames));
	allfile(k).dupes = namematch(namematch~=k); 
end

filefilter = struct(...
	'nonmcode',@(f)~[f.ismcode],...
	'mathworks',@(f)[f.ismathworks],...
	'scrap',@(f)contains(lower({f.name}),'scrap'),...
	'hasdup',@(f)~cellfun(@isempty,{f.dupes}),...
	'rest',@(f) true(size(f)));


file = allfile;
filters = fields(filefilter);
unfiltered = file;
for k=1:numel(filters)
	filtername = filters{k};	
	selection = feval(filefilter.(filtername),file);
	gfile.(filtername) = file(selection);
	file = file(~selection);
end




% matchCnt = cellfun(@numel,namesmatch)
%
% function fdup = findDuplicates(f)
% 	idx = 1:numel(f);
% 	for k=1:numel(idx)
% 	name = file(k).name;
% 	namesmatch{k} = find(strcmp(name,{file(k+1:end).name}));
% 	end
% end