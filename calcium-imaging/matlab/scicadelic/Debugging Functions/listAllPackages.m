function allpkg = listAllPackages()

allpkg = meta.package.getAllPackages;
allpkg = cat(1,allpkg{:});

fid = fopen('AllPackageList.txt','wt');



for k=1:numel(allpkg)
	fprintf( fid, '=====================================\n');
	fprintf( fid, 'Package: %s\n', allpkg(k).Name);
	fprintf( fid, '=====================================\n');
	
	sname = {allpkg(k).ClassList.Name};
	if ~isempty(sname)		
		fprintf( fid, '--------\n');
		fprintf( fid, '\tClass: %s\n', sname{:} );
	end
	
	sname = {allpkg(k).FunctionList.Name};
	if ~isempty(sname)
		fprintf( fid, '--------\n');
		fprintf( fid, '\tFunction: %s\n', sname{:});
	end
	
	sname = {allpkg(k).PackageList.Name};
	if ~isempty(sname)
		fprintf( fid, '--------\n');
		fprintf( fid, '\tSub-Package: %s\n', sname{:});
	end
		
end
fclose(fid)

