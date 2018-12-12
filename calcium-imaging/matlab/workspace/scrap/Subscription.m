classdef Subscription < handle
    %Subscription   Define the Subscription class.
    %   This class wraps message.subscribe and message.unsubscribe so that
    %   their lifecycles are tied to this object.
    
    %   Copyright 2015 The MathWorks, Inc.
    %   $Revision:  $  $Date:  $
    
    properties (SetAccess = protected)
        
        %ID keep track of the subscription for later deletion.
        ID;
    end
    
    methods
        
        function this = Subscription(channelName, fcn)
            %Subscription   Construct the Subscription class.
            this.ID = message.subscribe(channelName, fcn);
        end
        
        function delete(this)
            message.unsubscribe(this.ID)
        end
    end
end

% [EOF]
