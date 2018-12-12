
fn = cat(1,info.FrameNumber);
   fnmax = max(fn);
   fn = round(unwrap(fn.*(2*pi/fnmax)) .* (fnmax/(2*pi)));