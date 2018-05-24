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

        
        function obj = BoardPlot(data_plot, snapshot, num_channels, samplingfreq)
        % Constructor.
        %
        % Example:
        %     boardPlot = BoardPlot(gca, 32);
            obj.passed=0;
            obj.detec_seuil=100;
            obj.fired=0;
            obj.detected=0;
            obj.DataPlotAxes = data_plot;
            obj.SnapshotAxes=snapshot;
            obj.NumChannels = num_channels;
            obj.SaveIndex = 1;
            obj.countermax=4/(1/samplingfreq)/60;  %default refractory time for fire is 4
            obj.countermax_detection=0.3/(1/samplingfreq)/60; %refractory time for detection is 0.3s
            obj.sound_tone=0;
            
            
            
            
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
%             myAmplifiers=myAmplifiers(:,obj.num_points-obj.nbrptaft-obj.nbrptaft);
%             mycell=num2cell(obj.Amplifiers(:,indices), 2);
            
            mycell=[num2cell(obj.Amplifiers(:,indices),2);num2cell(obj.Math(:,indices),2);num2cell(obj.SoundFile(:,indices),2);num2cell(obj.ThresholdFile(:,indices),2);num2cell(obj.Math_filtered_display(:,indices),2)];
            set(obj.SnapshotLines, {'YData'},mycell);        
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
                                            fwrite(arduino,1);
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
            a=obj.Channels;
        end

    end
    
end

