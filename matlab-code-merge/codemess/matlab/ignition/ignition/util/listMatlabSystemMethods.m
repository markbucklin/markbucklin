% listMatlabSystemMethods
%
% or listSuperClassAvailableMethods (TODO)


oMetaClass = ?ignition.core.Object;
supMetaClass = oMetaClass.SuperclassList.SuperclassList(1);
supMetaMeth = supMetaClass.MethodList(cellfun(@ischar, {supMetaClass.MethodList.Access}));
% supMetaClass = ~cellfun(@isempty, strfind({supMetaMeth.Access}, 'public'));
supMetaPubMeth = supMetaMeth( strcmp({supMetaMeth.Access}, 'public'));


fprintf('%s\n',supMetaPubMeth(:).Name);
strvcat(supMetaPubMeth(:).Name)
