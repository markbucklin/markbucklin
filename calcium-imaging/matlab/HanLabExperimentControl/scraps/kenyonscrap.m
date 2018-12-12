w = exper.worlds{1}
methods(w)
w.draw3D
h = gca
h = handle(gca)
h
get(h)
h.DataAspectRatio = [1 1 1]
h.ALim = [.1 20]
get(h)
set(h.Children,'AlphaDataMapping','direct')
h.ALim = [.1 1]
set(h.Children,'AlphaDataMapping','scaled')
set(h.Children,'AmbientStrength')
h.ALim = [.1 20]
h.ALim = [.1 15]
h.ALim = [.1 10]
h.ALim = [.1 2]
hold on
quiver(info.Xpos(200:end), info.Ypos(200:end), squeeze(data(5,1,1,200:end)), squeeze(data(5,2,1,200:end)))
clf
w.draw3D
h = handle(gca)
h.DataAspectRatio = [1 1 1]
set(h.Children,'AlphaDataMapping','scaled')
h.ALim = [.1 2]
hold on
hquiv = handle(quiver(info.Xpos(200:end), info.Ypos(200:end), squeeze(data(5,1,1,200:end)), squeeze(data(5,2,1,200:end))))
whitebg('k')