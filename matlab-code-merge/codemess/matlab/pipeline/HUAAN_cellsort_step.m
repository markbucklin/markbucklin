
[mixedsig, mixedfilters, CovEvals, covtrace, movm, movtm] = CellsortPCA_HT('_crop_correct_Ali11_06212014', 150, 3);

PCuse = 1:50;
mu_=0.5;
[ica_sig, ica_filters, ica_A, numiter] = CellsortICA_HT('Ali12_20140621',mixedsig, mixedfilters, CovEvals, [PCuse], mu_, [], [], [], 10000);

[ica_segments, ica_filtersbw, segmentlabel, segcentroid] = CellsortSegmentation_HT(ica_filters, 1, 2, 50, 0);

[merged_segments,merged_segcentroid,segments_structure] = merge_mask('Ali9-20140621',ica_segments,segcentroid,[0.5 0.9],1);


[cell_sig, segments_structure] = CellsortApplyFilter_HT_para('_crop_correct_Ali9_06212014', segments_structure,0);


[behavior_structure] = get_behavior_data('20140621');

[neuron_structure] = combine_behavior_trace('Ali9_20140621',segments_structure,behavior_structure);


















fn = '496-20140509-behavior.tif'
f0=imread('AVG_496-20140509-behavior.tif');
lick_file = '496L-lick-20140510';
trial_file = 'Trial-20140510';
video_number = 140;
dt=0.061104;
sound1 = 3075;
sound2 = 12300;
mu_=1;
ratebin=0.01;
% PCuse=1:50;

lick=dlmread(lick_file);
trial=dlmread(trial_file);
cell_sig_neuron={};
all_lick=[];


[mixedsig, mixedfilters, CovEvals, covtrace, movm, movtm] = CellsortPCA(fn, [], [], [], './', []);

% [PCuse] = CellsortChoosePCs(fn, mixedfilters);
% [PCuse] = CellsortChoosePCs_HT(movm, mixedfilters);


% CellsortPlotPCspectrum(fn, CovEvals, PCuse)



PCuse = 1:50;
mu_=1;
[ica_sig, ica_filters, ica_A, numiter] = CellsortICA(mixedsig, mixedfilters, CovEvals, [PCuse], mu_, [], [], [], 10000);
% [ica_sig, ica_filters, ica_A, numiter] = CellsortICA(mixedsig, mixedfilters, CovEvals, [], mu_, [], [], [], 10000);




% CellsortICAplot('contour', ica_filters, ica_sig, movm, [], dt, ratebin, [], [1:10], [], []);
[ica_segments, ica_filtersbw, segmentlabel, segcentroid] = CellsortSegmentation_HT(ica_filters, 1, 1, 100, 1);


% apply filter to combined video
cell_sig = CellsortApplyFilter(fn, ica_segments, [], movm, 0);


% apply filter to each video
% cell_sig_all=[];
cell_sig_neuron={};

% i is the video, j is the neuron
for i=1:video_number
    tic;
%     cell_sig_all(:,:,i) = CellsortApplyFilter([num2str(i),'.tif'], ica_segments, [], movm, 0);
    signal = CellsortApplyFilter([num2str(i),'.tif'], ica_segments, [], movm, 0);
    for j=1:size(signal,1)
        cell_sig_neuron(j).video(i).signal = signal;
        normalized_signal = (signal(j,:)-mean(signal(j,:)))/mean(signal(j,:));
        cell_sig_neuron(j).video(i).normalized_signal = normalized_signal;
        trial_number = (i-1)*3+1;
        cell_sig_neuron(j).video(i).trial_start = trial(trial_number,1);
        cell_sig_neuron(j).video(i).trial = trial_number;
        cell_sig_neuron(j).video(i).sound = trial(trial_number,3);
    end
end


x=[dt:dt:size(cell_sig, 2)*dt];
trial_x=[dt:dt:size(signal,2)*dt]-1.5;


close all;

for j=1:size(ica_segments,1)
    figure(j)
    clf;
    subplot(4,2,1)
    imagesc(squeeze(ica_segments(j,:,:)));
    title(['Neuron ',num2str(j)]);
    axis image off;
    colormap(gray);
    
    subplot(4,2,3)
    imagesc(f0);
    axis image off;
    colormap(gray);
    
    subplot(4,2,[2,4])
    plot(x,cell_sig(j,:));
    title('all trials');
    xlabel('second');
    xlim([0 size(cell_sig, 2)*dt]);
    
    subplot(4,2,[5,7])
    plot(trial_x,cat(1,cell_sig_neuron(j).video(:).normalized_signal))
    xlabel('second');
    ylabel('each trial');
    xlim([min(trial_x) max(trial_x)]);
    
%     subplot(4,2,[6,8])
%     imagesc(trial_x,1:size(cat(1,cell_sig_neuron(1).video(:).normalized_signal),1),cat(1,cell_sig_neuron(1).video(:).normalized_signal));
%     xlabel('second');
%     xlim([min(trial_x) max(trial_x)]);
%     colormap('default');
    
%     subplot(4,2,[6,8])
%     ploted_trial = 5;
%     plot(trial_x,cell_sig_neuron(i).signal(1:ploted_trial,:),'b')
%     hold on;
%     plot(trial_x,cell_sig_neuron(i).signal(end-ploted_trial:end,:),'r')
%     hold off;
%     xlabel('second');
%     xlim([0 size(cell_sig_all, 2)*dt]);
    
    filename = ['Neuron_' num2str(j)];
    saveas(figure(j), filename, 'fig');
    saveas(figure(j), filename, 'jpg');
    close all;
end


for j=1:numel(cell_sig_neuron)
    figure(j)

    subplot(2,2,1)
    all_lick=[];
    sound1_index = find([cell_sig_neuron(j).video(:).sound]==sound1);
    for i=1:length(sound1_index)
        trial_start = cell_sig_neuron(1).video(sound1_index(i)).trial_start;
        cell_sig_neuron(1).video(sound1_index(i)).lick_time = (lick(find(lick(:,1)>trial_start-1.5 & lick(:,1)<trial_start+6),1)-trial_start);
        trial_lick = (lick(find(lick(:,1)>trial_start-1.5 & lick(:,1)<trial_start+6),1)-trial_start);
        all_lick = [all_lick;trial_lick ones(length(trial_lick),1)*i];
    end
    scatter(all_lick(:,1),all_lick(:,2),'.');
    xlim([min(trial_x) max(trial_x)]);
    ylim([0 length(sound1_index)+1]);
    axis ij;
    title(sound1);
    xlabel('second');
    ylabel('trial #');
    
    subplot(2,2,2)
    all_lick=[];
    sound2_index = find([cell_sig_neuron(j).video(:).sound]==sound2);
    for i=1:length(sound2_index)
        trial_start = cell_sig_neuron(j).video(sound2_index(i)).trial_start;
        trial_lick = (lick(find(lick(:,1)>trial_start-1.5 & lick(:,1)<trial_start+6),1)-trial_start);
        all_lick = [all_lick;trial_lick ones(length(trial_lick),1)*i];
    end
    scatter(all_lick(:,1),all_lick(:,2),'.');
    xlim([min(trial_x) max(trial_x)]);
    ylim([0 length(sound2_index)+1]);
    axis ij;
    title(sound2);
    xlabel('second');
    ylabel('trial #');
    
    sound1_signal = cat(1,cell_sig_neuron(j).video(sound1_index).normalized_signal);
    sound2_signal = cat(1,cell_sig_neuron(j).video(sound2_index).normalized_signal);
    c_max = max([max(sound1_signal(:)) max(sound2_signal(:))]);
    c_min = max([min(sound1_signal(:)) min(sound2_signal(:))]);
    
    subplot(2,2,3)
    imagesc(trial_x,1:size(sound1_signal,1),sound1_signal);
    xlabel('second');
    ylabel('trial #');
    caxis([c_min c_max]);
    
    subplot(2,2,4)
    imagesc(trial_x,1:size(sound2_signal,1),sound2_signal);
    xlabel('second');
    ylabel('trial #');
    caxis([c_min c_max]);
    
    colormap('default');
    
    filename = ['Neuron_lick_' num2str(j)];
    saveas(figure(j), filename, 'fig');
    saveas(figure(j), filename, 'jpg');
    close all;
    
end

save([fn,'_',datestr(datenum(date,'dd-mmm-yyyy'),'yyyymmdd'),'.mat'],'-v7.3')


for j=1:numel(cell_sig_neuron)
    
    figure(j)
    
    subplot(1,2,1)
    neuron_filter = squeeze(ica_segments(j,:,:));
    imagesc(neuron_filter);
    title(['Neuron ',num2str(j)]);
    axis image off;
    colormap(gray);
    
    subplot(1,2,2)
    neuron_outline = edge(neuron_filter,'zerocross');
    f1 = f0;
    f1(neuron_outline) = max(f0(:));
    imagesc(f1);
    title(['Neuron ',num2str(j),' outline']);
    axis image off;
    colormap(gray);
    
    filename = ['Neuron_outline_' num2str(j)];
    saveas(figure(j), filename, 'fig');
    saveas(figure(j), filename, 'jpg');
    close all;
    
end




%%%%

sound1_index = find([cell_sig_neuron(1).video(:).sound]==sound1);
sound1_signal = cat(1,cell_sig_neuron(1).video(sound1_index).signal);
imagesc(trial_x,1:size(sound1_signal,1),sound1_signal);
for i=1:length(sound1_index)
    trial_start = cell_sig_neuron(1).video(i).trial_start;
    trial_lick = (lick(find(lick(:,1)>trial_start-1.5 & lick(:,1)<trial_start+6),1)-trial_start);
    all_lick = [all_lick;trial_lick ones(length(trial_lick),1)*i];
end
scatter(all_lick(:,1),all_lick(:,2),'.');
ylim([0 length(sound1_index)+1]);
axis ij;










%%%%%%%%%%%%%%%%%%%

for j=1:size(ica_segments,1)
    figure(j)
    clf;
    subplot(2,2,1)
    imagesc(squeeze(ica_segments(j,:,:)));
    title(['Neuron ',num2str(j)]);
    axis image off;
    colormap(gray);
    
    subplot(2,2,3)
    imagesc(f0);
    axis image off;
    colormap(gray);
    
    subplot(2,2,[2,4])
    plot(x,cell_sig(j,:));
    title('all trials');
    xlabel('second');
    xlim([0 size(cell_sig, 2)*dt]);
    
    
    filename = ['Neuron_N_' num2str(j)];
    saveas(figure(j), filename, 'fig');
    saveas(figure(j), filename, 'jpg');
    close all;
end











%%%%%%%%%%%%%%%%%%

subplot([2,1,1],2,1)
    imagesc(squeeze(ica_segments(j,:,:)));
    title(['Neuron ',num2str(j)]);
    axis image off;

    
    
for i=1:length(cell_sig(1,:))-5
    dt(i)=mean(cell_sig(1,i:i+4));
end

filtfilt(1,1,