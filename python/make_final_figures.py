from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import soundfile as sf
from scipy.signal import stft


PROJECT_DIR = Path(__file__).resolve().parents[1]

RESULTS_DIR = PROJECT_DIR / "results" / "final"
FIGURE_DIR = RESULTS_DIR / "figures"

FIGURE_DIR.mkdir(parents=True, exist_ok=True)

SIGNAL_FILE = RESULTS_DIR / "signal_metrics.csv"
SIGNAL_SUMMARY_FILE = RESULTS_DIR / "signal_metrics_summary.csv"

REP_FILE = RESULTS_DIR / "representation_results.csv"
REP_SUMMARY_FILE = RESULTS_DIR / "representation_summary.csv"

MODEL_SUMMARY_FILE = RESULTS_DIR / "model_layer_overall_summary.csv"

METADATA_FILE = PROJECT_DIR / "data" / "mixtures" / "mixture_metadata.csv"


# ============================================================
# Load results
# ============================================================

signal = pd.read_csv(SIGNAL_FILE)
signal_summary = pd.read_csv(SIGNAL_SUMMARY_FILE)

rep = pd.read_csv(REP_FILE)
rep_summary = pd.read_csv(REP_SUMMARY_FILE)

model_summary = pd.read_csv(MODEL_SUMMARY_FILE)

metadata = pd.read_csv(METADATA_FILE)

print("Loaded final result files successfully.")


# ============================================================
# Figure 1
# SNR improvement versus input SNR
# ============================================================

fig, ax = plt.subplots(figsize=(8, 5))

for noise_name, group in signal_summary.groupby("noise_type"):

    group = group.sort_values("target_snr_db")

    ax.errorbar(
        group["target_snr_db"],
        group["mean_snr_improvement_db"],
        yerr=group["std_snr_improvement_db"],
        marker="o",
        linewidth=1.8,
        capsize=4,
        label=noise_name
    )

ax.axhline(0, linestyle="--", linewidth=1)

ax.set_xlabel("Input SNR (dB)")
ax.set_ylabel("SNR Improvement (dB)")
ax.set_title("Wiener Enhancement: SNR Improvement")
ax.legend(title="Noise Type")
ax.grid(True, alpha=0.3)

fig.tight_layout()

fig.savefig(
    FIGURE_DIR / "fig1_snr_improvement.png",
    dpi=220
)

plt.close(fig)


# ============================================================
# Figure 2
# STOI improvement versus input SNR
# ============================================================

fig, ax = plt.subplots(figsize=(8, 5))

for noise_name, group in signal_summary.groupby("noise_type"):

    group = group.sort_values("target_snr_db")

    ax.errorbar(
        group["target_snr_db"],
        group["mean_stoi_improvement"],
        yerr=group["std_stoi_improvement"],
        marker="o",
        linewidth=1.8,
        capsize=4,
        label=noise_name
    )

ax.axhline(0, linestyle="--", linewidth=1)

ax.set_xlabel("Input SNR (dB)")
ax.set_ylabel("STOI Improvement")
ax.set_title("Wiener Enhancement: STOI Improvement")
ax.legend(title="Noise Type")
ax.grid(True, alpha=0.3)

fig.tight_layout()

fig.savefig(
    FIGURE_DIR / "fig2_stoi_improvement.png",
    dpi=220
)

plt.close(fig)


# ============================================================
# Function:
# Layer-wise recovery at each SNR
# ============================================================

def make_layer_snr_figure(model_name, output_name):

    subset = rep[
        rep["model"] == model_name
    ].copy()

    fig, ax = plt.subplots(figsize=(8, 5))

    for snr_value in sorted(
        subset["target_snr_db"].unique()
    ):

        snr_subset = subset[
            subset["target_snr_db"] == snr_value
        ]

        grouped = (
            snr_subset
            .groupby("layer")
            ["recovery_score"]
            .agg(["mean", "std"])
            .reset_index()
            .sort_values("layer")
        )

        ax.errorbar(
            grouped["layer"],
            grouped["mean"],
            yerr=grouped["std"],
            marker="o",
            linewidth=1.7,
            capsize=3,
            label=f"{snr_value:+.0f} dB"
        )

    ax.axhline(
        0,
        linestyle="--",
        linewidth=1
    )

    ax.set_xlabel("Transformer Layer")
    ax.set_ylabel("Representation Recovery Score")

    ax.set_title(
        f"{model_name}: Layer-Wise Wiener Benefit"
    )

    ax.legend(
        title="Input SNR"
    )

    ax.grid(True, alpha=0.3)

    fig.tight_layout()

    fig.savefig(
        FIGURE_DIR / output_name,
        dpi=220
    )

    plt.close(fig)


# ============================================================
# Figures 3 and 4
# ============================================================

make_layer_snr_figure(
    "WavLM_BasePlus",
    "fig3_wavlm_layer_recovery.png"
)

make_layer_snr_figure(
    "HuBERT_Base",
    "fig4_hubert_layer_recovery.png"
)


# ============================================================
# Figure 5
# Overall layer-wise model comparison
# ============================================================

fig, ax = plt.subplots(figsize=(8, 5))

for model_name, group in model_summary.groupby("model"):

    group = group.sort_values("layer")

    ax.errorbar(
        group["layer"],
        group["mean_recovery_score"],
        yerr=group["std_recovery_score"],
        marker="o",
        linewidth=1.8,
        capsize=4,
        label=model_name
    )

ax.axhline(
    0,
    linestyle="--",
    linewidth=1
)

ax.set_xlabel("Transformer Layer")
ax.set_ylabel("Mean Representation Recovery Score")

ax.set_title(
    "Overall Layer-Wise Representation Recovery"
)

ax.legend()
ax.grid(True, alpha=0.3)

fig.tight_layout()

fig.savefig(
    FIGURE_DIR / "fig5_model_layer_comparison.png",
    dpi=220
)

plt.close(fig)


# ============================================================
# Figure 6
# Waveform improvement versus representation improvement
# ============================================================

experiment_rep = (
    rep
    .groupby(
        ["experiment_id", "model"]
    )
    .agg(
        mean_recovery_score=(
            "recovery_score",
            "mean"
        ),

        snr_improvement_db=(
            "snr_improvement_db",
            "first"
        )
    )
    .reset_index()
)

fig, ax = plt.subplots(figsize=(8, 5))

for model_name, group in experiment_rep.groupby("model"):

    ax.scatter(
        group["snr_improvement_db"],
        group["mean_recovery_score"],
        alpha=0.75,
        label=model_name
    )

    if len(group) > 1:

        r = np.corrcoef(
            group["snr_improvement_db"],
            group["mean_recovery_score"]
        )[0, 1]

        print(
            f"{model_name}: "
            f"correlation(SNR improvement, recovery) = {r:.4f}"
        )

ax.axhline(
    0,
    linestyle="--",
    linewidth=1
)

ax.set_xlabel("SNR Improvement (dB)")
ax.set_ylabel("Mean Representation Recovery Score")

ax.set_title(
    "Waveform Improvement vs Representation Recovery"
)

ax.legend()
ax.grid(True, alpha=0.3)

fig.tight_layout()

fig.savefig(
    FIGURE_DIR / "fig6_snr_vs_representation.png",
    dpi=220
)

plt.close(fig)


# ============================================================
# Figure 7
# Representative real-noise spectrogram
#
# Use one STRAFFIC 0 dB condition.
# ============================================================

candidate = metadata[
    (metadata["noise_type"].astype(str).str.contains(
        "STRAFFIC",
        case=False
    ))
    &
    (metadata["target_snr_db"] == 0)
]

if len(candidate) > 0:

    row = candidate.iloc[0]

    clean_path = PROJECT_DIR / row["clean_path"]
    noisy_path = PROJECT_DIR / row["noisy_path"]
    wiener_path = PROJECT_DIR / row["wiener_path"]

    clean, fs = sf.read(clean_path)
    noisy, _ = sf.read(noisy_path)
    wiener, _ = sf.read(wiener_path)

    # Remove one-second calibration region
    trim = int(fs)

    clean = clean[trim:]
    noisy = noisy[trim:]
    wiener = wiener[trim:]

    length = min(
        len(clean),
        len(noisy),
        len(wiener)
    )

    clean = clean[:length]
    noisy = noisy[:length]
    wiener = wiener[:length]

    def spectrogram_db(x):

        frequencies, times, spectrum = stft(
            x,
            fs=fs,
            window="hann",
            nperseg=512,
            noverlap=256,
            nfft=512,
            boundary=None
        )

        magnitude_db = 20 * np.log10(
            np.abs(spectrum) + 1e-8
        )

        return frequencies, times, magnitude_db

    f1, t1, s_clean = spectrogram_db(clean)
    f2, t2, s_noisy = spectrogram_db(noisy)
    f3, t3, s_wiener = spectrogram_db(wiener)

    common_max = max(
        np.max(s_clean),
        np.max(s_noisy),
        np.max(s_wiener)
    )

    common_min = common_max - 80

    fig, axes = plt.subplots(
        3,
        1,
        figsize=(10, 8),
        sharex=True
    )

    plots = [
        (axes[0], f1, t1, s_clean, "Clean Speech"),
        (axes[1], f2, t2, s_noisy, "Noisy Speech — STRAFFIC, 0 dB"),
        (axes[2], f3, t3, s_wiener, "Wiener-Enhanced Speech")
    ]

    for ax, freq, times, spec, title in plots:

        image = ax.pcolormesh(
            times,
            freq / 1000,
            spec,
            shading="auto",
            vmin=common_min,
            vmax=common_max
        )

        ax.set_ylabel("Frequency (kHz)")
        ax.set_title(title)

    axes[-1].set_xlabel("Time (s)")

    fig.colorbar(
        image,
        ax=axes,
        label="Magnitude (dB)"
    )

    fig.suptitle(
        "Representative Real-Noise Spectrogram Comparison"
    )

    fig.savefig(
        FIGURE_DIR / "fig7_representative_spectrogram.png",
        dpi=220,
        bbox_inches="tight"
    )

    plt.close(fig)

else:

    print(
        "WARNING: Could not find STRAFFIC 0 dB experiment "
        "for representative spectrogram."
    )


# ============================================================
# Save compact numerical summary
# ============================================================

model_summary.to_csv(
    RESULTS_DIR / "final_model_summary.csv",
    index=False
)

print()
print("=" * 65)
print("FINAL FIGURES GENERATED SUCCESSFULLY")
print("=" * 65)

for file in sorted(FIGURE_DIR.glob("*.png")):
    print(file.name)