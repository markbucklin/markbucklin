function flag = isWholeNumber(vec)
rvecdiff = abs( sum( vec(:) - round(vec(:)) ));
flag = rvecdiff < .001;
end
