classdef (Abstract) DatasetStorage
%DATASETSTORAGE Dataset Storage Abstract Interface
    
    methods (Abstract, Hidden = true)
        nelem = numElements(this)
        meta = getMetaData(this, idx, prop)
        elem = getElements(this, idx)       
        this = addElements(this, idx, elem)
        this = setElements(this, idx, elem)
        this = removeElements(this, idx)
        this = sortElements(this)
    end
    
end


%from -> Simulink.SimulationData.Storage