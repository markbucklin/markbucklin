function portStruct = InputPort(this,idx)
% Adapter method for BlockInputPorts to convert its attributes to
% sometyhing that is similar to the RTO.InputPort attributes

% Copyright 2013 The MathWorks, Inc.

feature scopedaccelenablement off;

% Complexity
cmplxStrings = {'Real','Complex'};
portStruct.Complexity = cmplxStrings{this.Complexity(idx)+1};

% Dimensions & SampleTime
portStruct.Dimensions = this.Dimensions(idx);
portStruct.SampleTime = this.SampleTime(idx,:);

% DataType names
portStruct.DataType = this.DataType(idx);
portStruct.AliasedThroughDatatype = this.AliasedThroughDatatype(idx);

% XXX Stub, floating is never a bus signal
portStruct.isBus = 0;

