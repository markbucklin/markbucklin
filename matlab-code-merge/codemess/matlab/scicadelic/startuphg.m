function startuphg
screen = get(groot, 'ScreenSize');
width = screen(3) - screen(1);
height = screen(4) - screen(2);
if any(screen(3:4) ~= 1)  % don't change default if screensize == [1 1]
  if ~ismac % For PC and Linux
    margin = 100;
    if height >= 1400
      mwwidth = 1600; mwheight = 1200;
      scaling = max(1, get(groot,'screenpixelsperinch')/96);           
      mwwidth = mwwidth * scaling;
      mwheight = mwheight * scaling; 
      margin = margin * scaling;
    else
      mwwidth = 960; mwheight = 720;
    end
    left = screen(1) + (width - mwwidth)/2;
    bottom = height - mwheight - margin - screen(2);
  else % For Mac
    if height > 1400
      mwwidth = 1600; mwheight = 1200;
      left = screen(1) + (width-mwwidth)/2;
      bottom = height-mwheight -100 - screen(2);
    else  % for screens that aren't so high
      mwwidth = 960; mwheight = 720;
      left = screen(1) + (width-mwwidth)/2;
      bottom = height-mwheight -76 - screen(2);
    end
  end
  % round off to the closest integer.
  left = floor(left); bottom = floor(bottom);
  mwwidth = floor(mwwidth); mwheight = floor(mwheight);

  rect = [ left bottom mwwidth mwheight ];
        set(groot, 'DefaultFigurePosition',rect);
end