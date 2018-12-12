classdef DataBuffer < handle
    %DataBuffer Cache data in a circular buffer.
    
    %   Copyright 2011 The MathWorks, Inc.
    
    properties
        
        % MaxDimensions Data dimensions for all inputs.
        MaxDimensions = [1 1];
        
        % PointsPerSignal Points to store per signal.
        PointsPerSignal = 50000;
        
        Updater = [];
        
        NewData = false;
    end
    
    properties (Access = private)
        CircularBuffer;
    end
    
    properties (SetAccess = private)
        EndTime = -inf;
    end
    
    methods
        
        function this = DataBuffer(maxDimensions, nPoints)
            
            mlock;
            if nargin > 0
                this.MaxDimensions = maxDimensions;
            end
            if nargin > 1
                this.PointsPerSignal = nPoints;
            end
            
            % Create the data buffer using the dimensions and points
            % requested by the constructor.
            initialize(this);
        end
        
        % -----------------------------------------------------------------
        function b = isBusy(this)
            
            % We cannot do anything if the circular buffer is currently
            % empty.  It can be set to empty when data is being added.
            b = isempty(this.CircularBuffer);
        end
        
        % -----------------------------------------------------------------
        function reset(this)
            circBuffer = this.CircularBuffer;
            this.CircularBuffer = [];
            
            if isempty(circBuffer)
                initialize(this);
            else
                
                % Set all of the values back to their defaults.
                for indx = 1:numel(circBuffer)
                    circBuffer(indx).values = NaN(size(circBuffer(indx).values));
                    circBuffer(indx).time   = NaN(size(circBuffer(indx).time));
                    circBuffer(indx).end    = 0;
                    circBuffer(indx).isFull = false;
                end
                this.CircularBuffer = circBuffer;
            end
            this.EndTime = -inf;
        end
        
        % -----------------------------------------------------------------
        function addVector(this, varargin)
            dataBuffer = this.CircularBuffer;
            this.CircularBuffer = [];
            
            endTime = this.EndTime;
            
            for inputIndex = 1:2:numel(varargin)
                portIndex = (inputIndex+1)/2;
                
                endIndex = dataBuffer(portIndex).end;
                time = varargin{inputIndex};
                data = varargin{inputIndex+1};
                
                % Make sure that if the data is a vector that it is a
                % column, but only if the time is also a vector, otherwise
                % the data could be multiple channels with a single time
                % stamp.
                if numel(time) > 1 && isvector(data)
                    data = data(:);
                end
                
                for jndx = 1:numel(time)
                    
                    endIndex = endIndex+1;
                    if endIndex > dataBuffer(portIndex).length
                        endIndex = 1;
                        dataBuffer(portIndex).isFull = true;
                    end
                    dataBuffer(portIndex).values(:, endIndex) = double(data(jndx, :));
                    dataBuffer(portIndex).time(endIndex) = time(jndx);
                    endTime = max(endTime, max(time));
                end
                
                dataBuffer(portIndex).end = endIndex;
            end
            
            this.EndTime        = endTime;
            this.CircularBuffer = dataBuffer;
            this.NewData        = true;
            if ~isempty(this.Updater)
                update(this.Updater);
            end
        end
        
        % -----------------------------------------------------------------
        function addAtInput(this, portIndex, time, values)
            endTime = this.EndTime;
            dataBuffer = this.CircularBuffer;
            this.CircularBuffer = [];
            
            endIndex = dataBuffer(portIndex).end+1;
            if endIndex > dataBuffer(portIndex).length
                endIndex = 1;
                dataBuffer(portIndex).isFull = true;
            end
            
            newSize = size(values);
            if ~isequal(newSize, dataBuffer(portIndex).maxDimensions)
                oldSize = dataBuffer(portIndex).maxDimensions;
                
                % Fill out any dimensions that are completely missing with 1.
                newSize = [newSize ones(1, numel(oldSize)-numel(newSize))];
                
                % Pad the missing dimensions with NaNs.
                values = uiservices.padArray(values, NaN, oldSize);
            end
            dataBuffer(portIndex).dimensions(:, endIndex) = newSize(:);
            
            endTime = max(endTime, time);
            
            dataBuffer(portIndex).values(:, endIndex) = double(values(:));
            dataBuffer(portIndex).time(endIndex)      = time;
            dataBuffer(portIndex).end                 = endIndex;
            
            this.CircularBuffer = dataBuffer;
            this.EndTime = endTime;
            this.NewData = true;
            
            if ~isempty(this.Updater)
                update(this.Updater);
            end

        end
        
        % -----------------------------------------------------------------
        function add(this, varargin)
            %add Add data to the buffer
            %   h.add(time1, values1, time2, values2, etc.)
            
            endTime = this.EndTime;
            
            dataBuffer = this.CircularBuffer;
            this.CircularBuffer = [];
            for inputIndex = 1:2:numel(varargin)
                portIndex = (inputIndex+1)/2;
                endIndex = dataBuffer(portIndex).end+1;
                if endIndex > dataBuffer(portIndex).length
                    endIndex = 1;
                    dataBuffer(portIndex).isFull = true;
                end
                
                newData = varargin{inputIndex+1};
                
                newSize = size(newData);
                if ~isequal(newSize, dataBuffer(portIndex).maxDimensions)
                    oldSize = dataBuffer(portIndex).maxDimensions;
                    
                    % Fill out any dimensions that are completely missing with 1.
                    newSize = [newSize ones(1, numel(oldSize)-numel(newSize))]; %#ok<AGROW>
                    
                    % Pad the missing dimensions with NaNs.
                    newData = uiservices.padArray(newData, NaN, oldSize);
                end
                dataBuffer(portIndex).dimensions(:, endIndex) = newSize(:);
                
                time = varargin{inputIndex};
                
                endTime = max(endTime, time);
                
                dataBuffer(portIndex).values(:, endIndex) = double(newData(:));
                dataBuffer(portIndex).time(endIndex)      = time;
                dataBuffer(portIndex).end                 = endIndex;
            end
            this.CircularBuffer = dataBuffer;
            this.EndTime        = endTime;
            this.NewData        = true;
            if ~isempty(this.Updater)
                update(this.Updater);
            end
        end
        
        % -----------------------------------------------------------------
        function data = getData(this, startingTime, endingTime)
            %GETDATA  Get the data from the data buffer.
            
            dataBuffer = this.CircularBuffer;
            
            if nargin < 3
                endingTime = startingTime;
            end
            
            nInputs = length(dataBuffer);
            
            data = repmat(struct('values', {[]}, ...
                'time', [], ...
                'dimensions', []), 1, nInputs);
            
            for indx = 1:length(dataBuffer)
                endOfBuffer   = dataBuffer(indx).end;
                startOfBuffer = endOfBuffer+1;
                if startOfBuffer > dataBuffer(indx).length || ~dataBuffer(indx).isFull
                    startOfBuffer = 1;
                end
                time = dataBuffer(indx).time;
                
                % Search for the ending index first.  It is very likely that the user
                % is requesting the last time stamp.  This will be much faster than
                % looking for the starting index first by narrowing down the search for
                % the first index.
                if time(endOfBuffer) == endingTime
                    endIndex = endOfBuffer;
                else
                    endIndex = find(time(1:endOfBuffer) <= endingTime, 1, 'last');
                end
                
                if isempty(endIndex)
                    endIndex = find(time(startOfBuffer:end) <= endingTime, 1, 'last')+startOfBuffer-1;
                    
                    if isempty(endIndex)
                        startIndex = [];
                    else
                        
                        % The starting index is definitely after the "start" of the
                        % circular buffer.  If not this means that the startingTime is
                        % below all values of time we still have in the buffer.  In
                        % this case, just get the first value greater than the starting
                        % time.
                        startIndex = find(time(startOfBuffer:endIndex) >= startingTime, 1, 'first')+startOfBuffer-1;
                    end
                else
                    startIndex = find(time(1:endIndex) <= startingTime, 1 , 'last');
                    if isempty(startIndex)
                        startIndex = find(time(startOfBuffer:end) >= startingTime, 1, 'first')+startOfBuffer-1;
                    end
                end
                
                if isempty(endIndex)
                    % NO OP, return the empty values and time.
                elseif endIndex >= startIndex
                    % No need to realign the data for time.
                    data(indx).values     = dataBuffer(indx).values(:, startIndex:endIndex);
                    data(indx).time       = time(startIndex:endIndex);
                    data(indx).dimensions = dataBuffer(indx).dimensions(:, startIndex:endIndex);
                else
                    % Need to realign the data for time.
                    data(indx).values = [dataBuffer(indx).values(:, startIndex:end) ...
                        dataBuffer(indx).values(:, 1:endIndex)];
                    data(indx).time = [time(startIndex:end) time(1:endIndex)];
                    data(indx).dimensions = [dataBuffer(indx).dimensions(:, startIndex:end) ...
                        dataBuffer(indx).dimensions(:, 1:endIndex)];
                end
            end
        end
        
        % -----------------------------------------------------------------
        function set.MaxDimensions(this, newMaxDimensions)
            this.MaxDimensions = newMaxDimensions;
            % Reset the data buffer from scratch.
            initialize(this);
        end
        
        % -----------------------------------------------------------------
        function set.PointsPerSignal(this, newPointsPerSignal)
            this.PointsPerSignal = newPointsPerSignal;
            
            % Reset the data buffer from scratch.
            reset(this);
        end
    end
end

% -------------------------------------------------------------------------
function initialize(this)

maxDims   = this.MaxDimensions;
maxPoints = this.PointsPerSignal;

% The number of signals is equal to the number of rows in
% MaxDimensions because each row represents a signal.
nSignals  = size(maxDims, 1);

% Preallocate the data buffer structure.
dataBuffer = repmat(struct( ...
    'values', {[]}, ...
    'time', [], ...
    'length', 0, ...
    'maxDimensions', [], ...
    'isFull', false, ...
    'end', 0, ...
    'dimensions', []), 1, nSignals);

for inputIndex = 1:nSignals
    
    % Calculate the length of the buffer based on the size of the input.
    thisDims    = maxDims(inputIndex, :);
    channelSize = prod(thisDims);
    maxLength   = ceil(maxPoints/channelSize);
    
    dataBuffer(inputIndex).values        = NaN(channelSize, maxLength);
    dataBuffer(inputIndex).time          = NaN(1, maxLength);
    dataBuffer(inputIndex).length        = maxLength;
    dataBuffer(inputIndex).maxDimensions = thisDims;
    dataBuffer(inputIndex).isFull        = false;
    dataBuffer(inputIndex).end           = 0;
    dataBuffer(inputIndex).dimensions    = repmat(thisDims(:), 1, maxLength);
    
    this.CircularBuffer = dataBuffer;
end
end

% [EOF]
