
classdef dlm_summary
    % FNIRS1.DLM_SUMMARY stores coefficient summaries for parameters
    % estimated with fnirs1.dlm
    %
    % Example usage:
    %   summ = fnirs1.dlm_summary;
    %   fieldnames(summ);
    %   disp(summ)
    %
    % See also dlm
    % 
    properties
        Nickname;      % Optional, setable, lable for objects
    end
    properties (SetAccess = private)
        Descriptions;  % Description of each parameter
        Estimates;     % Estimate of each parameter
        GroupAnalysis; % Logical group analysis marker
        Intervals;     % Posterior credible intervals for each parameter
        Level;         % Credible interval probability width
        LogFiles;      % List (cellstr) of analysis's MCMC log files
        LogFileDir;    % Analysis directory
        Samples;       % MCMC samples from main analysis
        StdErrors;     % Standard error of each Estimate
    end
    properties (Access = private)
        Decimals;            % Max decimal places to display
        DescripPrintWidth;   % Max number of Descriptions characters to print
        EstimatePrintWidth;  % Max numbers to display per item
        FormatDescrip;       % Format specifier for displayed Descriptions
        FormatEstimate;      % Format specifier for displayed Estimates
        FormatEstimateStr;   % Special formatting for displayed Estimates as strings
        FormatInterval;      % Format specifier for displayed Intervals
        FormatLine;          % Format specifier for whole line to display
        IntervalPrintWidth;  % Max width of interval characters to display
        PrintWidth;          % Max number of characters to print for display
        StarsCuttoffs;       % Cuttoff bounds for displaying asterisks
    end
    methods
        function obj = dlm_summary()
            % Default constructor for FNIRS1.DLM_SUMMARY objects
            obj.Nickname = '';
            obj.Descriptions = {};
            obj.Estimates = [];
            obj.Intervals = [];
            obj.Level = 0.95;
            obj.LogFiles = {};
            obj.LogFileDir = {};
            obj.Samples = '';
            obj.StdErrors = [];
            
            obj.Decimals = 3;
            obj.DescripPrintWidth = 45;
            obj.EstimatePrintWidth = 10;
            obj.IntervalPrintWidth = 15;
            obj.FormatDescrip = sprintf('%%-%is', obj.DescripPrintWidth);
            obj.FormatEstimate = sprintf('%%.%if', obj.Decimals);
            obj.FormatEstimateStr = sprintf('%%%is', obj.EstimatePrintWidth);
            obj.FormatInterval = sprintf('(%%.%if, %%.%if)', ...
                obj.Decimals - 1, obj.Decimals - 1);
            obj.FormatLine = sprintf('%%-%is  %%+%is  %%-%is %%%is %%s', ...
                obj.DescripPrintWidth - 2, obj.EstimatePrintWidth - 1, ...
                obj.EstimatePrintWidth - 2, obj.IntervalPrintWidth - 1);  
                % -1's for the spaces
            obj.PrintWidth = 80;  % not counting asterisks
            obj.StarsCuttoffs = [0.95, 0.99, 0.999];
        end
        function obj = add_contrast(obj, C)
            con = fnirs1.contrast(C);
            moreFilesNeeded = false;
            if (size(con.Vectors, 1) < size(obj.Samples, 2))
                con.Vectors = vertcat(con.Vectors, ...
                    zeros(size(obj.Samples, 2) - size(con.Vectors, 1), ...
                    size(con.Vectors, 2)));
            elseif (size(con.Vectors, 1) > size(obj.Samples, 2))
                if (obj(1).GroupAnalysis)
                    moreFilesNeeded = true;
                else
                    error('Contrast vectors longer than model parameters');
                end
            end
            if (~moreFilesNeeded)
                if (obj(1).GroupAnalysis)
                    con.Names = erase(obj(1).Descriptions(...
                        regexpl(obj(1).Descriptions, '^Population Estimate:')), ...
                        'Population Estimate: ');
                else
                    con.Names = abbreviate(obj(1).Descriptions);
                end
                for i = 1:numel(obj)
                    BcHat = obj(i).Samples * con.Vectors;
                    p = (1 - obj(i).Level) / 2 * [1 -1] + [0 1];
                    Q = quantile(BcHat, p);
                    if (size(BcHat, 2) > 1)
                        Q = Q';
                    end
                    obj(i).Descriptions = [cellstr("Contrast: " + ...
                        string(con)); obj(i).Descriptions];
                    obj(i).Estimates = [mean(BcHat)'; obj(i).Estimates];
                    obj(i).Intervals = [Q; obj(i).Intervals];
                    obj(i).StdErrors = [std(BcHat)'; ...
                        obj(i).StdErrors];
                end
            else
                modelParamIndex = ~regexpl(obj(1).Descriptions, ...
                    '^Contrast: ');
                groupLevel = regexpl(obj(1).Descriptions(...
                    modelParamIndex), '^Population Estimate:');
            end
        end
        function disp(obj)
            for j = 1:length(obj)
                P = length(obj(j).Estimates);
                if (~isempty(obj(j).Estimates))
                    header = sprintf(obj(j).FormatLine, 'Parameter', 'Estimate', ...
                        'Std.Err.', sprintf('%.1f%% Cred.Int.', obj(j).Level * 100), ' ');
                    fprintf('\tDLM Summary: %s\n', char(obj(j).Nickname));
                    fprintf('%s\n', header);
                    fprintf('%s\n', repmat('-', 1, obj(j).PrintWidth));
                    for i = 1:P
                        descrip = sprintf(obj(j).FormatDescrip, obj(j).Descriptions{i});
                        descrip = descrip(1:min(length(descrip), obj(j).DescripPrintWidth - 2));
                        est = sprintf(obj(j).FormatEstimate, obj(j).Estimates(i));
                        est = est(1:min(length(est), obj(j).EstimatePrintWidth - 1));
                        est = sprintf(obj(j).FormatEstimateStr, est);
                        se = sprintf(obj(j).FormatEstimate, obj(j).StdErrors(i));
                        se = se(1:min(length(se), obj(j).EstimatePrintWidth - 2));
                        intvl = sprintf(obj(j).FormatInterval, obj(j).Intervals(i, :));
                        nstars = sum(obj(j).Level >= obj(j).StarsCuttoffs) * ...
                            (obj(j).Intervals(i, 1) > 0 || obj(j).Intervals(i, 2) < 0);
                        stars = sprintf('%s', repmat('*', 1, nstars));
                        line = sprintf(obj(j).FormatLine, descrip, est, se, intvl, stars);
                        fprintf('%s\n', line);
                    end
                    fprintf('%s\n\n', repmat('-', 1, obj(j).PrintWidth));
                else
                    obj(j).displayEmptyObject();
                end  % if (~isempty(obj(j).Estimate))
            end  % for ob = obj
        end
        function obj = head(obj, varargin)
            % Extract only the first N items from an fnris1.dlm_summary
            % object. By default, N = 6
            %
            N = int16(6);
            if (nargin > 1 && isnumeric(varargin{1}))
                N = int16(varargin{1});
                if (N <= 0)
                    error('head: N must be a strictly positive integer');
                end
            end
            for i = 1:numel(obj)
                obj(i).Descriptions = obj(i).Descriptions(1:N);
                obj(i).Estimates = obj(i).Estimates(1:N);
                obj(i).Intervals = obj(i).Intervals(1:N, :);
                obj(i).StdErrors = obj(i).StdErrors(1:N);
            end
        end
        function B = isempty(obj)
            % Returns logical true of object does not contain any data
            B = isempty(horzcat(obj(:).Estimates));
        end
        function obj = read_from_file(obj, file)
            % Read data from a Parameter_Estimates.log file and extract
            % parameter estimates and inferential summaries
            
            obj.LogFileDir = basename(file);
            if (isempty(obj.LogFileDir) || ...
                    strcmp(obj.LogFileDir, './') || ...
                    strcmp(obj.LogFileDir, file))
                obj.LogFileDir = pwd;
            end
            lfd = dir(fullfile(obj.LogFileDir, '*_beta.log'));
            obj.LogFiles = fullfile(obj.LogFileDir, {lfd(:).name}');
            
            % Read file into cell array and clean up lines
            lines = fnirs1.read_whole_file(file);
            lines = lines(~strcmp(lines, ''));
            if (length(lines) > 2)
                % last two lines of Parameter_Estimates.log files are notes
                % explaining quantile/interval methods
                lines = lines(1:(end - 2));
            end
            
            % Clean lines, increment stimulus/covariate numbers (originally
            % start from zero)
            for i = 1:length(lines)
                lines{i} = erase(lines{i}, ': Parameter Summary for regression of');
                lines{i} = strrep(lines{i}, 'Temporal Derivative', 'TempDeriv');
                lines{i} = strrep(lines{i}, 'Pop ', 'Population ');
                lines{i} = strrep(lines{i}, ...
                    'Population Level Parameters:', 'Population Effect');
                
                condNo = sscanf(lines{i}, 'Cond_%i');
                if ~isempty(condNo)
                    lines{i} = strrep(lines{i}, sprintf('Cond_%i', condNo), ...
                        sprintf('Cond_%i', condNo));
                end
                
                condNo = sscanf(lines{i}, 'Cond = %i');
                if ~isempty(condNo)
                    lines{i} = strrep(lines{i}, sprintf('Cond = %i', condNo), ...
                        sprintf('Cond_%i', condNo + 1));
                end
                
                covarNo = sscanf(lines{i}, '%*s Covariate %i');
                if ~isempty(covarNo)
                    lines{i} = strrep(lines{i}, sprintf('Covariate %i', covarNo), ...
                        sprintf('Covar %i', covarNo + 1));
                end
            end
            
            % Identify special types of lines/blocks related to parameter
            % interpretation - group vs subject-specific analyses
            mean_lines = contains(lines, 'mean = ');
            P = sum(mean_lines);
            if (P == 0)
                error('%s does not appear to be a valid parameter-log file', file);
            end
            
            % File is structured:
            %   Title
            %      SubTitle
            %        mean = X\tsd = Y
            %        V% Cred.Int. = (L, U)*
            interval_lines = [false; mean_lines(1:(end - 1))];
            subtitle_lines = [mean_lines(2:end); false];
            
            % Set object parameter values
            obj.Descriptions = cell(P, 1);
            obj.Estimates = nan(P, 1);
            obj.StdErrors = nan(P, 1);
            obj.Intervals = nan(P, 2);
            
            count = 1;
            title = '';
            blockTitle = '';
            groupAnalysisBlock = true(length(lines), 1);
            beginningOfSubjectBlockLine = 'Parameter Summary for Subjects';
            beginningOfSubjectBlockIndex = find(contains(lines, ...
                beginningOfSubjectBlockLine));
            if (~isempty(beginningOfSubjectBlockIndex))
                groupAnalysisBlock(beginningOfSubjectBlockIndex(1):end) = false;
            end
            obj.GroupAnalysis = any(groupAnalysisBlock);
            
            subtitle_lines(groupAnalysisBlock) = false;
            title_lines = ~(mean_lines | interval_lines | subtitle_lines);
            
            % Loop over lines and extract relevant information.
            % (!) This block may need to be edited if Parameter_Estimates.log
            % formatting ever chanes
            for i = 1:length(lines)
                % Identify line types
                if (title_lines(i))
                    % Identify title/subtitle information - formatting slightly
                    % different for group analysis results vs subject-specific
                    % analyses
                    if (strcmpi(lines{i}, beginningOfSubjectBlockLine))
                        title_lines(i) = false;
                    end
                    if (i == 1)
                        blockTitle = lines{i};
                    else
                        if (length(lines) > i)
                            if (~groupAnalysisBlock(i) && ...
                                    interval_lines(i - 1) && ...
                                    title_lines(i + 1))
                                blockTitle = lines{i};
                            elseif (groupAnalysisBlock(i) && ...
                                    interval_lines(i - 1) || ...
                                    strcmpi(lines{i - 1}, ...
                                    beginningOfSubjectBlockLine))
                                blockTitle = lines{i};
                            else
                                title = lines{i};
                            end
                        end
                    end
                    if ~isempty(blockTitle)
                        blockTitle = strrep(blockTitle, ':', '');
                    end
                elseif (subtitle_lines(i))
                    % Format parameter descriptions given block-titles,
                    % titles, and subtitles
                    obj.Descriptions{count} = strrep(...
                        sprintf('%s %s: %s', blockTitle, title, lines{i}), ...
                        ' :', ':');
                    if (contains(obj.Descriptions{count}, 'Population, '))
                        obj.Descriptions{count} = sprintf('Population %s', ...
                            erase(obj.Descriptions{count}, 'Population, '));
                    end
                elseif (mean_lines(i))
                    theta = format_mean_sd_line(lines{i});
                    obj.Estimates(count) = theta.Estimate;
                    obj.StdErrors(count) = theta.SE;
                    if (~isempty(theta.Name))
                        obj.Descriptions{count} = strrep(...
                            sprintf('%s %s: %s', blockTitle, title, theta.Name), ...
                            ' :', ':');
                        if (contains(obj.Descriptions{count}, 'Population, '))
                            obj.Descriptions{count} = sprintf('Population %s', ...
                                erase(obj.Descriptions{count}, 'Population, '));
                        end
                    end
                elseif (interval_lines(i))
                    ntrvl = format_interval_line(lines{i});
                    obj.Intervals(count, :) = ntrvl.Interval';
                    obj.Level = ntrvl.Level;
                    count = count + 1;
                end
            end
            
            % Read in appropriate samples
            if (obj.GroupAnalysis)
                try
                    obj.Samples = load(...
                        fullfile(obj.LogFileDir, 'pop_beta.log'), ...
                        '-ascii');
                catch ME
                    warning(ME.identifier, '%s', ME.message);
                end
            else
                % Attempt to find correct file for single subject
                obj.Samples = 0;
                for i = 1:length(lfd)
                    if ~(regexpl(lfd(i).name, '^sub_') || ...
                            regexpl(lfd(i).name, '^pop_beta'))
                        if all(obj.Samples == 0)
                            obj.Samples = load(obj.LogFiles{i}, '-ascii');
                        end
                    end
                end
                if all(obj.Samples == 0)
                    obj.Samples = [];
                    warning('Could not locate participant''s MCMC ouptut file');
                end
            end
        end
        function tbl = table(obj, varargin)
            % Conversion from FNIRS1.DLM_SUMMARY to table
            %
            % Optional additional argument can be used to select whether to
            % return table of the estimates or standard errors. For
            % example, if D is an fnirs1.dlm_summary object,
            % >> table(D)              % returns table of Estimates
            % >> table(D, 'Std.Err.')  % returns table of standard errors
            %
            prop = 'Estimates';
            if (nargin > 1)
                if ~(ischar(varargin{1}) || isstring(varargin{1}))
                    error('dlm_summary:TableConversion:BadProperty', ...
                        'property should be string-like');
                end
                if (strcmpi(varargin{1}, 'StdError') || ...
                        strcmpi(varargin{1}, 'Std.Err.') || ...
                        strcmpi(varargin{1}, 'StdErrors'))
                    prop = 'StdErrors';
                elseif ~(strcmpi(varargin{1}, 'Estimate') || ...
                        strcmpi(varargin{1}, 'Estimates'))
                    error('dlm_summary:TableConversion:UnrecProp', ...
                        'unrecognized property option');
                end
            end
            if ~isempty(obj)
                Channel = cellstr(vertcat(obj(:).Nickname));
                tbl = array2table(horzcat(obj(:).(prop))', ...
                    'VariableNames', ...
                    matlab.lang.makeValidName(obj(1).Descriptions), ...
                    'RowNames', Channel);
            else
                tbl = table();
            end
        end
    end
    methods (Static)
        function displayEmptyObject()
            fprintf('\tempty fnirs1.dlm_summary object\n');
        end
    end
end
