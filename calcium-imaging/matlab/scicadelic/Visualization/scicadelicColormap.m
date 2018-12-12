function cmap = scicadelicColormap()

n = 4096;
redtrans = round(n/5);
bluetrans = round(n/10);
greentrans = 50;

% CONSTRUCT CUSTOM COLORMAP
chan.red = [ zeros(n-redtrans-greentrans,1) ; logspace(2, log10(n), redtrans+greentrans)'./(redtrans+greentrans) ];%log10(n-redtrans)
chan.green = [zeros(greentrans,1) ; linspace(0, 1, n-greentrans-redtrans)'; fliplr(linspace(.5, 1, redtrans-1))' ; .25];
chan.blue = [fliplr( logspace(1, 2, n-bluetrans)./250)'-log(2)/500 ; zeros(bluetrans,1)];
cmap = max(0, min(1, [chan.red(:) chan.green(:) chan.blue(:)]));