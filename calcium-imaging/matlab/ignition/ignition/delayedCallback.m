function delayedCallback( callback, varargin )
    % Copyright 2010 The MathWorks, Inc.
    % Start a timer, which will call the callback function with
    % userData stored in t.UserData    
    persistent t;
    
    if ~isempty(t)
        t.delete;
    end
    % User-interaction: Post event to the queue to be processed later 
    % From test: process callback synchronously (immediately) 
    % In test in callback: error out
    DASdeferCallback(callback,varargin{:});
end
