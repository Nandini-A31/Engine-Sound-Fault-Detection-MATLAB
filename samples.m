fs = 16000;
duration = 2; % seconds
t = 0:1/fs:duration;

numSamples = 20; % 10 normal + 10 faulty

outputFolder = 'EngineAudioDataset';
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

for i = 1:numSamples
    if i <= numSamples/2
        % ---- NORMAL ENGINE ----
        baseFreq = 120 + 20*randn(); % small jitter
        signal = 0.5 * sin(2*pi*baseFreq*t);
        signal = signal + 0.02 * randn(size(t)); % tiny noise
        label = 'normal';
    else
        % ---- FAULTY ENGINE ----
        baseFreq = 500 + 200*randn(); % higher freq
        noise = 0.5 * randn(size(t));
        signal = 0.3 * sin(2*pi*baseFreq*t) + ...
                 0.2 * sin(2*pi*2000*t) + ...
                 noise;
        label = 'faulty';
    end

    % Normalize audio
    signal = signal / max(abs(signal));

    % Save as .wav
    filename = sprintf('%s/engine_%s_%02d.wav', outputFolder, label, i);
    audiowrite(filename, signal, fs);
    fprintf('Saved: %s\n', filename);
end

disp('✅ Dataset generation complete!');
