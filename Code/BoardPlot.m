classdef BoardPlot < handle
    %BOARDUI Class containing UI data related to a single board
    %
    % There's a lot of common functionality in the read_continuously,
    % episodic_recording, read_optimized, and two_boards examples.
    %
    % This class implement some of the common functionality.  It handles
    % one board's worth of time-series data.  It stores data and plots it 
    % on axes, lets you choose which chip to plot and which group of 
    % channels.
    %
    % See also read_continuously, episodic_recording, and two_boards.
    
    properties
        % Number of channels to store
        NumChannels

        % Currently selected chip index (e.g., 3 for Port B, MISO 1).
        ChipIndex
        
        % Channels to store.  Usually 1:32 or something like that
        StoreChannels 
        
        % Channels to get from data block.  E.g. 33:64.  This should be the
        % same length as StoreChannels, but it may have a different offset
        % (e.g., StoreChannels could be 1:10, and this could be 11:20
        Channels
        fired
        detected
        detec_status
        wait_status
        detec_seuil
        sound_mode
        armed
        
        
        SoundFile
        ThresholdFile
        
        timer1
        passed
        counter
        counter_detection
        countermax
        countermax_detection
        DeltaPoints_counter
        ptperdb %>=1 db:datablock
        
        durationdb
        durationbf
        durationaft
        nbrptbf
        nbrdbaft
        nbrptaft
        
        samplingfreq %Sampling frequency of the Intan Controller
        num_points %Number of points to display
        prefactors %Prefactors for the substraction of the cortex signals
        
        Timestamps
        
        Time_real
        Math_buffer_to_filter % a public property, cause needs to be created when click the filter "Apply"
        Math_buffer_filtered % buffer for IIR filter
        Math_filtered %Stores the output of the filtering of the difference
        Math_filtered_display
        sound_tone %Type of sound played during stimulation
        Time

        % Jingyuan
        hilbert_filter_order % Order of the filter used to filter the signal prior to hilbert transform
         
        coeff_Spectremax 
        
        coeff_bullfmin % Minimal frequency of Gamma oscillations
        coeff_bullfmax  % Maximal frequency of Gamma oscillations
        bullchannel %Channel used to get gamma oscillations
        bullFilt % Filter used to get the gamma signal
        
        coeff_Thetafmin %Minimal frequency for theta oscillations
        coeff_Thetafmax %Maximal frequency for theta oscillations
        Thetachannel %Channel used to get the theta signal 
        ThetaFilt % Filter used to get the theta signal 
        
        coeff_Deltafmin %Minimal frequency for delta oscillations
        coeff_Deltafmax %Maximal frequency for delta oscillations
        Deltachannel % Channel used for delta oscillations
        DeltaFilt %Filter used for delta oscillations 
        
        DeltaFiltPFC_A %Delta filter for PFC detection
        DeltaFiltPFC_B
        ratioData
        
        result
        
        gamma_prob
        gamma_value
        ratio_probSleep
        ratio_valueSleep
        ratio_prob
        ratio_value
        ratio_threshold
        gamma_threshold
        threshold_status
        vline_phase
        hline_phase
        vline_gamma
        hline_ratio
        % Data extracted from Amplifier for spectre plotting Jingyuan
        BullData
        ThetaData
        DeltaData
        %Stimulate during NREM Sleep
        stimulateDuringNREM
        
        stimulateDuringREM
        
        stimulateDuringWake
        stimulateAtRandom
        
        % Data plot axes (Axes type)
        DataPlotAxes
        
        % Plot lines (array of Line type)
        DataPlotLines
        OffsetAdjust
        
        timerNREM %Timer for last epoch of NREM
        timerREM
        
        snakeSize
        recordingTime
        maxSleepstages
        timerDeltaStart
        timeStartDelta
        
        deltaDensity
    end
    
    properties (Access = private, Hidden = false)
        SpectreWindowSize
        % Amplifier data for plotting        
        Amplifiers
        
        %Kejian, substraction
        Math
        
        % Offsets for the various amplifiers, for plotting        
        Offsets
        
       
        
        SnapshotAxes
        
        SnapshotLines
        

        
        % Spectre plot axes (Axes type) Jingyuan
        SleepStageAxes
        % Spectre Plot lines (array of Line type)Jingyuan
        SleepStageLinesLeft
        SleepStageLinesRight
        
        HilbertPlotAxes
        HilbertPlotLines
        
        PhaseSpaceAxes
        PhaseSpaceTrajectory
        PhaseSpaceLines
        
        gamma_distributionAxes
        gamma_distributionLines
        ratio_distributionAxes
        ratio_distributionLines

        % We'll implement a circular queue of data in Amplifiers; 
        % this is the index where we should store the next datablock
        %
        % So, for example, if we store 10 points and the values 1-10, our 
        % array would be:
        %        [1 2 3 4 5 6 7 8 9 10]
        % If we now store 11 and 12, our array would loop around and be:
        %        [11 12 3 4 5 6 7 8 9 10]
        % We can store data efficiently this way (because we're only 
        % overwriting the part where new data (e.g., 11 & 12) occurs.
        % There's some accounting when we need to get the data out to plot
        % (e.g., we'd get [3 4 5 6 7 8 9 10 11 12]); see the details below.
        SaveIndex
        
        SleepState %SleepState At the moment
    end
    
    methods

        
        function obj = BoardPlot(data_plot,sleep_stage, phase_space,gamma_distr,ratio_distr,...
                                snapshot, num_channels, samplingfreq)
            obj.passed=0;
            obj.detec_seuil=100;
            obj.fired=0;
            obj.detected=0;
            obj.recordingTime=0;
            obj.maxSleepstages=0;
            obj.DataPlotAxes = data_plot;
            obj.SpectreWindowSize=3;
            obj.OffsetAdjust=0;
            obj.timerDeltaStart=tic();
            obj.timeStartDelta=0;
            obj.SleepStageAxes = sleep_stage; %Jingyuan 
            obj.hilbert_filter_order = 332;
            obj.bullchannel = 12; %Default Bull CHannel is 12
            obj.coeff_bullfmin = 50;
            obj.coeff_bullfmax = 70;
            obj.Thetachannel = 16;
            obj.coeff_Thetafmin = 5;
            obj.coeff_Thetafmax = 10;
            obj.Deltachannel = 16;
            obj.coeff_Deltafmin = 2;
            obj.coeff_Deltafmax = 5;
            obj.coeff_Spectremax = 100;
            obj.samplingfreq=samplingfreq;
            obj.bullFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',obj.coeff_bullfmin,'CutoffFrequency2',obj.coeff_bullfmax,'SampleRate',obj.samplingfreq/60);
            obj.ThetaFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',obj.coeff_Thetafmin,'CutoffFrequency2',obj.coeff_Thetafmax,'SampleRate',obj.samplingfreq/60);           
            obj.DeltaFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',obj.coeff_Deltafmin,'CutoffFrequency2',obj.coeff_Deltafmax,'SampleRate',obj.samplingfreq/60);            
            obj.result = [];
            obj.timerNREM=0;
            %Setting up the spectrum analysis variables
            obj.BullData=zeros(1, ceil(obj.samplingfreq/60*obj.SpectreWindowSize));
            obj.ThetaData=zeros(1, ceil(obj.samplingfreq/60*obj.SpectreWindowSize));
            obj.DeltaData=zeros(1, ceil(obj.samplingfreq/60*obj.SpectreWindowSize));
            obj.deltaDensity=0;
            obj.PhaseSpaceAxes = phase_space; %Jingyuan
            obj.gamma_distributionAxes = gamma_distr;
            obj.ratio_distributionAxes = ratio_distr;
            
            
            obj.SnapshotAxes=snapshot;
            obj.NumChannels = num_channels;
            obj.SaveIndex = 1;
            obj.countermax=4/(1/samplingfreq)/60;  %default refractory time for fire is 4
            obj.countermax_detection=0.15/(1/samplingfreq)/60; %refractory time for detection is 0.3s
            

            % We'll display num_channels channels x 2040 time stamps 
            % (# of time stamps should be divisible by 60, as each data 
            % block contains 60 time stamps)
            obj.num_points = 1020;  %2040 as original, the window width. not very necessary bigger than 2000 because of the screen resolution limits.
            obj.ptperdb=1; % display parametre, take how many points from a datablock to inject to obj.Amplifiers. should >=1.
            % Create arrays for timestamp and amplifier data
            obj.Timestamps = 1:obj.num_points;
            obj.Time_real=obj.Timestamps*(1000*60/samplingfreq); %ms
            obj.counter=0;
            obj.counter_detection=0;
            obj.DeltaPoints_counter = 0;
            
            obj.Math_buffer_to_filter=zeros(1, obj.num_points);
            obj.Math_buffer_filtered=zeros(1, obj.num_points);
            obj.Math_filtered=0;
            [b,a]=butter(2,4/(samplingfreq/(2*60)));
            obj.DeltaFiltPFC_B=b;
            obj.DeltaFiltPFC_A=a;
            
            obj.Amplifiers = zeros(num_channels, obj.num_points); %pas de voies inutiles
            obj.Math = zeros(1, obj.num_points);
            obj.Math_filtered_display = zeros(1, obj.num_points);
            obj.SoundFile=zeros(1, obj.num_points)-0.5*ones(1,obj.num_points);
            obj.ThresholdFile=zeros(1,obj.num_points);
            obj.durationdb=60/samplingfreq;
            obj.durationbf=0.200; %s for showing the snapshot. the time before the detection to show
            obj.durationaft=0.800; %s
            obj.nbrptbf=ceil(obj.durationbf*obj.ptperdb/obj.durationdb);
            obj.nbrdbaft=ceil(obj.durationaft/obj.durationdb);
            obj.nbrptaft=ceil(obj.durationaft*obj.ptperdb/obj.durationdb);
            
            obj.stimulateDuringNREM=false;
            obj.stimulateDuringREM=false;
            obj.stimulateDuringWake=false;
            obj.stimulateAtRandom=false;
            
            
            % Channels are offset, so they're not all on top of each other
            obj.Offsets = (1:num_channels)' * ones(1,60) * 1e-3*0.5;
            
            % Create and set up the plot area
            axes(obj.DataPlotAxes);
            obj.DataPlotLines = plot(obj.Time_real, [obj.Amplifiers ; obj.Math  ;obj.SoundFile ; obj.ThresholdFile ; obj.Math_filtered_display]); %Kejian
            
            set(obj.DataPlotLines(5),'LineStyle','--');
            a = gca;
%             set(a,'xdir','reverse');
            l = get(a, 'XLabel');
            set(l, 'String', 'Time(ms)');
            set(l, 'FontSize', 9);
            l = get(a, 'YLabel');
            set(l, 'String', 'Amplitude (mV) - each channel is offset 0.5s mV');
            set(l, 'FontSize', 9);

            set(obj.DataPlotAxes, 'YLim', [-0.5 (1 + num_channels*0.5)]);
            set(obj.DataPlotAxes, 'XLim', [0 obj.Time_real(end)]);
            
            
            axes(obj.SnapshotAxes); 
            obj.SnapshotLines = plot(obj.Time_real(1:obj.nbrptbf+obj.nbrptaft+1), [obj.Amplifiers(:,1:obj.nbrptbf+obj.nbrptaft+1);obj.Math(1:obj.nbrptbf+obj.nbrptaft+1);obj.SoundFile(1:obj.nbrptbf+obj.nbrptaft+1);obj.ThresholdFile(1:obj.nbrptbf+obj.nbrptaft+1);obj.Math_filtered_display(1:obj.nbrptbf+obj.nbrptaft+1)]); %Kejian
            set(obj.SnapshotLines(5),'LineStyle','--');
            a = gca;
            l = get(a, 'XLabel');
            set(l, 'String', 'Time(ms)');
            set(l, 'FontSize', 9);
            l = get(a, 'YLabel');
            %set(l, 'String', 'Amplitude (mV) - each channel is offset 1 mV');
            set(l, 'FontSize', 9);

            set(obj.SnapshotAxes, 'YLim', [-0.5 (1 + num_channels*0.5)]);
            set(obj.SnapshotAxes, 'XLim', [0 obj.Time_real((obj.nbrptbf+obj.nbrptaft+2))]);
            
            a = gca;
            l = get(a, 'XLabel');
            set(l, 'String', 'Time(ms)');
            set(l, 'FontSize', 9);
            l = get(a, 'YLabel');
            set(l, 'FontSize', 9);
            
            % Create and set up the plot area for the spectre Jingyuan
            axes(obj.SleepStageAxes);
            [obj.SleepStageAxes,obj.SleepStageLinesLeft,obj.SleepStageLinesRight] = plotyy(0,0,0,0,'stairs','plot');
            set(obj.SleepStageAxes(1),{'XLimMode'},{'auto'});
            set(obj.SleepStageAxes(2),{'XLimMode'},{'auto'});
            set(obj.SleepStageAxes(2),{'YTickMode'},{'auto'});
            set(obj.SleepStageAxes(2),'YColor','r');
            set(obj.SleepStageAxes(1),'YTick',[]);
            l = get(obj.SleepStageAxes(1), 'XLabel');
            set(l, 'String', 'time (s)');
            set(l, 'FontSize', 9);
            set(obj.SleepStageAxes(1), 'YLim', [0 4]);
            set(obj.SleepStageAxes(2), 'YLim', [0 10]);
            set (obj.SleepStageLinesRight,'Color','r');
            
            
            % Create and set up the plot area of phase space and distribution Jingyuan
            axes (obj.PhaseSpaceAxes);
            obj.PhaseSpaceLines = plot([0],[0],'.',[0],[0],'rO',[0],[0],'r.',[0],[0],'g.',[0],[0],'b.',[0],[0],'k.-');
            set(gca,'XTick',[]);
            set(gca,'YTick',[]);
            set(obj.PhaseSpaceAxes, 'YLim', [-0.5 2.5]);
            set(obj.PhaseSpaceAxes, 'XLim', [-8 -5.5]);
            obj.snakeSize=10;

            axes(obj.gamma_distributionAxes);
            obj.gamma_distributionLines = plot(0,0);
            set(gca,'YTick',[]);
            a = gca;
            l = get(a, 'XLabel');
            set(l, 'String', 'Gamma Power (log scale)');
            set(l, 'FontSize', 9);
            set(obj.gamma_distributionAxes, 'XLim', [-8 -4]);
                        
            axes(obj.ratio_distributionAxes);
            obj.ratio_distributionLines = plot([0],[0],[0],[0]);
            set(gca,'XTick',[]);
            a = gca;
            l = get(a, 'YLabel');
            set(l, 'String', 'Theta / Delta power (log scale)');
            set(l, 'FontSize', 9);
            set(obj.ratio_distributionAxes, 'YLim', [-2 3]);
            
        end
        
        function refresh_display_now(obj,filter_activated)
        % Update the plot.
        %
        % This takes time, so you shouldn't call it every iteration if
        % you're running at a high sampling rate.
            indices = 1:length(obj.Timestamps);
            if obj.SaveIndex ~= 1
                % See note above, where SaveIndex is defined
                indices = [indices(obj.SaveIndex:end) indices(1:obj.SaveIndex-1)];
            end
            obj.ThresholdFile=obj.detec_seuil*ones(1,obj.num_points);
            mycell=[num2cell(obj.Amplifiers(:,indices), 2);num2cell(obj.Math(:,indices),2);num2cell(obj.SoundFile(:,indices),2);num2cell(obj.ThresholdFile(:,indices),2);num2cell(obj.Math_filtered_display(:,indices),2)];
            set(obj.DataPlotLines, {'YData'},mycell);
        end
        
        function refresh_snapshot(obj)
            indices = 1:length(obj.Timestamps);
            if obj.SaveIndex ~= 1
                % See note above, where SaveIndex is defined
                indices = [indices(obj.SaveIndex:end) indices(1:obj.SaveIndex-1)];
            end

            indices=indices(obj.num_points-obj.nbrptbf-obj.nbrptaft:end);
            mycell=[num2cell(obj.Amplifiers(:,indices),2);num2cell(obj.Math(:,indices),2);num2cell(obj.SoundFile(:,indices),2);num2cell(obj.ThresholdFile(:,indices),2);num2cell(obj.Math_filtered_display(:,indices),2)];
            set(obj.SnapshotLines, {'YData'},mycell);        
        end
        
        function Bull_filterdesign (obj)
           obj.bullFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',...
                                obj.coeff_bullfmin,'CutoffFrequency2',obj.coeff_bullfmax,'SampleRate',obj.samplingfreq/60);
                   
        end
        
        function Theta_filterdesign (obj)
           obj.ThetaFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',...
                                obj.coeff_Thetafmin,'CutoffFrequency2',obj.coeff_Thetafmax,'SampleRate',obj.samplingfreq/60);
        end
        
        function Delta_filterdesign(obj)
           obj.DeltaFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',...
                                obj.coeff_Deltafmin,'CutoffFrequency2',obj.coeff_Deltafmax,'SampleRate',obj.samplingfreq/60);
        end
                
        function hilbert_process_now(obj) %Sleep scoring is done here
        
        BullFiltered = filtfilt (obj.bullFilt,obj.BullData); %filter the data between fmin and fmax 
        BullEnv = abs(hilbert(BullFiltered)); % hilbert transfer
        obj.result(1) = mean (BullEnv);
        
        ThetaFiltered = filtfilt (obj.ThetaFilt,obj.ThetaData); %filter the data between fmin and fmax
        ThetaEnv = abs( hilbert(ThetaFiltered)); % hilbert transfer
        obj.result(2) = mean(ThetaEnv);
        
        DeltaFiltered = filtfilt (obj.DeltaFilt,obj.DeltaData); %filter the data between fmin and fmax
        DeltaEnv = abs( hilbert(DeltaFiltered)); % hilbert transform
        DeltaEnv(DeltaEnv<0.01)=0.01; %To avoid strange values
        obj.result(3)=mean(DeltaEnv);
        obj.ratioData = ThetaEnv./DeltaEnv;
        obj.result(4)= mean(obj.ratioData);
        
        %%Test SleepState
        if(obj.threshold_status == 1)
            if(obj.result(1)>10^(obj.gamma_threshold))
                obj.SleepState=3; %Wake 
                obj.timerNREM=0;
                obj.timerREM=0;
            else 
                if(obj.result(4)>10^(obj.ratio_threshold))
                     obj.SleepState=2; %REM 
                     obj.timerNREM=0;
                     obj.timerREM=obj.timerREM+1;
                else
                    obj.SleepState=1; %NREM
                    obj.timerNREM=obj.timerNREM+1;
                    obj.timerREM=0;
                end
            end
        end
        end
         
         function refresh_sleepstage_now (obj,timestamps,sleepstage)
             time=timestamps(timestamps<obj.maxSleepstages & timestamps>(obj.maxSleepstages-3600));
             sleep=sleepstage(timestamps<obj.maxSleepstages & timestamps>(obj.maxSleepstages-3600));
             time=time(sleep>0);
             sleep=sleep(sleep>0);
             %set (obj.SleepStageLinesLeft,'XData',time,'YData',sleep);
             if length(sleep)>0
                drawHypnogram(obj.SleepStageAxes,time,sleep);
             end
             obj.recordingTime=timestamps(end);
         end
         
         function detection_number_now (obj,timestamps,nb_detection,detections)
             set(obj.SleepStageAxes(2),{'XLimMode'},{'auto'});
             set (obj.SleepStageLinesRight,'XData',timestamps(timestamps<obj.maxSleepstages & timestamps>(obj.maxSleepstages-3600)),'YData',smooth(nb_detection(timestamps<obj.maxSleepstages & timestamps>(obj.maxSleepstages-3600))));
             lastDeltas=detections(detections(:,1)>(detections(end,1)-4E4),:);
             obj.deltaDensity=sum(lastDeltas(:,1)-lastDeltas(:,2))/4E4;
         end
         
        function refresh_phasespace_now(obj,timestamps,gamma,ratio) 

            if (size(timestamps)>1)%delete the initialization point except there is only one point
                timestamps (1) = [];
                gamma (1) = [];
                ratio (1) = [];
            end
            
            gamma = log10(gamma);
            ratio = log10(ratio);
            
            
            if (timestamps(end)>2*3600) % only display the points in the last 2 h
                indice = find (timestamps > (timestamps(end)-2*3600),1);
                gamma(1:indice-1) = [];
                ratio(1:indice-1) = [];
            end
            
            if(length(gamma)>obj.snakeSize+1) %indicate the last 10 points with black snake
                if( obj.threshold_status==1)
                    set(obj.PhaseSpaceLines(1),'Color','none');
                    gamma_disp=gamma(3:end);
                    ratio_disp=ratio(3:end);
                    ratio_sleep=ratio_disp(find(gamma_disp<obj.gamma_threshold));
                    gamma_sleep=gamma_disp(find(gamma_disp<obj.gamma_threshold));
                    if(~isempty(gamma_disp(find(gamma_disp>obj.gamma_threshold))))
                        set(obj.PhaseSpaceLines(3),'XData',gamma_disp(find(gamma_disp>obj.gamma_threshold)),'YData',ratio_disp(find(gamma_disp>obj.gamma_threshold)));
                    end
                    if(~isempty(gamma_sleep))
                        if(~isempty(gamma_sleep(find(ratio_sleep<obj.ratio_threshold))))
                            set(obj.PhaseSpaceLines(4),'XData',gamma_sleep(find(ratio_sleep<obj.ratio_threshold)),'YData',ratio_sleep(find(ratio_sleep<obj.ratio_threshold)));
                        end
                        if(~isempty(gamma_sleep(find(ratio_sleep>obj.ratio_threshold))))
                            set(obj.PhaseSpaceLines(5),'XData',gamma_sleep(find(ratio_sleep>obj.ratio_threshold)),'YData',ratio_sleep(find(ratio_sleep>obj.ratio_threshold)));
                        end
                    end
                else
                    set(obj.PhaseSpaceLines(1),'XData',gamma(3:(end-obj.snakeSize)),'YData',ratio(3:(end-obj.snakeSize)));
                end
                set(obj.PhaseSpaceLines(6),'XData',gamma((end-obj.snakeSize+1):end),'YData',ratio((end-obj.snakeSize+1):end));
                set(obj.PhaseSpaceLines(2),'XData',gamma(end),'YData',ratio(end));
                [obj.gamma_prob,obj.gamma_value] = ksdensity (gamma(3:end));
                [obj.ratio_prob,obj.ratio_value] = ksdensity (ratio(3:end)); 
            else
                set(obj.PhaseSpaceLines(1),'XData',gamma,'YData',ratio);
                [obj.gamma_prob,obj.gamma_value] = ksdensity (gamma);
                [obj.ratio_prob,obj.ratio_value] = ksdensity (ratio); 
            end
            
            set(obj.PhaseSpaceAxes, 'XLim', [(min(obj.gamma_value)-1) (max(obj.gamma_value)+1)]);
            set(obj.PhaseSpaceAxes, 'YLim', [(min(obj.ratio_value)-1) (max(obj.ratio_value)+1)]);
            
            
            
            set(obj.gamma_distributionLines,'XData',obj.gamma_value,'YData',obj.gamma_prob);
            set(obj.gamma_distributionAxes, 'XLim',  [(min(obj.gamma_value)-1) (max(obj.gamma_value)+1)]);
             

            set(obj.ratio_distributionLines(1),'XData',obj.ratio_prob,'YData',obj.ratio_value);
            set(obj.ratio_distributionAxes, 'YLim', [(min(obj.ratio_value)-1) (max(obj.ratio_value)+1)]);
            if(obj.threshold_status==1) 
                [obj.ratio_probSleep,obj.ratio_valueSleep] = ksdensity (ratio(find(gamma<(obj.gamma_threshold))));
                set(obj.ratio_distributionLines(2),'XData',obj.ratio_probSleep,'YData',obj.ratio_valueSleep);
            end
            
        end
        
        function set_thethreshold_now(obj,gamma_threshold,ratio_threshold)

            delete (obj.vline_phase); %firstly clear the old reference line
            delete (obj.hline_phase);
            delete (obj.vline_gamma);
            delete (obj.hline_ratio);
            obj.gamma_threshold=gamma_threshold;
            obj.ratio_threshold=ratio_threshold;

            
             if (obj.threshold_status==1 & ~isempty(obj.ratio_value)) 
                obj.vline_phase = line([gamma_threshold gamma_threshold],[(min(obj.ratio_value)-1) (max(obj.ratio_value)+1)],'LineStyle','--','Color','red','Parent',obj.PhaseSpaceAxes);
                obj.hline_phase = refline(obj.PhaseSpaceAxes,[0 ratio_threshold]);
                set (obj.hline_phase,'LineStyle','--');
                obj.vline_gamma = line([gamma_threshold gamma_threshold],[0 max(obj.gamma_prob)],'LineStyle','--','Color','red','Parent',obj.gamma_distributionAxes);
                obj.hline_ratio = refline(obj.ratio_distributionAxes,[0 ratio_threshold]);
                set (obj.hline_ratio,'LineStyle','--');
            end
        end
        
        % Jingyuan
        function obj = set_coeff_spectrefreq(obj,spectrefmin,spectrefmax)
            obj.coeff_spectrefmin = spectrefmin;
            obj.coeff_spectrefmax = spectrefmax;
        end
        
        function obj = Spectre_data_block(obj,datablock)  % Jingyuan Sve the data from Datablock to a new array
            obj.BullData = [obj.BullData(2:end), mean(datablock.Chips{obj.ChipIndex}.Amplifiers(obj.bullchannel,:))*1000];
            obj.ThetaData = [obj.ThetaData(2:end), mean(datablock.Chips{obj.ChipIndex}.Amplifiers(obj.Thetachannel,:))*1000];
            obj.DeltaData = [obj.DeltaData(2:end), mean(datablock.Chips{obj.ChipIndex}.Amplifiers(obj.Deltachannel,:))*1000];
        end
        
        function obj = process_data_block(obj, datablock,arduino,filter_activated)
            % Called to process a data block; stores the new data in Amplifiers
            
            % In either case, we keep a rolling window of the form
            % [(existing data) (new datablock)], where the data is always offset so
            % that multiple channels can be overlaid on top of each other
            
            
            %it's a MEAN, which means only the value of the average 60
            %samples in a datablock
            newdata_original=mean([obj.prefactors(1),0;0,obj.prefactors(2)]*... %matrix multiplication for the prefactors
                datablock.Chips{obj.ChipIndex}.Amplifiers(obj.Channels,:),2);  %the last 2 is a parameter for the mean function
            newdata_math=newdata_original(1,:)-newdata_original(2,:);
            newdata_sound=-0.5*ones(1,obj.ptperdb);
            newdata_time=datablock.Timestamps;
            if filter_activated==1
                obj.Math_buffer_to_filter=[obj.Math_buffer_to_filter(2:end) newdata_math];
                filtered = filtfilt(obj.DeltaFiltPFC_B,obj.DeltaFiltPFC_A ,obj.Math_buffer_to_filter);
                obj.Math_filtered=filtered(end);
            end
            
            if(obj.stimulateAtRandom & obj.detec_status==1) %stimulate at random
                p=0.0001;
                if (obj.counter_detection>obj.countermax_detection)
                    if strcmp(arduino.Status,'open')
                        fwrite(arduino,00);
                    end
                    if (obj.wait_status==1)&&(obj.fired==0)
                        if(rand()>(1-p) & obj.counter>obj.countermax)
                            if strcmp(arduino.Status,'open')
                                fwrite(arduino,obj.sound_mode*10+obj.sound_tone);%the mode and the sound are sent to the arduino as an integer AB => A is the mode and B is the sound type
                            end
                            newdata_sound=3*ones(1,obj.ptperdb);
                            obj.fired=1;
                            obj.counter=0;
                            
                            obj.detected=1;
                            obj.counter_detection=0;
                        end
                    end
                end
            end
            
            if (obj.detec_status==1 & (~obj.stimulateDuringNREM & ~obj.stimulateDuringREM & ~obj.stimulateDuringWake)) | (obj.SleepState==1 & obj.stimulateDuringNREM &  obj.detec_status==1) | (obj.SleepState==2 & obj.stimulateDuringREM &  obj.detec_status==1) | (obj.SleepState==3 & obj.stimulateDuringWake &  obj.detec_status==1)% means the user wants to detect the pic
                obj.counter=obj.counter+1;  %in initialization it was 0
                obj.counter_detection=obj.counter_detection+1;
                % the refractory time of the detection
                
                if (obj.Math_filtered>=obj.detec_seuil*1e-3 & filter_activated==1) | (newdata_math(end)>=obj.detec_seuil*1e-3 & filter_activated==0)
                    if  obj.DeltaPoints_counter==0
                        obj.timerDeltaStart=tic();
                        obj.timeStartDelta=double(obj.Time(end))/20000;
                    end
                    obj.DeltaPoints_counter = obj.DeltaPoints_counter + 1;
                    
                elseif (toc(obj.timerDeltaStart)> 0.05 && toc(obj.timerDeltaStart) <0.15) && ((double(obj.Time(end))/20000-obj.timeStartDelta)>0.05 && (double(obj.Time(end))/20000-obj.timeStartDelta)<0.15)
                    if (obj.counter>obj.countermax) && (obj.wait_status==1)&&(obj.fired==0)
                        disp('good delta wave fired (50ms < duration < 150ms)');
                        obj.detected=1;
                        obj.counter=0;
                        obj.counter_detection=0;
                        obj.DeltaPoints_counter = 0;
                        if strcmp(arduino.Status,'open')
                            fwrite(arduino,obj.sound_mode*10+obj.sound_tone);
                        end
                        newdata_sound=3*ones(1,obj.ptperdb);
                        obj.fired=1;
                        toc(obj.timerDeltaStart)
                    elseif (obj.counter_detection>obj.countermax_detection) && (obj.wait_status==1) && (obj.detected==0)
                        disp('good delta wave (50ms < duration < 150ms)');
                        obj.detected=1;
                        obj.counter_detection=0;
                        obj.DeltaPoints_counter = 0;
                        toc(obj.timerDeltaStart)
                        if strcmp(arduino.Status,'open')
                            fwrite(arduino,00);
                        end
                    end
                else
                    obj.DeltaPoints_counter = 0;
                end
                
            end
        newdata = newdata_original + obj.Offsets(obj.StoreChannels,1)+[0, obj.OffsetAdjust]';  %%%%%
        
        
        % inject the data from newdata, newdata_math, newdata_sound to
        % Amplifiers, Math, and SoundFile. these properties are only for
        % display purpose.
        % ATTENTION: we don't inject all the data to these properties,
        % only take ptperdb(here 1 point) to inject. Otherwise the
        % display will roll too rapidely in the screen.
        
        
        % Scale to mV, rather than V.
        obj.Amplifiers(obj.StoreChannels,obj.SaveIndex:(obj.SaveIndex+obj.ptperdb-1)) =  newdata*1000; %Injection from newdata to obj.amplifiers
        obj.Math(obj.SaveIndex:(obj.SaveIndex+obj.ptperdb-1))=newdata_math*1000;
        obj.SoundFile(obj.SaveIndex:(obj.SaveIndex+obj.ptperdb-1))=newdata_sound;
        obj.Time=newdata_time;
        if filter_activated==1
            obj.Math_filtered_display(obj.SaveIndex:(obj.SaveIndex+obj.ptperdb-1))=obj.Math_filtered*1000;
        end
        
        %obj.Math(obj.SaveIndex:(obj.SaveIndex+59))=newdata_math*1000;
        
        % And loop SaveIndex, the index into our circular buffer.
        obj.SaveIndex = obj.SaveIndex + obj.ptperdb;
        if obj.SaveIndex > length(obj.Timestamps)
            obj.SaveIndex = 1;
        end
    end
        
        function obj = clear_data(obj)
        % Zero out obj.Amplifiers and reset.
            
            sz = size(obj.Amplifiers);
            obj.Amplifiers = zeros(sz);

            obj.SaveIndex = 1;
        end
        
        
        function a=sendoutchannels(obj) %Kejian
            a = obj.Channels;
        end
        
        function obj=testArduino(obj)
            if strcmp(arduino.Status,'open')
                fwrite(arduino,1*10+obj.sound_tone); %the mode and the sound are sent to the arduino as an integer AB => A is the mode and B is the sound type
            end
        end
        function DeltaPFC_filterdesign(obj,order,fmin,fmax)
            [b,a]=butter(order,fmax/(obj.samplingfreq/(2*60)));
            obj.DeltaFiltPFC_B=b;
            obj.DeltaFiltPFC_A=a;
        end
        function obj=triggerArduino(obj, arduino)
            if strcmp(arduino.Status,'open')
                 fwrite(arduino,60); %Mode 6=> trigger video
            end
        end
            

    end
    
end

