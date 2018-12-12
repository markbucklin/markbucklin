
libname = 'scicadelic.'
classname = 'SciCaDelicSystem';
fullname = [libname,classname];
fname = which(fullname);


obj = eval(fullname);
oMeta = metaclass(obj);
oProps = oMeta.PropertyList(:);
oProps = oProps([oProps.DefiningClass] == oMeta);
propNames = {oProps.Name}'

text = fileread(fname);

for k=1:numel(propNames)
   currName = propNames{k};
   camelName = [lower(currName(1)) , currName(2:end)];
   ProperName = [upper(currName(1)) , currName(2:end)];
   text = strrep(text, camelName, ProperName);   
end

fid = fopen([classname,'.m'],'w');
fwrite(fid, text)
fclose(fid);




subclassnames = {...
   'TiffStackLoader',...
   'MotionCorrector',...
   'LocalContrastEnhancer'}


for n = 1:numel(subclassnames)
   classname = subclassnames{n};
   fullname = [libname,classname];
   fname = which(fullname);
   text = fileread(fname);   
   for k=1:numel(propNames)
	  currName = propNames{k};
	  camelName = [lower(currName(1)) , currName(2:end)];
	  ProperName = [upper(currName(1)) , currName(2:end)];
	  text = strrep(text, camelName, ProperName);
   end
   fid = fopen([classname,'.m'],'w');
   fwrite(fid, text)
   fclose(fid);   
end


for n = 1:numel(subclassnames)
   classname = subclassnames{n};
   fullname = [libname,classname];
   fname = which(fullname);
   
   
   obj = eval(fullname);
   oMeta = metaclass(obj);
   oProps = oMeta.PropertyList(:);
   oProps = oProps([oProps.DefiningClass] == oMeta);
   propNames = cat(1, propNames(:),  {oProps.Name}');
   text = fileread(fname);
   for k=1:numel(propNames)
	  currName = propNames{k};
	  camelName = [lower(currName(1)) , currName(2:end)];
	  ProperName = [upper(currName(1)) , currName(2:end)];
	  text = strrep(text, camelName, ProperName);
   end
   fid = fopen([classname,'.m'],'w');
   fwrite(fid, text)
   fclose(fid);
   
end
