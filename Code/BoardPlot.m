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
        deltaDensity
        
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
        %Kejian, substraction
        Math
        Time_real
        Math_buffer_to_filter % a public property, cause needs to be created when click the filter "Apply"
        Math_buffer_filtered % buffer for IIR filter
        Math_filtered %Stores the output of the filtering of the difference
        Math_filtered_display
        sound_tone %Type of sound played during stimulation
        Time
        DeltaStart
        DeltaEnd

        % Jingyuan
        hilbert_filter_order % Order of the filter used to filter the signal prior to hilbert transform
                 
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
        DeltaPFCData
        %Stimulate during NREM Sleep
        stimulateDuringNREM
        
        stimulateDuringREM
        
        stimulateDuringWake
        stimulateAtRandom
        
        % Data plot axes (Axes type)
        DataPlotAxes
        
        % Plot lines (array of Line type)
        DataPlotLines
        OffsetAdjustSup
        OffsetAdjustDeep
        
        timerNREM %Timer for last epoch of NREM
        timerREM
        timerWake
        
        snakeSize %Size of the snake
        recordingTime %Total recording time
        maxSleepstages %Max timestamp to display in hypnogram
        timerDeltaStart %Timestamp of the beginning of the delta wave
        timeStartDelta%Timestamp of the end of the delta wave
        saveIndexStartDelta%SaveIndex of the end of the delta wave
        saveIndexEndDelta%SaveIndex of the end of the delta wave
        minDuration%Min duration to detect
        maxDuration%Max duration to detect
        
        meanDelta
        numberDetection

        
        SleepState %SleepState At the moment
        
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
        
        GMModel
        probREM
        probNREM
        probWake
        PhaseSpaceAxes
    end
    
    properties (Access = private, Hidden = false)
        SpectreWindowSize
        % Amplifier data for plotting        
        Amplifiers
        
        
        
        % Offsets for the various amplifiers, for plotting        
        Offsets
        
       
        
        SnapshotAxes
        
        SnapshotLines
        

        
        % Spectre plot axes (Axes type) Jingyuan
        SleepStageAxes
        % Spectre Plot lines (array of Line type)Jingyuan
        SleepStageLines
        SleepStagePatches
        DeltaDensityLines
        
        HilbertPlotAxes
        HilbertPlotLines
        
        PhaseSpaceTrajectory
        PhaseSpaceLines
        
        gamma_distributionAxes
        gamma_distributionLines
        ratio_distributionAxes
        ratio_distributionLines
        
        
        meanDeltaAxes
        meanDeltaLines
        
    end
    
    methods

        
        function obj = BoardPlot(data_plot,sleep_stage, phase_space,gamma_distr,ratio_distr,...
                                snapshot, num_channels, samplingfreq,meanDeltaPlot)
            obj.passed=0;
            obj.detec_seuil=100;
            obj.fired=0;%Send firing signal to interface=> update plots
            obj.detected=0;%Send detection signal to interface => update 
            obj.recordingTime=0;
            obj.maxSleepstages=0;
            obj.DataPlotAxes = data_plot; %Axes for plotting signals
            obj.SpectreWindowSize=3; % Duration of the sleep scoring time window
            obj.OffsetAdjustSup=0; % Offset of PFCsup for display adjusted by a click on button
            obj.OffsetAdjustDeep=0;% Offset of PFCDeep for display adjusted by a click on button
            obj.timerDeltaStart=tic(); %Time of the beginning of the delta wave
            obj.timeStartDelta=0; %Timestamp beginning of the delta wave
            obj.SleepStageAxes = sleep_stage; % Axes of the hypnogram 
            obj.hilbert_filter_order = 332; %order of the sleep scoring filters
            obj.bullchannel = 12; %Channel of the bulb signal
            obj.coeff_bullfmin = 50; %Fmin for OB gamma
            obj.coeff_bullfmax = 70;%Fmax for OB gamma
            obj.Thetachannel = 16; %Hippocamp channel
            obj.coeff_Thetafmin = 5;%Fmin for theta
            obj.coeff_Thetafmax = 10;%Fmax for theta
            obj.Deltachannel = 16;%Hippocamp channel
            obj.coeff_Deltafmin = 2;%Fmin for delta
            obj.coeff_Deltafmax = 5;%Fmax for delta
            
            obj.samplingfreq=samplingfreq; %Sampling frequency, usually 20 000Hz
            
            %%Filters for sleep scoring
            obj.bullFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',obj.coeff_bullfmin,'CutoffFrequency2',obj.coeff_bullfmax,'SampleRate',obj.samplingfreq/60);
            obj.ThetaFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',obj.coeff_Thetafmin,'CutoffFrequency2',obj.coeff_Thetafmax,'SampleRate',obj.samplingfreq/60);           
            obj.DeltaFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',obj.coeff_Deltafmin,'CutoffFrequency2',obj.coeff_Deltafmax,'SampleRate',obj.samplingfreq/60);            
            %% results of the sleep scoring process
            obj.result = [];
            obj.timerNREM=0;
            obj.timerWake=0;
            
            %Setting up the spectrum analysis variables
            obj.BullData=zeros(1, ceil(obj.samplingfreq/60*obj.SpectreWindowSize));
            obj.ThetaData=zeros(1, ceil(obj.samplingfreq/60*obj.SpectreWindowSize));
            obj.DeltaData=zeros(1, ceil(obj.samplingfreq/60*obj.SpectreWindowSize));
            obj.DeltaPFCData=zeros(1, ceil(obj.samplingfreq/60*obj.SpectreWindowSize));
                        
            obj.PhaseSpaceAxes = phase_space; %Phase space axes
            obj.gamma_distributionAxes = gamma_distr;
            obj.ratio_distributionAxes = ratio_distr;
            
            
            obj.SnapshotAxes=snapshot;
            obj.NumChannels = num_channels;
            obj.SaveIndex = 1;
            obj.countermax=4/(1/samplingfreq)/60;  %default refractory time for fire is 4
            obj.countermax_detection=0.15/(1/samplingfreq)/60; %refractory time for detection is 0.15s
            

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
            obj.minDuration = 0.05;
            obj.maxDuration = 0.15;
            
            obj.numberDetection=0;
            %% Delta detection filtering
            obj.Math_buffer_to_filter=zeros(1, obj.num_points);
            obj.Math_buffer_filtered=zeros(1, obj.num_points);
            obj.Math_filtered=0;
            [b,a]=butter(2,8/(samplingfreq/(2*60)));
            obj.DeltaFiltPFC_B=b;
            obj.DeltaFiltPFC_A=a;
            %% Signals to plot
            obj.Amplifiers = zeros(num_channels, obj.num_points); %pas de voies inutiles
            obj.Math = zeros(1, obj.num_points);
            obj.Math_filtered_display = zeros(1, obj.num_points);
            obj.SoundFile=zeros(1, obj.num_points)-0.5*ones(1,obj.num_points);
            obj.DeltaStart=zeros(1, obj.num_points)-0.5*ones(1,obj.num_points);
            obj.DeltaEnd=zeros(1, obj.num_points)-0.5*ones(1,obj.num_points);
            obj.ThresholdFile=zeros(1,obj.num_points);
            %% Configuration of the snapshot window
            obj.durationdb=60/samplingfreq;
            obj.durationbf=0.300; %s for showing the snapshot. the time before the detection to show
            obj.durationaft=0.500; %s time time after the detection
            obj.nbrptbf=ceil(obj.durationbf*obj.ptperdb/obj.durationdb);
            obj.nbrdbaft=ceil(obj.durationaft/obj.durationdb);
            obj.nbrptaft=ceil(obj.durationaft*obj.ptperdb/obj.durationdb);
            
            obj.meanDelta=zeros(2,obj.nbrptbf+obj.nbrptaft+1);
            %% Stimulate during specific sleepstage
            obj.stimulateDuringNREM=false;
            obj.stimulateDuringREM=false;
            obj.stimulateDuringWake=false;
            obj.stimulateAtRandom=false;
            
            %% Save index of the start and end of the detected delta wave => used for display in snapshot
            obj.saveIndexStartDelta=0;
            obj.saveIndexEndDelta=0;
            
            
            % Channels are offset, so they're not all on top of each other
            obj.Offsets = (1:num_channels)' * ones(1,60) * 1e-3*0.5;
            obj.Offsets([1,2],:) = obj.Offsets([2,1],:);
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
            obj.SnapshotLines = plot(obj.Time_real(1:obj.nbrptbf+obj.nbrptaft+1)-obj.durationbf*1E3, [obj.Amplifiers(:,1:obj.nbrptbf+obj.nbrptaft+1);obj.Math(1:obj.nbrptbf+obj.nbrptaft+1);obj.SoundFile(1:obj.nbrptbf+obj.nbrptaft+1);obj.ThresholdFile(1:obj.nbrptbf+obj.nbrptaft+1);obj.Math_filtered_display(1:obj.nbrptbf+obj.nbrptaft+1)],[0],[0],'r--',[0],[0],'k--'); %Kejian
            set(obj.SnapshotLines(5),'LineStyle','--');
            a = gca;
            l = get(a, 'XLabel');
            set(l, 'String', 'Time(ms)');
            set(l, 'FontSize', 9);
            l = get(a, 'YLabel');
            %set(l, 'String', 'Amplitude (mV) - each channel is offset 1 mV');
            set(l, 'FontSize', 9);

            set(obj.SnapshotAxes, 'YLim', [-0.5 (1 + num_channels*0.5)]);
            set(obj.SnapshotAxes, 'XLim', [-obj.durationbf*1E3 obj.Time_real((obj.nbrptbf+obj.nbrptaft+2))-obj.durationbf*1E3]);
            
            a = gca;
            l = get(a, 'XLabel');
            set(l, 'String', 'Time(ms)');
            set(l, 'FontSize', 9);
            l = get(a, 'YLabel');
            set(l, 'FontSize', 9);
            
            % Create and set up the plot area for the spectre Jingyuan
            axes(obj.SleepStageAxes);
            obj.SleepStageLines = plot(0,0,0,0);
            l = get(obj.SleepStageAxes, 'XLabel');
            set(l, 'String', 'time (s)');
            set(l, 'FontSize', 9);
            set(obj.SleepStageAxes, 'YLim', [0 4]);
            set(obj.SleepStageAxes, 'YTick', [1 2 3]);
            set(obj.SleepStageAxes, 'YTickLabel', {'NREM' 'REM' 'WAKE'});
            obj.SleepStagePatches=patch(obj.SleepStageAxes,[0],[0],[0],'EdgeColor','flat','LineWidth',2);
            
            
            % Create and set up the plot area of phase space and distribution Jingyuan
            axes (obj.PhaseSpaceAxes);
            obj.PhaseSpaceLines = plot([0],[0],'.',[0],[0],'rO',[0],[0],'r.',[0],[0],'g.',[0],[0],'b.',[0],[0],'k.-');
            set(gca,'XTick',[]);
            set(gca,'YTick',[]);
            uistack(obj.PhaseSpaceLines(2),'top');
            set(obj.PhaseSpaceLines(6),'LineWidth',2);
            set(obj.PhaseSpaceLines(3),'Color',[0.7 0 0],'MarkerSize',10);
            set(obj.PhaseSpaceLines(4),'Color',[0 0.7 0],'MarkerSize',10);
            set(obj.PhaseSpaceLines(5),'Color',[0 0 0.5],'MarkerSize',10);
            set(obj.PhaseSpaceLines(6),'LineWidth',2);
            set(obj.PhaseSpaceLines(2),'MarkerSize',15,'MarkerEdgeColor',[0 0 0],'MarkerFaceColor',[0.7 1 0.2]);
            set(obj.PhaseSpaceAxes, 'YLim', [-0.5 2.5]);
            set(obj.PhaseSpaceAxes, 'XLim', [-8 -5.5]);
            obj.snakeSize=10;

            axes(obj.gamma_distributionAxes);
            obj.gamma_distributionLines = plot([0],[0]);
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
            
            obj.meanDeltaAxes=meanDeltaPlot;
            axes(obj.meanDeltaAxes);
            obj.meanDeltaLines=plot([0],[0],[0],[0]);
            set(obj.meanDeltaLines(1),'XData',obj.Time_real(1:obj.nbrptbf+obj.nbrptaft+1)-obj.durationbf*1E3,'YData',obj.meanDelta(1,:));
            set(obj.meanDeltaLines(2),'XData',obj.Time_real(1:obj.nbrptbf+obj.nbrptaft+1)-obj.durationbf*1E3,'YData',obj.meanDelta(2,:));
            a = gca;
            l = get(a, 'XLabel');
            set(l, 'String', 'Time(ms)');
            set(l, 'FontSize', 9);
            l = get(a, 'YLabel');
            %set(l, 'String', 'Amplitude (mV) - each channel is offset 1 mV');
            set(l, 'FontSize', 9);

            set(obj.meanDeltaAxes, 'YLim', [-0.5 1]);
            set(obj.meanDeltaAxes, 'XLim', [-obj.durationbf*1E3 obj.Time_real((obj.nbrptbf+obj.nbrptaft+2))-obj.durationbf*1E3]);
            
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
            obj.numberDetection=obj.numberDetection+1;
            indices = 1:length(obj.Timestamps);           
            if obj.SaveIndex ~= 1
                % See note above, where SaveIndex is defined
                indices = [indices(obj.SaveIndex:end) indices(1:obj.SaveIndex-1)];
            end
            
            indices=indices(obj.num_points-obj.nbrptbf-obj.nbrptaft:end);
            startDelta=find(obj.DeltaStart(:,indices)==3); %% Showing the beginning of the detection
            endDelta=find(obj.DeltaEnd(:,indices)==3);
            if length(endDelta)>1
                endDelta=endDelta(end);
            end
            startDelta=startDelta(startDelta<endDelta);
            if length(startDelta)>1
                startDelta=startDelta(end);
            end
            %% prepare for plotting
            mycell=[num2cell(obj.Amplifiers(:,indices),2);num2cell(obj.Math(:,indices),2);num2cell(obj.SoundFile(:,indices),2);num2cell(obj.ThresholdFile(:,indices),2);num2cell(obj.Math_filtered_display(:,indices),2)];
            set(obj.SnapshotLines(1:6), {'YData'},mycell);
            obj.meanDelta=obj.meanDelta+(obj.Amplifiers(:,indices)- obj.Offsets(obj.StoreChannels,1)*1E3+[obj.OffsetAdjustDeep, obj.OffsetAdjustSup]'*1E3);
            set(obj.meanDeltaLines(1),'YData',obj.meanDelta(1,:)/obj.numberDetection);
            set(obj.meanDeltaLines(2),'YData',obj.meanDelta(2,:)/obj.numberDetection);
            set(obj.SnapshotLines(7),'XData',[obj.SnapshotLines(1).XData(startDelta) obj.SnapshotLines(1).XData(startDelta)],'YData',obj.SnapshotAxes.YLim);
            set(obj.SnapshotLines(8),'XData',[obj.SnapshotLines(1).XData(endDelta) obj.SnapshotLines(1).XData(endDelta)],'YData',obj.SnapshotAxes.YLim);
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
        sleepScoring(obj);
        end
         
         function refresh_sleepstage_now (obj,timestamps,sleepstage)
             % Plot the hynogram
             time=timestamps(timestamps<obj.maxSleepstages & timestamps>(obj.maxSleepstages-3600));
             sleep=sleepstage(timestamps<obj.maxSleepstages & timestamps>(obj.maxSleepstages-3600));
             time=time(sleep>0);
             sleep=sleep(sleep>0);
             if length(sleep)>1
                drawHypnogram(obj.SleepStageLines(1),obj.SleepStageAxes,obj.SleepStagePatches,time,sleep);
             end
             obj.recordingTime=timestamps(end);
         end
         
         function detection_number_now (obj,timestamps,nb_detection,detections)
             %%Plotting Delta density on the Hypnogram defined as delta
             %%duration in the last 4 seconds (cf read_continuously
             %%handles.detections)
             if length(detections)>1
             set(obj.SleepStageLines(2),'XData',detections(detections(:,1)/1E4<obj.maxSleepstages & detections(:,1)/1E4>(obj.maxSleepstages-3600),2)/1E4,'YData',smooth(detections(detections(:,1)/1E4<obj.maxSleepstages & detections(:,1)/1E4>(obj.maxSleepstages-3600),3),5));
             end
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
            
            set(obj.PhaseSpaceAxes, 'XLim', [(min(obj.gamma_value)) (max(obj.gamma_value))]);
            set(obj.PhaseSpaceAxes, 'YLim', [(min(obj.ratio_value)) (max(obj.ratio_value))]);
            
            
            %% plot gamma and theta/delta distributions
            set(obj.gamma_distributionLines(1),'XData',obj.gamma_value,'YData',obj.gamma_prob);
            set(obj.gamma_distributionAxes, 'XLim',  [(min(obj.gamma_value)) (max(obj.gamma_value))]);
             

            set(obj.ratio_distributionLines(1),'XData',obj.ratio_prob,'YData',obj.ratio_value);
            set(obj.ratio_distributionAxes, 'YLim', [(min(obj.ratio_value)) (max(obj.ratio_value))]);
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
        
        function obj = Spectre_data_block(obj,datablock)  % Jingyuan Sve the data from Datablock to a new array for further sleep scoring processing
            obj.BullData = [obj.BullData(2:end), mean(datablock.Chips{obj.ChipIndex}.Amplifiers(obj.bullchannel,:))*1000];
            obj.ThetaData = [obj.ThetaData(2:end), mean(datablock.Chips{obj.ChipIndex}.Amplifiers(obj.Thetachannel,:))*1000];
            obj.DeltaData = [obj.DeltaData(2:end), mean(datablock.Chips{obj.ChipIndex}.Amplifiers(obj.Deltachannel,:))*1000];
            if(sum(obj.Math_filtered)~=0)
                obj.DeltaPFCData = [obj.DeltaPFCData(2:end), obj.Math_filtered_display(obj.SaveIndex)];
            else
                obj.DeltaPFCData = [obj.DeltaPFCData(2:end), obj.Math(obj.SaveIndex)];
            end
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
            newdata_deltaStart=-0.5*ones(1,obj.ptperdb);
            newdata_deltaEnd=-0.5*ones(1,obj.ptperdb);
            newdata_time=datablock.Timestamps;
            if filter_activated==1
                obj.Math_buffer_to_filter=[obj.Math_buffer_to_filter(2:end) newdata_math];
                filtered = filtfilt(obj.DeltaFiltPFC_B,obj.DeltaFiltPFC_A ,obj.Math_buffer_to_filter);
                obj.Math_filtered=filtered(end);
            end
            %% We call deltaDetection to detect delta waves
            [newdata_sound, newdata_deltaStart, newdata_deltaEnd]=deltaDetection(arduino,newdata_sound,newdata_deltaStart,newdata_deltaEnd,obj,newdata_math,filter_activated);
            newdata = newdata_original + obj.Offsets(obj.StoreChannels,1)+[obj.OffsetAdjustDeep, obj.OffsetAdjustSup]';  % Adjust the offsets            
            
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
            obj.DeltaStart(obj.SaveIndex:(obj.SaveIndex+obj.ptperdb-1))=newdata_deltaStart;
            obj.DeltaEnd(obj.SaveIndex:(obj.SaveIndex+obj.ptperdb-1))=newdata_deltaEnd;
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
        function DeltaPFC_filterdesign(obj,order,fmax)
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

