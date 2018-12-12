


%%
searchDirNames = {'pipeline','scicadelic','util','workspace','ignition'}
for name=searchDirNames
	c.(name{:}) = dir2([pwd,filesep,name{:}],'.m'); 
end
cc = struct2cell(c)
c.all = cat(2, cc{:})
for k=1:numel(c.all)
	[c.allpaths{k}, c.allnames{k},~] = fileparts(c.all{k}); 
end

%%
hasdup = zeros(size(c.allnames));
c.dupidx = cell(size(c.allnames));
for k=1:numel(c.allnames)
	name = c.allnames{k};
	match = strcmp(name,c.allnames);
	if nnz(match)>1		
		hasdup(k) = nnz(match)-1;
		idx = find(match);
		c.dupidx{k} = idx(idx~=k);
	end
end
	