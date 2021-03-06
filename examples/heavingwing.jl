#=##############################################################################
# DESCRIPTION
Test FLOWVLM solver on kinematics of an isolated, planar, swept, wing in
heaving motion

# AUTHORSHIP
  * Author    : Eduardo J. Alvarez
  * Email     : Edo.AlvarezR@gmail.com
  * Created   : Oct 2019
  * License   : MIT
=###############################################################################

# ------------ MODULES ---------------------------------------------------------
# Load simulation engine
# import FLOWUnsteady
reload("FLOWUnsteady")
uns = FLOWUnsteady
vlm = uns.vlm

import GeometricTools
gt = GeometricTools

using PyPlot

# ------------ GLOBAL VARIABLES ------------------------------------------------
# Default path where to save data
extdrive_path = "/media/edoalvar/MyExtDrive/simulationdata7/"



# ------------ DRIVERS ---------------------------------------------------------
function run_heavingwing()
    heavingwing(; nsteps=400, p_per_step=1, vlm_rlx=0.75,
                    VehicleType=uns.VLMVehicle,
                    save_path=extdrive_path*"bertinsheaving20/",
                    verbose=true, disp_plot=true)
end


# ------------------------------------------------------------------------------
"""
    Test FLOWVLM solver on kinematics of an isolated, planar, swept, wing in
    heaving motion.
"""
function heavingwing(;   # TEST OPTIONS
                        VehicleType=uns.VLMVehicle,
                        tol=0.025,
                        wake_coupled=true,
                        nsteps=150,
                        vlm_fsgm=-1,
                        p_per_step = 1,
                        vlm_rlx = -1,
                        # OUTPUT OPTIONS
                        save_path=nothing,
                        run_name="bertins",
                        prompt=true,
                        verbose=true, verbose2=true, v_lvl=1,
                        disp_plot=true, figsize_factor=5/6
                        )

    if verbose; println("\t"^(v_lvl)*"Running Bertin's wing test..."); end;

    # ------------- GENERATE BERTIN'S WING -------------------------------------
    if verbose; println("\t"^(v_lvl+1)*"Generating geometry..."); end;
    # Experimental conditions
    magVinf = 163*0.3048            # (m/s) freestream
    rhoinf = 9.093/10^1             # (kg/m^3) air density
    alpha = 4.2                     # (deg) angle of attack
    qinf = 0.5*rhoinf*magVinf^2     # (Pa) static pressure

    # Geometry
    twist = 0.0                     # (deg) root twist
    lambda = 45.0                   # (deg) sweep
    gamma = 0.0                     # (deg) Dihedral
    b = 98*0.0254                   # (m) span
    ar = 5.0                        # Aspect ratio
    tr = 1.0                        # Taper ratio

    # Discretization
    n = 4*2^4                       # Number of horseshoes
    r = 12.0                        # Geometric expansion
    central = false                 # Central expansion

    # Freestream function
    # Vinf(X, t) = 1e-12*ones(3)      # (Don't make this zero or things will break)
    # Here I had to give it an initial freestream or the unsteady shedding would
    # in the first step
    Vinf(X, t) = t==0 ? magVinf*[1,0,0] : 1e-12*ones(3)

    # Generate wing
    wing = vlm.simpleWing(b, ar, tr, twist, lambda, gamma;
                                                    n=n, r=r, central=central)

    # Pitch wing to corresponding angle of attack
    O = zeros(3)                    # Coordinate system origin
    Oaxis = gt.rotation_matrix2(0.0, -alpha, 0.0) # Coordinate system axes
    vlm.setcoordsystem(wing, O, Oaxis)


    # ------------- SIMULATION SETUP -------------------------------------------
    if verbose; println("\t"^(v_lvl+1)*"Simulation setup..."); end;

    wake_len = 8*b             # (m) length to develop the wake
    lambda_vpm = 2.0            # target core overlap of vpm wake

    # Simulation options
    telapsed = wake_len/magVinf # (s) total time to perform maneuver
    # nsteps = 2000             # Number of time steps
    Vcruise = magVinf           # (m/s) aircraft velocity during cruise
    RPMh_w = 0.0                # Rotor RPM during hover (dummy)

    # Solver options
    # p_per_step = 1              # Number of particle sheds per time steps
    overwrite_sigma = lambda_vpm * magVinf * (telapsed/nsteps)/p_per_step # Smoothing core size
    # vlm_sigma = -1            # VLM regularization core size (deactivated with -1)
    vlm_sigma = vlm_fsgm*b
    surf_sigma = overwrite_sigma
    # wake_coupled = true       # Coupled VPM wake with VLM solution
    shed_unsteady = true        # Whether to shed unsteady-loading wake
    # shed_unsteady = false
    # vlm_rlx = -1                # VLM relaxation (deactivated with -1)

    # System definitions
    system = vlm.WingSystem()   # System of all FLOWVLM objects
    vlm.addwing(system, "BertinsWing", wing)

    vlm_system = system         # System solved through VLM solver
    wake_system = system        # System that will shed a VPM wake

    # Vehicle definition
    vehicle = VehicleType(      system;
                                vlm_system=vlm_system,
                                wake_system=wake_system
                             )

    if verbose
        println("\t"^(v_lvl+1)*"Core overlap:\t\t$(lambda_vpm)")
        println("\t"^(v_lvl+1)*"Core size:\t\t$(round(overwrite_sigma/b, 3))*b")
        println("\t"^(v_lvl+1)*"Time step translation:\t$(round(magVinf * (telapsed/nsteps)/b, 3))*b")
    end


    # ------------- MANEUVER DEFINITION  ---------------------------------------
    ncycles = 10                # Number of cycles in maneuver
    k = 2*pi*ncycles            # Oscillation frequency
    tilt_amplitude = alpha/2    # (deg) tilting amplitude

    # Translational velocity of system over Vcruise
    function Vaircraft(t)
        Vx = 0.75 + abs(0.25*sin(k*t/2))
        Vy = 0
        Vz = 0.1*sin(k*t)
        return [-Vx, Vy, Vz]
    end
    # Angle of the vehicle
    function angle_wing(t)
        return [0, tilt_amplitude*sin(k*t), 0]
    end

    angle = ()                  # Angle of each tilting system
    RPM = ()                    # RPM of each rotor system
    Vvehicle = Vaircraft        # Velocity of the vehicle
    anglevehicle = angle_wing   # Angle of the vehicle

    maneuver = uns.KinematicManeuver(angle, RPM, Vvehicle, anglevehicle)

    # Plot maneuver path and controls
    uns.plot_maneuver(maneuver; vis_nsteps=nsteps)

    # Simulation setup
    Vref = Vcruise                  # Reference velocity
    RPMref = RPMh_w                 # Reference RPM
    ttot = telapsed                 # Total time to perform maneuver
    Vinit = Vref*Vaircraft(0)       # Initial vehicle velocity
    Winit = pi/180*(angle_wing(1e-6) - angle_wing(0))/(1e-6*ttot)  # Initial angular velocity
                                    # Maximum number of particles
    max_particles = ceil(Int, (nsteps+2)*(2*vlm.get_m(vehicle.vlm_system)+1)*p_per_step)

    simulation = uns.Simulation(vehicle, maneuver, Vref, RPMref, ttot;
                                                    Vinit=Vinit, Winit=Winit)

    # ------------- SIMULATION MONITOR -----------------------------------------
    y2b = 2*wing._ym/b

    # Weber's lift distribution data (Table 3)
    web_2yb = [0.0, 0.041, 0.082, 0.163, 0.245, 0.367, 0.510, 0.653, 0.898, 0.949]
    web_Cl = [0.235, 0.241, 0.248, 0.253, 0.251, 0.251, 0.251, 0.246, 0.192, 0.171]
    web_CL = 0.238
    web_ClCL = web_Cl/web_CL

    # Weber's drag distribution data (Table 3)
    web_Cd = [0.059, 0.025, 0.016, 0.009, 0.007, 0.006, 0.006, 0.004, -0.002, -0.007]
    web_CD = 0.005
    web_CdCD = web_Cd/web_CD

    prev_wing = nothing

    function monitor(sim, PFIELD, T, DT; figname="monitor_$(save_path)",
                                                                nsteps_plot=1)

        aux = PFIELD.nt/nsteps
        clr = (1-aux, 0, aux)

        if PFIELD.nt==0 && disp_plot
            figure(figname, figsize=[7*2, 5*2]*figsize_factor)
            subplot(221)
            xlim([0,1])
            xlabel(L"$\frac{2y}{b}$")
            ylabel(L"$\frac{Cl}{CL}$")
            title("Spanwise lift distribution")

            subplot(222)
            xlim([0,1])
            xlabel(L"$\frac{2y}{b}$")
            ylabel(L"$\frac{Cd}{CD}$")
            title("Spanwise drag distribution")

            subplot(223)
            xlabel("Simulation time (s)")
            ylabel(L"Lift Coefficient $C_L$")

            subplot(224)
            xlabel("Simulation time (s)")
            ylabel(L"Drag Coefficient $C_D$")

            figure(figname*"_2", figsize=[7*2, 5*1]*figsize_factor)
            subplot(121)
            xlabel(L"$\frac{2y}{b}$")
            ylabel(L"Circulation $\Gamma$")
            subplot(122)
            xlabel(L"$\frac{2y}{b}$")
            ylabel(L"Effective velocity $V_\infty$")

            figure(figname*"_3", figsize=[7*2, 5*1]*figsize_factor)
            subplot(121)
            xlabel("Simulation time")
            ylabel("Velocity")
            subplot(122)
            xlabel("Simulation time")
            ylabel("Angular velocity")
        end

        if PFIELD.nt!=0 && PFIELD.nt%nsteps_plot==0 && disp_plot
            figure(figname)


            # Force at each VLM element
            Ftot = uns.calc_aerodynamicforce(wing, prev_wing, PFIELD, Vinf, DT,
                                                            rhoinf; t=PFIELD.t)
            L, D, S = uns.decompose(Ftot, [0,0,1], [-1,0,0])
            vlm._addsolution(wing, "L", L)
            vlm._addsolution(wing, "D", D)
            vlm._addsolution(wing, "S", S)

            # Force per unit span at each VLM element
            ftot = uns.calc_aerodynamicforce(wing, prev_wing, PFIELD, Vinf, DT,
                                        rhoinf; t=PFIELD.t, per_unit_span=true)
            l, d, s = uns.decompose(ftot, [0,0,1], [-1,0,0])

            # Lift of the wing
            Lwing = norm(sum(L))
            CLwing = Lwing/(qinf*b^2/ar)
            ClCL = norm.(l) / (Lwing/b)

            # Drag of the wing
            Dwing = norm(sum(D))
            CDwing = Dwing/(qinf*b^2/ar)
            CdCD = [sign(dot(this_d, [1,0,0])) for this_d in d].*norm.(d) / (Dwing/b) # Preserves the sign of drag

            vlm._addsolution(wing, "Cl/CL", ClCL)
            vlm._addsolution(wing, "Cd/CD", CdCD)

            subplot(221)
            plot(web_2yb, web_ClCL, "ok", label="Weber's experimental data")
            plot(y2b, ClCL, "-", label="FLOWVLM", alpha=0.5, color=clr)

            subplot(222)
            plot(web_2yb, web_CdCD, "ok", label="Weber's experimental data")
            plot(y2b, CdCD, "-", label="FLOWVLM", alpha=0.5, color=clr)

            subplot(223)
            plot([0, T], web_CL*ones(2), ":k", label="Weber's experimental data")
            plot([T], [CLwing], "o", label="FLOWVLM", alpha=0.5, color=clr)

            subplot(224)
            plot([0, T], web_CD*ones(2), ":k", label="Weber's experimental data")
            plot([T], [CDwing], "o", label="FLOWVLM", alpha=0.5, color=clr)

            figure(figname*"_2")
            subplot(121)
            plot(y2b, wing.sol["Gamma"], "-", label="FLOWVLM", alpha=0.5, color=clr)
            if wake_coupled && PFIELD.nt!=0
                subplot(122)
                plot(y2b, norm.(wing.sol["Vkin"])/magVinf, "-", label="FLOWVLM", alpha=0.5, color=[clr[1], 1, clr[3]])
                if VehicleType==uns.VLMVehicle
                    plot(y2b, norm.(wing.sol["Vvpm"]), "-", label="FLOWVLM", alpha=0.5, color=clr)
                end
                plot(y2b, [norm(Vinf(vlm.getControlPoint(wing, i), T)) for i in 1:vlm.get_m(wing)],
                                                            "-k", label="FLOWVLM", alpha=0.5)
            end

            figure(figname*"_3")
            subplot(121)
            plot([sim.t], [sim.vehicle.V[1]], ".r", label=L"V_x", alpha=0.5)
            plot([sim.t], [sim.vehicle.V[2]], ".g", label=L"V_y", alpha=0.5)
            plot([sim.t], [sim.vehicle.V[3]], ".b", label=L"V_z", alpha=0.5)
            if PFIELD.nt==1; legend(loc="best", frameon=false); end;
            subplot(122)
            plot([sim.t], [sim.vehicle.W[1]], ".r", label=L"\Omega_x", alpha=0.5)
            plot([sim.t], [sim.vehicle.W[2]], ".g", label=L"\Omega_y", alpha=0.5)
            plot([sim.t], [sim.vehicle.W[3]], ".b", label=L"\Omega_z", alpha=0.5)
            if PFIELD.nt==1; legend(loc="best", frameon=false); end;
        end

        prev_wing = deepcopy(wing)

        return false
    end


    # ------------- RUN SIMULATION ---------------------------------------------
    if verbose; println("\t"^(v_lvl+1)*"Running simulation..."); end;
    # Run simulation
    pfield = uns.run_simulation(simulation, nsteps;
                                      # SIMULATION OPTIONS
                                      Vinf=Vinf,
                                      # SOLVERS OPTIONS
                                      p_per_step=p_per_step,
                                      overwrite_sigma=overwrite_sigma,
                                      vlm_sigma=vlm_sigma,
                                      vlm_rlx=vlm_rlx,
                                      surf_sigma=surf_sigma,
                                      max_particles=max_particles,
                                      wake_coupled=wake_coupled,
                                      shed_unsteady=shed_unsteady,
                                      extra_runtime_function=monitor,
                                      # OUTPUT OPTIONS
                                      save_path=save_path,
                                      run_name=run_name,
                                      prompt=prompt,
                                      verbose=verbose2, v_lvl=v_lvl+1,
                                      save_horseshoes=!wake_coupled
                                      )

    return simulation, pfield
end
