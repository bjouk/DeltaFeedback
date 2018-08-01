
classdef BoardUI < handle
    %BOARDUI Class containing UI data related to a single board
    %
    % There's a lot of common functionality in the read_continuously,
    % episodic_recording, and two_boards examples.
    %
    % This class implement some of the common functionality.  It handles
    % one board's worth of data.  It stores data, plots it on axes, lets
    % you choose which chip to plot and which group of channels, and
    % displays the FIFO Lag and Percentage Full values.
    %
    % See also read_continuously, episodic_recording, and two_boards.
    
    properties
        Board         % Handle of an rhd2000.Board
        Plot
        paramsFile
    end
    
    properties (Access = private)
        ChipsPopup    % Popup that chooses Port A, MISO 1, etc.
        ChipIndices   % Indices corresponding to ChipsPopup
        
        ChannelsToDisplay % Popup that chooses channels 1-32, 33-64, etc.
        
        FifoLag             % Handle to the UI element
        FifoPercentageFull  % Handle to the UI element
               
        bullchannel % Jingyuan the channel selected for bull plot
        bullfmin
        bullfmax
        
        Thetachannel
        Thetafmin
        Thetafmax
        
        Deltachannel
        Deltafmin
        Deltafmax
        
        TheChannels  %Kejian for just one channel
        DataBlock_temp %Kejian
        Plot2 %Kejian
        ChipIndex %Kejian
        FilterDef %Kejian
        
        Webcam
        MaskWebcam
        previewWindow
    end
    
    methods
        function obj = BoardUI(board, data_plot,sleep_stage,phase_space,gamma_distr,ratio_distr,...
                              snapshot, chips_popup, channels_popup, fifolag, fifopercentagefull, num_channels,detections,meanDeltaPlot)
        % Constructor
        %
        % board              handle to an rhd2000.Board object
        % data_plot          UI object: data plot axes
        % hilbert_plot       UI object: raw data and data after hilbert
        % tranfrom
        % sleep_stage        UI object: sleep stage Jingyuan
        % spectre_channel    UI object: spectre channel selected Jingyuan
        % chips_popup        UI object: popup that chooses Port A, MISO 1, etc.
        % channels_popup     UI object: popup that chooses channels 1-32, 33-64, etc.
        % fifolag            UI object: FIFO Lag text
        % fifopercentagefull UI object: FIFO Percentage Full text
        % num_channels       number of channels to display at the same time
            if nargin == 6
                num_channels = 32;
            end
            
            obj.Board = board;        
            obj.ChipsPopup = chips_popup;
            obj.ChannelsToDisplay = channels_popup;
            obj.FifoLag = fifolag;
            obj.FifoPercentageFull = fifopercentagefull;
            obj.Plot = BoardPlot(data_plot,sleep_stage,phase_space,gamma_distr,ratio_distr,...
                                 snapshot,num_channels,frequency(obj.Board.SamplingRate),meanDeltaPlot);
            obj.TheChannels=[1 2];
            
            % Set the Chips popup in the Display area to a list of allowed chips
            obj.get_allowed_chips();
            obj.set_chip();
            
        end
        
        
        function hilbert_process (obj)
            obj.Plot.hilbert_process_now();
        end
        
        function Bull_filterdesign (obj)
             obj.Plot.Bull_filterdesign ();        
        end
        
        function Theta_filterdesign (obj)
            obj.Plot.Theta_filterdesign();
        end
        
        function Delta_filterdesign (obj)
            obj.Plot.Delta_filterdesign();
        end
        
        function refresh_sleepstage(obj,timestamps,sleepstage)
            obj.Plot.refresh_sleepstage_now (timestamps,sleepstage);
        end
        
        function detection_number(obj,timestamps,nb_detection,detections)
            obj.Plot.detection_number_now (timestamps,nb_detection,detections);
        end
        
        function refresh_phasespace (obj,timestamps,gamma,ratio)
            obj.Plot.refresh_phasespace_now(timestamps,gamma,ratio);
        end
        
        
        function refresh_display(obj,filter_activated)
        % Update the plots and FIFO text.
        %
        % This takes time, so you shouldn't call it every iteration if
        % you're running at a high sampling rate.  
            obj.Plot.refresh_display_now(filter_activated);
        end
        
        function refresh_fifo(obj)
            set(obj.FifoLag, 'String', sprintf('%g ms', obj.Board.FIFOLag));
            set(obj.FifoPercentageFull, 'String', ...
            sprintf('(%2.2f%% full)', obj.Board.FIFOPercentageFull));
        end
        
        
        %--------------------------------------------------------------------
        % list_of_chips is used to populate the Chips popup
        % This function returns the valid options for chips, based on which data
        % sources have chips attached to them.
        %
        % For example, if Ports A & B, MISO 1 both have chips attached, this will
        % return list_of_chips = { 'Port A, MISO 1'; 'Port B, MISO 1'} and
        % indices_of_chips = (1 3).
        function obj = get_allowed_chips(obj)
            datasources = { 'Port A, MISO 1'; 'Port A, MISO 2'; ...
                            'Port B, MISO 1'; 'Port B, MISO 2'; ...
                            'Port C, MISO 1'; 'Port C, MISO 2'; ...
                            'Port D, MISO 1'; 'Port D, MISO 2'};
            indices = 1:8;
            set(obj.ChipsPopup, 'String', datasources(obj.Board.Chips ~= rhd2000.Chip.none));
            obj.ChipIndices = indices(obj.Board.Chips ~= rhd2000.Chip.none);
        end
        
        %--------------------------------------------------------------------

        % Call this when the Chip popup changes value; it uses obj.ChipsPopup.Value
        % to set several related UI and data elements.
        function obj = set_chip(obj)
            % Set the chip_index (e.g., 3 for 'Port B, MISO 1')
        obj.Plot.ChipIndex = obj.ChipIndices(get(obj.ChipsPopup, 'Value'));
             %obj.Plot.ChipIndex =1;
            set(obj.ChannelsToDisplay, 'String', ...
                BoardUI.get_channel_text(obj.Plot.NumChannels, ...
                                         obj.Board.Chips(obj.Plot.ChipIndex)));
            set(obj.ChannelsToDisplay, 'Value', 1);

            obj.Plot.clear_data();
        end

        % Called to process a data block; stores the new data in the plot
        function obj = process_data_block(obj, datablock, arduino,filter_activated)
            obj.Plot.process_data_block(datablock,arduino,filter_activated);
        end
        
        function obj = Spectre_data_block(obj,datablock)%Processes the datablock for spectrum analysis 
            obj.Plot.Spectre_data_block(datablock);
        end
        
        function obj=set_channels_chips(obj)
            obj = set_channels(obj);
            obj.ChipIndex = obj.ChipIndices(get(obj.ChipsPopup, 'Value'));
        end
        
        
        function datablock2 = send_out_datablock2(obj)
            datablock2 = obj.DataBlock_temp;
        end
        
        function obj=set_filter(filterdef)
            obj.FilterDef = filterdef;
        end
        
        % Set the channels indices whenever chip or channels to display
        % change.
        function obj = set_channels(obj)
            chip = obj.Board.Chips(obj.Plot.ChipIndex);
            
            [obj.Plot.StoreChannels, obj.Plot.Channels] = ...
                BoardUI.get_channels(obj.Plot.NumChannels, ...
                                     get(obj.ChannelsToDisplay, 'Value'), ...
                                     chip);
             
             obj.Plot.Channels=obj.TheChannels; %Kejian
        end
  
        function obj=set_thechannels(obj,TheChannels) %Kejian
            %% Set PFC Channels
            obj.TheChannels=TheChannels;
        end

        function obj=set_thethreshold (obj,gamma_threshold,ratio_threshold)
            %% Set the sleep scoring thresholds
            obj.Plot.set_thethreshold_now(gamma_threshold,ratio_threshold);
            if ~isempty(obj.paramsFile)
                paramsArray=readtable(obj.paramsFile,'Delimiter',';');
                paramsArray{6,2}=gamma_threshold;
                paramsArray{7,2}=ratio_threshold;
                writetable(paramsArray,obj.paramsFile,'Delimiter',';');
            end
        end
        function obj=setChannelsSpectre(obj, file) %
            %% Get the mouse channels from a .csv file and use the data: Important to keep the same order for the parameters
            paramsArray=readtable(file,'Delimiter',';','Format', '%s%f');
            obj.paramsFile=file;
            obj.set_thechannels([paramsArray{5,2}+1 paramsArray{4,2}+1]);
            obj.set_channels();
            obj.Plot.bullchannel=paramsArray{1,2}+1;
            obj.Plot.Deltachannel=paramsArray{2,2}+1;
            obj.Plot.Thetachannel=paramsArray{3,2}+1;
            obj.set_thethreshold(paramsArray{6,2},paramsArray{7,2});
            
        end
        function obj=setDigitalOutput(obj, value)
            %% Set intan digital output to indicate sleepstate
            obj.Board.DigitalOutputs(9:end)=0;
            obj.Board.DigitalOutputs(8+value)=1;
        end
        
        
        function obj=webcaminit(obj,previewWindow)
            %% Init the webcam interface and get first snapshot
            obj.Webcam=webcam;
            obj.Webcam.Resolution='320x240'; %small resolution
            previewWeb = snapshot(obj.Webcam);
            previewWeb=previewWeb(40:125,41:241); %Get snaphshot with mask
            set(previewWindow,'Units','pixels');
            resizePos = get(previewWindow,'Position');
            previewWeb= imresize(previewWeb, [resizePos(3) resizePos(3)]);%% Resize to fit the axes
            imshow(previewWeb,'Parent', previewWindow);
        end
        
        function obj=refreshWebcam(obj,previewWindow)
            %% Refresh webcam snapshot
            previewWeb = snapshot(obj.Webcam);
            previewWeb=previewWeb(40:125,41:241,:);
            set(previewWindow,'Units','pixels');
            resizePos = get(previewWindow,'Position');
            previewWeb= imresize(previewWeb, [resizePos(3) resizePos(3)]); %% Resize to fit the axes
            imshow(previewWeb,'Parent', previewWindow);
        end   
    end
    
    
    methods (Static=true)
        function [store_channels, channels] = get_channels(num_channels, display_index, chip)
        % Examples: 
        %    Plot.NumChannels   Chip      store_channels    channels
        %    32                 RHD2216   1:16              1:16
        %    32                 RHD2132   1:32              1:32
        %    32                 RHD2164   1:32              1:32,33:64
        %    8                  RHD2216   1:8               1:8,9:16
        %    8                  RHD2132   1:8               1:8,9:16,17:24,25:32
        %    8                  RHD2164   1:8               1:8,9:16,17:24,25:32,...,57:64
            max_store_channel = min([num_channels chip.num_channels]);
            store_channels = 1:max_store_channel;
            
            maxchannel = min([chip.num_channels, num_channels * display_index]);
            minchannel = max([maxchannel - num_channels + 1, 1]);
            channels = minchannel:maxchannel;
        end
        
        function strings = get_channel_text(num_channels, chip)
        % Examples:
        %    Plot.NumChannels   Chip      channels
        %    32                 RHD2216   { '1-16' }
        %    32                 RHD2132   { '1-32' }
        %    32                 RHD2164   { '1-32', '33-64' }
        %    8                  RHD2216   { '1-8', '9-16' }
        %    8                  RHD2132   { '1-8', '9-16', '17-24', '25-32' }
        %    8                  RHD2164   { '1-8', '9-16', '17-24', '25-32', ... , '57-64' }
            last = 0;
            index = 0;
            strings = cell(chip.num_channels, 1);
            while last < chip.num_channels
                index = index + 1;
                first = last + 1;
                last = min([last + num_channels, chip.num_channels]);
                if first < last
                    strings{index} = sprintf('%d-%d', first, last);
                else
                    strings{index} = sprintf('%d', first);
                end
            end
            strings = strings(1:index);
        end
    end
    
end

