classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		DataflowBlock < ignition.core.Object & handle & matlab.mixin.CustomDisplay
	
	
	
	
	
	% DESCRIPTION
	properties (SetAccess = immutable)
		Name = ''
		ID = ''
	end
	properties (SetAccess = protected)		
		NumInputArguments = 0
		NumOutputArguments = 0
	end
	
	% CONTROL
	properties
		Priority = 0
		Enabled @logical scalar = false % todo
		DispatchMethod @ignition.core.FunctionDispatchType
	end
	
	% IO
	properties (SetAccess = protected)
		InputArguments @cell
		OutputArguments @cell
	end
	
	properties (SetAccess = protected) % Hidden
		ConfigureFcn @function_handle		
		InitializeFcn @function_handle		
		CachePreUpdateFcn @function_handle
		MainOperation @ignition.core.Operation
		CachePostUpdateFcn @function_handle
	end
	properties (SetAccess = protected) % Hidden
		Cache @struct
		Configuration @struct
	end
	% 	properties (SetAccess = protected) % Hidden
	% 		CacheObj @ignition.dataflow.Cache
	% 		ConfigurationObj @ignition.dataflow.Configuration
	% 	end
	
	
	
	
	
	
	
	
	methods
		function obj = DataflowBlock( varargin )
			
			% INITIALIZE WITH DEFAULT NAME
			persistent class_id_factory_store
			
			if isempty(class_id_factory_store)
				class_id_factory_store = containers.Map;
			end
			className = ignition.util.getClassName(obj);
			if ~isKey(class_id_factory_store, className)
				uidGenerator = ignition.util.UniqueIdFactory(className);				
			else
				uidGenerator = class_id_factory_store(className);
			end
			
			% SET NAME & UNIQUE ID
			obj.Name = className;
			obj.ID = uidGenerator.nextId();
						
				
			% INITIALIZE WITH DEFAULT CONFIGURATION
			if isempty(obj.Configuration)
				obj.Configuration = getStructFromPropGroup(obj, 'configuration');
			end
			
			% PARSE (PROPNAME,PROPVALUE) PAIRS OR OTHER TYPE OF INPUT
			if nargin>0
				parseConstructorInput(obj, varargin{:});
			end
			
			
			
		end
		
	end
	
	methods
		function config = configure(obj)
			% Runs a 'ConfigureFcn' adhering to the format:
			%			>> config = myconfigfcn( val1, val2, ...)
			
			% INITIALIZE TO EMPTY STRUCTURE
			config = struct.empty();
			
			% RUN SPECIFIC CONFIGURE-FUNCTION
			if ~isempty(obj.ConfigureFcn)
				argsIn = [ {obj.ConfigureFcn} , getConfigurationValues(obj)];
				config = feval( argsIn{:} );
				obj.Configuration = config;
			end
			
			% UPDATE PROPERTY VALUES BY COPYING FROM STRUCTURE
			fillPropsFromStruct(obj, config);
			
		end
		function cache = initialize(obj)
			% Runs an 'InitializeFcn' adhering to the format:
			%			>> cache = myinitfcn( config, in1, in2, ...)
			% where config is also updated and copied into the cache structure
			
			% INITIALIZE TO EMPTY STRUCTURE
			cache = struct.empty();
			
			% RUN SPECIFIC CONFIGURE-FUNCTION
			if ~isempty(obj.InitializeFcn)
				argsIn = [ {obj.InitializeFcn} , obj.Configuration , obj.InputArguments];				
				cache = feval( argsIn{:} );				
				obj.Cache = cache;				
			end
			
			% UPDATE PROPERTY VALUES BY COPYING FROM STRUCTURE
			fillPropsFromStruct(obj, cache);			
			
		end
	end
	
	
	
	
	
	
	methods (Access = protected)
		function propGroups = getPropertyGroups(obj)
			
			propGroupLabelMap = containers.Map;
			
			% GET METACLASS OF CALLING OBJECT
			mobj = metaclass(obj);
			metaObjectHeirarchy = mobj;
			
			% GET TOP PACKAGE
			pkg = mobj.ContainingPackage;
			while ~isempty(pkg.ContainingPackage)
				pkg = pkg.ContainingPackage;
			end
			parentPackageName = pkg.Name;
			
			% GET SUPERCLASSES OF CALLING OBJECT
			superNames = superclasses(obj);
			for kSuper=1:numel(superNames)
				msuper = meta.class.fromName(superNames{kSuper});
				if ~isempty(msuper.ContainingPackage)
					pkgMatch =  strncmpi( parentPackageName,...
						msuper.ContainingPackage.Name, numel(parentPackageName));
					if pkgMatch
						metaObjectHeirarchy = [metaObjectHeirarchy ; msuper];
					end
				end
			end
			
			% CATEGORIZE PROPERTIES FROM EACH INHERITED CLASS
			for kObj=1:numel(metaObjectHeirarchy)
				
				% EXTRACT LABELS FROM COMMENT ABOVE PROPERTY BLOCKS IN CLASS-CODE
				propBlocks = ignition.util.getLabeledPropertyBlocks(...
					metaObjectHeirarchy(kObj).Name);
				
				for kBlock=1:numel(propBlocks)
					blockLabel = propBlocks(kBlock).Label;
					
					% ADD TO CURRENT LABELS IF NECESSARY
					if ~isKey(propGroupLabelMap, blockLabel)
						propGroupLabelMap(blockLabel) = propBlocks(kBlock).Properties;
					else
						currentProps = propGroupLabelMap(blockLabel);
						newProps = propBlocks(kBlock).Properties;
						propGroupLabelMap(blockLabel) = [currentProps newProps];
					end
				end
				
			end
			
			% CONSTRUCT PROPERTY GROUPS
			groupKeys = keys(propGroupLabelMap);
			for kGroup = 1:numel(groupKeys)
				groupLabel = groupKeys{kGroup};
				groupPropList = propGroupLabelMap(groupLabel);
				propGroups(kGroup) = matlab.mixin.util.PropertyGroup(...
					groupPropList, groupLabel);
			end
						
			
		end
		function s = getStructFromPropGroup(obj, propGroupName)
			
			try
				s = struct.empty();
				allPropGroups = getPropertyGroups(obj);
				isGroup = strcmpi(propGroupName,{allPropGroups.Title});
				propGroup = allPropGroups(isGroup);
				propList = [propGroup.PropertyList];
				for k=1:numel(propList)
					try
						propName = propList{k};
						s.(propName) = obj.(propName);
					catch
					end
				end
			catch
			end
			
		end
		function configVals = getConfigurationValues(obj)
			% configVals = getConfigurationValues(obj)
			% Return the values stored in properties labeled 'CONFIGURATION' in cell array
			configVals = {};
			s = getStructFromPropGroup(obj, 'configuration');
			if ~isempty(s)
				configVals = struct2cell(s);
			end
		end		
		function me = handleError(obj, me)
			% 		function logTaskError(~,src,evnt)
			% todo
			
			% todo: handleError(obj, futureObj)
			
			% 			fprintf('An error occurred : src,evnt sent to base workspace\n')
			% 			assignin('base','src',src);
			% 			assignin('base','evnt',evnt);
			notify(obj, 'Error')
			rethrow(me); %TODO
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end