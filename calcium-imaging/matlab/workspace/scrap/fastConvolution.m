function y = fastConvolution(data,filter)
warning('fastConvolution.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

% FROM MATLAB PCT TOOLBOX USER'S GUIDE

[m,n] = size(data);
% Zero-pad filter to the column length of data, and transform
filter_f = fft(filter,m);
% Create an array of zeros of the same size and class as data
y = zeros(m,n,'like',data);
% Transform each column of data
for ix = 1:n
af = fft(data(:,ix));
y(:,ix) = ifft(af .* filter_f);
end
end
