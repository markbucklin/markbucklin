load('Z:\Data\susie\[Temp Data] Processing\[SC0419] GCaMP\[Processed] I0918 - 152DAT\0419Ctx-M1LH-152DAT-40fps00001\varThresh.mat')
m1lh.compR_8bit_lzma2.dat152 = compressionRatio_8bit_7z;
m1lh.compR_bin_lzma2.dat152 = compressionRatio_bin_7z;
m1lh.thresh.dat152 = legendInfo;
m1lh.netEntropy.dat152 =NetworkEntropy;
m1lh.firingProb.dat152 = BlueFiringProb;
m1lh.ROIcompR_8bit_deflate.dat152 = ROIcompressionRatio_8bit;
m1lh.ROIcomR_bin_deflate.dat152 = ROIcompressionRatio_bin;

load('Z:\Data\susie\[Temp Data] Processing\[SC0419] GCaMP\[Processed] I0911 - 145DAT\0419Ctx-M1LH-145DAT-40fps00001\varThresh.mat')
m1lh.firingProb.dat145 = BlueFiringProb;
m1lh.compR_8bit_lzma2.dat145 = compressionRatio_8bit_7z;
m1lh.compR_bin_lzma2.dat145 = compressionRatio_bin_7z;
m1lh.thresh.dat145 = legendInfo;
m1lh.netEntropy.dat145 =NetworkEntropy;
m1lh.ROIcompR_8bit_deflate.dat145 = ROIcompressionRatio_8bit;
m1lh.ROIcomR_bin_deflate.dat145 = ROIcompressionRatio_bin;

load('Z:\Data\susie\[Temp Data] Processing\[SC0419] GCaMP\[Processed] I0817 - 120DAT\0419Ctx-M1LH-120DAT-40fps00001\varThresh.mat')
m1lh.firingProb.dat120 = BlueFiringProb;
m1lh.compR_8bit_lzma2.dat120 = compressionRatio_8bit_7z;
m1lh.compR_bin_lzma2.dat120 = compressionRatio_bin_7z;
m1lh.thresh.dat120 = legendInfo;
m1lh.netEntropy.dat120 =NetworkEntropy;
m1lh.ROIcompR_8bit_deflate.dat120 = ROIcompressionRatio_8bit;
m1lh.ROIcomR_bin_deflate.dat120 = ROIcompressionRatio_bin;

load('Z:\Data\susie\[Temp Data] Processing\[SC0419] GCaMP\[Processed] I0728 - 100DAT\0419Ctx-M1LH-100DAT-40fps\varThresh.mat')
m1lh.firingProb.dat100 = BlueFiringProb;
m1lh.compR_8bit_lzma2.dat100 = compressionRatio_8bit_7z;
m1lh.compR_bin_lzma2.dat100 = compressionRatio_bin_7z;
m1lh.thresh.dat100 = legendInfo;
m1lh.netEntropy.dat100 =NetworkEntropy;
m1lh.ROIcompR_8bit_deflate.dat100 = ROIcompressionRatio_8bit;
m1lh.ROIcomR_bin_deflate.dat100 = ROIcompressionRatio_bin;

load('Z:\Data\susie\[Temp Data] Processing\[SC0419] GCaMP\[Processed] I0705 - 77DAT\SC0419-M1LH-I0705\varThresh.mat')
m1lh.firingProb.dat77 = BlueFiringProb;
m1lh.compR_8bit_lzma2.dat77 = compressionRatio_8bit_7z;
m1lh.compR_bin_lzma2.dat77 = compressionRatio_bin_7z;
m1lh.thresh.dat77 = legendInfo;
m1lh.netEntropy.dat77 =NetworkEntropy;
m1lh.ROIcompR_8bit_deflate.dat77 = ROIcompressionRatio_8bit;
m1lh.ROIcomR_bin_deflate.dat77 = ROIcompressionRatio_bin;

load('Z:\Data\susie\[Temp Data] Processing\[SC0419] GCaMP\[Processed] I0504 - 15 DAT\SC0419-M1LH-I0504\varThresh.mat')
m1lh.firingProb.dat15 = BlueFiringProb;
m1lh.compR_8bit_lzma2.dat15 = compressionRatio_8bit_7z;
m1lh.compR_bin_lzma2.dat15 = compressionRatio_bin_7z;
m1lh.thresh.dat15 = legendInfo;
m1lh.netEntropy.dat15 =NetworkEntropy;
m1lh.ROIcompR_8bit_deflate.dat15 = ROIcompressionRatio_8bit;
m1lh.ROIcomR_bin_deflate.dat15 = ROIcompressionRatio_bin;

load('Z:\Data\susie\[Temp Data] Processing\[SC0419] GCaMP\[Processed] I0428 - 9 DAT\SC0419-M1LH-I0428\varThresh.mat')
m1lh.firingProb.dat9 = BlueFiringProb;
m1lh.compR_8bit_lzma2.dat9 = compressionRatio_8bit_7z;
m1lh.compR_bin_lzma2.dat9 = compressionRatio_bin_7z;
m1lh.thresh.dat9 = legendInfo;
m1lh.netEntropy.dat9 =NetworkEntropy;
m1lh.ROIcompR_8bit_deflate.dat9 = ROIcompressionRatio_8bit;
m1lh.ROIcomR_bin_deflate.dat9 = ROIcompressionRatio_bin;



datName = {'dat9','dat15','dat77','dat100','dat120','dat145','dat152'};

figure
hold on
for k = 1:size(datName,2)
    dat = datName{k};
    subplot(size(datName,2),1,k)
    histROI(k) = histogram(m1lh.ROIcompR_8bit_deflate.(dat)(2,:),100,'BinLimits',[0.005 0.04]);
    histROI(k).Normalization = 'probability';
end

figure
histogram(m1lh.ROIcompR_8bit_deflate.dat152(2,:),80,'BinLimits',[0.005 0.04]);
hold on
histogram(m1lh.ROIcompR_8bit_deflate.dat9(2,:),80,'BinLimits',[0.005 0.04]);

figure
hold on
for k = 1:size(datName,2)
    dat = datName{k};
    subplot(size(datName,2),1,k)
    histROI(k) = histogram(m1lh.ROIcomR_bin_deflate.(dat)(2,:),40,'BinLimits',[0.06 0.22]);
    histROI(k).Normalization = 'probability';
end

figure
histogram(m1lh.ROIcomR_bin_deflate.dat152(2,:),80,'BinLimits',[0.06 0.22]);
hold on
histogram(m1lh.ROIcomR_bin_deflate.dat9(2,:),80,'BinLimits',[0.06 0.22]);

figure
hold on
for k = 1:size(datName,2)
    dat = datName{k};
    subplot(size(datName,2),1,k)
    histROI(k) = histogram(m1lh.firingProb.(dat)(2,:),100,'BinLimits',[0.01 0.1]);
    histROI(k).Normalization = 'probability';
end

figure
histogram(m1lh.firingProb.dat152(2,:),80,'BinLimits',[0.01 0.1]);
hold on
histogram(m1lh.firingProb.dat9(2,:),80,'BinLimits',[0.01 0.1]);

for k = 1:size(datName,2)
    dat = datName{k};
    compR_8bit_lzma2_thresh1(k) = m1lh.compR_8bit_lzma2.(dat)(2);
    compR_8bit_lzma2_thresh3(k) = m1lh.compR_8bit_lzma2.(dat)(3);
    compR_8bit_lzma2_thresh5(k) = m1lh.compR_8bit_lzma2.(dat)(4);
end
figure
plot(compR_8bit_lzma2_thresh1)
hold on
plot(compR_8bit_lzma2_thresh5)
plot(compR_8bit_lzma2_thresh3)
hold off

for k = 1:size(datName,2)
    dat = datName{k};
    compR_bin_lzma2_thresh1(k) = m1lh.compR_bin_lzma2.(dat)(2);
    compR_bin_lzma2_thresh3(k) = m1lh.compR_bin_lzma2.(dat)(3);
    compR_bin_lzma2_thresh5(k) = m1lh.compR_bin_lzma2.(dat)(4);
end
figure
plot(compR_bin_lzma2_thresh1)
hold on
plot(compR_bin_lzma2_thresh3)
plot(compR_bin_lzma2_thresh5)
hold off

for k = 1:size(datName,2)
    dat = datName{k};
    netEntropy_thresh1(k) = m1lh.netEntropy.(dat)(2);
    netEntropy_thresh3(k) = m1lh.netEntropy.(dat)(3);
    netEntropy_thresh5(k) = m1lh.netEntropy.(dat)(4);
end
figure
plot(netEntropy_thresh1)
hold on
plot(netEntropy_thresh3)
plot(netEntropy_thresh5)
hold off




% 
% legend([152 145 15 9],'location','northeast')
% 
% 
% 
% 
% 
