function suppressLastWarning()

evalin('caller', '[~,warnID] = lastwarn;')
evalin('caller', sprintf('warning(''off'',warnID)'))
evalin('caller', 'clearvars warnID')