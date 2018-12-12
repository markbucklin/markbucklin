function vec = vsFrameMean(vid)

vec = arrayfun(@(v)(mean2(v.cdata)), vid);