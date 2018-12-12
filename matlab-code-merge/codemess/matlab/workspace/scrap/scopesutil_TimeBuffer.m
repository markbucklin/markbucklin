%SCOPESUTIL.TIMEBUFFER - An MCOS buffer object 
%   myTimeBuffer = scopesutil.TimeBuffer  - Buffer for time series.
%   TimeBuffer is used to store sequences of (time,value) pairs.  A
%   TimeBuffer can store several independent time series, indexed by a
%   port number.
%
%   There are 3 ways to construct a TimeBuffer.
%
%   myTimeBuffer = scopesutil.TimeBuffer. This is the default constructor.
%   A single port TimeBuffer will be created. The maximum number of time
%   steps is set to 100. And the maximum dimension is set to [1 1]
%
%   myTimeBuffer = scopesutil.TimeBuffer(NPORTS,BUFFERTYPE). NPORTS must
%   be an unsigned integer. It set the number of ports the TimeBuffer
%   has. BUFFERTYPE is a string. it can either be "SingleRate" or
%   "MultipleRate". The string has to be passed in the exact way written
%   here. Otherwise it will be considered invalid input.
%
%   myTimeBuffer =
%   scopesutil.TimeBuffer(NPORTS,BUFFERTYPE,MAXNUMTIMESTEPS,MAXDIMENSIONS).
%   This is the full construtor for TimeBuffer. MAXDIMENSIONS can be a
%   matrix when the number of dimensions for each port is the same. In
%   this situation, the dimension size per port is represented by one row
%   in the matrix. The port index matches to the row index. MAXDIMENSIONS
%   can also be a cell array when the number of dimensions is not the
%   same for all the port. The number of elements in the cell array
%   equals to the number of ports the TimeBuffer object has. Each cell
%   element stores the maximum dimension size per port.
%
%   scopesutil.TimeBuffer properties:
%       MaxDimensions       - Stores the size of maximum dimensions.
%       MaxNumTimeSteps     - Stores the maximum number of time steps.	 
%       NPorts              - Stores the number of ports. 
%       Type                - Stores the type of the buffer.
%       IsReady             - True if the buffer is ready for read
%       IsFull              - True if the buffer starts overwriting.
%       Complexity          - A vector, true if the corresponding port
%                             support Complex Data type
%   scopesutil.TimeBuffer methods:
%       addTime - Add time to the designated port(s) of TimeBuffer
%       addValue - Add values to the designated port(s) of TimeBuffer
%       clear - Clear the content in the TimeBuffer
%       clearBackTo - Clear the content up to a specfified time point
%       getTimeAndValue - get time and value from designated port(s)
%       getLastTime     - get the most recent time sampling point
%
%   % Examples:
%   
%   % EXAMPLE #1: 
%   % Use the default TimeBuffer constructor:
%       myTimeBuffer = scopesutil.TimeBuffer;
%
%   % EXAMPLE #2: 
%   % Specify the port number and buffer type 
%       myTimeBuffer = scopesutil.TimeBuffer(3,'MultipleRate');
%
%   % EXAMPLE #3: 
%   % Full constructor with MaxDimensions passed as cell array
%       myTimeBuffer = scopesutil.TimeBuffer(2,'MultipleRate',5,...
%       {[2 3 5],[1 3]});
%
%   % EXAMPLE #4: 
%   % Constructor with MaxDimensions passed as a matrix
%       myTimeBuffer = scopesutil.TimeBuffer(2,'SingleRate',5,[2 2; 3 1]);
%
%   % EXAMPLE #5
%   % Full constructor with complexity per port specified by a vector
%   myTimeBuffer = scopesutil.TimeBuffer(3,'SingleRate',5, [1;1;1],...
%               [true,false,true]);


%{
properties
%MaxDimensions - Stores the maximum dimension of data value each port support 
%   It can be a nPorts by nDim 2D matrix, for which nDim represents
%   the number of dimensions for data value for all the ports. E.g. the
%   size of the data value of port i is: maxDimensions(i,1) x
%   maxDimensions(i,2) ... x maxDimensions(i, nDim); it can also be a
%   cell array in which each cell element stores the maximum dimension
%   sizes for a port. 	Read/Write
%
MaxDimensions;
%MaxNumTimeSteps - Store the maximum number of time steps the buffer can hold for all the ports. 
%   It is an integer scalar. It can be read and written. 
%
MaxNumTimeSteps;
%NPorts - Stores the number of ports supported by the buffer. 
%   It is an integer scalar and read only.
%
NPorts;
%Type - Stores the type of the buffer. 
%   It is a string. The only accepted inputs are "SingleRate" and
%   "MultipleRate". It is read only.
%
Type;
%IsReady - The flag indicating whether the buffer is ready for reading or writing.
%   This flag is queried before getting data from the buffer. It is
%   also read only.
%
IsReady;
end
%}

%This class is not intended for customer use and may be removed from future
%releases

%   Copyright 2011 The MathWorks, Inc.
%   Built-in class.


