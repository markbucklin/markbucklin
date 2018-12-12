function control = preUpdateTiffFileStream(control)

% note: cache=State (for now)

% todo: add flag inidicating last idx

[control.NextFrameIdx, control.StreamFinishedFlag] = ignition.shared.getNextIdx(...
		control.NextFrameIdx, control.NumFramesPerRead, control.LastFrameIdx);