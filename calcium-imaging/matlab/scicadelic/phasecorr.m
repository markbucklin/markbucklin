function d = phasecorr(A,B)
%PHASECORR Compute phase correlation matrix
% >> d = phasecorr(moving, fixed)

% size_A  = size(A);
% size_B  = size(B);
% 
% outSize = size_A(1:2) + size_B(1:2) - 1;
% 
% fA = fft2(A,outSize(1),outSize(2));
% fB = fft2(B,outSize(1),outSize(2));

fA = fft2(A);
fB = fft2(B);


ABConj = bsxfun(@times, fA , conj(fB));
d = ifft2( single(ABConj ./ abs(eps(ABConj)+ABConj)),'symmetric');



