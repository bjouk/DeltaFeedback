clear all 
%% Init
Freq=20000; %Hz
latence=4; %s

%% load 

Path='C:\Users\samantha\Desktop\DeltaFeedBack Project\test\test15_20180522_180850\';
HP_signal=LoadBinary(strcat(Path,'analogin.dat'),'frequency',20000,'nchannels',3);

time=LoadBinary(strcat(Path,'time.dat'),'frequency',20000,'nchannels',1,'channels',1);
load(strcat(Path,'fires_matrix.mat'));
load(strcat(Path,'fires_actual_time.mat'));
fire_points=fires(:,1);

%% Results

figure;
hold on;
plot((1:size(HP_signal,1))/Freq,HP_signal(:,1)*0.000050354,'k');
plot((1:size(HP_signal,1))/Freq,HP_signal(:,2)*0.000050354,'r');
y1=get(gca,'ylim');
plot([round(fire_points*2)/Freq round(fire_points*2)/Freq],y1,'b')
%y1=get(gca,'ylim')
%plot([fires_actual_time*2 fires_actual_time*2],y1,'b');
legend('HP signal','Enveloppe','Fired');
title('Firing detection and delay')
xlabel('time (s)');

figure;
sig=zeros(size(fires,1)-1,latence*Freq+1);
hold on
for i = 2:size(fires,1)-1
    plot((-latence*Freq/2:latence*Freq/2)/Freq,HP_signal(round(2*fires(i),2)-latence*Freq/2:round(2*fires(i),2)+latence*Freq/2,2),'r');
    sig(i,:)=HP_signal(round(2*fires(i),2)-latence*Freq/2:round(2*fires(i),2)+latence*Freq/2,2);
end
y1=get(gca,'ylim');
plot([0 0],y1,'b');
xlabel('time (s)');
xlim([-0.2 0.4]);
title('Delay between trigger and detection');
figure;
hold on;
plot((-latence*Freq/2:latence*Freq/2)/Freq,mean(sig,1),'r');
y1=get(gca,'ylim');
plot([0 0],y1,'b');
xlim([-0.2 0.4]);

xlabel('time (s)');
title('Mean signal')



