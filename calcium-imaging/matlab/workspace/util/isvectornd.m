function y = isvectornd(x)
% N-D version of isvector

y = ~isempty(x) && sum(size(x) > 1) <= 1;

end
