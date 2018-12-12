%QueueIterator
% A helper class that wraps a queue-like logic as an Iterator.
%
% This is intended for use by IteratorWrapper, to allow data pushed by the
% Java layer to be pulled by the underlying MATLAB iterator.
%

%   Copyright 2016 The MathWorks, Inc.

classdef (Sealed) QueueIterator < handle
    properties (SetAccess = private)
        % The underlying queue of elements.
        Queue = {};
        
        % A flag that specifies whether any further data might exist.
        UnqueuedDataExists = true;
    end
    
    methods
        % Check whether more data exists.
        function out = hasnext(obj)
            out = obj.UnqueuedDataExists || numel(obj.Queue) > 0;
        end
        
        % Get the next element from the queue.
        function out = getnext(obj)
            assert(~isempty(obj.Queue), 'getnext called when there is no data.');
            out = obj.Queue{1};
            obj.Queue(1) = [];
        end
        
        % Add more elements to the queue.
        function add(obj, isLastOfInput, value)
            obj.Queue(end + 1) = {value};
            obj.UnqueuedDataExists = obj.UnqueuedDataExists && ~isLastOfInput;
        end
    end
end
