clear all
close all
clc

%% Plot data

load('Signal.mat');
figure;
plot(Signal(1:10:end));

%% Select data

Signal_good=Signal(7e7:8e7-1);
figure;
plot(Signal_good);

fs=20000; %Sampling frequency (samples per second)
dt=1/fs;
stop_time=size(Signal_good,1)/fs;
t=[0:dt:stop_time-dt]; % Time Vector
F=10;% Frequency

figure;
plot(t,Signal_good);

%% Read Signal

clear theta delta

d_theta=designfilt('bandpassfir','FilterOrder',332,'CutoffFrequency1', 5,'CutoffFrequency2',10,'SampleRate',fs/60); %Filter for theta
d_delta=designfilt('bandpassfir','FilterOrder',332,'CutoffFrequency1', 2,'CutoffFrequency2',4,'SampleRate',fs/60); %Filter for theta

t_cycle=3; % Cycle duration (s)
N_cycles=stop_time/t_cycle;
t_tmp=t_cycle/2;
subscripts=[1:t_cycle*fs];
t_tmp=[t_tmp-(t_cycle/2):dt:t_tmp+(t_cycle/2)-dt];
t_tmp_plot=t_tmp(1:60:end);

%theta=zeros(round(N_cycles),1)
%delta=zeros(round(N_cycles),1)


f=figure
    
for i=1:N_cycles
    
    
    signal_temp=Signal_good(subscripts);
    signal_temp=movmean(signal_temp,60);
    signal_temp=signal_temp(1:60:end);
    
    signal_theta_temp_filtered = filtfilt(d_theta,signal_temp);
    signal_delta_temp_filtered = filtfilt(d_delta,signal_temp);
    
    hilbert_theta = abs( hilbert(signal_theta_temp_filtered));
    theta(i)=mean(hilbert_theta);
    
    hilbert_delta = abs( hilbert(signal_delta_temp_filtered));
    delta(i)=mean(hilbert_delta);
    
    
    subplot(3,1,1)
    
    plot(t_tmp_plot,signal_temp,'b',t_tmp_plot,signal_theta_temp_filtered,'r');
    xlabel('time (s)');
    ylabel('Theta Signal');
    title(i);
    
     subplot(3,1,2)
    
    plot(t_tmp_plot,signal_temp,'b',t_tmp_plot,signal_delta_temp_filtered,'r');
    xlabel('time (s)');
    ylabel('Theta Signal');
    title(i);
    
    t_tmp=t_tmp+t_cycle;
    t_tmp_plot=t_tmp_plot+t_cycle;
    subscripts=subscripts+(t_cycle*fs);
    pause(0.1);
    
    subplot(3,1,3)
    plot([1:i]*3,theta./delta,'*');
    xlim([0 N_cycles*3])
    xlabel('time (s)');
    ylabel('Theta/Delta ratio');
    
end




