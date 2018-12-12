function normsig = normfunctions()


normsig.z = @(v) bsxfun(@rdivide, bsxfun(@minus, v, mean(v,1)), std(v,[],1));
normsig.poslt1 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, min(v,[],1)), range(v,1));
normsig.zmlt1 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, mean(v,1)), max(abs(v),[],1));
normsig.poslog = @(v) log( bsxfun(@plus, bsxfun(@minus, v, min(v,[],1)) , std(v,[],1)));
