function f = makewinmat(x,M)
x = x(:);
f = hankel(repmat(x(1), M, 1), [x; x(1:M)]);
f = f(:, M:end-1);
%    f = znormcol(f);