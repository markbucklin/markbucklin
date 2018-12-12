%%
import java.util.jar.*
import java.io.*
jarList = javaclasspath('-all');
[selection,ok] = listdlg('ListString',jarList,'ListSize',[600 600]);

%%
if ok
	jarFile = jarList(selection);
	
	for file = jarFile
		fis = FileInputStream(file{:});
		jis = JarInputStream(fis);
		fileClose = onCleanup(@() closeFile(jis, fis));
		jarClass = {}
		jarEntry = jis.getNextJarEntry;
		while ~isempty(jarEntry)
			name = char(jarEntry.getName);
			if endsWith(name,'.class')
				className = extractBefore(strrep(name,'/','.'),'.class');				
				jarClass{end+1,1} = className;
				[attrNames,methodsData] = methods(className,'-full');
				% todo structure attrNames and methodsData
			end
			jarEntry = jis.getNextJarEntry;
		end
	end
	
end

% ava.lang.Class.getMethods
% com.mathworks.jmi.OpaqueJavaInterface.getMethodDescriptions(OpaqueJavaInterface.java:278)