function [numBusy, varargout] = getNumWorkersBusy()

numBusy = 0;
fractionBusy = 0;

pool = gcp('nocreate');
if ~isempty(pool)
	session = pool.hGetSession();
	clientInfo = session.getClientSessionInfo;
	numWorkers = get(clientInfo,'Size');
	numBusy = get(clientInfo,'NumWorkersBusy');
	fractionBusy = numBusy/max(1,numWorkers);
end




if nargout
	varargout{1} = fractionBusy;
end
