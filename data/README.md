\# Dataset Instructions



The raw speech and environmental-noise datasets are not included in this repository because of their size.



\## Clean Speech



Clean speech was selected from the LibriSpeech `dev-clean` subset.



Dataset:

LibriSpeech ASR Corpus



Source:

https://www.openslr.org/12



Four utterances from two speakers were used:



\- 84-121123-0014

\- 84-121123-0015

\- 1988-24833-0021

\- 1988-24833-0022



Place the selected audio files in:



```text

data/selected/clean/

```



\## Environmental Noise



Environmental noise was obtained from the DEMAND (Diverse Environments Multi-channel Acoustic Noise Database).



Two environments were used:



\- DKITCHEN

\- STRAFFIC



The 16 kHz versions were used and one channel was selected from each environment.



Place the selected noise files in:



```text

data/selected/noise/

```



with filenames:



```text

demand\_DKITCHEN\_ch01.wav

demand\_STRAFFIC\_ch01.wav

```



\## Controlled Mixture Generation



Run the MATLAB script:



```matlab

addpath('src')

generate\_final\_dataset

```



The script creates 32 controlled experiments:



```text

4 clean utterances

× 2 environmental noise types

× 4 input SNR levels

= 32 experiments

```



The tested SNR levels are:



```text

\-5 dB

0 dB

5 dB

10 dB

```



For each condition, the script produces:



```text

clean.wav

noisy.wav

wiener.wav

```



The generated mixtures are stored locally under:



```text

data/mixtures/

```



Generated raw mixtures are intentionally excluded from GitHub. Final numerical results and figures are available under `results/final/`.

