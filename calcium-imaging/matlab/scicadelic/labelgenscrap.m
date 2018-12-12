



bwB = bwData(:,:,k);
bwF = bwData(:,:,k+1);



[Bx, By] = gradient(int16(B));
[Byx, Byy] = gradient(By);
[Bxx, Bxy] = gradient(Bx);

[r,c,k] = size(B);
byy = reshape(Byy, r*c, k);
bxx = reshape(Bxx', r*c, k);


[Fx, Fy] = gradient(int16(F));
[Fyx, Fyy] = gradient(Fy);
[Fxx, Fxy] = gradient(Fx);

[r,c,k] = size(F);
fyy = reshape(Fyy, r*c, k);
fxx = reshape(Fxx', r*c, k);




