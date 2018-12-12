Pxy = fcn.P_XandY;

Pxylogxy = @(x,y) Pxy(x,y)*log2(Pxy(x,y));

H = @( x) - ( Pxy(x,x) + Pxy(x,~x) + Pxy(~x,x) + Pxy(~x,~x) );