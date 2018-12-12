% mobj = metaclass(obj)
% mdsys = metaclass('matlab.system.DefaultObject')

% msys = metaclass(matlab.System);
% mpkg = msys.SuperclassList(1).ContainingPackage;

mpkg = meta.package.fromName('matlab.system');



fid = fopen('systempackageclassmethods.txt','w');
for k=1:numel(mpkg.ClassList),
	methList =  {mpkg.ClassList(k).MethodList.Name };
	className = mpkg.ClassList(k).Name;
	if ~isempty(methList)
		fprintf(fid, '==================\n%s\n==================\n',className);
		fprintf(fid, '%s\n',methList{:});
		fprintf(fid, '\n\n');
	end
end
fclose(fid)