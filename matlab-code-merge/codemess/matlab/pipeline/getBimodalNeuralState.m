function xs = getBimodalNeuralState(R)

% CONSTANTS
% reach.step = 4;
% reach.max = 40;

% CONVERSION TO STATE-SPACE IS SIGNIFICANTLY CLEANER USING FILTERED CA SIGNAL
X = [R.Trace]; 

% GET PERIODS OF INCREASING/POSITIVE/STIMULATORY ACTIVITY
xPos = getStatePredictor(X);

% GET PERIODS OF DECREASING/NEGITIVE/INHIBITORY ACTIVITY  (Assert Positive Dominance)
xNeg = getStatePredictor(-X);

% CORRECT FOR FIT TO POSITIVE-PEAK-RECOVERY SECTIONS OF INVERTED SIGNAL 
xNeg = xNeg & bsxfun(@lt, X, trimmean(X,10,'round',1)-std(X,[],1));
% xSuppressed = xNeg;
% xSuppressed(xPos) = false;
% % xSuppressed(1:reach.max, :) = false;
% % xSuppressed((end-reach.max):end, :) = false;
% [~,dX] = gradient(X);
% xGenerallyNeg = dX < 0 ;
% xSuppressor = xSuppressed;
% iter = 1;
% % USE STEP-WISE ADVANCING POSITIVE-STATE PREDICTOR SECTIONS TO SUPPRESS CORRESPONDING RECOVERY TO BASELINE SECTIONS
% while any(xSuppressor(:))
%    xSuppressed = xSuppressed | xSuppressor;
%    xSuppressor = xSuppressed & squeeze(any(shiftedWinMat(xPos, 0, reach.step*iter ), 1));
%    iter = iter+1;
%    if iter > reach.max, break, end
% end





xs.pos = xPos;
xs.neg = xNeg;