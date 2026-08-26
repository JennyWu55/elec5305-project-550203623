# STFT-Based Speech Enhancement Using Wiener Filtering in Noisy Environments

## ELEC5305 Project

This project investigates speech enhancement using the Short-Time Fourier Transform (STFT) and Wiener filtering under different noisy conditions.

## Project Overview

Speech recordings are often affected by environmental background noise, which can reduce speech intelligibility and degrade the performance of speech processing systems. This project aims to develop a speech enhancement system based on time-frequency signal processing.

The noisy speech signal will first be analysed using the Short-Time Fourier Transform (STFT). A Wiener filter will then be applied in the time-frequency domain to suppress noise components while preserving the speech signal. The enhanced speech will be reconstructed using the inverse STFT.

## Objectives

- Analyse noisy speech signals in the time-frequency domain using STFT.
- Implement Wiener filtering for speech enhancement.
- Test the algorithm under different noise levels.
- Compare noisy and enhanced speech using spectrograms.
- Evaluate performance using Signal-to-Noise Ratio (SNR) improvement.

## Methodology

The proposed processing pipeline is:

Clean Speech  
→ Add Environmental Noise  
→ STFT  
→ Noise Spectrum Estimation  
→ Wiener Filtering  
→ Inverse STFT  
→ Enhanced Speech  
→ Performance Evaluation

## Tools

- MATLAB
- GitHub
- Audio and speech datasets

## Expected Results

The project is expected to produce a MATLAB-based speech enhancement system capable of reducing background noise in speech recordings. Performance will be evaluated using objective measures such as SNR improvement together with waveform and spectrogram comparisons.

## Project Proposal

[View the Project Proposal](ELEC5305%20Project%20Proposal.pdf)
## Project Status

Project proposal and initial planning stage.

## Course

ELEC5305 – Acoustics, Speech and Signal Processing  
The University of Sydney
