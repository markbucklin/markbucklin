classdef FixedChunkingFunction < handle & matlab.mixin.Copyable
% Utility class to guarantee fixed chunk sizes by creating a particular
% chunking rule. Use FixedChunkingFunction to wrap the function that you
% would use with partitionfun. FixedChunkingFunction adds a unique
% FixedSizeChunkID (per partition) to the info structure that is passed by
% partitionfun.
%
% NOTE: FixedChunkingFunction must be wrapped by FunctionHandle and
% FixedChunkSize must be the same as MaxNumSlices as for now
% FixedChunkingFunction cannot handle input buffers with more than
% 2*NumSlices, the FunctionHandle enforces small inputs with 'MaxNumSlices'
%
% Use as follows:
% fixed_FH = FixedChunkingFunction(fcn,NumSlices,BrodcastedFlag,OutputEmptyTemplate);
% lazyEval_FH = FunctionHandle(fixed_FH,'MaxNumSlices',NumSlices);
% partitionfun(lazyEval_FH,tall_inputs)
    
    properties (SetAccess = private)
        FunctionHandle
        FixedChunkSize
        BroadcastFlag
        EmptyTemplate
    end
    properties (Transient)
        Inputs = [];
        FixedSizeChunkID = 0;
    end
    methods
        function obj = FixedChunkingFunction(funtionHandle,chunkSize,broadCastflag,emptyTemplate)
            obj.FunctionHandle = funtionHandle;
            obj.FixedChunkSize = chunkSize;
            
            % Indicate which variables are broadcasted, otherwise we'll try
            % to index them to create fixed chunks.
            obj.BroadcastFlag = broadCastflag;
            
            % There are cases where not enough rows are passed in varargin
            % in order to create a chunk, then these are saved in 
            % obj.Inputs, however we need to create an -empty- output that the
            % framework will vertcat. Vercat casts to the upper class, so
            % this -empty- must be created of the same type as FunctionHandle  
            % would return for the future chunks. Thus this information
            % is given when constructing the object.
            if ~iscell(emptyTemplate)
                emptyTemplate = {emptyTemplate};
            end
            obj.EmptyTemplate = emptyTemplate;
            
        end
        
        function [hasFinished, varargout] = feval(obj, info, varargin)

            fitstNonBroadcastedInput = find(~obj.BroadcastFlag,1);
            
            % Is this the last chunk in this partition?
            hasFinished = info.IsLastChunk;
            
            % Start by storing all input as state in this object, combine
            % some remaining input not processed so far.
            if isempty(obj.Inputs) ||  info.RelativeIndexInPartition==1
                obj.FixedSizeChunkID = 0;
                obj.Inputs = varargin;
            else
                for ii = 1:numel(obj.Inputs)
                    if ~obj.BroadcastFlag(ii)
                        obj.Inputs{ii} = vertcat(obj.Inputs{ii}, varargin{ii});
                    end
                end
            end
            
            % Get the size of the data that need to be processed, be
            % carefull because we want to get the size from a
            % non-broadcasted input.
            currentInputSize = size(obj.Inputs{fitstNonBroadcastedInput},1);
            fixedChunkSize = obj.FixedChunkSize;
            
            if currentInputSize>fixedChunkSize
                % For most of the cases we just form the input taking
                % fixedChunkSize from the input buffer and dispatch the
                % functor
                inputs = cell(1,nargin-2);
                for ii = 1:numel(obj.Inputs)
                    if obj.BroadcastFlag(ii)
                        inputs{ii} = obj.Inputs{ii};
                    else
                        % n-d subsref
                        ss = substruct('()',[{1:fixedChunkSize} repmat({':'},1,ndims(obj.Inputs{ii})-1)]);
                        inputs{ii} = subsref(obj.Inputs{ii},ss);
                        if istable(obj.Inputs{ii})
                            % tables are never n-d, so just use parenthesis
                            % syntax:
                            obj.Inputs{ii}(1:fixedChunkSize,:) = [];
                        else
                            obj.Inputs{ii} = subsasgn(obj.Inputs{ii},ss,[]);
                        end
                    end
                end  
                obj.FixedSizeChunkID = obj.FixedSizeChunkID + 1;
                info.FixedSizeChunkID = obj.FixedSizeChunkID;
                [~,varargout{1:nargout-1}] = feval(obj.FunctionHandle, info, inputs{:});
            else
                % There are some cases when we are not at the end of the
                % data however the input buffer does not have enough rows
                % to dispatch the functor. 
                varargout = obj.EmptyTemplate;
            end
            
            if hasFinished
                % If we are at the last chunk (hasFinished==true), just
                % flush the remaining out, it is going to be of
                % fixedChunkSize size or less.
                inputs = cell(1,nargin-2);
                for ii = 1:numel(obj.Inputs)
                    if obj.BroadcastFlag(ii)
                        inputs{ii} = obj.Inputs{ii};
                    else
                        inputs{ii} = obj.Inputs{ii};
                     end
                end  
                info.FixedSizeChunkID = obj.FixedSizeChunkID + 1;
                [~,lastout{1:nargout-1}] = feval(obj.FunctionHandle, info, inputs{:});
                for ii = 1:nargout-1
                    varargout{ii} = vertcat(varargout{ii}, lastout{ii});
                end
                % This functor may be used again for another tree branch so
                % we need to return it to its initial state
                obj.FixedSizeChunkID = 0;
                obj.Inputs = [];
            end
            
        end
    end
    
end
