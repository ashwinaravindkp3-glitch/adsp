
classdef CurrencyAuthenticationApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        GridLayout                    matlab.ui.container.GridLayout
        LeftPanel                     matlab.ui.container.Panel
        LoadTestImageButton           matlab.ui.control.Button
        StartDetectionButton          matlab.ui.control.Button
        UseExponentialScoringCheckBox matlab.ui.control.CheckBox
        ExportReportButton            matlab.ui.control.Button
        StatusTextArea                matlab.ui.control.TextArea
        StatusLabel                   matlab.ui.control.Label
        
        RightPanel                    matlab.ui.container.Panel
        TabGroup                      matlab.ui.container.TabGroup
        ImagesTab                     matlab.ui.container.Tab
        TestImageAxes                 matlab.ui.control.UIAxes
        ReferenceImageAxes            matlab.ui.control.UIAxes
        
        ResultsTab                    matlab.ui.container.Tab
        VerdictLabel                  matlab.ui.control.Label
        WeightedScoreGauge            matlab.ui.control.SemicircularGauge
        WeightedScoreLabel            matlab.ui.control.Label
        ChannelScoresAxes             matlab.ui.control.UIAxes
        
        ChannelATab                   matlab.ui.container.Tab
        ChannelAAxes1                 matlab.ui.control.UIAxes
        ChannelAAxes2                 matlab.ui.control.UIAxes
        ChannelAScoreLabel            matlab.ui.control.Label
        
        ChannelBTab                   matlab.ui.container.Tab
        ChannelBAxes                  matlab.ui.control.UIAxes
        ChannelBScoreLabel            matlab.ui.control.Label
        
        ChannelCTab                   matlab.ui.container.Tab
        ChannelCAxes1                 matlab.ui.control.UIAxes
        ChannelCAxes2                 matlab.ui.control.UIAxes
        ChannelCScoreLabel            matlab.ui.control.Label
        
        ChannelDTab                   matlab.ui.container.Tab
        ChannelDAxes1                 matlab.ui.control.UIAxes
        ChannelDAxes2                 matlab.ui.control.UIAxes
        ChannelDScoreLabel            matlab.ui.control.Label
        
        DetailsTab                    matlab.ui.container.Tab
        DetailsTextArea               matlab.ui.control.TextArea
    end

    % Properties for storing data
    properties (Access = private)
        TestImagePath           % Path to test image
        ReferenceImagePath = 'ref_camera.png'  % HARDCODED internal reference
        TestImage               % Loaded test image
        ReferenceImage          % Loaded reference image
        DetectionResults        % Structure containing all results
        ProcessingInProgress    % Flag to prevent multiple simultaneous processing
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Initialize default values
            app.UseExponentialScoringCheckBox.Value = true;
            app.ProcessingInProgress = false;
            
            % Auto-load reference image
            try
                if exist(app.ReferenceImagePath, 'file')
                    app.ReferenceImage = imread(app.ReferenceImagePath);
                    imshow(app.ReferenceImage, 'Parent', app.ReferenceImageAxes);
                    title(app.ReferenceImageAxes, 'Reference Image (Internal)', 'FontSize', 12, 'FontWeight', 'bold');
                    app.updateStatus('✓ Reference image loaded automatically');
                else
                    app.updateStatus('⚠ Reference image not found! Place ref_camera.png in current directory');
                end
            catch ME
                app.updateStatus(sprintf('⚠ Error loading reference: %s', ME.message));
            end
            
            % Set initial status
            app.StatusTextArea.Value = {'Currency Authentication System Ready', ...
                                        'Please load a test image to begin.', ...
                                        '', ...
                                        'Reference: ref_camera.png (auto-loaded)'};
            
            % Disable detection and export buttons initially
            app.StartDetectionButton.Enable = 'off';
            app.ExportReportButton.Enable = 'off';
            
            % Initialize verdict label
            app.VerdictLabel.Text = 'AWAITING DETECTION';
            app.VerdictLabel.FontColor = [0.5 0.5 0.5];
        end

        % Button pushed function: LoadTestImageButton
        function LoadTestImageButtonPushed(app, event)
            [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp','Image Files (*.jpg,*.jpeg,*.png,*.bmp)'}, ...
                                     'Select Test Currency Image');
            
            if file ~= 0
                try
                    app.TestImagePath = fullfile(path, file);
                    app.TestImage = imread(app.TestImagePath);
                    
                    % Display image
                    imshow(app.TestImage, 'Parent', app.TestImageAxes);
                    title(app.TestImageAxes, 'Test Image', 'FontSize', 12, 'FontWeight', 'bold');
                    
                    % Update status
                    app.updateStatus(sprintf('✓ Test image loaded: %s', file));
                    
                    % Enable detection if both images are loaded
                    app.checkEnableDetection();
                catch ME
                    uialert(app.UIFigure, sprintf('Error loading image: %s', ME.message), 'Load Error');
                end
            end
        end

        % Button pushed function: StartDetectionButton
        function StartDetectionButtonPushed(app, event)
            if app.ProcessingInProgress
                return;
            end
            
            % Disable button and show processing state
            app.ProcessingInProgress = true;
            app.StartDetectionButton.Enable = 'off';
            app.StartDetectionButton.Text = 'PROCESSING...';
            app.StartDetectionButton.BackgroundColor = [0.93 0.69 0.13]; % Orange
            drawnow;
            
            try
                % Update status
                app.updateStatus('Starting detection process...');
                
                % Use hardcoded optimal threshold values
                threshold_A = 0.25;
                threshold_B = 0.43;
                threshold_C = 0.50;
                threshold_D = 0.75;
                use_exponential = app.UseExponentialScoringCheckBox.Value;
                
                % Run detection (main processing function)
                app.DetectionResults = app.runDetection(app.TestImagePath, app.ReferenceImagePath, ...
                                                        threshold_A, threshold_B, threshold_C, threshold_D, ...
                                                        use_exponential);
                
                % Display results
                app.displayResults();
                
                % Enable export button
                app.ExportReportButton.Enable = 'on';
                
                % Update status
                app.updateStatus('✓ Detection complete!');
                
            catch ME
                uialert(app.UIFigure, sprintf('Detection Error: %s', ME.message), 'Processing Error');
                app.updateStatus(sprintf('✗ Error: %s', ME.message));
            end
            
            % Re-enable button
            app.ProcessingInProgress = false;
            app.StartDetectionButton.Enable = 'on';
            app.StartDetectionButton.Text = 'START DETECTION';
            app.StartDetectionButton.BackgroundColor = [0.39 0.83 0.07]; % Green
        end

        % Button pushed function: ExportReportButton
        function ExportReportButtonPushed(app, event)
            if isempty(app.DetectionResults)
                uialert(app.UIFigure, 'No results to export. Please run detection first.', 'Export Error');
                return;
            end
            
            [file, path] = uiputfile({'*.txt','Text File (*.txt)'; '*.pdf','PDF Report (*.pdf)'}, ...
                                     'Save Report As');
            
            if file ~= 0
                try
                    fullpath = fullfile(path, file);
                    app.exportReport(fullpath);
                    uialert(app.UIFigure, sprintf('Report saved successfully to:\n%s', fullpath), ...
                           'Export Successful', 'Icon', 'success');
                    app.updateStatus(sprintf('✓ Report exported: %s', file));
                catch ME
                    uialert(app.UIFigure, sprintf('Export Error: %s', ME.message), 'Export Failed');
                end
            end
        end

        % Helper function to check if detection can be enabled
        function checkEnableDetection(app)
            if ~isempty(app.TestImagePath) && ~isempty(app.ReferenceImage)
                app.StartDetectionButton.Enable = 'on';
            end
        end

        % Helper function to update status
        function updateStatus(app, message)
            currentStatus = app.StatusTextArea.Value;
            timestamp = datetime('now', 'Format', 'HH:mm:ss');
            newMessage = sprintf('[%s] %s', timestamp, message);
            
            % Keep only last 10 messages
            if length(currentStatus) >= 10
                currentStatus = currentStatus(2:end);
            end
            
            app.StatusTextArea.Value = [currentStatus; {newMessage}];
            drawnow;
        end

        % Main detection function (calls your existing code)
        function results = runDetection(app, test_path, ref_path, thresh_A, thresh_B, thresh_C, thresh_D, use_exp)
            % This function integrates your existing detection code
            app.updateStatus('Step 1/6: Loading images...');
            
            % Pre-processing
            app.updateStatus('Step 2/6: Pre-processing...');
            test_img_denoised = app.applyNoiseFilter(test_path);
            
            % Alignment
            app.updateStatus('Step 3/6: Aligning images...');
            [aligned_img, alignment_info] = app.warpImageAfterHomography(test_path, ref_path);
            
            % Channel A
            app.updateStatus('Step 4/6: Running Channel A (Photocopy Detection)...');
            [score_A, channelA_fig] = app.run_channel_A(aligned_img);
            
            % Channel B
            app.updateStatus('Step 4/6: Running Channel B (Template Matching)...');
            [score_B, channelB_fig] = app.run_channel_B(aligned_img);
            
            % Channel C
            app.updateStatus('Step 4/6: Running Channel C (Security Thread)...');
            [scores_C, channelC_fig] = app.run_channel_C(aligned_img);
            
            % Channel D
            app.updateStatus('Step 4/6: Running Channel D (Gabor Texture)...');
            reference_img = imread(ref_path);
            [score_D, peak_count, channelD_fig] = app.run_channel_D(aligned_img, reference_img);
            
            % Final decision
            app.updateStatus('Step 5/6: Computing final verdict...');
            [verdict, weighted_score, decision_info] = app.computeFinalDecision(...
                score_A, score_B, scores_C.thread, score_D, ...
                thresh_A, thresh_B, thresh_C, thresh_D, use_exp);
            
            % Package results
            results.score_A = score_A;
            results.score_B = score_B;
            results.score_C = scores_C.thread;
            results.score_D = score_D;
            results.scores_C_full = scores_C;
            results.channelA_fig = channelA_fig;
            results.channelB_fig = channelB_fig;
            results.channelC_fig = channelC_fig;
            results.channelD_fig = channelD_fig;
            results.verdict = verdict;
            results.weighted_score = weighted_score;
            results.decision_info = decision_info;
            results.aligned_img = aligned_img;
            results.thresholds = [thresh_A, thresh_B, thresh_C, thresh_D];
            results.use_exponential = use_exp;
            
            app.updateStatus('Step 6/6: Complete!');
        end

        % Display results in GUI
        function displayResults(app)
            res = app.DetectionResults;
            
            % Update verdict label
            if strcmp(res.verdict, 'REAL')
                app.VerdictLabel.Text = '✓ AUTHENTIC';
                app.VerdictLabel.FontColor = [0 0.7 0]; % Green
            else
                app.VerdictLabel.Text = '✗ COUNTERFEIT';
                app.VerdictLabel.FontColor = [0.8 0 0]; % Red
            end
            
            % Update weighted score gauge
            app.WeightedScoreGauge.Value = res.weighted_score;
            app.WeightedScoreLabel.Text = sprintf('Confidence: %.1f%%', res.weighted_score * 100);
            
            % Plot channel scores
            cla(app.ChannelScoresAxes);
            scores = [res.score_A, res.score_B, res.score_C, res.score_D];
            thresholds = res.thresholds;
            
            hold(app.ChannelScoresAxes, 'on');
            bar(app.ChannelScoresAxes, scores, 'FaceColor', [0.2 0.6 0.8]);
            plot(app.ChannelScoresAxes, 1:4, thresholds, 'ro-', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
            
            % Add score labels
            for i = 1:4
                text(app.ChannelScoresAxes, i, scores(i)+0.03, sprintf('%.3f', scores(i)), ...
                    'HorizontalAlignment', 'center', 'FontWeight', 'bold');
            end
            
            set(app.ChannelScoresAxes, 'XTick', 1:4, 'XTickLabel', {'Channel A', 'Channel B', 'Channel C', 'Channel D'});
            ylabel(app.ChannelScoresAxes, 'Score');
            ylim(app.ChannelScoresAxes, [0 1]);
            title(app.ChannelScoresAxes, sprintf('Channel Scores (Weighted: %.3f)', res.weighted_score), 'FontWeight', 'bold');
            legend(app.ChannelScoresAxes, {'Scores', 'Thresholds'}, 'Location', 'northwest');
            grid(app.ChannelScoresAxes, 'on');
            hold(app.ChannelScoresAxes, 'off');
            
            % Display Channel A results
            cla(app.ChannelAAxes1);
            imshow(res.channelA_fig.roi, 'Parent', app.ChannelAAxes1);
            title(app.ChannelAAxes1, 'ROI', 'FontSize', 10);
            
            cla(app.ChannelAAxes2);
            bar(app.ChannelAAxes2, [res.channelA_fig.halftone_score, res.channelA_fig.noise_score, ...
                                    res.channelA_fig.sharpness_score, res.channelA_fig.color_score]);
            set(app.ChannelAAxes2, 'XTickLabel', {'Halftone', 'Noise', 'Sharp', 'Color'});
            title(app.ChannelAAxes2, 'Sub-Scores', 'FontSize', 10);
            ylim(app.ChannelAAxes2, [0 1]);
            
            app.ChannelAScoreLabel.Text = sprintf('Channel A Score: %.3f\nHalftone: %.3f | Noise: %.3f\nSharpness: %.3f | Color: %.3f', ...
                res.score_A, res.channelA_fig.halftone_score, res.channelA_fig.noise_score, ...
                res.channelA_fig.sharpness_score, res.channelA_fig.color_score);
            
            % Display Channel B (simplified)
            cla(app.ChannelBAxes);
            if ~isempty(res.channelB_fig.individual_scores)
                bar(app.ChannelBAxes, res.channelB_fig.individual_scores);
                title(app.ChannelBAxes, 'Template Match Scores', 'FontSize', 10);
                ylabel(app.ChannelBAxes, 'Score');
                ylim(app.ChannelBAxes, [0 1]);
                grid(app.ChannelBAxes, 'on');
            end
            app.ChannelBScoreLabel.Text = sprintf('Channel B Score: %.3f\n(%d/%d templates matched)', ...
                res.score_B, round(res.score_B * length(res.channelB_fig.individual_scores)), ...
                length(res.channelB_fig.individual_scores));
            
            % Display Channel C
            cla(app.ChannelCAxes1);
            imshow(res.channelC_fig.thread_roi, 'Parent', app.ChannelCAxes1);
            title(app.ChannelCAxes1, 'Security Thread ROI', 'FontSize', 10);
            
            cla(app.ChannelCAxes2);
            imshow(res.channelC_fig.s_thread, [], 'Parent', app.ChannelCAxes2);
            title(app.ChannelCAxes2, 'HSV Saturation', 'FontSize', 10);
            colormap(app.ChannelCAxes2, 'jet');
            
            app.ChannelCScoreLabel.Text = sprintf('Channel C Score: %.3f\nAvg a*: %.2f\nAvg Saturation: %.3f', ...
                res.score_C, res.scores_C_full.avg_a_star, res.scores_C_full.avg_saturation);
            
            % Display Channel D
            cla(app.ChannelDAxes1);
            imshow(res.channelD_fig.test_texture, [], 'Parent', app.ChannelDAxes1);
            title(app.ChannelDAxes1, 'Gabor Response', 'FontSize', 10);
            colormap(app.ChannelDAxes1, 'gray');
            
            cla(app.ChannelDAxes2);
            imshow(res.channelD_fig.peaks, 'Parent', app.ChannelDAxes2);
            title(app.ChannelDAxes2, 'Detected Peaks', 'FontSize', 10);
            
            app.ChannelDScoreLabel.Text = sprintf('Channel D Score: %.3f\nPeaks Detected: %d', ...
                res.score_D, sum(res.channelD_fig.peaks(:)));
            
            % Update details text area
            app.DetailsTextArea.Value = app.generateDetailedReport();
            
            % Switch to results tab
            app.TabGroup.SelectedTab = app.ResultsTab;
        end

        % Generate detailed text report
        function report = generateDetailedReport(app)
            res = app.DetectionResults;
            
            report = {
                '═══════════════════════════════════════════'
                '    CURRENCY AUTHENTICATION REPORT'
                '═══════════════════════════════════════════'
                ''
                sprintf('Test Image: %s', app.TestImagePath)
                sprintf('Reference Image: %s', app.ReferenceImagePath)
                sprintf('Detection Time: %s', datetime('now'))
                ''
                '───────────────────────────────────────────'
                '  FINAL VERDICT'
                '───────────────────────────────────────────'
                sprintf('Result: %s', res.verdict)
                sprintf('Confidence Score: %.3f (%.1f%%)', res.weighted_score, res.weighted_score*100)
                sprintf('Decision Reason: %s', res.decision_info.reason)
                ''
                '───────────────────────────────────────────'
                '  CHANNEL ANALYSIS'
                '───────────────────────────────────────────'
                sprintf('Channel A (Photocopy):  %.3f [Threshold: %.2f] %s', ...
                    res.score_A, res.thresholds(1), app.passFailStr(res.score_A >= res.thresholds(1)))
                sprintf('  ├─ Halftone:    %.3f', res.channelA_fig.halftone_score)
                sprintf('  ├─ Noise:       %.3f (std: %.2f)', res.channelA_fig.noise_score, res.channelA_fig.noise_std)
                sprintf('  ├─ Sharpness:   %.3f', res.channelA_fig.sharpness_score)
                sprintf('  └─ Color:       %.3f', res.channelA_fig.color_score)
                ''
                sprintf('Channel B (Templates):  %.3f [Threshold: %.2f] %s', ...
                    res.score_B, res.thresholds(2), app.passFailStr(res.score_B >= res.thresholds(2)))
                sprintf('  └─ Matched: %d/%d templates', ...
                    round(res.score_B * length(res.channelB_fig.individual_scores)), ...
                    length(res.channelB_fig.individual_scores))
                ''
                sprintf('Channel C (Thread):     %.3f [Threshold: %.2f] %s', ...
                    res.score_C, res.thresholds(3), app.passFailStr(res.score_C >= res.thresholds(3)))
                sprintf('  ├─ Avg a*:      %.2f', res.scores_C_full.avg_a_star)
                sprintf('  └─ Saturation:  %.3f', res.scores_C_full.avg_saturation)
                ''
                sprintf('Channel D (Texture):    %.3f [Threshold: %.2f] %s', ...
                    res.score_D, res.thresholds(4), app.passFailStr(res.score_D >= res.thresholds(4)))
                sprintf('  └─ Peaks: %d', sum(res.channelD_fig.peaks(:)))
                ''
                '───────────────────────────────────────────'
                '  DECISION SUMMARY'
                '───────────────────────────────────────────'
                sprintf('Channels Passed: %d/4', res.decision_info.channels_passed)
                sprintf('Strong Passes: %d/4', res.decision_info.strong_passes)
                sprintf('Scoring Method: %s', app.ternaryStr(res.use_exponential, 'Exponential', 'Linear'))
                ''
                '═══════════════════════════════════════════'
            };
        end

        % Export report to file
        function exportReport(app, filepath)
            report = app.generateDetailedReport();
            
            % Write to text file
            fid = fopen(filepath, 'w');
            if fid == -1
                error('Cannot open file for writing');
            end
            
            try
                for i = 1:length(report)
                    fprintf(fid, '%s\n', report{i});
                end
                fclose(fid);
            catch ME
                fclose(fid);
                rethrow(ME);
            end
        end

        % Helper functions
        function str = passFailStr(~, passed)
            if passed
                str = '✓ PASS';
            else
                str = '✗ FAIL';
            end
        end

        function str = ternaryStr(~, condition, true_str, false_str)
            if condition
                str = true_str;
            else
                str = false_str;
            end
        end

        % === DETECTION ALGORITHM FUNCTIONS (from your code) ===
        
        function denoised = applyNoiseFilter(~, image_path)
            original_image = imread(image_path);
            if ~isfloat(original_image)
                original_image = im2double(original_image);
            end
            denoised_double = imbilatfilt(original_image, 'DegreeOfSmoothing', 0.1, 'SpatialSigma', 2);
            denoised = im2uint8(denoised_double);
        end

        function normalized = normalizeIllumination(~, image)
            if size(image, 3) == 3
                gray = rgb2gray(image);
            else
                gray = image;
            end
            I = im2double(gray);
            I_log = log(1 + I);
            I_fft = fft2(I_log);
            [M, N] = size(I);
            D0 = 15; n = 2;
            [X, Y] = meshgrid(1:N, 1:M);
            D = sqrt((X - N/2).^2 + (Y - M/2).^2);
            D(D == 0) = 1e-6;
            H = 1 ./ (1 + (D0 ./ D).^(2*n));
            I_fft_filtered = fftshift(I_fft) .* H;
            I_filtered = real(ifft2(ifftshift(I_fft_filtered)));
            I_exp = exp(I_filtered) - 1;
            normalized = im2uint8(mat2gray(I_exp));
        end

        function [warped, info] = warpImageAfterHomography(app, test_path, ref_path)
            ref_img = imread(ref_path);
            if size(ref_img, 3) == 3
                ref_gray = rgb2gray(ref_img);
            else
                ref_gray = ref_img;
            end
            
            test_denoised = app.applyNoiseFilter(test_path);
            test_img = imresize(test_denoised, [size(ref_img, 1), NaN]);
            if size(test_img, 3) == 3
                test_gray = rgb2gray(test_img);
            else
                test_gray = test_img;
            end
            
            ref_pts = detectORBFeatures(ref_gray);
            test_pts = detectORBFeatures(test_gray);
            
            [ref_feats, ref_pts] = extractFeatures(ref_gray, ref_pts);
            [test_feats, test_pts] = extractFeatures(test_gray, test_pts);
            
            index_pairs = matchFeatures(test_feats, ref_feats, 'MaxRatio', 0.7, 'Unique', true);
            matched_test = test_pts(index_pairs(:, 1), :);
            matched_ref = ref_pts(index_pairs(:, 2), :);
            
            if size(matched_test, 1) < 4
                error('Insufficient feature matches for alignment');
            end
            
            [tform, inliers] = estimateGeometricTransform2D(matched_test, matched_ref, 'projective', ...
                'Confidence', 99.9, 'MaxNumTrials', 2000);
            
            warped = imwarp(test_img, tform, 'OutputView', imref2d(size(ref_img)), 'FillValues', 255);
            
            info.match_count = size(matched_test, 1);
            info.inlier_count = sum(inliers);
        end

        function [score, fig_data] = run_channel_A(app, aligned_img)
            roi_rect = [200, 200, 600, 400];
            roi = app.extractROI(aligned_img, roi_rect);
            if size(roi, 3) == 3
                gray = rgb2gray(roi);
            else
                gray = roi;
            end
            [H, W] = size(gray);
            
            F = fftshift(fft2(double(gray)));
            [X, Y] = meshgrid(1:W, 1:H);
            cx = round(W/2); cy = round(H/2);
            R = sqrt((X - cx).^2 + (Y - cy).^2);
            R_int = max(round(R), 1);
            rad_profile = accumarray(R_int(:), abs(F(:)), [], @mean, 0);
            
            mid_start = round(length(rad_profile) * 0.3);
            mid_end = round(length(rad_profile) * 0.7);
            mid_band = rad_profile(mid_start:mid_end);
            low_band = rad_profile(1:min(30, length(rad_profile)));
            
            periodicity = max(mid_band) / (mean(low_band) + 1e-6);
            score_halftone = 1 - min(periodicity / 5, 1);
            
            high_pass = imfilter(double(gray), fspecial('laplacian', 0.2));
            noise_std = std(high_pass(:));
            
            if noise_std >= 8 && noise_std <= 15
                score_noise = 1.0;
            elseif noise_std < 5
                score_noise = noise_std / 5;
            else
                score_noise = max(0, 1 - (noise_std - 15) / 10);
            end
            
            edges = edge(gray, 'Canny');
            if any(edges(:))
                [Gx, Gy] = gradient(double(gray));
                G_mag = sqrt(Gx.^2 + Gy.^2);
                edge_sharp = mean(G_mag(edges));
                score_sharpness = min(edge_sharp / 15, 1);
            else
                score_sharpness = 0.5;
            end
            
            if size(roi, 3) == 3
                hsv_roi = rgb2hsv(roi);
                sat = hsv_roi(:, :, 2);
                sat_std = std(sat(:));
                if sat_std >= 0.08 && sat_std <= 0.15
                    score_color = 1.0;
                elseif sat_std < 0.08
                    score_color = sat_std / 0.08;
                else
                    score_color = max(0, 1 - (sat_std - 0.15) / 0.1);
                end
            else
                score_color = 0.5;
            end
            
            score = 0.35 * score_halftone + 0.30 * score_noise + 0.25 * score_sharpness + 0.10 * score_color;
            score = max(0, min(score, 1));
            
            fig_data.roi = roi;
            fig_data.freq_profile = rad_profile;
            fig_data.halftone_score = score_halftone;
            fig_data.noise_score = score_noise;
            fig_data.sharpness_score = score_sharpness;
            fig_data.color_score = score_color;
            fig_data.noise_std = noise_std;
            fig_data.edge_sharpness = edge_sharp;
            fig_data.high_pass = high_pass;
        end

        function [score, fig_data] = run_channel_B(app, aligned_img)
            processed = app.normalizeIllumination(aligned_img);
            processed_eq = histeq(processed);
            
            template_files = {'template_ashoka.png', 'template_devnagari.jpg', 'template_rbi_seal.jpg', ...
                'template_small100.jpg', 'template_ashoka.jpg', 'template_pattern.jpg', ...
                'template_kuthira.jpg', 'template_sathyam.png', 'template_verysmall_100.jpg'};
            
            threshold = 0.6;
            num_found = 0;
            num_templates = length(template_files);
            scores = zeros(num_templates, 1);
            
            for i = 1:num_templates
                try
                    template = imread(template_files{i});
                    if size(template, 3) == 3
                        template = rgb2gray(template);
                    end
                    template_eq = histeq(template);
                    corr_map = normxcorr2(template_eq, processed_eq);
                    max_corr = max(corr_map(:));
                    scores(i) = max_corr;
                    if max_corr >= threshold
                        num_found = num_found + 1;
                    end
                catch
                    scores(i) = 0;
                end
            end
            
            score = num_found / num_templates;
            fig_data.individual_scores = scores;
        end

        function [scores_struct, fig_data] = run_channel_C(app, aligned_img)
            roi_rect = [845, 14, 338, 731];
            roi = app.extractROI(aligned_img, roi_rect);
            
            lab_img = rgb2lab(roi);
            hsv_img = rgb2hsv(roi);
            
            a_channel = lab_img(:, :, 2);
            s_channel = hsv_img(:, :, 2);
            
            avg_a = mean(a_channel(:));
            avg_sat = mean(s_channel(:));
            
            a_norm = 1 - min(max((avg_a - 2.5) / (9.0 - 2.5), 0), 1);
            s_norm = min(max((avg_sat - 0.12) / (0.18 - 0.12), 0), 1);
            texture_std = std(s_channel(:));
            score_texture = min(texture_std / 0.05, 1);
            
            score = 0.6 * a_norm + 0.3 * s_norm + 0.1 * score_texture;
            
            scores_struct.thread = score;
            scores_struct.avg_a_star = avg_a;
            scores_struct.avg_saturation = avg_sat;
            
            fig_data.thread_roi = roi;
            fig_data.a_channel = a_channel;
            fig_data.s_thread = s_channel;
        end

        function [score, peak_count, fig_data] = run_channel_D(~, test_img, ref_img)
            if size(ref_img, 3) == 3
                ref_gray = rgb2gray(ref_img);
            else
                ref_gray = ref_img;
            end
            if size(test_img, 3) == 3
                test_gray = rgb2gray(test_img);
            else
                test_gray = test_img;
            end
            
            g = gabor(4, 90);
            mag_ref = abs(imfilter(im2double(ref_gray), g.SpatialKernel, 'conv'));
            mag_test = abs(imfilter(im2double(test_gray), g.SpatialKernel, 'conv'));
            
            avg_height = mean(mag_ref(:));
            peaks = imregionalmax(mag_test);
            heights = mag_test(peaks);
            sig_mask = heights > avg_height;
            peak_count = sum(sig_mask);
            
            score = min(peak_count / 500, 1.0);
            
            fig_data.ref_texture = mag_ref;
            fig_data.test_texture = mag_test;
            fig_data.peaks = peaks;
            fig_data.peak_heights = heights(sig_mask);
        end

        function roi = extractROI(~, img, rect)
            x = rect(1); y = rect(2); w = rect(3); h = rect(4);
            [rows, cols, ~] = size(img);
            x = max(1, min(x, cols));
            y = max(1, min(y, rows));
            w = min(w, cols - x + 1);
            h = min(h, rows - y + 1);
            roi = img(y:y+h-1, x:x+w-1, :);
        end

        function [verdict, weighted_score, info] = computeFinalDecision(~, sA, sB, sC, sD, tA, tB, tC, tD, use_exp)
            t_sum = tA + tB + tC + tD;
            wA = tA / t_sum;
            wB = tB / t_sum;
            wC = tC / t_sum;
            wD = tD / t_sum;
            
            if use_exp
                exp_scores = [sA^1.5, sB^1.5, sC^1.2, sD^1.0];
                weighted_score = wA * exp_scores(1) + wB * exp_scores(2) + wC * exp_scores(3) + wD * exp_scores(4);
            else
                weighted_score = wA * sA + wB * sB + wC * sC + wD * sD;
            end
            
            pass_A = sA >= tA;
            pass_B = sB >= tB;
            pass_C = sC >= tC;
            pass_D = sD >= tD;
            
            channels_passed = sum([pass_A, pass_B, pass_C, pass_D]);
            
            margin_thresh = 0.05;
            strong_passes = sum([sA >= (tA + margin_thresh), sB >= (tB + margin_thresh), ...
                                 sC >= (tC + margin_thresh), sD >= (tD + margin_thresh)]);
            
            if channels_passed >= 4
                verdict = 'REAL';
                reason = 'All 4 channels passed';
            elseif strong_passes >= 3
                verdict = 'REAL';
                reason = sprintf('%d channels passed with strong margins', strong_passes);
            elseif channels_passed >= 3 && weighted_score > 0.58
                verdict = 'REAL';
                reason = '3 channels passed + weighted score > 0.58';
            else
                verdict = 'FAKE';
                if channels_passed < 3
                    reason = sprintf('Only %d channel(s) passed (need 3+)', channels_passed);
                else
                    reason = sprintf('3 channels passed but weighted score %.3f < 0.58', weighted_score);
                end
            end
            
            info.channels_passed = channels_passed;
            info.strong_passes = strong_passes;
            info.reason = reason;
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1400 800];
            app.UIFigure.Name = 'Currency Authentication System';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {300, '1x'};
            app.GridLayout.RowHeight = {'1x'};

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Title = 'Controls';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.FontWeight = 'bold';
            app.LeftPanel.FontSize = 14;

            % Create LoadTestImageButton
            app.LoadTestImageButton = uibutton(app.LeftPanel, 'push');
            app.LoadTestImageButton.ButtonPushedFcn = createCallbackFcn(app, @LoadTestImageButtonPushed, true);
            app.LoadTestImageButton.Position = [20 720 260 50];
            app.LoadTestImageButton.Text = '📁 Load Test Image';
            app.LoadTestImageButton.FontSize = 16;
            app.LoadTestImageButton.FontWeight = 'bold';
            app.LoadTestImageButton.BackgroundColor = [0.3 0.7 1];
            app.LoadTestImageButton.FontColor = [1 1 1];

            % Create StartDetectionButton
            app.StartDetectionButton = uibutton(app.LeftPanel, 'push');
            app.StartDetectionButton.ButtonPushedFcn = createCallbackFcn(app, @StartDetectionButtonPushed, true);
            app.StartDetectionButton.Position = [20 600 260 80];
            app.StartDetectionButton.Text = '▶ START DETECTION';
            app.StartDetectionButton.FontSize = 20;
            app.StartDetectionButton.FontWeight = 'bold';
            app.StartDetectionButton.BackgroundColor = [0.39 0.83 0.07];
            app.StartDetectionButton.FontColor = [1 1 1];

            % Create UseExponentialScoringCheckBox
            app.UseExponentialScoringCheckBox = uicheckbox(app.LeftPanel);
            app.UseExponentialScoringCheckBox.Text = 'Use Exponential Scoring';
            app.UseExponentialScoringCheckBox.Position = [20 550 220 22];
            app.UseExponentialScoringCheckBox.FontWeight = 'bold';
            app.UseExponentialScoringCheckBox.FontSize = 12;

            % Create ExportReportButton
            app.ExportReportButton = uibutton(app.LeftPanel, 'push');
            app.ExportReportButton.ButtonPushedFcn = createCallbackFcn(app, @ExportReportButtonPushed, true);
            app.ExportReportButton.Position = [20 470 260 60];
            app.ExportReportButton.Text = '💾 Export Report';
            app.ExportReportButton.FontSize = 16;
            app.ExportReportButton.FontWeight = 'bold';
            app.ExportReportButton.BackgroundColor = [1 0.8 0.4];

            % Create StatusLabel
            app.StatusLabel = uilabel(app.LeftPanel);
            app.StatusLabel.Position = [20 430 100 22];
            app.StatusLabel.Text = 'Status Log:';
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.FontSize = 14;

            % Create StatusTextArea
            app.StatusTextArea = uitextarea(app.LeftPanel);
            app.StatusTextArea.Position = [20 20 260 400];
            app.StatusTextArea.Editable = 'off';
            app.StatusTextArea.FontName = 'Consolas';

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Title = 'Results & Analysis';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;
            app.RightPanel.FontWeight = 'bold';
            app.RightPanel.FontSize = 14;

            % Create TabGroup
            app.TabGroup = uitabgroup(app.RightPanel);
            app.TabGroup.Position = [10 10 1070 730];

            % Create ImagesTab
            app.ImagesTab = uitab(app.TabGroup);
            app.ImagesTab.Title = '📷 Images';

            % Create TestImageAxes
            app.TestImageAxes = uiaxes(app.ImagesTab);
            title(app.TestImageAxes, 'Test Image')
            app.TestImageAxes.Position = [20 370 500 340];

            % Create ReferenceImageAxes
            app.ReferenceImageAxes = uiaxes(app.ImagesTab);
            title(app.ReferenceImageAxes, 'Reference Image')
            app.ReferenceImageAxes.Position = [540 370 500 340];

            % Create ResultsTab
            app.ResultsTab = uitab(app.TabGroup);
            app.ResultsTab.Title = '✓ Final Results';

            % Create VerdictLabel
            app.VerdictLabel = uilabel(app.ResultsTab);
            app.VerdictLabel.HorizontalAlignment = 'center';
            app.VerdictLabel.FontSize = 48;
            app.VerdictLabel.FontWeight = 'bold';
            app.VerdictLabel.Position = [250 550 550 80];
            app.VerdictLabel.Text = 'AWAITING DETECTION';

            % Create WeightedScoreGauge
            app.WeightedScoreGauge = uigauge(app.ResultsTab, 'semicircular');
            app.WeightedScoreGauge.Limits = [0 1];
            app.WeightedScoreGauge.Position = [400 400 250 137];

            % Create WeightedScoreLabel
            app.WeightedScoreLabel = uilabel(app.ResultsTab);
            app.WeightedScoreLabel.HorizontalAlignment = 'center';
            app.WeightedScoreLabel.FontSize = 16;
            app.WeightedScoreLabel.FontWeight = 'bold';
            app.WeightedScoreLabel.Position = [400 360 250 22];
            app.WeightedScoreLabel.Text = 'Confidence: --';

            % Create ChannelScoresAxes
            app.ChannelScoresAxes = uiaxes(app.ResultsTab);
            title(app.ChannelScoresAxes, 'Channel Scores')
            app.ChannelScoresAxes.Position = [50 20 980 320];

            % Create ChannelATab
            app.ChannelATab = uitab(app.TabGroup);
            app.ChannelATab.Title = 'A: Photocopy';

            % Create ChannelAAxes1
            app.ChannelAAxes1 = uiaxes(app.ChannelATab);
            title(app.ChannelAAxes1, 'ROI')
            app.ChannelAAxes1.Position = [50 350 450 330];

            % Create ChannelAAxes2
            app.ChannelAAxes2 = uiaxes(app.ChannelATab);
            title(app.ChannelAAxes2, 'Sub-Scores')
            app.ChannelAAxes2.Position = [550 350 450 330];

            % Create ChannelAScoreLabel
            app.ChannelAScoreLabel = uilabel(app.ChannelATab);
            app.ChannelAScoreLabel.FontSize = 14;
            app.ChannelAScoreLabel.Position = [50 50 950 280];
            app.ChannelAScoreLabel.Text = 'Channel A results will appear here';

            % Create ChannelBTab
            app.ChannelBTab = uitab(app.TabGroup);
            app.ChannelBTab.Title = 'B: Templates';

            % Create ChannelBAxes
            app.ChannelBAxes = uiaxes(app.ChannelBTab);
            title(app.ChannelBAxes, 'Template Matching Scores')
            app.ChannelBAxes.Position = [50 250 980 430];

            % Create ChannelBScoreLabel
            app.ChannelBScoreLabel = uilabel(app.ChannelBTab);
            app.ChannelBScoreLabel.FontSize = 14;
            app.ChannelBScoreLabel.Position = [50 50 950 180];
            app.ChannelBScoreLabel.Text = 'Channel B results will appear here';

            % Create ChannelCTab
            app.ChannelCTab = uitab(app.TabGroup);
            app.ChannelCTab.Title = 'C: Thread';

            % Create ChannelCAxes1
            app.ChannelCAxes1 = uiaxes(app.ChannelCTab);
            title(app.ChannelCAxes1, 'Security Thread ROI')
            app.ChannelCAxes1.Position = [50 350 450 330];

            % Create ChannelCAxes2
            app.ChannelCAxes2 = uiaxes(app.ChannelCTab);
            title(app.ChannelCAxes2, 'HSV Saturation')
            app.ChannelCAxes2.Position = [550 350 450 330];

            % Create ChannelCScoreLabel
            app.ChannelCScoreLabel = uilabel(app.ChannelCTab);
            app.ChannelCScoreLabel.FontSize = 14;
            app.ChannelCScoreLabel.Position = [50 50 950 280];
            app.ChannelCScoreLabel.Text = 'Channel C results will appear here';

            % Create ChannelDTab
            app.ChannelDTab = uitab(app.TabGroup);
            app.ChannelDTab.Title = 'D: Texture';

            % Create ChannelDAxes1
            app.ChannelDAxes1 = uiaxes(app.ChannelDTab);
            title(app.ChannelDAxes1, 'Gabor Response')
            app.ChannelDAxes1.Position = [50 350 450 330];

            % Create ChannelDAxes2
            app.ChannelDAxes2 = uiaxes(app.ChannelDTab);
            title(app.ChannelDAxes2, 'Detected Peaks')
            app.ChannelDAxes2.Position = [550 350 450 330];

            % Create ChannelDScoreLabel
            app.ChannelDScoreLabel = uilabel(app.ChannelDTab);
            app.ChannelDScoreLabel.FontSize = 14;
            app.ChannelDScoreLabel.Position = [50 50 950 280];
            app.ChannelDScoreLabel.Text = 'Channel D results will appear here';

            % Create DetailsTab
            app.DetailsTab = uitab(app.TabGroup);
            app.DetailsTab.Title = '📋 Detailed Report';

            % Create DetailsTextArea
            app.DetailsTextArea = uitextarea(app.DetailsTab);
            app.DetailsTextArea.Position = [20 20 1020 660];
            app.DetailsTextArea.Editable = 'off';
            app.DetailsTextArea.FontName = 'Courier New';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = CurrencyAuthenticationApp

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end