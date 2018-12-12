classdef (HandleCompatible) Object
	%
	% Equivalent to gstreamer element?
	% ---------------->>>>> in progress
	%
	%
	
	
	
	
	
	properties
	end
	
	
	

	
	
	% CONSTRUCTOR
	methods
		function obj = Object(varargin)
			
			% PARSE INPUT
			if nargin
				obj = parseConstructorInput(obj,varargin{:});
			end
			
		end
	end
	
	% INITIALIZATION HELPER METHODS
	methods	(Access = protected, Hidden)
		function obj = parseConstructorInput(obj, varargin)
						
			% RETURN IF NO INPUT PROVIDED
			if (nargin < 2) || isempty(varargin) || isempty(varargin{1})
				return
			else
				args = varargin;
			end
			
			propValPairInput = {};
			nArgs = numel(args);
			if nArgs >= 1
				% EXAMINE FIRST INPUT -> SUBCLASS, STRUCT, DATA, PROPS
				firstArg = args{1};
				firstArgType = find([...
					isobject(firstArg) ; ...		% 1
					isstruct(firstArg ) ; ...		% 2
					isa(firstArg, 'char') ;...	% 3
					isnumeric(firstArg ) ],...	% 4
					1, 'first');
				switch firstArgType
					case 1 % FIRST ARGUMENT IS A MATLAB OBJECT -> CLONE												
						if isa( firstArg, class(obj))
							% IDENTICAL TO CALLING CLASS TYPE INPUT								
							
						else
							% CHECK IF FIRST-ARGUMENT SHARES A PARENT CLASS WITH CONSTRUCTING OBJECT
							newObjSuperClasses = superclasses(obj);
							givenObjSuperClasses = superclasses(firstArg);
							if ~isempty(intersect(newObjSuperClasses, givenObjSuperClasses))
								% ATTEMPT COPY
								obj = copyProps(obj,firstArg);
							end
						end						
						
					case 2 % STRUCTURE REPRESENTATION OF OBJECT
						obj = fillPropsFromStruct(obj,firstArg);
						
					case 3 % 'PROPERTY',VALUE PAIRS						
						propValPairInput = args(:);
						
					case 4 % NUMERIC INPUT -> SERIALIZED OBJECT (todo)
						if isa(firstArg, 'uint8')
							firstArgDeser = distcompdeserialize(firstArg);
							if ~isa(firstArgDeser, 'uint8')
								args{1} = firstArgDeser;
								obj = parseConstructorInput(obj, args{:});
								return
							end
						end
						% byteobj = parallel.internal.pool.serialize(obj);
						% isa(firstArg,'com.mathworks.toolbox.distcomp.util.ByteBufferHandle[]')
						
					otherwise
						% TODO: warning
						
				end
				
				% ALLOW ADDITIONAL ARGUMENTS TO FOLLOW NAME-VALUE COMMA-SEPARATED LIST FORMAT
				if isempty(propValPairInput) && nArgs >=2
					propValPairInput = args(2:end);
				end
			end
			
			% FILL PROPERTIES FROM 'NAME-VALUE' PAIRS -> obj = Object('PropName',propVal)
			numObj = numel(obj);
			if ~isempty(propValPairInput)
				if numel(propValPairInput) >=2
					for kPair = 1:2:length(propValPairInput)
						propName = propValPairInput{kPair};
						propVal = propValPairInput{kPair+1};
						for kObj = 1:numObj
							obj(kObj).(propName) = propVal;
						end
						% alternately [obj(kObj).(propName)] = deal(propVal);
					end
				end
			end
			
		end
		function obj = fillPropsFromStruct(obj, structInput)
			% todo: make array compatible
			fn = fields(structInput);
			for kf = 1:numel(fn)
				try
					obj.(fn{kf}) = structInput.(fn{kf});
				catch
				end
			end
			
			% todo: make Upper/lowerCamelCase insensitive
		end
		function structOutput = getStructFromProps(obj, propList)
			numObj = numel(obj);
			if iscellstr(propList) && ~isempty(propList)
				k = 0;
				numProps = numel(propList);
				while k < numProps
					k = k + 1;
					try
						[structOutput(1:numObj).(propList{k})] = obj.(propList{k});
					catch
					end
				end
			else
				structOutput = struct.empty();
			end
		end
		function obj = copyProps(obj, srcObj)
			
			% TODO: use ign.util.getNullConstructor ??
			% 			persistent constructorCache
			% 			constructorCache = ign.util.persistentMapVariable(constructorCache);
			
			% DETERMINE NUMBER OF OBJECTS BEING COPIED/CREATED
			numSrcObj = numel(srcObj);
			numObjOut = max(numel(obj),numSrcObj);
			
			% GET NULL CONSTRUCTOR FROM CLASSNAME OR CACHED HANDLE (todo)
			% 			className = class(obj);
			% 			classKey = strrep(className,'.','_');
			% 			if iskey(constructorCache,classKey)
			% 				nullConstructor = constructorCache(classKey);
			% 			else
			% 				nullConstructor = str2func(className);
			% 				constructorCache(classKey) = nullConstructor;
			% 			end
			
			srcMetaClass = metaclass(srcObj);
			srcMetaProps = srcMetaClass.PropertyList;
			sourceObjPropNames = {srcMetaProps.Name};
			%sourceObjPropNames = properties(srcObj);
			
			% GET COMMON PROPERTIES (todo: see if this is faster -> 0.3ms
			% commonPropNames = intersect( properties(srcObj), properties(obj))
			commonPropNames = sourceObjPropNames;
			
			if (numSrcObj == numObjOut)
				% EXPANSION OF 'THIS' OBJECT OR DIRECT COPY FROM SOURCE-OBJECT TO OUTPUT-OBJECT
				for kProp = 1:numel(commonPropNames)
					try
						propName = commonPropNames{kProp};
						[obj(1:numObjOut).(propName)] = srcObj.(propName);
					catch
					end
				end
			else
				% REPLICATE SOURCE-OBJECT
				for kProp = 1:numel(commonPropNames)
					try
						propName = commonPropNames{kProp};
						[obj(1:numObjOut).(propName)] = deal(srcObj(1).(propName));
					catch
					end
				end
			end
			
			
			
			% 			% GET META-CLASS INFO FROM INPUT CLASSES
			% 			oMetaIn = metaclass(objInput);
			% 			oMetaOut = metaclass(obj);
			% 			oPropsOut = oMetaOut.PropertyList(:);
			% 			oPropsIn = oMetaIn.PropertyList(:);
			%
			% 			numObjIn = numel(objInput);
			%
			% 			% (NEW)
			% 			if (numel(obj)==1)
			% 				numObjOut = numObjIn;
			% 			else
			% 				numObjOut = numel(obj);
			% 			end
			% 			numObjCopies = max(numObjOut, numObjIn);
			%
			% 			for kCopy = numObjCopies:-1:1
			% 				kObjIn = min(kCopy,numObjIn);
			% 				kObjOut = min(kCopy,numObjOut);
			% 				for kProp = 1:numel(oPropsOut)
			% 					if any(strcmp({oPropsIn.Name},oPropsOut(kProp).Name))
			% 						% TODO: use SettableProps ...
			% 						% may need new settable props prop (internal vs external, private, public, etc)
			% 						if ~strcmp(oPropsOut(kProp).GetAccess,'private') ...
			% 								&& ~oPropsOut(kProp).Constant ...
			% 								&& ~oPropsOut(kProp).Transient
			% 							obj(kObjOut).(oPropsOut(kProp).Name) = objInput(kObjIn).(oPropsOut(kProp).Name);
			% 						end
			% 					end
			% 				end
			% 			end
		end
	end
	
	
	
end
















