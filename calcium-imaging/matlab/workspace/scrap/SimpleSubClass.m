classdef (HandleCompatible) SimpleSubClass < SimpleSuperClass
	
	
	properties
		D
	end
	
	
	methods
		function obj = SimpleSubClass()
			
			obj.D = 10;
			
		end				
		function overriddenMethod(obj)
			obj.B = obj.A;
			obj.D = obj.A*obj.B;
			disp('SimpleSubClass:overriddenMethod')
		end
	end
	methods (Access = protected)
		function obj = protectedAccessMethod(obj)
			obj.B = obj.B + 1;
		end
	end
	methods (Access = private)
		function obj = privateAccessMethod(obj, a, d)
			obj.B = d.*(obj.B + a);
			disp('SimpleSubClass:privateAccessMethod')
		end
	end
	
	
	
	
	
	methods
		function [simplefh, anonfh] = getMethodHandles(obj)
			simplefh.constructor = @SimpleSubClass.SimpleSubClass;
			simplefh.internal = @simpleInternalMethod;
			simplefh.internalret = @simpleInternalReturnMethod;
			simplefh.get = @simpleGetMethod;
			simplefh.set = @simpleSetMethod;
			simplefh.prot = @protectedAccessMethod;
			simplefh.priv = @privateAccessMethod;
			simplefh.spec = @specificAccessMethod;
			simplefh.stat = @SimpleSubClass.simpleStaticMethod;
			simplefh.classfcn = @simpleClassFunction;
			
			anonfh.constructor = @()SimpleSubClass();
			anonfh.internal = @()simpleInternalMethod(obj);
			anonfh.internalret = @()simpleInternalReturnMethod(obj);
			anonfh.get = @()simpleGetMethod(obj);
			anonfh.set = @(b)simpleSetMethod(obj,b);
			anonfh.prot = @()protectedAccessMethod(obj);
			anonfh.priv = @()privateAccessMethod(obj);
			anonfh.spec = @()specificAccessMethod(obj);
			anonfh.stat = @(a)SimpleSubClass.simpleStaticMethod;
			anonfh.classfcn = @(b)simpleClassFunction(b);
			
		end
	end
	
	
	
	
end

function b = simpleClassFunction(b)
if isempty(b)
	b = 0;
end
end
