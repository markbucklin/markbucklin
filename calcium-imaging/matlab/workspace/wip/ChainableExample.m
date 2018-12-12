classdef ChainableExample < Chainable
    
    properties
        cnt = 0
    end
    
   methods
       function obj = ChainableExample()
           
       end
       function out = noSideEffectMethod(~,in)
          out = in + 1;          
       end
       
       function out = sideEffectMethod(obj, in)
           out = obj.cnt + in;
       end
   end
    
    
end