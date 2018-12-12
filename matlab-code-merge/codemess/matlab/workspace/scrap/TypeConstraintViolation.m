classdef TypeConstraintViolation < handle
    %TypeConstraintViolation   Define the TypeConstraintViolation class.
    
    %   Copyright 2012 The MathWorks, Inc.
    
    properties
        Type;
        Constraint;
        Details;
    end
    
    methods
        
        function this = TypeConstraintViolation(theType,theConstraint,theDetails)
            %ExtTypeConstraintViolation Extension type constraint violation object.
            %  ExtTypeConstraintViolation(Type,Constraint,Details) creates a violation
            %  object that specifies a constraint violated by configuration.  Details
            %  is an optional string describing the specific violation.
            
            this.Type = theType;
            this.Constraint = theConstraint;
            if nargin>2
                this.Details = theDetails;
            end
        end
        
        function s = message(this)
            %MESSAGE Return formatted violation message.
            
            % Format message string:
            % '    Type (Constraint:Details)'
            % Ex:
            % '    General (EnableAll:)'
            %
            % Note: uses 4 leading spaces, so that display works
            %       well with ExtTypeConstraintViolationDb display method.
            
            if isempty(this.Details)
                s = sprintf('    %s, %s\n', ...
                    this.Type, ...
                    this.Constraint);
            else
                s = sprintf('    %s%s, %s%s (%s)\n', ...
                    getString(message('Spcuilib:uiservices:LabelMessageLogType')), this.Type, ...
                    uiscopes.message('TextConstraint'), this.Constraint, ...
                    this.Details);
            end
        end
    end
end

% [EOF]
