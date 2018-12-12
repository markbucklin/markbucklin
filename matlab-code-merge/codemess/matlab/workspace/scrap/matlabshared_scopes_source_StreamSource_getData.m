function data = getData(this,startingTime,endingTime,inputIndex)
%GETDATA  Get the data from the data buffer.

%   Copyright 2013-2014 The MathWorks, Inc.

if nargin<2
    startingTime = getTimeOfDisplayData( this );
end
if nargin<3
    endingTime = startingTime;
end
% get the data, port by port, and assemble it
if isempty( this.DataBuffer )
    if nargin>3
        nInputs = 1;
    else
        nInputs = getNumInputs( this );
    end
    data = repmat( struct( 'values', [  ], 'time', [  ] ), 1, nInputs );
else
    if nargin<4
        nInputs = this.DataBuffer.NPorts;
        if isa(this,'Simulink.scopes.source.WiredSource')
            usingDataRepository = this.Application.Specification.IsUsingDataRepository;
            if usingDataRepository
                ts = this.Application.Specification.Block;
                simData = ts.getSimData;  
            end
        end
        % Preallocate only if the input index has not been specified.
        data = repmat( struct( 'values', [  ], 'time', [  ] ), 1, nInputs );
        for indx = 1:nInputs
            if isa(this,'Simulink.scopes.source.WiredSource') && ...
                    usingDataRepository && ~isempty(simData)
                [time, value] = getDataFromLogging(ts, simData, indx, startingTime, endingTime, this.isRunning);
                data( indx ).values = value;
                data( indx ).time = time;
            else
                [data( indx ).time,data( indx ).values] = this.DataBuffer.getTimeAndValue( double( indx ), startingTime, endingTime, true );
            end
        end
    else
        [data.time,data.values] = this.DataBuffer.getTimeAndValue( double( inputIndex ), startingTime, endingTime, true );
    end
end

if this.ShouldFlushBuffer
    clear(this.DataBuffer);
end

end

function [time ,value] = getDataFromLogging(ts, simData, numPort, startingTime, endingTime, isSourceRunning)
if ~isstruct(simData) && ~isa(simData,'Simulink.SimulationData.Dataset')
    simData = simData.';
    time = double(simData(1,:));
    numLines = length(simData(:,1))-1;
    value = [];
    for indx=1:numLines
        value = [value ;simData(indx+1,:)];
    end
    value = double(value);
elseif isstruct(simData)
    value = double(simData.signals(numPort).values);
    time = double(simData.time);
    dims = ndims(value);
    if isequal(numel(time),1)
        value = value(:);
    else
    if dims>2
        value = reshape(value,[],size(value,dims),1);
    else
        value = value.';
    end
    end
    time = time';
else
    value = double(simData.getElement(numPort).Values.Data);
    time = double(simData.getElement(numPort).Values.Time);
    if isequal(numel(time),1)
        value = value(:);
    else
        dims = ndims(value);
        if dims>2
            value = reshape(value,[],size(value,dims),1);
        else
            value = value.';
        end
    end
    time = time';
end
if ~isscalar(time) && ~isempty(time) && ts.VariableDimension
    value = checkForComplexNaNSignals(value);
end

if isempty(time)
    time = []; value = [];
elseif ~isSourceRunning
    [time, value] = getDataInRange(time,value, startingTime, endingTime);
end

if isscalar(time)
    value = value(:);
end

end

function[time, value] = getDataInRange(timeValues,value, startingTime, endingTime)
startIdx = find(timeValues < startingTime,1,'last');
% Check for negative cases.
if (isempty(startIdx) && endingTime < timeValues(1))
    value = [];
    time = [];
else    
    endIdx = find(timeValues > endingTime,1);
    
    if isempty(startIdx)
        startIdx = 1;
    end    
    if isempty(endIdx)
        endIdx = length(timeValues);
    end    
    value = value(:,startIdx:endIdx);
    time = timeValues(:,startIdx:endIdx);
end
end

function nanValue =  checkForComplexNaNSignals(value)
nanValue = [];
for indx=1:length(value(:,1))
    tempVal = value(indx,:);
    tempVal(isnan(tempVal)) = complex(nan,nan);
    nanValue = [nanValue ; tempVal];    
end
end

