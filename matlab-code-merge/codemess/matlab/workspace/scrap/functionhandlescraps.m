%%
[fcnMapLoc, infoMapLoc, fcnMapExt, infoMapExt] = getMethodHandles(obj);
allFcn = [fcnMapLoc.values, fcnMapExt.values]
allInfo = [infoMapLoc.values, infoMapExt.values]
fcnbytype = containers.Map({'simple','classsimple','scopedfunction','nested','anonymous'},{ {}, {}, {}, {}, {}})
infobytype = containers.Map({'simple','classsimple','scopedfunction','nested','anonymous'},{ {}, {}, {}, {}, {}})
infoextbytype = containers.Map({'simple','classsimple','scopedfunction','nested','anonymous'},{ {}, {}, {}, {}, {}})
for k=1:numel(allFcn),
	try
		fcn = allFcn{k};
		info = allInfo{k};
		infoext = functions(fcn);
		fcnbytype(info.type) = [fcnbytype(info.type) {fcn}];
		infobytype(info.type) = [infobytype(info.type) {info}];
		infoextbytype(infoext.type) = [infoextbytype(infoext.type) {infoext}];
	catch
	end
end
clc
fcnbytype('simple')'
celldisp(infobytype('simple')')
fcnbytype('classsimple')'
celldisp(infobytype('classsimple')')
fcnbytype('scopedfunction')'
celldisp(infobytype('scopedfunction')')
fcnbytype('nested')'
celldisp(infobytype('nested')')
fcnbytype('anonymous')'
celldisp(infobytype('anonymous')'))





%%
keysLoc = {
	'anonlocalnestedfcn'
	'localnestedfcn'
	'anonexternalpkgfcn'
	'externalpkgfcn'
	'anonshadowedclassfcn'
	'shadowedclassfcn'
	'anonpublicaccess'
	'publicaccess'
	'anonprivateaccess'
	'privateaccess'
	'anoninternal'
	'internal'
	'anonconstructor'
	'constructor'
	'anonset'
	'set'
	'anonstatic'
	'static'
	
	}


%%
keys = keysLoc;
fcnMap = fcnMapLoc;
infoMap = infoMapLoc;


%%
for k=1:numel(keys)
	try
		fcn = fcnMap(keys{k});
		info = infoMap(keys{k});
		info2 = functions(fcn);
		
		% PRINT RESULTS
		fprintf('\n\n========================\n')
		fprintf('[%s] %s\n',keys{k},func2str(fcn)); %disp(fcn)
		
		% INFO
		disp(info)
		if info2 ~= info
			disp(info2)
		end
		
		if isempty(info.file)
			[wloc, wtype] = which( info.function, '-all' );
		end
		%
		% numInOut = [nargin(fcns{k}), nargout(fcns{k})]
		
	catch me
		%disp(getReport(me))
	end
end

[wloc,wtype] = which(info.function, '-all')