function setAutoProps2Manual(gfxHandle)
% setAutoProps2Manual - Sets all properties of given handle object with current value 'auto' to new value 'manual'

handleProps = properties(gfxHandle);
handleVals = get(gfxHandle, handleProps);
isCurrentAuto = strcmp(handleVals,'auto');
set(gfxHandle, handleProps(isCurrentAuto), repelem({'manual'},nnz(isCurrentAuto)))