classdef (Hidden, Sealed) Percentile < handle
    %Percentile Defines Percentile class for COMMMEASURE package
    
    %   Copyright 2008-2011 The MathWorks, Inc.
    
    %===========================================================================
    % Public properties
    properties
        PercentileValue = 95;
        Tail = 'Lower';
        MaxValue = 1;
        MinValue = 0;
        StepSize = 0.01;
    end
    
    %===========================================================================
    % Read-only, Dependent properties
    properties (SetAccess = protected, Dependent)
        PercentilePoint;
    end
    
    %===========================================================================
    % Protected properties
    properties (SetAccess = protected, GetAccess = protected)
        DataHist
        BinEdges
    end
    
    %===========================================================================
    % Public methods
    methods
        function this = Percentile(varargin)
            reset(this)
        end
        %-----------------------------------------------------------------------
        function reset(this)
            this.BinEdges = [-inf; (this.MinValue:this.StepSize:this.MaxValue)'; inf];
            this.DataHist = zeros(size(this.BinEdges));
        end
        %-----------------------------------------------------------------------
        function update(this, x)
            tempHist = histc(x, this.BinEdges);
            this.DataHist = this.DataHist + tempHist(:);
        end
        %-----------------------------------------------------------------------
        function h = copy(this)
            for p=1:length(this)
                hTemp = commmeasure.Percentile;
                hTemp.PercentileValue = this.PercentileValue;
                hTemp.Tail = this.Tail;
                hTemp.MaxValue = this.MaxValue;
                hTemp.MinValue = this.MinValue;
                hTemp.StepSize = this.StepSize;
                hTemp.DataHist = this.DataHist;
                hTemp.BinEdges = this.BinEdges;
                h(p) = hTemp; %#ok<AGROW>
            end
        end
    end
    
    %===========================================================================
    % Protected methods
    methods (Access = private)
        function v = calcPercentile(this)
            bins = this.BinEdges(2:end);
            bins = bins - (this.StepSize / 2);
            bins(end) = bins(end-1) + this.StepSize;
            
            dataHist = this.DataHist(1:end-1);
            
            p = this.PercentileValue;
            if strcmp(this.Tail, 'Higher')
                p = 100 - p;
            end
            
            cdfX = cumtrapz(dataHist)*this.StepSize;
            if sum(cdfX)
                cdfX = 100 * cdfX / max(cdfX);

                if p < 100
                    % Look for CDF value just above p, then go one down.
                    % Bias by SQRT_EPS = sqrt(eps)~1.5e-8 to avoid
                    % numerical discrepancies between MATLAB and Simulink
                    maxIdx = find(cdfX > (p + 1.5e-8), 1);                
                    minIdx = maxIdx - 1;
                else
                    % Look for CDF value just below p, then go one up
                    minIdx = find(cdfX < p, 1, 'last');
                    maxIdx = minIdx + 1;
                end                    

                if (minIdx == 1)
                    error(message('comm:commmeasure:Percentile:HighMinValue'));
                end
                if (maxIdx == length(bins))
                    error(message('comm:commmeasure:Percentile:LowMaxValue'));
                end

                % Determine the percentile point using linear interpolation
                v = this.StepSize*(p-cdfX(minIdx))/(cdfX(maxIdx)-cdfX(minIdx)) ...
                    + bins(minIdx);
            else
                v = NaN;
            end
        end
    end
    
    %===========================================================================
    % Set/Get methods
    methods
        function set.MaxValue(this, v)
            propName = 'MaxValue';
            validateattributes(v, ...
                {'double'}, ...
                {'finite', 'scalar', 'nonnan', 'nonempty', 'real'}, ...
                [class(this) '.' propName], propName);
            
            if (v <= this.MinValue) %#ok<MCSUP>
                error(message('comm:commmeasure:Percentile:InvalidMaxValue'));
            end
            
            this.MaxValue = v;
            reset(this)
        end
        %-----------------------------------------------------------------------
        function set.MinValue(this, v)
            propName = 'MinValue';
            validateattributes(v, ...
                {'double'}, ...
                {'finite', 'scalar', 'nonnan', 'nonempty', 'real'}, ...
                [class(this) '.' propName], propName);
            
            if (v >= this.MaxValue) %#ok<MCSUP>
                error(message('comm:commmeasure:Percentile:InvalidMinValue'));
            end
            
            this.MinValue = v;
            reset(this)
        end
        %-----------------------------------------------------------------------
        function set.StepSize(this, v)
            propName = 'StepSize';
            validateattributes(v, ...
                {'double'}, ...
                {'finite', 'nonnan', 'scalar', 'positive', 'real'}, ...
                [class(this) '.' propName], propName);
            
            this.StepSize = v;
            reset(this)
        end
        %-----------------------------------------------------------------------
        function set.Tail(this, v)
            propName = 'Tail';
            v = validatestring(v, {'Lower', 'Higher'}, ...
                [class(this) '.' propName], propName);
            this.Tail = v;
        end
        %-----------------------------------------------------------------------
        function set.PercentileValue(this, v)
            propName = 'PercentileValue';
            validateattributes(v, ...
                {'double'}, ...
                {'finite', 'scalar', 'nonnan', 'nonnegative', 'real'}, ...
                [class(this) '.' propName], propName);
            
            if (v > 100)
                error(message('comm:commmeasure:Percentile:InvalidPercentileValue'));
            end
            
            this.PercentileValue = v;
            reset(this)
        end
        %-----------------------------------------------------------------------
        function v = get.PercentilePoint(this)
            v = calcPercentile(this);
        end
    end
end
