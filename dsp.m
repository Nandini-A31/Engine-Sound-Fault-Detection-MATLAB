% Engine Sound Analysis and Fault Detection System
clc;
clear; 
close all;
% Load Audio File
[filename, pathname] = uigetfile({'*.wav;*.mp3;*.ogg;*.flac;*.au',...
                                  'Audio Files (*.wav, *.mp3, *.ogg, *.flac, *.au)'},...
                                  'Select Engine Sound Recording');
if isequal(filename, 0)
    disp('User selected Cancel');
    return;
else
    disp(['User selected ', fullfile(pathname, filename)]);
end

[audioIn, fs] = audioread(fullfile(pathname, filename));
% Plot the original signal
figure(1);
subplot(2,1,1);
plot(audioIn);
title('Original Engine Sound Signal');
xlabel('Sample Number');
ylabel('Amplitude');
% Normalize the audio signal
audioIn = audioIn / max(abs(audioIn));
% If stereo, convert to mono
if size(audioIn, 2) == 2
    audioIn = mean(audioIn, 2);
end
% Apply bandpass filter to focus on engine sound frequencies (50Hz to 5kHz)
lowCutoff = 50; % Hz
highCutoff = 5000; % Hz
[b, a] = butter(4, [lowCutoff, highCutoff]/(fs/2), 'bandpass');
filteredAudio = filtfilt(b, a, audioIn);
% Plot the filtered signal
subplot(2,1,2);
plot(filteredAudio);
title('Filtered Engine Sound Signal');
xlabel('Sample Number');
ylabel('Amplitude');
% Feature Extraction
frameLength = round(0.03 * fs); 
overlapLength = round(0.02 * fs); 
hopLength = frameLength - overlapLength;
% Initialize feature vectors
zeroCrossingRate = [];
spectralCentroid = [];
spectralFlux = [];
mfccs = [];
rmsEnergy = [];
% Create window function
window = hamming(frameLength, 'periodic');
% Previous frame spectrum for spectral flux calculation
prevSpectrum = [];
numFrames = floor((length(filteredAudio) - frameLength)/hopLength) + 1;
for i = 1:numFrames
    frameStart = (i-1)*hopLength + 1;
    frameEnd = frameStart + frameLength - 1;
     if frameEnd > length(filteredAudio)
        frame = filteredAudio(frameStart:end);
        frame = [frame; zeros(frameLength - length(frame), 1)];
    else
        frame = filteredAudio(frameStart:frameEnd);
    end
    % Apply window
    frameWindowed = frame .* window;
    % Zero-crossing rate
    zcr = sum(abs(diff(frameWindowed > 0))) / length(frameWindowed);
    zeroCrossingRate = [zeroCrossingRate; zcr];
    % RMS energy
    rms = sqrt(mean(frameWindowed.^2));
    rmsEnergy = [rmsEnergy; rms];
    % Spectral features
    fftFrame = abs(fft(frameWindowed, 2048));
    fftFrame = fftFrame(1:1024); 
    % Spectral Centroid
    freqBins = (0:1023)' * (fs/2048);
    spectralCentroid = [spectralCentroid; sum(fftFrame .* freqBins) / sum(fftFrame)];
    % Spectral Flux
    if ~isempty(prevSpectrum)
        flux = sum((fftFrame - prevSpectrum).^2) / length(fftFrame);
        spectralFlux = [spectralFlux; flux];
    end
    prevSpectrum = fftFrame;
    % Simple MFCC-like features 
    melSpectrum = melfilterbank(fftFrame, fs, 26);
    mfccFrame = dct(log(melSpectrum + eps));
    mfccs = [mfccs; mfccFrame(1:13)'];
end
% Fill first spectral flux with zero if empty
if isempty(spectralFlux)
    spectralFlux = zeros(size(spectralCentroid));
else
    spectralFlux = [0; spectralFlux]; 
end
% Statistical feature aggregation
features = [
    mean(zeroCrossingRate), std(zeroCrossingRate), ...
    mean(spectralCentroid), std(spectralCentroid), ...
    mean(spectralFlux), std(spectralFlux), ...
    mean(rmsEnergy), std(rmsEnergy), ...
    mean(mfccs), std(mfccs)
];
% Simple Classification (Replace with your trained model)
threshold1 = mean(spectralCentroid) > 1500;
threshold2 = std(mfccs(:,1)) > 5;
threshold3 = mean(zeroCrossingRate) > 0.25;
if threshold1 || threshold2 || threshold3
    engineStatus = 'Faulty';
    disp('Potential issues detected:');
    if threshold1
        disp('- High spectral centroid (possible high-frequency noise)');
    end
    if threshold2
        disp('- High variation in MFCCs (possible irregular sound patterns)');
    end
    if threshold3
        disp('- High zero crossing rate (possible knocking or rattling)');
    end
else
    engineStatus = 'Normal';
    disp('No significant anomalies detected');
end
% Display Results
figure(2);
subplot(3,1,1);
plot(zeroCrossingRate);
title('Zero Crossing Rate Over Time');
xlabel('Frame Number');
ylabel('ZCR');
subplot(3,1,2);
plot(spectralCentroid);
title('Spectral Centroid Over Time');
xlabel('Frame Number');
ylabel('Frequency (Hz)');
subplot(3,1,3);
plot(rmsEnergy);
title('RMS Energy Over Time');
xlabel('Frame Number');
ylabel('Amplitude');
% Display classification result
disp('===============================================');
disp('Engine Sound Analysis Results:');
disp(['File: ' filename]);
disp(['Sampling Rate: ' num2str(fs) ' Hz']);
disp(['Analysis Duration: ' num2str(length(audioIn)/fs) ' seconds']);
disp('-----------------------------------------------');
disp(['Engine Status: ' engineStatus]);
disp('===============================================');
msgbox(['Engine Status: ' engineStatus], 'Analysis Result');
% Helper function for mel filterbank
function melSpectrum = melfilterbank(spectrum, fs, numFilters)
    lowMel = 2595 * log10(1 + 300/700);
    highMel = 2595 * log10(1 + fs/(2*700));
    melPoints = linspace(lowMel, highMel, numFilters + 2);
    hzPoints = 700 * (10.^(melPoints/2595) - 1);
    binPoints = floor(hzPoints * (length(spectrum)/(fs/2)));
    filterbank = zeros(numFilters, length(spectrum));
    for i = 1:numFilters
        left = binPoints(i);
        center = binPoints(i+1);
        right = binPoints(i+2);
        filterbank(i,left:center) = linspace(0, 1, center-left+1);
        filterbank(i,center:right) = linspace(1, 0, right-center+1);
    end
    melSpectrum = filterbank * spectrum;
end