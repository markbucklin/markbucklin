%% GET FLAT ARRAY OF ALL META CLASSES
meta.internal.updateClasses
[M,MEX,C] = inmem('-completenames');
mc1 = cellfun(@meta.class.fromName, C, 'uniformoutput',false);
mc2 = meta.class.getAllClasses;
numclass = 0;
mc = unique([mc1{:}, mc2{:}]);
allmc = mc(:);
while (numel(allmc) > numclass)	
	numclass = numel(allmc);
	hasInferior = ~cellfun(@isempty, {mc.InferiorClasses});
	hasSuper = ~cellfun(@isempty, {mc.SuperclassList});
	mcinf = cat(1, mc(hasInferior).InferiorClasses);
	if iscell(mcinf), mcinf = cat(1,mcinf{:}); end
	mcsuper = cat(1, mc(hasSuper).SuperclassList);
	mc = unique(cat(1, mcinf, mcsuper));
	mc = setdiff(mc,allmc);
	allmc = cat(1, mc(:), allmc(:));	
end
strvcat(allmc.Name)

% ALL CLASS METHODS
allmcmet = cat(1,allmc.MethodList);
strvcat(allmcmet.Name);
 

%% GET FLAT ARRAY OF ALL META PACKAGES
numpkg = 0;
mp = [meta.package.getAllPackages{:}]
allmp = mp(:);
while (numel(mp) > numpkg)	
	numpkg = numel(mp);
	hasPkg = ~cellfun(@isempty, {mp.PackageList});
	isInPkg = ~cellfun(@isempty, {mp.ContainingPackage});
	mpsub = cat(1, mp(hasPkg).PackageList);
	mpcontain = cat(1, mp(isInPkg).ContainingPackage);
	mp = unique(cat(1, mpsub, mpcontain));
	mp = setdiff(mp,allmp);
	allmp = cat(1, mp(:), allmp(:));
	%mp = unique(cat(1, mp(:), mp.PackageList));
end



%% mtree
strings( List( Ins(mt.root)))
strings( List( Outs(mt.root)))
mfunc = mt.select(find(iskind(mt,'FUNCTION')))
strings(mfunc.Fname)


% DETERMINE POTENTIAL INPUT TYPES
% functionhintsfunc