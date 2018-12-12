% Copyright 2015 The MathWorks, Inc.

classdef RamDatasetStorage <  Simulink.SimulationData.Storage.DatasetStorage
    
    %% Protected Properties =================================================
    properties (Access = 'protected')
        Version = 1;
        Elements = {};
    end % Protected properties
    
    %% Public Methods =====================================================
    methods (Hidden = true)
        
        %% -----------------------------------------------------------------
        function nelem = numElements(this)
            if length(this) ~= 1
                Simulink.SimulationData.utError('InvalidDatasetArray');
            end
            nelem = length(this.Elements);
        end
        
        %% -----------------------------------------------------------------
        function meta = getMetaData(this, idx, prop)
            % Make sure dataset is not empty
            if isempty(this.Elements)
                Simulink.SimulationData.utError('InvalidDatasetGetIndexEmpty');   
            end
            % Index must be integer within the correct range
            this.checkIdxRange(idx, this.numElements(), 'InvalidDatasetGetIndex');
            
            meta = this.Elements{idx}.(prop);
        end
        
        %% -----------------------------------------------------------------
        function element = getElements(this, idx)
            % Make sure dataset is not empty
            if isempty(this.Elements)
                Simulink.SimulationData.utError('InvalidDatasetGetIndexEmpty');   
            end
            % Index must be integer within the correct range
            this.checkIdxRange(idx, this.numElements(), 'InvalidDatasetGetIndex');
            
            if isscalar(idx)
                element = this.Elements{idx};
            else
                element = this.Elements(idx);
            end
        end
               
        %% ----------------------------------------------------------------
        function this = setElements(this, idx, element)
            % Index must be integer within the correct range
            this.checkIdxRange(idx, this.numElements(), 'DatasetSetInvalidIdx');
            if isscalar(idx)
                this.Elements{idx} = element;
            else
                this.Elements(idx) = element;
            end
        end
        
        %% ----------------------------------------------------------------
        function this = addElements(this, idx, element)
            % Index must be scalar integer within the correct range
            this.checkIdxRange(idx, this.numElements() + 1, 'DatasetInsertInvalidIdx');
            if ~isscalar(idx)
                Simulink.SimulationData.utError(...
                    'DatasetInsertInvalidIdx', maxIdx);
            end
            % Shift items to insert item
            this.Elements = [this.Elements(1:idx-1) cell(1, length(element)) this.Elements(idx:end)];
            try
                this = this.setElements(idx:idx+length(element)-1, element);
            catch me
                throwAsCaller(me);
            end
           
        end
        
        %% ----------------------------------------------------------------
        function this = removeElements(this, idx)
            % Check the parameter
            this.checkIdxRange(idx, this.numElements(), 'DatasetRemoveInvalidIdx');          
            % Remove the elements 
            this.Elements(idx) = [];
        end 
        

         %% ----------------------------------------------------------------
        function this = utSetElements(this, elements)
        % Utility function to set all the elements of the Dataset in 1
        % call. This function is hidden, as we only use it internally in
        % Simulink logging.
            if isrow(elements)
                this.Elements = elements;
            else
                this.Elements = elements';
            end
        end
        
	%% ----------------------------------------------------------------
	% functions in seperate files	
	this = sortElements(this);
        this = utfillfromstruct(this, datasetStruct);
               
    end % Public Methods
    
    %% Hidden Methods =====================================================
    methods (Access = private, Hidden = true)
        
        %% ---------------------------------------------------------------------
        function strct = saveobj(this)
            strct.Version = this.Version;
            strct.Elements = this.Elements;
        end
        
        function checkIdxRange(this, idx, maxIdx, err)
        % Check if index is scalar integer in range

            % Only valid for scalar objects
            if length(this) ~= 1
                Simulink.SimulationData.utError('InvalidDatasetArray');
            end

            if ~isnumeric(idx) || ~isreal(idx) ||...
                    any(idx ~= uint32(idx)) || min(idx) < 1 || max(idx) > maxIdx
                Simulink.SimulationData.utError(err, maxIdx);
            end
        end
        
    end
    
    %% Static Hidden Methods ===================================================
    methods (Static = true, Hidden = true)
        
        %% ---------------------------------------------------------------------
        function obj = loadobj(strct)
            assert(strct.Version == 1);
            obj = Simulink.SimulationData.Storage.RamDatasetStorage;
            obj.Version = 1;
            obj.Elements = strct.Elements;
        end
        
    end % Static Hidden Methods
    
end % Dataset



