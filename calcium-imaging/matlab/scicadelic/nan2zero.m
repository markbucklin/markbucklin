function f = nan2zero(f)

f(isnan(f)) = 0;