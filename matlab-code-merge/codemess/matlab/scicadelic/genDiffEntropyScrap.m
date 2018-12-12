
%% CONVERTS TO BINARY
% X = getActivationState(Fmax);
X = getStatePredictor(double(Fmax));


%%
M = size(X,1);
numRoi = size(X,2);

hFig = figure;

% for winSizeSeconds = 1:5
fps=20;
winSizeSeconds = 2;
winOffset = winSizeSeconds*fps + 1;

DE = differentialEntropy(X, winSizeSeconds*20);

parfor k=1:size(X,2)
	meanEntropy(1,k) = entropy(X(:,k));
end
idx = find((meanEntropy<=.95) & (std(DE(winOffset:end,:), 1, 1)>.15));
numLowEntropyRoi = numel(idx);
figure(hFig)

%%
cla
hAx = gca;


for k=1:numel(idx)
	hLine(k) = line((1:M)./fps, DE(:,idx(k)), 'Color',[0 .6 0 .15], 'Parent', hAx);
end
hMeanLine = line((1:M)./fps, mean(DE(:,idx),2), 'Color',[0 .6 0 .75], 'LineWidth',2.75, 'Parent', hAx);


title(sprintf('Window Size: %d seconds',winSizeSeconds))










% 	pause







% 	newFig = figure;
% 	hAx.Parent = newFig;
% 	savefig2jpeg
% end