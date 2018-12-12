classdef StructAccessRecorder < handle & dynamicprops
	
	
	properties (SetAccess = protected, Hidden)
		StructInternal @struct
		FieldWriteCount = []
		FieldReadCount = []
		FieldWriteFlag @logical
		FieldReadFlag @logical
		FieldNameList @cell
		FieldRecordIdx @struct
		PropReadListener @event.proplistener
		PropWriteListener @event.proplistener
	end
	
	
	
	methods
		function obj = StructAccessRecorder( structInput)
			if nargin
				N = numel(structInput);
				if N==1
					wrapStruct(obj, structInput)
				else
					obj(N) = ignition.util.StructAccessRecorder();
					for k=1:N
						obj(k) = ignition.util.StructAccessRecorder(structInput(k));
					end
					reshape(obj, size(structInput));
				end
			end
		end
		function wrapStruct(obj, s)
			
			% EXAMINE STRUCT
			assert(isstruct(s), 'Ignition:Util:StractAccessRecorder:NonStructInput');
			assert(isscalar(s), 'Ignition:Util:StractAccessRecorder:NonScalarInput');
			fields = fieldnames(s);
			vals = struct2cell(s);
			numFields = numel(vals);
			cellIdx = num2cell(1:numFields)';
			
			% INITIALIZE RECORD
			obj.FieldNameList = fields;
			obj.FieldRecordIdx = cell2struct( cellIdx,fields,1);
			obj.FieldReadCount = zeros(numFields,1);
			obj.FieldWriteCount = zeros(numFields,1);
			obj.FieldReadFlag = false(numFields,1);
			obj.FieldWriteFlag = false(numFields,1);
			
			% ADD PROPERTIES TO REFLECT STRUCTURE
			for k=1:numFields
				prop(k) = addprop(obj, fields{k});
				obj.(fields{k}) = vals{k};
				
				% MONITOR READS
				prop(k).GetObservable = true;				
												
				% MONITOR WRITES
				prop(k).SetObservable = true;
				% 				prop(k).AbortSet = true;
								
			end
			
			% CONSTRUCT LISTENERS WITH CALLBACK FOR ACCESS EVENT
			obj.PropReadListener = addlistener(obj, prop, 'PostGet', @recordPropAccess);
			obj.PropWriteListener = addlistener(obj, prop, 'PostSet', @recordPropAccess);
			% CONSTRUCT LISTENERS WITH CALLBACK FOR ACCESS EVENT
			% 			obj.PropReadListener = addlistener(obj, prop, 'PostGet', @(src,evnt)recordPropAccess(obj,src,evnt));
			% 			obj.PropWriteListener = addlistener(obj, prop, 'PostSet', @(src,evnt)recordPropAccess(obj,src,evnt));
			
			% CALLBACK
			function recordPropAccess(src,evnt)
				% src is the same meta.property object defined using 'prop' above				
				propName = src.Name;
				switch evnt.EventName
					case 'PreGet'
						recordReadAccess(obj, propName)
					case 'PostGet'
						recordReadAccess(obj, propName)
					case 'PreSet'
						recordWriteAccess(obj, propName)
					case 'PostSet'
						recordWriteAccess(obj, propName)
				end
			end			
		end
		function recordReadAccess(obj, fieldName)
			idx = obj.FieldRecordIdx.(fieldName);
			obj.FieldReadCount(idx) = obj.FieldReadCount(idx) + 1;
			obj.FieldReadFlag(idx) = true;
		end
		function recordWriteAccess(obj, fieldName)
			idx = obj.FieldRecordIdx.(fieldName);
			obj.FieldWriteCount(idx) = obj.FieldWriteCount(idx) + 1;
			obj.FieldWriteFlag(idx) = true;
		end
		function [readCount, writeCount] = reportCount(obj)
			fields = obj.FieldNameList;
			readCount = cell2struct(num2cell(obj.FieldReadCount(:)), fields, 1);
			writeCount = cell2struct(num2cell(obj.FieldWriteCount(:)), fields, 1);
		end
		function resetCount(obj)
			obj.FieldReadCount = obj.FieldReadCount*0;
			obj.FieldWriteCount = obj.FieldWriteCount*0;
			obj.FieldReadFlag = bsxfun(@and, obj.FieldReadFlag, false);
			obj.FieldWriteFlag = bsxfun(@and, obj.FieldWriteFlag, false);
		end
		function s = getStruct(obj)
			fld = fields(obj);
			for k=1:numel(fld)
				s.(fld{k}) = obj.(fld{k});
			end
		end
	end
	
	% IMPOSTER FUNCTIONS
	methods 
		function flag = isstruct(~)
			flag = true;			
		end
		function names = fields(obj)
			names = properties(obj);
		end
		function names = fieldnames(obj)
			names = properties(obj);
		end		
	end
	
end







% cm = ignition.alpha.CacheManager

% TWO-LEVEL-CACHE
% obj = ignition.alpha.TwoLevelCache
% add(obj, 'Configuration Input', 'FileInputObj', @ignition.io.FileWrapper )
% add(obj, 'Configuration Input', 'ParseFrameInfoFcn', @ignition.io.tiff.parseHamamatsuTiffTag )
% add(obj, 'Tunable Task Settings', 'FirstFrameIdx', 0)
% add(obj, 'Tunable Task Settings', 'NextFrameIdx', 0)
% add(obj, 'Tunable Task Settings', 'LastFrameIdx', 0)
% add(obj, 'Tunable Task Settings', 'NumFramesPerRead', 8)
% retrieve( obj, 'NumFramesPerRead')
% [~,config] = retrieveArrayIfPresent( obj, 'ConfigurationInput')
% [~,config] = retrieveArrayIfPresent( obj, 'Configuration Input')