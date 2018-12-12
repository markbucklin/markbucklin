classdef Accumulator < handle
    % This class is undocumented and subject to change in a future release
    
    % Copyright 2015 The MathWorks, Inc.
    
    properties (Hidden, SetAccess=private)
        S1 % sum of values
        S2 % sum of squares
        N  % sample size iterator
    end
    
    methods
        
        function A = Accumulator()
            A.reset();
        end
        
        function accumulate(A,v)
            % Accumulate value - store in running totals
            A.S1 = A.S1 + v;
            A.S2 = A.S2 + v.^2;
            A.N  = A.N  + 1;
        end
        
        function xbar = mean(A)
            % Get current mean
            
            xbar = A.S1 ./ A.N;
            
        end
        
        function s = std(A)
            % Get current standard deviation
            if A.N == 1
                s = 0;
            else
                s = sqrt( abs( A.N .* A.S2 - A.S1.^2 ) ./ ( A.N.^2 - A.N ) );
            end
        end
        
        function e = stderr(A)
            % Get the Standard Error, representing the following
            % expression for a double vector X:
            %
            %   e = std(X) ./ sqrt(length(X))
            
            if A.N == 1
                e = 0;
            else
                % optimize - avoid calling STD explictly
                e = sqrt( abs(A.N .* A.S2 - A.S1 .^ 2) ./ (A.N-1) ) ./ A.N;
            end
            
        end
        
        function e = relStdErr(A)
            % Get the Relative Standard Error, representing the following
            % expression for a double vector X:
            %
            %   e = std(X) ./ mean(X) ./ sqrt(length(X))
            
            if A.N == 1
                e = 0;
            else
                % optimize - avoid calling STD and MEAN separately
                e = sqrt( abs(A.N .* (A.S2 ./ (A.S1 .^ 2)) - 1) ./ (A.N-1) );
            end
            
        end
        
        function reset(A)
            A.S1 = 0;
            A.S2 = 0;
            A.N  = 0;
        end
        
    end
    
end