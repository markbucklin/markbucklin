function mshow(metaObj, numTab)

% INCREMENT NUMBER OF TABS ON RECURSIVE CALLS WITH SAME TYPE
if nargin < 2
	numTab = 0;
end

switch numTab
	case 0
		T = '';
	case 1
		T = '\t';
	otherwise
		tc = repmat({'\t'},1,numTab);
		T = [tc{:}];
end

if ischar(metaObj)
	% STRING INPUT -> CLASS OR PACKAGE NAME
	name = metaObj;
	if ~isempty(meta.class.fromName(name))
		% STRING IS NAME OF A CLASS
		mshow(meta.class.fromName(name),numTab)
	else
		% ASSUME STRING IS A PACKAGE NAME
		mshow(meta.package.fromName(name),numTab)
	end
	return
	
	% todo elseif isjava(metaObj), try struct() and get()
	
end

% META-TYPES TO LOOK FOR
metaTypeList = {
	'package'
	'class'
	'method'
	'property'
	'event'};

% ALLOW FOR CUSTOM METATYPES (e.g. 'Simulink.data.MetaClassWithPropertyType')
metaTypeMatch = find(~cellfun(@isempty, ...
	cellfun(@strfind,...
	repmat({lower(class(metaObj))},numel(metaTypeList),1), metaTypeList, ...
	'UniformOutput',false) ), 1, 'first');

if isempty(findstr('meta',lower(class(metaObj))))
	% TRY TO GET THE META-OBJECT
	if isobject(metaObj)
		mshow( metaclass(metaObj) );
	else
		
	end
	return
end

switch metaTypeMatch
	case 1 %'meta.package'
		% META-PACKAGE
		fprintf(['\n','\n',T,'<strong>Package: %s</strong>\n'], metaObj.Name)
		fprintf(['\n',T,'Classes:\n'])
		fprintf([T,'\t%s\n'], metaObj.ClassList.Name)
		mshow(metaObj.FunctionList, numTab)
		numSubPkg = numel(metaObj.PackageList);
		if numSubPkg > 0
			for k=1:numSubPkg
				mshow(metaObj.PackageList(k), numTab + 1)
			end
		end
		
	case 2 %'meta.class'
		% META-CLASS
		fprintf(['\n',T,'Class: %s\n'], metaObj.Name)
		mshow(metaObj.PropertyList, numTab)
		mshow(metaObj.MethodList, numTab)
		mshow(metaObj.EventList, numTab)
		
	case 3 %'meta.method'
		% META-METHOD (OR FUNCTION)
		fprintf(['\n',T,'Methods:\n'])
		fprintf([T,'\t%s\n'], metaObj.Name)
		% todo: make each an html tag and use
		%	[attrNames, methodsData] = methodsview( T, 'noUI')
		% fprintf('<a href="matlab:eval(''beep'')">do beep</a>\n')
		
		
	case 4 %'meta.property'
		% META-PROPERTY
		fprintf(['\n',T,'Properties:\n'])
		fprintf([T,'\t%s\n'], metaObj.Name)
		
	case 5 %'meta.event'
		% META-EVENT
		fprintf(['\n',T,'Events:\n'])
		fprintf([T,'\t%s\n'], metaObj.Name)
		
	otherwise
		% UNKNOWN
		%error('Unknown type: %s', class(metaObj))
		
end


%strvcat(metaObj.Name)