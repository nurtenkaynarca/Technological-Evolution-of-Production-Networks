# Appendix C: Sensitivity analyses

Code and initial networks for the sensitivity analyses in Appendix C. All simulations use an increasing number of categories (INC) and random targeting. Each changes one element of the baseline:

| Simulation | Appendix | Change from the baseline | Output files |
|---|---|---|---|
| Heterogeneous size | C.1 | Initial categories of 25–75 firms | `simHetSize_0_<scenario>_<run>.mat` |
| Heterogeneous homogeneity | C.1 | Initial categories differ in their number of essential inputs | `simHetHom_0_<scenario>_<run>.mat` |
| Stronger spillovers | C.2 | $\lambda_1 = 0.01$ | `simHighSpill_0_<scenario>_<run>.mat` |
| Disadvantaged new firms | C.3 | $\lambda_0^e = 0.5$, raised to $\lambda_0 = 1$ after 10 periods | `simDisadv_0_<scenario>_<run>.mat` |

## Contents

| File | Description |
|---|---|
| `generateSimulationFiles.m` | Simulation function (same as in the main folder) |
| `i_data_ar.mat` | Baseline initial network |
| `i_data_hetsize.mat` | Initial network with heterogeneous category sizes |
| `i_data_hethom.mat` | Initial network with heterogeneous homogeneity |
| `figures_app.m` | Figures and tables of Appendix C |

## Reproducing the results

Run everything from this folder, so that the simulation files and the initial networks are in the same folder as `figures_app.m`.

**1. Run the simulations** (100 runs for each scenario; Scenarios A, B, C = 0, 1, 2):

```matlab
for s = 0:2
    parfor k = 1:100
        generateSimulationFiles(k, 0, s, 1, 1,   Inf, 0.004, 50, 0, 1, 1)   % heterogeneous size
        generateSimulationFiles(k, 0, s, 1, 1,   Inf, 0.004, 50, 0, 1, 2)   % heterogeneous homogeneity
        generateSimulationFiles(k, 0, s, 1, 1,   Inf, 0.01,  50, 0, 1)      % stronger spillovers
        generateSimulationFiles(k, 0, s, 1, 0.5, 10,  0.004, 50, 0, 1)      % disadvantaged new firms
    end
end
```

The output file names are set automatically from the inputs, so the four simulations do not overwrite each other.

**2. Produce the figures and tables:**

```matlab
figures_app
```

| Paper | Output |
|---|---|
| Figures C1–C9 | `graphs/figC1.pdf` … `graphs/figC9.pdf` |
| Table C1 | `tables/tab_exits_app.tex` |
| Tables C2–C4 | `tables/tab_corr_app.tex`, `tables/tab_corr_chan_app.tex`, `tables/tab_corr_sup_app.tex` |

With $\lambda_1 = 0.01$, structural productivity is well defined only while $\lambda_1 \rho(M_t) < 1$, where $\rho(M_t)$ is the spectral radius of the adjacency matrix. This condition fails as the network becomes denser, so `figures_app.m` reports these simulations up to period 245; all other simulations are reported up to period 750.
