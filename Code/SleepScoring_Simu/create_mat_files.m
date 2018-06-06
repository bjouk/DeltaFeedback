clear all 
clc

addpath(genpath('/Volumes/Macintosh_SSD_2/Dropbox/PrgMatlab/'));

%acquisition parameters
frequency=20000;
nChannels=64;
PFC_channel=47;
OB_channel=44;

%paths
acq_path='/Volumes/Macintosh_SSD_2/MATLAB/MOBs_Project/DeltaFeedback/Recordings/SleepScoring-717-723-31052018-wideband.dat';
saving_path='/Volumes/Macintosh_SSD_2/MATLAB/MOBs_Project/DeltaFeedback/Code/SleepScoring_Simu/Signals/'

%load interest signals
gamma=LoadBinary(acq_path,'frequency',frequency,'nChannels',nChannels,'channels',OB_channel);
thetadelta=LoadBinary(acq_path,'frequency',frequency,'nChannels',nChannels,'channels',PFC_channel);

%save interest signals
save(strcat(saving_path,'gamma.mat'),'gamma');
save(strcat(saving_path,'thetadelta.mat'),'thetadelta');


