function [x,y] = bezline(pt1, pt2, curv)
warning('bezline.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

if nargin < 3
   curv = randn;
end
t = linspace(0,1,101);
pt1 = pt1(:);
pt2 = pt2(:);

ptdif = pt2-pt1;
ptcurv = mean([pt1,pt2],2) + curv/2 * [ptdif(2) ; ptdif(1)];
pts = kron((1-t).^2,pt1) + kron(2*(1-t).*t,ptcurv) + kron(t.^2,pt2);
x = pts(1,:)';
y = pts(2,:)';


