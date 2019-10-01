# How to set up dependencies needed for FlightVehicleSim (October 2019)
Note: currently this simulation tool functions only with Julia v0.6, thus the following will assume Julia v0.6 syntax.

## [GeometricTools](https://github.com/byuflowlab/GeometricTools.jl): 

Dependencies:
- PyCall
- PyPlot
- Dierckx
- Roots
- QuadGK

Go ahead and add these Julia packages first with the standard add syntax for v0.6

```Pkg.add("PackageName")```

After you have the dependencies, clone the package using Julia. (Though you can get the dependencies later when errors show up. It's up to you.)

```Pkg.clone("https://github.com/byuflowlab/GeometricTools.jl.git")```

If using MacOS, you'll want to add 

```export PATH=$PATH:/Applications/ParaView-5.5.2.app/Contents/MacOS/```

to your .bash_profile, swapping the 5.5.2 for whatever version of [Paraview](https://www.paraview.org/download/) you have downloaded (you'll need to download it if you don't already have it).

## [FLOWVLM](https://github.com/byuflowlab/FLOWVLM)

Additional Dependencies for FLOWVLM:
- [CCBlade](https://github.com/byuflowlab/CCBlade.jl)
- [airfoil](https://github.com/EdoAlvarezR/airfoil)

### Getting CCBlade in the right version
To get CCBlade, clone the package in Julia

```Pkg.clone("https://github.com/byuflowlab/CCBlade.jl.git")```

You'll then need to go find your .julia/v0.6 directory (where all your v0.6 packages are stored, and go into the CCBlade directory and checkout the last commit before CCBlade was updated to v1.0

```git checkout bb897066c46bd10d0cad934af3fb677e4f9d0061```

### Getting airfoil
To get airfoil, clone the repo (not in Julia) and put it somewhere good for you

```git clone https://github.com/EdoAlvarezR/airfoil.git```

You will then need to go into the airfoil/src/jxlight directory and build the Fortran binary. If using MacOS, do

```make gfortran```

and that should be sufficient to build it.

Finally, clone the FLOWVLM repo (not in julia)

```git clone https://github.com/byuflowlab/FLOWVLM.git```

and then in any code using FLOWVLM, you'll need to include the FLOWVLM.jl file, and it is convenient to call FLOWVLM vlm as is done in the examples. Your code might begin with something like the following:

```
flowvlm_path = "/path_to_FLOWVLM/"
include(flowvlm_path*"src/FLOWVLM.jl")
vlm = FLOWVLM
```

In addition, you will need to make a change in FLOWVLM.jl to make sure FLOWVLM is pointed to the airfoil code correctly. In FLOWVLM.jl (in the src folder of the FLOWVLM repo) change line 21 such that the airfoil_path is the path to the directory you just cloned.

```airfoil_path = "/path_to_airfoil/"```

## [MyPanel](https://github.com/EdoAlvarezR/MyPanel.jl/blob/master/src/MyPanel.jl)

Additional Dependencies for MyPanel
- ForwardDiff

Clone the package using Julia

```Pkg.clone("https://github.com/EdoAlvarezR/MyPanel.jl.git")```

# Troubleshooting

Some things you might need to look out for:

1. Make sure your Homebrew (in Julia) is up to date. You may need to run the following:
```
using Homebrew
Homebrew.brew(`update-reset`)
```
in order to update your Homebrew.

2. You're going to have to make sure that things are in place in your Julia settings. Having things like Conda, HDF5, etc. on your machine doesn't necessarily mean that the Julia implementation has them as well.