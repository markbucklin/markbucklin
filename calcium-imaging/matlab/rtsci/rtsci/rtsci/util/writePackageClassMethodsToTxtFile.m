% mobj = metaclass(obj)
% mdsys = metaclass('matlab.system.DefaultObject')

% msys = metaclass(matlab.System);
% mpkg = msys.SuperclassList(1).ContainingPackage;


% mpkg = meta.package.fromName('matlab.system');

mpkg = meta.package.fromName('rtsci');


fid = fopen('rtscipackageclassmethods.txt','w');
for k=1:numel(mpkg.ClassList)
	curClass = mpkg.ClassList(k);
	methList = curClass.MethodList;
	methName =  {methList.Name };
	className = mpkg.ClassList(k).Name;
	if ~isempty(methName)
		fprintf(fid, '==================\n%s\n==================\n',className);
		% 		fprintf(fid, '%s\n',methName{:});
		for m = 1:numel(methList)
			curMeth = methList(m);
			
			% DEFINING CLASS
			isLocalDef = curMeth.DefiningClass == curClass;
			if ~isLocalDef
				fprintf(fid, '\t(@%s)\t',curMeth.DefiningClass.Name);
			end
			
			% METHOD OUTPUT
			if isempty(curMeth.OutputNames)
				outStr = '';
			else
				outStr = ['[ ',sprintf('%s ', curMeth.OutputNames{:}), '] = ' ];
			end
			
			% METHOD NAME
			methStr = curMeth.Name;
			
			% METHOD INPUT
			if isempty(curMeth.InputNames)
				inStr = '()';
			else
				inStr = ['( ',sprintf('%s ', curMeth.InputNames{:}), ')' ];
			end
			
			fprintf(fid, '%s%s%s\n', outStr, methStr, inStr);
			
		end
		
		% PRINT
		fprintf(fid, '\n\n');
		
	end
end
fclose(fid);
