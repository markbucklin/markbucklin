 function this = utfillfromstruct(this, datasetStruct)

%   Copyright 2015 The MathWorks, Inc.

     if ~isempty(datasetStruct)
         assert(locDatasetIsInStructStorage(datasetStruct));
         assert(this.numElements == 0);
         this = utSetElements( ...
             this, ...
             locConstructMcosElementArrayFromStructStorage( ...
             datasetStruct.Elements ...
             ) ...
             );
     else
         this = [];
     end
 end
 
%% Function locDatasetIsInStructStorage ----------------------------------------
function bRet = locDatasetIsInStructStorage(ds) 
% Return TRUE if ds is a MATLAB structure of specific kind used to store
% Simulink logged data without using MCOS objects
    if ~isstruct(ds),
        bRet = false;
        return
    end
    targetFields = { ...
        'Name'; ...
        'Elements' ...
        };
    fields = fieldnames(ds);
    if ~isequal(fields, targetFields),
        bRet = false;
        return
    end
    if ~ischar(ds.Name),
        bRet = false;
        return
    end
    if ~iscell(ds.Elements),
        bRet = false;
        return
    end
    if size(ds.Elements, 1) ~= 1 && size(ds.Elements, 2) ~= 1,
        bRet = false;
        return
    end
    for idx = 1 : length(ds.Elements),
        el = ds.Elements{idx};
        if ~locElementIsInStructStorage(el),
            bRet = false;
            return
        end
    end
    bRet = true;
end

%% Function locElementIsInStructStorage ----------------------------------------
function bRet = locElementIsInStructStorage(el) 
% Return TRUE if el is a MATLAB structure of specific kind used to store
% Simulink logged data without using MCOS objects
    if ~isstruct(el),
        bRet = false;
        return
    end
    signalElemTargetFields = { ...
        'ElementType';
        'Name'; ...
        'PropagatedName'; ...
        'BlockPath'; ...
        'PortType'; ...
        'PortIndex'; ...
        'Values' ...
        };
    stateElemTargetFields = { ...
        'ElementType';
        'Name'; ...
        'BlockPath'; ...
        'StateType'; ...
        'Values' ...
        };
    fields = fieldnames(el);
    if ~isequal(fields, signalElemTargetFields) && ...
       ~isequal(fields, stateElemTargetFields),
        bRet = false;
        return
    end
    if ~ischar(el.Name),
        bRet = false;
        return
    end
    if ~iscellstr(el.BlockPath),
        bRet = false;
        return
    end
    if strcmp(el.ElementType, 'signal')
        if ~ischar(el.PortType),
            bRet = false;
            return
        end
        if ~isscalar(el.PortIndex) || ...
                ~isnumeric(el.PortIndex) || ...
                ~isreal(el.PortIndex) || ...
                el.PortIndex ~= uint32(el.PortIndex) || ...
                el.PortIndex < 1,
            bRet = false;
            return        
        end
    else
        if ~ischar(el.ElementType),
            bRet = false;
            return
        end 
    end
    if ~locValuesIsAobStructStorage(el.Values),
        bRet = false;
        return        
    end
    bRet = true;    
end

%% Function locValuesIsAobStructStorage -----------------------------------
function bRet = locValuesIsAobStructStorage(val)
% locValuesIsAobStructStorage - detects if the given object is a specific 
% structure used for internal storage of AoB logged data.

    if locValuesIsTimeseriesStructStorage(val),
        bRet = true;
        return
    end
    if ~isstruct(val),
        bRet = false;
        return
    end
    fields = fieldnames(val);
    for dimIdx = 1 : length(val),
        for fieldIdx = 1 : length(fields);
            field = fields{fieldIdx};
            if ~locValuesIsAobStructStorage(val(dimIdx).(field)),
                bRet = false;
                return
            end
        end
    end   
    bRet = true;
end

%% Function locValuesIsTimeseriesStructStorage ----------------------------
function bRet = locValuesIsTimeseriesStructStorage(val)
% locValuesIsTimeseriesStructStorage - detects if the given
% object is a specific structure used for internal storage of timeseries 
% objects.

    if ~isstruct(val),
        bRet = false;
        return
    end
    targetFields = { ...
        'Name'; ...
        'Units'; ...
        'Data'; ...
        'Time'; ...
        'Interp3d'; ...
        'DuplicateTimes'; ...
        'InterpMethod' ;...
        'SignalAttributes'...
        };
    fields = fieldnames(val);
    if ~isequal(fields, targetFields),
        bRet = false;
        return
    end
    if ~locTimeOrDataIsRecordStructStorage(val.Time),
        bRet = false;
        return        
    end
    if ~locTimeOrDataIsRecordStructStorage(val.Data),
        bRet = false;
        return        
    end
    if ~isscalar(val.Interp3d) || ~islogical(val.Interp3d),
        bRet = false;
        return        
    end
    if ~isscalar(val.DuplicateTimes) || ~islogical(val.DuplicateTimes),
        bRet = false;
        return        
    end
    if ~ischar(val.InterpMethod),
        bRet = false;
        return        
    end
    if ~ischar(val.Name),
        bRet = false;
        return        
    end
    
    if ~isstruct(val.SignalAttributes),
        bRet = false;
        return
    end
    
    bRet = true;    
end

%% Function locTimeOrDataIsRecordStructStorage ---------------------------------
function bRet = locTimeOrDataIsRecordStructStorage(val)
% locTimeOrDataIsRecordStructStorage - detects if the given
% object is a specific structure used for internal storage of time or data
% using record format.

    if ~isstruct(val),
        bRet = false;
        return
    end
    targetFields = { ...
        'RecordStorageKey'; ...
        'Data' ...
        };
    fields = fieldnames(val);
    if ~isequal(fields, targetFields),
        bRet = false;
        return
    end
    
    if ~ischar(val.RecordStorageKey),
        bRet = false;
        return        
    end
    
    if ~isnumeric(val.Data) && ~islogical(val.Data)
        bRet = false;
        return        
    end
    
    bRet = true;
end

%% Function locConstructMcosElementFromStructStorage ----------------------
function obj = locConstructMcosElementFromStructStorage(strct) 
% locConstructMcosElementFromStructStorage - construct an MCOS object for a
% given element represented using the specific MATLAB structure storage.

   if(strcmp(strct.ElementType,'signal'))
       obj = Simulink.SimulationData.Signal;
       
       obj.PortType = strct.PortType;
       obj.PortIndex = strct.PortIndex;
       
       blockPath = Simulink.SimulationData.BlockPath(strct.BlockPath, '');
       obj.BlockPath = blockPath;
       obj.Values = locConstructMcosValuesFromStructStorage(strct.Values);
       
       obj.PropagatedName = strct.PropagatedName;
       obj.Name = strct.Name;   
   else
       obj = Simulink.SimulationData.State;
       
       obj.Label = strct.StateType;
       
       blockPath = Simulink.SimulationData.BlockPath(strct.BlockPath, '');
       obj.BlockPath = blockPath;
       obj.Values = locConstructMcosValuesFromStructStorage(strct.Values);
       
       obj.Name = strct.Name;    
   end
end

%% Function locConstructMcosElementArrayFromStructStorage -----------------
function objArray = ...
    locConstructMcosElementArrayFromStructStorage(structArray) 
% locConstructMcosElementArrayFromStructStorage - construct a cell array of
% MCOS dataset elements for a given cell array of elements represented 
% using the specific MATLAB structure storage.
    nElements = length(structArray);
    objArray = cell(1, nElements);
    for idx = 1 : nElements,
        objArray{idx} = ...
            locConstructMcosElementFromStructStorage(structArray{idx});
    end
end


%% Function locConstructMcosTimeseriesFromStructStorage -------------------
function obj = locConstructMcosTimeseriesFromStructStorage(strct)
% locConstructMcosTimeseriesFromStructStorage - converts leaf structures 
% used for internal storage of timeseries object into a timeseries object.    

    if strcmp(strct.Time.RecordStorageKey, 'Compressed'),
        starttime = strct.Time.Data(1);
        increment = strct.Time.Data(2);
        len = strct.Time.Data(3);
        nSamples = len;
    else
        assert(strcmp(strct.Time.RecordStorageKey, 'Raw'));
        time = strct.Time.Data;
        nSamples = length(time);
    end
    
    assert(strcmp(strct.Data.RecordStorageKey, 'Raw'));
    data = strct.Data.Data;
    
    className = strct.SignalAttributes.ClassName;
    dims = strct.SignalAttributes.Dimension;
    dims_reshape = ([dims; nSamples]);
    
    if(strcmp(className, 'fixed-point') || ...
            strcmp(className,'scaled-double') )
        sign = strct.SignalAttributes.FixedPointParameters.isSigned;
        wordLen = strct.SignalAttributes.FixedPointParameters.WordLength;
        slopeAdj = strct.SignalAttributes.FixedPointParameters.SlopeAdjustmentFactor;
        exp = strct.SignalAttributes.FixedPointParameters.Exponent;
        bias = strct.SignalAttributes.FixedPointParameters.Bias;
               
        if(slopeAdj == 1 && bias == 0)
            NT = numerictype(sign, wordLen, -exp);
        else
            NT = numerictype(sign, wordLen, slopeAdj, exp, bias);
        end

        if(strcmp(className,'scaled-double'))
            NT = numerictype(NT, 'DataType', 'ScaledDouble');
            fh = @sim2fi;
            data = fh(data, NT);
            data = Simulink.SimulationData.createScaledDoubleFI(data.double,NT);
        else
            fh = @sim2fi;
            data = fh(data, NT);
        end
    else
        if(~strcmp(className, 'double') && ...
           ~strcmp(className, 'single') && ...
           ~strcmp(className, 'int8') && ...
           ~strcmp(className, 'uint8') && ...
           ~strcmp(className, 'int16') && ...
           ~strcmp(className, 'uint16') && ...
           ~strcmp(className, 'int32') && ...
           ~strcmp(className, 'uint32') && ...
           ~strcmp(className, 'logical'))
            fh = str2func(className);
            data = fh(data);
        end
    end
    
    complexity = strct.SignalAttributes.Complexity;
    if complexity == true
        data_complex = complex(data(1:2:end-1), data(2:2:end)) ;
 
    else
        data_complex = data;
    end
    
    data_reshape = reshape(data_complex, dims_reshape');
    
    if length(dims) == 1
        if strcmp(className, 'logical')
            data_reshape = data_reshape';
        else
            data_reshape = data_reshape.';
        end
    end   
    
    if strcmp(strct.Time.RecordStorageKey, 'Compressed'),
        obj = ...
            Simulink.SimulationData.TimeseriesUtil.utcreateuniformwithoutcheck( ...
            data_reshape, ...
            len, ...
            starttime, ...
            increment, ...
            strct.Interp3d, ...
            strct.Units, ...
            strct.InterpMethod ...
            );
    else
        obj = Simulink.SimulationData.TimeseriesUtil.utcreatewithoutcheck( ...
            data_reshape, ...
            time, ...
            strct.Interp3d, ...
            strct.DuplicateTimes, ...
            strct.Units, ...
            strct.InterpMethod ...
            );
    end
    obj.Name = strct.Name;
end

%% Function locConstructMcosValuesFromStructStorage -----------------------
function obj = locConstructMcosValuesFromStructStorage(strct)
% locConstructMcosValuesFromStructStorage - converts structures used for
% internal storage into a structure of timeseries objects.
    if locValuesIsTimeseriesStructStorage(strct),
        obj = locConstructMcosTimeseriesFromStructStorage(strct);
    else
        fields = fieldnames(strct);
        dim = [length(fields), size(strct)];
        emptyData = cell(dim);
        obj = cell2struct(emptyData, fields, 1);
        for idx = 1 : numel(strct),
            for fieldIdx = 1 : length(fields),
                field = fields{fieldIdx};
                obj(idx).(field) = ...
                    locConstructMcosValuesFromStructStorage( ...
                    strct(idx).(field) ...
                    );
            end
        end
    end    
end

% LocalWords:  el Aob Ao utcreatewithoutcheck strct
