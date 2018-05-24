classdef SaveConfigUI < handle
    %SAVECONFIGUI Class containing UI data related to saving
    %
    % There's a lot of common functionality in the read_continuously,
    % episodic_recording, and two_boards example.
    %
    % This class implement some of the common functionality.  It handles
    % the configuration options related to saving.  It deals with the radio
    % buttons that control the save format, and the button that sets the
    % base name for save files.
    %
    % See also read_continuously, episodic_recording, and two_boards.
    
    properties
        SaveFileDialog
        BaseName
    end
    
    properties (Dependent=true, GetAccess=private)
        Enable
    end
    
    properties (Dependent=true, SetAccess=private)
        Format
    end

    properties (Access=private, Hidden=true)
        Intan
        FilePerSignalType
        FilePerChannel
    end
    
    methods
        function obj = SaveConfigUI(intan, file_per_signal_type, file_per_channel, save_file_dialog)
            obj.Intan = intan;
            obj.FilePerSignalType = file_per_signal_type;
            obj.FilePerChannel = file_per_channel;
            obj.SaveFileDialog = save_file_dialog;
            obj.BaseName = [];
        end
        
        function obj = set.Enable(obj, value)
            set(obj.Intan, 'Enable', value);
            set(obj.FilePerSignalType, 'Enable', value);
            set(obj.FilePerChannel, 'Enable', value);
            set(obj.SaveFileDialog, 'Enable', value);
        end
        
        % Returns the current save file format
        % Converts the combination of radio buttons into an rhd2000.savefile.Format
        % enumeration value.
        function value = get.Format(obj)
            if get(obj.Intan, 'Value') == 1
                value = rhd2000.savefile.Format.intan;
            else
                if get(obj.FilePerChannel, 'Value') == 1
                    value = rhd2000.savefile.Format.file_per_channel;
                else
                    value = rhd2000.savefile.Format.file_per_signal_type;
                end
            end
        end
        
        function obj = save_dialog(obj)
            % Pop up a dialog and get the base path
            if obj.Format == rhd2000.savefile.Format.intan
                [filename, pathname] = uiputfile(...
                                      {'*.rhd', 'Intan RHD File format (*.rhd)'; ...
                                      '*.*',   'All Files (*.*)'}, ...
                                      'Pick a file location to save data', ...
                                      obj.BaseName);
            else
                [filename, pathname] = uiputfile(...
                                      { '*.*',   'All Files (*.*)'}, ...
                                      'Pick a directory to save data', ...
                                      obj.BaseName);
            end

            if isequal(filename,0) || isequal(pathname,0)
                % User cancelled
            else
                % Set basename
                obj.BaseName = fullfile(pathname, filename);
            end
        end
        
    end
    
end

