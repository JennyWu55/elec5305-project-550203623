function feedback2_preliminary()
% ELEC5305 Project Feedback Two
% STFT-Based Speech Enhancement Using Wiener Filtering
%
% Stable preliminary implementation using manual STFT / ISTFT
% reconstruction with weighted overlap-add.
%
% Input:
%   audio/clean.wav
%
% Output:
%   audio/noisy.wav
%   audio/enhanced.wav
%
% Results:
%   results/waveform_comparison.png
%   results/spectrogram_comparison.png
%   results/snr_results.png
%   results/snr_results.txt

close all;
clc;

%% ============================================================
%  1. Project folders
% =============================================================

thisFile = mfilename('fullpath');
srcDir = fileparts(thisFile);
projectDir = fileparts(srcDir);

audioDir = fullfile(projectDir, 'audio');
resultsDir = fullfile(projectDir, 'results');

if ~exist(audioDir, 'dir')
    mkdir(audioDir);
end

if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

cleanFile = fullfile(audioDir, 'clean.wav');
noisyFile = fullfile(audioDir, 'noisy.wav');
enhancedFile = fullfile(audioDir, 'enhanced.wav');

if ~isfile(cleanFile)
    error(['audio/clean.wav was not found. ' ...
           'Please keep the valid clean recording from the previous run.']);
end

fprintf('\n============================================\n');
fprintf('ELEC5305 PROJECT FEEDBACK TWO\n');
fprintf('STFT + WIENER SPEECH ENHANCEMENT\n');
fprintf('============================================\n');

%% ============================================================
%  2. Parameters
% =============================================================

fsTarget = 16000;

% Use 5 dB for the preliminary Feedback Two result.
% More difficult conditions can be tested later.
targetSNRdB = 5;

silenceDuration = 1.0;

frameLength = 512;
hopLength = 256;
fftLength = 512;

% Wiener gain floor
gainFloor = 0.12;

%% ============================================================
%  3. Load clean speech
% =============================================================

[clean, fsOriginal] = audioread(cleanFile);

if size(clean, 2) > 1
    clean = mean(clean, 2);
end

clean = clean(:);

if fsOriginal ~= fsTarget
    clean = resample(clean, fsTarget, fsOriginal);
end

fs = fsTarget;

% Remove DC offset
clean = clean - mean(clean);

% Normalise processing signal while leaving headroom
cleanPeak = max(abs(clean));

if cleanPeak <= 0
    error('clean.wav contains no usable audio.');
end

clean = 0.30 * clean / cleanPeak;

fprintf('\nLoaded clean speech successfully.\n');
fprintf('Clean duration: %.2f seconds\n', length(clean) / fs);

%% ============================================================
%  4. Verify clean recording
% =============================================================

fprintf('Playing clean speech for verification...\n');

soundsc(clean, fs);
pause(length(clean) / fs + 0.5);

%% ============================================================
%  5. Define evaluation speech region
% =============================================================

speechStartSample = round(silenceDuration * fs) + 1;

if speechStartSample >= length(clean)
    error('The clean recording is too short.');
end

evaluationRegion = speechStartSample:length(clean);

speechPower = mean(clean(evaluationRegion).^2);

fprintf('Clean speech power: %.8f\n', speechPower);

if speechPower < 1e-8
    error('Clean speech power is too small.');
end

%% ============================================================
%  6. Generate synthetic Gaussian background noise
% =============================================================

rng(5305);

noise = randn(size(clean));
noise = noise - mean(noise);

noisePower = mean(noise(evaluationRegion).^2);

noiseScale = sqrt( ...
    speechPower / ...
    (noisePower * 10^(targetSNRdB / 10)) );

addedNoise = noiseScale * noise;

noisy = clean + addedNoise;

fprintf('\nSynthetic background noise generated.\n');
fprintf('Target input SNR: %.2f dB\n', targetSNRdB);

%% ============================================================
%  7. Manual STFT preparation
% =============================================================

analysisWindow = hann(frameLength, 'periodic');

% Zero-padding prevents boundary reconstruction instability
prePad = frameLength;
postPad = frameLength;

noisyPadded = [
    zeros(prePad, 1);
    noisy;
    zeros(postPad, 1)
];

originalPaddedLength = length(noisyPadded);

% Ensure last frame is fully covered
numFrames = ceil( ...
    (originalPaddedLength - frameLength) / hopLength) + 1;

requiredLength = ...
    (numFrames - 1) * hopLength + frameLength;

if requiredLength > length(noisyPadded)

    noisyPadded = [
        noisyPadded;
        zeros(requiredLength - length(noisyPadded), 1)
    ];

end

%% ============================================================
%  8. Manual STFT
% =============================================================

X = zeros(fftLength, numFrames);

frameTimes = zeros(1, numFrames);

for k = 1:numFrames

    startIndex = (k - 1) * hopLength + 1;

    frame = noisyPadded( ...
        startIndex:startIndex + frameLength - 1);

    windowedFrame = frame .* analysisWindow;

    X(:, k) = fft(windowedFrame, fftLength);

    % Frame centre mapped back to original audio time
    centreSample = ...
        startIndex - 1 ...
        + frameLength / 2 ...
        - prePad;

    frameTimes(k) = centreSample / fs;

end

fprintf('Manual STFT completed.\n');

%% ============================================================
%  9. Estimate noise PSD
% =============================================================
%
% The original recording contains approximately 1 second of silence.
% Use frames between 0.05 s and 0.80 s as noise-only frames.

noiseFrames = ...
    frameTimes >= 0.05 & ...
    frameTimes <= 0.80;

if sum(noiseFrames) < 3
    error('Not enough noise-only frames were found.');
end

noisePSD = mean( ...
    abs(X(:, noiseFrames)).^2, ...
    2);

fprintf('Noise PSD estimated from initial silent region.\n');

%% ============================================================
%  10. Wiener filtering
% =============================================================

Y = zeros(size(X));

previousGain = ones(fftLength, 1);

for k = 1:numFrames

    noisyPSD = abs(X(:, k)).^2;

    % Estimate speech PSD
    estimatedSpeechPSD = max( ...
        noisyPSD - noisePSD, ...
        0);

    % Classical Wiener gain
    currentGain = ...
        estimatedSpeechPSD ./ ...
        (estimatedSpeechPSD + noisePSD + eps);

    % Gain floor prevents speech from being completely removed
    currentGain = max(currentGain, gainFloor);

    % Mild temporal smoothing reduces musical-noise artefacts
    smoothedGain = ...
        0.70 * previousGain ...
        + 0.30 * currentGain;

    Y(:, k) = smoothedGain .* X(:, k);

    previousGain = smoothedGain;

end

fprintf('Wiener filtering completed.\n');

%% ============================================================
%  11. Stable weighted overlap-add reconstruction
% =============================================================

reconstructed = zeros(length(noisyPadded), 1);
windowWeight = zeros(length(noisyPadded), 1);

for k = 1:numFrames

    startIndex = (k - 1) * hopLength + 1;

    reconstructedFrame = real( ...
        ifft(Y(:, k), fftLength));

    reconstructedFrame = ...
        reconstructedFrame(1:frameLength);

    % Synthesis window
    reconstructedFrame = ...
        reconstructedFrame .* analysisWindow;

    outputIndices = ...
        startIndex:startIndex + frameLength - 1;

    reconstructed(outputIndices) = ...
        reconstructed(outputIndices) ...
        + reconstructedFrame;

    windowWeight(outputIndices) = ...
        windowWeight(outputIndices) ...
        + analysisWindow.^2;

end

% Safe overlap-add normalisation
validWeight = windowWeight > 1e-8;

reconstructed(validWeight) = ...
    reconstructed(validWeight) ./ ...
    windowWeight(validWeight);

reconstructed(~validWeight) = 0;

%% ============================================================
%  12. Remove zero padding
% =============================================================

enhanced = reconstructed( ...
    prePad + 1 : ...
    prePad + length(clean));

enhanced = real(enhanced(:));

enhanced(~isfinite(enhanced)) = 0;

fprintf('Stable overlap-add reconstruction completed.\n');

%% ============================================================
%  13. Match lengths
% =============================================================

signalLength = min([ ...
    length(clean), ...
    length(noisy), ...
    length(enhanced)]);

clean = clean(1:signalLength);
noisy = noisy(1:signalLength);
addedNoise = addedNoise(1:signalLength);
enhanced = enhanced(1:signalLength);

time = (0:signalLength - 1)' / fs;

evaluationStart = min( ...
    round(silenceDuration * fs) + 1, ...
    signalLength);

evaluationRegion = ...
    evaluationStart:signalLength;

%% ============================================================
%  14. Calculate SNR
% =============================================================

inputError = ...
    noisy(evaluationRegion) ...
    - clean(evaluationRegion);

outputError = ...
    enhanced(evaluationRegion) ...
    - clean(evaluationRegion);

inputSNR = 10 * log10( ...
    sum(clean(evaluationRegion).^2) / ...
    (sum(inputError.^2) + eps));

outputSNR = 10 * log10( ...
    sum(clean(evaluationRegion).^2) / ...
    (sum(outputError.^2) + eps));

snrImprovement = ...
    outputSNR - inputSNR;

%% ============================================================
%  15. Signal diagnostic information
% =============================================================

cleanPeak = max(abs(clean));
noisyPeak = max(abs(noisy));
enhancedPeak = max(abs(enhanced));

fprintf('\nSignal peaks after reconstruction:\n');
fprintf('Clean peak    : %.6f\n', cleanPeak);
fprintf('Noisy peak    : %.6f\n', noisyPeak);
fprintf('Enhanced peak : %.6f\n', enhancedPeak);

fprintf('\nMeasured Input SNR : %.2f dB\n', inputSNR);
fprintf('Measured Output SNR: %.2f dB\n', outputSNR);
fprintf('SNR Improvement    : %.2f dB\n', snrImprovement);

%% ============================================================
%  16. Save listening versions
% =============================================================

cleanToSave = normaliseForListening(clean);
noisyToSave = normaliseForListening(noisy);
enhancedToSave = normaliseForListening(enhanced);

audiowrite(cleanFile, cleanToSave, fs);
audiowrite(noisyFile, noisyToSave, fs);
audiowrite(enhancedFile, enhancedToSave, fs);

fprintf('\nAudio files saved.\n');

%% ============================================================
%  17. Listen to noisy and enhanced signals
% =============================================================

fprintf('Playing NOISY speech...\n');

soundsc(noisyToSave, fs);
pause(length(noisyToSave) / fs + 0.5);

fprintf('Playing ENHANCED speech...\n');

soundsc(enhancedToSave, fs);
pause(length(enhancedToSave) / fs + 0.5);

%% ============================================================
%  18. Waveform comparison
% =============================================================

fig1 = figure( ...
    'Color', 'w', ...
    'Position', [100 80 1200 780]);

subplot(3,1,1);

plot(time, clean, 'LineWidth', 0.8);

title('Clean Speech');
xlabel('Time (s)');
ylabel('Amplitude');

set(gca, ...
    'Color', 'w', ...
    'XColor', 'k', ...
    'YColor', 'k');

grid on;

subplot(3,1,2);

plot(time, noisy, 'LineWidth', 0.8);

title(sprintf( ...
    'Noisy Speech - Input SNR = %.2f dB', ...
    inputSNR));

xlabel('Time (s)');
ylabel('Amplitude');

set(gca, ...
    'Color', 'w', ...
    'XColor', 'k', ...
    'YColor', 'k');

grid on;

subplot(3,1,3);

plot(time, enhanced, 'LineWidth', 0.8);

title(sprintf( ...
    'Enhanced Speech - Output SNR = %.2f dB', ...
    outputSNR));

xlabel('Time (s)');
ylabel('Amplitude');

set(gca, ...
    'Color', 'w', ...
    'XColor', 'k', ...
    'YColor', 'k');

grid on;

sgtitle( ...
    'ELEC5305 Preliminary Speech Enhancement Results');

exportgraphics( ...
    fig1, ...
    fullfile(resultsDir, 'waveform_comparison.png'), ...
    'Resolution', 200);

%% ============================================================
%  19. Spectrogram comparison
% =============================================================

positiveBins = 1:(fftLength/2 + 1);

frequencyAxis = ...
    (0:fftLength/2)' * fs / fftLength / 1000;

validFrames = ...
    frameTimes >= 0 & ...
    frameTimes <= signalLength / fs;

noisySpectrumDB = ...
    20 * log10( ...
    abs(X(positiveBins, validFrames)) ...
    + 1e-8);

enhancedSpectrumDB = ...
    20 * log10( ...
    abs(Y(positiveBins, validFrames)) ...
    + 1e-8);

displayTimes = frameTimes(validFrames);

commonMaximum = max(noisySpectrumDB(:));
commonMinimum = commonMaximum - 80;

fig2 = figure( ...
    'Color', 'w', ...
    'Position', [100 60 1200 800]);

subplot(2,1,1);

imagesc( ...
    displayTimes, ...
    frequencyAxis, ...
    noisySpectrumDB);

axis xy;

xlabel('Time (s)');
ylabel('Frequency (kHz)');
title('Noisy Speech Spectrogram');

set(gca, ...
    'Color', 'w', ...
    'XColor', 'k', ...
    'YColor', 'k');

clim([commonMinimum commonMaximum]);

colorbar;

subplot(2,1,2);

imagesc( ...
    displayTimes, ...
    frequencyAxis, ...
    enhancedSpectrumDB);

axis xy;

xlabel('Time (s)');
ylabel('Frequency (kHz)');
title('Enhanced Speech Spectrogram');

set(gca, ...
    'Color', 'w', ...
    'XColor', 'k', ...
    'YColor', 'k');

clim([commonMinimum commonMaximum]);

colorbar;

sgtitle( ...
    'STFT-Based Wiener Speech Enhancement');

exportgraphics( ...
    fig2, ...
    fullfile(resultsDir, 'spectrogram_comparison.png'), ...
    'Resolution', 200);

%% ============================================================
%  20. SNR result figure
% =============================================================

fig3 = figure( ...
    'Color', 'w', ...
    'Position', [200 120 760 560]);

values = [inputSNR outputSNR];

bar(values);

set(gca, ...
    'Color', 'w', ...
    'XColor', 'k', ...
    'YColor', 'k', ...
    'XTick', [1 2], ...
    'XTickLabel', ...
    {'Input SNR', 'Output SNR'});

ylabel('SNR (dB)');

title(sprintf( ...
    'Preliminary SNR Improvement = %.2f dB', ...
    snrImprovement));

grid on;

% Add numeric labels
for i = 1:2

    text( ...
        i, ...
        values(i), ...
        sprintf(' %.2f dB', values(i)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', ...
        'FontWeight', 'bold');

end

exportgraphics( ...
    fig3, ...
    fullfile(resultsDir, 'snr_results.png'), ...
    'Resolution', 200);

%% ============================================================
%  21. Save numerical results
% =============================================================

resultFile = ...
    fullfile(resultsDir, 'snr_results.txt');

fileID = fopen(resultFile, 'w');

fprintf(fileID, ...
    'ELEC5305 Project Feedback Two - Preliminary Results\n\n');

fprintf(fileID, ...
    'Target Input SNR: %.2f dB\n', ...
    targetSNRdB);

fprintf(fileID, ...
    'Measured Input SNR: %.2f dB\n', ...
    inputSNR);

fprintf(fileID, ...
    'Measured Output SNR: %.2f dB\n', ...
    outputSNR);

fprintf(fileID, ...
    'SNR Improvement: %.2f dB\n\n', ...
    snrImprovement);

fprintf(fileID, ...
    'STFT Parameters:\n');

fprintf(fileID, ...
    'Sampling Rate: %d Hz\n', fs);

fprintf(fileID, ...
    'Frame Length: %d samples\n', frameLength);

fprintf(fileID, ...
    'Hop Length: %d samples\n', hopLength);

fprintf(fileID, ...
    'FFT Length: %d samples\n', fftLength);

fprintf(fileID, ...
    'Input Noise Type: Gaussian white noise\n');

fclose(fileID);

%% ============================================================
%  22. Final summary
% =============================================================

fprintf('\n============================================\n');
fprintf('ELEC5305 PRELIMINARY RESULTS\n');
fprintf('============================================\n');

fprintf('Measured Input SNR : %.2f dB\n', inputSNR);
fprintf('Measured Output SNR: %.2f dB\n', outputSNR);
fprintf('SNR Improvement    : %.2f dB\n', snrImprovement);

fprintf('\nGenerated files:\n');

fprintf('  audio/clean.wav\n');
fprintf('  audio/noisy.wav\n');
fprintf('  audio/enhanced.wav\n');

fprintf('  results/waveform_comparison.png\n');
fprintf('  results/spectrogram_comparison.png\n');
fprintf('  results/snr_results.png\n');
fprintf('  results/snr_results.txt\n');

fprintf('\nPreliminary experiment completed successfully.\n');
fprintf('============================================\n\n');

end


%% ============================================================
%  Local function: normalise audio for listening
% =============================================================

function y = normaliseForListening(x)

peakValue = max(abs(x));

if peakValue > 0
    y = 0.95 * x / peakValue;
else
    y = x;
end

y = max(min(y, 0.99), -0.99);

end