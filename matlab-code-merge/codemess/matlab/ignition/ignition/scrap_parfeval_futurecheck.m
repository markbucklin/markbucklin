for k=1:8
	fut(k) = parfeval( pool, @fft2 , 1, F(:,:,:,k) );
	sfut(k) = struct(fut(k));
end

pause(.005)


argsOut = cell(numel(fut),fut(1).NumOutputArguments);


while ~all([fut.Read])
	[futIdx, futArg] = fetchNext(fut, .005);
	
	if ~isempty(futIdx)
		argsOut{futIdx} = futArg;
	end
	
end




sinCache = struct(sfut(1).InputCache); 
% InputCache.PropertyCache -> % { @fcn , numOut, {inputArgs} }
fut(1) = parallel.FevalFuture( sinCache.PropertyCache{:} ) ;
submit(fut(1),Q)






% ALSO

session = pool.hGetSession();