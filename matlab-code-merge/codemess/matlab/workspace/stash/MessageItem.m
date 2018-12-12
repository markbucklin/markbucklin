classdef MessageItem < matlab.mixin.Copyable
    %MessageItem   Define the MessageItem class.
    
    %   Copyright 2012 The MathWorks, Inc.
    
    properties
        
        %         if isempty(findtype('MessageItemType'))
        %             schema.EnumType('MessageItemType',);
        %         end
        Time
        Type = 'info'; % {'info','warn','fail'}
        Category = '';
        Summary = '';
        Detail = '';
        CategoryLabel = '';
        
    end
    
    methods
        
        function this = MessageItem(mType,mCategory,mSummary,mDetail,mCatLabel)
            %MessageItem Constructor for uiservices.MessageItem
            %  Constructs a new messages for use with MessageLog.
            %  A time/date stamp is automatically added when message
            %  is first created.
            mlock;
            this.Time = now; % date number
            
            if nargin>0, this.Type=mType; end % required arg: info, warn, fail
            if nargin>1, this.Category=mCategory; end
            if nargin>2, this.Summary=mSummary; end
            if nargin>3, this.Detail=mDetail; end
            if nargin < 5
                mCatLabel = this.Category;
            end
            
            this.CategoryLabel = mCatLabel;
        end
        
        function set.Type(this, newType)
            this.Type = lower(newType);
        end
    end
    
    methods (Access = protected)
        function hCopy = copyElement(this)
            hCopy      = uiservices.MessageItem(this.Type, this.Category, ...
                this.Summary, this.Detail, this.CategoryLabel);
            
            % overwrite the Time stamp which is "now" but we want the old
            % time stamp from the original object.
            hCopy.Time = this.Time;
        end
    end
end
% [EOF]
