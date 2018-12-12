function data = filterDataSpatialGaussian(data)
[nRows,nCols,nFrames] = size(data);
filtType = 'gauss';
switch filtType
   case 'med'
	  fprintf('Applying 2D Median Filter \n')
	  medFiltSize = [3 3];
	  for k=1:nFrames
		 data(:,:,k) = gather(medfilt2(gpuArray(data(:,:,k)), medFiltSize));
	  end
   case 'gauss'
	  h = fspecial('gaussian',[5 5], .8);
	  data = imfilter(data, h, 'replicate');
end
end