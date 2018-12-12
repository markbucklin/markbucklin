classdef (CaseInsensitiveProperties, TruncatedProperties, HandleCompatible) Object
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
			
			% FILL IN SETTABLE PROPERTIES ?? todo
			% 			obj = getSettableProperties(obj);
			
			% PARSE INPUT
			if nargin
				obj = parseConstructorInput(obj,varargin{:});
			end
			
		end
	end
	
	% INITIALIZATION HELPER METHODS
	methods	(Access = protected, Hidden)
		function obj = parseConstructorInput(obj, varargin)
			
			% TODO: use parseInputs from parent class?
			
			if (nargin < 2) || isempty(varargin)
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
					isa( firstArg, class(obj)) ; ...% 1
					isstruct( firstArg ) ; ...			% 2
					isa( firstArg, 'char') ;...			% 3
					isnumeric( firstArg ) ],...			% 4
					1, 'first');
				switch firstArgType
					case 1 % IDENTICAL TO CALLING CLASS TYPE INPUT -> CLONE
						obj = copyProps(obj,firstArg);
						% TODO: add check to see if first arg shares a parent class
						% sc = superclasses(obj)
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
						% TODO
				end
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
		function obj = copyProps(obj, srcObj)
			
			% TODO: use ignition.util.getNullConstructor ??
			% 			persistent constructorCache
			% 			constructorCache = ignition.util.persistentMapVariable(constructorCache);
			
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





















% [CONSTRUCTOR ALTERNATIVE]
% argsIn = varargin;
%
% % COPY FROM SUB-OBJECT INPUT IF CLONING?? (todo)
% if nargin && isa(argsIn{1}, 'ignition.core.Object')
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
