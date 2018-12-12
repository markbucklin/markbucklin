function x = sslog(x)
x = reallog(abs(x)) .* sign(x);