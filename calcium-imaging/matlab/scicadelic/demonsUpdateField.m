function [Da_x, Da_y] = demonsUpdateField(fixed,FgradX, FgradY, movingWarped,Da_x,Da_y)
%(moved in) Function scoped broadcast variables for use in zeroUpdateThresholding
IntensityDifferenceThreshold = single(0.001);
DenominatorThreshold = single(1e-9);

FixedMinusMovingWarped = fixed-movingWarped;
FgradMagSquared = FgradX.^2 + FgradY.^2;
denominator =  (FgradMagSquared + FixedMinusMovingWarped.^2);
% denominator =  (abs(FgradX)+abs(FgradY) + abs(FixedMinusMovingWarped));% changed to ABS

% Compute additional displacement field - Thirion
directionallyConstFactor = FixedMinusMovingWarped ./ denominator;
Du_x = directionallyConstFactor .* FgradX;
Du_y = directionallyConstFactor .* FgradY;


if (denominator < DenominatorThreshold) |...
	  (abs(FixedMinusMovingWarped) < IntensityDifferenceThreshold) |...
	  isnan(FixedMinusMovingWarped) %#ok<OR2>
   
   Du_x = single(0);
   Du_y = single(0);
   
end

% Compute total displacement vector - additive update
Da_x = Da_x + Du_x;
Da_y = Da_y + Du_y;

end