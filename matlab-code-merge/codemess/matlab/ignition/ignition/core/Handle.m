classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		Handle ...
		< ignition.core.Object ...
		& handle
	
	
	
	
	
	properties (SetAccess = protected, Hidden)
		%SettableProps
		%PrivateCopyProps
		GpuRetrievedProps
	end
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = Handle(varargin)
			
			obj = obj@ignition.core.Object(varargin{:});
			
		end
	end
	
	% INITIALIZATION HELPER METHODS
	methods (Access = protected, Hidden)
		function structOutput = updateFieldsFromProps(obj, structInput)
			fn = fields(structInput);
			for kf = 1:numel(fn)
				try
					structOutput.(fn{kf}) = obj.(fn{kf});
				catch
					structOutput.(fn{kf}) = structInput.(fn{kf});
				end
			end
			% todo: make Upper/lowerCamelCase insensitive
		end
		function structOutput = updateFieldsFromPropsCaseInsensitive(obj, structInput)
			fieldNames = fields(structInput);
			%propNames = properties(obj);
			
			% todo
			%fieldMatch = cellfun(@(c,s) find(strcmpi(c,s),1,'first'),...
			%	repmat({propNames},numel(fieldNames),1), fieldNames);
			
			for kf = 1:numel(fieldNames)
				try
					structOutput.(fieldNames{kf}) = obj.(fieldNames{kf});
				catch
					structOutput.(fieldNames{kf}) = structInput.(fieldNames{kf});
				end
			end
			
			% 			function fpMatch = anyCaseMatch
			% todo: make Upper/lowerCamelCase insensitive
		end
	end
	
	% GPU DATA MANAGEMENT
	methods (Access = protected, Hidden)
		function obj = fetchPropsFromGpu(obj) %TODO: manage when this is called??
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			propSettable = ~[oProps.Dependent] & ~[oProps.Constant];
			for k=1:length(propSettable)
				if propSettable(k)
					pn = oProps(k).Name;
					
					% todo
					try
						if isa(obj.(pn), 'gpuArray') && existsOnGPU(obj.(pn))
							obj.(pn) = ignition.shared.onCpu( obj.(pn));
							obj.GpuRetrievedProps.(pn) = obj.(pn);
						end
						% 							obj.(pn) = gather(obj.(pn));
						% 							obj.GpuRetrievedProps.(pn) = obj.(pn);
						% 						end
					catch me
						getReport(me)
					end
				end
			end
		end
		function obj = pushGpuPropsBack(obj) %TODO: ditto??
			if isstruct(obj.GpuRetrievedProps)
				fn = fields(obj.GpuRetrievedProps);
				if ~isempty(fn)
					for kf = 1:numel(fn)
						pn = fn{kf};
						if isprop(obj, pn)
							obj.(pn) = ignition.shared.onGpu( obj.(pn));
							% todo: check that this functions properly
							% 						if obj.UseGpu
							% 							obj.(pn) = gpuArray(obj.GpuRetrievedProps.(pn));
							% 						else
							% 							obj.(pn) = obj.GpuRetrievedProps.(pn);
							% 						end
						end
					end
				end
				obj.GpuRetrievedProps = struct.empty();
			end
		end
	end
	
	
	
	
	
end










% function obj = getSettableProperties(obj)
% 			% todo: allow for static variable to store repeat calls from same class
%
% 			% GET META-CLASS & META-PROPERTIES FOR CALLING CLASS
% 			thisClass = metaclass(obj);
% 			% 			thisSuperClass = thisClass.SuperclassList;
% 			allProps = thisClass.PropertyList(:);
% 			sc = superclasses(obj);
% 			allSetAccess = [allProps.SetAccess];
%
% 			% EXTRACT META-PROPERTY DESCRIPTORS RELATED TO SETTABILITY
% 			% 			isDefinedByThisClass = ([allProps.DefiningClass] == thisClass);
%
%
% 			%isCopyable = ~[allProps.NonCopyable];
% 			isConstant = [allProps.Constant];
% 			isDependent = [allProps.Dependent];
%
% 			isPrivateSet = strcmp('private',allSetAccess);
% 			isProtectedSet = strcmp('protected',allSetAccess);
% 			isInheritedClassSet = false(size(isPrivateSet));
% 			for kProp = 1:numel(allSetAccess)
% 				accessAttribute = allSetAccess{kProp};
% 				inhSet = false;
% 				if ~iscell(accessAttribute)
% 					if isa(accessAttribute, 'meta.class')
% 						inhSet = isa( obj, accessAttribute.Name);
% 					end
% 				else
% 					kAtt = 1;
% 					while (kAtt < numel(accessAttribute)) && ~inhSet
% 						if isa(accessAttribute{kAtt}, 'meta.class')
% 							inhSet = isa( obj, accessAttribute{kAtt}.Name);
% 						end
% 						kAtt = kAtt + 1;
% 					end
% 				end
% 				isInheritedClassSet(kProp) = inhSet;
% 			end
%
% 			propSettable = ...
% 				~isPrivateSet && ...
% 				~isProtectedSet && ...
% 				~isInheritedClassSet && ...
% 				~isConstant && ...
% 				~isDependent;
%
% 			obj.SettableProps = allProps(propSettable);
%
%
% 			% isPrivate, isProtected, isConstant, isTransient
%
%
% 			% 			oMeta = metaclass(obj);
% 			% 			oPropsAll = oMeta.PropertyList(:);
% 			% 			oProps = oPropsAll([oPropsAll.DefiningClass] == oMeta);
% 			% 			propSettable = ~strcmp('private',{oProps.SetAccess}) ...
% 			% 				& ~strcmp('protected',{oProps.SetAccess}) ...
% 			% 				& ~[oProps.Constant] ...
% 			% 				& ~[oProps.Transient];
% 			% 			obj.SettableProps = oProps(propSettable);
%
%
% 			% 			thisClass = metaclass(obj);
% 			% 			thisSuperClass = thisClass.SuperclassList;
% 			% 			allProps = thisClass.PropertyList(:);
% 			% 			mpp = properties(thisClass.PropertyList)
% 			%
% 			% 			for k=1:numel(mpp)
% 			% 				try
% 			% 					if islogical(allProps(1).(mpp{k}))
% 			% 						lp.(mpp{k}) = [allProps.(mpp{k})];
% 			% 					end
% 			% 				catch
% 			% 				end
% 			% 			end
%
% 		end










% [CONSTRUCTOR ALTERNATIVE]
% argsIn = varargin;
%
% % COPY FROM SUB-OBJECT INPUT IF CLONING?? (todo)
% if nargin && isa(argsIn{1}, 'ignition.core.Handle')
% 	obj = copyProps(obj, argsIn{1}); % TODO: make static?
% 	argsIn(1) = [];
% end
%
% % FILL IN SETTABLE PROPERTIES ?? todo
% obj = getSettableProperties(obj);
%
% % PARSE INPUT
% if ~isempty(argsIn)
% 	obj = parseConstructorInput(obj,argsIn{:});
% end
