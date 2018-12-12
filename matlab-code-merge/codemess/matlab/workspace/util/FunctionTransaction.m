classdef FunctionTransaction < handle
    % Transaction class to record and evaluate undo and redo functions
    % associated with an operation
    
    % Copyright 2014 The MathWorks, Inc.
    properties
        Name        % Name of the transaction - used in posting status
        UndoFcn     % How to undo an operation
        RedoFcn     % How to redo an operation
    end
    
    methods
        function this = FunctionTransaction(Name)
            % Constructor
            
            % Set the name of the transaction if applicable
            if nargin < 1
                this.Name = '';
            else
                this.Name = Name;
            end
        end
        
        function undo(this)
            % Evaluate the undo function
            if ~isempty(this.UndoFcn)
                feval(this.UndoFcn{:});
            else
                return;
            end
        end
        
        function redo(this)
            % Evaluate the redo function
            if ~isempty(this.RedoFcn)
                feval(this.RedoFcn{:});
            else
                return;
            end
        end
    end
end