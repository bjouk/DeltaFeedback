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
        timer2
        passed
        counter
        counter_detection
        countermax
        countermax_detection
        ptperdb %>=1 db:datablock
        
        durationdb
        durationbf
        durationaft
        nbrptbf
        nbrdbaft
        nbrptaft
        
        samplingfreq
        num_points
        prefactors
        
        Timestamps
        
        Time_real
        Math_buffer_to_filter % a public property, cause needs to be created when click the filter "Apply"
        Math_buffer_filtered % buffer for IIR filter
        Math_filtered
        Math_filtered_display
        coeff_filter
        sound_tone
        %Microphone data
        MicrophoneFile

        % Jingyuan
        hilbert_filter_order 
         
        coeff_Spectremax 
        
        coeff_bullfmin 
        coeff_bullfmax 
        bullchannel 
        bullpxx
        bullfreq
        bullfmin_indice
        bullfmax_indice
        bullFilt
        
        coeff_HPCfmin 
        coeff_HPCfmax 
        HPCchannel 
        HPCpxx
        HPCfreq
        HPCfmin_indice
        HPCfmax_indice
        HPCFilt
        
        coeff_PFCxfmin 
        coeff_PFCxfmax 
        PFCxchannel 
        PFCxpxx
        PFCxfreq
        PFCxfmin_indice
        PFCxfmax_indice
        PFCxFilt
        
        ratioData
        
        result
        
        gamma_prob
        gamma_value
        ratio_prob
        ratio_value
        gamma_threshold
        threshold_status
        vline_phase
        hline_phase
        vline_gamma
        hline_ratio
                % Data substracted from Amplifier for spectre plotting Jingyuan
        BullData
        HPCData
        PFCxData
    end
    
    properties (Access = private, Hidden = false)
        % Timestamps for plotting
%         Timestamps
%         
%         Time_real
%         
        % Amplifier data for plotting        
        Amplifiers
        
        %Kejian, substraction
        Math
        
        % Offsets for the various amplifiers, for plotting        
        Offsets
        
        % Data plot axes (Axes type)
        DataPlotAxes
        
        % Plot lines (array of Line type)
        DataPlotLines
        
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
    end
    
    methods

        
        function obj = BoardPlot(data_plot, hilbert_plot,sleep_stage, phase_space,gamma_distr,ratio_distr,...
                                snapshot, num_channels, samplingfreq)
        % Constructor.
        %
        % Example:
        %     boardPlot = BoardPlot(gca, 32);
            obj.passed=0;
            obj.detec_seuil=100;
            obj.fired=0;
            obj.detected=0;
            obj.DataPlotAxes = data_plot;
            
            
            obj.SleepStageAxes = sleep_stage; %Jingyuan 
            obj.HilbertPlotAxes = hilbert_plot;
            obj.hilbert_filter_order = 96;
            obj.bullchannel = 12;
            obj.coeff_bullfmin = 50;
            obj.coeff_bullfmax = 70;
            obj.HPCchannel = 16;
            obj.coeff_HPCfmin = 5;
            obj.coeff_HPCfmax = 10;
            obj.PFCxchannel = 16;
            obj.coeff_PFCxfmin = 2;
            obj.coeff_PFCxfmax = 4;
            obj.coeff_Spectremax = 100;
            obj.samplingfreq=samplingfreq;
            obj.bullFilt = fir1(obj.hilbert_filter_order,[obj.coeff_bullfmin obj.coeff_bullfmax]/(samplingfreq/(60*2))); %Changed to fir1 type filter
            obj.HPCFilt = fir1(obj.hilbert_filter_order*24,[obj.coeff_HPCfmin obj.coeff_HPCfmax]/(samplingfreq/(60*2))); %Changed to fir1 type filter
            obj.PFCxFilt = fir1(obj.hilbert_filter_order*24,[obj.coeff_PFCxfmin obj.coeff_PFCxfmax]/(samplingfreq/(60*2))); %Changed to fir1 type filter
            obj.result = [];
            
            %Setting up the spectrum analysis variables
            obj.BullData=zeros(1, ceil(obj.samplingfreq/60*3));
            obj.HPCData=zeros(1, ceil(obj.samplingfreq/60*3));
            obj.PFCxData=zeros(1, ceil(obj.samplingfreq/60*3));
            
            obj.PhaseSpaceAxes = phase_space; %Jingyuan
            obj.gamma_distributionAxes = gamma_distr;
            obj.ratio_distributionAxes = ratio_distr;
            
            
            obj.SnapshotAxes=snapshot;
            obj.NumChannels = num_channels;
            obj.SaveIndex = 1;
            obj.countermax=4/(1/samplingfreq)/60;  %default refractory time for fire is 4
            obj.countermax_detection=0.3/(1/samplingfreq)/60; %refractory time for detection is 0.3s
            
            
            
            
%             obj.timer1 = timer(...
%                             'ExecutionMode', 'fixedRate', ...       % Run timer repeatedly
%                             'Period', 1, ...
%                             'TimerFcn', {@set_wait_mode,obj}); % Specify callback
%             obj.timer2 = timer(...
%                             'ExecutionMode', 'fixedRate', ...       % Run timer repeatedly
%                             'Period', 10, ...
%                             'TimerFcn', {@set_wait_mode,obj}); % Specify callback                      

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
            
            obj.Math_buffer_to_filter=[0];
            obj.Math_buffer_filtered=[0];
            obj.Math_filtered=0;
            
            obj.Amplifiers = zeros(num_channels, obj.num_points); %pas de voies inutiles
            obj.Math = zeros(1, obj.num_points);
            obj.Math_filtered_display = zeros(1, obj.num_points);
            obj.SoundFile=zeros(1, obj.num_points)-0.5*ones(1,obj.num_points);
            obj.ThresholdFile=zeros(1,obj.num_points);
            obj.MicrophoneFile = zeros(1, obj.num_points); %Stocking data from the microphone
            obj.durationdb=60/samplingfreq;
            obj.durationbf=0.200; %s for showing the snapshot. the time before the detection to show
            obj.durationaft=0.800; %s
            obj.nbrptbf=ceil(obj.durationbf*obj.ptperdb/obj.durationdb);
            obj.nbrdbaft=ceil(obj.durationaft/obj.durationdb);
            obj.nbrptaft=ceil(obj.durationaft*obj.ptperdb/obj.durationdb);
            
            
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
            
            % Creat the plot area for Hilbert transform
            axes(obj.HilbertPlotAxes);
            obj.HilbertPlotLines = plot(0,0,0,0,0,0,0,0,0,0,0,0);
            set(obj.HilbertPlotLines(1),'LineWidth',1);
            set(obj.HilbertPlotLines(2),'Color','blue');
            set(obj.HilbertPlotLines(3),'Color',[0 0.5 0],'LineWidth',1);
            set(obj.HilbertPlotLines(4),'Color',[0 0.5 0]);
            set(obj.HilbertPlotLines(5),'Color','red','LineWidth',1);
            set(obj.HilbertPlotLines(6),'Color','red');
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
            obj.PhaseSpaceLines = scatter([],[],'.');
            set(gca,'XTick',[]);
            set(gca,'YTick',[]);
            set(obj.PhaseSpaceAxes, 'YLim', [-0.5 2.5]);
            set(obj.PhaseSpaceAxes, 'XLim', [-8 -5.5]);

            axes(obj.gamma_distributionAxes);
            obj.gamma_distributionLines = plot(0,0);
            set(gca,'YTick',[]);
            a = gca;
            l = get(a, 'XLabel');
            set(l, 'String', 'Gamma Power (log scale)');
            set(l, 'FontSize', 9);
            set(obj.gamma_distributionAxes, 'XLim', [-8 -4]);
                        
            axes(obj.ratio_distributionAxes);
            obj.ratio_distributionLines = plot(0,0);
            set(gca,'XTick',[]);
            a = gca;
            l = get(a, 'YLabel');
            set(l, 'String', 'Theta / Delta power (log scale)');
            set(l, 'FontSize', 9);
            set(obj.ratio_distributionAxes, 'YLim', [-2 3]);
            
        end
        
        function set_visible1(obj,visiblevalue)
            if visiblevalue==0
                obj.DataPlotLines(1).Visible='off';
            else
                obj.DataPlotLines(1).Visible='on';
            end
        end
        
        function set_visible2(obj,visiblevalue)
            if visiblevalue==0
                obj.DataPlotLines(2).Visible='off';
            else
                obj.DataPlotLines(2).Visible='on';
            end
        end
        
        function set_visible3(obj,visiblevalue)
            if visiblevalue==0
                obj.DataPlotLines(3).Visible='off';
            else
                obj.DataPlotLines(3).Visible='on';
            end    
        end
        
        function set_visible4(obj,visiblevalue)
            if visiblevalue==0
                obj.DataPlotLines(4).Visible='off';
            else
                obj.DataPlotLines(4).Visible='on';
            end    
        end        
        
        function set_visible5(obj,visiblevalue)
            if visiblevalue==0
                obj.DataPlotLines(5).Visible='off';
            else
                obj.DataPlotLines(5).Visible='on';
            end    
        end     
        
        function set_visible6(obj,visiblevalue)
            if visiblevalue==0
                obj.DataPlotLines(6).Visible='off';
            else
                obj.DataPlotLines(6).Visible='on';
            end    
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
    % myAmplifiers=myAmplifiers(:,obj.num_points-obj.nbrptaft-obj.nbrptaft);
    % mycell=num2cell(obj.Amplifiers(:,indices), 2);
            
            mycell=[num2cell(obj.Amplifiers(:,indices),2);num2cell(obj.Math(:,indices),2);num2cell(obj.SoundFile(:,indices),2);num2cell(obj.ThresholdFile(:,indices),2);num2cell(obj.Math_filtered_display(:,indices),2)];
            set(obj.SnapshotLines, {'YData'},mycell);        
        end
        
        function Bull_filterdesign (obj)
             obj.bullFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',...
                                obj.coeff_bullfmin,'CutoffFrequency2',obj.coeff_bullfmax,'SampleRate',samplingfreq);
                   
        end
        
        function HPC_filterdesign (obj)
                        obj.HPCFilt = fir1(obj.hilbert_filter_order,[obj.coeff_HPCfmin obj.coeff_HPCfmin]/(samplingfreq/2)); %Changed to fir1 type filter
        end
        
        function PFCx_filterdesign(obj)
             obj.PFCxFilt = designfilt('bandpassfir','FilterOrder',obj.hilbert_filter_order,'CutoffFrequency1',...
                                obj.coeff_PFCxfmin,'CutoffFrequency2',obj.coeff_PFCxfmax,'SampleRate',samplingfreq);
        end
                
        function hilbert_process_now(obj)
        % Jingyuan filtre the raw data and do the hilbert transfer  
        timestamps = 0:3/(length(obj.BullData)-1):3;
        
        set (obj.HilbertPlotLines(1),'XData',timestamps,'YData',obj.BullData);
        BullFiltered = filter (obj.bullFilt,1,obj.BullData); %filter the data between fmin and fmax 
        set (obj.HilbertPlotLines(2),'XData',timestamps,'YData',BullFiltered);
        BullEnv = abs(hilbert(BullFiltered)); % hilbert transfer
        %set (obj.HilbertPlotLines(2),'XData',timestamps,'YData',obj.BullData);
        obj.result(1) = mean (BullEnv);
        
        set (obj.HilbertPlotLines(3),'XData',timestamps,'YData',obj.HPCData+ 2e-3*0.5);
        HPCFiltered = filter (obj.HPCFilt,1,obj.HPCData); %filter the data between fmin and fmax
        set (obj.HilbertPlotLines(4),'XData',timestamps,'YData',HPCFiltered+ 2e-3*0.5);
        HPCEnv = abs( hilbert(HPCFiltered)); % hilbert transfer
        %set (obj.HilbertPlotLines(4),'XData',timestamps,'YData',obj.HPCData+ 2e-3*0.5); 
        obj.result(2) = mean(HPCEnv);
        

        set (obj.HilbertPlotLines(5),'XData',timestamps,'YData',obj.PFCxData+ 4e-3*0.5);
        PFCxFiltered = filter (obj.PFCxFilt,1,obj.PFCxData); %filter the data between fmin and fmax
        set (obj.HilbertPlotLines(6),'XData',timestamps,'YData',PFCxFiltered+ 4e-3*0.5);
        PFCxEnv = abs( hilbert(PFCxFiltered)); % hilbert transfer
        %set (obj.HilbertPlotLines(6),'XData',timestamps,'YData',obj.PFCxData+ 4e-3*0.5);
        % obj.PFCxData(obj.PFCxData < 100)= 100;
        obj.result=mean(PFCxEnv);
  
        obj.ratioData = PFCxEnv./HPCEnv;
        obj.result(4)= mean(obj.ratioData);
        end
         
         function refresh_sleepstage_now (obj,timestamps,sleepstage)
             set (obj.SleepStageLinesLeft,'XData',timestamps,'YData',sleepstage);
         end
         
         function detection_number_now (obj,timestamps,nb_detection)
             set(obj.SleepStageAxes(2),{'XLimMode'},{'auto'});
             set (obj.SleepStageLinesRight,'XData',timestamps,'YData',nb_detection);
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
            
            [obj.gamma_prob,obj.gamma_value] = ksdensity (gamma);
            [obj.ratio_prob,obj.ratio_value] = ksdensity (ratio); 
            
            
            set(obj.PhaseSpaceLines,'XData',gamma,'YData',ratio);
            set(obj.PhaseSpaceAxes, 'XLim', [(min(obj.gamma_value)-1) (max(obj.gamma_value)+1)]);
            set(obj.PhaseSpaceAxes, 'YLim', [(min(obj.ratio_value)-1) (max(obj.ratio_value)+1)]);

            
            set(obj.gamma_distributionLines,'XData',obj.gamma_value,'YData',obj.gamma_prob);
             set(obj.gamma_distributionAxes, 'XLim',  [(min(obj.gamma_value)-1) (max(obj.gamma_value)+1)]);
             

            set(obj.ratio_distributionLines,'XData',obj.ratio_prob,'YData',obj.ratio_value);
            set(obj.ratio_distributionAxes, 'YLim', [(min(obj.ratio_value)-1) (max(obj.ratio_value)+1)]);
            
            
        end
        
        function set_thethreshold_now(obj,gamma_threshold,ratio_threshold)

            delete (obj.vline_phase); %firstly clear the old reference line
            delete (obj.hline_phase);
            delete (obj.vline_gamma);
            delete (obj.hline_ratio);
            
             if (obj.threshold_status==1) 
                obj.vline_phase = line([gamma_threshold gamma_threshold],[(min(obj.ratio_value)-1) (max(obj.ratio_value)+1)],'LineStyle','--','Color','red','Parent',obj.PhaseSpaceAxes);
                obj.hline_phase = refline(obj.PhaseSpaceAxes,[0 ratio_threshold]);
                set (obj.hline_phase,'LineStyle','--');
                obj.vline_gamma = line([gamma_threshold gamma_threshold],[0 1],'LineStyle','--','Color','red','Parent',obj.gamma_distributionAxes);
                obj.hline_ratio = refline(obj.ratio_distributionAxes,[0 ratio_threshold]);
                set (obj.hline_ratio,'LineStyle','--');
            end
        end
        
        function obj = reset_buffer_to_filter(obj, n_points)
            %methods to reset the buffer used in the filters
            obj.Math_buffer_to_filter = zeros(1, n_points);
        end
        function obj = reset_buffer_filtered(obj, n_points)
            obj.Math_buffer_filtered = zeros(1, n_points);
        end
        function obj = set_coeff_filter(obj,coeff)
            obj.coeff_filter = coeff;
        end
        
        % Jingyuan
        function obj = set_coeff_spectrefreq(obj,spectrefmin,spectrefmax)
            obj.coeff_spectrefmin = spectrefmin;
            obj.coeff_spectrefmax = spectrefmax;
        end
        
        function obj = Spectre_data_block(obj,datablock)  % Jingyuan Sve the data from Datablock to a new array
            obj.BullData = [obj.BullData(2:end), mean(datablock.Chips{obj.ChipIndex}.Amplifiers(obj.bullchannel,:))];
            obj.HPCData = [obj.HPCData(2:end), mean(datablock.Chips{obj.ChipIndex}.Amplifiers(obj.HPCchannel,:))];
            obj.PFCxData = [obj.PFCxData(2:end), mean(datablock.Chips{obj.ChipIndex}.Amplifiers(obj.PFCxchannel,:))];
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
                newdata_microphone=mean(datablock.Board.ADCs(2,:)); %get the data from the ADC 
                newdata_math=newdata_original(1,:)-newdata_original(2,:);
                newdata_sound=-0.5*ones(1,obj.ptperdb);
                                
                if filter_activated==1
                    obj.Math_buffer_to_filter(1:end-1)=obj.Math_buffer_to_filter(2:end);
                    obj.Math_buffer_to_filter(end)=newdata_math;
                    a = obj.coeff_filter(1,:);
                    b = obj.coeff_filter(2,:);
                    
                    newdata_filt = dot(fliplr(b), obj.Math_buffer_to_filter);
                    newdata_filt = newdata_filt - dot(fliplr(a(2:end)), obj.Math_buffer_filtered);
                    obj.Math_filtered = newdata_filt / a(1);
                    
                    obj.Math_buffer_filtered(1:end-1)=obj.Math_buffer_filtered(2:end);
                    obj.Math_buffer_filtered(end)= obj.Math_filtered;
                end
                    
                               
                if obj.detec_status==1 % means the user wants to detect the pic
                    obj.counter=obj.counter+1;  %in initialization it was 0
                    obj.counter_detection=obj.counter_detection+1;
                    % the refractory time of the detection
                    if (obj.counter_detection>obj.countermax_detection) && (obj.wait_status==1)&& (obj.detected==0)
                        if filter_activated==1
                            if obj.Math_filtered>=obj.detec_seuil*1e-3
                                obj.detected=1; 
                                obj.counter_detection=0;
                                if strcmp(arduino.Status,'open')
                                    fwrite(arduino,5);
                                end
                            end                            
                        else
                            if newdata_math>=obj.detec_seuil*1e-3
                                obj.detected=1; 
                                obj.counter_detection=0;
                                if strcmp(arduino.Status,'open')
                                    fwrite(arduino,5);
                                end
                            end
                        end
                    end
                    
                    
                    if obj.counter>obj.countermax %for firing. take into consideration of the refractory time for firing, here means it now ok to proceed (passed the refractory time)                    
                        if filter_activated==1
                            if obj.Math_filtered>=obj.detec_seuil*1e-3
                                if (obj.wait_status==1)&&(obj.fired==0)
                                    if obj.sound_mode==0  %detection only
                                        if strcmp(arduino.Status,'open')
                                            fwrite(arduino,0);
                                        end
                                        newdata_sound=3*ones(1,obj.ptperdb);
                                    elseif obj.sound_mode==1 % 1 sound
                                        if strcmp(arduino.Status,'open')
                                            fwrite(arduino,1*10+obj.sound_tone); %the mode and the sound are sent to the arduino as an integer AB => A is the mode and B is the sound type
                                        end
                                        newdata_sound=3*ones(1,obj.ptperdb);
                                    elseif obj.sound_mode==2 %10 sound
                                        if strcmp(arduino.Status,'open')
                                            fwrite(arduino,2*10+obj.sound_tone);%the mode and the sound are sent to the arduino as an integer AB => A is the mode and B is the sound type
                                        end
                                        newdata_sound=3*ones(1,obj.ptperdb);
                                    elseif obj.sound_mode==3 %1 sound with delay
                                        if strcmp(arduino.Status,'open')
                                            fwrite(arduino,3*10+obj.sound_tone);%the mode and the sound are sent to the arduino as an integer AB => A is the mode and B is the sound type
                                        end
                                        newdata_sound=3*ones(1,obj.ptperdb);
                                    elseif obj.sound_mode==4 %10 sound with delay
                                        if strcmp(arduino.Status,'open')
                                            fwrite(arduino,4*10+obj.sound_tone);%the mode and the sound are sent to the arduino as an integer AB => A is the mode and B is the sound type
                                        end
                                        newdata_sound=3*ones(1,obj.ptperdb);
                                    end
                                    obj.fired=1;
                                    obj.counter=0;

                                    obj.detected=1;
                                    obj.counter_detection=0;

                                end
                            end
                        else
                            if newdata_math>=obj.detec_seuil*1e-3
                                if (obj.wait_status==1)&&(obj.fired==0)
                                    if obj.sound_mode==0  %detection only
                                        if strcmp(arduino.Status,'open')
                                            fwrite(arduino,0);
                                        end
                                        newdata_sound=3*ones(1,obj.ptperdb);
                                    elseif obj.sound_mode==1 % 1 sound
                                        if strcmp(arduino.Status,'open')
                                            fwrite(arduino,1*10+obj.sound_tone);
                                        end
                                        newdata_sound=3*ones(1,obj.ptperdb);
                                    elseif obj.sound_mode==2 %10 sound
                                        if strcmp(arduino.Status,'open')
                                            fwrite(arduino,2);
                                        end
                                        newdata_sound=3*ones(1,obj.ptperdb);
                                    elseif obj.sound_mode==3 %1 sound with delay
                                        if strcmp(arduino.Status,'open')
                                            fwrite(arduino,3);
                                        end
                                        newdata_sound=3*ones(1,obj.ptperdb);
                                    elseif obj.sound_mode==4 %10 sound with delay
                                        if strcmp(arduino.Status,'open')
                                            fwrite(arduino,4);
                                        end
                                        newdata_sound=3*ones(1,obj.ptperdb);
                                    end
                                    obj.fired=1;
                                    obj.counter=0;

                                    obj.detected=1;
                                    obj.counter_detection=0;

                                end
                            end
                        end
                    end
                end
                
                newdata = newdata_original + obj.Offsets(obj.StoreChannels,1);  %%%%%
                        
 
            % inject the data from newdata, newdata_math, newdata_sound to
            % Amplifiers, Math, and SoundFile. these properties are only for
            % display purpose.
            % ATTENTION: we don't inject all the data to these properties,
            % only take ptperdb(here 1 point) to inject. Otherwise the
            % display will roll too rapidely in the screen.
           
            
            % Scale to mV, rather than V.
            obj.Amplifiers(obj.StoreChannels,obj.SaveIndex:(obj.SaveIndex+obj.ptperdb-1)) = ...
                newdata*1000; %Injection from newdata to obj.amplifiers
            obj.Math(obj.SaveIndex:(obj.SaveIndex+obj.ptperdb-1))=newdata_math*1000;
            obj.SoundFile(obj.SaveIndex:(obj.SaveIndex+obj.ptperdb-1))=newdata_sound;
            obj.MicrophoneFile(obj.SaveIndex:(obj.SaveIndex+obj.ptperdb-1))=newdata_microphone;
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
        
        function b=sendoutspectrechannel(obj) %Jingyuan
            b = [obj.bullchannel,obj.HPCchannel,obj.PFCxchannel];
        end
        
        function c=sendoutspectrefmin(obj) %Jingyuan
            c = [obj.coeff_bullfmin,obj.coeff_HPCfmin, obj.coeff_PFCxfmin]; 
        end
    
        function d=sendoutspectrefmax(obj) %Jingyuan
            d = [obj.coeff_bullfmax, obj.coeff_HPCfmax,obj.coeff_PFCxfmax]; 
        end

    end
    
end

